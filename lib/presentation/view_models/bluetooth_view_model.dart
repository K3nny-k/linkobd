import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../ble_transport.dart';
import '../../data/ecu/ecu_repository.dart';
import '../../domain/protocol/frame_codec.dart';

class BluetoothViewModel extends ChangeNotifier {
  final BleTransport _bleTransport;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<Uint8List>? _sfdDataSubscription;
  bool _isConnected = false;
  final List<int> _sfdBuffer = [];
  int? _negotiatedMtu;
  
  // Cache for formatted data lines to avoid reprocessing
  final List<String> _formattedLines = [];
  int _lastProcessedIndex = -1;
  
  // BLE communication constants (matching Python script)
  static const int maxRetries = 3;
  static const int responseTimeoutMs = 2000;
  
  // Response handling for Python-like BLE communication
  Completer<List<int>?>? _responseCompleter;
  Completer<bool>? _ackCompleter;
  Timer? _responseTimer;
  bool _waitingForResponse = false;
  bool _waitingForAck = false;
  int _expectedAckIndex = 0;
  List<EcuInfo> ecuList = [];
  EcuInfo? selectedEcu;

  BluetoothViewModel(this._bleTransport) {
    _isConnected = _bleTransport.isConnected; // initial snapshot
    debugPrint('🔍 BluetoothViewModel created, initial isConnected=$_isConnected');
    _setupConnectionListener();
    _setupSfdDataListener();
    // Load ECU list immediately when ViewModel is created
    initEcuList();
  }

  bool get isConnected {
    debugPrint('🔍 isConnected getter -> $_isConnected');
    return _isConnected;
  }

  String get sfdReceivedData {
    if (_sfdBuffer.isEmpty) return '';
    
    // Use cached result if buffer hasn't changed and we have processed data
    if (_lastProcessedIndex == _sfdBuffer.length && _lastProcessedIndex > 0 && _formattedLines.isNotEmpty) {
      return _formattedLines.join('\n');
    }
    
    // Process the entire buffer to detect frames correctly
    _processCompleteBuffer();
    
    return _formattedLines.join('\n');
  }
  
  /// Process the complete buffer to correctly detect frames
  void _processCompleteBuffer() {
    // Clear previous formatted lines and reprocess everything
    _formattedLines.clear();
    
    // Format the buffer with line breaks after complete frames (55 A9 headers)
    final List<int> buffer = List.from(_sfdBuffer);
    
    while (buffer.length >= 4) {
      // Look for frame header 55 A9
      final headerIndex = _findFrameHeader(buffer);
      if (headerIndex == -1) {
        // No more complete frames, add remaining bytes as-is
        if (buffer.isNotEmpty) {
          final hexString = buffer.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          _formattedLines.add('RX: $hexString');
        }
        break;
      }
      
      // Skip bytes before the header (add as-is)
      if (headerIndex > 0) {
        final prefix = buffer.take(headerIndex).toList();
        final hexString = prefix.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _formattedLines.add('RX: $hexString');
        buffer.removeRange(0, headerIndex);
      }
      
      // Check if we have enough bytes for DLC
      if (buffer.length < 4) {
        final hexString = buffer.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _formattedLines.add('RX: $hexString');
        break;
      }
      
      // Calculate frame length (big-endian DLC)
      final dlc = (buffer[2] << 8) | buffer[3] + 1;
      final totalLength = 4 + dlc;
      
      if (buffer.length >= totalLength && dlc > 1) {
        // Complete frame with payload - extract only the payload (skip header and checksum)
        // Header: buffer[0-3] (55 A9 + DLC)
        // Payload: buffer[4] to buffer[totalLength-2] (excluding last checksum byte)
        final payloadStart = 4;
        final payloadEnd = totalLength - 1; // Exclude last checksum byte
        
        if (payloadEnd > payloadStart) {
          final payload = buffer.sublist(payloadStart, payloadEnd);
          final hexString = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          _formattedLines.add('RX: $hexString');
        }
        buffer.removeRange(0, totalLength);
      } else if (buffer.length >= totalLength) {
        // Complete frame but too short for meaningful payload, show as-is
        final frame = buffer.take(totalLength).toList();
        final hexString = frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _formattedLines.add('RX: $hexString');
        buffer.removeRange(0, totalLength);
      } else {
        // Incomplete frame, add all remaining bytes as-is
        final hexString = buffer.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _formattedLines.add('RX: $hexString');
        break;
      }
    }
    
    // Update processed index
    _lastProcessedIndex = _sfdBuffer.length;
  }
  
  int _findFrameHeader(List<int> buffer) {
    for (int i = 0; i <= buffer.length - 2; i++) {
      if (buffer[i] == 0x55 && buffer[i + 1] == 0xA9) {
        return i;
      }
    }
    return -1;
  }

  void _setupConnectionListener() {
    _connectionStateSubscription = _bleTransport.connectionStateStream.listen((state) {
      final wasConnected = _isConnected;
      _isConnected = (state == BluetoothConnectionState.connected);
      
      if (wasConnected != _isConnected) {
        debugPrint('BluetoothViewModel: Connection state changed to $_isConnected');
        if (!_isConnected) {
          _sfdBuffer.clear();
          _formattedLines.clear();
          _lastProcessedIndex = -1;
          _negotiatedMtu = null;
          selectedEcu = null;
          // Don't clear ecuList anymore - keep it available
        }
        notifyListeners();
      }
    });
  }

  void _setupSfdDataListener() {
    _sfdDataSubscription = _bleTransport.rawBytesStream.listen((data) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final dataHex = data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      
      _sfdBuffer.addAll(data);
      debugPrint('📥 [$timestamp] Received ${data.length} bytes: $dataHex');
      
      // Handle Python-like response processing
      _handlePythonStyleResponse(data);
      
      // Mark data as needing reprocessing
      _lastProcessedIndex = -1; // Force reprocessing
      
      // Immediately update UI when new data arrives
      notifyListeners();
    });
  }
  
  /// Handle responses in Python-like manner
  void _handlePythonStyleResponse(List<int> data) {
    // Check for complete frame response (55 A9 header)
    if (_waitingForResponse && data.length >= 4 && data[0] == 0x55 && data[1] == 0xA9) {
      final dlc = (data[2] << 8) | data[3] + 1;
      final totalLen = 4 + dlc;
      
      if (data.length >= totalLen) {
        debugPrint('✅ [完整帧接收] ${data.take(totalLen).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        _completeResponse(data.take(totalLen).toList());
        return;
      }
    }
    
    // Enhanced ACK response debugging (55 A9 03 xx format)
    if (data.length >= 4 && data[0] == 0x55 && data[1] == 0xA9 && data[2] == 0x03) {
      debugPrint('🔍 ACK 帧检测: 状态_waitingForAck=$_waitingForAck, 期望索引=$_expectedAckIndex, 收到索引=${data[3]}');
      
      if (_waitingForAck) {
        if (data[3] == _expectedAckIndex) {
          debugPrint('✅ 收到 ACK 应答: 55 A9 03 ${_expectedAckIndex.toRadixString(16).toUpperCase().padLeft(2, '0')}');
          _completeAck(true);
          return;
        } else {
          debugPrint('⚠️ ACK 帧索引不匹配: 期望 ${_expectedAckIndex.toRadixString(16).toUpperCase().padLeft(2, '0')}, 收到 ${data[3].toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      } else {
        debugPrint('⚠️ 收到 ACK 帧，但不在等待状态');
      }
    }
    
    // Check for SFD status response that should update the status display
    // Response pattern: 55 A9 00 07 62 01 74 XX XX XX YY ZZ (YY is minutes from second-to-last byte)
    // Examples: 55 A9 00 07 62 01 74 02 01 01 20 53 (32 minutes)
    //           55 A9 00 07 62 01 74 02 01 01 17 20 (23 minutes)
    if (data.length >= 12 && 
        data[0] == 0x55 && data[1] == 0xA9 && data[2] == 0x00 && data[3] == 0x07 &&
        data[4] == 0x62 && data[5] == 0x01 && data[6] == 0x74) {
      
      // Extract minutes from the second-to-last byte (倒数第二个字节)
      final minutes = data[data.length - 2]; // Always get second-to-last byte
      final allBytes = data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      
      debugPrint('🎯 检测到SFD状态响应，倒数第二字节分钟数: $minutes (0x${minutes.toRadixString(16).padLeft(2, '0')})');
      debugPrint('🔍 完整帧数据: $allBytes');
      
      // Force UI update for SFD status
      notifyListeners();
      return;
    }
    
    // Check for specific routine control response that triggers automatic SFD query
    // Response pattern: 55 A9 00 06 71 01 C0 04 (only check first 8 bytes)
    if (data.length >= 8 && 
        data[0] == 0x55 && data[1] == 0xA9 && data[2] == 0x00 && data[3] == 0x06 &&
        data[4] == 0x71 && data[5] == 0x01 && data[6] == 0xC0 && data[7] == 0x04) {
      
      debugPrint('🎯 检测到特定routine control响应，准备自动发送SFD查询...');
      
      // Schedule automatic SFD query after a short delay to ensure current processing completes
      Future.delayed(const Duration(milliseconds: 30), () async {
        await _sendAutomaticSfdQuery();
      });
    }
  }
  
  /// Complete response waiting
  void _completeResponse(List<int>? response) {
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.complete(response);
    }
    _responseTimer?.cancel();
    _waitingForResponse = false;
  }
  
  /// Complete ACK waiting
  void _completeAck(bool success) {
    debugPrint('🔍 完成 ACK 等待: success=$success, _waitingForAck=$_waitingForAck');
    if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
      _ackCompleter!.complete(success);
    }
    _responseTimer?.cancel();
    _waitingForAck = false;
  }

  /// Automatically send SFD query command after detecting specific routine control response
  Future<void> _sendAutomaticSfdQuery() async {
    try {
      await _ensureConnected();
      
      debugPrint('🚀 自动发送SFD查询命令...');
      
      // SFD query command: AA A6 00 00 03 22 01 74 00
      final sfdQueryFrame = [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x01, 0x74, 0x00];
      
      debugPrint('📤 发送自动SFD查询: ${sfdQueryFrame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
      
      // Send the SFD query frame
      await _bleTransport.sendRawBytes(Uint8List.fromList(sfdQueryFrame));
      
      // Wait for response
      debugPrint('⏳ 等待SFD查询响应...');
      final responseReceived = await _waitForCompleteFrame(5000);
      
      if (responseReceived) {
        debugPrint('✅ 自动SFD查询响应已接收');
        // Update UI to reflect new data
        notifyListeners();
      } else {
        debugPrint('⚠️ 自动SFD查询超时');
      }
      
    } catch (e) {
      debugPrint('❌ 自动SFD查询失败: $e');
    }
  }

  void clearSfdBuffer() {
    _sfdBuffer.clear();
    _formattedLines.clear();
    _lastProcessedIndex = -1;
    notifyListeners();
  }
  
  /// Wait for frame with header (Python: wait_for_frame_with_header)
  Future<List<int>?> _waitForFrameWithHeader({int timeoutMs = responseTimeoutMs}) async {
    if (_waitingForResponse) {
      debugPrint('⚠️ Already waiting for response, cancelling previous wait');
      _completeResponse(null);
    }
    
    _responseCompleter = Completer<List<int>?>();
    _waitingForResponse = true;
    
    // Set timeout
    _responseTimer = Timer(Duration(milliseconds: timeoutMs), () {
      debugPrint('❌ 超时未收到完整帧');
      _completeResponse(null);
    });
    
    return await _responseCompleter!.future;
  }
  
  /// Wait for frame ACK (Python: wait_for_frame_ack)
  Future<bool> _waitForFrameAck(int expectedIndex, {int timeoutMs = responseTimeoutMs}) async {
    if (_waitingForAck) {
      debugPrint('⚠️ Already waiting for ACK, cancelling previous wait');
      _completeAck(false);
    }
    
    _ackCompleter = Completer<bool>();
    _waitingForAck = true;
    _expectedAckIndex = expectedIndex;
    
    debugPrint('🔍 开始等待帧索引 ${expectedIndex.toRadixString(16).toUpperCase().padLeft(2, '0')} 的 ACK（超时: ${timeoutMs}ms）');
    
    // Set timeout
    _responseTimer = Timer(Duration(milliseconds: timeoutMs), () {
      debugPrint('❌ 超时未收到帧索引 ${expectedIndex.toRadixString(16).toUpperCase().padLeft(2, '0')} 的应答');
      _completeAck(false);
    });
    
    return await _ackCompleter!.future;
  }

  /// Send frames with retry (Python: send_frames_with_retry)
  Future<bool> _sendFramesWithRetry(List<List<int>> frames, String description, {bool useAck = false}) async {
    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final frameIndex = i + 1;
      int retryCount = 0;
      
      while (retryCount < maxRetries) {
        // Add delay for better reliability
        await Future.delayed(Duration(milliseconds: 100 + retryCount * 50));
        
        debugPrint('\n📤 发送$description第$frameIndex帧（第${retryCount + 1}次尝试）: ${frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        
        // Setup response waiting BEFORE sending
        dynamic responseFuture;
        if (useAck) {
          responseFuture = _waitForFrameAck(frameIndex);
          // Small delay to ensure ACK waiting state is set before device responds
          await Future.delayed(const Duration(milliseconds: 10));
        } else {
          // For non-ACK frames, use the unified response waiting mechanism
          responseFuture = _waitForFrameWithHeader(timeoutMs: 2000);
        }
        
        try {
          await _bleTransport.sendRawBytes(Uint8List.fromList(frame));
          await Future.delayed(const Duration(milliseconds: 50)); // Small delay after write
        } catch (e) {
          debugPrint('❌ 写入失败: $e');
          // Cancel waiting if send failed
          if (useAck) {
            _completeAck(false);
          } else {
            _completeResponse(null);
          }
          retryCount++;
          continue;
        }
        
        // Wait for response
        final responseResult = await responseFuture;
        bool success = false;
        if (useAck) {
          success = responseResult as bool;
        } else {
          success = (responseResult as List<int>?) != null;
        }
        
        if (success) {
          break;
        }
        
        retryCount++;
        debugPrint('⚠️ 未收到应答，重试中（$retryCount/$maxRetries）');
      }
      
      if (retryCount >= maxRetries) {
        debugPrint('❌ $description第$frameIndex帧连续失败 $maxRetries 次，终止通信');
        return false;
      }
    }
    return true;
  }

  /// Send preset UDS frames (Python: FRAMES)
  Future<bool> sendPresetFrames() async {
    debugPrint('🧪 发送预设UDS帧...');
    
    final presetFrames = [
      [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00, 0x00], // Tester Present
      [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00], // Diagnostic Session Control
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x90, 0x00], // Read Data By Identifier F190
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x8C, 0x00], // Read Data By Identifier F18C
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x01, 0x74, 0x00], // Read Data By Identifier 0174
    ];
    
    final success = await _sendFramesWithRetry(presetFrames, "预设帧", useAck: false);
    if (success) {
      debugPrint('✅ 所有预设帧发送完毕');
    } else {
      debugPrint('❌ 预设帧发送失败');
    }
    
    return success;
  }
  
  /// Send long data with framing (Python: split_into_frames + send with ACK)
  /// This method includes full device configuration before sending data
  Future<bool> sendLongDataWithFraming(String hexString) async {
    try {
      debugPrint('🧪 开始长数据传输流程...');
      
      // Step 1: Execute device configuration sequence (same as SFD Info request)
      debugPrint('🔍 Step 1: 执行设备配置序列...');
      
      // Clear buffer before starting
      _sfdBuffer.clear();
      notifyListeners();
      
      // Configure CAN channel first
      debugPrint('🔍 配置 CAN 通道...');
      final canConfigSuccess = await configureCanChannel();
      if (!canConfigSuccess) {
        throw Exception('CAN 通道配置失败');
      }
      
      // Small delay between configuration commands
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Configure UDS flow control
      debugPrint('🔍 配置 UDS 流控制...');
      final flowControlSuccess = await configureUdsFlowControl();
      if (!flowControlSuccess) {
        throw Exception('UDS 流控制配置失败');
      }
      
      // Allow device to fully initialize after configuration
      debugPrint('⏳ 等待设备初始化 (2 秒)...');
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Step 2: Establish diagnostic session
      debugPrint('🔍 Step 2: 建立诊断会话...');
      
      // First, try to establish communication with extended diagnostic session
      debugPrint('📤 建立诊断会话 (扩展模式)...');
      await enterDiagnosticSession(sessionType: 0x03); // Extended diagnostic session
      
      // Give time for diagnostic session to establish
      debugPrint('⏳ 等待诊断会话响应...');
      bool diagSessionResponse = await _waitForCompleteFrame(5000);
      if (!diagSessionResponse) {
        debugPrint('⚠️ 扩展诊断会话无响应，尝试默认会话...');
        await enterDiagnosticSession(sessionType: 0x01); // Default diagnostic session
        diagSessionResponse = await _waitForCompleteFrame(5000);
      }
      
      if (diagSessionResponse) {
        debugPrint('✅ 诊断会话已建立，继续进行...');
      } else {
        debugPrint('⚠️ 诊断会话无响应，但继续进行...');
      }
      
      // Small delay before next command
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Tester Present to maintain session
      debugPrint('📤 发送 Tester Present...');
      await sendTesterPresent();
      await _waitForCompleteFrame(3000);
      
      // Step 3: First execute complete SFD Info request (same as fetch button)
      debugPrint('🔍 Step 3a: 执行完整的 SFD Info 请求 (Fetch)...');
      
             try {
         // Execute the complete SFD info request sequence (same as fetch button)
         await requestSfdInfo();
         debugPrint('✅ SFD Info 请求完成，响应已显示在接收数据区域');
         
         // Add a visual separator in the received data to distinguish fetch from long data
         final timestamp = DateTime.now().toString().substring(11, 19);
         _formattedLines.add('[$timestamp] ━━━ 开始长数据传输 ━━━');
         notifyListeners();
         
       } catch (e) {
         debugPrint('⚠️ SFD Info 请求失败: $e，但继续长数据传输...');
       }
       
       // Allow time for fetch responses to be displayed and processed
       await Future.delayed(const Duration(milliseconds: 1500));
      
      // Step 3b: Send long data frames  
      debugPrint('🔍 Step 3b: 发送长数据帧...');
      
      // Use 16-byte frame size to match Python script
      final longFrames = FrameCodec.parseHexAndSplitFrames(hexString, framePayloadSize: 16);
      
      debugPrint('📦 准备发送 ${longFrames.length} 个长数据帧');
      
      final success = await _sendFramesWithRetry(longFrames, "长数据帧", useAck: true);
      if (success) {
        debugPrint('🎉 所有长数据帧发送完毕并收到 ACK');
        
        // Step 4: Wait for any final response data
        debugPrint('🔍 Step 4: 等待最终响应数据...');
        final finalResponse = await _waitForCompleteFrame(5000);
        if (finalResponse) {
          debugPrint('✅ 收到最终响应数据');
        } else {
          debugPrint('⚠️ 无最终响应数据');
        }
        
      } else {
        debugPrint('⚠️ 长数据帧传输中断');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ 长数据传输流程失败: $e');
      return false;
    }
  }

  /// Diagnose BLE connection and notification issues
  Future<void> diagnoseBleConnection() async {
    debugPrint('🔍 Starting BLE connection diagnosis...');
    try {
      await _bleTransport.diagnoseBleConnection();
    } catch (e) {
      debugPrint('❌ BLE diagnosis failed: $e');
    }
  }

  Future<void> initEcuList() async {
    try {
      // Try to load from XML with CAN IDs first, fallback to CSV
      try {
        ecuList = await EcuRepository.loadFromXml();
        if (ecuList.isNotEmpty) {
          debugPrint('✅ Loaded ${ecuList.length} ECUs from XML with CAN IDs');
        } else {
          throw Exception('XML list is empty');
        }
      } catch (e) {
        debugPrint('⚠️ XML loading failed, falling back to CSV: $e');
        ecuList = await EcuRepository.load();
        debugPrint('✅ Loaded ${ecuList.length} ECU entries from CSV (without CAN IDs)');
      }
      
      // Debug: Print all ECU names to see what was loaded
      for (final ecu in ecuList) {
        debugPrint('🔍 ECU: ${ecu.name} (node: ${ecu.node}, id: ${ecu.ecuId}, canReq: ${ecu.canPhysReqId?.toRadixString(16) ?? 'N/A'}, canResp: ${ecu.canRespUsdtId?.toRadixString(16) ?? 'N/A'})');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('🔥 Failed to load ECU list: $e');
      ecuList = [];
    }
  }

  void selectEcu(EcuInfo? ecu) {
    selectedEcu = ecu;
    debugPrint('🔍 Selected ECU: ${ecu?.toString() ?? 'None'}');
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _sfdDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected) {
      throw Exception('BLE not connected');
    }
    
    // Double-check with transport
    if (!_bleTransport.isConnected) {
      _isConnected = false;
      notifyListeners();
      throw Exception('BLE link lost');
    }
  }

  // Configuration acknowledgment responses
  static const List<int> _canConfigDoneResponse = [0x55, 0xA9, 0x00, 0x01, 0xFF, 0x00];
  static const List<int> _flowControlDoneResponse = [0x55, 0xA9, 0x00, 0x01, 0xFE, 0x00];

  /// Wait for a specific response frame
  Future<bool> _waitForSpecificResponse(List<int> expectedResponse, int timeoutMs) async {
    final startTime = DateTime.now();
    final timeoutDuration = Duration(milliseconds: timeoutMs);
    final List<int> responseBuffer = [];
    int initialBufferLength = _sfdBuffer.length;
    
    debugPrint('⏳ Waiting for specific response: ${expectedResponse.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
    
    while (DateTime.now().difference(startTime) < timeoutDuration) {
      // Check if new data has arrived
      if (_sfdBuffer.length > initialBufferLength) {
        // Copy new data to response buffer
        responseBuffer.addAll(_sfdBuffer.skip(initialBufferLength));
        initialBufferLength = _sfdBuffer.length;
        
        // Check if we have enough data for the expected response
        if (responseBuffer.length >= expectedResponse.length) {
          // Look for the expected response anywhere in the buffer
          for (int i = 0; i <= responseBuffer.length - expectedResponse.length; i++) {
            bool found = true;
            for (int j = 0; j < expectedResponse.length; j++) {
              if (responseBuffer[i + j] != expectedResponse[j]) {
                found = false;
                break;
              }
            }
            if (found) {
              final responseHex = expectedResponse.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
              debugPrint('✅ Found expected response: $responseHex');
              return true;
            }
          }
          
          // If buffer is getting too long, remove old data
          if (responseBuffer.length > 50) {
            responseBuffer.removeRange(0, responseBuffer.length - 20);
          }
        }
      }
      
      // Small delay before checking again
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    debugPrint('❌ Timeout waiting for specific response');
    return false;
  }

  /// Configure CAN channel settings (0xFF command) with acknowledgment
  Future<bool> configureCanChannel({
    int canChannel = 0,
    int filterCount = 1,
    int baudrate = 500, // 500 kbps
    int? diagCanId,      // Will use selectedEcu's response ID if not provided
    int? diagReqCanId,   // Will use selectedEcu's request ID if not provided
    int? filterMask,     // Will use selectedEcu's appropriate mask if not provided
    int timeoutMs = 5000,
  }) async {
    await _ensureConnected();
    
    // Use selected ECU's CAN IDs if available and not overridden
    int finalDiagCanId = diagCanId ?? selectedEcu?.canRespUsdtId ?? 0x000007FF;
    int finalDiagReqCanId = diagReqCanId ?? selectedEcu?.canPhysReqId ?? 0x00000710;
    int finalFilterMask = filterMask ?? selectedEcu?.filterMask ?? 0xFFFFFFFF;
    
    debugPrint('🔍 Using CAN IDs - Request: 0x${finalDiagReqCanId.toRadixString(16).toUpperCase()}, Response: 0x${finalDiagCanId.toRadixString(16).toUpperCase()}, Mask: 0x${finalFilterMask.toRadixString(16).toUpperCase()}');
    
    final frame = BleCanProtocol.createCanConfigFrame(
      canChannel: canChannel,
      filterCount: filterCount,
      baudrate: baudrate,
      diagCanId: finalDiagCanId,
      diagReqCanId: finalDiagReqCanId,
      filterMask: finalFilterMask,
    );
    
    debugPrint('🔍 Configuring CAN: ${FrameDecoder.formatHexBytes(frame)}');
    
    try {
      // Send the configuration frame
      await _bleTransport.sendRawBytes(Uint8List.fromList(frame));
      debugPrint('✅ CAN config frame sent');
      
      // Wait for acknowledgment
      final success = await _waitForSpecificResponse(_canConfigDoneResponse, timeoutMs);
      if (success) {
        debugPrint('✅ CAN configuration confirmed!');
      } else {
        debugPrint('❌ CAN configuration failed - no acknowledgment received');
      }
      return success;
    } catch (e) {
      debugPrint('❌ CAN configuration error: $e');
      return false;
    }
  }
  
  /// Configure UDS flow control settings (0xFE command) with acknowledgment
  Future<bool> configureUdsFlowControl({
    int udsRequestEnable = 1,
    int replyFlowControl = 1,
    int blockSize = 0x0F,
    int stMin = 0x05,
    int padValue = 0x55,
    int timeoutMs = 5000,
  }) async {
    await _ensureConnected();
    
    final frame = BleCanProtocol.createUdsFlowControlFrame(
      udsRequestEnable: udsRequestEnable,
      replyFlowControl: replyFlowControl,
      blockSize: blockSize,
      stMin: stMin,
      padValue: padValue,
    );
    
    debugPrint('🔍 Configuring UDS Flow Control: ${FrameDecoder.formatHexBytes(frame)}');
    
    try {
      // Send the configuration frame
      await _bleTransport.sendRawBytes(Uint8List.fromList(frame));
      debugPrint('✅ UDS Flow Control frame sent');
      
      // Wait for acknowledgment
      final success = await _waitForSpecificResponse(_flowControlDoneResponse, timeoutMs);
      if (success) {
        debugPrint('✅ UDS Flow Control configuration confirmed!');
      } else {
        debugPrint('❌ UDS Flow Control configuration failed - no acknowledgment received');
      }
      return success;
    } catch (e) {
      debugPrint('❌ UDS Flow Control configuration error: $e');
      return false;
    }
  }
  
  /// Send UDS request with proper protocol formatting
  Future<void> sendUdsRequest(List<int> udsPayload) async {
    await _ensureConnected();
    
    final frame = BleCanProtocol.createUdsPayloadFrame(udsPayload);
    
    debugPrint('🔍 Sending UDS request: ${FrameDecoder.formatHexBytes(frame)}');
    await _bleTransport.sendRawBytes(Uint8List.fromList(frame));
  }
  
  /// Send a Tester Present message to keep the diagnostic session active
  Future<void> sendTesterPresent() async {
    await sendUdsRequest([UdsServiceIds.testerPresent, 0x00]);
  }
  
  /// Read VIN using UDS
  Future<void> readVin() async {
    await sendUdsRequest([
      UdsServiceIds.readDataByIdentifier,
      (UdsDataIdentifiers.vehicleIdentificationNumber >> 8) & 0xFF,
      UdsDataIdentifiers.vehicleIdentificationNumber & 0xFF,
    ]);
  }
  
  /// Enter diagnostic session
  Future<void> enterDiagnosticSession({int sessionType = 0x03}) async {
    await sendUdsRequest([UdsServiceIds.diagnosticSessionControl, sessionType]);
  }

  /// Check if any data is being received from the device
  Future<bool> checkDataReception() async {
    debugPrint('🔍 Checking if device is sending any data...');
    final initialBufferLength = _sfdBuffer.length;
    
    // Wait for a short period to see if any data arrives
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final dataReceived = _sfdBuffer.length > initialBufferLength;
    if (dataReceived) {
      final newDataLength = _sfdBuffer.length - initialBufferLength;
      debugPrint('✅ Received $newDataLength bytes of data');
      final newData = _sfdBuffer.skip(initialBufferLength).take(20).toList(); // Show first 20 bytes
      final dataHex = newData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      debugPrint('📥 Sample data: $dataHex${newDataLength > 20 ? '...' : ''}');
    } else {
      debugPrint('❌ No data received from device');
    }
    
    return dataReceived;
  }

  /// Check if device is properly configured by sending a simple test command
  Future<bool> isDeviceConfigured() async {
    try {
      await _ensureConnected();
      
      // Clear buffer before test
      _sfdBuffer.clear();
      
      // First check if device is sending any data at all
      final dataReception = await checkDataReception();
      if (!dataReception) {
        debugPrint('⚠️ Device is not sending any data - may not be configured');
      }
      
      // Send a simple Tester Present command to check if device responds correctly
      debugPrint('🔍 Testing device configuration with Tester Present...');
      await sendTesterPresent();
      
      // Wait for response
      final responseReceived = await _waitForCompleteFrame(5000);
      
      if (responseReceived) {
        debugPrint('✅ Device appears to be configured correctly');
        return true;
      } else {
        debugPrint('❌ Device may not be configured - no response to test command');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Device configuration test failed: $e');
      return false;
    }
  }

  /// Full device configuration with proper sequence and error handling
  Future<bool> configureDevice({
    int canChannel = 0,
    int filterCount = 1,
    int baudrate = 500,
    int? diagCanId,      // Will use selectedEcu's values if not provided
    int? diagReqCanId,   // Will use selectedEcu's values if not provided
    int? filterMask,     // Will use selectedEcu's values if not provided
    int udsRequestEnable = 1,
    int replyFlowControl = 1,
    int blockSize = 0x0F,
    int stMin = 0x05,
    int padValue = 0x55,
  }) async {
    try {
      debugPrint('🔧 Starting complete device configuration...');
      
      // Check if ECU is selected and has valid CAN IDs
      if (selectedEcu == null) {
        debugPrint('❌ No ECU selected for configuration');
        return false;
      }
      
      if (!selectedEcu!.hasValidCanIds) {
        debugPrint('⚠️ Selected ECU "${selectedEcu!.name}" does not have CAN IDs, using defaults');
      } else {
        debugPrint('✅ Using CAN IDs from selected ECU: "${selectedEcu!.name}"');
      }
      
      // Step 1: Configure CAN channel
      debugPrint('📤 Step 1/2: Configuring CAN channel...');
      final canSuccess = await configureCanChannel(
        canChannel: canChannel,
        filterCount: filterCount,
        baudrate: baudrate,
        diagCanId: diagCanId,      // These will use selectedEcu's IDs if null
        diagReqCanId: diagReqCanId,
        filterMask: filterMask,
      );
      
      if (!canSuccess) {
        debugPrint('❌ CAN configuration failed');
        return false;
      }
      
      // Small delay between configurations
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 2: Configure UDS flow control
      debugPrint('📤 Step 2/2: Configuring UDS flow control...');
      final flowSuccess = await configureUdsFlowControl(
        udsRequestEnable: udsRequestEnable,
        replyFlowControl: replyFlowControl,
        blockSize: blockSize,
        stMin: stMin,
        padValue: padValue,
      );
      
      if (!flowSuccess) {
        debugPrint('❌ UDS flow control configuration failed');
        return false;
      }
      
      // Allow device time to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 3: Verify configuration with test command
      debugPrint('🧪 Verifying device configuration...');
      final isConfigured = await isDeviceConfigured();
      
      if (isConfigured) {
        debugPrint('🎉 Device configuration completed and verified successfully!');
        return true;
      } else {
        debugPrint('❌ Device configuration verification failed');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Device configuration error: $e');
      return false;
    }
  }

  Future<void> requestSfdInfo() async {
    await _ensureConnected();
    
    // Clear buffer before requesting new data
    _sfdBuffer.clear();
    notifyListeners();
    
    // Enhanced protocol-aware frame sequence with proper acknowledgment handling
    try {
      // Step 1: Configure CAN channel first
      debugPrint('🔍 Step 1: Configuring CAN channel...');
      final canConfigSuccess = await configureCanChannel();
      if (!canConfigSuccess) {
        throw Exception('CAN channel configuration failed');
      }
      
      // Small delay between configuration commands
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Step 2: Configure UDS flow control
      debugPrint('🔍 Step 2: Configuring UDS flow control...');
      final flowControlSuccess = await configureUdsFlowControl();
      if (!flowControlSuccess) {
        throw Exception('UDS flow control configuration failed');
      }
      
      // Allow device to fully initialize after configuration
      debugPrint('⏳ Allowing device to initialize (2 seconds)...');
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Step 3: Send UDS diagnostic sequence
      debugPrint('🔍 Step 3: Starting UDS diagnostic sequence...');
      
      // First, try to establish communication with extended diagnostic session
      debugPrint('📤 Establishing diagnostic session (extended)...');
      await enterDiagnosticSession(sessionType: 0x03); // Extended diagnostic session
      
      // Give more time for diagnostic session to establish
      debugPrint('⏳ Waiting for diagnostic session response...');
      bool diagSessionResponse = await _waitForCompleteFrame(5000);
      if (!diagSessionResponse) {
        debugPrint('⚠️ No response to diagnostic session, trying default session...');
        await enterDiagnosticSession(sessionType: 0x01); // Default diagnostic session
        diagSessionResponse = await _waitForCompleteFrame(5000);
      }
      
      if (diagSessionResponse) {
        debugPrint('✅ Diagnostic session established, proceeding with commands...');
      } else {
        debugPrint('⚠️ No diagnostic session response, but continuing...');
      }
      
      // Small delay before next command
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Tester Present
      debugPrint('📤 Sending Tester Present...');
      await sendTesterPresent();
      await _waitForCompleteFrame(5000);
      
      // Read VIN
      debugPrint('📤 Reading VIN...');
      await readVin();
      bool vinResponse = await _waitForCompleteFrame(5000);
      debugPrint(vinResponse ? '✅ VIN response received' : '⚠️ VIN response timeout');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Read vehicle manufacturer serial number
      debugPrint('📤 Reading manufacturer serial number...');
      await sendUdsRequest([
        UdsServiceIds.readDataByIdentifier,
        (UdsDataIdentifiers.vehicleManufacturerSerialNumber >> 8) & 0xFF,
        UdsDataIdentifiers.vehicleManufacturerSerialNumber & 0xFF,
      ]);
      bool serialResponse = await _waitForCompleteFrame(5000);
      debugPrint(serialResponse ? '✅ Serial number response received' : '⚠️ Serial number response timeout');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Read custom data identifier
      debugPrint('📤 Reading custom data identifier (0174)...');
      await sendUdsRequest([UdsServiceIds.readDataByIdentifier, 0x01, 0x74]);
      bool customDataResponse = await _waitForCompleteFrame(5000);
      debugPrint(customDataResponse ? '✅ Custom data response received' : '⚠️ Custom data response timeout');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Routine control
      debugPrint('📤 Executing routine control...');
      await sendUdsRequest([UdsServiceIds.routineControl, 0x01, 0xC0, 0x08, 0x02]);
      bool routineResponse = await _waitForCompleteFrame(5000);
      debugPrint(routineResponse ? '✅ Routine control response received' : '⚠️ Routine control response timeout');
      
      debugPrint('🎉 SFD Info request sequence completed successfully');
      
    } catch (e) {
      debugPrint('🔥 SFD Info request failed: $e');
      debugPrint('🔄 Attempting fallback to legacy communication method...');
      
      try {
        // Try legacy communication as fallback
        await requestSfdInfoLegacy();
        debugPrint('✅ Legacy communication method succeeded');
      } catch (legacyError) {
        debugPrint('❌ Legacy communication also failed: $legacyError');
        rethrow;
      }
    }
  }
  
  /// Legacy method for compatibility with existing code
  Future<void> requestSfdInfoLegacy() async {
    await _ensureConnected();
    
    // Clear buffer before requesting new data
    _sfdBuffer.clear();
    notifyListeners();
    
    // Predefined frames to send (same as Python code)
    final frames = [
      [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00, 0x00],
      [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x90, 0x00],
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x8C, 0x00],
      [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x01, 0x74, 0x00],
      [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x31, 0x01, 0xC0, 0x08, 0x02, 0x00],
    ];
    
    const maxRetries = 3;
    const responseTimeoutMs = 2000;
    
    debugPrint('🔍 Starting SFD fetch sequence with ${frames.length} frames');
    
    try {
      for (int i = 0; i < frames.length; i++) {
        final frameData = Uint8List.fromList(frames[i]);
        int retryCount = 0;
        bool success = false;
        
        while (retryCount < maxRetries && !success) {
          // Small delay before retry (increasing with retry count)
          await Future.delayed(Duration(milliseconds: 50 + retryCount * 10));
          
          debugPrint('📤 Sending frame ${i + 1}/${frames.length} (attempt ${retryCount + 1}/$maxRetries): ${frameData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
          
                     try {
             // Send the frame
             await _bleTransport.sendRawBytes(frameData);
            
            // Wait for response with timeout
            final responseReceived = await _waitForCompleteFrame(responseTimeoutMs);
            
            if (responseReceived) {
              debugPrint('✅ Frame ${i + 1} sent successfully and response received');
              success = true;
            } else {
              debugPrint('⚠️ No complete response received for frame ${i + 1}, retrying (${retryCount + 1}/$maxRetries)');
              retryCount++;
            }
            
          } catch (e) {
            debugPrint('❌ Failed to send frame ${i + 1}: $e');
            retryCount++;
          }
        }
        
        if (!success) {
          debugPrint('❌ Frame ${i + 1} failed after $maxRetries attempts, terminating communication');
          throw Exception('Frame ${i + 1} failed after $maxRetries attempts');
        }
      }
      
      debugPrint('🎉 All frames sent successfully and responses received');
      
    } catch (e) {
      debugPrint('🔥 SFD fetch failed: $e');
      rethrow;
    }
  }

  Future<void> sendSfdData(Uint8List bytes) async {
    await _ensureConnected();
    
    try {
      // Convert input data to UDS command frame format
      final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      
      debugPrint('📤 Preparing to send UDS command: $hexString');
      debugPrint('📤 Original data length: ${bytes.length} bytes');
      
      // Create UDS command frame: AA A6 00 00 [length] [UDS_data] 00
      final udsFrame = FrameCodec.createUdsCommandFrame(bytes.toList());
      
      // Use Python-style frame sending with retry
      final success = await _sendFramesWithRetry([udsFrame], "UDS命令", useAck: false);
      
      if (success) {
        debugPrint('✅ UDS command sent and response received');
        notifyListeners(); // Ensure UI updates
      } else {
        debugPrint('❌ UDS command failed after retries');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to send UDS command: $e');
      rethrow;
    }
  }

  /// Send raw SFD data without framing (original method)
  Future<void> sendRawSfdData(Uint8List bytes) async {
    await _ensureConnected();
    
    // Get or negotiate MTU
    if (_negotiatedMtu == null && _bleTransport.getConnectedDevice() != null) {
      try {
        // Try to request larger MTU
        final device = _bleTransport.getConnectedDevice()!;
        _negotiatedMtu = await device.requestMtu(247);
        debugPrint('🔍 MTU negotiated: $_negotiatedMtu');
      } catch (e) {
        debugPrint('🔍 MTU negotiation failed, using default: $e');
        _negotiatedMtu = 23; // Default BLE MTU
      }
    }
    
    final mtu = _negotiatedMtu ?? 23;
    final chunkSize = mtu - 3; // Reserve 3 bytes for BLE overhead
    
    debugPrint('📤 Sending ${bytes.length} bytes as raw data in chunks of $chunkSize');
    
    // Send data in chunks
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      // Re-check connection before each chunk
      await _ensureConnected();
      
      final end = min(offset + chunkSize, bytes.length);
      final chunk = bytes.sublist(offset, end);
      
      // Send raw bytes directly
      await _bleTransport.sendRawBytes(chunk);
      
      // Small delay between chunks to avoid overwhelming the device
      if (offset + chunkSize < bytes.length) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
    
    debugPrint('📤 Raw data sent successfully');
    
    // Wait for response with timeout
    debugPrint('⏳ Waiting for device response...');
    final responseReceived = await _waitForCompleteFrame(3000); // 3 second timeout
    
    if (responseReceived) {
      debugPrint('✅ Response received and displayed in UI');
      notifyListeners(); // Ensure UI updates
    } else {
      debugPrint('⚠️ No response received within 3 seconds');
    }
  }

  /// Send large data using frame splitting (for big file transfers)
  Future<void> sendLargeDataFramed(Uint8List bytes) async {
    await _ensureConnected();
    
    try {
      // Convert bytes to hex string for processing
      final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join('');
      
      // Use Python-style long data framing and sending
      final success = await sendLongDataWithFraming(hexString);
      
      if (success) {
        debugPrint('✅ Large data framing completed successfully');
        notifyListeners(); // Ensure UI updates
      } else {
        debugPrint('❌ Large data framing failed');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to send framed data: $e');
      rethrow;
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      debugPrint('🔍 BluetoothViewModel.connect() starting for ${device.remoteId}');
      
      // Disconnect any existing connection first
      if (_isConnected) {
        debugPrint('🔍 Disconnecting existing connection first');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 200)); // Brief delay
      }
      
      // Connect via transport
      final success = await _bleTransport.connect(device);
      
      if (success) {
        debugPrint('🔍 Connection successful, waiting for state to stabilize');
        // Give the connection time to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Update our local state
        _isConnected = true;
        
        notifyListeners();
      }
      
      return success;
    } catch (e, stack) {
      debugPrint('🔥 BluetoothViewModel.connect() error: $e');
      debugPrint('🔥 Stack: $stack');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      debugPrint('🔍 BluetoothViewModel.disconnect() called');
      await _bleTransport.disconnect();
      _isConnected = false;
      _sfdBuffer.clear();
      _negotiatedMtu = null;
      selectedEcu = null;
      // Don't clear ecuList - keep it available
      notifyListeners();
    } catch (e) {
      debugPrint('🔥 Error during disconnect: $e');
    }
  }

  /// Wait for a complete frame with 0x55A9 header (matching Python logic)
  Future<bool> _waitForCompleteFrame(int timeoutMs) async {
    final List<int> buffer = [];
    final double timeoutSec = timeoutMs / 1000.0;
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    final int deadline = startTime + timeoutMs;
    int initialBufferLength = _sfdBuffer.length;
    
    debugPrint('⏳ Waiting for response frame (timeout: ${timeoutMs}ms)...');
    
    while (true) {
      final int remaining = deadline - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) {
        debugPrint('❌ 超时未收到完整帧');
        return false;
      }
      
      // Check if new data has arrived in _sfdBuffer
      if (_sfdBuffer.length > initialBufferLength) {
        final newData = _sfdBuffer.skip(initialBufferLength).toList();
        buffer.addAll(newData);
        initialBufferLength = _sfdBuffer.length;
        
        final newDataHex = newData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        debugPrint('📥 New data received: $newDataHex');
      }
      
      // Process buffer to find complete frames (same logic as Python)
      while (buffer.length >= 4) {
        // Remove bytes until we find frame header 0x55A9
        if (buffer[0] != 0x55 || buffer[1] != 0xA9) {
          final removedByte = buffer.removeAt(0);
            debugPrint('🗑️ Discarding byte: 0x${removedByte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
            continue;
          }
          
          // Calculate frame length (big-endian DLC)
        final dlc = (buffer[2] << 8) | buffer[3] + 1;
        final totalLen = 4 + dlc;
        
        debugPrint('📊 Frame analysis: DLC=$dlc, total_length=$totalLen, buffer_length=${buffer.length}');
        
        if (buffer.length >= totalLen) {
          // Complete frame found
          final frame = buffer.take(totalLen).toList();
          final frameHex = frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          debugPrint('✅ [完整帧接收] $frameHex');
          return true;
        } else {
          // Incomplete frame, need more data
          break;
        }
      }
      
      // Small delay before checking again (equivalent to Python's asyncio wait)
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// SFD activation state parsed from received data
  Map<String, dynamic> get sfdActivationState {
    final data = sfdReceivedData;
    if (data.isEmpty) {
      return {'isActive': false, 'minutes': 0};
    }
    
    // Look for SFD response pattern: 62 01 74 followed by 4 bytes
    final lines = data.split('\n');
    for (final line in lines) {
      // Remove timestamp and extract hex data
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (hexData.contains('62 01 74')) {
        // Find the exact position of 62 01 74 and get the following 4 bytes
        final cleanHex = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f\s]'), ' ');
        final bytes = cleanHex.split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty && s.length == 2)
            .map((s) => int.tryParse(s, radix: 16))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        
        // Look for the pattern 62 01 74 in the bytes
        for (int i = 0; i <= bytes.length - 7; i++) {
          if (bytes[i] == 0x62 && bytes[i + 1] == 0x01 && bytes[i + 2] == 0x74) {
            // Found the pattern, check if we have a complete SFD response frame
            // For the specific frame format: 62 01 74 XX XX XX YY (where YY is minutes)
            // We need to find the second-to-last byte in the complete line
            
            // Parse the complete hex line to find the frame boundaries
            final allHexBytes = hexData.split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty && s.length == 2)
                .map((s) => int.tryParse(s, radix: 16))
                .where((i) => i != null)
                .cast<int>()
                .toList();
            
            // For SFD status frames, extract minutes from second-to-last byte of the complete frame
            if (allHexBytes.length >= 8) { // Ensure we have enough bytes
              final minutes = allHexBytes[allHexBytes.length - 2]; // Second-to-last byte
              
              debugPrint('🔍 SFD 状态解析: 帧长度=${allHexBytes.length}, 倒数第二字节分钟数=$minutes (0x${minutes.toRadixString(16).padLeft(2, '0')})');
              
              // Check for inactive pattern: if the status bytes indicate inactive state
              // For now, use a simple heuristic: if minutes > 0, consider it active
              if (minutes > 0) {
                return {'isActive': true, 'minutes': minutes};
              } else {
                return {'isActive': false, 'minutes': 0};
              }
            }
            
            // Fallback to original logic for compatibility
            if (i + 6 < bytes.length) {
              final byte1 = bytes[i + 3];
              final byte2 = bytes[i + 4];
              final byte3 = bytes[i + 5];
              final byte4 = bytes[i + 6];
              
              debugPrint('🔍 SFD 状态字节 (fallback): ${byte1.toRadixString(16).padLeft(2, '0')} ${byte2.toRadixString(16).padLeft(2, '0')} ${byte3.toRadixString(16).padLeft(2, '0')} ${byte4.toRadixString(16).padLeft(2, '0')}');
              
              // Check if SFD is active
              // Pattern: 00 00 01 00 = not active
              // Pattern: XX XX XX YY = active, YY is remaining minutes in hex
              if (byte1 == 0x00 && byte2 == 0x00 && byte3 == 0x01 && byte4 == 0x00) {
                return {'isActive': false, 'minutes': 0};
              } else {
                // SFD is active, last byte is remaining minutes
                return {'isActive': true, 'minutes': byte4};
              }
            }
          }
        }
      }
    }
    
    return {'isActive': false, 'minutes': 0};
  }

  /// Extract specific frame data starting from 6th byte for copy functionality
  /// Looks for frames with header pattern: 71 01 C0 08 24
  String getSpecificFrameDataForCopy() {
    final data = sfdReceivedData;
    if (data.isEmpty) {
      return '';
    }
    
    debugPrint('🔍 查找帧头 71 01 C0 08 24 用于复制...');
    
    final lines = data.split('\n');
    for (final line in lines) {
      // Remove timestamp and extract hex data
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      
      // Look for the specific frame header pattern: 71 01 C0 08 24 (case insensitive)
      if (hexData.toUpperCase().contains('71 01 C0 08 24')) {
        debugPrint('✅ 找到目标帧: $hexData');
        
        // Extract all hex bytes from the line
        final cleanHex = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f\s]'), ' ');
        final hexBytes = cleanHex.split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty && s.length == 2)
            .toList();
        
        // Look for the pattern 71 01 C0 08 24 in the hex bytes
        for (int i = 0; i <= hexBytes.length - 5; i++) {
          if (hexBytes[i].toUpperCase() == '71' && 
              hexBytes[i + 1].toUpperCase() == '01' && 
              hexBytes[i + 2].toUpperCase() == 'C0' && 
              hexBytes[i + 3].toUpperCase() == '08' && 
              hexBytes[i + 4].toUpperCase() == '24') {
            
            // Found the pattern, extract data starting from the 6th byte (index i + 5)
            if (i + 5 < hexBytes.length) {
              final dataFromSixthByte = hexBytes.skip(i + 5).toList();
              final result = dataFromSixthByte.join(' ').toUpperCase();
              
              debugPrint('📋 复制数据（从第6个字节开始）: $result');
              return result;
            }
          }
        }
      }
    }
    
    debugPrint('⚠️ 未找到带有帧头 71 01 C0 08 24 的帧');
    return '';
  }

  // ==================== MAINTENANCE RESET METHODS ====================

  /// Close Diagnostic Firewall
  /// Protocol: Gateway 19 -> Check status -> Close if needed -> Recheck status
  Future<void> closeDiagnosticFirewall() async {
    await _ensureConnected();
    debugPrint('🔧 关闭诊断防火墙流程开始...');
    
    try {
      // Step 1: Send gateway command (Gateway 19)
      await _sendGatewayCommand(0x19);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Query firewall status
      await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x03, 0x1D, 0x00]);
      
      // Wait for response and check status
      final responseReceived = await _waitForCompleteFrame(5000);
      if (responseReceived) {
        final firewallStatus = diagnosticFirewallStatus;
        final statusStr = firewallStatus['status'];
        
        if (statusStr == 'no_action_needed') {
          debugPrint('✅ 检测到无需处理响应，防火墙操作完成');
        } else {
          final status = _checkFirewallStatus();
          if (status == 0x01) {
            debugPrint('🔧 防火墙已开启，正在关闭...');
            
            // Step 4: Close firewall
            await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x04, 0x2E, 0x03, 0x1D, 0x00]);
            await _waitForCompleteFrame(3000);
            
            // Step 5: Recheck status
            await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x03, 0x1D, 0x00]);
            await _waitForCompleteFrame(3000);
            
            debugPrint('✅ 防火墙关闭流程完成');
          } else {
            debugPrint('✅ 防火墙已经关闭');
          }
        }
      }
      
      // Notify listeners so UI can update
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ 关闭诊断防火墙失败: $e');
      rethrow;
    }
  }

  /// Query diagnostic firewall status only
  Future<void> queryFirewallStatus() async {
    await _ensureConnected();
    debugPrint('🔧 查询诊断防火墙状态...');
    
    try {
      // Step 1: Send gateway command (Gateway 19)
      await _sendGatewayCommand(0x19);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Query firewall status
      await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x03, 0x1D, 0x00]);
      
      // Wait for response
      final responseReceived = await _waitForCompleteFrame(5000);
      if (responseReceived) {
        final firewallStatus = diagnosticFirewallStatus;
        final statusStr = firewallStatus['status'];
        
        switch (statusStr) {
          case 'open':
            debugPrint('🔧 防火墙状态: 开启');
            break;
          case 'closed':
            debugPrint('✅ 防火墙状态: 关闭');
            break;
          case 'no_action_needed':
            debugPrint('ℹ️ 防火墙状态: 无需处理');
            break;
          default:
            debugPrint('❓ 防火墙状态: 未知');
            break;
        }
        
        // Notify listeners so UI can update
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('❌ 查询防火墙状态失败: $e');
      rethrow;
    }
  }

  /// Reset Kombi 17 (Dashboard Module)
  Future<void> resetKombi17() async {
    await _ensureConnected();
    debugPrint('🔧 仪表模块复位流程开始...');
    
    try {
      // Step 1: Send gateway command (Kombi 17)
      await _sendGatewayCommand(0x17);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Execute Kombi reset sequence
      final resetCommands = [
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x22, 0xA6, 0x00, 0x00, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x22, 0xA7, 0x00, 0x00, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x06, 0x2E, 0x22, 0xA4, 0x00, 0x3A, 0x98, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x22, 0xA5, 0x01, 0x6D, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x04, 0x14, 0xFF, 0xFF, 0xFF, 0x00],
      ];
      
      for (int i = 0; i < resetCommands.length; i++) {
        debugPrint('🔧 发送 Kombi 命令 ${i + 1}/${resetCommands.length}');
        await _sendRawCommand(resetCommands[i]);
        
        // Wait for response and check for completion
        final responseReceived = await _waitForCompleteFrame(3000);
        if (i == resetCommands.length - 1) {
          // Check for completion response on last command
          if (responseReceived && _isCompletionResponse()) {
            debugPrint('✅ Kombi 17 复位完成');
            break;
          }
        } else {
          // Check for expected response on intermediate commands
          if (!responseReceived || !_isExpectedResponse()) {
            debugPrint('⚠️ 命令 ${i + 1} 响应异常，但继续执行');
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ 仪表模块复位失败: $e');
      rethrow;
    }
  }

  /// Reset Headunit 5F (Audio System)
  Future<void> resetHeadunit5F() async {
    await _ensureConnected();
    debugPrint('🔧 音响主机复位流程开始...');
    
    try {
      // Step 1: Send gateway command (Headunit 5F)
      await _sendGatewayCommand(0x5F);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Execute Headunit reset sequence
      final resetCommands = [
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x44, 0x27, 0x10, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x45, 0x01, 0x6D, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x46, 0x27, 0x01, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x47, 0x01, 0x6D, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x48, 0x00, 0x00, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x04, 0x2E, 0x05, 0x49, 0x00, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x05, 0x2E, 0x05, 0x49, 0x00, 0x00, 0x00],
        [0xAA, 0xA6, 0x00, 0x00, 0x04, 0x14, 0xFF, 0xFF, 0xFF, 0x00],
      ];
      
      for (int i = 0; i < resetCommands.length; i++) {
        debugPrint('🔧 发送 Headunit 命令 ${i + 1}/${resetCommands.length}');
        await _sendRawCommand(resetCommands[i]);
        
        // Wait for response and check for completion
        final responseReceived = await _waitForCompleteFrame(3000);
        if (i == resetCommands.length - 1) {
          // Check for completion response on last command
          if (responseReceived && _isCompletionResponse()) {
            debugPrint('✅ Headunit 5F 复位完成');
            break;
          }
        } else {
          // Check for expected response on intermediate commands
          if (!responseReceived || !_isExpectedResponse()) {
            debugPrint('⚠️ 命令 ${i + 1} 响应异常，但继续执行');
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ 音响主机复位失败: $e');
      rethrow;
    }
  }

  /// Close Transport Mode
  Future<void> closeTransportMode() async {
    await _ensureConnected();
    debugPrint('🔧 解除运输模式流程开始...');
    
    try {
      // Step 1: Send gateway command (Gateway 19)
      await _sendGatewayCommand(0x19);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Send deactivation command directly
      debugPrint('🔧 发送解除运输模式命令...');
      await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x04, 0x2E, 0x04, 0xFF, 0x00, 0x00]);
      
      // Wait for deactivation response
      final deactivationReceived = await _waitForCompleteFrame(5000);
      if (deactivationReceived) {
        // Check for success response: 55 A9 00 03 6E 04 FF 00
        if (_isTransportModeCloseSuccess()) {
          debugPrint('✅ 运输模式解除成功');
        } else {
          debugPrint('❌ 运输模式解除失败');
          throw Exception('需要先SFD激活，再执行解除运输模式');
        }
      } else {
        debugPrint('❌ 运输模式解除无响应');
        throw Exception('需要先SFD激活，再执行解除运输模式');
      }
      
      // Notify listeners so UI can update
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ 解除运输模式失败: $e');
      rethrow;
    }
  }

  /// Query transport mode status only
  Future<void> queryTransportModeStatus() async {
    await _ensureConnected();
    debugPrint('🔧 查询运输模式状态...');
    
    try {
      // Step 1: Send gateway command (Gateway 19)
      await _sendGatewayCommand(0x19);
      
      // Step 2: Session control
      await _sendCommandWithResponse(
        [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00],
        [0x55, 0xA9, 0x00, 0x02, 0x50, 0x03],
        '会话控制'
      );
      
      // Step 3: Query transport mode status
      await _sendRawCommand([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x04, 0xFF, 0x00]);
      
      // Wait for response
      final responseReceived = await _waitForCompleteFrame(5000);
      if (responseReceived) {
        final transportStatus = _checkTransportModeStatus();
        
        switch (transportStatus) {
          case 0x00:
            debugPrint('✅ 运输模式状态: 未激活');
            break;
          case 0x01:
            debugPrint('🔧 运输模式状态: 已激活');
            break;
          default:
            debugPrint('❓ 运输模式状态: 未知');
            break;
        }
        
        // Notify listeners so UI can update
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('❌ 查询运输模式状态失败: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Send gateway command with correct formatting for each maintenance reset function
  Future<void> _sendGatewayCommand(int targetId) async {
    List<int> gatewayCmd;
    
    // Use correct frame for each target
    switch (targetId) {
      case 0x19: // Gateway (防火墙/运输模式)
        gatewayCmd = [
          0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07,
          0x10, 0x00, 0x00, 0x07, 0x7A, 0x00, 0x00, 0x07, 0xFF, 0xFF
        ];
        break;
      case 0x17: // Kombi (仪表)
        gatewayCmd = [
          0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07,
          0x14, 0x00, 0x00, 0x07, 0x7E, 0x00, 0x00, 0x07, 0xFF, 0xFF
        ];
        break;
      case 0x5F: // Headunit (音响)
        gatewayCmd = [
          0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07,
          0x73, 0x00, 0x00, 0x07, 0xDD, 0x00, 0x00, 0x07, 0xFF, 0xFF
        ];
        break;
      default:
        debugPrint('⚠️ 未知的目标ID: 0x${targetId.toRadixString(16)}，使用默认Gateway帧');
        gatewayCmd = [
          0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07,
          0x10, 0x00, 0x00, 0x07, 0x7A, 0x00, 0x00, 0x07, 0xFF, 0xFF
        ];
        break;
    }
    
    debugPrint('🔧 发送网关命令到 0x${targetId.toRadixString(16).padLeft(2, '0')}');
    await _sendRawCommand(gatewayCmd);
    await _waitForCompleteFrame(3000);
  }

  /// Send command and wait for specific response
  Future<void> _sendCommandWithResponse(List<int> command, List<int> expectedResponse, String description) async {
    debugPrint('🔧 发送$description命令');
    await _sendRawCommand(command);
    
    final responseReceived = await _waitForCompleteFrame(3000);
    if (responseReceived) {
      final gotExpectedResponse = await _waitForSpecificResponse(expectedResponse, 1000);
      if (gotExpectedResponse) {
        debugPrint('✅ $description响应正确');
      } else {
        debugPrint('⚠️ $description响应异常');
      }
    }
  }

  /// Send raw command
  Future<void> _sendRawCommand(List<int> command) async {
    final frameData = Uint8List.fromList(command);
    await _bleTransport.sendRawBytes(frameData);
  }

  /// Check diagnostic firewall status from response
  int _checkFirewallStatus() {
    final data = sfdReceivedData;
    if (data.isEmpty) return 0xFF; // Unknown status
    
    // Look for response pattern: 55 A9 00 04 62 02 1D XX 00
    final lines = data.split('\n');
    for (final line in lines) {
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (hexData.toUpperCase().contains('62 02 1D')) {
        final bytes = hexData.split(RegExp(r'\s+'))
            .where((s) => s.length == 2)
            .map((s) => int.tryParse(s, radix: 16))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        
        for (int i = 0; i < bytes.length - 3; i++) {
          if (bytes[i] == 0x62 && bytes[i + 1] == 0x02 && bytes[i + 2] == 0x1D) {
            return bytes[i + 3]; // Return the status byte
          }
        }
      }
    }
    return 0xFF; // Unknown status
  }

  /// Check if response indicates completion
  bool _isCompletionResponse() {
    final data = sfdReceivedData;
    // Look for completion response: 55 A9 00 01 54 00 or 55 A9 00 03 7F 14 XX 00
    return data.toUpperCase().contains('55 A9 00 01 54 00') || 
           data.toUpperCase().contains('7F 14');
  }

  /// Check if response is expected
  bool _isExpectedResponse() {
    final data = sfdReceivedData;
    // Look for expected response patterns like 6E XX XX 00 or 7F 2E XX 00
    return data.toUpperCase().contains('6E') || data.toUpperCase().contains('7F 2E');
  }

  /// Check if transport mode close was successful
  bool _isTransportModeCloseSuccess() {
    final data = sfdReceivedData;
    // Look for success response: 55 A9 00 03 6E 04 FF 00
    return data.toUpperCase().contains('6E 04 FF');
  }

  /// Check transport mode status from response
  int _checkTransportModeStatus() {
    final data = sfdReceivedData;
    if (data.isEmpty) return 0xFF; // Unknown status
    
    // Look for response pattern: 55 A9 00 04 62 04 FF XX 00
    // Where XX is: 00 = not activated, any other value = activated
    final lines = data.split('\n');
    for (final line in lines) {
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (hexData.toUpperCase().contains('62 04 FF')) {
        final bytes = hexData.split(RegExp(r'\s+'))
            .where((s) => s.length == 2)
            .map((s) => int.tryParse(s, radix: 16))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        
        for (int i = 0; i < bytes.length - 4; i++) {
          if (bytes[i] == 0x62 && bytes[i + 1] == 0x04 && bytes[i + 2] == 0xFF) {
            final statusByte = bytes[i + 3];
            debugPrint('🔍 运输模式状态字节: 0x${statusByte.toRadixString(16).padLeft(2, '0')}');
            
            // Return normalized status: 0x00 = not activated, 0x01 = activated (any non-zero value)
            return statusByte == 0x00 ? 0x00 : 0x01;
          }
        }
      }
    }
    return 0xFF; // Unknown status
  }

  /// Diagnostic firewall status parsed from received data
  Map<String, dynamic> get diagnosticFirewallStatus {
    final data = sfdReceivedData;
    if (data.isEmpty) {
      return {'status': 'unknown', 'isOpen': false};
    }
    
    final lines = data.split('\n');
    for (final line in lines) {
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      
      // Check for "no action needed" response pattern: 7F 22 ...
      if (hexData.toUpperCase().contains('7F 22')) {
        debugPrint('🔍 检测到 7F 22 响应 - 无需处理');
        return {'status': 'no_action_needed', 'isOpen': false};
      }
      
      // Look for diagnostic firewall response pattern: 62 02 1D XX
      if (hexData.toUpperCase().contains('62 02 1D')) {
        final bytes = hexData.split(RegExp(r'\s+'))
            .where((s) => s.length == 2)
            .map((s) => int.tryParse(s, radix: 16))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        
        // Look for the pattern 62 02 1D in the bytes
        for (int i = 0; i < bytes.length - 3; i++) {
          if (bytes[i] == 0x62 && bytes[i + 1] == 0x02 && bytes[i + 2] == 0x1D) {
            final statusByte = bytes[i + 3];
            debugPrint('🔍 诊断防火墙状态字节: 0x${statusByte.toRadixString(16).padLeft(2, '0')}');
            
            if (statusByte == 0x00) {
              return {'status': 'closed', 'isOpen': false};
            } else if (statusByte == 0x01) {
              return {'status': 'open', 'isOpen': true};
            } else {
              return {'status': 'unknown', 'isOpen': false};
            }
          }
        }
      }
    }
    
    return {'status': 'unknown', 'isOpen': false};
  }

  /// Transport mode status parsed from received data
  Map<String, dynamic> get transportModeStatus {
    final data = sfdReceivedData;
    if (data.isEmpty) {
      return {'status': 'unknown', 'isActivated': false};
    }
    
    final lines = data.split('\n');
    for (final line in lines) {
      final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      
      // Look for transport mode response pattern: 62 04 FF XX
      if (hexData.toUpperCase().contains('62 04 FF')) {
        final bytes = hexData.split(RegExp(r'\s+'))
            .where((s) => s.length == 2)
            .map((s) => int.tryParse(s, radix: 16))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        
        // Look for the pattern 62 04 FF in the bytes
        for (int i = 0; i < bytes.length - 3; i++) {
          if (bytes[i] == 0x62 && bytes[i + 1] == 0x04 && bytes[i + 2] == 0xFF) {
            final statusByte = bytes[i + 3];
            debugPrint('🔍 运输模式状态字节: 0x${statusByte.toRadixString(16).padLeft(2, '0')}');
            
            if (statusByte == 0x00) {
              return {'status': 'not_activated', 'isActivated': false};
            } else if (statusByte == 0x01) {
              return {'status': 'activated', 'isActivated': true};
            } else {
              return {'status': 'unknown', 'isActivated': false};
            }
          }
        }
      }
    }
    
    return {'status': 'unknown', 'isActivated': false};
  }

  // ==================== DIAGNOSIS METHODS ====================

  /// Predefined diagnosis frames based on Python script
  static const List<List<int>> _diagnosisFrames = [
    [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00], // Extended diagnostic session
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x87, 0x00], // Read VIN
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x89, 0x00], // Read vehicle info
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x8C, 0x00], // Read serial number
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x90, 0x00], // Read VIN extended
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x91, 0x00], // Read calibration ID
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x97, 0x00], // Read system name
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x9E, 0x00], // Read development data
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0xA0, 0x00], // Read active diagnostic info
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0xA1, 0x00], // Read VW system name
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0xA2, 0x00], // Read Audi system name
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0xA3, 0x00], // Read seat system name
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0xAA, 0x00], // Read system supplier
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x19, 0x02, 0x04, 0x00], // Read DTC by status 04
    [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x19, 0x02, 0x08, 0x00], // Read DTC by status 08
  ];

  /// Run complete diagnosis process
  Future<String> runDiagnosis() async {
    await _ensureConnected();
    debugPrint('🔧 开始诊断流程...');
    
    final StringBuffer diagnosisResults = StringBuffer();
    
    try {
      // Clear previous data
      _sfdBuffer.clear();
      notifyListeners();
      
      diagnosisResults.writeln('=== DIAGNOSIS STARTED ===');
      diagnosisResults.writeln('Time: ${DateTime.now().toString().substring(0, 19)}');
      diagnosisResults.writeln('');
      
      // Send all diagnosis frames directly (like Python script)
      debugPrint('🔍 Sending ${_diagnosisFrames.length} diagnosis frames...');
      
      for (int i = 0; i < _diagnosisFrames.length; i++) {
        final frame = _diagnosisFrames[i];
        final frameDescription = _getDiagnosisFrameDescription(i);
        
        debugPrint('📤 发送预设帧第${i + 1}帧（第1次尝试）: ${frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        diagnosisResults.writeln('📤 Frame ${i + 1}: $frameDescription');
        diagnosisResults.writeln('Send: ${frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        
        try {
          // Get current buffer length BEFORE sending (critical for timing)
          final bufferLengthBeforeSend = _sfdBuffer.length;
          
          // Send frame directly
          await _bleTransport.sendRawBytes(Uint8List.fromList(frame));
          await Future.delayed(const Duration(milliseconds: 50)); // Small delay after write
          
          // Wait for response using the pre-send buffer length
          final responseReceived = await _waitForCompleteFrameFromPosition(bufferLengthBeforeSend, 2000);
          
          if (responseReceived) {
            // Extract the latest complete frame
            final responseData = _extractLatestCompleteFrame();
            diagnosisResults.writeln('✅ Response: $responseData');
            debugPrint('✅ [完整帧接收] $responseData');
          } else {
            diagnosisResults.writeln('❌ No response received');
            debugPrint('❌ 超时未收到完整帧');
          }
          
        } catch (e) {
          diagnosisResults.writeln('❌ Error: $e');
          debugPrint('❌ 发送帧失败: $e');
        }
        
        diagnosisResults.writeln('');
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay between frames
      }
      
      debugPrint('🎉 所有预设帧发送完毕');
      diagnosisResults.writeln('=== DIAGNOSIS COMPLETED ===');
      
      return diagnosisResults.toString();
      
    } catch (e) {
      final errorMsg = '🔥 Diagnosis failed: $e';
      debugPrint(errorMsg);
      diagnosisResults.writeln(errorMsg);
      return diagnosisResults.toString();
    }
  }

  /// Wait for complete frame starting from a specific buffer position (like Python queue)
  Future<bool> _waitForCompleteFrameFromPosition(int startPosition, int timeoutMs) async {
    final List<int> localBuffer = [];
    final int deadline = DateTime.now().millisecondsSinceEpoch + timeoutMs;
    int currentPosition = startPosition;
    
    debugPrint('⏳ Waiting for response frame from position $startPosition (timeout: ${timeoutMs}ms)...');
    
    while (DateTime.now().millisecondsSinceEpoch < deadline) {
      // Check if new data has arrived since our start position
      if (_sfdBuffer.length > currentPosition) {
        final newData = _sfdBuffer.skip(currentPosition).toList();
        localBuffer.addAll(newData);
        currentPosition = _sfdBuffer.length;
        
        final newDataHex = newData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        debugPrint('📥 New data received: $newDataHex');
        
        // Process the local buffer (Python-style)
        while (localBuffer.length >= 4) {
          // Remove bytes until we find frame header 0x55A9
          if (localBuffer[0] != 0x55 || localBuffer[1] != 0xA9) {
            final removedByte = localBuffer.removeAt(0);
            debugPrint('🗑️ Discarding byte: 0x${removedByte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
            continue;
          }
          
          // Calculate frame length (big-endian DLC)
          final dlc = (localBuffer[2] << 8) | localBuffer[3] + 1;
          final totalLen = 4 + dlc;
          
          debugPrint('📊 Frame analysis: DLC=$dlc, total_length=$totalLen, buffer_length=${localBuffer.length}');
          
          if (localBuffer.length >= totalLen) {
            // Complete frame found
            final frame = localBuffer.take(totalLen).toList();
            final frameHex = frame.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
            debugPrint('✅ [完整帧接收] $frameHex');
            return true;
          } else {
            // Need more data, break and wait
            break;
          }
        }
      }
      
      // Small delay before checking again (like Python asyncio)
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    debugPrint('❌ 超时未收到完整帧');
    return false;
  }

  /// Get description for diagnosis frame
  String _getDiagnosisFrameDescription(int frameIndex) {
    switch (frameIndex) {
      case 0: return 'Extended Diagnostic Session (10 03)';
      case 1: return 'Read VIN (22 F1 87)';
      case 2: return 'Read Vehicle Info (22 F1 89)';
      case 3: return 'Read Serial Number (22 F1 8C)';
      case 4: return 'Read VIN Extended (22 F1 90)';
      case 5: return 'Read Calibration ID (22 F1 91)';
      case 6: return 'Read System Name (22 F1 97)';
      case 7: return 'Read Development Data (22 F1 9E)';
      case 8: return 'Read Active Diagnostic Info (22 F1 A0)';
      case 9: return 'Read VW System Name (22 F1 A1)';
      case 10: return 'Read Audi System Name (22 F1 A2)';
      case 11: return 'Read Seat System Name (22 F1 A3)';
      case 12: return 'Read System Supplier (22 F1 AA)';
      case 13: return 'Read DTC by Status 04 (19 02 04)';
      case 14: return 'Read DTC by Status 08 (19 02 08)';
      default: return 'Unknown Frame';
    }
  }

  /// Extract latest response from buffer
  String _extractLatestResponse() {
    if (_sfdBuffer.isEmpty) return '';
    
    // Get the last few received bytes and format them
    final latestData = _sfdBuffer.length > 50 
        ? _sfdBuffer.skip(_sfdBuffer.length - 50).toList()
        : _sfdBuffer;
    
    if (latestData.isEmpty) return '';
    
    // Look for complete frames in the latest data
    final hexData = latestData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    
    // Try to find and extract meaningful response frames
    final lines = hexData.split(' ');
    final responseFrames = <String>[];
    
    // Look for 55 A9 headers (response frames)
    for (int i = 0; i < lines.length - 3; i++) {
      if (lines[i] == '55' && lines[i + 1] == 'A9') {
        // Found a response frame header
        final dlcHigh = int.tryParse(lines[i + 2], radix: 16) ?? 0;
        final dlcLow = int.tryParse(lines[i + 3], radix: 16) ?? 0;
        final dlc = (dlcHigh << 8) | dlcLow + 1;
        final totalLen = 4 + dlc;
        
        if (i + totalLen <= lines.length) {
          final frameData = lines.skip(i).take(totalLen).join(' ');
          responseFrames.add(frameData);
          i += totalLen - 1; // Skip processed frame
        }
      }
    }
    
    return responseFrames.isNotEmpty ? responseFrames.last : hexData;
  }

  /// Extract the latest complete frame from buffer (for diagnosis)
  String _extractLatestCompleteFrame() {
    if (_sfdBuffer.length < 4) return '';
    
    // Look for the most recent complete frame with 55 A9 header
    final buffer = List<int>.from(_sfdBuffer);
    final responseFrames = <String>[];
    
    // Process buffer from end to find the latest complete frame
    for (int i = buffer.length - 4; i >= 0; i--) {
      if (buffer[i] == 0x55 && buffer[i + 1] == 0xA9) {
        // Found a potential frame header
        if (i + 3 < buffer.length) {
          final dlc = (buffer[i + 2] << 8) | buffer[i + 3] + 1;
          final totalLen = 4 + dlc;
          
          if (i + totalLen <= buffer.length) {
            // Complete frame found
            final frameData = buffer.skip(i).take(totalLen).toList();
            final frameHex = frameData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
            return frameHex;
          }
        }
      }
    }
    
    return '';
  }
} 
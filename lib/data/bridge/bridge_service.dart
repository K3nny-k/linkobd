import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../domain/protocol/frame_codec.dart';
import '../../ble_transport.dart';

class BridgeService {
  StreamSubscription? _bleToNetworkSubscription;
  StreamSubscription? _networkToBleSubscription;
  Socket? _tcpSocket;
  RawDatagramSocket? _udpSocket;
  
  final ByteQueue _bleBuffer = ByteQueue();
  final ByteQueue _networkBuffer = ByteQueue();
  int _networkSeq = 0;
  bool _isActive = false;

  bool get isActive => _isActive;

  /// Start BLE to TCP bridge
  Future<bool> startBleToTcp(BleTransport bleTransport, String host, int port) async {
    if (_isActive) {
      print('Bridge already active');
      return false;
    }

    try {
      // Connect TCP socket
      _tcpSocket = await Socket.connect(host, port);
      _isActive = true;

      print('Bridge: BLE ↔ TCP started ($host:$port)');

      // BLE → TCP: accumulate fragments, decode frames, forward data
      _bleToNetworkSubscription = bleTransport.rawResponseStream.listen(
        (data) => _handleBleToNetwork(data, _tcpSocket!),
        onError: (error) {
          print('Bridge: BLE→TCP error: $error');
          _stopBridge();
        },
      );

      // TCP → BLE: read stream, encode frames, split for BLE MTU
      _networkToBleSubscription = _tcpSocket!.listen(
        (data) => _handleNetworkToBle(data, bleTransport),
        onError: (error) {
          print('Bridge: TCP→BLE error: $error');
          _stopBridge();
        },
        onDone: () {
          print('Bridge: TCP connection closed');
          _stopBridge();
        },
      );

      return true;
    } catch (e) {
      print('Bridge: Failed to start BLE↔TCP: $e');
      _stopBridge();
      return false;
    }
  }

  /// Start TCP to BLE bridge (reverse direction)
  Future<bool> startTcpToBle(Socket tcpSocket, BleTransport bleTransport) async {
    if (_isActive) {
      print('Bridge already active');
      return false;
    }

    try {
      _tcpSocket = tcpSocket;
      _isActive = true;

      print('Bridge: TCP ↔ BLE started');

      // Same logic as startBleToTcp but with reversed roles
      _bleToNetworkSubscription = bleTransport.rawResponseStream.listen(
        (data) => _handleBleToNetwork(data, _tcpSocket!),
        onError: (error) {
          print('Bridge: BLE→TCP error: $error');
          _stopBridge();
        },
      );

      _networkToBleSubscription = _tcpSocket!.listen(
        (data) => _handleNetworkToBle(data, bleTransport),
        onError: (error) {
          print('Bridge: TCP→BLE error: $error');
          _stopBridge();
        },
        onDone: () {
          print('Bridge: TCP connection closed');
          _stopBridge();
        },
      );

      return true;
    } catch (e) {
      print('Bridge: Failed to start TCP↔BLE: $e');
      _stopBridge();
      return false;
    }
  }

  /// Start UDP to BLE bridge
  Future<bool> startUdpToBle(BleTransport bleTransport, String host, int port) async {
    if (_isActive) {
      print('Bridge already active');
      return false;
    }

    try {
      // Create UDP socket
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _isActive = true;

      print('Bridge: BLE ↔ UDP started ($host:$port)');

      // BLE → UDP: accumulate fragments, decode frames, forward data
      _bleToNetworkSubscription = bleTransport.rawResponseStream.listen(
        (data) => _handleBleToUdp(data, host, port),
        onError: (error) {
          print('Bridge: BLE→UDP error: $error');
          _stopBridge();
        },
      );

      // UDP → BLE: read datagrams, encode frames, split for BLE MTU
      _networkToBleSubscription = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleNetworkToBle(datagram.data, bleTransport);
          }
        }
      });

      return true;
    } catch (e) {
      print('Bridge: Failed to start BLE↔UDP: $e');
      _stopBridge();
      return false;
    }
  }

  /// Handle BLE data going to network (TCP/UDP)
  void _handleBleToNetwork(String data, dynamic networkSink) {
    try {
      // Add incoming BLE data to buffer
      _bleBuffer.addBytes(data.codeUnits);

      // Try to decode complete frames
      Frame? frame;
      while ((frame = FrameCodec.tryDecode(_bleBuffer)) != null) {
        print('Bridge: BLE→Network frame seq=${frame!.seq}, ${frame.data.length} bytes');
        
        // Forward raw data (without frame wrapper) to network
        if (networkSink is Socket) {
          networkSink.add(frame.data);
        } else {
          print('Bridge: Invalid network sink type');
        }
      }
    } catch (e) {
      print('Bridge: BLE→Network decode error: $e');
    }
  }

  /// Handle BLE data going to UDP
  void _handleBleToUdp(String data, String host, int port) {
    try {
      // Add incoming BLE data to buffer
      _bleBuffer.addBytes(data.codeUnits);

      // Try to decode complete frames
      Frame? frame;
      while ((frame = FrameCodec.tryDecode(_bleBuffer)) != null) {
        print('Bridge: BLE→UDP frame seq=${frame!.seq}, ${frame.data.length} bytes');
        
        // Forward raw data to UDP
        _udpSocket?.send(frame.data, InternetAddress(host), port);
      }
    } catch (e) {
      print('Bridge: BLE→UDP decode error: $e');
    }
  }

  /// Handle network data going to BLE
  void _handleNetworkToBle(Uint8List data, BleTransport bleTransport) {
    try {
      print('Bridge: Network→BLE ${data.length} bytes');

      // Encode data into frame
      final frame = FrameCodec.encode(data, _networkSeq);
      _networkSeq = (_networkSeq + 1) % 256;

      // Split frame into BLE-sized chunks (respect MTU)
      const int bleMtu = 247; // Conservative BLE MTU
      const int maxChunkSize = bleMtu - 3; // Account for ATT overhead

      for (int offset = 0; offset < frame.length; offset += maxChunkSize) {
        final chunkSize = (offset + maxChunkSize > frame.length) 
            ? frame.length - offset 
            : maxChunkSize;
        
        final chunk = frame.sublist(offset, offset + chunkSize);
        final chunkStr = String.fromCharCodes(chunk);
        
        // Send chunk via BLE
        bleTransport.sendCommand(chunkStr);
        print('Bridge: Network→BLE chunk ${offset ~/ maxChunkSize + 1}, $chunkSize bytes');
      }
    } catch (e) {
      print('Bridge: Network→BLE encode error: $e');
    }
  }

  /// Stop the bridge
  void _stopBridge() {
    _isActive = false;
    _bleToNetworkSubscription?.cancel();
    _networkToBleSubscription?.cancel();
    _tcpSocket?.close();
    _udpSocket?.close();
    
    _bleToNetworkSubscription = null;
    _networkToBleSubscription = null;
    _tcpSocket = null;
    _udpSocket = null;
    
    _bleBuffer.addBytes([]); // Clear buffer
    _networkBuffer.addBytes([]); // Clear buffer
    _networkSeq = 0;
    
    print('Bridge: Stopped');
  }

  /// Public method to stop bridge
  void stopBridge() {
    _stopBridge();
  }

  void dispose() {
    _stopBridge();
  }
} 
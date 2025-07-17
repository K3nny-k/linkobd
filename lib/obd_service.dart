import 'dart:async';

// Data class for parsed OBD frames
class ObdFrame {
  final String pid;
  final List<int> rawBytes;
  final dynamic value;
  final String unit;

  ObdFrame({
    required this.pid,
    required this.rawBytes,
    required this.value,
    required this.unit,
  });

  @override
  String toString() {
    return 'ObdFrame(pid: $pid, value: $value $unit, rawBytes: $rawBytes)';
  }
}

class ObdService {
  final Future<void> Function(String command) _sendCommand;
  final Stream<String> _rawResponseStream;
  late StreamSubscription<String> _responseSubscription;

  final _obdFrameController = StreamController<ObdFrame>.broadcast();
  Stream<ObdFrame> get obdFrameStream => _obdFrameController.stream;

  // Nordic UART Service and Characteristic UUIDs (for reference, actual BLE interaction is outside this class)
  // static const String nordicUartServiceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  // static const String nordicUartTxCharUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Write
  // static const String nordicUartRxCharUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // Notify

  ObdService({
    required Future<void> Function(String command) sendCommand,
    required Stream<String> rawResponseStream,
  })  : _sendCommand = sendCommand,
        _rawResponseStream = rawResponseStream {
    _responseSubscription = _rawResponseStream.listen(_handleRawResponse);
  }

  // Helper to send AT initialization sequence
  Future<void> initializeElm() async {
    await _sendCommand('ATZ'); // Reset
    await Future.delayed(const Duration(milliseconds: 100)); // Allow time for reset
    await _sendCommand('ATE0'); // Echo off
    await _sendCommand('ATL0'); // Linefeeds off
    await _sendCommand('ATH0'); // Headers off (usually, but can be H1 for more data)
    await _sendCommand('ATS0'); // Spaces off
    await _sendCommand('ATSP0'); // Protocol auto
    print("ELM327 Initialized");
  }

  // Request a specific PID
  Future<void> requestPid(String pid) async {
    if (pid.length != 4 || !pid.startsWith("01")) {
      print("Warning: Standard PIDs are usually mode 01XX. Requesting as is: $pid");
    }
    await _sendCommand(pid);
  }

  void _handleRawResponse(String rawResponse) {
    // Basic parsing: ELM327 often prefixes responses with the PID query + 40.
    // Example: Query "010C", Response "410C1A2B"
    // More robust parsing needed for multi-line responses, errors, etc.
    rawResponse = rawResponse.replaceAll('>', '').trim(); // Remove prompt and whitespace

    if (rawResponse.startsWith('41')) { // Mode 01 response
      String pid = rawResponse.substring(2, 4); // e.g., 0C from 410C
      String dataBytesStr = rawResponse.substring(4);
      List<int> dataBytes = [];
      for (int i = 0; i < dataBytesStr.length; i += 2) {
        dataBytes.add(int.parse(dataBytesStr.substring(i, i + 2), radix: 16));
      }

      if (pid == '0C' && dataBytes.length >= 2) { // RPM
        _parseRpm('010C', dataBytes);
      } else if (pid == '0D' && dataBytes.isNotEmpty) { // Speed
        _parseSpeed('010D', dataBytes);
      } else {
        // Placeholder for other PIDs or unhandled responses
        _obdFrameController.add(ObdFrame(
          pid: '01$pid',
          rawBytes: dataBytes,
          value: 'Unhandled: $rawResponse',
          unit: '',
        ));
      }
    } else if (rawResponse.contains("NO DATA") || rawResponse.contains("ERROR")) {
        _obdFrameController.add(ObdFrame(
          pid: 'ERROR',
          rawBytes: [],
          value: rawResponse,
          unit: '',
        ));
    }
    // Add handling for AT command responses (e.g., "OK", "ATZ" echo)
  }

  // Decode RPM (PID 010C)
  // Formula: (256A + B) / 4
  void _parseRpm(String pid, List<int> bytes) {
    if (bytes.length >= 2) {
      double rpm = ((bytes[0] * 256) + bytes[1]) / 4.0;
      _obdFrameController.add(ObdFrame(
        pid: pid,
        rawBytes: bytes,
        value: rpm,
        unit: 'RPM',
      ));
    }
  }

  // Decode Speed (PID 010D)
  // Formula: A
  void _parseSpeed(String pid, List<int> bytes) {
    if (bytes.isNotEmpty) {
      int speed = bytes[0]; // km/h
      _obdFrameController.add(ObdFrame(
        pid: pid,
        rawBytes: bytes,
        value: speed,
        unit: 'km/h',
      ));
    }
  }

  void dispose() {
    _responseSubscription.cancel();
    _obdFrameController.close();
  }
} 
import 'dart:typed_data';

class Frame {
  final int seq;
  final Uint8List data;

  Frame(this.seq, this.data);

  @override
  String toString() => 'Frame(seq: $seq, data: ${data.length} bytes)';
}

class ByteQueue {
  final List<int> _buffer = [];

  void addBytes(List<int> bytes) {
    _buffer.addAll(bytes);
  }

  int get length => _buffer.length;

  List<int> peek(int count) {
    if (count > _buffer.length) return [];
    return _buffer.take(count).toList();
  }

  void consume(int count) {
    if (count >= _buffer.length) {
      _buffer.clear();
    } else {
      _buffer.removeRange(0, count);
    }
  }

  bool get isEmpty => _buffer.isEmpty;
}

class FrameCodec {
  static const int headerByte1 = 0xAA;
  static const int headerByte2 = 0x55;
  static const int headerSize = 2;
  static const int seqSize = 1;
  static const int lenSize = 2;
  static const int crcSize = 2;
  static const int minFrameSize = headerSize + seqSize + lenSize + crcSize; // 7 bytes
  static const int maxPayloadSize = 244; // For BLE MTU 247

  /// Encode data into frame format: AA55 + seq + len + data + crc16
  static Uint8List encode(Uint8List data, int seq) {
    if (data.length > maxPayloadSize) {
      throw ArgumentError('Payload too large: ${data.length} > $maxPayloadSize');
    }

    final frameSize = minFrameSize + data.length;
    final frame = Uint8List(frameSize);
    int offset = 0;

    // Header: AA55
    frame[offset++] = headerByte1;
    frame[offset++] = headerByte2;

    // Sequence
    frame[offset++] = seq & 0xFF;

    // Length (little-endian)
    frame[offset++] = data.length & 0xFF;
    frame[offset++] = (data.length >> 8) & 0xFF;

    // Data
    frame.setRange(offset, offset + data.length, data);
    offset += data.length;

    // Calculate CRC16-CCITT over seq + len + data
    final crcData = Uint8List(seqSize + lenSize + data.length);
    crcData[0] = seq & 0xFF;
    crcData[1] = data.length & 0xFF;
    crcData[2] = (data.length >> 8) & 0xFF;
    crcData.setRange(3, 3 + data.length, data);

    final crc = _crc16Ccitt(crcData);

    // CRC (little-endian)
    frame[offset++] = crc & 0xFF;
    frame[offset++] = (crc >> 8) & 0xFF;

    return frame;
  }

  /// Try to decode a frame from the buffer. Returns null if incomplete.
  static Frame? tryDecode(ByteQueue buffer) {
    // Always check for invalid header first, even if buffer is small
    if (buffer.length >= headerSize) {
      final header = buffer.peek(headerSize);
      if (header[0] != headerByte1 || header[1] != headerByte2) {
        // Invalid header, consume one byte and try again
        buffer.consume(1);
        return null;
      }
    }

    // Check for invalid length if we have enough bytes
    if (buffer.length >= headerSize + seqSize + lenSize) {
      final headerSeqLen = buffer.peek(headerSize + seqSize + lenSize);
      final len = headerSeqLen[3] | (headerSeqLen[4] << 8);
      
      if (len > maxPayloadSize) {
        // Invalid length, consume header and try again
        buffer.consume(headerSize);
        return null;
      }
    }

    // Now check if we have enough bytes for a complete frame
    if (buffer.length < minFrameSize) return null;

    // Read seq and length (we know this is safe now)
    final headerSeqLen = buffer.peek(headerSize + seqSize + lenSize);
    final seq = headerSeqLen[2];
    final len = headerSeqLen[3] | (headerSeqLen[4] << 8);

    final totalFrameSize = minFrameSize + len;
    if (buffer.length < totalFrameSize) return null; // Incomplete frame

    // Read complete frame
    final frameBytes = buffer.peek(totalFrameSize);
    
    // Extract data
    final data = Uint8List(len);
    data.setRange(0, len, frameBytes, headerSize + seqSize + lenSize);

    // Extract CRC
    final receivedCrc = frameBytes[totalFrameSize - 2] | 
                      (frameBytes[totalFrameSize - 1] << 8);

    // Calculate expected CRC over seq + len + data
    final crcData = Uint8List(seqSize + lenSize + len);
    crcData[0] = seq;
    crcData[1] = len & 0xFF;
    crcData[2] = (len >> 8) & 0xFF;
    crcData.setRange(3, 3 + len, data);

    final expectedCrc = _crc16Ccitt(crcData);

    if (receivedCrc != expectedCrc) {
      // CRC mismatch, consume header and try again
      buffer.consume(headerSize);
      return null;
    }

    // Valid frame, consume it from buffer
    buffer.consume(totalFrameSize);
    return Frame(seq, data);
  }

  /// CRC16-CCITT implementation (polynomial 0x1021)
  static int _crc16Ccitt(Uint8List data) {
    int crc = 0xFFFF;
    
    for (int byte in data) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    
    return crc;
  }

  /// Calculate CRC8 with polynomial 0x07 (for data frames, matching Python implementation)
  static int calculateDataCrc8(List<int> data) {
    int crc = 0;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x07) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }
    return crc;
  }

  /// Create UDS command frame with AA A6 protocol wrapper (short format)
  /// Format: AA A6 00 00 [length] [UDS_data] 00
  /// This is used for standard UDS commands (compatible with Python FRAMES)
  static List<int> createUdsCommandFrame(List<int> udsData) {
    if (udsData.isEmpty) {
      throw ArgumentError('UDS data cannot be empty');
    }
    
    final frame = <int>[
      0xAA, 0xA6,       // Protocol header
      0x00, 0x00,       // Reserved bytes
      udsData.length,   // UDS data length
      ...udsData,       // UDS command data
      0x00,             // Terminator
    ];
    
    return frame;
  }

  /// Create single frame using long format (for consistency with splitIntoFrames)
  /// Format: AA A6 [frame_index] [total_length_be] [UDS_data] [CRC8]
  static List<int> createSingleLongFrame(List<int> udsData) {
    if (udsData.isEmpty) {
      throw ArgumentError('UDS data cannot be empty');
    }
    
    // For single frame, use frame index 01
    final totalLength = udsData.length;
    final totalLengthBytes = [(totalLength >> 8) & 0xFF, totalLength & 0xFF]; // big-endian
    
    final frame = <int>[
      0xAA, 0xA6,           // Protocol header
      0x01,                 // Frame index (01 for single frame)
      ...totalLengthBytes,  // Total data length (big-endian, 2 bytes)
      ...udsData,           // UDS command data
    ];
    
    // Calculate CRC8 for entire frame (including header) - PYTHON COMPATIBLE
    final crc = calculateDataCrc8(frame);
    frame.add(crc);
    
    return frame;
  }

  /// Split large UDS data into multiple frames (Python compatible)
  /// Returns list of complete frames ready to send
  /// Format: AA A6 [frame_index] [total_length_be] [16_bytes_data] [CRC8]
  /// This matches exactly the Python split_into_frames function
  static List<List<int>> splitIntoFrames(List<int> data, {int framePayloadSize = 16}) {
    if (data.isEmpty) {
      throw ArgumentError('Data cannot be empty');
    }
    
    final totalLength = data.length;
    final totalLengthBytes = [(totalLength >> 8) & 0xFF, totalLength & 0xFF]; // big-endian
    final numFrames = (totalLength / framePayloadSize).ceil();
    
    final frames = <List<int>>[];
    
    for (int i = 0; i < numFrames; i++) {
      final frameIndex = i + 1; // Frame index: 01, 02, 03, ... (1-based, Python compatible)
      final start = i * framePayloadSize;
      final end = (start + framePayloadSize > totalLength) ? totalLength : start + framePayloadSize;
      
      // Get frame data
      var frameData = data.sublist(start, end);
      
      // Pad with 0xFF if needed to reach exactly framePayloadSize bytes (Python compatible)
      if (frameData.length < framePayloadSize) {
        final padding = List.filled(framePayloadSize - frameData.length, 0xFF);
        frameData = [...frameData, ...padding];
      }
      
      // Create frame header: AA A6 [frame_index] [total_length_be]
      final header = <int>[
        0xAA, 0xA6,           // Protocol header
        frameIndex,           // Frame index: 01, 02, 03, ... (1-based)
        ...totalLengthBytes,  // Total data length (big-endian, 2 bytes)
      ];
      
      // Combine header + frame data
      final frameWithoutCrc = [...header, ...frameData];
      
      // Calculate CRC8 for entire frame INCLUDING header (Python compatible)
      final crc = calculateDataCrc8(frameWithoutCrc);
      
      // Final frame: header + data + CRC8
      final completeFrame = [...frameWithoutCrc, crc];
      
      frames.add(completeFrame);
    }
    
    return frames;
  }

  /// Parse hex string and split into frames
  /// Handles hex string cleaning (removes spaces, line breaks etc.)
  static List<List<int>> parseHexAndSplitFrames(String hexString, {int framePayloadSize = 16}) {
    // Clean hex string - remove spaces, newlines, etc.
    final cleanHex = hexString.trim().replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    
    if (cleanHex.isEmpty || cleanHex.length.isOdd) {
      throw ArgumentError('Invalid hex string: must contain even number of hex characters');
    }
    
    // Convert to bytes
    final data = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      data.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
    }
    
    return splitIntoFrames(data, framePayloadSize: framePayloadSize);
  }
}

// BLE to CAN Gateway Protocol Implementation
// Supports UDS (Unified Diagnostic Services) over CAN via BLE
class BleCanProtocol {
  // Frame headers
  static const int cmdFrameHeader1 = 0xAA;
  static const int cmdFrameHeader2 = 0xA6;
  static const int responseFrameHeader1 = 0x55;
  static const int responseFrameHeader2 = 0xA9;
  
  // Command types
  static const int cmdCanConfig = 0xFF;        // CAN Channel, Filter, and Baudrate Configuration
  static const int cmdUdsFlowControl = 0xFE;   // UDS Response Format & Flow Control Configuration
  static const int cmdUdsPayloadSmall = 0x00;  // UDS payload data DLC <128
  static const int cmdUdsPayloadLarge = 0x01;  // UDS payload data DLC >128 (up to 0x7F)
  
  // CRC8 polynomial
  static const int crc8Poly = 0x1F;
  
  /// Create CAN configuration frame
  /// [canChannel] - CAN channel (0 or 1)
  /// [filterCount] - Number of filters (0-15)
  /// [baudrate] - Baudrate in kbps (will be multiplied by 1000)
  /// [diagCanId] - CAN ID used for response (4 bytes)
  /// [diagReqCanId] - Filter ID for incoming requests (4 bytes)
  /// [filterMask] - Filter mask (4 bytes)
  static List<int> createCanConfigFrame({
    required int canChannel,
    required int filterCount,
    required int baudrate,
    required int diagCanId,
    required int diagReqCanId,
    required int filterMask,
  }) {
    final frame = <int>[
      cmdFrameHeader1, cmdFrameHeader2,  // AA A6
      cmdCanConfig,                      // FF
      0x00, 0x10,                       // Length = 16 bytes
      
      // Byte 1: Upper 4 bits = filter_count, Lower 4 bits = can_channel
      (filterCount << 4) | (canChannel & 0x0F),
      
      // Byte 2-3: Baudrate in kbps
      (baudrate >> 8) & 0xFF,
      baudrate & 0xFF,
      
      // Byte 4-7: DiagReqCANID (request/physical ID) - FIRST
      (diagReqCanId >> 24) & 0xFF,
      (diagReqCanId >> 16) & 0xFF,
      (diagReqCanId >> 8) & 0xFF,
      diagReqCanId & 0xFF,
      
      // Byte 8-11: DiagCANID (response/functional ID) - SECOND  
      (diagCanId >> 24) & 0xFF,
      (diagCanId >> 16) & 0xFF,
      (diagCanId >> 8) & 0xFF,
      diagCanId & 0xFF,
      
      // Byte 12-15: Filter mask (big-endian)
      (filterMask >> 24) & 0xFF,
      (filterMask >> 16) & 0xFF,
      (filterMask >> 8) & 0xFF,
      filterMask & 0xFF,
    ];
    
    // Add CRC8
    final crc = calculateCrc8(frame.skip(2).toList());
    frame.add(crc);
    
    return frame;
  }
  
  /// Create UDS Flow Control configuration frame
  /// [udsRequestEnable] - Enable UDS requests (0: disable, 1: enable)
  /// [replyFlowControl] - Flow control reply (0: off, 1: on)
  /// [blockSize] - ISO15765 block size (BS)
  /// [stMin] - ISO15765 separation time minimum (STmin)
  /// [padValue] - ISO15765 padding value (usually 0x00)
  static List<int> createUdsFlowControlFrame({
    required int udsRequestEnable,
    required int replyFlowControl,
    required int blockSize,
    required int stMin,
    int padValue = 0x00,
  }) {
    final frame = <int>[
      cmdFrameHeader1, cmdFrameHeader2,  // AA A6
      cmdUdsFlowControl,                 // FE
      0x00, 0x04,                       // Length = 4 bytes
      
      // Byte 1: Upper 4 bits = UDS_RequestEnable, Lower 4 bits = ReplyFlowControl
      (udsRequestEnable << 4) | (replyFlowControl & 0x0F),
      
      // Byte 2: ISO15765_BS (block size)
      blockSize,
      
      // Byte 3: ISO15765_STMIN (separation time minimum)
      stMin,
      
      // Byte 4: ISO15765_PAD_VALUES
      padValue,
    ];
    
    // Add CRC8
    final crc = calculateCrc8(frame.skip(2).toList());
    frame.add(crc);
    
    return frame;
  }
  
  /// Create UDS payload frame
  /// [payload] - UDS data payload
  static List<int> createUdsPayloadFrame(List<int> payload) {
    final isLarge = payload.length >= 128;
    final cmdType = isLarge ? cmdUdsPayloadLarge : cmdUdsPayloadSmall;
    
    final frame = <int>[
      cmdFrameHeader1, cmdFrameHeader2,  // AA A6
      cmdType,                          // 00 or 01-7F
      
      // Length (big-endian, 16-bit)
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
    ];
    
    // Add payload
    frame.addAll(payload);
    
    // Add CRC8
    final crc = calculateCrc8(frame.skip(2).toList());
    frame.add(crc);
    
    return frame;
  }
  
  /// Parse response frame
  /// Returns the UDS data portion (without 55 A9 header and DLC)
  static List<int>? parseResponseFrame(List<int> rawData) {
    if (rawData.length < 4) return null;
    
    // Check for response frame header
    if (rawData[0] != responseFrameHeader1 || rawData[1] != responseFrameHeader2) {
      return null;
    }
    
    // Extract DLC (big-endian, 16-bit)
    final dlc = (rawData[2] << 8) | rawData[3];
    final totalLength = 4 + dlc + 1; // Header + DLC + Data + CRC
    
    if (rawData.length < totalLength) return null;
    
    // Extract UDS data (skip header, DLC, and last CRC byte)
    return rawData.sublist(4, totalLength - 1);
  }
  
  /// Calculate CRC8 with polynomial 0x1F
  static int calculateCrc8(List<int> data) {
    int crc = 0;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = (crc << 1) ^ crc8Poly;
        } else {
          crc <<= 1;
        }
        crc &= 0xFF;
      }
    }
    return crc;
  }
  
  /// Verify CRC8 of a complete frame
  static bool verifyCrc8(List<int> frame) {
    if (frame.length < 3) return false;
    
    final data = frame.sublist(2, frame.length - 1); // Skip header, include last byte for CRC
    final expectedCrc = frame.last;
    final actualCrc = calculateCrc8(data);
    
    return expectedCrc == actualCrc;
  }
}

// UDS Service IDs (commonly used)
class UdsServiceIds {
  static const int diagnosticSessionControl = 0x10;
  static const int ecuReset = 0x11;
  static const int readDataByIdentifier = 0x22;
  static const int securityAccess = 0x27;
  static const int communicationControl = 0x28;
  static const int writeDataByIdentifier = 0x2E;
  static const int inputOutputControlByIdentifier = 0x2F;
  static const int routineControl = 0x31;
  static const int requestDownload = 0x34;
  static const int requestUpload = 0x35;
  static const int transferData = 0x36;
  static const int requestTransferExit = 0x37;
  static const int testerPresent = 0x3E;
}

// UDS Data Identifiers (commonly used)
class UdsDataIdentifiers {
  static const int vehicleIdentificationNumber = 0xF190;  // VIN
  static const int vehicleManufacturerSerialNumber = 0xF18C;
  static const int systemSupplierIdentifier = 0xF1A0;
  static const int applicationSoftwareFingerprint = 0xF184;
  static const int activeDiagnosticSession = 0xF186;
}

// Frame decoder for handling complete protocol
class FrameDecoder {
  static String formatHexBytes(List<int> bytes, {String separator = ' '}) {
    return bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(separator);
  }
  
  static List<int> parseHexString(String hexString) {
    final cleaned = hexString.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final bytes = <int>[];
    for (int i = 0; i < cleaned.length; i += 2) {
      if (i + 1 < cleaned.length) {
        bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
      }
    }
    return bytes;
  }
} 
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
} 
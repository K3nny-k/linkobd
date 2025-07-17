import asyncio
from bleak import BleakClient

ADDRESS = "38:3B:26:A2:27:FC"
DEVICE_NAME = "X_ble_OBD2"
WRITE_UUID = "0000FFF2-0000-1000-8000-00805F9B34FB"
NOTIFY_UUID = "0000FFF1-0000-1000-8000-00805F9B34FB"

MAX_RETRIES = 3
RESPONSE_TIMEOUT_MS = 3000

# Expected configuration acknowledgments
RECONFIG_DONE = bytes([0x55, 0xA9, 0x00, 0x01, 0xFF, 0x00])
FLOWCONTROL_DONE = bytes([0x55, 0xA9, 0x00, 0x01, 0xFE, 0x00])

def calculate_crc8(data):
    """Calculate CRC8 with polynomial 0x1F (BLE-CAN protocol)"""
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = (crc << 1) ^ 0x1F
            else:
                crc <<= 1
            crc &= 0xFF
    return crc

def create_can_config_frame():
    """Create CAN configuration frame (0xFF command)"""
    frame = [
        0xAA, 0xA6,  # Header
        0xFF,        # CAN config command
        0x00, 0x10,  # Length = 16 bytes
        0x10,        # filterCount=1, canChannel=0  
        0x01, 0xF4,  # baudrate = 500 (0x01F4)
        # diagCanId = 0x000007FF (big-endian)
        0x00, 0x00, 0x07, 0xFF,
        # diagReqCanId = 0x00000710 (big-endian)  
        0x00, 0x00, 0x07, 0x10,
        # filterMask = 0xFFFFFFFF (big-endian)
        0xFF, 0xFF, 0xFF, 0xFF,
    ]
    
    # Add CRC8
    crc_data = frame[2:]  # Skip header
    crc = calculate_crc8(crc_data)
    frame.append(crc)
    
    return bytes(frame)

def create_uds_flow_control_frame():
    """Create UDS Flow Control configuration frame (0xFE command)"""
    frame = [
        0xAA, 0xA6,  # Header
        0xFE,        # UDS flow control command
        0x00, 0x04,  # Length = 4 bytes
        0x11,        # udsRequestEnable=1, replyFlowControl=1
        0x0F,        # blockSize = 15
        0x05,        # stMin = 5ms
        0x55,        # padValue = 0x55
    ]
    
    # Add CRC8
    crc_data = frame[2:]  # Skip header
    crc = calculate_crc8(crc_data)
    frame.append(crc)
    
    return bytes(frame)

def create_uds_payload_frame(payload):
    """Create UDS payload frame in BLE-CAN protocol format"""
    is_large = len(payload) >= 128
    cmd_type = 0x01 if is_large else 0x00  # 0x01 for large, 0x00 for small
    
    frame = [
        0xAA, 0xA6,  # Header
        cmd_type,    # Command type
        (len(payload) >> 8) & 0xFF,  # Length high byte
        len(payload) & 0xFF,         # Length low byte
    ]
    
    frame.extend(payload)  # Add payload
    
    # Calculate CRC8 over everything except the header
    crc_data = frame[2:]  # Skip AA A6 header
    crc = calculate_crc8(crc_data)
    frame.append(crc)
    
    return bytes(frame)

# UDS Service IDs
class UdsServiceIds:
    TESTER_PRESENT = 0x3E
    DIAGNOSTIC_SESSION_CONTROL = 0x10
    READ_DATA_BY_IDENTIFIER = 0x22
    ROUTINE_CONTROL = 0x31

# UDS Data Identifiers
class UdsDataIdentifiers:
    VIN = 0xF190
    VEHICLE_MANUFACTURER_SERIAL = 0xF18C

async def wait_for_specific_response(notify_queue: asyncio.Queue, expected_response: bytes, timeout_ms: int = 3000):
    """Wait for a specific response frame"""
    buffer = bytearray()
    timeout_sec = timeout_ms / 1000
    deadline = asyncio.get_event_loop().time() + timeout_sec

    print(f"⏳ Waiting for response: {expected_response.hex(' ').upper()}")

    while True:
        remaining = deadline - asyncio.get_event_loop().time()
        if remaining <= 0:
            print("❌ Timeout waiting for specific response")
            return False

        try:
            data = await asyncio.wait_for(notify_queue.get(), timeout=remaining)
            buffer.extend(data)
            print(f"📥 Received {len(data)} bytes: {data.hex(' ').upper()}")

            # Check if we have the complete expected response
            if len(buffer) >= len(expected_response):
                # Look for the expected response anywhere in the buffer
                for i in range(len(buffer) - len(expected_response) + 1):
                    if buffer[i:i+len(expected_response)] == expected_response:
                        print(f"✅ Found expected response: {expected_response.hex(' ').upper()}")
                        return True
                        
                # If buffer is getting too long, remove old data
                if len(buffer) > 50:
                    buffer = buffer[-20:]  # Keep last 20 bytes
                    
        except asyncio.TimeoutError:
            print("❌ Timeout waiting for data")
            return False

async def wait_for_frame_with_header(notify_queue: asyncio.Queue, timeout_ms: int = 3000):
    """Wait for complete BLE-CAN response frame (0x55A9 header, big-endian DLC)"""
    buffer = bytearray()
    timeout_sec = timeout_ms / 1000
    deadline = asyncio.get_event_loop().time() + timeout_sec

    while True:
        remaining = deadline - asyncio.get_event_loop().time()
        if remaining <= 0:
            print("❌ Timeout waiting for complete frame")
            return None

        try:
            data = await asyncio.wait_for(notify_queue.get(), timeout=remaining)
            buffer.extend(data)
            print(f"📥 Received {len(data)} bytes: {data.hex(' ').upper()}")

            while len(buffer) >= 4:
                # Look for BLE-CAN response header (55 A9)
                if buffer[0] != 0x55 or buffer[1] != 0xA9:
                    buffer.pop(0)
                    continue

                # Calculate frame length (big-endian DLC + 1 for CRC)
                dlc = (buffer[2] << 8) | buffer[3] + 1
                total_len = 4 + dlc

                if len(buffer) >= total_len:
                    frame = buffer[:total_len]
                    del buffer[:total_len]
                    print(f"✅ [Complete Response Frame] {frame.hex(' ').upper()}")
                    
                    # Extract and display UDS data (skip header, DLC, and CRC)
                    if total_len > 5:  # Header(2) + DLC(2) + at least 1 data byte + CRC(1)
                        uds_data = frame[4:total_len-1]  # Skip header, DLC, and last CRC byte
                        print(f"📋 [UDS Data] {uds_data.hex(' ').upper()}")
                        
                        # Basic UDS response interpretation
                        if len(uds_data) > 0:
                            service_id = uds_data[0]
                            if service_id == 0x7E:  # Tester Present positive response
                                print("✅ Tester Present OK")
                            elif service_id == 0x50:  # Diagnostic Session positive response  
                                print("✅ Diagnostic Session established")
                            elif service_id == 0x62:  # Read Data positive response
                                print(f"✅ Data read successful: {uds_data[1:].hex(' ').upper()}")
                            elif service_id == 0x71:  # Routine Control positive response
                                print(f"✅ Routine control successful: {uds_data[1:].hex(' ').upper()}")
                            elif service_id == 0x7F:  # Negative response
                                if len(uds_data) >= 3:
                                    req_service = uds_data[1]
                                    error_code = uds_data[2]
                                    print(f"❌ Negative response: Service 0x{req_service:02X}, Error 0x{error_code:02X}")
                            else:
                                print(f"📋 Response: Service 0x{service_id:02X}")
                    
                    return frame
                else:
                    break
        except asyncio.TimeoutError:
            print("❌ Timeout waiting for data")
            return None

async def main():
    notify_queue = asyncio.Queue()

    def handle_notify(sender, data):
        loop = asyncio.get_running_loop()
        loop.call_soon_threadsafe(notify_queue.put_nowait, data)

    print(f"🔌 Connecting to {DEVICE_NAME} ({ADDRESS})...")
    
    async with BleakClient(ADDRESS) as client:
        if not client.is_connected:
            print("❌ Connection failed")
            return

        print("✅ Connected to device")

        await client.start_notify(NOTIFY_UUID, handle_notify)
        await asyncio.sleep(0.5)  # Give time for notifications to set up
        print("✅ BLE notifications enabled")

        print("\n🔧 Starting device configuration sequence...")
        
        # Step 1: Send CAN Configuration
        print("\n📤 Step 1: Sending CAN Configuration...")
        can_config_frame = create_can_config_frame()
        print(f"   Frame: {can_config_frame.hex(' ').upper()}")
        
        try:
            await client.write_gatt_char(WRITE_UUID, can_config_frame, response=True)
            print("✅ CAN config frame sent")
            
            # Wait for CAN config acknowledgment
            if await wait_for_specific_response(notify_queue, RECONFIG_DONE, 5000):
                print("✅ CAN configuration confirmed!")
            else:
                print("❌ CAN configuration failed - no acknowledgment received")
                return
                
        except Exception as e:
            print(f"❌ CAN config failed: {e}")
            return

        await asyncio.sleep(0.2)  # Small delay between commands

        # Step 2: Send UDS Flow Control Configuration  
        print("\n📤 Step 2: Sending UDS Flow Control Configuration...")
        flow_control_frame = create_uds_flow_control_frame()
        print(f"   Frame: {flow_control_frame.hex(' ').upper()}")
        
        try:
            await client.write_gatt_char(WRITE_UUID, flow_control_frame, response=True)
            print("✅ Flow control frame sent")
            
            # Wait for Flow Control acknowledgment
            if await wait_for_specific_response(notify_queue, FLOWCONTROL_DONE, 5000):
                print("✅ UDS Flow Control configuration confirmed!")
            else:
                print("❌ UDS Flow Control configuration failed - no acknowledgment received")
                return
                
        except Exception as e:
            print(f"❌ Flow control config failed: {e}")
            return

        await asyncio.sleep(0.5)  # Allow device to fully initialize

        print("\n🚀 Device configured! Starting UDS communication sequence...")

        # Create UDS request frames (proper BLE-CAN protocol format)
        UDS_FRAMES = [
            # Tester Present
            ("Tester Present", create_uds_payload_frame([UdsServiceIds.TESTER_PRESENT, 0x00])),
            
            # Enter Diagnostic Session (mode 0x03)
            ("Diagnostic Session", create_uds_payload_frame([UdsServiceIds.DIAGNOSTIC_SESSION_CONTROL, 0x03])),
            
            # Read VIN (Data Identifier F190)
            ("Read VIN", create_uds_payload_frame([
                UdsServiceIds.READ_DATA_BY_IDENTIFIER, 
                (UdsDataIdentifiers.VIN >> 8) & 0xFF,
                UdsDataIdentifiers.VIN & 0xFF
            ])),
            
            # Read Vehicle Manufacturer Serial Number (Data Identifier F18C)
            ("Read Manufacturer Serial", create_uds_payload_frame([
                UdsServiceIds.READ_DATA_BY_IDENTIFIER,
                (UdsDataIdentifiers.VEHICLE_MANUFACTURER_SERIAL >> 8) & 0xFF,
                UdsDataIdentifiers.VEHICLE_MANUFACTURER_SERIAL & 0xFF
            ])),
            
            # Read Custom Data Identifier (0174)
            ("Read Custom Data (0174)", create_uds_payload_frame([
                UdsServiceIds.READ_DATA_BY_IDENTIFIER, 
                0x01, 0x74
            ])),
            
            # Routine Control (C008 with parameter 02)
            ("Routine Control", create_uds_payload_frame([
                UdsServiceIds.ROUTINE_CONTROL, 
                0x01, 0xC0, 0x08, 0x02
            ])),
        ]

        for i, (frame_name, frame) in enumerate(UDS_FRAMES):
            retry_count = 0
            success = False
            
            while retry_count < MAX_RETRIES and not success:
                await asyncio.sleep(0.1 + retry_count * 0.05)  # Increasing delay between retries
                
                print(f"\n📤 Sending frame {i+1}/{len(UDS_FRAMES)} - {frame_name}")
                print(f"    (Attempt {retry_count+1}/{MAX_RETRIES}): {frame.hex(' ').upper()}")

                try:
                    await client.write_gatt_char(WRITE_UUID, frame, response=True)
                    print("✅ Frame sent successfully")
                    
                    # Wait for response
                    result = await wait_for_frame_with_header(notify_queue, RESPONSE_TIMEOUT_MS)
                    if result is not None:
                        print(f"✅ {frame_name} completed successfully")
                        success = True
                    else:
                        print(f"⚠️ No response received for {frame_name}, retrying...")
                        retry_count += 1
                        
                except Exception as e:
                    print(f"❌ Write failed: {e}")
                    retry_count += 1

            if not success:
                print(f"❌ {frame_name} failed after {MAX_RETRIES} attempts")

        print("\n🎉 UDS communication sequence completed")
        await client.stop_notify(NOTIFY_UUID)
        print("🔚 BLE communication ended")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 User interrupted, exiting")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc() 
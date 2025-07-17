import asyncio
from bleak import BleakClient

ADDRESS = "38:3B:26:A2:27:FC"
DEVICE_NAME = "X_ble_OBD2"
WRITE_UUID = "0000FFF2-0000-1000-8000-00805F9B34FB"
NOTIFY_UUID = "0000FFF1-0000-1000-8000-00805F9B34FB"

async def debug_device():
    """Simple script to test basic BLE communication and see device responses"""
    
    def handle_notify(sender, data):
        print(f"📥 Received: {data.hex(' ').upper()} ({len(data)} bytes)")
        try:
            # Try to decode as text
            text = data.decode('utf-8', errors='ignore')
            if text.isprintable():
                print(f"📝 As text: '{text}'")
        except:
            pass

    print(f"🔌 Connecting to {DEVICE_NAME} ({ADDRESS})...")
    
    async with BleakClient(ADDRESS) as client:
        if not client.is_connected:
            print("❌ Connection failed")
            return

        print("✅ Connected successfully!")
        
        # Get device info
        try:
            device_name = await client.read_gatt_char("00002A00-0000-1000-8000-00805F9B34FB")
            print(f"📱 Device Name: {device_name.decode('utf-8', errors='ignore')}")
        except:
            print("📱 Could not read device name")

        # Start notifications
        await client.start_notify(NOTIFY_UUID, handle_notify)
        print("✅ Notifications enabled")
        
        # Test 1: Send a simple UDS Tester Present frame
        print("\n🧪 Test 1: UDS Tester Present")
        test_frame = bytes([0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00])
        
        # Calculate CRC8
        crc_data = test_frame[2:]  # Skip header
        crc = 0
        for byte in crc_data:
            crc ^= byte
            for _ in range(8):
                if crc & 0x80:
                    crc = (crc << 1) ^ 0x1F
                else:
                    crc <<= 1
                crc &= 0xFF
        
        final_frame = test_frame + bytes([crc])
        print(f"📤 Sending: {final_frame.hex(' ').upper()}")
        
        try:
            await client.write_gatt_char(WRITE_UUID, final_frame, response=True)
            print("✅ Write successful")
        except Exception as e:
            print(f"❌ Write failed: {e}")
        
        # Wait for response
        await asyncio.sleep(2)
        
        # Test 2: Send original legacy frame to see what happens
        print("\n🧪 Test 2: Legacy frame format")
        legacy_frame = bytes.fromhex('AA A6 00 00 02 3E 00 00')
        print(f"📤 Sending: {legacy_frame.hex(' ').upper()}")
        
        try:
            await client.write_gatt_char(WRITE_UUID, legacy_frame, response=True)
            print("✅ Write successful")
        except Exception as e:
            print(f"❌ Write failed: {e}")
            
        # Wait for response
        await asyncio.sleep(2)
        
        # Test 3: Check if device needs configuration first
        print("\n🧪 Test 3: Try to send CAN config frame")
        # This should match what your Flutter app sends
        can_config = [
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
        
        # Calculate CRC8
        crc_data = can_config[2:]  # Skip header
        crc = 0
        for byte in crc_data:
            crc ^= byte
            for _ in range(8):
                if crc & 0x80:
                    crc = (crc << 1) ^ 0x1F
                else:
                    crc <<= 1
                crc &= 0xFF
        
        can_config.append(crc)
        can_config_frame = bytes(can_config)
        
        print(f"📤 Sending CAN config: {can_config_frame.hex(' ').upper()}")
        
        try:
            await client.write_gatt_char(WRITE_UUID, can_config_frame, response=True)
            print("✅ CAN config sent successfully")
        except Exception as e:
            print(f"❌ CAN config failed: {e}")
            
        await asyncio.sleep(2)
        
        await client.stop_notify(NOTIFY_UUID)
        print("🔚 Debug session completed")

if __name__ == "__main__":
    try:
        asyncio.run(debug_device())
    except KeyboardInterrupt:
        print("\n🛑 User interrupted")
    except Exception as e:
        print(f"\n💥 Error: {e}")
        import traceback
        traceback.print_exc() 
import asyncio
from bleak import BleakScanner

async def scan_for_devices():
    """Scan for available BLE devices to help find your OBD device"""
    print("🔍 Scanning for BLE devices...")
    print("📍 Looking for all BLE devices")
    print("⏰ Scanning for 10 seconds...\n")
    
    devices = await BleakScanner.discover(timeout=10.0)
    
    target_address = "38:3B:26:A2:27:FC"
    target_found = False
    
    print(f"📱 Found {len(devices)} BLE devices:")
    print("-" * 80)
    
    for device in devices:
        address = device.address
        name = device.name or "Unknown"
        rssi = getattr(device, 'rssi', 'N/A')
        
        # Highlight our target device
        if address.upper() == target_address.upper():
            print(f"🎯 TARGET FOUND: {address} | {name} | RSSI: {rssi}")
            target_found = True
        elif "obd" in name.lower() or "ble" in name.lower():
            print(f"🚗 POSSIBLE OBD: {address} | {name} | RSSI: {rssi}")
        else:
            print(f"📱 {address} | {name} | RSSI: {rssi}")
    
    print("-" * 80)
    
    if target_found:
        print("✅ Target device found! You can use the debug/main scripts now.")
    else:
        print("❌ Target device not found. Possible issues:")
        print("   • Device is powered off")
        print("   • Device is connected to another client (Flutter app)")
        print("   • Device is out of range")
        print("   • Device address has changed")
        print("   • Device is not in discoverable mode")
        
        # Look for similar devices
        obd_devices = [d for d in devices if "obd" in (d.name or "").lower()]
        if obd_devices:
            print(f"\n🤔 Found {len(obd_devices)} potential OBD devices:")
            for device in obd_devices:
                print(f"   {device.address} | {device.name}")
            print("   Try using one of these addresses in your script")

if __name__ == "__main__":
    try:
        asyncio.run(scan_for_devices())
    except KeyboardInterrupt:
        print("\n🛑 Scan interrupted by user")
    except Exception as e:
        print(f"\n💥 Error during scan: {e}")
        if "Bluetooth device is turned off" in str(e):
            print("🔧 Solution: Turn on Bluetooth in System Settings")
        elif "permission" in str(e).lower():
            print("🔧 Solution: Grant Bluetooth permissions to Terminal/Python") 
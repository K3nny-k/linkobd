import asyncio
import math
import platform
from binascii import unhexlify, hexlify
from bleak import BleakClient, BleakScanner

ADDRESS = "5C:53:10:03:76:7A"
DEVICE_NAME = "X_BLE_OBD"
WRITE_UUID = "0000FFF2-0000-1000-8000-00805F9B34FB"
NOTIFY_UUID = "0000FFF1-0000-1000-8000-00805F9B34FB"

FRAMES = [
    bytes.fromhex('AA A6 00 00 02 10 03 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 87 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 89 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 8C 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 90 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 91 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 97 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 9E 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 A0 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 A1 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 A2 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 A3 00'),
    bytes.fromhex('AA A6 00 00 03 22 F1 AA 00'),
    bytes.fromhex('AA A6 00 00 03 19 02 04 00'),
    bytes.fromhex('AA A6 00 00 03 19 02 08 00'),
]


MAX_RETRIES = 3
RESPONSE_TIMEOUT_MS = 2000

# ==== CRC8 ==== 
def crc8(data: bytes, poly=0x07, init=0x00) -> int:
    crc = init
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ poly) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc

# ==== 分帧函数 ==== 
def split_into_frames(hex_str: str, frame_payload_size: int = 16):
    hex_str = hex_str.strip().replace(" ", "").replace("\n", "")
    data = unhexlify(hex_str)
    total_length = len(data)
    total_length_bytes = total_length.to_bytes(2, byteorder='big')
    num_frames = math.ceil(total_length / frame_payload_size)

    frames = []
    for i in range(num_frames):
        frame_index = i + 1
        start = i * frame_payload_size
        end = start + frame_payload_size
        frame_data = data[start:end]

        if len(frame_data) < frame_payload_size:
            frame_data += b'\xFF' * (frame_payload_size - len(frame_data))

        header = bytes([0xAA, 0xA6, frame_index]) + total_length_bytes
        crc_input = header + frame_data
        crc = crc8(crc_input)
        full_frame = crc_input + bytes([crc])
        frames.append(full_frame)

    return frames

# ==== BLE应答等待（用于预设帧）====
async def wait_for_frame_with_header(notify_queue: asyncio.Queue, timeout_ms: int = 2000):
    buffer = bytearray()
    timeout_sec = timeout_ms / 1000
    deadline = asyncio.get_event_loop().time() + timeout_sec

    while True:
        remaining = deadline - asyncio.get_event_loop().time()
        if remaining <= 0:
            print("❌ 超时未收到完整帧")
            return None

        try:
            data = await asyncio.wait_for(notify_queue.get(), timeout=remaining)
            buffer.extend(data)

            while len(buffer) >= 4:
                if buffer[0] != 0x55 or buffer[1] != 0xA9:
                    buffer.pop(0)
                    continue

                dlc = (buffer[2] << 8) | buffer[3] + 1
                total_len = 4 + dlc

                if len(buffer) >= total_len:
                    frame = buffer[:total_len]
                    del buffer[:total_len]
                    print(f"✅ [完整帧接收] {frame.hex(' ').upper()}")
                    return frame
                else:
                    break
        except asyncio.TimeoutError:
            return None

# ==== 等待 ACK（用于长帧）====
async def wait_for_frame_ack(notify_queue: asyncio.Queue, expected_index: int, timeout_ms: int = 2000):
    timeout_sec = timeout_ms / 1000
    deadline = asyncio.get_event_loop().time() + timeout_sec

    while True:
        remaining = deadline - asyncio.get_event_loop().time()
        if remaining <= 0:
            print(f"❌ 超时未收到帧索引 {expected_index:02X} 的应答")
            return False

        try:
            data = await asyncio.wait_for(notify_queue.get(), timeout=remaining)
            if len(data) >= 4 and data[0] == 0x55 and data[1] == 0xA9 and data[2] == 0x03:
                if data[3] == expected_index:
                    print(f"✅ 收到 ACK 应答: 55 A9 03 {expected_index:02X}")
                    return True
        except asyncio.TimeoutError:
            return False

# ==== 通用帧发送器 ====
async def send_frames_with_retry(client, notify_queue, frames, description="数据帧", use_ack=False):
    for i, frame in enumerate(frames):
        frame_index = i + 1
        retry_count = 0
        while retry_count < MAX_RETRIES:
            # Longer delays on macOS for better reliability
            await asyncio.sleep(0.1 + retry_count * 0.05)
            print(f"\n📤 发送{description}第{frame_index}帧（第{retry_count+1}次尝试）: {frame.hex(' ').upper()}")
            
            try:
                # On macOS, use response=False to avoid issues with some devices
                if platform.system() == "Darwin":  # macOS
                    await client.write_gatt_char(WRITE_UUID, frame, response=False)
                    await asyncio.sleep(0.05)  # Small delay after write
                else:
                    await client.write_gatt_char(WRITE_UUID, frame, response=True)
            except Exception as e:
                print(f"❌ 写入失败: {e}")
                retry_count += 1
                continue

            if use_ack:
                ack_ok = await wait_for_frame_ack(notify_queue, frame_index, RESPONSE_TIMEOUT_MS)
                if ack_ok:
                    break
            else:
                result = await wait_for_frame_with_header(notify_queue, RESPONSE_TIMEOUT_MS)
                if result is not None:
                    break

            retry_count += 1
            print(f"⚠️ 未收到应答，重试中（{retry_count}/{MAX_RETRIES}）")

        if retry_count >= MAX_RETRIES:
            print(f"❌ {description}第{frame_index}帧连续失败 {MAX_RETRIES} 次，终止通信")
            return False
    return True

# ==== 设备发现（可选，用于更可靠的连接）====
async def find_device():
    print("🔍 正在扫描 BLE 设备...")
    try:
        devices = await BleakScanner.discover(timeout=10.0)
        
        target_device = None
        for device in devices:
            if device.address == ADDRESS or (device.name and DEVICE_NAME in device.name):
                target_device = device
                print(f"✅ 找到目标设备: {device.name} ({device.address})")
                break
        
        if not target_device:
            print(f"❌ 未找到设备 {DEVICE_NAME} ({ADDRESS})")
            print("📋 发现的设备列表:")
            for device in devices:
                print(f"  - {device.name or 'Unknown'} ({device.address})")
            return None
        
        return target_device
    except Exception as e:
        print(f"⚠️ 设备扫描失败: {e}")
        return None


# ==== 主流程 ====
async def main():
    print(f"🖥️ 运行平台: {platform.system()}")
    
    notify_queue = asyncio.Queue()

    def handle_notify(sender, data):
        loop = asyncio.get_running_loop()
        loop.call_soon_threadsafe(notify_queue.put_nowait, data)

    # Try to find device first (more reliable on macOS)
    if platform.system() == "Darwin":  # macOS
        target_device = await find_device()
        if target_device:
            device_address = target_device.address
        else:
            print("⚠️ 扫描失败，尝试直接连接...")
            device_address = ADDRESS
    else:
        device_address = ADDRESS

    try:
        async with BleakClient(device_address) as client:
            print(f"🔌 正在连接 {DEVICE_NAME} ({device_address})...")
            
            if not client.is_connected:
                print("❌ 连接失败")
                return

            print("✅ BLE 连接成功")

            # Handle pairing differently on macOS
            if platform.system() == "Darwin":
                try:
                    paired = await client.pair()
                    print(f"配对状态: {paired}")
                except Exception as e:
                    print(f"⚠️ 配对跳过或失败: {e}")
                    print("🔄 继续尝试连接...")
            else:
                paired = await client.pair(protection_level=2)
                print(f"配对状态: {paired}")
                if not paired:
                    print("❌ 配对失败")
                    return

            await client.start_notify(NOTIFY_UUID, handle_notify)
            await asyncio.sleep(0.5)
            print("✅ BLE 通知监听已启动")

            # 发送预设帧
            ok = await send_frames_with_retry(client, notify_queue, FRAMES, "预设帧", use_ack=False)
            if not ok:
                await client.stop_notify(NOTIFY_UUID)
                return

            print("🎉 所有预设帧发送完毕")

            await client.stop_notify(NOTIFY_UUID)
            print("🔚 BLE 通信结束")

    except Exception as e:
        print(f"❌ 连接或通信错误: {e}")
        if platform.system() == "Darwin":
            print("💡 macOS 提示：")
            print("   - 确保蓝牙已开启")
            print("   - 检查系统设置 → 隐私与安全性 → 蓝牙权限")
            print("   - 尝试重启蓝牙或重新配对设备")
# ==== 启动 ====
if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 用户中断，退出程序")
    except Exception as e:
        print(f"❌ 程序异常: {e}")
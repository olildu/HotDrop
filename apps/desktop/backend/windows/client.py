import asyncio
import json
import uuid
import sys
from bleak import BleakScanner, BleakClient
from llama_cpp import Llama

from winrt.windows.devices.bluetooth.genericattributeprofile import (
    GattServiceProvider,
    GattLocalCharacteristicParameters,
    GattCharacteristicProperties,
    GattProtectionLevel,
    GattServiceProviderAdvertisingParameters
)
from winrt.windows.storage.streams import DataWriter

# Define UUIDs as strings (matching the main script)
SERVICE_UUID_STR = "0000ABCD-0000-1000-8000-00805F9B34FB"
CHAR_UUID_STR = "0000FFFE-0000-1000-8000-00805F9B34FB"
CCCD_UUID = "00002902-0000-1000-8000-00805F9B34FB"

JSON_DATA = json.dumps({
    "ssid": "HotDropWiFi_Test",
    "password": "password123",
    "ip": "192.168.1.100"
})

provider = None
ble_loop = None

MODEL_PATH = "gemma-3-1b-it-Q4_K_M.gguf"
llm = None

SYSTEM_PROMPT = (
    "You are the HotDrop AI Assistant, a highly specialized expert in decentralized peer-to-peer (P2P) file transfer systems. "
    "You assist users in securely transferring files between Windows, Android and Linux devices using local-only communication.\n\n"

    "CORE IDENTITY:\n"
    "- You are precise, efficient, and technically competent.\n"
    "- You prioritize clarity and actionable guidance over verbosity.\n"
    "- You behave like a senior engineer guiding a user through a system.\n\n"

    "SYSTEM CONTEXT:\n"
    "- HotDrop uses Bluetooth Low Energy (BLE) for device discovery.\n"
    "- All communication is strictly local (LAN or direct device-to-device).\n"
    "- No cloud, internet, or external servers are involved at any stage.\n\n"

    "RESPONSE RULES:\n"
    "1. CONCISE: Default to 1-3 sentences unless deeper explanation is explicitly required.\n"
    "2. STRUCTURED: Prefer clear, step-by-step guidance when explaining processes.\n"
    "3. CONTEXT-AWARE: Tailor responses to file transfer, connectivity, or device interaction scenarios.\n"
    "4. NO HALLUCINATION: If unsure, ask for clarification instead of guessing.\n"
    "5. ACTIONABLE: Always provide practical next steps when possible.\n\n"

    "TROUBLESHOOTING PROTOCOL:\n"
    "- If a user reports connection issues:\n"
    "  • Verify Bluetooth is enabled on both devices\n"
    "  • Ensure both devices are on the same network (Wi-Fi or hotspot)\n"
    "  • Restart the HotDrop app on both devices\n"
    "  • Retry discovery and connection\n"
    "- If issues persist, ask for device details and error messages.\n\n"

    "FILE HANDLING LOGIC:\n"
    "- If a user references an unknown file, request metadata (file type, size, and source).\n"
    "- If discussing transfers, consider network conditions and device roles.\n\n"

    "SECURITY & PRIVACY:\n"
    "- Reinforce that all transfers are local and private.\n"
    "- Never imply cloud usage or external data storage.\n\n"

    "TONE:\n"
    "- Professional, calm, and technically confident.\n"
    "- Avoid unnecessary filler or casual language.\n"
    "- Focus on being helpful and precise.\n\n"

    "OUTPUT STYLE:\n"
    "- Direct answers first, then optional clarification if needed.\n"
    "- Avoid long paragraphs; prefer compact, readable responses.\n"
)

def log(msg):
    print(msg, flush=True)

def init_llm():
    global llm
    try:
        llm = Llama(model_path=MODEL_PATH, n_gpu_layers=-1, n_ctx=6144, verbose=False)
        print("Model loaded successfully!")
    except Exception as e:
        print(f"Failed to load model: {e}")
        llm = None

async def generate_response(prompt):
    if not llm:
        print("Error: AI Model not loaded.")
        return None
    
    loop = asyncio.get_running_loop()
    
    def run_llm():
        formatted_prompt = (
            f"<start_of_turn>user\n{SYSTEM_PROMPT}\n\n"
            f"User Question: {prompt}\n<end_of_turn>\n"
            "<start_of_turn>model\n"
        )

        print("AI: ", end="", flush=True)

        for chunk in llm(
            formatted_prompt,
            max_tokens=150,
            temperature=0.4,
            top_p=0.9,
            stop=["<end_of_turn>", "User:"],
            stream=True
        ):
            token = chunk["choices"][0]["text"]
            print(token, end="", flush=True)

        print("\n")

    await loop.run_in_executor(None, run_llm)
    return None
     
# --- HOST LOGIC (ADVERTISING) ---
async def start_host():
    global provider, ble_loop
    ble_loop = asyncio.get_running_loop()

    log("Starting BLE host...")

    result = await GattServiceProvider.create_async(uuid.UUID(SERVICE_UUID_STR))
    provider = result.service_provider
    service = provider.service

    params = GattLocalCharacteristicParameters()
    params.characteristic_properties = GattCharacteristicProperties.READ
    params.read_protection_level = GattProtectionLevel.PLAIN

    char_result = await service.create_characteristic_async(uuid.UUID(CHAR_UUID_STR), params)
    characteristic = char_result.characteristic

    adv_params = GattServiceProviderAdvertisingParameters()
    adv_params.is_discoverable = True
    adv_params.is_connectable = True

    def on_read(sender, args):
        deferral = args.get_deferral()
        async def handle():
            try:
                request = await args.get_request_async()
                if request:
                    writer = DataWriter()
                    writer.write_string(JSON_DATA)
                    request.respond_with_value(writer.detach_buffer())
                    log(f"Sent data to client: {JSON_DATA}")

                    provider.stop_advertising()
                    await asyncio.sleep(0.5)
                    provider.start_advertising_with_parameters(adv_params)
                    log("Advertising restarted")
            finally:
                deferral.complete()

        asyncio.run_coroutine_threadsafe(handle(), ble_loop)

    characteristic.add_read_requested(on_read)
    provider.start_advertising_with_parameters(adv_params)

    log("Advertising started. Press Ctrl+C to stop.")

    try:
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        provider.stop_advertising()
        log("Advertising stopped")

# --- CLIENT LOGIC (LIVE SCAN & CHOOSE) ---
async def run_client():
    log("Scanning for 10 seconds. Devices will appear live...\n")
    
    found_devices_dict = {}
    found_devices_list = []

    def detection_callback(device, advertisement_data):
        service_uuids = [u.lower() for u in advertisement_data.service_uuids]
        if SERVICE_UUID_STR.lower() in service_uuids:
            mac = device.address
            resolved_name = advertisement_data.local_name or device.name
            
            if mac not in found_devices_dict:
                name = resolved_name or "Unknown Windows PC"
                found_devices_dict[mac] = name
                found_devices_list.append({"name": name, "address": mac})
                
                idx = len(found_devices_list) - 1
                print(f"[+] Found [{idx}]: {name} ({mac})", flush=True)
            else:
                if resolved_name and found_devices_dict[mac] == "Unknown Windows PC":
                    found_devices_dict[mac] = resolved_name
                    
                    for idx, d in enumerate(found_devices_list):
                        if d["address"] == mac:
                            d["name"] = resolved_name
                            print(f"[~] Found [{idx}]: {resolved_name} ({mac}) [ Name Updated ]", flush=True)
                            break

    scanner = BleakScanner(detection_callback)
    await scanner.start()
    
    await asyncio.sleep(10.0)
    await scanner.stop()

    if not found_devices_list:
        log("\nNo HotDrop hosts found nearby.")
        return

    print("\n--- Scan Complete ---")
    choice = input("Enter the number of the host to connect to: ").strip()
    
    try:
        selected_index = int(choice)
        target_device = found_devices_list[selected_index]
    except (ValueError, IndexError):
        log("Invalid selection. Exiting.")
        return

    address = target_device["address"]
    log(f"\nConnecting specifically to {target_device['name']} [{address}]...")

    try:
        async with BleakClient(address, timeout=10.0) as client:
            if not client.is_connected:
                log("Connection failed.")
                return

            log("Connected! Fetching IP credentials...")
            data = await asyncio.wait_for(
                client.read_gatt_char(CHAR_UUID_STR),
                timeout=5.0
            )

            decoded = data.decode()
            parsed = json.loads(decoded)

            log("\n--- SUCCESS: Data Received ---")
            log(json.dumps(parsed, indent=4))

    except Exception as e:
        log(f"Error during connection/fetching: {str(e)}")

async def run_ai():
    init_llm()
    if not llm:
        print("Model failed to load.")
        return

    print("\nAI ready. Type 'exit' to quit.\n")

    while True:
        prompt = input("You: ").strip()
        if prompt.lower() == "exit":
            break

        await generate_response(prompt)

async def main():
    print("=== HotDrop BLE Test CLI ===")
    print("1. Start as Host (Advertise)")
    print("2. Start as Client (Live Scan & Join)")
    print("3. Run AI")

    choice = input("\nEnter choice (1, 2 or 3): ").strip()

    if choice == "1":
        await start_host()
    elif choice == "2":
        await run_client()
    elif choice == "3":
        await run_ai()
    else:
        print("Invalid choice.")

if __name__ == "__main__":
    asyncio.run(main())
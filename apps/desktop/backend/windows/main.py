import asyncio
import datetime
import json
import tempfile
import uuid
import os
from llama_cpp import Llama

from bleak import BleakScanner, BleakClient
from winrt.windows.devices.bluetooth.genericattributeprofile import (
    GattServiceProvider,
    GattLocalCharacteristicParameters,
    GattCharacteristicProperties,
    GattProtectionLevel,
    GattServiceProviderAdvertisingParameters
)
from winrt.windows.storage.streams import DataWriter

SERVICE_UUID = "0000ABCD-0000-1000-8000-00805F9B34FB"
CHAR_UUID = "0000FFFE-0000-1000-8000-00805F9B34FB"
CCCD_UUID = "00002902-0000-1000-8000-00805F9B34FB"

BLE_PAYLOAD_STRING = "{}"
provider = None

def log(msg):
    temp_dir = tempfile.gettempdir()
    path = os.path.join(temp_dir, "hotdrop_ble_logs.txt")
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted_msg = f"[{timestamp}] {msg}"
    with open(path, "a", encoding="utf-8") as f:
        f.write(formatted_msg + "\n")
    print(formatted_msg, flush=True)

# --- BLE LOGIC ---- 
async def start_ble():
    global provider, BLE_PAYLOAD_STRING
    if provider: return "Already running"

    ble_loop = asyncio.get_running_loop()
    result = await GattServiceProvider.create_async(uuid.UUID(SERVICE_UUID))
    provider = result.service_provider
    service = provider.service

    params = GattLocalCharacteristicParameters()
    params.characteristic_properties = GattCharacteristicProperties.READ
    params.read_protection_level = GattProtectionLevel.PLAIN

    char_result = await service.create_characteristic_async(uuid.UUID(CHAR_UUID), params)
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
                    writer.write_string(BLE_PAYLOAD_STRING)
                    request.respond_with_value(writer.detach_buffer())
                    log(f"Sent dynamic data to client: {BLE_PAYLOAD_STRING}")
            except Exception as e: log(f"Read error: {e}")
            finally: deferral.complete()
        asyncio.run_coroutine_threadsafe(handle(), ble_loop)

    characteristic.add_read_requested(on_read)
    provider.start_advertising_with_parameters(adv_params)
    log(f"BLE Host started with payload: {BLE_PAYLOAD_STRING}")
    return "BLE started"

def stop_ble():
    global provider
    if provider:
        provider.stop_advertising()
        provider = None
        log("BLE stopped")
        return "BLE stopped"
    return "Already stopped"

async def stream_hosts(writer):
    log("Starting continuous host scan...")
    found_devices_dict = {}
    queue = asyncio.Queue()
    loop = asyncio.get_running_loop()

    def detection_callback(device, advertisement_data):
        service_uuids = [u.lower() for u in advertisement_data.service_uuids]
        if SERVICE_UUID.lower() in service_uuids:
            mac = device.address
            resolved_name = advertisement_data.local_name or device.name
            
            updated = False
            if mac not in found_devices_dict:
                found_devices_dict[mac] = {
                    "name": resolved_name or "Unknown Windows PC",
                    "address": mac
                }
                updated = True
            else:
                if resolved_name and found_devices_dict[mac]["name"] == "Unknown Windows PC":
                    found_devices_dict[mac]["name"] = resolved_name
                    updated = True
            
            if updated:
                loop.call_soon_threadsafe(queue.put_nowait, found_devices_dict[mac])

    scanner = BleakScanner(detection_callback)
    await scanner.start()

    try:
        end_time = loop.time() + 15.0 
        while loop.time() < end_time:
            try:
                new_host = await asyncio.wait_for(queue.get(), timeout=1.0)
                payload = {"status": "found", "host": new_host}
                
                writer.write((json.dumps(payload) + "\n").encode())
                await writer.drain()
            except asyncio.TimeoutError:
                continue
    except Exception as e:
        log(f"Stream error: {e}")
    finally:
        await scanner.stop()
        writer.write((json.dumps({"status": "done"}) + "\n").encode())
        await writer.drain()

async def fetch_connection_data(address):
    try:
        log(f"Fetching connection data from {address}")
        async with BleakClient(address, timeout=10.0) as client:
            data = await client.read_gatt_char(CHAR_UUID)
            return {"status": "success", "data": json.loads(data.decode())}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# --- END OF BLE LOGIC  ---

# --- AI MODEL LOGIC ---
MODEL_PATH = r"C:\\Users\\olildu\\Documents\\Code\\Personal\\HotDrop\\apps\\desktop\\assets\\bin\\model.gguf"

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
        return "Error: AI Model not loaded."
    
    loop = asyncio.get_running_loop()
    
    def run_llm():
        formatted_prompt = (
            "<start_of_turn>user\n"
            f"{SYSTEM_PROMPT}\n\n"
            f"User: {prompt}\n"
            "<end_of_turn>\n"
            "<start_of_turn>model\n"
        )

        response = llm(
            formatted_prompt,
            max_tokens=150,
            temperature=0.6,
            top_p=0.9,
            stop=["<end_of_turn>", "User:"],
            echo=False
        )

        output = response['choices'][0]['text'].strip()
        return output if output else "I couldn't generate a response. Please try again."

    result = await loop.run_in_executor(None, run_llm)
    return result

async def handle_ai_command(request):
    command = request.get("command")

    if command == "generate":
        user_prompt = request.get("prompt", "")
        print(f"Generating response for: {user_prompt[:50]}...")
        answer = await generate_response(user_prompt)
        return {"status": "success", "response": answer}
    
    elif command == "status":
        return {"status": "success", "message": "AI Engine is running ready." if llm else "Model missing."}
    
    return None

# --- END OF AI MODEL LOGIC  ---

async def handle_client(reader, writer):
    global BLE_PAYLOAD_STRING
    try:
        data = await reader.read(4096)
        request = json.loads(data.decode())
        command = request.get("command")

        if command == "stream_hosts":
            await stream_hosts(writer)
            writer.close()
            return

        elif command == "start":
            BLE_PAYLOAD_STRING = request.get("data", "{}")
            msg = await start_ble()
            response = {"status": "ok", "message": msg}

        elif command == "stop":
            response = {"status": "ok", "message": stop_ble()}

        elif command == "connect_to":
            response = await fetch_connection_data(request.get("address"))

        else:
            ai_response = await handle_ai_command(request)
            if ai_response:
                response = ai_response
            else:
                response = {"status": "error", "message": "Unknown command"}

        writer.write(json.dumps(response).encode())
        await writer.drain()
    except Exception as e:
        log(f"Handle client error: {e}")
    finally:
        writer.close()

async def main():
    server = await asyncio.start_server(handle_client, "127.0.0.1", 8765)
    log("Python Socket server running")
    init_llm()
    async with server: await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
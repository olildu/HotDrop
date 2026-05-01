import asyncio
import datetime
import json
import tempfile
import uuid
import os
import traceback
import sys
import sentry_sdk

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

sentry_sdk.init(
    dsn="https://662b59483acbaaafc82a0c63eddff120@o4511313817436160.ingest.de.sentry.io/4511314046025808",
    traces_sample_rate=1.0,
    send_default_pii=True,
)

BLE_PAYLOAD_STRING = "{}"
VERSION = "1.0.0"
provider = None
shutdown_event = asyncio.Event()
last_activity_time = 0
WATCHDOG_TIMEOUT = 30.0 # Seconds

def log(msg):
    try:
        temp_dir = tempfile.gettempdir()
        path = os.path.join(temp_dir, "hotdrop_ble_logs.txt")
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        formatted_msg = f"[{timestamp}] {msg}"
        
        try:
            with open(path, "a", encoding="utf-8") as f:
                f.write(formatted_msg + "\n")
        except:
            pass

        try:
            print(formatted_msg, flush=True)
        except OSError:
            pass
    except:
        pass

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

async def handle_client(reader, writer):
    global BLE_PAYLOAD_STRING, last_activity_time
    last_activity_time = asyncio.get_running_loop().time()
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

        elif command == "ping":
            response = {"status": "pong"}

        elif command == "version":
            response = {"status": "ok", "version": VERSION}

        elif command == "kill":
            log("Kill command received. Shutting down...")
            shutdown_event.set()
            response = {"status": "shutting_down"}
            writer.write(json.dumps(response).encode())
            await writer.drain()
            return

        writer.write(json.dumps(response).encode())
        await writer.drain()
    except Exception as e:
        log(f"Handle client error: {e}")
    finally:
        writer.close()

async def watchdog():
    global last_activity_time
    log(f"Watchdog started (timeout: {WATCHDOG_TIMEOUT}s)")
    while not shutdown_event.is_set():
        await asyncio.sleep(5)
        if asyncio.get_running_loop().time() - last_activity_time > WATCHDOG_TIMEOUT:
            log("Watchdog timeout: No activity from Flutter. Shutting down...")
            shutdown_event.set()
            break

async def main():
    global last_activity_time
    last_activity_time = asyncio.get_event_loop().time()
    
    server = await asyncio.start_server(handle_client, "127.0.0.1", 8765)
    log("Python Socket server running")
    
    async with server:
        # Run until shutdown_event is set
        server_task = asyncio.create_task(server.serve_forever())
        shutdown_task = asyncio.create_task(shutdown_event.wait())
        watchdog_task = asyncio.create_task(watchdog())
        
        done, pending = await asyncio.wait(
            [server_task, shutdown_task, watchdog_task],
            return_when=asyncio.FIRST_COMPLETED
        )
        
        for task in pending:
            task.cancel()
            
    log("Python Socket server stopped")

if __name__ == "__main__":
    asyncio.run(main())
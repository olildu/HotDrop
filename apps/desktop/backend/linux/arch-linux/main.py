import asyncio
import datetime
import json
import tempfile
import os
import threading

from bleak import BleakScanner, BleakClient

# --- Linux D-Bus Imports ---
import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

# ---------------- CONFIG ----------------
SERVICE_UUID = "0000abcd-0000-1000-8000-00805f9b34fb"
CHAR_UUID = "0000fffe-0000-1000-8000-00805f9b34fb"

# BlueZ Constants
BLUEZ_SERVICE_NAME = "org.bluez"
ADAPTER_PATH = "/org/bluez/hci0"
GATT_MANAGER_IFACE = "org.bluez.GattManager1"
ADV_MANAGER_IFACE = "org.bluez.LEAdvertisingManager1"
DBUS_OM_IFACE = "org.freedesktop.DBus.ObjectManager"
DBUS_PROP_IFACE = "org.freedesktop.DBus.Properties"
GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
GATT_SERVICE_IFACE = "org.bluez.GattService1"

BLE_PAYLOAD_STRING = "{}"
is_ble_running = False

# Thread and D-Bus Object References
glib_mainloop = None
dbus_thread = None
gatt_mgr_iface = None
adv_mgr_iface = None
app_obj = None
adv_obj = None

# Runtime guards to avoid overlapping BlueZ operations.
active_scan_stop_event = None
active_scan_done_event = None
scan_state_lock = asyncio.Lock()
ble_operation_lock = asyncio.Lock()

def log(msg):
    temp_dir = tempfile.gettempdir()
    path = os.path.join(temp_dir, "hotdrop_ble_logs.txt")
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted_msg = f"[{timestamp}] {msg}"
    with open(path, "a", encoding="utf-8") as f:
        f.write(formatted_msg + "\n")
    print(formatted_msg, flush=True)

# ==========================================
#          LINUX D-BUS GATT SERVER
# ==========================================

class Characteristic(dbus.service.Object):
    def __init__(self, bus, index, service):
        self.path = service.path + f"/char{index}"
        self.service = service
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_CHRC_IFACE: {
                "Service": dbus.ObjectPath(self.service.path),
                "UUID": CHAR_UUID,
                "Flags": dbus.Array(["read"], signature="s")
            }
        }

    @dbus.service.method(DBUS_PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != GATT_CHRC_IFACE:
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs")
        return self.get_properties()[GATT_CHRC_IFACE]

    @dbus.service.method(GATT_CHRC_IFACE, in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        global BLE_PAYLOAD_STRING
        log(f"Sent dynamic data to client: {BLE_PAYLOAD_STRING}")
        return [dbus.Byte(b) for b in BLE_PAYLOAD_STRING.encode()]

class Service(dbus.service.Object):
    def __init__(self, bus, index):
        self.path = f"/org/bluez/example/service{index}"
        self.characteristics = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_SERVICE_IFACE: {
                "UUID": SERVICE_UUID,
                "Primary": True
            }
        }

    @dbus.service.method(DBUS_PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != GATT_SERVICE_IFACE:
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs")
        return self.get_properties()[GATT_SERVICE_IFACE]

class Application(dbus.service.Object):
    def __init__(self, bus):
        self.path = "/" # Critical for BlueZ discovery
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    @dbus.service.method(DBUS_OM_IFACE, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        response = {}
        for s in self.services:
            response[dbus.ObjectPath(s.path)] = s.get_properties()
            for c in s.characteristics:
                response[dbus.ObjectPath(c.path)] = c.get_properties()
        return response

class Advertisement(dbus.service.Object):
    def __init__(self, bus, index):
        self.path = f"/org/bluez/example/adv{index}"
        dbus.service.Object.__init__(self, bus, self.path)

    @dbus.service.method(DBUS_PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != "org.bluez.LEAdvertisement1":
            return {}
        return {
            "Type": "peripheral",
            "ServiceUUIDs": dbus.Array([SERVICE_UUID], signature="s"),
            "LocalName": "HotDrop",
            "Discoverable": True
        }

    @dbus.service.method("org.bluez.LEAdvertisement1", in_signature="", out_signature="")
    def Release(self):
        log("Advertisement released")

# ---------------- SERVER CONTROL ----------------

def _run_dbus_server():
    global glib_mainloop, gatt_mgr_iface, adv_mgr_iface, app_obj, adv_obj
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    try:
        adapter_obj = bus.get_object(BLUEZ_SERVICE_NAME, ADAPTER_PATH)
        gatt_mgr_iface = dbus.Interface(adapter_obj, GATT_MANAGER_IFACE)
        adv_mgr_iface = dbus.Interface(adapter_obj, ADV_MANAGER_IFACE)

        # Setup GATT
        app_obj = Application(bus)
        srv = Service(bus, 0)
        ch = Characteristic(bus, 0, srv)
        srv.characteristics.append(ch)
        app_obj.services.append(srv)

        # Setup Advertisement
        adv_obj = Advertisement(bus, 0)

        # Registration Success/Failure Handlers
        def reg_success(msg): log(msg)
        def reg_fail(e): log(f"Registration Error: {e}")

        gatt_mgr_iface.RegisterApplication(app_obj.path, {}, 
                                         reply_handler=lambda: reg_success("GATT App Registered"), 
                                         error_handler=reg_fail)
        
        adv_mgr_iface.RegisterAdvertisement(adv_obj.path, {}, 
                                          reply_handler=lambda: reg_success("Advertisement Registered"), 
                                          error_handler=reg_fail)

        glib_mainloop = GLib.MainLoop()
        glib_mainloop.run()
    except Exception as e:
        log(f"Critical D-Bus server error: {e}")

# ==========================================
#              BLE CLIENT LOGIC
# ==========================================

async def start_ble():
    global is_ble_running, dbus_thread
    if is_ble_running: return "Already running"

    is_ble_running = True
    dbus_thread = threading.Thread(target=_run_dbus_server, daemon=True)
    dbus_thread.start()
    log("BLE Host Background Thread started")
    return "BLE started"

def stop_ble():
    global is_ble_running, glib_mainloop, dbus_thread
    if not is_ble_running: return "Already stopped"

    if glib_mainloop:
        glib_mainloop.quit()
        glib_mainloop = None

    if dbus_thread:
        dbus_thread.join(timeout=1.0)
        dbus_thread = None

    is_ble_running = False
    log("BLE stopped")
    return "BLE stopped"

async def stop_active_scan(reason=None, timeout=3.0):
    global active_scan_stop_event, active_scan_done_event

    async with scan_state_lock:
        stop_event = active_scan_stop_event
        done_event = active_scan_done_event

    if stop_event is None or done_event is None:
        return

    if reason:
        log(f"Stopping active scan: {reason}")

    stop_event.set()
    try:
        await asyncio.wait_for(done_event.wait(), timeout=timeout)
    except asyncio.TimeoutError:
        log("Timed out waiting for active scan to stop")

async def stream_hosts(writer):
    global active_scan_stop_event, active_scan_done_event

    await stop_active_scan("new stream_hosts request")

    stop_event = asyncio.Event()
    done_event = asyncio.Event()
    async with scan_state_lock:
        active_scan_stop_event = stop_event
        active_scan_done_event = done_event

    log("Starting host scan...")
    found_devices_dict = {}
    queue = asyncio.Queue()
    loop = asyncio.get_running_loop()

    def detection_callback(device, advertisement_data):
        service_uuids = [u.lower() for u in (advertisement_data.service_uuids or [])]
        if SERVICE_UUID.lower() in service_uuids:
            mac = device.address
            resolved_name = advertisement_data.local_name or device.name
            
            if mac not in found_devices_dict:
                found_devices_dict[mac] = {"name": resolved_name or "Unknown", "address": mac}
                loop.call_soon_threadsafe(queue.put_nowait, found_devices_dict[mac])

    scanner = BleakScanner(detection_callback)
    await scanner.start()

    try:
        end_time = loop.time() + 15.0 
        while loop.time() < end_time and not stop_event.is_set():
            try:
                new_host = await asyncio.wait_for(queue.get(), timeout=1.0)
                log(f"Streaming discovered host to socket client: {new_host['name']} ({new_host['address']})")
                writer.write((json.dumps({"status": "found", "host": new_host}) + "\n").encode())
                await writer.drain()
            except asyncio.TimeoutError:
                continue
    finally:
        try:
            await scanner.stop()
        except Exception as e:
            log(f"Scanner stop error: {e}")

        if not writer.is_closing():
            writer.write((json.dumps({"status": "done"}) + "\n").encode())
            await writer.drain()

        done_event.set()
        async with scan_state_lock:
            if active_scan_stop_event is stop_event:
                active_scan_stop_event = None
                active_scan_done_event = None

async def fetch_connection_data(address):
    try:
        log(f"Connecting to {address}...")
        async with BleakClient(address, timeout=10.0) as client:
            raw_data = await client.read_gatt_char(CHAR_UUID)
            decoded_data = json.loads(raw_data.decode())
            # Added log here to see the data inside the service
            log(f"Successfully fetched data from {address}: {decoded_data}")
            return {"status": "success", "data": decoded_data}
    except Exception as e:
        log(f"Failed to fetch data from {address}: {e}")
        return {"status": "error", "message": str(e)}

# ==========================================
#             SOCKET SERVER
# ==========================================

async def handle_client(reader, writer):
    global BLE_PAYLOAD_STRING
    command = "unknown"
    try:
        raw_data = await reader.read(4096)
        if not raw_data: return
        request = json.loads(raw_data.decode())
        command = request.get("command")

        if command == "stream_hosts":
            await stream_hosts(writer)
            return

        elif command == "start":
            BLE_PAYLOAD_STRING = json.dumps(request.get("data", {}))
            msg = await start_ble()
            response = {"status": "ok", "message": msg}

        elif command == "stop":
            response = {"status": "ok", "message": stop_ble()}

        elif command == "connect_to":
            await stop_active_scan("connect_to request")
            async with ble_operation_lock:
                response = await fetch_connection_data(request.get("address"))
        
        else:
            response = {"status": "error", "message": "Unknown command"}

        # Added logging for the final response being sent back
        log(f"Socket Response for '{command}': {response}")
        
        writer.write(json.dumps(response).encode())
        await writer.drain()
    except Exception as e:
        log(f"Socket Handler Error for '{command}': {e}")
    finally:
        writer.close()
        await writer.wait_closed()

async def main():
    server = await asyncio.start_server(handle_client, "127.0.0.1", 8765)
    log("Main BLE Service running on port 8765")
    async with server: 
        await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
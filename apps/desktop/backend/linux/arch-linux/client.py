import asyncio
import json
import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib
from bleak import BleakScanner, BleakClient

# ---------------- CONFIG ----------------
SERVICE_UUID = "0000abcd-0000-1000-8000-00805f9b34fb"
CHAR_UUID = "0000fffe-0000-1000-8000-00805f9b34fb"

DATA = json.dumps({
    "ssid": "HotDropWiFi_Test",
    "password": "password123",
    "ip": "192.168.1.100"
})

BLUEZ = "org.bluez"
ADAPTER_PATH = "/org/bluez/hci0"
GATT_MANAGER_IFACE = "org.bluez.GattManager1"
ADV_MANAGER_IFACE = "org.bluez.LEAdvertisingManager1"
DBUS_PROP_IFACE = "org.freedesktop.DBus.Properties"
DBUS_OM_IFACE = "org.freedesktop.DBus.ObjectManager"

def log(msg):
    print(f"[BLE] {msg}", flush=True)

# ---------------- GATT CLASSES ----------------

class Characteristic(dbus.service.Object):
    def __init__(self, bus, index, service):
        self.path = service.path + f"/char{index}"
        self.service = service
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            "org.bluez.GattCharacteristic1": {
                "Service": dbus.ObjectPath(self.service.path),
                "UUID": CHAR_UUID,
                "Flags": dbus.Array(["read"], signature="s")
            }
        }

    @dbus.service.method(DBUS_PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != "org.bluez.GattCharacteristic1":
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs")
        return self.get_properties()["org.bluez.GattCharacteristic1"]

    @dbus.service.method("org.bluez.GattCharacteristic1", in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        log("Client read → sending JSON")
        return [dbus.Byte(b) for b in DATA.encode()]

class Service(dbus.service.Object):
    def __init__(self, bus, index):
        self.path = f"/org/bluez/example/service{index}"
        self.chars = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            "org.bluez.GattService1": {
                "UUID": SERVICE_UUID,
                "Primary": True
            }
        }

    @dbus.service.method(DBUS_PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != "org.bluez.GattService1":
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs")
        return self.get_properties()["org.bluez.GattService1"]

class Application(dbus.service.Object):
    def __init__(self, bus):
        self.path = "/" 
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    @dbus.service.method(DBUS_OM_IFACE, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        response = {}
        for s in self.services:
            response[dbus.ObjectPath(s.path)] = s.get_properties()
            for c in s.chars:
                response[dbus.ObjectPath(c.path)] = c.get_properties()
        return response

# ---------------- ADVERTISEMENT ----------------

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

# ---------------- SERVER ----------------

def run_server():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    # Create GATT structure
    app = Application(bus)
    service = Service(bus, 0)
    char = Characteristic(bus, 0, service)
    service.chars.append(char)
    app.services.append(service)

    # Create Adv
    adv = Advertisement(bus, 0)

    adapter_obj = bus.get_object(BLUEZ, ADAPTER_PATH)
    gatt_mgr = dbus.Interface(adapter_obj, GATT_MANAGER_IFACE)
    adv_mgr = dbus.Interface(adapter_obj, ADV_MANAGER_IFACE)

    # Success/Error loggers
    def gatt_success(): log("GATT Registered Successfully")
    def adv_success(): log("Advertisement Registered Successfully")
    def fail(e): log(f"Registration Failed: {e}")

    # Register
    gatt_mgr.RegisterApplication(app.path, {}, reply_handler=gatt_success, error_handler=fail)
    adv_mgr.RegisterAdvertisement(adv.path, {}, reply_handler=adv_success, error_handler=fail)

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass

# ---------------- CLIENT/MAIN ----------------

async def start_host():
    log("Starting BLE host...")
    await asyncio.get_event_loop().run_in_executor(None, run_server)

async def run_client():
    log("Cleaning up previous scans and starting new scan for HotDrop...")
    found = []
    
    def cb(device, adv_data):
        # We handle NoneType service_uuids safely here
        uuids = [u.lower() for u in (adv_data.service_uuids or [])]
        if SERVICE_UUID.lower() in uuids:
            if device.address not in [d["addr"] for d in found]:
                found.append({"addr": device.address, "name": adv_data.local_name or device.name})
                print(f"[{len(found)-1}] {found[-1]['name']} ({device.address})")

    scanner = BleakScanner(cb)
    
    try:
        # Force a stop first in case a previous run hung
        try:
            await scanner.stop()
        except:
            pass

        await scanner.start()
        log("Scan active (8s)...")
        await asyncio.sleep(8)
    except Exception as e:
        log(f"Scan Error: {e}")
    finally:
        await scanner.stop()
        log("Scan stopped.")

    if not found:
        log("No devices found")
        return

    try:
        idx_str = input("Select index: ")
        if not idx_str.isdigit():
            log("Invalid selection.")
            return
        idx = int(idx_str)
        target = found[idx]

        log(f"Connecting to {target['addr']}...")
        async with BleakClient(target["addr"], timeout=10.0) as client:
            data = await client.read_gatt_char(CHAR_UUID)
            log(f"Received JSON: {data.decode()}")
    except Exception as e:
        log(f"Connection/Read Error: {e}")

async def main():
    print("1. Host (Advertise)\n2. Client (Scan & Read)")
    choice = input("> ")
    if choice == "1":
        await start_host()
    elif choice == "2":
        await run_client()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
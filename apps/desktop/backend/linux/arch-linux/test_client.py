import socket
import json
import sys

# Configuration to match your main.py
HOST = '127.0.0.1'
PORT = 8765

def send_command(command, data=None, address=None):
    """Sends a JSON command to the BLE service and prints the response."""
    payload = {"command": command}
    if data:
        payload["data"] = data
    if address:
        payload["address"] = address

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((HOST, PORT))
            s.sendall(json.dumps(payload).encode())

            # Handle streaming response for scanning
            if command == "stream_hosts":
                print(f"--- Starting Scan (Waiting for hosts...) ---")
                buffer = ""
                while True:
                    chunk = s.recv(4096).decode()
                    if not chunk:
                        break
                    buffer += chunk
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line:
                            resp = json.loads(line)
                            if resp.get("status") == "found":
                                host = resp.get("host")
                                print(f"Found: {host['name']} [{host['address']}]")
                            elif resp.get("status") == "done":
                                print("--- Scan Complete ---")
                                return
            else:
                # Handle single-line responses for start/stop/connect
                response = s.recv(4096).decode()
                if response:
                    print(f"Response: {json.loads(response)}")
                else:
                    print("No response from server.")

    except ConnectionRefusedError:
        print(f"Error: Could not connect to BLE service at {HOST}:{PORT}. Is main.py running?")
    except Exception as e:
        print(f"An error occurred: {e}")

def main_menu():
    while True:
        print("\n--- BLE Service Test Menu ---")
        print("1. Start BLE Server (Advertising)")
        print("2. Stop BLE Server")
        print("3. Scan for Hosts (stream_hosts)")
        print("4. Connect to a Host (connect_to)")
        print("q. Quit")
        
        choice = input("\nSelect an option: ").strip().lower()

        if choice == '1':
            name = input("Enter your identity/name for the payload: ")
            send_command("start", data={"user": name, "status": "active"})
        
        elif choice == '2':
            send_command("stop")
        
        elif choice == '3':
            send_command("stream_hosts")
        
        elif choice == '4':
            addr = input("Enter the MAC address to connect to: ").strip()
            if addr:
                send_command("connect_to", address=addr)
            else:
                print("Address cannot be empty.")
        
        elif choice == 'q':
            print("Exiting.")
            break
        else:
            print("Invalid choice, try again.")

if __name__ == "__main__":
    main_menu()

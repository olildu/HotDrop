#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ASSETS_BIN_DIR="$PROJECT_ROOT/assets/bin"
OUTPUT_NAME="HotDropBLE"

cd "$SCRIPT_DIR"

echo "==============================="
echo "Stopping running BLE backend..."
echo "==============================="
pkill -f "${OUTPUT_NAME}|HotDropBLE|backend/linux/arch-linux/main.py" >/dev/null 2>&1 || true

echo "==============================="
echo "Cleaning old build artifacts..."
echo "==============================="
rm -rf build dist "${OUTPUT_NAME}.spec"

echo "==============================="
echo "Preparing Python build environment..."
echo "==============================="
PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "ERROR: python3 not found. Install Python 3 and retry."
  exit 1
fi

VENV_DIR="$SCRIPT_DIR/.venv-build"
"$PYTHON_BIN" -m venv --system-site-packages "$VENV_DIR"
source "$VENV_DIR/bin/activate"

if ! python - <<'PY'
import importlib.util
required = ["dbus", "gi"]
missing = [m for m in required if importlib.util.find_spec(m) is None]
if missing:
    print("ERROR: Missing required system Python modules:", ", ".join(missing))
    print("Install distro packages for dbus and gobject-introspection, then retry.")
    raise SystemExit(1)
PY
then
  exit 1
fi

python -m pip install --upgrade pip setuptools wheel
if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
  python -m pip install -r "$SCRIPT_DIR/requirements.txt"
else
  python -m pip install pyinstaller bleak
fi

echo "==============================="
echo "Building Linux distributable..."
echo "==============================="
python -m PyInstaller --clean --onefile \
  --name "$OUTPUT_NAME" \
  --hidden-import dbus.mainloop.glib \
  --hidden-import gi.repository.GLib \
  --collect-submodules bleak.backends.bluezdbus \
  main.py

echo "==============================="
echo "Copying binary to Flutter assets..."
echo "==============================="
mkdir -p "$ASSETS_BIN_DIR"
cp -f "dist/$OUTPUT_NAME" "$ASSETS_BIN_DIR/$OUTPUT_NAME"
chmod +x "$ASSETS_BIN_DIR/$OUTPUT_NAME"

echo "==============================="
echo "DONE"
echo "Output: $ASSETS_BIN_DIR/$OUTPUT_NAME"
echo "==============================="

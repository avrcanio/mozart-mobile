#!/usr/bin/env bash
# Install debug build on a USB iPhone and stream Flutter logs.
# 1) Plug in the device, trust this computer on the phone if asked.
# 2) Run: IOS_DEVICE_ID=<id from flutter devices> ./scripts/ios_install_logs.sh
#    Or export IOS_DEVICE_ID once, then run the script.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${IOS_DEVICE_ID:-}" ]]; then
  echo "Set IOS_DEVICE_ID to your iPhone id (see: flutter devices)."
  echo "Example: IOS_DEVICE_ID=00008110-000135443A31801E $0"
  exit 1
fi

flutter build ios --debug
flutter install -d "$IOS_DEVICE_ID"
echo ""
echo "Streaming logs (Ctrl+C to stop). Filter FCM: look for purchase_order_fcm"
echo ""
exec flutter logs -d "$IOS_DEVICE_ID"

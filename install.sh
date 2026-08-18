#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main"
INSTALL_DIR="/opt/linux-smart-mirror-manager"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Please run this installer as root."
    exit 1
fi

mkdir -p "$INSTALL_DIR"

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apt-get update
    apt-get install -y curl
fi

echo "Downloading latest Linux Smart Mirror Manager from GitHub..."
for file in smart-mirror.sh mirrors-iran.txt mirrors-foreign.txt; do
    echo "  -> $file"
    curl -4 -fL --retry 3 --connect-timeout 10 --max-time 60 \
        -o "$INSTALL_DIR/$file" "$REPO_RAW/$file"
done

chmod +x "$INSTALL_DIR/smart-mirror.sh"
ln -sfn "$INSTALL_DIR/smart-mirror.sh" /usr/local/bin/smart-mirror

iran_count=$(awk -F'|' 'NF>=4 && $1 !~ /^#/ {n++} END{print n+0}' "$INSTALL_DIR/mirrors-iran.txt")
foreign_count=$(awk -F'|' 'NF>=4 && $1 !~ /^#/ {n++} END{print n+0}' "$INSTALL_DIR/mirrors-foreign.txt")

if [ "$iran_count" -eq 0 ] || [ "$foreign_count" -eq 0 ]; then
    echo "ERROR: Mirror lists were downloaded but contain no valid entries."
    exit 1
fi

echo
echo "=============================================================="
echo "       Linux Smart Mirror Manager installed successfully"
echo "=============================================================="
echo "Install directory : $INSTALL_DIR"
echo "Iranian mirrors   : $iran_count"
echo "Foreign mirrors   : $foreign_count"
echo
echo "Run: smart-mirror"
echo
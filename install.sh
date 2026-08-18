#!/usr/bin/env bash
set -e

REPO="https://github.com/raminol12/linux-smart-mirror-manager.git"
INSTALL_DIR="/opt/linux-smart-mirror-manager"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Please run this installer as root."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Installing Git..."
    apt-get update
    apt-get install -y git
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "Cloning repository..."
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/smart-mirror.sh"
ln -sf "$INSTALL_DIR/smart-mirror.sh" /usr/local/bin/smart-mirror

echo
echo "=============================================================="
echo "       Linux Smart Mirror Manager installed successfully"
echo "=============================================================="
echo
echo "Run: smart-mirror"
echo
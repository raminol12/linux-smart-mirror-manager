#!/usr/bin/env bash
set -euo pipefail

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
    git -C "$INSTALL_DIR" fetch origin main
    git -C "$INSTALL_DIR" checkout -q main
    git -C "$INSTALL_DIR" pull --ff-only origin main
else
    echo "Cloning repository..."
    rm -rf "$INSTALL_DIR"
    git clone --branch main "$REPO" "$INSTALL_DIR"
fi

# Make sure the repository data files are present after installation/update.
for file in smart-mirror.sh mirrors-iran.txt mirrors-foreign.txt; do
    if [ ! -s "$INSTALL_DIR/$file" ]; then
        echo "ERROR: Required file is missing or empty: $file"
        exit 1
    fi
done

chmod +x "$INSTALL_DIR/smart-mirror.sh"
ln -sf "$INSTALL_DIR/smart-mirror.sh" /usr/local/bin/smart-mirror

echo
echo "=============================================================="
echo "       Linux Smart Mirror Manager installed successfully"
echo "=============================================================="
echo "Installed files:"
echo "  $INSTALL_DIR/smart-mirror.sh"
echo "  $INSTALL_DIR/mirrors-iran.txt"
echo "  $INSTALL_DIR/mirrors-foreign.txt"
echo
echo "Run: smart-mirror"
echo
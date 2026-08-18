#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main"
INSTALL_DIR="/opt/linux-smart-mirror-manager"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Please run this installer as root."
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if ! command -v curl >/dev/null 2>&1; then
  echo "Installing curl..."
  apt-get update
  apt-get install -y curl
fi

if ! command -v awk >/dev/null 2>&1; then
  echo "ERROR: awk is required."
  exit 1
fi

files=(smart-mirror.sh mirrors-iran.txt mirrors-foreign.txt README.md)

echo "=============================================================="
echo "       Linux Smart Mirror Manager - Installer"
echo "=============================================================="
echo "Downloading latest files from GitHub..."
echo

for file in "${files[@]}"; do
  printf '  [..] %-22s' "$file"
  if curl -4 -fsSL --retry 3 --connect-timeout 10 --max-time 60 \
      -o "$INSTALL_DIR/$file.tmp" "$REPO_RAW/$file"; then
    mv -f "$INSTALL_DIR/$file.tmp" "$INSTALL_DIR/$file"
    echo "  OK"
  else
    rm -f "$INSTALL_DIR/$file.tmp"
    echo "  FAILED"
    echo "ERROR: Could not download $file"
    exit 1
  fi
done

chmod 755 "$INSTALL_DIR/smart-mirror.sh"
ln -sfn "$INSTALL_DIR/smart-mirror.sh" /usr/local/bin/smart-mirror

iran_count=$(awk -F'|' 'NF>=4 && $1 !~ /^#/ {n++} END{print n+0}' "$INSTALL_DIR/mirrors-iran.txt")
foreign_count=$(awk -F'|' 'NF>=4 && $1 !~ /^#/ {n++} END{print n+0}' "$INSTALL_DIR/mirrors-foreign.txt")

if [[ "$iran_count" -eq 0 || "$foreign_count" -eq 0 ]]; then
  echo "ERROR: Mirror lists contain no valid entries."
  exit 1
fi

echo
echo "=============================================================="
echo "${GREEN:-}       Installation completed successfully${RESET:-}"
echo "=============================================================="
echo "Install directory : $INSTALL_DIR"
echo "Iranian mirrors   : $iran_count"
echo "Foreign mirrors   : $foreign_count"
echo "Command           : /usr/local/bin/smart-mirror"
echo "=============================================================="
echo
echo "Run the program with:"
echo
 echo "  smart-mirror"
echo

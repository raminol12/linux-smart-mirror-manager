#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IRAN_FILE="$BASE_DIR/mirrors-iran.txt"
FOREIGN_FILE="$BASE_DIR/mirrors-foreign.txt"
DATA_DIR="/root/smart-mirror"
BACKUP_DIR="$DATA_DIR/backups"
REPORT_DIR="$DATA_DIR/reports"

mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this program as root."
  exit 1
fi

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required."; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get was not found."; exit 1; }

OS_ID="unknown"
CODENAME="unknown"
[[ -r /etc/os-release ]] && source /etc/os-release && OS_ID="${ID:-unknown}" && CODENAME="${VERSION_CODENAME:-}"
if [[ -z "$CODENAME" || "$CODENAME" == "unknown" ]]; then
  CODENAME="$(. /etc/os-release 2>/dev/null; lsb_release -sc 2>/dev/null || true)"
fi

case "$OS_ID" in
  ubuntu|debian) ;;
  *) echo "WARNING: This version is designed for Ubuntu/Debian. Detected: $OS_ID" ;;
esac

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required."; exit 1; }

mapfile -t ALL_NAMES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print $1}')
mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pause(){ read -r -p $'\nPress Enter to continue...' _; }

show_header(){
  clear 2>/dev/null || true
  echo "=============================================================="
  echo "              Linux Smart Mirror Manager"
  echo "=============================================================="
  echo "OS       : $OS_ID"
  echo "Codename : ${CODENAME:-unknown}"
  echo "Mirrors  : ${#ALL_LINES[@]}"
  echo "=============================================================="
  echo
}

load_mirrors(){
  local mode="$1"
  mapfile -t SELECTED_LINES < <(case "$mode" in
    iran) awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE" 2>/dev/null;;
    foreign) awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$FOREIGN_FILE" 2>/dev/null;;
    all) cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}';;
  esac)
}

show_available(){
  echo "Available mirrors:"
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    IFS='|' read -r name country distro url _ <<< "$line"
    printf "%3d) %-28s %-8s %-10s %s\n" "$i" "$name" "$country" "$distro" "$url"
    ((i++))
  done
}

parse_selection(){
  local input="$1" token a b i
  SELECTED_LINES=()
  IFS=',' read -ra tokens <<< "$input"
  for token in "${tokens[@]}"; do
    token="${token//[[:space:]]/}"
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
      ((a>b)) && { local t=$a; a=$b; b=$t; }
      for ((i=a;i<=b;i++)); do
        ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      i=$token
      ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
    fi
  done
}

check_mirror(){
  local line="$1"; IFS='|' read -r name country distro url _ <<< "$line"
  local test_url="${url%/}/dists/${CODENAME}/Release"
  local start end elapsed status speed
  start=$(date +%s%N)
  if ! curl -4 -L --fail --silent --show-error --max-time 12 -o /dev/null "$test_url" 2>/dev/null; then
    echo "FAIL|$name|$country|$url|0|0"
    return 0
  fi
  end=$(date +%s%N)
  elapsed=$(( (end-start)/1000000 ))
  ((elapsed<1)) && elapsed=1
  speed="$(curl -4 -L --fail --silent --max-time 15 -o /dev/null -w '%{speed_download}' "${url%/}/dists/${CODENAME}/Release" 2>/dev/null || echo 0)"
  awk -v s="$speed" 'BEGIN{printf "%.2f", s/1048576}' | {
    read -r speed_mb
    echo "OK|$name|$country|$url|$elapsed|$speed_mb"
  }
}

test_selected(){
  local report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt"
  local line result name country url latency speed status
  echo "Starting tests..."
  echo "Report: $report"
  printf "%-28s %-8s %-10s %-14s %s\n" "MIRROR" "REGION" "LATENCY" "SPEED" "STATUS"
  echo "--------------------------------------------------------------------------"
  : > "$report"
  echo "Linux Smart Mirror Manager report - $(date)" >> "$report"
  echo "OS: $OS_ID $CODENAME" >> "$report"
  for line in "${SELECTED_LINES[@]}"; do
    result="$(check_mirror "$line")"
    IFS='|' read -r status name country url latency speed <<< "$result"
    printf "%-28s %-8s %-10s %-14s %s\n" "$name" "$country" "${latency}ms" "${speed} MB/s" "$status"
    echo "$result" >> "$report"
  done
  LAST_REPORT="$report"
}

backup_sources(){
  local stamp="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$stamp"
  if [[ -d /etc/apt/sources.list.d ]]; then cp -a /etc/apt/sources.list.d "$stamp/"; fi
  [[ -f /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$stamp/"
  echo "$stamp"
}

apply_mirror(){
  local line="$1"; IFS='|' read -r name country distro url _ <<< "$line"
  local backup
  backup=$(backup_sources)
  echo "Backup created: $backup"
  if [[ -f /etc/apt/sources.list ]]; then
    sed -i -E "s#https?://[^ ]+/(ubuntu|debian)(/[^ ]*)?#$url#g" /etc/apt/sources.list 2>/dev/null || true
  fi
  if [[ -d /etc/apt/sources.list.d ]]; then
    find /etc/apt/sources.list.d -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
      sed -i -E "s#https?://[^ ]+/(ubuntu|debian)(/[^ ]*)?#$url#g" "$f" 2>/dev/null || true
    done
  fi
  echo "Testing APT configuration..."
  if apt-get update; then
    echo "MIRROR APPLIED SUCCESSFULLY: $name"
  else
    echo "apt update failed. Restore manually from: $backup"
    return 1
  fi
}

manual_test(){
  show_available
  echo
  read -r -p "Select mirrors (example: 1,3,5-8): " input
  parse_selection "$input"
  ((${#SELECTED_LINES[@]})) || { echo "No valid mirrors selected."; pause; return; }
  test_selected
  pause
}

mode_test(){
  local mode="$1"
  load_mirrors "$mode"
  ((${#SELECTED_LINES[@]})) || { echo "No mirrors found for this category."; pause; return; }
  test_selected
  pause
}

main_menu(){
  while true; do
    show_header
    echo "1) Test Iranian mirrors"
    echo "2) Test foreign mirrors"
    echo "3) Test Iranian + foreign mirrors"
    echo "4) Manual mirror selection"
    echo "5) Show available mirrors"
    echo "6) Restore backup"
    echo "0) Exit"
    echo
    read -r -p "Select an option: " choice
    case "$choice" in
      1) mode_test iran;;
      2) mode_test foreign;;
      3) mode_test all;;
      4) manual_test;;
      5) show_available; pause;;
      6) echo "Backups are stored in $BACKUP_DIR"; ls -1 "$BACKUP_DIR" 2>/dev/null || true; pause;;
      0) exit 0;;
      *) echo "Invalid option."; pause;;
    esac
  done
}

main_menu

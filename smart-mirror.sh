#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IRAN_FILE="$BASE_DIR/mirrors-iran.txt"
FOREIGN_FILE="$BASE_DIR/mirrors-foreign.txt"
DATA_DIR="/root/smart-mirror"
BACKUP_DIR="$DATA_DIR/backups"
REPORT_DIR="$DATA_DIR/reports"
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if [[ $EUID -ne 0 ]]; then echo "ERROR: Run this program as root."; exit 1; fi
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required."; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get was not found."; exit 1; }

OS_ID="unknown"; CODENAME="unknown"
[[ -r /etc/os-release ]] && source /etc/os-release && OS_ID="${ID:-unknown}" && CODENAME="${VERSION_CODENAME:-}"
if [[ -z "$CODENAME" || "$CODENAME" == "unknown" ]]; then CODENAME="$(lsb_release -sc 2>/dev/null || true)"; fi

mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')

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
 case "$mode" in
  iran) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE" 2>/dev/null);;
  foreign) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$FOREIGN_FILE" 2>/dev/null);;
  all) mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}');;
 esac
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
 local input="$1" token a b i t
 SELECTED_LINES=()
 IFS=',' read -ra tokens <<< "$input"
 for token in "${tokens[@]}"; do
  token="${token//[[:space:]]/}"
  if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
   a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; if ((a>b)); then t=$a; a=$b; b=$t; fi
   for ((i=a;i<=b;i++)); do ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}"); done
  elif [[ "$token" =~ ^[0-9]+$ ]]; then
   i=$token; ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
  fi
 done
}

check_mirror(){
 local line="$1"; IFS='|' read -r name country distro url _ <<< "$line"
 local test_url="${url%/}/dists/${CODENAME}/Release" start end elapsed speed speed_mb
 start=$(date +%s%N)
 if ! curl -4 -L --fail --silent --show-error --max-time 12 -o /dev/null "$test_url" 2>/dev/null; then echo "FAIL|$name|$country|$url|0|0"; return; fi
 end=$(date +%s%N); elapsed=$(( (end-start)/1000000 )); ((elapsed<1)) && elapsed=1
 speed=$(curl -4 -L --fail --silent --max-time 15 -o /dev/null -w '%{speed_download}' "$test_url" 2>/dev/null || echo 0)
 speed_mb=$(awk -v s="$speed" 'BEGIN{printf "%.2f", s/1048576}')
 echo "OK|$name|$country|$url|$elapsed|$speed_mb"
}

test_selected(){
 local report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt" line result name country url latency speed status
 echo "Starting tests..."; echo "Report: $report"
 printf "%-28s %-8s %-10s %-14s %s\n" "MIRROR" "REGION" "LATENCY" "SPEED" "STATUS"
 echo "--------------------------------------------------------------------------"
 : > "$report"; echo "Linux Smart Mirror Manager report - $(date)" >> "$report"; echo "OS: $OS_ID $CODENAME" >> "$report"
 for line in "${SELECTED_LINES[@]}"; do
  result="$(check_mirror "$line")"; IFS='|' read -r status name country url latency speed <<< "$result"
  printf "%-28s %-8s %-10s %-14s %s\n" "$name" "$country" "${latency}ms" "${speed} MB/s" "$status"
  echo "$result" >> "$report"
 done
 echo; echo "Report saved: $report"
}

manual_test(){
 show_available; echo
 read -r -p "Select mirrors (example: 1,3,5-8): " input
 parse_selection "$input"
 ((${#SELECTED_LINES[@]})) || { echo "No valid mirrors selected."; pause; return; }
 test_selected; pause
}

category_test(){
 local mode="$1" label="$2"
 load_mirrors "$mode"
 ((${#SELECTED_LINES[@]})) || { echo "No mirrors found for $label."; pause; return; }
 echo "Selected: ${#SELECTED_LINES[@]} $label mirrors"
 echo
 test_selected; pause
}

main_menu(){
 while true; do
  show_header
  echo "1) Select all Iranian mirrors"
  echo "2) Select all foreign mirrors"
  echo "3) Select all Iranian + foreign mirrors"
  echo "4) Manual mirror selection"
  echo "5) Show available mirrors"
  echo "6) Restore backup"
  echo "0) Exit"
  echo
  read -r -p "Select an option: " choice
  case "$choice" in
   1) category_test iran "Iranian";;
   2) category_test foreign "foreign";;
   3) category_test all "Iranian + foreign";;
   4) manual_test;;
   5) show_available; pause;;
   6) echo "Backups are stored in $BACKUP_DIR"; ls -1 "$BACKUP_DIR" 2>/dev/null || true; pause;;
   0) exit 0;;
   *) echo "Invalid option."; pause;;
  esac
 done
}
main_menu

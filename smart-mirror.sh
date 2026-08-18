#!/usr/bin/env bash
set -uo pipefail

# Linux Smart Mirror Manager
# Ubuntu/Debian APT mirror selector, tester and manager.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
IRAN_FILE="$BASE_DIR/mirrors-iran.txt"
FOREIGN_FILE="$BASE_DIR/mirrors-foreign.txt"
DATA_DIR="/root/smart-mirror"
BACKUP_DIR="$DATA_DIR/backups"
REPORT_DIR="$DATA_DIR/reports"
LAST_REPORT_FILE="$DATA_DIR/last-report"

mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root."
  exit 1
fi

for cmd in curl awk sed find date readlink mktemp sort head; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required."; exit 1; }
done
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get is required."; exit 1; }
[[ -f "$IRAN_FILE" && -f "$FOREIGN_FILE" ]] || { echo "ERROR: Mirror list files not found in $BASE_DIR"; exit 1; }

OS_ID="unknown"
CODENAME="unknown"
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  CODENAME="${VERSION_CODENAME:-}"
fi
if [[ -z "$CODENAME" || "$CODENAME" == "unknown" ]]; then
  CODENAME="$(lsb_release -sc 2>/dev/null || true)"
fi

if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'
  CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; WHITE=''
fi

load_all() {
  mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')
}
load_all
SELECTED_LINES=()
SELECTED_MODE="none"

pause() { read -r -p $'\nPress Enter to continue...' _; }

show_header() {
  clear 2>/dev/null || true
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  echo "${CYAN}${BOLD}              Linux Smart Mirror Manager${RESET}"
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  printf "${WHITE}OS       :${RESET} %-10s  ${WHITE}Codename :${RESET} %s\n" "$OS_ID" "$CODENAME"
  printf "${WHITE}Mirrors  :${RESET} ${GREEN}%d${RESET}       ${WHITE}Selected :${RESET} ${YELLOW}%d${RESET}\n" "${#ALL_LINES[@]}" "${#SELECTED_LINES[@]}"
  [[ "$SELECTED_MODE" != "none" ]] && echo "${WHITE}Selection:${RESET} ${MAGENTA}$SELECTED_MODE${RESET}"
  echo "${CYAN}==============================================================${RESET}"
  echo
}

load_mirrors() {
  case "$1" in
    iran)
      mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE")
      SELECTED_MODE="All Iranian mirrors"
      ;;
    foreign)
      mapfile -t SELECTED_LINES < <(awk -F'|' -v os="$OS_ID" 'NF>=4 && $1 !~ /^#/ && tolower($3)==tolower(os) {print}' "$FOREIGN_FILE")
      SELECTED_MODE="All foreign $OS_ID mirrors"
      ;;
    all)
      mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' -v os="$OS_ID" 'NF>=4 && $1 !~ /^#/ && tolower($3)==tolower(os) {print}')
      SELECTED_MODE="All Iranian + foreign $OS_ID mirrors"
      ;;
  esac
}

show_available() {
  echo "${CYAN}${BOLD}Available mirrors${RESET}"
  echo
  printf "${BOLD}%-4s %-28s %-8s %-9s %s${RESET}\n" "No." "Name" "Region" "Distro" "URL"
  echo "--------------------------------------------------------------------------"
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    IFS='|' read -r name country distro url _ <<< "$line"
    if [[ "$country" == "IR" || "$country" == "IRAN" ]]; then
      printf "${GREEN}%-4d${RESET} %-28s ${GREEN}%-8s${RESET} %-9s %s\n" "$i" "$name" "$country" "$distro" "$url"
    else
      printf "${BLUE}%-4d${RESET} %-28s ${BLUE}%-8s${RESET} %-9s %s\n" "$i" "$name" "$country" "$distro" "$url"
    fi
    ((i++))
  done
}

manual_select() {
  show_available
  echo
  echo "${YELLOW}Example:${RESET} 1,3,5-8"
  read -r -p "Enter mirror numbers: " input
  SELECTED_LINES=()
  local token a b i t
  IFS=',' read -ra tokens <<< "$input"
  for token in "${tokens[@]}"; do
    token="${token//[[:space:]]/}"
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
      if ((a>b)); then t=$a; a=$b; b=$t; fi
      for ((i=a;i<=b;i++)); do
        if ((i>=1 && i<=${#ALL_LINES[@]})); then SELECTED_LINES+=("${ALL_LINES[i-1]}"); fi
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      i=$token
      if ((i>=1 && i<=${#ALL_LINES[@]})); then SELECTED_LINES+=("${ALL_LINES[i-1]}"); fi
    fi
  done
  SELECTED_MODE="Manual selection"
  if ((${#SELECTED_LINES[@]})); then
    echo "${GREEN}Selected ${#SELECTED_LINES[@]} mirror(s).${RESET}"
  else
    echo "${RED}No valid mirrors selected.${RESET}"
  fi
  pause
}

progress() {
  local current="$1" total="$2" width=40 percent filled empty
  ((total<1)) && total=1
  percent=$((current*100/total))
  filled=$((percent*width/100)); empty=$((width-filled))
  printf "\r${CYAN}[${RESET}"
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%*s' "$empty" '' | tr ' ' '-'
  printf "${CYAN}]${RESET} ${BOLD}%3d%%${RESET}  %d/%d" "$percent" "$current" "$total"
}

check_mirror() {
  local line="$1" name country distro url
  IFS='|' read -r name country distro url _ <<< "$line"
  local base="${url%/}" release_url speed_url http_code start end latency speed_raw speed_mb

  if [[ "${distro,,}" != "${OS_ID,,}" ]]; then
    echo "N/A|$name|$country|$distro|$url|0|0|INCOMPATIBLE"
    return
  fi

  release_url="$base/dists/$CODENAME/Release"
  speed_url="$base/dists/$CODENAME/main/binary-amd64/Packages.gz"

  start=$(date +%s%N)
  http_code=$(curl -4 -L --fail --silent --show-error --max-time 10 -o /dev/null -w '%{http_code}' "$release_url" 2>/dev/null || true)
  end=$(date +%s%N)
  latency=$(( (end-start)/1000000 ))
  ((latency<1)) && latency=1

  if [[ "$http_code" != "200" ]]; then
    echo "FAIL|$name|$country|$distro|$url|$latency|0|HTTP_$http_code"
    return
  fi

  speed_raw=$(curl -4 -L --fail --silent --max-time 20 -o /dev/null -w '%{speed_download}' "$speed_url" 2>/dev/null || echo 0)
  speed_mb=$(awk -v s="$speed_raw" 'BEGIN{printf "%.2f", s/1048576}')
  if [[ "$speed_mb" == "0.00" ]]; then
    echo "FAIL|$name|$country|$distro|$url|$latency|0|SPEED_TEST_FAILED"
  else
    echo "OK|$name|$country|$distro|$url|$latency|$speed_mb|OK"
  fi
}

test_selected() {
  local total=${#SELECTED_LINES[@]} current=0 line result raw report
  local status name country distro url latency speed code ok=0 fail=0 na=0
  if ((total==0)); then echo "${RED}No mirrors selected.${RESET}"; pause; return; fi

  raw=$(mktemp)
  report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt"

  echo
  echo "${CYAN}${BOLD}==================== MIRROR TEST ====================${RESET}"
  echo "Target: ${WHITE}$OS_ID $CODENAME${RESET}   Mirrors: ${WHITE}$total${RESET}"
  echo
  : > "$raw"

  for line in "${SELECTED_LINES[@]}"; do
    ((current++))
    progress "$current" "$total"
    result="$(check_mirror "$line")"
    echo "$result" >> "$raw"
  done
  printf "\n\n"

  while IFS='|' read -r status name country distro url latency speed code; do
    case "$status" in
      OK) ((ok++));;
      FAIL) ((fail++));;
      N/A) ((na++));;
    esac
  done < "$raw"

  echo "${CYAN}${BOLD}==================== FINAL RESULT ===================${RESET}"
  printf "  Total: ${WHITE}%d${RESET}   ${GREEN}OK: %d${RESET}   ${RED}FAIL: %d${RESET}   ${YELLOW}N/A: %d${RESET}\n" "$total" "$ok" "$fail" "$na"
  echo
  printf "${BOLD}%-4s %-27s %-7s %-8s %-12s %-12s %-18s${RESET}\n" "#" "Mirror" "Region" "Status" "Latency" "Speed" "Details"
  echo "------------------------------------------------------------------------------------------------"

  local idx=1
  while IFS='|' read -r status name country distro url latency speed code; do
    case "$status" in
      OK) printf "${GREEN}%-4d %-27s %-7s %-8s %-12s %-12s %-18s${RESET}\n" "$idx" "$name" "$country" "OK" "${latency} ms" "${speed} MB/s" "$code";;
      FAIL) printf "${RED}%-4d %-27s %-7s %-8s %-12s %-12s %-18s${RESET}\n" "$idx" "$name" "$country" "FAILED" "${latency} ms" "-" "$code";;
      N/A) printf "${YELLOW}%-4d %-27s %-7s %-8s %-12s %-12s %-18s${RESET}\n" "$idx" "$name" "$country" "N/A" "-" "-" "$code";;
    esac
    ((idx++))
  done < "$raw"

  echo "${CYAN}------------------------------------------------------------------------------------------------${RESET}"
  echo "${BOLD}Fastest successful mirrors:${RESET}"
  if ! awk -F'|' '$1=="OK" {print}' "$raw" | sort -t'|' -k7,7nr | head -5 | awk -F'|' '{printf "  %-27s %-7s %8s MB/s  %s ms\n",$2,$3,$7,$6}' ; then
    true
  fi

  {
    echo "Linux Smart Mirror Manager report"
    echo "Date: $(date)"
    echo "OS: $OS_ID"
    echo "Codename: $CODENAME"
    echo "Total: $total | OK: $ok | FAIL: $fail | N/A: $na"
    echo
    cat "$raw"
  } > "$report"
  cp -f "$report" "$LAST_REPORT_FILE"
  echo
  echo "${DIM}Report: $report${RESET}"
  echo "${CYAN}=======================================================${RESET}"
  rm -f "$raw"
  pause
}

backup_sources() {
  local stamp="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$stamp"
  [[ -f /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$stamp/"
  [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$stamp/"
  echo "$stamp"
}

restore_backup() {
  local latest
  latest=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
  if [[ -z "$latest" ]]; then echo "${RED}No backup found.${RESET}"; pause; return; fi
  echo "Latest backup: $latest"
  read -r -p "Restore this backup? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return
  [[ -f "$latest/sources.list" ]] && cp -a "$latest/sources.list" /etc/apt/sources.list
  if [[ -d "$latest/sources.list.d" ]]; then rm -rf /etc/apt/sources.list.d; cp -a "$latest/sources.list.d" /etc/apt/sources.list.d; fi
  echo "${GREEN}APT sources restored.${RESET}"
  pause
}

apply_best() {
  [[ -s "$LAST_REPORT_FILE" ]] || { echo "${RED}No test report found. Run a test first.${RESET}"; pause; return; }
  local best name country distro url backup file components
  best=$(awk -F'|' '$1=="OK" {print}' "$LAST_REPORT_FILE" | sort -t'|' -k7,7nr | head -1)
  [[ -z "$best" ]] && { echo "${RED}No successful mirror found.${RESET}"; pause; return; }
  IFS='|' read -r _ name country distro url _ <<< "$best"
  echo "${GREEN}Best mirror:${RESET} $name ($country)"
  echo "URL: $url"
  read -r -p "Apply this mirror to APT? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return
  backup=$(backup_sources)
  file="/etc/apt/sources.list.d/99-smart-mirror.list"
  if [[ "$OS_ID" == "ubuntu" ]]; then components="main restricted universe multiverse"; else components="main contrib non-free non-free-firmware"; fi
  cat > "$file" <<EOF2
# Managed by Linux Smart Mirror Manager
# Mirror: $name
# URL: $url
# Generated: $(date)
deb ${url%/}/ $CODENAME $components
EOF2
  echo "Backup: $backup"
  if apt-get update; then echo "${GREEN}Mirror applied successfully.${RESET}"; else echo "${RED}apt-get update failed. Backup: $backup${RESET}"; fi
  pause
}

main_menu() {
  while true; do
    show_header
    echo "${GREEN}  1)${RESET} Select mirrors manually"
    echo "${GREEN}  2)${RESET} Test all Iranian mirrors"
    echo "${BLUE}  3)${RESET} Test all foreign mirrors"
    echo "${MAGENTA}  4)${RESET} Test all Iranian + foreign mirrors"
    echo "${YELLOW}  5)${RESET} Test currently selected mirrors"
    echo "${CYAN}  6)${RESET} Show available mirrors"
    echo "${GREEN}  7)${RESET} Apply best mirror from last test"
    echo "${BLUE}  8)${RESET} Restore latest APT backup"
    echo "${RED}  0)${RESET} Exit"
    echo
    read -r -p "Select an option: " choice
    case "$choice" in
      1) manual_select;;
      2) load_mirrors iran; test_selected;;
      3) load_mirrors foreign; test_selected;;
      4) load_mirrors all; test_selected;;
      5) test_selected;;
      6) show_available; pause;;
      7) apply_best;;
      8) restore_backup;;
      0) exit 0;;
      *) echo "${RED}Invalid option.${RESET}"; pause;;
    esac
  done
}

main_menu

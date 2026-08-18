#!/usr/bin/env bash
set -uo pipefail

# Linux Smart Mirror Manager
# Clean interactive tester/manager for Ubuntu and Debian.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
IRAN_FILE="$BASE_DIR/mirrors-iran.txt"
FOREIGN_FILE="$BASE_DIR/mirrors-foreign.txt"
DATA_DIR="/root/smart-mirror"
BACKUP_DIR="$DATA_DIR/backups"
REPORT_DIR="$DATA_DIR/reports"
LAST_REPORT_FILE="$DATA_DIR/last-report"
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if [[ $EUID -ne 0 ]]; then echo "ERROR: Run this program as root."; exit 1; fi
for cmd in curl awk sed find date readlink mktemp sort head; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required."; exit 1; }
done
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get was not found."; exit 1; }
[[ -f "$IRAN_FILE" && -f "$FOREIGN_FILE" ]] || { echo "ERROR: Mirror list files not found in $BASE_DIR"; exit 1; }

OS_ID="unknown"; CODENAME="unknown"
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  CODENAME="${VERSION_CODENAME:-}"
fi
[[ -z "$CODENAME" ]] && CODENAME="$(lsb_release -sc 2>/dev/null || true)"

if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'
  CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; WHITE=''
fi

load_all(){ mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}'); }
load_all
SELECTED_LINES=(); SELECTED_MODE="none"

pause(){ read -r -p $'\nPress Enter to continue...' _; }

show_header(){
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

load_mirrors(){
  case "$1" in
    iran) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE"); SELECTED_MODE="All Iranian mirrors";;
    foreign) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$FOREIGN_FILE"); SELECTED_MODE="All foreign mirrors";;
    all) mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}'); SELECTED_MODE="All Iranian + foreign mirrors";;
  esac
}

show_available(){
  echo "${CYAN}${BOLD}Available mirrors${RESET}"; echo
  local i=1 line name country distro url
  printf "${BOLD}%-4s %-28s %-8s %-9s %s${RESET}\n" "No." "Name" "Region" "Distro" "URL"
  echo "--------------------------------------------------------------------------"
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

parse_selection(){
  local input="$1" token a b i t
  SELECTED_LINES=(); IFS=',' read -ra tokens <<< "$input"
  for token in "${tokens[@]}"; do
    token="${token//[[:space:]]/}"
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; ((a>b)) && { t=$a; a=$b; b=$t; }
      for ((i=a;i<=b;i++)); do ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}"); done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      i=$token; ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
    fi
  done
  SELECTED_MODE="Manual selection"
}

manual_select(){
  show_available; echo
  echo "${YELLOW}Example:${RESET} 1,3,5-8"; echo
  read -r -p "Enter mirror numbers: " input
  parse_selection "$input"
  if ((${#SELECTED_LINES[@]})); then echo "${GREEN}Selected ${#SELECTED_LINES[@]} mirror(s).${RESET}"; else echo "${RED}No valid mirrors selected.${RESET}"; fi
  pause
}

progress(){
  local current=$1 total=$2 width=42 filled empty percent
  ((total<1)) && total=1
  percent=$((current*100/total)); filled=$((percent*width/100)); empty=$((width-filled))
  printf "\r${CYAN}[${RESET}"
  ((filled>0)) && printf '%*s' "$filled" '' | tr ' ' '█' | sed "s/^/${GREEN}/;s/$/${RESET}/"
  ((empty>0)) && printf '%*s' "$empty" '' | tr ' ' '░' | sed "s/^/${DIM}/;s/$/${RESET}/"
  printf "${CYAN}]${RESET} ${BOLD}%3d%%${RESET}  Mirror ${current}/${total}" "$percent"
}

# Test a real metadata file. Release is used for reachability; Packages.gz is used for speed.
check_mirror(){
  local line="$1" name country distro url
  IFS='|' read -r name country distro url _ <<< "$line"
  local base="${url%/}" release_url speed_url http_code start end latency bytes speed_mb
  if [[ "$distro" != "$OS_ID" ]]; then
    echo "SKIP|$name|$country|$distro|$url|0|0|INCOMPATIBLE"
    return
  fi
  if [[ "$OS_ID" == "ubuntu" ]]; then
    release_url="$base/dists/$CODENAME/Release"
    speed_url="$base/dists/$CODENAME/main/binary-amd64/Packages.gz"
  else
    release_url="$base/dists/$CODENAME/Release"
    speed_url="$base/dists/$CODENAME/main/binary-amd64/Packages.gz"
  fi
  start=$(date +%s%N)
  http_code=$(curl -4 -L --fail --silent --max-time 12 -o /dev/null -w '%{http_code}' "$release_url" 2>/dev/null || true)
  end=$(date +%s%N); latency=$(( (end-start)/1000000 )); ((latency<1)) && latency=1
  if [[ "$http_code" != "200" ]]; then
    echo "FAIL|$name|$country|$distro|$url|$latency|0|HTTP_$http_code"
    return
  fi
  bytes=$(curl -4 -L --fail --silent --max-time 20 -o /dev/null -w '%{speed_download}' "$speed_url" 2>/dev/null || echo 0)
  speed_mb=$(awk -v s="$bytes" 'BEGIN{printf "%.2f", s/1048576}')
  [[ "$speed_mb" == "0.00" ]] && echo "FAIL|$name|$country|$distro|$url|$latency|0|SPEED_TEST_FAILED" || echo "OK|$name|$country|$distro|$url|$latency|$speed_mb|OK"
}

# Compact test UI: one live progress bar, then a clean final table.
test_selected(){
  local total=${#SELECTED_LINES[@]} current=0 line result raw="$(mktemp)" report
  local status name country distro url latency speed code ok=0 fail=0 skip=0
  ((total==0)) && { echo "${RED}No mirrors selected.${RESET}"; pause; return; }

  report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt"
  echo
  echo "${CYAN}${BOLD}==================== MIRROR TEST ====================${RESET}"
  echo "Target: ${WHITE}$OS_ID $CODENAME${RESET}   Mirrors: ${WHITE}$total${RESET}"
  echo
  : > "$raw"
  for line in "${SELECTED_LINES[@]}"; do
    ((current++)); progress "$current" "$total"
    result="$(check_mirror "$line")"
    echo "$result" >> "$raw"
    IFS='|' read -r status name country distro url latency speed code <<< "$result"
    case "$status" in OK) ((ok++));; FAIL) ((fail++));; SKIP) ((skip++));; esac
  done
  printf "\n\n"

  {
    echo "Linux Smart Mirror Manager report"
    echo "Date: $(date)"
    echo "OS: $OS_ID"
    echo "Codename: $CODENAME"
    echo "Total: $total | OK: $ok | FAIL: $fail | SKIP: $skip"
    echo
    sort -t'|' -k7,7nr "$raw"
  } > "$report"
  cp -f "$report" "$LAST_REPORT_FILE"

  echo "${CYAN}${BOLD}==================== FINAL RESULT ===================${RESET}"
  printf "  Total: ${WHITE}%d${RESET}   ${GREEN}OK: %d${RESET}   ${RED}FAIL: %d${RESET}   ${YELLOW}N/A: %d${RESET}\n" "$total" "$ok" "$fail" "$skip"
  echo
  printf "${BOLD}%-4s %-27s %-7s %-8s %-12s %-12s %-16s${RESET}\n" "#" "Mirror" "Region" "Status" "Latency" "Speed" "Details"
  echo "------------------------------------------------------------------------------------------------"

  local idx=1
  while IFS='|' read -r status name country distro url latency speed code; do
    case "$status" in
      OK) printf "${GREEN}%-4d %-27s %-7s %-8s %-12s %-12s %-16s${RESET}\n" "$idx" "$name" "$country" "OK" "${latency} ms" "${speed} MB/s" "$code";;
      FAIL) printf "${RED}%-4d %-27s %-7s %-8s %-12s %-12s %-16s${RESET}\n" "$idx" "$name" "$country" "FAILED" "${latency} ms" "-" "$code";;
      SKIP) printf "${YELLOW}%-4d %-27s %-7s %-8s %-12s %-12s %-16s${RESET}\n" "$idx" "$name" "$country" "N/A" "-" "-" "$code";;
    esac
    ((idx++))
  done < "$raw"

  echo
  echo "${CYAN}------------------------------------------------------------------------------------------------${RESET}"
  echo "${BOLD}Fastest successful mirrors:${RESET}"
  awk -F'|' '$1=="OK" {printf "  %-27s %-7s %8s MB/s  %s ms\n",$2,$3,$7,$6}' "$raw" | head -10
  echo
  echo "${DIM}Report: $report${RESET}"
  echo "${CYAN}=======================================================${RESET}"
  rm -f "$raw"
}

backup_sources(){
  local stamp="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$stamp"
  [[ -f /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$stamp/"
  [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$stamp/"
  echo "$stamp"
}

restore_backup(){
  local latest; latest=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
  [[ -z "$latest" ]] && { echo "${RED}No backup found.${RESET}"; pause; return; }
  echo "Latest backup: $latest"; read -r -p "Restore this backup? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  [[ -f "$latest/sources.list" ]] && cp -a "$latest/sources.list" /etc/apt/sources.list
  [[ -d "$latest/sources.list.d" ]] && { rm -rf /etc/apt/sources.list.d; cp -a "$latest/sources.list.d" /etc/apt/sources.list.d; }
  echo "${GREEN}APT sources restored.${RESET}"; pause
}

apply_best(){
  [[ -s "$LAST_REPORT_FILE" ]] || { echo "${RED}No test report found. Run a test first.${RESET}"; pause; return; }
  local best; best=$(awk -F'|' '$1=="OK" {print; exit}' "$LAST_REPORT_FILE")
  [[ -z "$best" ]] && { echo "${RED}No successful mirror found.${RESET}"; pause; return; }
  local name country distro url; IFS='|' read -r _ name country distro url _ <<< "$best"
  echo "${GREEN}Best mirror:${RESET} $name ($country)"
  echo "URL: $url"
  read -r -p "Apply this mirror to APT? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  local backup; backup=$(backup_sources); echo "Backup: $backup"
  local file="/etc/apt/sources.list.d/99-smart-mirror.list" components="main restricted universe multiverse"
  [[ "$OS_ID" == "debian" ]] && components="main contrib non-free non-free-firmware"
  cat > "$file" <<EOF
# Managed by Linux Smart Mirror Manager
# Mirror: $name
# URL: $url
# Generated: $(date)
deb ${url%/}/ $CODENAME $components
EOF
  if apt-get update; then echo "${GREEN}Mirror applied successfully.${RESET}"; else echo "${RED}apt-get update failed. Backup: $backup${RESET}"; fi
  pause
}

main_menu(){
  while true; do
    show_header
    echo "${GREEN}  1)${RESET} Select mirrors manually"
    echo "${GREEN}  2)${RESET} Test all Iranian mirrors"
    echo "${BLUE}  3)${RESET} Test all foreign mirrors"
    echo "${MAGENTA}  4)${RESET} Test all Iranian + foreign mirrors"
    echo "${YELLOW}  5)${RESET} Test currently selected mirrors"
    echo "${CYAN}  6)${RESET} Show available mirrors"
    echo "${WHITE}  7)${RESET} Apply best mirror from last test"
    echo "${WHITE}  8)${RESET} Restore latest APT backup"
    echo "${RED}  0)${RESET} Exit"
    echo
    read -r -p "Select an option: " choice
    case "$choice" in
      1) manual_select;;
      2) load_mirrors iran; test_selected; pause;;
      3) load_mirrors foreign; test_selected; pause;;
      4) load_mirrors all; test_selected; pause;;
      5) test_selected; pause;;
      6) show_available; pause;;
      7) apply_best;;
      8) restore_backup;;
      0) exit 0;;
      *) echo "${RED}Invalid option.${RESET}"; pause;;
    esac
  done
}

main_menu

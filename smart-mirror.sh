#!/usr/bin/env bash
set -uo pipefail

# Linux Smart Mirror Manager
# Interactive APT mirror tester/manager for Ubuntu and Debian.
# The script resolves its real path so it also works through /usr/local/bin/smart-mirror.

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
for cmd in curl awk sed find date readlink mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required."; exit 1; }
done
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get was not found."; exit 1; }

if [[ ! -f "$IRAN_FILE" || ! -f "$FOREIGN_FILE" ]]; then
  echo "ERROR: Mirror list files were not found."
  echo "Expected directory: $BASE_DIR"
  echo "Iranian list: $IRAN_FILE"
  echo "Foreign list: $FOREIGN_FILE"
  exit 1
fi

OS_ID="unknown"
CODENAME="unknown"
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  CODENAME="${VERSION_CODENAME:-}"
fi
if [[ -z "$CODENAME" || "$CODENAME" == "unknown" ]]; then CODENAME="$(lsb_release -sc 2>/dev/null || true)"; fi

# ANSI colors. If output is not a terminal, colors are disabled.
if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'
  CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; WHITE=''
fi

load_all(){
  mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')
}
load_all
SELECTED_LINES=()
SELECTED_MODE="none"

pause(){ read -r -p $'\nPress Enter to continue...' _; }

show_header(){
  clear 2>/dev/null || true
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  echo "${CYAN}${BOLD}              Linux Smart Mirror Manager${RESET}"
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  echo "${WHITE}OS       :${RESET} $OS_ID"
  echo "${WHITE}Codename :${RESET} ${CODENAME:-unknown}"
  printf "${WHITE}Mirrors  :${RESET} ${GREEN}%d${RESET}  |  ${WHITE}Selected:${RESET} ${YELLOW}%d${RESET}\n" "${#ALL_LINES[@]}" "${#SELECTED_LINES[@]}"
  if [[ "$SELECTED_MODE" != "none" ]]; then
    echo "${WHITE}Selection:${RESET} ${MAGENTA}${SELECTED_MODE}${RESET}"
  fi
  echo "${CYAN}==============================================================${RESET}"
  echo
}

load_mirrors(){
  case "$1" in
    iran) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE"); SELECTED_MODE="All Iranian mirrors";;
    foreign) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$FOREIGN_FILE"); SELECTED_MODE="All foreign mirrors";;
    all) mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}'); SELECTED_MODE="All Iranian + foreign mirrors";;
    *) SELECTED_LINES=(); SELECTED_MODE="none";;
  esac
}

show_available(){
  echo "${CYAN}${BOLD}Available mirrors${RESET}"
  echo
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    IFS='|' read -r name country distro url _ <<< "$line"
    if [[ "$country" == "IR" || "$country" == "IRAN" ]]; then
      printf "${GREEN}%3d)${RESET} %-28s ${GREEN}%-8s${RESET} %-10s %s\n" "$i" "$name" "$country" "$distro" "$url"
    else
      printf "${BLUE}%3d)${RESET} %-28s ${BLUE}%-8s${RESET} %-10s %s\n" "$i" "$name" "$country" "$distro" "$url"
    fi
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
      a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
      if ((a>b)); then t=$a; a=$b; b=$t; fi
      for ((i=a;i<=b;i++)); do
        ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      i=$token
      ((i>=1 && i<=${#ALL_LINES[@]})) && SELECTED_LINES+=("${ALL_LINES[i-1]}")
    fi
  done
  SELECTED_MODE="Manual selection"
}

manual_select(){
  show_available
  echo
  echo "${YELLOW}Examples:${RESET} ${DIM}1,3,5-8${RESET}"
  echo "${DIM}You can select Iranian and foreign mirrors together.${RESET}"
  echo
  read -r -p "Enter mirror numbers: " input
  parse_selection "$input"
  if ((${#SELECTED_LINES[@]} == 0)); then
    echo "${RED}No valid mirrors selected.${RESET}"
  else
    echo "${GREEN}Selected ${#SELECTED_LINES[@]} mirror(s).${RESET}"
  fi
  pause
}

clear_selection(){ SELECTED_LINES=(); SELECTED_MODE="none"; }

mirror_release_url(){ printf '%s/dists/%s/Release' "${1%/}" "$CODENAME"; }

progress_bar(){
  local current="$1" total="$2" width=38 filled empty percent
  ((total<1)) && total=1
  percent=$((current*100/total)); filled=$((current*width/total)); empty=$((width-filled))
  printf "${CYAN}[${RESET}"
  ((filled>0)) && printf '%*s' "$filled" '' | tr ' ' '#' | sed "s/^/${GREEN}/;s/$/${RESET}/"
  ((empty>0)) && printf '%*s' "$empty" '' | tr ' ' '-'
  printf "${CYAN}]${RESET} %3d%%" "$percent"
}

check_mirror(){
  local line="$1"; IFS='|' read -r name country distro url _ <<< "$line"
  local test_url start end elapsed speed speed_mb http_code
  if [[ "$distro" != "$OS_ID" ]]; then echo "SKIP|$name|$country|$distro|$url|0|0|DISTRO"; return; fi
  test_url="$(mirror_release_url "$url")"
  start=$(date +%s%N)
  http_code=$(curl -4 -L --fail --silent --show-error --max-time 12 -o /dev/null -w '%{http_code}' "$test_url" 2>/dev/null || true)
  end=$(date +%s%N); elapsed=$(( (end-start)/1000000 )); ((elapsed<1)) && elapsed=1
  if [[ "$http_code" != "200" ]]; then echo "FAIL|$name|$country|$distro|$url|$elapsed|0|$http_code"; return; fi
  speed=$(curl -4 -L --fail --silent --max-time 15 -o /dev/null -w '%{speed_download}' "$test_url" 2>/dev/null || echo 0)
  speed_mb=$(awk -v s="$speed" 'BEGIN{printf "%.2f", s/1048576}')
  echo "OK|$name|$country|$distro|$url|$elapsed|$speed_mb|200"
}

stage(){
  case "$2" in
    RUN) printf "  ${YELLOW}[..]${RESET} %s\n" "$1";;
    OK) printf "  ${GREEN}[OK]${RESET} %s\n" "$1";;
    FAIL) printf "  ${RED}[XX]${RESET} %s\n" "$1";;
    SKIP) printf "  ${DIM}[--]${RESET} %s\n" "$1";;
  esac
}

test_selected(){
  local report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt" raw="$(mktemp)"
  local total=${#SELECTED_LINES[@]} current=0 line result status name country distro url latency speed code
  local ok=0 fail=0 skip=0
  if ((total==0)); then echo "${RED}No mirrors selected.${RESET}"; pause; return; fi

  echo
  echo "${CYAN}${BOLD}==================== MIRROR TEST ====================${RESET}"
  echo "${WHITE}Target OS       :${RESET} $OS_ID $CODENAME"
  echo "${WHITE}Mirrors to test :${RESET} $total"
  echo "${WHITE}Test stages     :${RESET} Connectivity -> Release -> Speed -> Result"
  echo "${CYAN}=======================================================${RESET}"
  : > "$raw"

  for line in "${SELECTED_LINES[@]}"; do
    ((current++))
    IFS='|' read -r name country distro url _ <<< "$line"
    echo
    printf "${BOLD}Mirror %d/%d  ${RESET}" "$current" "$total"; progress_bar "$current" "$total"; echo
    echo "  ${WHITE}Name   :${RESET} $name"
    echo "  ${WHITE}Region :${RESET} $country"
    echo "  ${WHITE}URL    :${RESET} $url"
    echo "  ${DIM}----------------------------------------------------${RESET}"

    stage "Operating-system compatibility" RUN
    if [[ "$distro" != "$OS_ID" ]]; then
      stage "Operating-system compatibility" SKIP
      stage "Connectivity / HTTP" SKIP
      stage "Release file: $CODENAME/Release" SKIP
      stage "Download speed" SKIP
      result="SKIP|$name|$country|$distro|$url|0|0|DISTRO"; ((skip++)); echo "$result" >> "$raw"; continue
    fi
    stage "Operating-system compatibility" OK
    stage "Connectivity / HTTP" RUN
    result="$(check_mirror "$line")"
    IFS='|' read -r status name country distro url latency speed code <<< "$result"
    if [[ "$status" == "OK" ]]; then
      stage "Connectivity / HTTP" OK
      stage "Release file: $CODENAME/Release" OK
      stage "Download speed" OK
      printf "  ${GREEN}[OK]${RESET} Result: ${GREEN}%s${RESET} | Latency: ${CYAN}%sms${RESET} | Speed: ${MAGENTA}%s MB/s${RESET}\n" "$status" "$latency" "$speed"
      ((ok++))
    else
      stage "Connectivity / HTTP" FAIL
      stage "Release file: $CODENAME/Release" FAIL
      stage "Download speed" FAIL
      printf "  ${RED}[XX]${RESET} Result: ${RED}%s${RESET} | HTTP: %s | Latency: %sms\n" "$status" "$code" "$latency"
      ((fail++))
    fi
    echo "$result" >> "$raw"
  done

  {
    echo "Linux Smart Mirror Manager report"
    echo "Date: $(date)"; echo "OS: $OS_ID"; echo "Codename: $CODENAME"; echo "Selected: $total"; echo "OK: $ok | FAIL: $fail | SKIP: $skip"; echo
    sort -t'|' -k7,7nr "$raw"
  } > "$report"
  cp -f "$report" "$LAST_REPORT_FILE"

  echo
  echo "${CYAN}${BOLD}=======================================================${RESET}"
  echo "${CYAN}${BOLD}                    TEST COMPLETE${RESET}"
  echo "${CYAN}${BOLD}=======================================================${RESET}"
  printf "  Total tested : ${WHITE}%d${RESET}\n" "$total"
  printf "  Successful   : ${GREEN}%d${RESET}\n" "$ok"
  printf "  Failed       : ${RED}%d${RESET}\n" "$fail"
  printf "  Skipped      : ${YELLOW}%d${RESET}\n" "$skip"
  echo "${CYAN}-------------------------------------------------------${RESET}"
  echo "  ${BOLD}Fastest successful mirrors:${RESET}"
  awk -F'|' '$1=="OK" {printf "  %-27s %8s MB/s  %sms\n",$2,$7,$6}' "$raw" | head -10
  echo "${CYAN}-------------------------------------------------------${RESET}"
  echo "  ${DIM}Report: $report${RESET}"
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
  if [[ -z "$latest" ]]; then echo "${RED}No backup found.${RESET}"; pause; return; fi
  echo "Latest backup: $latest"; read -r -p "Restore this backup? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  [[ -f "$latest/sources.list" ]] && cp -a "$latest/sources.list" /etc/apt/sources.list
  if [[ -d "$latest/sources.list.d" ]]; then rm -rf /etc/apt/sources.list.d; cp -a "$latest/sources.list.d" /etc/apt/sources.list.d; fi
  echo "${GREEN}APT sources restored.${RESET}"; pause
}

apply_mirror(){
  local line="$1" name country distro url; IFS='|' read -r name country distro url _ <<< "$line"
  if [[ "$distro" != "$OS_ID" ]]; then echo "${RED}ERROR: Selected mirror is for $distro but this system is $OS_ID.${RESET}"; return 1; fi
  local backup; backup=$(backup_sources); echo "Backup created: $backup"
  local smart_file="/etc/apt/sources.list.d/99-smart-mirror.list" components="main restricted universe multiverse"
  [[ "$OS_ID" == "debian" ]] && components="main contrib non-free non-free-firmware"
  cat > "$smart_file" <<EOF
# Managed by Linux Smart Mirror Manager
# Mirror: $name
# URL: $url
# Generated: $(date)
deb ${url%/}/ $CODENAME $components
EOF
  echo "Mirror configuration written to: $smart_file"; echo "Running apt-get update..."
  if apt-get update; then echo "${GREEN}Mirror applied successfully: $name${RESET}"; else echo "${RED}apt-get update failed. Backup: $backup${RESET}"; return 1; fi
}

apply_best(){
  if [[ ! -s "$LAST_REPORT_FILE" ]]; then echo "${RED}No test report found. Run a mirror test first.${RESET}"; pause; return; fi
  local best_line; best_line=$(awk -F'|' '$1=="OK" {print; exit}' "$LAST_REPORT_FILE")
  if [[ -z "$best_line" ]]; then echo "${RED}No successful mirror found in the last report.${RESET}"; pause; return; fi
  echo "Best mirror from last test:"; echo "$best_line"; echo; read -r -p "Apply this mirror to APT? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  apply_mirror "$best_line"; pause
}

main_menu(){
  while true; do
    show_header
    echo "${GREEN}${BOLD}  1)${RESET} Select mirrors manually"
    echo "${GREEN}${BOLD}  2)${RESET} Test all Iranian mirrors"
    echo "${BLUE}${BOLD}  3)${RESET} Test all foreign mirrors"
    echo "${MAGENTA}${BOLD}  4)${RESET} Test all Iranian + foreign mirrors"
    echo "${CYAN}${BOLD}  5)${RESET} Test currently selected mirrors"
    echo "${WHITE}${BOLD}  6)${RESET} Show available mirrors"
    echo "${YELLOW}${BOLD}  7)${RESET} Apply best mirror from last test"
    echo "${YELLOW}${BOLD}  8)${RESET} Restore latest APT backup"
    echo "${RED}${BOLD}  0)${RESET} Exit"
    echo
    read -r -p "${BOLD}Select an option: ${RESET}" choice
    case "$choice" in
      1) manual_select;;
      2) load_mirrors iran; test_selected; pause;;
      3) load_mirrors foreign; test_selected; pause;;
      4) load_mirrors all; test_selected; pause;;
      5) test_selected; pause;;
      6) show_available; pause;;
      7) apply_best;;
      8) restore_backup;;
      0) echo "${GREEN}Goodbye.${RESET}"; exit 0;;
      *) echo "${RED}Invalid option.${RESET}"; pause;;
    esac
  done
}

main_menu

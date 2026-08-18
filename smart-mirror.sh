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

[[ $EUID -eq 0 ]] || { echo "ERROR: Run as root."; exit 1; }
for cmd in curl awk sed date readlink mktemp sort head tr; do
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
[[ -n "$CODENAME" && "$CODENAME" != "unknown" ]] || CODENAME="$(lsb_release -sc 2>/dev/null || true)"
[[ -n "$CODENAME" ]] || CODENAME="unknown"

if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; WHITE=''
fi

normalize_distro() {
  local x="${1,,}"
  case "$x" in
    ubuntu|ubuntu-server) echo "ubuntu" ;;
    debian) echo "debian" ;;
    *) echo "$x" ;;
  esac
}
TARGET_DISTRO="$(normalize_distro "$OS_ID")"

declare -a ALL_LINES SELECTED_LINES
SELECTED_MODE="none"
LAST_RESULTS_FILE=""
LAST_TEST_COUNT=0

load_all() {
  mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')
}
load_all

pause() { read -r -p $'\nPress Enter to continue...' _; }

show_header() {
  clear 2>/dev/null || true
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  echo "${CYAN}${BOLD}              Linux Smart Mirror Manager${RESET}"
  echo "${CYAN}${BOLD}==============================================================${RESET}"
  printf "${WHITE}OS       :${RESET} %-10s  ${WHITE}Codename :${RESET} %s\n" "$OS_ID" "$CODENAME"
  printf "${WHITE}Mirrors  :${RESET} ${GREEN}%d${RESET}       ${WHITE}Selected :${RESET} ${YELLOW}%d${RESET}\n" "${#ALL_LINES[@]}" "${#SELECTED_LINES[@]}"
  [[ "$SELECTED_MODE" != "none" ]] && printf "${WHITE}Selection:${RESET} ${MAGENTA}%s${RESET}\n" "$SELECTED_MODE"
  echo "${CYAN}==============================================================${RESET}"
  echo
}

line_is_compatible() {
  local distro
  IFS='|' read -r _ _ distro _ _ <<< "$1"
  [[ "$(normalize_distro "$distro")" == "$TARGET_DISTRO" ]]
}

load_mirrors() {
  local mode="$1"
  case "$mode" in
    iran)
      mapfile -t SELECTED_LINES < <(awk -F'|' -v os="$TARGET_DISTRO" 'NF>=4 && $1 !~ /^#/ {d=tolower($3); if ((d=="ubuntu" && os=="ubuntu") || (d=="debian" && os=="debian")) print}' "$IRAN_FILE")
      SELECTED_MODE="All Iranian $TARGET_DISTRO mirrors"
      ;;
    foreign)
      mapfile -t SELECTED_LINES < <(awk -F'|' -v os="$TARGET_DISTRO" 'NF>=4 && $1 !~ /^#/ {d=tolower($3); if ((d=="ubuntu" && os=="ubuntu") || (d=="debian" && os=="debian")) print}' "$FOREIGN_FILE")
      SELECTED_MODE="All foreign $TARGET_DISTRO mirrors"
      ;;
    all)
      mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' -v os="$TARGET_DISTRO" 'NF>=4 && $1 !~ /^#/ {d=tolower($3); if ((d=="ubuntu" && os=="ubuntu") || (d=="debian" && os=="debian")) print}')
      SELECTED_MODE="All Iranian + foreign $TARGET_DISTRO mirrors"
      ;;
  esac
  printf "${GREEN}Selected %d compatible %s mirror(s).${RESET}\n" "${#SELECTED_LINES[@]}" "$TARGET_DISTRO"
}

show_available() {
  echo "${CYAN}${BOLD}Available mirrors for $TARGET_DISTRO${RESET}"
  echo
  printf "${BOLD}%-4s %-27s %-8s %-10s %s${RESET}\n" "No." "Name" "Region" "Distro" "URL"
  echo "-------------------------------------------------------------------------------"
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    IFS='|' read -r name country distro url _ <<< "$line"
    if [[ "$(normalize_distro "$distro")" == "$TARGET_DISTRO" ]]; then
      if [[ "$country" == "IR" || "$country" == "IRAN" ]]; then
        printf "${GREEN}%-4d${RESET} %-27s ${GREEN}%-8s${RESET} %-10s %s\n" "$i" "$name" "$country" "$distro" "$url"
      else
        printf "${BLUE}%-4d${RESET} %-27s ${BLUE}%-8s${RESET} %-10s %s\n" "$i" "$name" "$country" "$distro" "$url"
      fi
    else
      printf "${DIM}%-4d %-27s %-8s %-10s %s${RESET}\n" "$i" "$name" "$country" "$distro" "$url"
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
      ((a>b)) && { t=$a; a=$b; b=$t; }
      for ((i=a;i<=b;i++)); do
        ((i>=1 && i<=${#ALL_LINES[@]})) || continue
        line_is_compatible "${ALL_LINES[i-1]}" && SELECTED_LINES+=("${ALL_LINES[i-1]}")
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      i=$token
      if ((i>=1 && i<=${#ALL_LINES[@]})) && line_is_compatible "${ALL_LINES[i-1]}"; then SELECTED_LINES+=("${ALL_LINES[i-1]}"); fi
    fi
  done
  SELECTED_MODE="Manual selection"
  printf "${GREEN}Selected %d compatible mirror(s).${RESET}\n" "${#SELECTED_LINES[@]}"
  pause
}

progress() {
  local current="$1" total="$2" width=40 percent filled empty
  ((total<1)) && total=1
  percent=$((current*100/total)); filled=$((percent*width/100)); empty=$((width-filled))
  printf "\r${CYAN}[${RESET}"
  ((filled>0)) && printf '%*s' "$filled" '' | tr ' ' '#'
  ((empty>0)) && printf '%*s' "$empty" '' | tr ' ' '-'
  printf "${CYAN}]${RESET} ${BOLD}%3d%%${RESET}  %d/%d" "$percent" "$current" "$total"
}

check_mirror() {
  local line="$1" name country distro url
  IFS='|' read -r name country distro url _ <<< "$line"
  local norm_distro base release_url speed_url http_code start end latency speed_raw speed_mb
  norm_distro="$(normalize_distro "$distro")"
  if [[ "$norm_distro" != "$TARGET_DISTRO" ]]; then
    printf 'N/A|%s|%s|%s|%s|0|0|INCOMPATIBLE\n' "$name" "$country" "$distro" "$url"; return
  fi
  base="${url%/}"; release_url="$base/dists/$CODENAME/Release"
  start=$(date +%s%N)
  http_code="$(curl -4 -L --fail --silent --max-time 12 -o /dev/null -w '%{http_code}' "$release_url" 2>/dev/null || true)"
  end=$(date +%s%N); latency=$(( (end-start)/1000000 )); ((latency<1)) && latency=1
  if [[ "$http_code" != "200" ]]; then
    printf 'FAIL|%s|%s|%s|%s|%s|0|HTTP_%s\n' "$name" "$country" "$distro" "$url" "$latency" "$http_code"; return
  fi
  speed_url="$base/dists/$CODENAME/main/binary-amd64/Packages.gz"
  speed_raw="$(curl -4 -L --fail --silent --max-time 25 -o /dev/null -w '%{speed_download}' "$speed_url" 2>/dev/null || echo 0)"
  if awk -v s="$speed_raw" 'BEGIN{exit !(s>0)}'; then
    speed_mb="$(awk -v s="$speed_raw" 'BEGIN{printf "%.2f",s/1048576}')"
    printf 'OK|%s|%s|%s|%s|%s|%s|OK\n' "$name" "$country" "$distro" "$url" "$latency" "$speed_mb"
  else
    printf 'OK|%s|%s|%s|%s|%s|0|RELEASE_OK_SPEED_UNAVAILABLE\n' "$name" "$country" "$distro" "$url" "$latency"
  fi
}

test_selected() {
  local total="${#SELECTED_LINES[@]}" current=0 line raw report
  local status name country distro url latency speed code ok=0 fail=0 na=0 idx=1
  ((total>0)) || { echo "${RED}No mirrors selected.${RESET}"; pause; return; }
  raw="$(mktemp)"; report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt"
  echo; echo "${CYAN}${BOLD}==================== MIRROR TEST ====================${RESET}"
  printf "Target: ${WHITE}%s %s${RESET}   Mirrors: ${WHITE}%d${RESET}\n\n" "$TARGET_DISTRO" "$CODENAME" "$total"
  for line in "${SELECTED_LINES[@]}"; do
    ((current++)); progress "$current" "$total"; check_mirror "$line" >> "$raw"
  done
  printf "\n\n"
  while IFS='|' read -r status name country distro url latency speed code; do
    case "$status" in OK) ((ok++));; FAIL) ((fail++));; N/A) ((na++));; esac
  done < "$raw"
  echo "${CYAN}${BOLD}==================== FINAL RESULT ===================${RESET}"
  printf "  Total: ${WHITE}%d${RESET}   ${GREEN}OK: %d${RESET}   ${RED}FAIL: %d${RESET}   ${YELLOW}N/A: %d${RESET}\n\n" "$total" "$ok" "$fail" "$na"
  printf "${BOLD}%-4s %-27s %-7s %-8s %-12s %-12s %-22s${RESET}\n" "#" "Mirror" "Region" "Status" "Latency" "Speed" "Details"
  echo "-------------------------------------------------------------------------------------------------------"
  while IFS='|' read -r status name country distro url latency speed code; do
    case "$status" in
      OK) printf "${GREEN}%-4d %-27s %-7s %-8s %-12s %-12s %-22s${RESET}\n" "$idx" "$name" "$country" "OK" "${latency} ms" "${speed} MB/s" "$code" ;;
      FAIL) printf "${RED}%-4d %-27s %-7s %-8s %-12s %-12s %-22s${RESET}\n" "$idx" "$name" "$country" "FAILED" "${latency} ms" "-" "$code" ;;
      N/A) printf "${YELLOW}%-4d %-27s %-7s %-8s %-12s %-12s %-22s${RESET}\n" "$idx" "$name" "$country" "N/A" "-" "-" "$code" ;;
    esac
    ((idx++))
  done < "$raw"
  echo "-------------------------------------------------------------------------------------------------------"
  echo "${BOLD}Fastest successful mirrors:${RESET}"
  awk -F'|' '$1=="OK" && $7>0' "$raw" | sort -t'|' -k7,7nr | head -5 | awk -F'|' '{printf "  %-27s %-7s %8s MB/s  %s ms\n",$2,$3,$7,$6}' || true
  {
    echo "Linux Smart Mirror Manager report"; echo "Date: $(date)"; echo "OS: $TARGET_DISTRO"; echo "Codename: $CODENAME"; echo "Total: $total | OK: $ok | FAIL: $fail | N/A: $na"; echo; cat "$raw"
  } > "$report"
  cp -f "$report" "$LAST_REPORT_FILE"
  echo; echo "${DIM}Report: $report${RESET}"; echo "${CYAN}=======================================================${RESET}"
  LAST_RESULTS_FILE="$raw"; LAST_TEST_COUNT="$total"; pause
}

backup_sources() {
  local stamp="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$stamp"
  [[ -f /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$stamp/"
  [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$stamp/"
  echo "$stamp"
}

apply_best() {
  if [[ -z "$LAST_RESULTS_FILE" || ! -f "$LAST_RESULTS_FILE" ]]; then echo "${YELLOW}No test results available in this session.${RESET}"; [[ -f "$LAST_REPORT_FILE" ]] && echo "Last report: $LAST_REPORT_FILE"; pause; return; fi
  local best status name country distro url latency speed code backup source_file tmp
  best="$(awk -F'|' '$1=="OK" && $7>0 {print}' "$LAST_RESULTS_FILE" | sort -t'|' -k7,7nr | head -1)"
  [[ -n "$best" ]] || { echo "${RED}No successful mirror found.${RESET}"; pause; return; }
  IFS='|' read -r status name country distro url latency speed code <<< "$best"
  echo "${GREEN}${BOLD}Best mirror:${RESET} $name"; echo "URL   : $url"; echo "Speed : ${speed} MB/s"; echo "Ping  : ${latency} ms"; echo
  read -r -p "Apply this mirror to APT? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  backup="$(backup_sources)"; source_file="/etc/apt/sources.list"; tmp="$(mktemp)"
  if [[ "$TARGET_DISTRO" == "ubuntu" ]]; then
    { echo "deb $url $CODENAME main restricted universe multiverse"; echo "deb $url $CODENAME-updates main restricted universe multiverse"; echo "deb $url $CODENAME-security main restricted universe multiverse"; } > "$tmp"
  else
    echo "deb $url $CODENAME main contrib non-free non-free-firmware" > "$tmp"
  fi
  cp "$tmp" "$source_file"; rm -f "$tmp"; echo "${GREEN}APT sources updated.${RESET}"; echo "Backup: $backup"; echo
  read -r -p "Run apt-get update now? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] && apt-get update; pause
}

restore_backup() {
  local latest; latest="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
  [[ -n "$latest" ]] || { echo "${RED}No backup found.${RESET}"; pause; return; }
  echo "Latest backup: $latest"; read -r -p "Restore this backup? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  [[ -f "$latest/sources.list" ]] && cp -a "$latest/sources.list" /etc/apt/sources.list
  if [[ -d "$latest/sources.list.d" ]]; then rm -rf /etc/apt/sources.list.d; cp -a "$latest/sources.list.d" /etc/apt/sources.list.d; fi
  echo "${GREEN}APT backup restored.${RESET}"; pause
}

while true; do
  show_header
  echo "  ${GREEN}1)${RESET} Select mirrors manually"
  echo "  ${GREEN}2)${RESET} Test all Iranian mirrors"
  echo "  ${GREEN}3)${RESET} Test all foreign mirrors"
  echo "  ${GREEN}4)${RESET} Test all Iranian + foreign mirrors"
  echo "  ${GREEN}5)${RESET} Test currently selected mirrors"
  echo "  ${GREEN}6)${RESET} Show available mirrors"
  echo "  ${GREEN}7)${RESET} Apply best mirror from last test"
  echo "  ${GREEN}8)${RESET} Restore latest APT backup"
  echo "  ${RED}0)${RESET} Exit"
  echo; read -r -p "Select an option: " option
  case "$option" in
    1) manual_select ;; 2) load_mirrors iran; test_selected ;; 3) load_mirrors foreign; test_selected ;; 4) load_mirrors all; test_selected ;; 5) test_selected ;; 6) show_available; pause ;; 7) apply_best ;; 8) restore_backup ;; 0) exit 0 ;; *) echo "${RED}Invalid option.${RESET}"; sleep 1 ;;
  esac
done

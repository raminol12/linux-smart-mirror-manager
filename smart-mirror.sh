#!/usr/bin/env bash
set -uo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
IRAN_FILE="$BASE_DIR/mirrors-iran.txt"
FOREIGN_FILE="$BASE_DIR/mirrors-foreign.txt"
DATA_DIR="/root/smart-mirror"
REPORT_DIR="$DATA_DIR/reports"
BACKUP_DIR="$DATA_DIR/backups"
mkdir -p "$REPORT_DIR" "$BACKUP_DIR"

[[ $EUID -eq 0 ]] || { echo "ERROR: Run as root."; exit 1; }
for c in curl awk sed date readlink realpath mktemp sort head tr; do
  command -v "$c" >/dev/null 2>&1 || { echo "ERROR: $c is required."; exit 1; }
done
[[ -r "$IRAN_FILE" && -r "$FOREIGN_FILE" ]] || { echo "ERROR: Mirror list files not found in $BASE_DIR"; exit 1; }

OS_ID="unknown"
CODENAME="unknown"
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  CODENAME="${VERSION_CODENAME:-}"
fi
[[ -n "$CODENAME" ]] || CODENAME="$(lsb_release -sc 2>/dev/null || true)"

if [[ -t 1 ]]; then
  R=$'\033[0m'; B=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; DIM=$'\033[2m'
else
  R=''; B=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; BLUE=''; MAGENTA=''; DIM=''
fi

norm() {
  case "${1,,}" in
    ubuntu|ubuntu-server) echo ubuntu ;;
    debian) echo debian ;;
    *) echo "${1,,}" ;;
  esac
}

TARGET="$(norm "$OS_ID")"
declare -a ALL_LINES SELECTED_LINES
SELECTED_LINES=()
SELECTION_LABEL="None"
LAST_RESULTS=""
LAST_REPORT=""

load_all() {
  mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')
}
load_all

pause() { read -r -p $'\nPress Enter to continue...' _; }

header() {
  clear 2>/dev/null || true
  echo "${CYAN}${B}==============================================================${R}"
  echo "${CYAN}${B}              Linux Smart Mirror Manager${R}"
  echo "${CYAN}${B}==============================================================${R}"
  printf "OS       : %-10s  Codename : %s\n" "$OS_ID" "$CODENAME"
  printf "Mirrors  : ${GREEN}%d${R}       Selected : ${YELLOW}%d${R}\n" "${#ALL_LINES[@]}" "${#SELECTED_LINES[@]}"
  echo "${CYAN}==============================================================${R}"
  echo
}

compatible() {
  local d
  IFS='|' read -r _ _ d _ _ <<< "$1"
  [[ "$(norm "$d")" == "$TARGET" ]]
}

select_mode() {
  local label="$1" file="$2"
  mapfile -t SELECTED_LINES < <(awk -F'|' -v os="$TARGET" 'NF>=4 && $1 !~ /^#/ {d=tolower($3); if ((os=="ubuntu" && d=="ubuntu") || (os=="debian" && d=="debian")) print}' "$file")
  SELECTION_LABEL="$label"
  printf "${GREEN}Selected %d compatible mirror(s).${R}\n" "${#SELECTED_LINES[@]}"
  pause
}

show_available() {
  echo "${CYAN}${B}Available compatible mirrors for $TARGET${R}"
  echo
  printf "${B}%-4s %-28s %-8s %-8s %s${R}\n" "No." "Mirror" "Region" "Distro" "URL"
  echo "--------------------------------------------------------------------------------"
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    IFS='|' read -r name country distro url _ <<< "$line"
    if compatible "$line"; then
      printf "${GREEN}%-4d${R} %-28s %-8s %-8s %s\n" "$i" "$name" "$country" "$distro" "$url"
    else
      printf "${DIM}%-4d %-28s %-8s %-8s %s${R}\n" "$i" "$name" "$country" "$distro" "$url"
    fi
    ((i++))
  done
  pause
}

manual() {
  echo "${CYAN}${B}Compatible mirror list${R}"
  local i=1 line name country distro url
  for line in "${ALL_LINES[@]}"; do
    if compatible "$line"; then
      IFS='|' read -r name country distro url _ <<< "$line"
      printf "%3d) %-28s %-8s %s\n" "$i" "$name" "$country" "$url"
    fi
    ((i++))
  done
  echo
  echo "${YELLOW}Example: 1,3,5-7${R}"
  read -r -p "Enter mirror numbers: " input
  SELECTED_LINES=()
  local token a b j tmp
  IFS=',' read -ra toks <<< "$input"
  for token in "${toks[@]}"; do
    token="${token//[[:space:]]/}"
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
      ((a>b)) && { tmp=$a; a=$b; b=$tmp; }
      for ((j=a;j<=b;j++)); do
        ((j>=1 && j<=${#ALL_LINES[@]})) || continue
        compatible "${ALL_LINES[j-1]}" && SELECTED_LINES+=("${ALL_LINES[j-1]}")
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      j=$token
      ((j>=1 && j<=${#ALL_LINES[@]})) && compatible "${ALL_LINES[j-1]}" && SELECTED_LINES+=("${ALL_LINES[j-1]}")
    fi
  done
  SELECTION_LABEL="Manual"
  echo "${GREEN}Selected ${#SELECTED_LINES[@]} mirror(s).${R}"
  pause
}

progress() {
  local n=$1 total=$2 width=40 pct fill empty
  ((total<1)) && total=1
  pct=$((n*100/total)); fill=$((pct*width/100)); empty=$((width-fill))
  printf "\r${CYAN}[${R}"
  if ((fill>0)); then printf '%*s' "$fill" '' | tr ' ' '#'; fi
  if ((empty>0)); then printf '%*s' "$empty" '' | tr ' ' '-'; fi
  printf "${CYAN}]${R} ${B}%3d%%${R}  %d/%d" "$pct" "$n" "$total"
}

check() {
  local line="$1" name country distro url base release latency_start latency_end latency code speed_raw speed
  IFS='|' read -r name country distro url _ <<< "$line"
  [[ "$(norm "$distro")" == "$TARGET" ]] || {
    printf 'N/A|%s|%s|%s|-|-|INCOMPATIBLE\n' "$name" "$country" "$distro"
    return
  }
  base="${url%/}"
  release="$base/dists/$CODENAME/Release"
  latency_start=$(date +%s%N)
  code=$(curl -4 -L --fail --silent --show-error --max-time 12 -o /dev/null -w '%{http_code}' "$release" 2>/dev/null || true)
  latency_end=$(date +%s%N)
  latency=$(( (latency_end-latency_start)/1000000 )); ((latency<1)) && latency=1
  [[ "$code" == 200 ]] || {
    printf 'FAIL|%s|%s|%s|%s ms|-|HTTP_%s\n' "$name" "$country" "$distro" "$latency" "$code"
    return
  }
  speed_raw=$(curl -4 -L --fail --silent --max-time 25 -o /dev/null -w '%{speed_download}' "$base/dists/$CODENAME/main/binary-amd64/Packages.gz" 2>/dev/null || echo 0)
  if awk -v s="$speed_raw" 'BEGIN{exit !(s>0)}'; then
    speed=$(awk -v s="$speed_raw" 'BEGIN{printf "%.2f",s/1048576}')
    printf 'OK|%s|%s|%s|%s ms|%s MB/s|OK\n' "$name" "$country" "$distro" "$latency" "$speed"
  else
    printf 'OK|%s|%s|%s|%s ms|-|RELEASE_OK_SPEED_UNAVAILABLE\n' "$name" "$country" "$distro" "$latency"
  fi
}

test_mirrors() {
  local total=${#SELECTED_LINES[@]} n=0 raw report status name country distro lat speed detail ok=0 fail=0 na=0 idx=1
  ((total>0)) || { echo "${RED}No mirrors selected.${R}"; pause; return; }
  raw=$(mktemp)
  report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt"
  echo
  echo "${CYAN}${B}==================== MIRROR TEST ====================${R}"
  echo "Target: $TARGET $CODENAME   Mirrors: $total"
  echo
  for line in "${SELECTED_LINES[@]}"; do
    ((n++)); progress "$n" "$total"; check "$line" >> "$raw"
  done
  printf "\n\n"
  while IFS='|' read -r status _ _ _ _ _ _; do
    case "$status" in OK) ((ok++));; FAIL) ((fail++));; N/A) ((na++));; esac
  done < "$raw"
  echo "${CYAN}${B}==================== FINAL RESULT ===================${R}"
  printf "Total: %d   ${GREEN}OK: %d${R}   ${RED}FAIL: %d${R}   ${YELLOW}N/A: %d${R}\n\n" "$total" "$ok" "$fail" "$na"
  printf "${B}%-4s %-28s %-8s %-9s %-12s %-13s %-28s${R}\n" "#" "Mirror" "Region" "Status" "Latency" "Speed" "Details"
  echo "----------------------------------------------------------------------------------------------------------------"
  while IFS='|' read -r status name country distro lat speed detail; do
    case "$status" in OK) c=$GREEN; s=OK;; FAIL) c=$RED; s=FAILED;; N/A) c=$YELLOW; s=N/A;; esac
    printf "${c}%-4d %-28s %-8s %-9s %-12s %-13s %-28s${R}\n" "$idx" "$name" "$country" "$s" "$lat" "$speed" "$detail"
    ((idx++))
  done < "$raw"
  echo "----------------------------------------------------------------------------------------------------------------"
  echo "${B}Fastest successful mirrors:${R}"
  awk -F'|' '$1=="OK" && $6!="-" {gsub(/ MB\/s/,"",$6); printf "%s|%s|%s|%s\n",$2,$3,$6,$5}' "$raw" | sort -t'|' -k3,3nr | head -5 | awk -F'|' '{printf "  %-28s %-8s %-10s %-10s\n",$1,$2,$3,$4}' || true
  {
    echo "Linux Smart Mirror Manager"
    echo "Target: $TARGET $CODENAME"
    echo "Total: $total OK: $ok FAIL: $fail N/A: $na"
    cat "$raw"
  } > "$report"
  LAST_RESULTS="$raw"; LAST_REPORT="$report"
  echo
  echo "${DIM}Report: $report${R}"
  echo "${CYAN}=======================================================${R}"
  pause
}

show_best() {
  [[ -n "$LAST_RESULTS" && -f "$LAST_RESULTS" ]] || { echo "${YELLOW}No test results in this session.${R}"; [[ -n "$LAST_REPORT" ]] && echo "Report: $LAST_REPORT"; pause; return; }
  echo "${CYAN}${B}Best successful mirrors${R}"
  awk -F'|' '$1=="OK" && $6!="-" {gsub(/ MB\/s/,"",$6); printf "%s|%s|%s|%s\n",$2,$3,$6,$5}' "$LAST_RESULTS" | sort -t'|' -k3,3nr | head -5 | awk -F'|' '{printf "%d) %-28s %-8s %8s MB/s  %s\n",NR,$1,$2,$3,$4}'
  pause
}

restore_latest() {
  local latest
  latest=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | tail -1)
  if [[ -z "$latest" ]]; then echo "${YELLOW}No APT backup found.${R}"; else echo "Latest backup: $latest"; echo "Restore can be performed manually from this directory to avoid changing APT unexpectedly."; fi
  pause
}

while true; do
  header
  echo "  ${GREEN}1)${R} Select mirrors manually"
  echo "  ${GREEN}2)${R} Test all Iranian mirrors"
  echo "  ${GREEN}3)${R} Test all foreign mirrors"
  echo "  ${GREEN}4)${R} Test all Iranian + foreign mirrors"
  echo "  ${GREEN}5)${R} Test currently selected mirrors"
  echo "  ${GREEN}6)${R} Show available mirrors"
  echo "  ${GREEN}7)${R} Show best mirrors from last test"
  echo "  ${GREEN}8)${R} Restore latest APT backup"
  echo "  ${GREEN}0)${R} Exit"
  echo
  read -r -p "Select an option: " opt
  case "$opt" in
    1) manual ;;
    2) select_mode "All Iranian $TARGET mirrors" "$IRAN_FILE"; test_mirrors ;;
    3) select_mode "All foreign $TARGET mirrors" "$FOREIGN_FILE"; test_mirrors ;;
    4) mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' -v os="$TARGET" 'NF>=4 && $1 !~ /^#/ {d=tolower($3); if ((os=="ubuntu" && d=="ubuntu") || (os=="debian" && d=="debian")) print}'); SELECTION_LABEL="All Iranian + foreign $TARGET mirrors"; printf "${GREEN}Selected %d compatible mirror(s).${R}\n" "${#SELECTED_LINES[@]}"; test_mirrors ;;
    5) test_mirrors ;;
    6) show_available ;;
    7) show_best ;;
    8) restore_latest ;;
    0) exit 0 ;;
    *) echo "${RED}Invalid option.${R}"; pause ;;
  esac
done

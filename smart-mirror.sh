#!/usr/bin/env bash
set -uo pipefail

# Resolve the real script path so execution through /usr/local/bin/smart-mirror
# always finds the mirror lists beside the actual script.
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
for cmd in curl awk sed find date readlink; do command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required."; exit 1; }; done
command -v apt-get >/dev/null 2>&1 || { echo "ERROR: apt-get was not found."; exit 1; }

if [[ ! -f "$IRAN_FILE" || ! -f "$FOREIGN_FILE" ]]; then
  echo "ERROR: Mirror list files were not found."
  echo "Expected directory: $BASE_DIR"
  echo "Iranian list: $IRAN_FILE"
  echo "Foreign list: $FOREIGN_FILE"
  exit 1
fi

OS_ID="unknown"; CODENAME="unknown"
if [[ -r /etc/os-release ]]; then source /etc/os-release; OS_ID="${ID:-unknown}"; CODENAME="${VERSION_CODENAME:-}"; fi
if [[ -z "$CODENAME" || "$CODENAME" == "unknown" ]]; then CODENAME="$(lsb_release -sc 2>/dev/null || true)"; fi

load_all(){
  mapfile -t ALL_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" 2>/dev/null | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}')
}
load_all

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
  case "$1" in
    iran) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$IRAN_FILE");;
    foreign) mapfile -t SELECTED_LINES < <(awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}' "$FOREIGN_FILE");;
    all) mapfile -t SELECTED_LINES < <(cat "$IRAN_FILE" "$FOREIGN_FILE" | awk -F'|' 'NF>=4 && $1 !~ /^#/ {print}');;
    *) SELECTED_LINES=();;
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
  SELECTED_LINES=(); IFS=',' read -ra tokens <<< "$input"
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

mirror_release_url(){ printf '%s/dists/%s/Release' "${1%/}" "$CODENAME"; }

check_mirror(){
  local line="$1"
  IFS='|' read -r name country distro url _ <<< "$line"
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

progress_bar(){
  local current="$1" total="$2" width=38 filled empty percent
  ((total<1)) && total=1
  percent=$((current*100/total)); filled=$((current*width/total)); empty=$((width-filled))
  printf "["
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%*s' "$empty" '' | tr ' ' '-'
  printf "] %3d%%" "$percent"
}

stage_line(){
  local label="$1" state="$2"
  case "$state" in
    RUN) printf "  [..] %s\n" "$label";;
    OK) printf "  [OK] %s\n" "$label";;
    FAIL) printf "  [XX] %s\n" "$label";;
    SKIP) printf "  [--] %s\n" "$label";;
  esac
}

test_selected(){
  local report="$REPORT_DIR/mirror-report-$(date +%Y%m%d-%H%M%S).txt" raw="$(mktemp)"
  local total=${#SELECTED_LINES[@]} current=0 line result status name country distro url latency speed code
  local ok=0 fail=0 skip=0

  echo ""
  echo "==================== MIRROR TEST ===================="
  echo "Target OS       : $OS_ID $CODENAME"
  echo "Mirrors to test : $total"
  echo "Test stages     : Connectivity -> Release -> Speed -> Result"
  echo "======================================================="
  echo ""

  : > "$raw"
  for line in "${SELECTED_LINES[@]}"; do
    ((current++))
    IFS='|' read -r name country distro url _ <<< "$line"
    echo ""
    printf "Mirror %d/%d  " "$current" "$total"; progress_bar "$current" "$total"; echo ""
    echo "  Name   : $name"
    echo "  Region : $country"
    echo "  URL    : $url"
    echo "  ----------------------------------------------------"
    stage_line "Checking operating-system compatibility" RUN
    if [[ "$distro" != "$OS_ID" ]]; then
      stage_line "Checking operating-system compatibility" SKIP
      stage_line "Connectivity" SKIP
      stage_line "Release file" SKIP
      stage_line "Download speed" SKIP
      result="SKIP|$name|$country|$distro|$url|0|0|DISTRO"
      ((skip++))
      echo "$result" >> "$raw"
      continue
    fi
    stage_line "Checking operating-system compatibility" OK
    stage_line "Connectivity / HTTP" RUN
    result="$(check_mirror "$line")"
    IFS='|' read -r status name country distro url latency speed code <<< "$result"
    if [[ "$status" == "OK" ]]; then
      stage_line "Connectivity / HTTP" OK
      stage_line "Release file: $CODENAME/Release" OK
      stage_line "Download speed" OK
      printf "  [OK] Result: %s | Latency: %sms | Speed: %s MB/s\n" "$status" "$latency" "$speed"
      ((ok++))
    else
      stage_line "Connectivity / HTTP" FAIL
      stage_line "Release file: $CODENAME/Release" FAIL
      stage_line "Download speed" FAIL
      printf "  [XX] Result: %s | HTTP: %s | Latency: %sms\n" "$status" "$code" "$latency"
      ((fail++))
    fi
    echo "$result" >> "$raw"
  done

  {
    echo "Linux Smart Mirror Manager report"
    echo "Date: $(date)"
    echo "OS: $OS_ID"
    echo "Codename: $CODENAME"
    echo "Selected: $total"
    echo "OK: $ok | FAIL: $fail | SKIP: $skip"
    echo
    sort -t'|' -k7,7nr "$raw"
  } > "$report"
  cp -f "$report" "$LAST_REPORT_FILE"

  echo ""
  echo "======================================================="
  echo "                    TEST COMPLETE"
  echo "======================================================="
  printf "  Total tested : %d\n" "$total"
  printf "  Successful   : %d\n" "$ok"
  printf "  Failed       : %d\n" "$fail"
  printf "  Skipped      : %d\n" "$skip"
  echo "-------------------------------------------------------"
  echo "  Fastest successful mirrors:"
  awk -F'|' '$1=="OK" {printf "  %-27s %8s MB/s  %sms\n",$2,$7,$6}' "$raw" | head -10
  echo "-------------------------------------------------------"
  echo "  Report: $report"
  echo "======================================================="
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
  if [[ -z "$latest" ]]; then echo "No backup found."; pause; return; fi
  echo "Latest backup: $latest"; read -r -p "Restore this backup? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  [[ -f "$latest/sources.list" ]] && cp -a "$latest/sources.list" /etc/apt/sources.list
  if [[ -d "$latest/sources.list.d" ]]; then rm -rf /etc/apt/sources.list.d; cp -a "$latest/sources.list.d" /etc/apt/sources.list.d; fi
  echo "APT sources restored."; pause
}

apply_mirror(){
  local line="$1" name country distro url; IFS='|' read -r name country distro url _ <<< "$line"
  if [[ "$distro" != "$OS_ID" ]]; then echo "ERROR: Selected mirror is for $distro but this system is $OS_ID."; return 1; fi
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
  if apt-get update; then echo "Mirror applied successfully: $name"; else echo "apt-get update failed. Backup: $backup"; return 1; fi
}

apply_best(){
  if [[ ! -s "$LAST_REPORT_FILE" ]]; then echo "No test report found. Run a mirror test first."; pause; return; fi
  local best_line; best_line=$(awk -F'|' '$1=="OK" {print; exit}' "$LAST_REPORT_FILE")
  if [[ -z "$best_line" ]]; then echo "No successful mirror found in the last report."; pause; return; fi
  echo "Best mirror from last test:"; echo "$best_line"; echo; read -r -p "Apply this mirror to APT? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return
  apply_mirror "$best_line"; pause
}

manual_test(){
  show_available; echo; read -r -p "Select mirrors (example: 1,3,5-8): " input; parse_selection "$input"
  if ((${#SELECTED_LINES[@]} == 0)); then echo "No valid mirrors selected."; pause; return; fi
  test_selected; pause
}

category_test(){
  local mode="$1" label="$2"; load_mirrors "$mode"
  if ((${#SELECTED_LINES[@]} == 0)); then echo "No mirrors found for $label."; echo "Check: $BASE_DIR"; echo "Iranian list : $IRAN_FILE"; echo "Foreign list : $FOREIGN_FILE"; pause; return; fi
  echo "Selected: ${#SELECTED_LINES[@]} $label mirrors"; sleep 1; test_selected; pause
}

main_menu(){
  while true; do
    show_header
    echo "1) Test all Iranian mirrors"
    echo "2) Test all foreign mirrors"
    echo "3) Test all Iranian + foreign mirrors"
    echo "4) Test manually selected mirrors"
    echo "5) Show available mirrors"
    echo "6) Apply best mirror from last test"
    echo "7) Restore latest APT backup"
    echo "0) Exit"
    echo
    read -r -p "Select an option: " choice
    case "$choice" in
      1) category_test iran "Iranian";;
      2) category_test foreign "foreign";;
      3) category_test all "Iranian + foreign";;
      4) manual_test;;
      5) show_available; pause;;
      6) apply_best;;
      7) restore_backup;;
      0) exit 0;;
      *) echo "Invalid option."; pause;;
    esac
  done
}

main_menu

#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#              MOTOROLA ROM FLASHER
# ============================================================

# ============================================================
# STRONG TERMINAL COLORS
# ============================================================

BOLD=$'\033[1m'
RESET=$'\033[0m'
GREEN=$'\033[1;92m'
RED=$'\033[1;91m'
YELLOW=$'\033[1;93m'
CYAN=$'\033[1;96m'
BLUE=$'\033[1;94m'
WHITE=$'\033[1;97m'
GRAY=$'\033[1;90m'

# ============================================================
# NORMAL / COLORED OUTPUT
# ============================================================


rainbow_print() {
    printf '%s%s%s\n' "$CYAN" "$1" "$RESET"
}

rainbow_printf() {
    local message="$1"
    shift
    printf '%s%s%s' "$CYAN" "$(printf "$message" "$@")" "$RESET"
}

rainbow_prompt() {
    printf '%s%s%s' "$WHITE" "$1" "$RESET"
}

rainbow_progress() {
    local message="$1"
    printf '\r\033[K%s%s%s' "$BLUE" "$message" "$RESET"
}

rainbow_cat() {
    local file="$1"
    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s%s%s\n' "$WHITE" "$line" "$RESET"
    done < "$file"
}

# ============================================================
# FIXED COLORS
# ============================================================

green_print() {
    printf '%s%s%s\n' "$GREEN" "$1" "$RESET"
}

red_print() {
    printf '%s%s%s\n' "$RED" "$1" "$RESET"
}

warning() {
    printf '%s%s%s\n' "$YELLOW" "$1" "$RESET"
}

success() {
    printf '%sSuccessful ✅%s\n' "$GREEN" "$RESET"
}

failed() {
    printf '%sFailed ❌%s\n' "$RED" "$RESET"
}

# ============================================================
# DIRECTORIES
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

TOOLS_DIR="$HOME/android-tools"
TMP_DIR="$HOME/.motorola-flasher-tmp"

ADB_BIN=""
FASTBOOT_BIN=""

mkdir -p "$TOOLS_DIR" "$TMP_DIR"

# ============================================================
# DEVICE VARIABLES
# ============================================================

DSERIAL="N/A"
DMODEL="N/A"
DCODENAME="N/A"
DBATTERY="N/A"
DBATTERY_VOLTAGE="N/A"
DSLOT="N/A"
DBOOTLOADER="N/A"
DMODE="N/A"

STOCK_XML_PATH=""
STOCK_TEMP_DIR=""
STOCK_SOURCE_IS_ARCHIVE=0

# ============================================================
# BASIC FUNCTIONS
# ============================================================

clear_screen() {
    clear 2>/dev/null || printf '\033c'
}

pause_failure() {
    printf '\n'
    rainbow_prompt "Press Enter To Continue..."
    read -r
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

resolve_path() {
    local path="$1"

    case "$path" in
        /sdcard/*)
            printf '%s/storage/emulated/0%s\n' \
                "$HOME" "${path#/sdcard}"
            ;;

        /storage/emulated/0/*)
            printf '%s/storage/shared%s\n' \
                "$HOME" "${path#/storage/emulated/0}"
            ;;

        *)
            printf '%s\n' "$path"
            ;;
    esac
}

# ============================================================
# HEADER
# ============================================================

show_header() {
    clear_screen
    printf '%s╔══════════════════════════════════════╗%s\n' "$CYAN" "$RESET"
    printf '%s║       Motorola Rom Flasher           ║%s\n' "$CYAN" "$RESET"
    printf '%s║              By Jinwoo               ║%s\n' "$CYAN" "$RESET"
    printf '%s║                                      ║%s\n' "$CYAN" "$RESET"
    printf '%s║       Telegram: \033]8;;https://t.me/JNW_SG\033\\JNW_SG\033]8;;\033\\               ║%s\n' "$CYAN" "$RESET"
    printf '%s║                                      ║%s\n' "$CYAN" "$RESET"
    printf '%s╚══════════════════════════════════════╝%s\n' "$CYAN" "$RESET"
    printf '\n'
}

# ============================================================
# CLEANUP
# ============================================================

cleanup() {

    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"/* 2>/dev/null
    fi
}

trap cleanup EXIT INT TERM

# ============================================================
# TERMUX STORAGE
# ============================================================

setup_termux_storage() {
    if [ -d "$HOME/storage/shared" ]; then
        return 0
    fi

    warning "Termux Storage Access Is Not Configured."
    rainbow_print "Setting Up Termux Storage..."

    if command_exists termux-setup-storage; then
        termux-setup-storage >/dev/null 2>&1
        sleep 2
    fi

    if [ -d "$HOME/storage/shared" ]; then
        success
        return 0
    fi

    warning "Unable To Configure Termux Storage Automatically."
    return 1
}

# ============================================================
# PYTHON
# ============================================================

ensure_python() {
    if command_exists python || command_exists python3; then
        return 0
    fi

    rainbow_print "Python Not Found."
    rainbow_print "Installing Python..."

    pkg update -y >/dev/null 2>&1
    pkg install python -y >/dev/null 2>&1

    hash -r 2>/dev/null || true

    if command_exists python || command_exists python3; then
        success
        return 0
    fi

    failed
    return 1
}

# ============================================================
# CURL
# ============================================================

ensure_curl() {
    if command_exists curl; then
        return 0
    fi

    rainbow_print "Curl Not Found."
    rainbow_print "Installing Curl..."

    pkg update -y >/dev/null 2>&1
    pkg install curl -y >/dev/null 2>&1

    hash -r 2>/dev/null || true

    if command_exists curl; then
        success
        return 0
    fi

    failed
    return 1
}

# ============================================================
# 7-ZIP
# ============================================================

ensure_7zip() {
    if command_exists 7z; then
        return 0
    fi

    warning "7Z Archive Tool Not Found."
    rainbow_print "Installing Archive Extraction Tool..."

    pkg update -y >/dev/null 2>&1

    if ! pkg install p7zip -y >/dev/null 2>&1; then
        failed
        return 1
    fi

    hash -r 2>/dev/null || true

    if command_exists 7z; then
        success
        return 0
    fi

    failed
    return 1
}

# ============================================================
# ANDROID TOOLS DIRECTORY
# ============================================================

setup_android_tools_directory() {
    mkdir -p "$TOOLS_DIR"

    case ":$PATH:" in
        *":$TOOLS_DIR:"*)
            ;;
        *)
            export PATH="$TOOLS_DIR:$PATH"
            ;;
    esac
}

# ============================================================
# ADB / FASTBOOT INSTALL
# ============================================================

install_adb_fastboot() {
    warning "Adb/Fastboot Tools Not Found."
    rainbow_print "Installing Android Tools..."

    if ! command_exists curl; then
        ensure_curl || return 1
    fi

    if ! curl -s \
        https://raw.githubusercontent.com/offici5l/termux-adb-fastboot/main/install |
        bash; then

        failed
        return 1
    fi

    hash -r 2>/dev/null || true

    return 0
}

ensure_android_tools() {
    if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ]; then
        case ":$PATH:" in
            *":$PREFIX/bin:"*) ;;
            *) export PATH="$PREFIX/bin:$PATH" ;;
        esac
    fi

    local adb_path=""
    local fastboot_path=""

    if command_exists adb; then
        adb_path="$(command -v adb)"
    fi
    if command_exists fastboot; then
        fastboot_path="$(command -v fastboot)"
    fi

    if [ -z "$adb_path" ] || [ -z "$fastboot_path" ]; then
        install_adb_fastboot || return 1
        hash -r 2>/dev/null || true

        adb_path="$(command -v adb 2>/dev/null || true)"
        fastboot_path="$(command -v fastboot 2>/dev/null || true)"
    fi

    if [ -z "$adb_path" ] || [ -z "$fastboot_path" ]; then
        failed
        return 1
    fi

    ADB_BIN="$adb_path"
    FASTBOOT_BIN="$fastboot_path"

    return 0
}

# ============================================================
# ADB SERVER SETUP
# ============================================================

setup_adb_server() {
    if [ -z "$ADB_BIN" ] || [ ! -x "$ADB_BIN" ]; then
        return 1
    fi

    rainbow_print "Starting Adb Server..."

    "$ADB_BIN" kill-server >/dev/null 2>&1 || true
    sleep 0.5

    if ! "$ADB_BIN" start-server >/dev/null 2>&1; then
        failed
        red_print "Unable To Start Adb Server."
        return 1
    fi

    sleep 0.5

    "$ADB_BIN" devices >/dev/null 2>&1 || true

    green_print "Adb Server Ready. ✅"
    return 0
}

# ============================================================
# STARTUP SETUP
# ============================================================

startup_setup() {
    setup_termux_storage >/dev/null 2>&1 || true

    if ! ensure_python; then
        failed
        rainbow_print "Python Setup Failed."
        return 1
    fi

    if ! ensure_curl; then
        failed
        rainbow_print "Curl Setup Failed."
        return 1
    fi

    if ! ensure_7zip; then
        failed
        rainbow_print "7-Zip Setup Failed."
        return 1
    fi

    if ! ensure_android_tools; then
        failed
        rainbow_print "Android Tools Setup Failed."
        return 1
    fi

    if ! setup_adb_server; then
        return 1
    fi

    return 0
}

# ============================================================
# DEVICE INFO
# ============================================================

reset_device_info() {
    DSERIAL="N/A"
    DMODEL="N/A"
    DCODENAME="N/A"
    DBATTERY="N/A"
    DBATTERY_VOLTAGE="N/A"
    DSLOT="N/A"
    DBOOTLOADER="N/A"
    DMODE="N/A"
}

show_device_info() {
    printf '\n'

    rainbow_print "Device Information"
    rainbow_print "──────────────────────────────────────"

    [ "$DSERIAL" != "N/A" ] &&
        rainbow_print "Serial        : $DSERIAL"

    [ "$DMODEL" != "N/A" ] &&
        rainbow_print "Model         : $DMODEL"

    [ "$DCODENAME" != "N/A" ] &&
        rainbow_print "Codename      : $DCODENAME"

    [ "$DBATTERY" != "N/A" ] &&
        rainbow_print "Battery       : $DBATTERY"

    [ "$DBATTERY_VOLTAGE" != "N/A" ] &&
        rainbow_print "Voltage       : $DBATTERY_VOLTAGE"

    [ "$DSLOT" != "N/A" ] &&
        rainbow_print "Slot          : $DSLOT"

    [ "$DBOOTLOADER" != "N/A" ] &&
        rainbow_print "Bootloader    : $DBOOTLOADER"

    [ "$DMODE" != "N/A" ] &&
        rainbow_print "Mode          : $DMODE"

    rainbow_print "──────────────────────────────────────"
}

# ============================================================
# ADB DEVICE DETECTION
# ============================================================

detect_adb_device() {
    reset_device_info

    local serial

    serial="$("$ADB_BIN" get-serialno 2>/dev/null)"

    if [ -z "$serial" ] || [ "$serial" = "unknown" ]; then
        return 1
    fi

    DSERIAL="$serial"
    DMODE="ADB"

    DMODEL="$(
        "$ADB_BIN" shell getprop ro.product.model 2>/dev/null |
        tr -d '\r'
    )"

    DCODENAME="$(
        "$ADB_BIN" shell getprop ro.product.device 2>/dev/null |
        tr -d '\r'
    )"

    DBATTERY="$(
        "$ADB_BIN" shell dumpsys battery 2>/dev/null |
        awk -F': ' '/level:/ {print $2; exit}' |
        tr -d '\r'
    )"

    if [ -n "$DBATTERY" ]; then
        DBATTERY="${DBATTERY}%"
    else
        DBATTERY="N/A"
    fi

    DBATTERY_VOLTAGE="$(
        "$ADB_BIN" shell dumpsys battery 2>/dev/null |
        awk -F': ' '/voltage:/ {print $2; exit}' |
        tr -d '\r'
    )"

    if [ -n "$DBATTERY_VOLTAGE" ]; then
        DBATTERY_VOLTAGE="${DBATTERY_VOLTAGE} mV"
    else
        DBATTERY_VOLTAGE="N/A"
    fi

    DSLOT="$(
        "$ADB_BIN" shell getprop ro.boot.slot_suffix 2>/dev/null |
        tr -d '\r'
    )"

    [ -z "$DSLOT" ] && DSLOT="N/A"

    DBOOTLOADER="$(
        "$ADB_BIN" shell getprop ro.boot.flash.locked 2>/dev/null |
        tr -d '\r'
    )"

    case "$DBOOTLOADER" in
        0)
            DBOOTLOADER="Unlocked"
            ;;
        1)
            DBOOTLOADER="Locked"
            ;;
        *)
            DBOOTLOADER="N/A"
            ;;
    esac

    return 0
}

# ============================================================
# ADB SIDELOAD DEVICE DETECTION
# ============================================================

detect_adb_sideload_device() {
    reset_device_info

    local device_line
    local serial
    local state

    device_line="$(
        "$ADB_BIN" devices 2>&1 |
        awk 'NR > 1 && NF >= 2 {
            print $1 "|" $2
            exit
        }'
    )"

    serial="${device_line%%|*}"
    state="${device_line#*|}"

    if [ -z "$serial" ] || [ -z "$state" ]; then
        return 1
    fi

    case "$state" in
        sideload)
            DSERIAL="$serial"
            DMODE="ADB Sideload"
            return 0
            ;;

        device)
            DSERIAL="$serial"
            DMODE="ADB"
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

# ============================================================
# FASTBOOT DEVICE DETECTION
# ============================================================

detect_fastboot_device() {
    reset_device_info

    local devices
    local serial
    local value
    local product_output

    devices="$($FASTBOOT_BIN devices 2>&1)"

    serial="$(
        printf '%s\n' "$devices" |
        awk 'NF >= 2 && $2 ~ /fastboot/ {print $1; exit}'
    )"

    if [ -z "$serial" ]; then
        product_output="$($FASTBOOT_BIN getvar product 2>&1)"
        if printf '%s\n' "$product_output" | grep -Eq '(^|[[:space:]])product:'; then
            serial="$($FASTBOOT_BIN getvar serialno 2>&1 | sed -n 's/.*serialno: //p' | tail -n1)"
            [ -z "$serial" ] && serial="unknown"
        else
            return 1
        fi
    fi

    DSERIAL="$serial"
    DMODE="Fastboot"

    value="$(
        printf '%s\n' "$product_output" |
        sed -n 's/.*product: //p' |
        tail -n1
    )"
    [ -n "$value" ] && DCODENAME="$value"

    value="$($FASTBOOT_BIN getvar product-name 2>&1 | sed -n 's/.*product-name: //p' | tail -n1)"
    if [ -n "$value" ] && [ "$value" != "not found" ]; then
        DMODEL="$value"
    else
        value="$($FASTBOOT_BIN getvar sku 2>&1 | sed -n 's/.*sku: //p' | tail -n1)"
        if [ -n "$value" ] && [ "$value" != "not found" ]; then
            DMODEL="$value"
        fi
    fi

    value="$($FASTBOOT_BIN getvar current-slot 2>&1 | sed -n 's/.*current-slot: //p' | tail -n1)"
    [ -n "$value" ] && DSLOT="$value"

    value="$($FASTBOOT_BIN getvar unlocked 2>&1 | sed -n 's/.*unlocked: //p' | tail -n1)"
    case "$value" in
        yes) DBOOTLOADER="Unlocked" ;;
        no)  DBOOTLOADER="Locked" ;;
    esac

    return 0
}

# ============================================================
# REQUIRE DEVICE FUNCTIONS
# ============================================================

require_adb_device() {
    if ! detect_adb_device; then
        failed
        red_print "No Adb Device Detected."
        return 1
    fi

    return 0
}

require_adb_sideload_device() {
    if ! detect_adb_sideload_device; then
        failed
        red_print "No Adb Sideload Device Detected."
        return 1
    fi

    return 0
}

require_fastboot_device() {
    if ! detect_fastboot_device; then
        failed
        red_print "No Fastboot Device Detected."
        return 1
    fi

    return 0
}

# ============================================================
# CHECK FUNCTIONS
# ============================================================

check_adb_device() {
    detect_adb_device
}

check_adb_sideload_device() {
    detect_adb_sideload_device
}

check_fastboot_device() {
    detect_fastboot_device
}

# ============================================================
# FIND FLASHFILE.XML
# ============================================================

find_flashfile_xml() {
    local source="$1"
    local found

    if [ -f "$source/flashfile.xml" ]; then
        printf '%s\n' "$source/flashfile.xml"
        return 0
    fi

    found="$(
        find "$source" \
            -type f \
            -iname "flashfile.xml" \
            -print \
            -quit 2>/dev/null
    )"

    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi

    return 1
}

# ============================================================
# PREPARE STOCK ROM SOURCE
# ============================================================

prepare_stock_source() {
    local input="$1"
    local resolved
    local extension
    local archive_dir
    local archive_output
    local xml

    STOCK_XML_PATH=""
    STOCK_TEMP_DIR=""
    STOCK_SOURCE_IS_ARCHIVE=0

    resolved="$(resolve_path "$input")"

    if [ ! -e "$resolved" ]; then
        failed
        rainbow_print "Stock Rom Path Does Not Exist:"
        rainbow_print "$resolved"
        return 1
    fi

    # DIRECTORY

    if [ -d "$resolved" ]; then
        rainbow_print "Searching For flashfile.xml..."

        xml="$(find_flashfile_xml "$resolved")"

        if [ -z "$xml" ]; then
            failed
            rainbow_print "flashfile.xml Not Found In The Selected Directory."
            return 1
        fi

        STOCK_XML_PATH="$xml"
        STOCK_SOURCE_IS_ARCHIVE=0

        green_print 'Found "flashfile.xml"'
        green_print "Using: $STOCK_XML_PATH"

        return 0
    fi

    # ARCHIVE

    if [ ! -f "$resolved" ]; then
        failed
        rainbow_print "Selected Stock Rom Is Not A Valid File Or Directory."
        return 1
    fi

    extension="${resolved##*.}"
    extension="$(
        printf '%s' "$extension" |
        tr '[:upper:]' '[:lower:]'
    )"

    case "$extension" in
        zip|rar|7z)
            ;;
        *)
            failed
            rainbow_print "Unsupported Stock Rom Format."
            rainbow_print "Supported: Directory, Zip, Rar, 7Z"
            return 1
            ;;
    esac

    if ! ensure_7zip; then
        return 1
    fi

    archive_dir="$TMP_DIR/stock_archive"

    rm -rf "$archive_dir" 2>/dev/null
    mkdir -p "$archive_dir"

    rainbow_print "Temporary Extracting..."

    archive_output="$TMP_DIR/7z_extract.log"

    rm -f "$archive_output" 2>/dev/null

    if ! 7z x \
        -y \
        "$resolved" \
        "-o$archive_dir" \
        >"$archive_output" 2>&1; then

        failed

        printf '\n'
        rainbow_print "7Z Error:"
        rainbow_cat "$archive_output"

        return 1
    fi

    xml="$(find_flashfile_xml "$archive_dir")"

    if [ -z "$xml" ]; then
        failed
        rainbow_print "flashfile.xml Not Found In Extracted Stock Rom."
        return 1
    fi

    STOCK_XML_PATH="$xml"
    STOCK_TEMP_DIR="$archive_dir"
    STOCK_SOURCE_IS_ARCHIVE=1

    green_print 'Found "flashfile.xml"'
    green_print "Using: $STOCK_XML_PATH"

    return 0
}

# ============================================================
# PARSE FLASHFILE.XML
# ============================================================

parse_flashfile_xml() {
    local xml="$1"

    if [ ! -f "$xml" ]; then
        return 1
    fi

    local parser="$TMP_DIR/parse_flashfile.py"

    cat > "$parser" <<'PY'
import sys
import xml.etree.ElementTree as ET

xml_file = sys.argv[1]

try:
    root = ET.parse(xml_file).getroot()
except Exception as e:
    print(f"ERROR|Unable to parse flashfile.xml: {e}")
    sys.exit(1)

steps = root.find(".//steps")

if steps is None:
    print("ERROR|<steps> section not found in flashfile.xml")
    sys.exit(1)

for step in steps.findall("step"):
    operation = (step.attrib.get("operation") or "").strip()
    filename = (step.attrib.get("filename") or "").strip()

    if not operation:
        continue

    print(
        "STEP|{}|{}".format(
            operation,
            filename.replace("|", "")
        )
    )
PY

    if ! python "$parser" "$xml"; then
        return 1
    fi
}

# ============================================================
# VALIDATE STOCK XML FILES
# ============================================================

validate_flashfile_files() {
    local xml="$1"
    local xml_dir
    local operation
    local filename
    local fullpath
    local missing=0

    xml_dir="$(dirname "$xml")"

    while IFS='|' read -r tag operation filename; do
        [ "$tag" = "STEP" ] || continue

        case "$operation" in
            flash)
                [ -z "$filename" ] && continue

                fullpath="$xml_dir/$filename"

                if [ ! -f "$fullpath" ]; then
                    failed
                    rainbow_print "Missing Flash File: $fullpath"
                    missing=1
                fi
                ;;
        esac
    done < <(parse_flashfile_xml "$xml")

    if [ "$missing" -ne 0 ]; then
        return 1
    fi

    return 0
}

# ============================================================
# FLASH SINGLE FILE
# ============================================================

flash_single_file() {
    local partition="$1"
    local file="$2"
    local output_file="$TMP_DIR/fastboot_output.log"

    PROGRESS_DRAWN=0
    rm -f "$output_file" 2>/dev/null

    if ! run_stock_command_with_progress 0 100 "$(basename "$file")" "Flash" "$output_file" \
        "$FASTBOOT_BIN" flash "$partition" "$file"; then

        printf '%sFlashing failed: %s%s\n' \
            "$RED" "$partition" "$RESET"

        printf '\n'
        rainbow_cat "$output_file"

        return 1
    fi

    return 0
}

# ============================================================
# STOCK FLASH PROGRESS BAR
# ============================================================

draw_stock_progress() {
    local percent="$1"
    local image="$2"
    local operation="$3"

    local width=10
    local filled empty bar operation_line progress_line cols pad

    [ -z "$percent" ] && percent=0
    [ "$percent" -lt 0 ] 2>/dev/null && percent=0
    [ "$percent" -gt 100 ] 2>/dev/null && percent=100

    filled=$((percent * width / 100))
    empty=$((width - filled))

    bar=""
    for ((i=0; i<filled; i++)); do
        bar+="●"
    done
    for ((i=0; i<empty; i++)); do
        bar+="○"
    done

    operation_line="⚡ ${operation:-Flash}"
    progress_line="[${bar}]  ${percent}%"

    cols="${COLUMNS:-}"
    if [ -z "$cols" ] || ! [[ "$cols" =~ ^[0-9]+$ ]]; then
        cols="$(tput cols 2>/dev/null || printf '80')"
    fi
    [ "$cols" -lt 20 ] && cols=20
    pad=$((cols - 1))

    if [ "${PROGRESS_DRAWN:-0}" -eq 1 ]; then
        printf '\033[1A\r%-*s\n%-*s\r' \
            "$pad" "$operation_line" \
            "$pad" "$progress_line"
    else
        printf '%-*s\n%-*s\r' \
            "$pad" "$operation_line" \
            "$pad" "$progress_line"
        PROGRESS_DRAWN=1
    fi
}

# ============================================================
# LIVE STOCK FLASH PROGRESS
# ============================================================

run_stock_command_with_progress() {
    local start_percent="$1"
    local end_percent="$2"
    local image="$3"
    local operation="$4"
    local output_file="$5"
    shift 5

    local percent="$start_percent"
    local status
    local pid

    rm -f "$output_file" 2>/dev/null

    draw_stock_progress "$percent" "$image" "$operation"

    "$@" >"$output_file" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        if [ "$percent" -lt $((end_percent - 1)) ]; then
            percent=$((percent + 1))
        fi
        draw_stock_progress "$percent" "$image" "$operation"
        sleep 0.15
    done

    wait "$pid"
    status=$?

    draw_stock_progress "$end_percent" "$image" "$operation"
    return "$status"
}

# ============================================================
# FLASH SUPER SPARSE CHUNK GROUP
# ============================================================

flash_super_group() {
    local xml_dir="$1"
    local base_step="$2"
    local total_steps="$3"
    shift 3

    local chunks=("$@")
    local total="${#chunks[@]}"
    local index=0
    local chunk
    local output_file="$TMP_DIR/fastboot_super.log"
    local step_number
    local progress

    FLASH_GROUP_COUNT="$total"

    if [ "$total" -eq 0 ]; then
        return 0
    fi

    for chunk in "${chunks[@]}"; do
        index=$((index + 1))
        step_number=$((base_step + index))
        progress=$((step_number * 100 / total_steps))

        local start_progress
        start_progress=$(((step_number - 1) * 100 / total_steps))

        if ! run_stock_command_with_progress \
            "$start_progress" \
            "$progress" \
            "$chunk" \
            "Flash Super ($index/$total): $chunk" \
            "$output_file" \
            "$FASTBOOT_BIN" flash super "$xml_dir/$chunk"; then

            printf '\n'
            failed
            rainbow_print "Flashing Super Failed At $chunk."

            printf '\n'
            rainbow_cat "$output_file"

            return 1
        fi
    done

    return 0
}

# ============================================================
# FLASH STOCK ROM
# ============================================================

flash_stock_rom() {
    clear_screen
    show_header

    rainbow_print "Stock Rom Flash"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    local input
    local xml
    local xml_dir
    local output_file
    local parser_output
    local total_steps
    local current_step
    local progress
    local start_progress
    local operation
    local filename
    local fullpath
    local partition

    rainbow_print "Enter Stock Rom Directory / Zip / Rar / 7Z:"
    rainbow_prompt ">>> "
    read -r input

    if [ -z "$input" ]; then
        failed
        rainbow_print "No Stock Rom Path Entered."
        pause_failure
        return
    fi

    printf '\n'

    if ! prepare_stock_source "$input"; then
        printf '\n'
        failed
        rainbow_print "Unable To Prepare Stock Rom Source."
        pause_failure
        return
    fi

    xml="$STOCK_XML_PATH"
    xml_dir="$(dirname "$xml")"

    printf '\n'
    rainbow_print "Checking Fastboot Device..."

    if ! require_fastboot_device; then
        pause_failure
        return
    fi

    show_device_info

    printf '\n'
    rainbow_print "Validating Stock Rom Files..."

    if ! validate_flashfile_files "$xml"; then
        failed
        rainbow_print "Stock Rom Validation Failed."
        pause_failure
        return
    fi

    green_print "Stock Rom Validation Successful. ✅"

    parser_output="$TMP_DIR/flashfile_steps.txt"

    if ! parse_flashfile_xml "$xml" >"$parser_output"; then
        failed
        rainbow_print "Unable To Parse flashfile.xml."
        pause_failure
        return
    fi

    total_steps="$(
        grep -c '^STEP|' "$parser_output" 2>/dev/null
    )"

    if [ -z "$total_steps" ] || [ "$total_steps" -eq 0 ]; then
        failed
        rainbow_print "No Flashing Steps Found In flashfile.xml."
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Starting Stock Rom Flashing..."
    printf '\n'

    PROGRESS_DRAWN=0

    current_step=0

    local super_chunks=()
    local in_super_group=0

    while IFS='|' read -r tag operation filename; do
        [ "$tag" = "STEP" ] || continue

        if [ "$operation" = "flash" ] &&
           printf '%s' "$filename" |
           grep -Eq '^super\.img_sparsechunk\.'; then

            super_chunks+=("$filename")
            in_super_group=1
            continue
        fi

        if [ "$in_super_group" -eq 1 ]; then

            if ! flash_super_group \
                "$xml_dir" \
                "$current_step" \
                "$total_steps" \
                "${super_chunks[@]}"; then

                failed
                rainbow_print "Stock Rom Flashing Failed."
                pause_failure
                return
            fi

            current_step=$((current_step + FLASH_GROUP_COUNT))
            super_chunks=()
            in_super_group=0
        fi

        current_step=$((current_step + 1))

        case "$operation" in

            flash)
                [ -z "$filename" ] && continue

                fullpath="$xml_dir/$filename"

                partition="$filename"
                partition="${partition%.img}"

                case "$partition" in
                    *.*)
                        partition="${partition##*/}"
                        ;;
                esac

                progress=$((current_step * 100 / total_steps))
                start_progress=$(((current_step - 1) * 100 / total_steps))

                output_file="$TMP_DIR/fastboot_output.log"

                if ! run_stock_command_with_progress \
                    "$start_progress" \
                    "$progress" \
                    "$filename" \
                    "Flash $partition: $filename" \
                    "$output_file" \
                    "$FASTBOOT_BIN" flash "$partition" "$fullpath"; then

                    printf '\n'

                    printf '%sFlashing failed: %s%s\n' \
                        "$RED" "$partition" "$RESET"

                    printf '\n'
                    rainbow_cat "$output_file"

                    pause_failure
                    return
                fi
                ;;

            erase)
                partition="$filename"

                [ -z "$partition" ] && continue

                progress=$((current_step * 100 / total_steps))
                start_progress=$(((current_step - 1) * 100 / total_steps))

                output_file="$TMP_DIR/fastboot_output.log"

                if ! run_stock_command_with_progress \
                    "$start_progress" \
                    "$progress" \
                    "$partition" \
                    "Erase $partition" \
                    "$output_file" \
                    "$FASTBOOT_BIN" erase "$partition"; then

                    printf '\n'

                    printf '%sErase failed: %s%s\n' \
                        "$RED" "$partition" "$RESET"

                    printf '\n'
                    rainbow_cat "$output_file"

                    pause_failure
                    return
                fi
                ;;

            getvar)
                progress=$((current_step * 100 / total_steps))

                draw_stock_progress \
                    "$progress" \
                    "${filename:-N/A}" \
                    "Getvar"

                "$FASTBOOT_BIN" getvar "$filename" \
                    >/dev/null 2>&1 || true
                ;;

            oem)
                progress=$((current_step * 100 / total_steps))
                start_progress=$(((current_step - 1) * 100 / total_steps))

                output_file="$TMP_DIR/fastboot_output.log"

                if ! run_stock_command_with_progress \
                    "$start_progress" \
                    "$progress" \
                    "${filename:-N/A}" \
                    "Oem" \
                    "$output_file" \
                    "$FASTBOOT_BIN" oem "$filename"; then

                    printf '\n'

                    printf '%sOEM command failed: %s%s\n' \
                        "$RED" "$filename" "$RESET"

                    printf '\n'
                    rainbow_cat "$output_file"

                    pause_failure
                    return
                fi
                ;;

            *)
                progress=$((current_step * 100 / total_steps))

                draw_stock_progress \
                    "$progress" \
                    "${filename:-N/A}" \
                    "$operation"
                ;;
        esac

    done < "$parser_output"

    # FLASH FINAL SUPER GROUP

    if [ "$in_super_group" -eq 1 ]; then

        if ! flash_super_group \
            "$xml_dir" \
            "$current_step" \
            "$total_steps" \
            "${super_chunks[@]}"; then

            failed
            rainbow_print "Stock Rom Flashing Failed."
            pause_failure
            return
        fi
    fi

    printf '\n'
    success
    green_print "Stock Rom Flashing Completed Successfully! ✅"

    # DELETE TEMPORARY EXTRACTED ARCHIVE

    if [ "$STOCK_SOURCE_IS_ARCHIVE" -eq 1 ] &&
       [ -n "$STOCK_TEMP_DIR" ] &&
       [ -d "$STOCK_TEMP_DIR" ]; then

        printf '\n'
        warning "Removing Temporary Extracted Stock Rom..."

        rm -rf "$STOCK_TEMP_DIR"

        if [ ! -d "$STOCK_TEMP_DIR" ]; then
            success
            green_print \
                "Temporary extracted Stock ROM deleted successfully. 🗑️"
        else
            warning \
                "Unable to completely remove temporary extracted files."
        fi
    fi

    printf '\n'

    flash_complete_menu
}

# ============================================================
# FLASH COMPLETE MENU
# ============================================================

flash_complete_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║          Flash Complete              ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Reboot To Recovery               ║'
        rainbow_print '║  2. Reboot To System                 ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                printf '\n'
                rainbow_prompt "Reboot To Recovery? [Y/N]: "
                read -r confirm

                case "$confirm" in
                    y|Y)
                        if "$FASTBOOT_BIN" reboot recovery \
                            >/dev/null 2>&1; then

                            success
                        else
                            failed
                        fi

                        sleep 2
                        return
                        ;;
                esac
                ;;

            2)
                printf '\n'
                rainbow_prompt "Reboot To System? [Y/N]: "
                read -r confirm

                case "$confirm" in
                    y|Y)
                        if "$FASTBOOT_BIN" reboot \
                            >/dev/null 2>&1; then

                            success
                        else
                            failed
                        fi

                        sleep 2
                        return
                        ;;
                esac
                ;;

        esac
    done
}

# ============================================================
# UNIVERSAL ROM DOWNLOAD HELPERS
# ============================================================

url_add_query() {
    local url="$1" key="$2" value="$3"
    case "$url" in
        *\?*) printf '%s&%s=%s\n' "$url" "$key" "$value" ;;
        *) printf '%s?%s=%s\n' "$url" "$key" "$value" ;;
    esac
}

normalize_download_url() {
    local url="$1"

    case "$url" in
        https://www.dropbox.com/*|https://dropbox.com/*)
            url="$(printf '%s' "$url" | sed -E 's/([?&])dl=[01]/\1dl=1/')"
            case "$url" in *dl=1*) ;; *) url="$(url_add_query "$url" dl 1)" ;; esac
            ;;
    esac

    case "$url" in
        https://github.com/*/blob/*)
            url="${url/https:\/\/github.com\//https:\/\/raw.githubusercontent.com\/}"
            url="${url/\/blob\//\/}"
            ;;
    esac

    printf '%s\n' "$url"
}

is_zip_file() {
    local file="$1"
    [ -s "$file" ] || return 1
    if command_exists xxd; then
        [ "$(xxd -p -l 2 "$file" 2>/dev/null)" = "504b" ]
    else
        [ "$(od -An -tx1 -N2 "$file" 2>/dev/null | tr -d ' \n')" = "504b" ]
    fi
}

download_direct_file() {
    local url="$1" output="$2"
    local headers="$TMP_DIR/download_headers.txt"
    local errors="$TMP_DIR/download_errors.txt"

    rm -f "$headers" "$errors" "$output" 2>/dev/null

    curl -L --fail --location-trusted \
        --retry 3 --retry-delay 2 \
        --connect-timeout 20 --max-time 0 \
        -A "Mozilla/5.0 (Android) Motorola-ROM-Flasher/1.0" \
        -D "$headers" --progress-bar "$url" \
        -o "$output" 2>"$errors"
}

download_google_drive() {
    local url="$1" output="$2" file_id=""
    file_id="$(printf '%s\n' "$url" |
        sed -n -E 's#.*drive\.google\.com/file/d/([^/?]+).*#\1#p')"

    [ -z "$file_id" ] && file_id="$(printf '%s\n' "$url" |
        sed -n -E 's#.*[?&]id=([^&]+).*#\1#p')"

    [ -n "$file_id" ] || return 1

    download_direct_file \
        "https://drive.usercontent.google.com/download?id=${file_id}&export=download&confirm=t" \
        "$output"
}

# ============================================================
# ADB SIDELOAD PROGRESS
# ============================================================

draw_sideload_progress() {
    local percent="$1"
    local width=10
    local filled empty bar operation_line progress_line cols pad

    [ -z "$percent" ] && percent=0
    [ "$percent" -lt 0 ] 2>/dev/null && percent=0
    [ "$percent" -gt 100 ] 2>/dev/null && percent=100

    filled=$((percent * width / 100))
    empty=$((width - filled))

    bar=""
    for ((i=0; i<filled; i++)); do
        bar+="●"
    done
    for ((i=0; i<empty; i++)); do
        bar+="○"
    done

    operation_line="⚡ Install Rom (Adb Sideload)"
    progress_line="[${bar}]  ${percent}%"

    cols="${COLUMNS:-}"
    if [ -z "$cols" ] || ! [[ "$cols" =~ ^[0-9]+$ ]]; then
        cols="$(tput cols 2>/dev/null || printf '80')"
    fi
    [ "$cols" -lt 20 ] && cols=20
    pad=$((cols - 1))

    if [ "${SIDELOAD_PROGRESS_DRAWN:-0}" -eq 1 ]; then
        printf '\033[1A\r%-*s\n%-*s\r' \
            "$pad" "$operation_line" \
            "$pad" "$progress_line"
    else
        printf '%-*s\n%-*s\r' \
            "$pad" "$operation_line" \
            "$pad" "$progress_line"
        SIDELOAD_PROGRESS_DRAWN=1
    fi
}

extract_sideload_percent() {
    local output="$1"
    local percent

    percent="$(tr '\r' '\n' < "$output" 2>/dev/null | \
        grep -oE '~?[0-9]{1,3}%' | \
        tail -n1 | \
        tr -cd '0-9')"

    printf '%s' "$percent"
}

adb_sideload_with_progress() {
    local rom="$1"
    local output="$2"
    local pid percent last_percent=-1 status
    local quoted_rom

    : > "$output"

    printf '\n'
    rainbow_print "Adb Sideload"
    rainbow_print "──────────────────────────────────────"

    SIDELOAD_PROGRESS_DRAWN=0

    ROM="$rom"
    draw_sideload_progress 0

    if command -v script >/dev/null 2>&1; then
        printf -v quoted_rom '%q' "$rom"
        script -qefc "$(printf '%q' "$ADB_BIN") sideload $quoted_rom" "$output" >/dev/null 2>&1 &
    else
        "$ADB_BIN" sideload "$rom" >"$output" 2>&1 &
    fi
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        percent="$(extract_sideload_percent "$output")"

        if [ -n "$percent" ]; then
            draw_sideload_progress "$percent"
            last_percent="$percent"
        else
            if [ "$last_percent" -lt 1 ] 2>/dev/null; then
                last_percent=1
            elif [ "$last_percent" -lt 95 ] 2>/dev/null; then
                last_percent=$((last_percent + 1))
            fi
            draw_sideload_progress "$last_percent"
        fi

        sleep 0.10
    done

    wait "$pid"
    status=$?

    percent="$(extract_sideload_percent "$output")"

    if [ "$status" -eq 0 ]; then
        draw_sideload_progress 100
    elif [ -n "$percent" ]; then
        draw_sideload_progress "$percent"
    fi

    printf '\n'
    return "$status"
}

# ============================================================
# ADB SIDELOAD
# ============================================================

adb_sideload() {
    clear_screen
    show_header
    rainbow_print "Adb Sideload"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! setup_adb_server; then
        pause_failure
        return
    fi

    if ! check_adb_sideload_device; then
        failed
        red_print "No Adb Sideload Device Detected."
        warning "Boot The Device Into Adb Sideload Mode First."
        pause_failure
        return
    fi

    show_device_info
    printf '\n'

    rainbow_print "Enter Rom Zip Path:"
    rainbow_prompt ">>> "
    read -r ROM

    if [ -z "$ROM" ]; then
        failed
        rainbow_print "No Rom Path Entered."
        pause_failure
        return
    fi

    ROM="$(resolve_path "$ROM")"

    if [ ! -f "$ROM" ]; then
        failed
        rainbow_print "Rom File Not Found:"
        rainbow_print "$ROM"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Checking Rom Zip..."

    rainbow_print "Rom Size:"
    ls -lh "$ROM"

    printf '\n'
    rainbow_print "Testing Zip Integrity..."

    if ! is_zip_file "$ROM" || ! 7z t "$ROM" >/dev/null 2>&1; then
        failed
        rainbow_print "The Selected File Is Not A Valid Rom Zip."
        rainbow_print "Please Select A Valid Rom Zip File."
        pause_failure
        return
    fi

    success
    rainbow_print "Rom Zip Verified."

    local sideload_output="$TMP_DIR/sideload_output.log"

    if adb_sideload_with_progress "$ROM" "$sideload_output"; then
        success
        rainbow_print "Adb Sideload Completed Successfully."
    else
        failed
        rainbow_print "Adb Sideload Failed."
        if [ -s "$sideload_output" ]; then
            printf '\n'
            rainbow_print "Adb Output:"
            rainbow_cat "$sideload_output"
        fi
        pause_failure
        return
    fi

    pause_failure
}

# ============================================================
# BOOT TWRP
# ============================================================

boot_twrp() {
    clear_screen
    show_header

    rainbow_print "Boot Twrp"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_fastboot_device; then
        failed
        red_print "No Fastboot Device Detected."
        pause_failure
        return
    fi

    show_device_info

    printf '\n'

    rainbow_print "Enter Path To Twrp Img:"
    rainbow_prompt ">>> "
    read -r twrp

    if [ -z "$twrp" ]; then
        failed
        rainbow_print "No Twrp Image Path Entered."
        pause_failure
        return
    fi

    twrp="$(resolve_path "$twrp")"

    if [ ! -f "$twrp" ]; then
        failed
        rainbow_print "Twrp Image Not Found:"
        rainbow_print "$twrp"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Booting Twrp..."

    local output_file="$TMP_DIR/twrp_output.log"

    rm -f "$output_file" 2>/dev/null


    if "$FASTBOOT_BIN" boot "$twrp" \
        >"$output_file" 2>&1; then

        success
    else
        failed

        printf '\n'
        rainbow_cat "$output_file"

        pause_failure
        return
    fi

    sleep 2
}

# ============================================================
# CUSTOM ROM PARTITION FLASH
# ============================================================

flash_boot() {
    local image=""
    local output_file="$TMP_DIR/flash_boot_output.log"

    clear_screen
    show_header
    rainbow_print "Flash Boot"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_fastboot_device; then
        failed
        red_print "No Fastboot Device Detected."
        pause_failure
        return
    fi

    show_device_info
    printf '\n'
    rainbow_print "Enter boot.img Path:"
    rainbow_prompt ">>> "
    read -r image

    if [ -z "$image" ]; then
        failed
        red_print "No boot.img Path Entered."
        pause_failure
        return
    fi

    image="$(resolve_path "$image")"
    if [ ! -f "$image" ]; then
        failed
        red_print "boot.img Not Found:"
        rainbow_print "$image"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Fastboot Flash Boot $image"
    PROGRESS_DRAWN=0
    rm -f "$output_file" 2>/dev/null

    if run_stock_command_with_progress 0 100 "$(basename "$image")" "Flash Boot: $(basename "$image")" "$output_file" \
        "$FASTBOOT_BIN" flash boot "$image"; then
        printf '\n'
        success
        green_print "Boot Flashed Successfully. ✅"
    else
        printf '\n'
        failed
        red_print "Failed To Flash Boot."
        [ -s "$output_file" ] && { printf '\n'; rainbow_cat "$output_file"; }
    fi
    pause_failure
}

flash_vendor_boot() {
    local image=""
    local output_file="$TMP_DIR/flash_vendor_boot_output.log"

    clear_screen
    show_header
    rainbow_print "Flash Vendor_Boot"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_fastboot_device; then
        failed
        red_print "No Fastboot Device Detected."
        pause_failure
        return
    fi

    show_device_info
    printf '\n'
    rainbow_print "Enter Vendor_boot.img Path:"
    rainbow_prompt ">>> "
    read -r image

    if [ -z "$image" ]; then
        failed
        red_print "No Vendor_boot.img Path Entered."
        pause_failure
        return
    fi

    image="$(resolve_path "$image")"
    if [ ! -f "$image" ]; then
        failed
        red_print "Vendor_boot.img Not Found:"
        rainbow_print "$image"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Fastboot Flash Vendor_Boot $image"
    PROGRESS_DRAWN=0
    rm -f "$output_file" 2>/dev/null

    if run_stock_command_with_progress 0 100 "$(basename "$image")" "Flash Vendor_Boot: $(basename "$image")" "$output_file" \
        "$FASTBOOT_BIN" flash vendor_boot "$image"; then
        printf '\n'
        success
        green_print "Vendor_Boot Flashed Successfully. ✅"
    else
        printf '\n'
        failed
        red_print "Failed To Flash Vendor_Boot."
        [ -s "$output_file" ] && { printf '\n'; rainbow_cat "$output_file"; }
    fi
    pause_failure
}

flash_dtbo() {
    local image=""
    local output_file="$TMP_DIR/flash_dtbo_output.log"

    clear_screen
    show_header
    rainbow_print "Flash Dtbo"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_fastboot_device; then
        failed
        red_print "No Fastboot Device Detected."
        pause_failure
        return
    fi

    show_device_info
    printf '\n'
    rainbow_print "Enter dtbo.img Path:"
    rainbow_prompt ">>> "
    read -r image

    if [ -z "$image" ]; then
        failed
        red_print "No dtbo.img Path Entered."
        pause_failure
        return
    fi

    image="$(resolve_path "$image")"
    if [ ! -f "$image" ]; then
        failed
        red_print "dtbo.img Not Found:"
        rainbow_print "$image"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Fastboot Flash Dtbo $image"
    PROGRESS_DRAWN=0
    rm -f "$output_file" 2>/dev/null

    if run_stock_command_with_progress 0 100 "$(basename "$image")" "Flash Dtbo: $(basename "$image")" "$output_file" \
        "$FASTBOOT_BIN" flash dtbo "$image"; then
        printf '\n'
        success
        green_print "Dtbo Flashed Successfully. ✅"
    else
        printf '\n'
        failed
        red_print "Failed To Flash Dtbo."
        [ -s "$output_file" ] && { printf '\n'; rainbow_cat "$output_file"; }
    fi
    pause_failure
}

# ============================================================
# CUSTOM ROM MENU
# ============================================================

custom_rom_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║           Custom Rom Flash           ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Flash Boot                       ║'
        rainbow_print '║  2. Flash Vendor_Boot                ║'
        rainbow_print '║  3. Flash Dtbo                       ║'
        rainbow_print '║  4. Boot Twrp                        ║'
        rainbow_print '║  5. Adb Sideload                     ║'
        rainbow_print '║                                      ║'
        rainbow_print '║  6. Back                             ║'
        rainbow_print '╚══════════════════════════════════════╝'

        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                flash_boot
                ;;

            2)
                flash_vendor_boot
                ;;

            3)
                flash_dtbo
                ;;

            4)
                boot_twrp
                ;;

            5)
                adb_sideload
                ;;

            6)
                return
                ;;

        esac
    done
}

# ============================================================
# REBOOT MENU
# ============================================================

reboot_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║              Reboot                  ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Adb Reboot Recovery              ║'
        rainbow_print '║  2. Adb Reboot Bootloader            ║'
        rainbow_print '║  3. Fastboot Reboot Recovery         ║'
        rainbow_print '║                                      ║'
        rainbow_print '║  4. Back                             ║'
        rainbow_print '╚══════════════════════════════════════╝'

        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                if ! require_adb_device; then
                    pause_failure
                    continue
                fi

                if "$ADB_BIN" reboot recovery >/dev/null 2>&1; then
                    success
                else
                    failed
                    pause_failure
                fi

                sleep 2
                ;;

            2)
                if ! require_adb_device; then
                    pause_failure
                    continue
                fi

                if "$ADB_BIN" reboot bootloader >/dev/null 2>&1; then
                    success
                else
                    failed
                    pause_failure
                fi

                sleep 2
                ;;

            3)
                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                if "$FASTBOOT_BIN" reboot recovery >/dev/null 2>&1; then
                    success
                else
                    failed
                    pause_failure
                fi

                sleep 2
                ;;

            4)
                return
                ;;

        esac
    done
}

# ============================================================
# WIPE DATA
# ============================================================

wipe_data() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║              Wipe Data              ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Yes                              ║'
        rainbow_print '║  2. No                               ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'

        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                printf '\n'
                local wipe_output="$TMP_DIR/wipe_output.log"
                PROGRESS_DRAWN=0

                if run_stock_command_with_progress \
                    0 100 "userdata + metadata" "Wipe Userdata + Metadata" "$wipe_output" \
                    "$FASTBOOT_BIN" -w; then

                    printf '\n'
                    success
                else
                    failed

                    printf '\n'
                    rainbow_cat "$wipe_output"

                    pause_failure
                fi

                sleep 2
                return
                ;;

            2)
                return
                ;;

            y|Y)
                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                printf '\n'
                local wipe_output="$TMP_DIR/wipe_output.log"
                PROGRESS_DRAWN=0

                if run_stock_command_with_progress \
                    0 100 "userdata + metadata" "Wipe Userdata + Metadata" "$wipe_output" \
                    "$FASTBOOT_BIN" -w; then

                    printf '\n'
                    success
                else
                    printf '\n'
                    failed
                    [ -s "$wipe_output" ] && { printf '\n'; rainbow_cat "$wipe_output"; }
                    pause_failure
                fi

                sleep 2
                return
                ;;

            n|N)
                return
                ;;

        esac
    done
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Flash Stock Rom                  ║'
        rainbow_print '║  2. Flash Custom Rom                 ║'
        rainbow_print '║  3. Reboot                           ║'
        rainbow_print '║  4. Wipe Data                        ║'
        rainbow_print '║  5. Exit                             ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'

        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                flash_stock_rom
                ;;

            2)
                custom_rom_menu
                ;;

            3)
                reboot_menu
                ;;

            4)
                wipe_data
                ;;

            5)
                clear_screen
                show_header
                rainbow_print "Goodbye! 👋"
                exit 0
                ;;

        esac
    done
}

# ============================================================
# START
# ============================================================

if ! startup_setup; then
    printf '\n'
    failed
    rainbow_print "Startup Setup Failed."
    rainbow_print "Please Check Your Termux Package Installation."
    exit 1
fi

main_menu
           failed

                    printf '\n'
                    rainbow_cat "$wipe_output"

                    pause_failure
                fi

                sleep 2
                return
                ;;

            2)
                return
                ;;

            y|Y)
                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                printf '\n'
                local wipe_output="$TMP_DIR/wipe_output.log"
                PROGRESS_DRAWN=0

                if run_stock_command_with_progress \
                    0 100 "userdata + metadata" "Wipe Userdata + Metadata" "$wipe_output" \
                    "$FASTBOOT_BIN" -w; then

                    printf '\n'
                    success
                else
                    printf '\n'
                    failed
                    [ -s "$wipe_output" ] && { printf '\n'; rainbow_cat "$wipe_output"; }
                    pause_failure
                fi

                sleep 2
                return
                ;;

            n|N)
                return
                ;;

        esac
    done
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Flash Stock Rom                  ║'
        rainbow_print '║  2. Flash Custom Rom                 ║'
        rainbow_print '║  3. Reboot                           ║'
        rainbow_print '║  4. Wipe Data                        ║'
        rainbow_print '║  5. Exit                             ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'

        printf '\n'

        rainbow_prompt "Select Option: "
        read -r choice

        case "$choice" in

            1)
                flash_stock_rom
                ;;

            2)
                custom_rom_menu
                ;;

            3)
                reboot_menu
                ;;

            4)
                wipe_data
                ;;

            5)
                clear_screen
                show_header
                rainbow_print "Goodbye! 👋"
                exit 0
                ;;

        esac
    done
}

# ============================================================
# START
# ============================================================

if ! startup_setup; then
    printf '\n'
    failed
    rainbow_print "Startup Setup Failed."
    rainbow_print "Please Check Your Termux Package Installation."
    exit 1
fi

main_menu

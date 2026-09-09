#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#              MOTOROLA ROM FLASHER
#                     by JINWOO
# ============================================================

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
RESET=$'\033[0m'

# ============================================================
# RAINBOW COLORS
# ============================================================

RAINBOW_COLORS=(
    $'\033[0;31m'    # Red
    $'\033[0;33m'    # Yellow
    $'\033[0;32m'    # Green
    $'\033[0;36m'    # Cyan
    $'\033[0;34m'    # Blue
    $'\033[0;35m'    # Magenta
)

RAINBOW_INDEX=0

rainbow_print() {
    local message="$1"
    local color="${RAINBOW_COLORS[$RAINBOW_INDEX]}"

    RAINBOW_INDEX=$(( (RAINBOW_INDEX + 1) % ${#RAINBOW_COLORS[@]} ))

    printf '%s%s%s\n' "$color" "$message" "$RESET"
}

rainbow_printf() {
    local message="$1"
    shift

    local color="${RAINBOW_COLORS[$RAINBOW_INDEX]}"

    RAINBOW_INDEX=$(( (RAINBOW_INDEX + 1) % ${#RAINBOW_COLORS[@]} ))

    printf '%s%s%s' "$color" "$(printf "$message" "$@")" "$RESET"
}

rainbow_prompt() {
    local message="$1"
    local color="${RAINBOW_COLORS[$RAINBOW_INDEX]}"

    RAINBOW_INDEX=$(( (RAINBOW_INDEX + 1) % ${#RAINBOW_COLORS[@]} ))

    printf '%s%s%s' "$color" "$message" "$RESET"
}

rainbow_progress() {
    local message="$1"
    local color="${RAINBOW_COLORS[$RAINBOW_INDEX]}"

    RAINBOW_INDEX=$(( (RAINBOW_INDEX + 1) % ${#RAINBOW_COLORS[@]} ))

    printf '\r\033[K%s%s%s' "$color" "$message" "$RESET"
}

rainbow_cat() {
    local file="$1"

    [ -f "$file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        rainbow_print "$line"
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

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

TOOLS_DIR="$HOME/android-tools"
TMP_DIR="$HOME/.motorola-flasher-tmp"

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

success() {
    printf '%sSuccessful ✅%s\n' "$GREEN" "$RESET"
}

failed() {
    printf '%sFailed ❌%s\n' "$RED" "$RESET"
}

warning() {
    printf '%s%s%s\n' "$YELLOW" "$1" "$RESET"
}

pause_failure() {
    printf '\n'
    rainbow_prompt "Press Enter to continue..."
    read -r
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

resolve_path() {
    local path="$1"

    case "$path" in
        /sdcard/*)
            printf '%s/storage/emulated/0%s\n' "$HOME" "${path#/sdcard}"
            ;;
        /storage/emulated/0/*)
            printf '%s/storage/shared%s\n' "$HOME" "${path#/storage/emulated/0}"
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

    rainbow_print '╔══════════════════════════════════════╗'
    rainbow_print '║       MOTOROLA ROM FLASHER           ║'
    rainbow_print '║              by JINWOO               ║'
    rainbow_print '║                                      ║'

    local color="${RAINBOW_COLORS[$RAINBOW_INDEX]}"
    RAINBOW_INDEX=$(( (RAINBOW_INDEX + 1) % ${#RAINBOW_COLORS[@]} ))

    printf '%s║       Telegram: \033]8;;https://t.me/JNW_SG\033\\JNW_SG\033]8;;\033\\               ║%s\n' \
        "$color" "$RESET"

    rainbow_print '║                                      ║'
    rainbow_print '╚══════════════════════════════════════╝'
    printf '\n'
}

# ============================================================
# CLEANUP
# ============================================================

cleanup() {
    # Only remove our temporary extracted files.
    # Original user ROM ZIP/RAR/directory is never touched.
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

    warning "Termux storage access is not configured."
    rainbow_print "Setting up Termux storage..."

    if command_exists termux-setup-storage; then
        termux-setup-storage >/dev/null 2>&1
        sleep 2
    fi

    if [ -d "$HOME/storage/shared" ]; then
        success
        return 0
    fi

    warning "Unable to configure Termux storage automatically."
    return 1
}

# ============================================================
# PYTHON
# ============================================================

ensure_python() {
    if command_exists python || command_exists python3; then
        return 0
    fi

    rainbow_print "Python not found."
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

    rainbow_print "curl not found."
    rainbow_print "Installing curl..."

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

    warning "7z archive tool not found."
    rainbow_print "Installing archive extraction tool..."

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
    warning "ADB/Fastboot tools not found."
    rainbow_print "Installing Android tools..."

    if ! command_exists curl; then
        ensure_curl || return 1
    fi

    if ! curl -s https://raw.githubusercontent.com/offici5l/termux-adb-fastboot/main/install | bash; then
        failed
        return 1
    fi

    hash -r 2>/dev/null || true

    return 0
}

ensure_android_tools() {
    setup_android_tools_directory

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
    fi

    hash -r 2>/dev/null || true

    if command_exists adb; then
        ln -sf "$(command -v adb)" "$TOOLS_DIR/adb" 2>/dev/null || true
    fi

    if command_exists fastboot; then
        ln -sf "$(command -v fastboot)" "$TOOLS_DIR/fastboot" 2>/dev/null || true
    fi

    export PATH="$TOOLS_DIR:$PATH"

    if ! command_exists adb || ! command_exists fastboot; then
        failed
        return 1
    fi

    return 0
}

# ============================================================
# STARTUP SETUP
# ============================================================

startup_setup() {
    setup_termux_storage >/dev/null 2>&1 || true

    if ! ensure_python; then
        failed
        rainbow_print "Python setup failed."
        return 1
    fi

    if ! ensure_curl; then
        failed
        rainbow_print "curl setup failed."
        return 1
    fi

    if ! ensure_android_tools; then
        failed
        rainbow_print "Android tools setup failed."
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
    serial="$(adb get-serialno 2>/dev/null)"

    if [ -z "$serial" ] || [ "$serial" = "unknown" ]; then
        return 1
    fi

    DSERIAL="$serial"

    DMODE="ADB"

    DMODEL="$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    DCODENAME="$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"

    DBATTERY="$(
        adb shell dumpsys battery 2>/dev/null |
        awk -F': ' '/level:/ {print $2; exit}' |
        tr -d '\r'
    )"

    if [ -n "$DBATTERY" ]; then
        DBATTERY="${DBATTERY}%"
    else
        DBATTERY="N/A"
    fi

    DBATTERY_VOLTAGE="$(
        adb shell dumpsys battery 2>/dev/null |
        awk -F': ' '/voltage:/ {print $2; exit}' |
        tr -d '\r'
    )"

    if [ -n "$DBATTERY_VOLTAGE" ]; then
        DBATTERY_VOLTAGE="${DBATTERY_VOLTAGE} mV"
    else
        DBATTERY_VOLTAGE="N/A"
    fi

    DSLOT="$(
        adb shell getprop ro.boot.slot_suffix 2>/dev/null |
        tr -d '\r'
    )"

    if [ -z "$DSLOT" ]; then
        DSLOT="N/A"
    fi

    DBOOTLOADER="$(
        adb shell getprop ro.boot.flash.locked 2>/dev/null |
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

    local serial
    serial="$(adb get-serialno 2>/dev/null)"

    if [ -z "$serial" ] || [ "$serial" = "unknown" ]; then
        return 1
    fi

    DSERIAL="$serial"
    DMODE="ADB Sideload"

    return 0
}

# ============================================================
# FASTBOOT DEVICE DETECTION
# ============================================================

detect_fastboot_device() {
    reset_device_info

    local devices
    local serial

    devices="$(fastboot devices 2>/dev/null)"

    serial="$(printf '%s\n' "$devices" | awk 'NR==1 {print $1}')"

    if [ -z "$serial" ]; then
        return 1
    fi

    DSERIAL="$serial"
    DMODE="Fastboot"

    local value

    value="$(fastboot getvar product 2>&1 | sed -n 's/.*product: //p' | tail -n1)"
    [ -n "$value" ] && DCODENAME="$value"

    value="$(fastboot getvar product-name 2>&1 | sed -n 's/.*product-name: //p' | tail -n1)"
    [ -n "$value" ] && DMODEL="$value"

    value="$(fastboot getvar current-slot 2>&1 | sed -n 's/.*current-slot: //p' | tail -n1)"
    [ -n "$value" ] && DSLOT="$value"

    value="$(fastboot getvar unlocked 2>&1 | sed -n 's/.*unlocked: //p' | tail -n1)"

    case "$value" in
        yes)
            DBOOTLOADER="Unlocked"
            ;;
        no)
            DBOOTLOADER="Locked"
            ;;
    esac

    return 0
}

# ============================================================
# REQUIRE DEVICE FUNCTIONS
# ============================================================

require_adb_device() {
    if ! detect_adb_device; then
        failed
        red_print "No ADB device detected."
        return 1
    fi

    return 0
}

require_adb_sideload_device() {
    if ! detect_adb_sideload_device; then
        failed
        red_print "No ADB sideload device detected."
        return 1
    fi

    return 0
}

require_fastboot_device() {
    if ! detect_fastboot_device; then
        failed
        red_print "No Fastboot device detected."
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
        rainbow_print "Stock ROM path does not exist:"
        rainbow_print "$resolved"
        return 1
    fi

    # --------------------------------------------------------
    # DIRECTORY
    # --------------------------------------------------------

    if [ -d "$resolved" ]; then
        rainbow_print "Searching for flashfile.xml..."

        xml="$(find_flashfile_xml "$resolved")"

        if [ -z "$xml" ]; then
            failed
            rainbow_print "flashfile.xml not found in the selected directory."
            return 1
        fi

        STOCK_XML_PATH="$xml"
        STOCK_SOURCE_IS_ARCHIVE=0

        green_print 'Founded "flashfile.xml"'
        green_print "Using: $STOCK_XML_PATH"

        return 0
    fi

    # --------------------------------------------------------
    # ARCHIVE
    # --------------------------------------------------------

    if [ ! -f "$resolved" ]; then
        failed
        rainbow_print "Selected Stock ROM is not a valid file or directory."
        return 1
    fi

    extension="${resolved##*.}"
    extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

    case "$extension" in
        zip|rar|7z)
            ;;
        *)
            failed
            rainbow_print "Unsupported Stock ROM format."
            rainbow_print "Supported: directory, ZIP, RAR, 7Z"
            return 1
            ;;
    esac

    # Only Stock ROM archives use 7z extraction.
    # ADB Sideload never comes through this function.

    if ! ensure_7zip; then
        return 1
    fi

    archive_dir="$TMP_DIR/stock_archive"

    rm -rf "$archive_dir" 2>/dev/null
    mkdir -p "$archive_dir"

    rainbow_print "Temporary extracting..."

    archive_output="$TMP_DIR/7z_extract.log"

    rm -f "$archive_output" 2>/dev/null

    if ! 7z x \
        -y \
        "$resolved" \
        "-o$archive_dir" \
        >"$archive_output" 2>&1; then

        failed

        printf '\n'
        rainbow_print "7z error:"
        rainbow_cat "$archive_output"

        return 1
    fi

    xml="$(find_flashfile_xml "$archive_dir")"

    if [ -z "$xml" ]; then
        failed
        rainbow_print "flashfile.xml not found in extracted Stock ROM."
        return 1
    fi

    STOCK_XML_PATH="$xml"
    STOCK_TEMP_DIR="$archive_dir"
    STOCK_SOURCE_IS_ARCHIVE=1

    green_print 'Founded "flashfile.xml"'
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
                if [ -z "$filename" ]; then
                    continue
                fi

                fullpath="$xml_dir/$filename"

                if [ ! -f "$fullpath" ]; then
                    failed
                    rainbow_print "Missing flash file: $fullpath"
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

    rm -f "$output_file" 2>/dev/null

    if ! fastboot flash "$partition" "$file" >"$output_file" 2>&1; then
        printf '%sFlashing failed: %s%s\n' \
            "$RED" "$partition" "$RESET"

        printf '\n'
        rainbow_cat "$output_file"

        return 1
    fi

    return 0
}

# ============================================================
# FLASH SUPER SPARSE CHUNK GROUP
# ============================================================

flash_super_group() {
    local xml_dir="$1"
    shift

    local chunks=("$@")
    local total="${#chunks[@]}"
    local index=0
    local chunk
    local output_file="$TMP_DIR/fastboot_super.log"

    if [ "$total" -eq 0 ]; then
        return 0
    fi

    rainbow_printf "Flashing super"

    for chunk in "${chunks[@]}"; do
        index=$((index + 1))

        rm -f "$output_file" 2>/dev/null

        if ! fastboot flash super "$xml_dir/$chunk" >"$output_file" 2>&1; then
            printf '\n'
            failed
            rainbow_print "Flashing super failed at $chunk."

            printf '\n'
            rainbow_cat "$output_file"

            return 1
        fi

        local progress=$((index * 100 / total))

        rainbow_progress "Flashing super — $progress%"
    done

    printf '\n'

    return 0
}

# ============================================================
# FLASH STOCK ROM
# ============================================================

flash_stock_rom() {
    clear_screen
    show_header

    rainbow_print "STOCK ROM FLASH"
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
    local operation
    local filename
    local fullpath
    local partition

    rainbow_print "Enter stock ROM directory / ZIP / RAR / 7Z:"
    rainbow_prompt ">>> "
    read -r input

    if [ -z "$input" ]; then
        failed
        rainbow_print "No Stock ROM path entered."
        pause_failure
        return
    fi

    printf '\n'

    if ! prepare_stock_source "$input"; then
        printf '\n'
        failed
        rainbow_print "Unable to prepare stock ROM source."
        pause_failure
        return
    fi

    xml="$STOCK_XML_PATH"
    xml_dir="$(dirname "$xml")"

    printf '\n'
    rainbow_print "Checking Fastboot device..."

    if ! require_fastboot_device; then
        pause_failure
        return
    fi

    show_device_info

    printf '\n'
    rainbow_print "Validating Stock ROM files..."

    if ! validate_flashfile_files "$xml"; then
        failed
        rainbow_print "Stock ROM validation failed."
        pause_failure
        return
    fi

    green_print "Stock ROM validation successful. ✅"

    parser_output="$TMP_DIR/flashfile_steps.txt"

    if ! parse_flashfile_xml "$xml" > "$parser_output"; then
        failed
        rainbow_print "Unable to parse flashfile.xml."
        pause_failure
        return
    fi

    total_steps="$(
        grep -c '^STEP|' "$parser_output" 2>/dev/null
    )"

    if [ -z "$total_steps" ] || [ "$total_steps" -eq 0 ]; then
        failed
        rainbow_print "No flashing steps found in flashfile.xml."
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Starting Stock ROM flashing..."
    printf '\n'

    current_step=0

    local super_chunks=()
    local in_super_group=0

    while IFS='|' read -r tag operation filename; do
        [ "$tag" = "STEP" ] || continue

        if [ "$operation" = "flash" ] &&
           printf '%s' "$filename" | grep -Eq '^super\.img_sparsechunk\.'; then

            super_chunks+=("$filename")
            in_super_group=1
            continue
        fi

        if [ "$in_super_group" -eq 1 ]; then

            if ! flash_super_group "$xml_dir" "${super_chunks[@]}"; then
                failed
                rainbow_print "Stock ROM flashing failed."
                pause_failure
                return
            fi

            super_chunks=()
            in_super_group=0
        fi

        current_step=$((current_step + 1))

        case "$operation" in

            flash)
                if [ -z "$filename" ]; then
                    continue
                fi

                fullpath="$xml_dir/$filename"

                partition="$filename"
                partition="${partition%.img}"

                case "$partition" in
                    *.*)
                        partition="${partition##*/}"
                        ;;
                esac

                progress=$((current_step * 100 / total_steps))

                rainbow_progress \
                    "Flashing $partition — $progress%"

                output_file="$TMP_DIR/fastboot_output.log"
                rm -f "$output_file" 2>/dev/null

                if ! fastboot flash "$partition" "$fullpath" \
                    >"$output_file" 2>&1; then

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

                if [ -z "$partition" ]; then
                    continue
                fi

                progress=$((current_step * 100 / total_steps))

                rainbow_progress \
                    "Erasing $partition — $progress%"

                output_file="$TMP_DIR/fastboot_output.log"
                rm -f "$output_file" 2>/dev/null

                if ! fastboot erase "$partition" \
                    >"$output_file" 2>&1; then

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
                printf '\n'
                rainbow_print "Reading variable: $filename"

                fastboot getvar "$filename" >/dev/null 2>&1 || true
                ;;

            oem)
                progress=$((current_step * 100 / total_steps))

                rainbow_progress \
                    "Running fastboot oem $filename — $progress%"

                output_file="$TMP_DIR/fastboot_output.log"
                rm -f "$output_file" 2>/dev/null

                if ! fastboot oem "$filename" \
                    >"$output_file" 2>&1; then

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

                rainbow_progress \
                    "Unsupported operation: $operation — $progress%"
                ;;
        esac

    done < "$parser_output"

    # --------------------------------------------------------
    # Flash final collected super group
    # --------------------------------------------------------

    if [ "$in_super_group" -eq 1 ]; then

        if ! flash_super_group "$xml_dir" "${super_chunks[@]}"; then
            failed
            rainbow_print "Stock ROM flashing failed."
            pause_failure
            return
        fi
    fi

    printf '\n'
    success
    green_print "Stock ROM flashing completed successfully! ✅"

    # --------------------------------------------------------
    # Delete ONLY temporary extracted archive
    # --------------------------------------------------------

    if [ "$STOCK_SOURCE_IS_ARCHIVE" -eq 1 ] &&
       [ -n "$STOCK_TEMP_DIR" ] &&
       [ -d "$STOCK_TEMP_DIR" ]; then

        printf '\n'
        warning "Removing temporary extracted Stock ROM..."

        rm -rf "$STOCK_TEMP_DIR"

        if [ ! -d "$STOCK_TEMP_DIR" ]; then
            success
            green_print "Temporary extracted Stock ROM deleted successfully. 🗑️"
        else
            warning "Unable to completely remove temporary extracted files."
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
        rainbow_print '║          FLASH COMPLETE              ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. Reboot To Recovery               ║'
        rainbow_print '║  2. Reboot To System                 ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select option: "
        read -r choice

        case "$choice" in
            1)
                printf '\n'
                rainbow_prompt "Reboot to recovery? [y/N]: "
                read -r confirm

                case "$confirm" in
                    y|Y)
                        if fastboot reboot recovery >/dev/null 2>&1; then
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
                rainbow_prompt "Reboot to system? [y/N]: "
                read -r confirm

                case "$confirm" in
                    y|Y)
                        if fastboot reboot >/dev/null 2>&1; then
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
# ADB SIDELOAD
# ============================================================

adb_sideload() {
    clear_screen
    show_header

    rainbow_print "ADB SIDELOAD"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_adb_sideload_device; then
        failed
        red_print "No ADB sideload device detected."
        warning "Boot the device into ADB Sideload mode first."
        pause_failure
        return
    fi

    show_device_info

    printf '\n'
    rainbow_print "Enter path to ROM zip:"
    rainbow_prompt ">>> "
    read -r ROM

    if [ -z "$ROM" ]; then
        failed
        rainbow_print "No ROM path entered."
        pause_failure
        return
    fi

    ROM="$(resolve_path "$ROM")"

    if [ ! -f "$ROM" ]; then
        failed
        rainbow_print "ROM file not found:"
        rainbow_print "$ROM"
        pause_failure
        return
    fi

    local sideload_output="$TMP_DIR/sideload_output.log"

    rm -f "$sideload_output" 2>/dev/null

    printf '\n'
    rainbow_print "Starting ADB sideload..."

    # IMPORTANT:
    # ROM ZIP is passed directly to adb sideload.
    # No ZIP/RAR/7Z extraction is performed here.

    adb sideload "$ROM" >"$sideload_output" 2>&1 &
    local sideload_pid=$!

    local progress
    local last_progress=-1

    while kill -0 "$sideload_pid" 2>/dev/null; do

        if [ -f "$sideload_output" ]; then
            progress="$(
                grep -oE '[0-9]{1,3}%' "$sideload_output" 2>/dev/null |
                tail -n1 |
                tr -d '%'
            )"

            if [ -n "$progress" ] &&
               [ "$progress" != "$last_progress" ]; then

                if [ "$progress" -gt 100 ] 2>/dev/null; then
                    progress=100
                fi

                rainbow_progress "Sideloading — $progress%"

                last_progress="$progress"
            fi
        fi

        sleep 1
    done

    wait "$sideload_pid"
    local result=$?

    printf '\n'

    if [ "$result" -eq 0 ]; then
        success
    else
        failed
        rainbow_print "ADB sideload failed."

        printf '\n'
        rainbow_cat "$sideload_output"

        pause_failure
        return
    fi

    sleep 2
}

# ============================================================
# BOOT TWRP
# ============================================================

boot_twrp() {
    clear_screen
    show_header

    rainbow_print "BOOT TWRP"
    rainbow_print "──────────────────────────────────────"
    printf '\n'

    if ! check_fastboot_device; then
        failed
        red_print "No Fastboot device detected."
        pause_failure
        return
    fi

    show_device_info

    printf '\n'
    rainbow_print "Enter path to TWRP img:"
    rainbow_prompt ">>> "
    read -r twrp

    if [ -z "$twrp" ]; then
        failed
        rainbow_print "No TWRP image path entered."
        pause_failure
        return
    fi

    twrp="$(resolve_path "$twrp")"

    if [ ! -f "$twrp" ]; then
        failed
        rainbow_print "TWRP image not found:"
        rainbow_print "$twrp"
        pause_failure
        return
    fi

    printf '\n'
    rainbow_print "Booting TWRP..."

    local output_file="$TMP_DIR/twrp_output.log"

    rm -f "$output_file" 2>/dev/null

    # IMPORTANT:
    # TWRP IMG is passed directly to fastboot boot.
    # No archive extraction is performed here.

    if fastboot boot "$twrp" >"$output_file" 2>&1; then
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
# CUSTOM ROM MENU
# ============================================================

custom_rom_menu() {
    while true; do
        clear_screen
        show_header

        rainbow_print '╔══════════════════════════════════════╗'
        rainbow_print '║           CUSTOM ROM FLASH           ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. ADB Sideload                     ║'
        rainbow_print '║  2. Boot TWRP                        ║'
        rainbow_print '║                                      ║'
        rainbow_print '║  3. Back                             ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select option: "
        read -r choice

        case "$choice" in
            1)
                adb_sideload
                ;;

            2)
                boot_twrp
                ;;

            3)
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
        rainbow_print '║              REBOOT                  ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. adb reboot recovery              ║'
        rainbow_print '║  2. adb reboot bootloader            ║'
        rainbow_print '║  3. fastboot reboot recovery         ║'
        rainbow_print '║                                      ║'
        rainbow_print '║  4. Back                             ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select option: "
        read -r choice

        case "$choice" in
            1)
                if ! require_adb_device; then
                    pause_failure
                    continue
                fi

                if adb reboot recovery >/dev/null 2>&1; then
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

                if adb reboot bootloader >/dev/null 2>&1; then
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

                if fastboot reboot recovery >/dev/null 2>&1; then
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
        rainbow_print '║              WIPE DATA              ║'
        rainbow_print '╠══════════════════════════════════════╣'
        rainbow_print '║                                      ║'
        rainbow_print '║  1. YES                              ║'
        rainbow_print '║  2. NO                               ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select option: "
        read -r choice

        case "$choice" in
            1)
                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                printf '\n'
                warning "Wiping userdata and metadata..."

                local wipe_output="$TMP_DIR/wipe_output.log"

                rm -f "$wipe_output" 2>/dev/null

                if fastboot -w >"$wipe_output" 2>&1; then
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
                warning "Wiping userdata and metadata..."

                if fastboot -w >/dev/null 2>&1; then
                    success
                else
                    failed
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
        rainbow_print '║  1. Flash Stock ROM                  ║'
        rainbow_print '║  2. Flash Custom ROM                 ║'
        rainbow_print '║  3. Reboot                           ║'
        rainbow_print '║  4. Wipe Data                        ║'
        rainbow_print '║  5. Exit                             ║'
        rainbow_print '║                                      ║'
        rainbow_print '╚══════════════════════════════════════╝'
        printf '\n'

        rainbow_prompt "Select option: "
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
    rainbow_print "Startup setup failed."
    rainbow_print "Please check your Termux package installation."
    exit 1
fi

main_menu 0
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
    rainbow_print "Startup setup failed."
    rainbow_print "Please check your Termux package installation."
    exit 1
fi

main_menu

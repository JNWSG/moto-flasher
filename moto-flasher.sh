#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#          MOTOROLA ROM FLASHER
#                 by JINWOO
#          Telegram: JNW_SG
# ============================================================

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
RESET=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
TOOLS_DIR="$HOME/android-tools"
TMP_DIR="$HOME/.motorola-flasher-tmp"

mkdir -p "$TOOLS_DIR" 2>/dev/null
mkdir -p "$TMP_DIR" 2>/dev/null

# ------------------------------------------------------------
# Clear screen
# ------------------------------------------------------------

clear_screen() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033[2J\033[H'
    fi
}

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

success() {
    printf '%sSuccessful ✅%s\n' "$GREEN" "$RESET"
}

failed() {
    printf '%sFailed ❌%s\n' "$RED" "$RESET"
}

warning() {
    printf '%sWarning ⚠️%s\n' "$YELLOW" "$RESET"
}

pause_failure() {
    printf '\n'
    read -r -p "Press Enter to continue..."
}

# ------------------------------------------------------------
# Resolve Android paths
# ------------------------------------------------------------

resolve_path() {
    case "$1" in
        /sdcard/*)
            printf '%s\n' \
                "$HOME/storage/shared/${1#/sdcard/}"
            ;;

        /storage/emulated/0/*)
            printf '%s\n' \
                "$HOME/storage/shared/${1#/storage/emulated/0/}"
            ;;

        *)
            printf '%s\n' "$1"
            ;;
    esac
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

show_header() {

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║       MOTOROLA ROM FLASHER           ║\n'
    printf '║              by JINWOO               ║\n'
    printf '║                                      ║\n'

    printf '║       Telegram: \033]8;;https://t.me/JNW_SG\033\\JNW_SG\033]8;;\033\\               ║\n'

    printf '║                                      ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n' "$RESET"
}

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

cleanup() {
    rm -rf "$TMP_DIR"/* 2>/dev/null || true
}

trap cleanup EXIT

# ------------------------------------------------------------
# Check command
# ------------------------------------------------------------

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# Termux storage setup
# ------------------------------------------------------------

setup_termux_storage() {

    if [[ -d "$HOME/storage/shared" ]]; then
        return 0
    fi

    printf 'Termux storage directory not found.\n'
    printf 'Setting up Termux storage...\n\n'

    if command_exists termux-setup-storage; then
        termux-setup-storage >/dev/null 2>&1 || true
        sleep 2
    fi

    mkdir -p "$HOME/storage" 2>/dev/null || true

    return 0
}

# ------------------------------------------------------------
# Python
# ------------------------------------------------------------

ensure_python() {

    if command_exists python; then
        return 0
    fi

    if command_exists python3; then
        return 0
    fi

    printf 'Python not found.\n'
    printf 'Installing Python...\n'

    pkg update -y >/dev/null 2>&1
    pkg install python -y >/dev/null 2>&1

    hash -r 2>/dev/null || true

    if command_exists python ||
       command_exists python3; then

        success
        return 0
    fi

    failed
    return 1
}

# ------------------------------------------------------------
# Curl
# ------------------------------------------------------------

ensure_curl() {

    if command_exists curl; then
        return 0
    fi

    printf 'curl not found.\n'
    printf 'Installing curl...\n'

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

# ------------------------------------------------------------
# Android tools directory
# ------------------------------------------------------------

setup_android_tools_directory() {

    mkdir -p "$TOOLS_DIR" 2>/dev/null

    if [[ ! -d "$TOOLS_DIR" ]]; then

        printf '%sUnable to create Android tools directory.%s\n' \
            "$RED" \
            "$RESET"

        return 1
    fi

    chmod 755 "$TOOLS_DIR" 2>/dev/null || true

    return 0
}

# ------------------------------------------------------------
# Install ADB + Fastboot
# ------------------------------------------------------------

install_adb_fastboot() {

    printf '\n'
    printf 'ADB/Fastboot not found.\n'
    printf 'Installing ADB + Fastboot...\n\n'

    ensure_curl || return 1

    curl -s \
        https://raw.githubusercontent.com/offici5l/termux-adb-fastboot/main/install \
        | bash >/dev/null 2>&1

    hash -r 2>/dev/null || true

    sleep 1

    if command_exists adb &&
       command_exists fastboot; then

        success
        return 0
    fi

    failed
    return 1
}

# ------------------------------------------------------------
# Setup ADB/Fastboot
# ------------------------------------------------------------

ensure_android_tools() {

    setup_android_tools_directory || return 1

    local adb_path=""
    local fastboot_path=""

    if command_exists adb; then
        adb_path="$(command -v adb)"
    fi

    if command_exists fastboot; then
        fastboot_path="$(command -v fastboot)"
    fi

    if [[ -z "$adb_path" ||
          -z "$fastboot_path" ]]; then

        install_adb_fastboot || return 1

        adb_path="$(
            command -v adb 2>/dev/null || true
        )"

        fastboot_path="$(
            command -v fastboot 2>/dev/null || true
        )"
    fi

    if [[ -z "$adb_path" ||
          -z "$fastboot_path" ]]; then

        printf '%sADB/Fastboot installation failed.%s\n' \
            "$RED" \
            "$RESET"

        return 1
    fi

    chmod +x "$adb_path" 2>/dev/null || true
    chmod +x "$fastboot_path" 2>/dev/null || true

    ln -sf "$adb_path" \
        "$TOOLS_DIR/adb"

    ln -sf "$fastboot_path" \
        "$TOOLS_DIR/fastboot"

    chmod +x "$TOOLS_DIR/adb" 2>/dev/null || true
    chmod +x "$TOOLS_DIR/fastboot" 2>/dev/null || true

    case ":$PATH:" in
        *":$TOOLS_DIR:"*)
            ;;
        *)
            export PATH="$TOOLS_DIR:$PATH"
            ;;
    esac

    hash -r 2>/dev/null || true

    if command_exists adb &&
       command_exists fastboot; then
        return 0
    fi

    if [[ -x "$TOOLS_DIR/adb" &&
          -x "$TOOLS_DIR/fastboot" ]]; then
        return 0
    fi

    return 1
}

# ------------------------------------------------------------
# Startup setup
# ------------------------------------------------------------

startup_setup() {

    printf '%sChecking required environment...%s\n\n' \
        "$GREEN" \
        "$RESET"

    setup_termux_storage

    ensure_python || exit 1

    ensure_curl || exit 1

    ensure_android_tools || exit 1

    mkdir -p "$TOOLS_DIR" "$TMP_DIR"

    chmod 755 \
        "$TOOLS_DIR" \
        "$TMP_DIR" \
        2>/dev/null || true

    printf '\n'
}

# ============================================================
# DEVICE INFORMATION
# ============================================================

DSERIAL="N/A"
DMODEL="N/A"
DCODENAME="N/A"
DBATTERY="N/A"
DBATTERY_VOLTAGE="N/A"
DSLOT="N/A"
DBOOTLOADER="N/A"
DMODE="N/A"

# ------------------------------------------------------------
# Reset device information
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Get ADB property
# ------------------------------------------------------------

adb_prop() {

    local prop="$1"
    local value

    value="$(
        adb shell getprop "$prop" 2>/dev/null |
        tr -d '\r' |
        head -n 1
    )"

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
    else
        printf 'N/A\n'
    fi
}

# ------------------------------------------------------------
# Get Fastboot variable
# ------------------------------------------------------------

fastboot_var() {

    local var="$1"
    local output
    local value

    output="$(
        fastboot getvar "$var" 2>&1
    )"

    value="$(
        printf '%s\n' "$output" |
        sed -n -E \
            -e "s/^\(bootloader\)[[:space:]]*${var}:[[:space:]]*(.*)$/\1/p" \
            -e "s/^${var}:[[:space:]]*(.*)$/\1/p" |
        head -n 1
    )"

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
    else
        printf 'N/A\n'
    fi
}

# ------------------------------------------------------------
# ADB battery
# ------------------------------------------------------------

adb_battery() {

    local level

    level="$(
        adb shell dumpsys battery 2>/dev/null |
        tr -d '\r' |
        grep -m1 \
            '^[[:space:]]*level:' |
        sed -E \
            's/.*level:[[:space:]]*([0-9]+).*/\1/'
    )"

    if [[ -n "$level" ]]; then
        printf '%s%%\n' "$level"
    else
        printf 'N/A\n'
    fi
}

# ------------------------------------------------------------
# Detect normal ADB device
# ------------------------------------------------------------

detect_adb_device() {

    reset_device_info

    local line
    local serial

    line="$(
        adb devices 2>/dev/null |
        awk '$2 == "device" {print; exit}'
    )"

    if [[ -z "$line" ]]; then
        return 1
    fi

    serial="$(
        printf '%s\n' "$line" |
        awk '{print $1}'
    )"

    DSERIAL="${serial:-N/A}"

    DMODE="ADB"

    DMODEL="$(adb_prop ro.product.model)"

    DCODENAME="$(adb_prop ro.product.device)"

    DBATTERY="$(adb_battery)"

    DBATTERY_VOLTAGE="$(
        adb_prop ro.boot.battery.voltage
    )"

    if [[ "$DBATTERY_VOLTAGE" != "N/A" ]]; then
        DBATTERY_VOLTAGE="${DBATTERY_VOLTAGE} mV"
    fi

    DSLOT="$(
        adb_prop ro.boot.slot_suffix
    )"

    if [[ "$DSLOT" == "_"* ]]; then
        DSLOT="${DSLOT#_}"
    fi

    if [[ -z "$DSLOT" ]]; then
        DSLOT="N/A"
    fi

    DBOOTLOADER="$(
        adb_prop ro.boot.verifiedbootstate
    )"

    if [[ "$DBOOTLOADER" == "green" ]]; then
        DBOOTLOADER="Locked"
    elif [[ "$DBOOTLOADER" == "orange" ]]; then
        DBOOTLOADER="Unlocked"
    fi

    return 0
}

# ------------------------------------------------------------
# Detect ADB sideload device
# ------------------------------------------------------------

detect_adb_sideload_device() {

    reset_device_info

    local line
    local serial

    line="$(
        adb devices 2>/dev/null |
        awk '$2 == "sideload" {print; exit}'
    )"

    if [[ -z "$line" ]]; then
        return 1
    fi

    serial="$(
        printf '%s\n' "$line" |
        awk '{print $1}'
    )"

    DSERIAL="${serial:-N/A}"

    DMODE="ADB SIDELOAD"

    # Other information is unavailable in sideload mode.
    DMODEL="N/A"
    DCODENAME="N/A"
    DBATTERY="N/A"
    DBATTERY_VOLTAGE="N/A"
    DSLOT="N/A"
    DBOOTLOADER="N/A"

    return 0
}

# ------------------------------------------------------------
# Detect Fastboot device
# ------------------------------------------------------------

detect_fastboot_device() {

    reset_device_info

    local devices
    local securestate

    devices="$(
        fastboot devices 2>/dev/null
    )"

    if [[ -z "$devices" ]]; then
        return 1
    fi

    DSERIAL="$(fastboot_var serialno)"

    DMODEL="$(fastboot_var sku)"

    DCODENAME="$(fastboot_var product)"

    DBATTERY="N/A"

    DBATTERY_VOLTAGE="$(
        fastboot_var battery-voltage
    )"

    if [[ "$DBATTERY_VOLTAGE" != "N/A" ]]; then
        DBATTERY_VOLTAGE="${DBATTERY_VOLTAGE} mV"
    fi

    DSLOT="$(fastboot_var current-slot)"

    securestate="$(fastboot_var securestate)"

    case "$securestate" in

        flashing_unlocked|unlocked)
            DBOOTLOADER="Unlocked"
            ;;

        flashing_locked|locked)
            DBOOTLOADER="Locked"
            ;;

        *)
            DBOOTLOADER="N/A"
            ;;
    esac

    DMODE="FASTBOOT"

    return 0
}

# ------------------------------------------------------------
# Show device information
# ------------------------------------------------------------

show_device_info() {

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║          DEVICE INFORMATION          ║\n'
    printf '╠══════════════════════════════════════╣\n'

    # --------------------------------------------------------
    # Only show values which are NOT N/A.
    # --------------------------------------------------------

    if [[ "$DSERIAL" != "N/A" ]]; then
        printf '║  Serial       : %-20s ║\n' \
            "$DSERIAL"
    fi

    if [[ "$DMODEL" != "N/A" ]]; then
        printf '║  Model        : %-20s ║\n' \
            "$DMODEL"
    fi

    if [[ "$DCODENAME" != "N/A" ]]; then
        printf '║  Codename     : %-20s ║\n' \
            "$DCODENAME"
    fi

    if [[ "$DBATTERY" != "N/A" ]]; then
        printf '║  Battery      : %-20s ║\n' \
            "$DBATTERY"
    fi

    if [[ "$DBATTERY_VOLTAGE" != "N/A" ]]; then
        printf '║  Voltage      : %-20s ║\n' \
            "$DBATTERY_VOLTAGE"
    fi

    if [[ "$DSLOT" != "N/A" ]]; then
        printf '║  Slot         : %-20s ║\n' \
            "$DSLOT"
    fi

    if [[ "$DBOOTLOADER" != "N/A" ]]; then
        printf '║  Bootloader   : %-20s ║\n' \
            "$DBOOTLOADER"
    fi

    if [[ "$DMODE" != "N/A" ]]; then
        printf '║  Mode         : %-20s ║\n' \
            "$DMODE"
    fi

    printf '║                                      ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n' "$RESET"
}

# ------------------------------------------------------------
# Require Fastboot
# ------------------------------------------------------------

require_fastboot_device() {

    if ! detect_fastboot_device; then

        printf '%sFastboot device not found.%s\n' \
            "$RED" \
            "$RESET"

        printf \
            'Put the phone into Fastboot mode and try again.\n'

        return 1
    fi

    show_device_info

    return 0
}

# ------------------------------------------------------------
# Require normal ADB
# ------------------------------------------------------------

require_adb_device() {

    if ! detect_adb_device; then

        printf '%sADB device not found.%s\n' \
            "$RED" \
            "$RESET"

        printf \
            'Connect the phone with USB debugging enabled.\n'

        return 1
    fi

    show_device_info

    return 0
}

# ------------------------------------------------------------
# Require ADB sideload
# ------------------------------------------------------------

require_adb_sideload() {

    if ! detect_adb_sideload_device; then

        printf '%sADB sideload device not found.%s\n' \
            "$RED" \
            "$RESET"

        printf \
            'Boot the phone into ADB Sideload mode and try again.\n'

        return 1
    fi

    show_device_info

    return 0
}

# ------------------------------------------------------------
# Device checks
# ------------------------------------------------------------

check_fastboot_device() {

    [[ -n "$(fastboot devices 2>/dev/null)" ]]
}

check_adb_device() {

    local state

    state="$(
        adb get-state 2>/dev/null |
        tr -d '\r\n'
    )"

    [[ "$state" == "device" ]]
}

check_adb_sideload() {

    adb devices 2>/dev/null |
        awk '
            NR > 1 && $2 == "sideload" {
                found=1
            }

            END {
                exit(found ? 0 : 1)
            }
        '
}

# ============================================================
# STOCK ROM
# ============================================================

# ------------------------------------------------------------
# Find flashfile.xml
# ------------------------------------------------------------

find_flashfile_xml() {

    local dir="$1"
    local found

    if [[ -f "$dir/flashfile.xml" ]]; then
        printf '%s\n' "$dir/flashfile.xml"
        return 0
    fi

    found="$(
        find "$dir" \
            -type f \
            -iname 'flashfile.xml' \
            -print \
            -quit \
            2>/dev/null
    )"

    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    return 1
}

# ------------------------------------------------------------
# Parse flashfile.xml
# ------------------------------------------------------------

parse_flashfile_xml() {

    local xml="$1"
    local py

    py="$(
        command -v python 2>/dev/null ||
        command -v python3 2>/dev/null
    )"

    if [[ -z "$py" ]]; then
        return 1
    fi

    "$py" - "$xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

xml_file = sys.argv[1]

try:
    root = ET.parse(xml_file).getroot()
except Exception as e:
    print(
        f"XML_PARSE_ERROR\t{e}",
        file=sys.stderr
    )
    sys.exit(1)

steps = root.find("steps")

if steps is None:
    print(
        "XML_PARSE_ERROR\t<steps> not found",
        file=sys.stderr
    )
    sys.exit(1)

for step in steps.findall("step"):

    operation = (
        step.get("operation") or ""
    ).strip()

    if operation == "flash":

        partition = (
            step.get("partition") or ""
        ).strip()

        filename = (
            step.get("filename") or ""
        ).strip()

        if not partition or not filename:

            print(
                "XML_PARSE_ERROR\tflash step missing "
                "partition/filename",
                file=sys.stderr
            )

            sys.exit(1)

        print(
            f"flash\t{partition}\t{filename}"
        )

    elif operation == "erase":

        partition = (
            step.get("partition") or ""
        ).strip()

        if not partition:

            print(
                "XML_PARSE_ERROR\terase step missing "
                "partition",
                file=sys.stderr
            )

            sys.exit(1)

        print(
            f"erase\t{partition}"
        )

    elif operation == "getvar":

        var = (
            step.get("var") or ""
        ).strip()

        if not var:

            print(
                "XML_PARSE_ERROR\tgetvar step missing var",
                file=sys.stderr
            )

            sys.exit(1)

        print(
            f"getvar\t{var}"
        )

    elif operation == "oem":

        var = (
            step.get("var") or ""
        ).strip()

        if not var:

            print(
                "XML_PARSE_ERROR\toem step missing var",
                file=sys.stderr
            )

            sys.exit(1)

        print(
            f"oem\t{var}"
        )

    else:

        print(
            f"unsupported\t{operation}"
        )
PY
}

# ------------------------------------------------------------
# Count flash operations
# ------------------------------------------------------------

count_flash_steps() {

    local plan="$1"

    awk -F '\t' '
        $1 == "flash" {
            count++
        }

        END {
            print count + 0
        }
    ' "$plan"
}

# ------------------------------------------------------------
# Validate XML-referenced files
# ------------------------------------------------------------

validate_flash_files() {

    local xml="$1"
    local plan="$2"

    local xml_dir
    local filename
    local fullpath
    local missing=0

    local type
    local partition

    xml_dir="$(dirname "$xml")"

    while IFS=$'\t' read -r \
        type \
        partition \
        filename
    do

        [[ "$type" != "flash" ]] && continue

        fullpath="$xml_dir/$filename"

        if [[ ! -f "$fullpath" ]]; then

            printf '%sMissing file: %s%s\n' \
                "$RED" \
                "$filename" \
                "$RESET"

            missing=1
        fi

    done < "$plan"

    if (( missing != 0 )); then
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Flash normal partition
# ------------------------------------------------------------

flash_partition_with_progress() {

    local partition="$1"
    local image="$2"
    local step_index="$3"
    local flash_total="$4"

    local output_file="$TMP_DIR/fastboot_output"

    local pid
    local start_percent
    local end_percent
    local progress
    local rc

    : > "$output_file"

    if (( flash_total <= 0 )); then

        start_percent=1
        end_percent=100

    else

        start_percent=$(
            printf '%d' \
                "$(( (step_index - 1) * 100 / flash_total + 1 ))"
        )

        end_percent=$(
            printf '%d' \
                "$(( step_index * 100 / flash_total ))"
        )

        (( end_percent > 100 )) &&
            end_percent=100

        (( start_percent > end_percent )) &&
            start_percent=end_percent
    fi

    progress="$start_percent"

    printf '\r\033[K%sFlashing %s — %d%%%s' \
        "$GREEN" \
        "$partition" \
        "$progress" \
        "$RESET"

    (
        fastboot flash \
            "$partition" \
            "$image" \
            >"$output_file" \
            2>&1
    ) &

    pid=$!

    while kill -0 "$pid" 2>/dev/null; do

        if (( progress < end_percent )); then

            progress=$((progress + 1))

            printf '\r\033[K%sFlashing %s — %d%%%s' \
                "$GREEN" \
                "$partition" \
                "$progress" \
                "$RESET"
        fi

        sleep 0.12
    done

    wait "$pid"
    rc=$?

    if (( rc == 0 )); then

        progress="$end_percent"

        printf '\r\033[K%sFlashing %s — %d%%%s\n' \
            "$GREEN" \
            "$partition" \
            "$progress" \
            "$RESET"

        return 0
    fi

    printf '\r\033[K%sFlashing %s — Failed ❌%s\n' \
        "$RED" \
        "$partition" \
        "$RESET"

    return "$rc"
}

# ------------------------------------------------------------
# Super group counter
# ------------------------------------------------------------

SUPER_GROUP_COUNT=0

# ------------------------------------------------------------
# Flash consecutive super chunks
# ------------------------------------------------------------

flash_super_group() {

    local plan_line_index="$1"
    local flash_start_index="$2"
    local flash_total="$3"
    local xml_dir="$4"

    local line_type
    local partition
    local filename
    local fullpath

    local chunk_count=0
    local chunk_index=0

    local start_percent
    local end_percent
    local progress
    local completed_percent

    local output_file
    local pid
    local rc

    SUPER_GROUP_COUNT=0

    while IFS=$'\t' read -r \
        line_type \
        partition \
        filename
    do

        if [[ "$line_type" != "flash" ||
              "$partition" != "super" ]]; then
            break
        fi

        chunk_count=$((chunk_count + 1))

    done < <(
        tail -n +"$plan_line_index" \
            "$TMP_DIR/stock_plan"
    )

    if (( chunk_count <= 0 )); then
        return 1
    fi

    SUPER_GROUP_COUNT="$chunk_count"

    start_percent=$(
        printf '%d' \
            "$(( (flash_start_index - 1) * 100 / flash_total + 1 ))"
    )

    end_percent=$(
        printf '%d' \
            "$(( (flash_start_index + chunk_count - 1) * 100 / flash_total ))"
    )

    (( end_percent > 100 )) &&
        end_percent=100

    (( start_percent > end_percent )) &&
        start_percent=end_percent

    progress="$start_percent"

    output_file="$TMP_DIR/super_output"

    : > "$output_file"

    printf '\r\033[K%sFlashing super — %d%%%s' \
        "$GREEN" \
        "$progress" \
        "$RESET"

    while IFS=$'\t' read -r \
        line_type \
        partition \
        filename
    do

        if [[ "$line_type" != "flash" ||
              "$partition" != "super" ]]; then
            break
        fi

        chunk_index=$((chunk_index + 1))

        fullpath="$xml_dir/$filename"

        (
            fastboot flash \
                super \
                "$fullpath" \
                >>"$output_file" \
                2>&1
        ) &

        pid=$!

        while kill -0 "$pid" 2>/dev/null; do

            completed_percent=$(
                printf '%d' \
                    "$(( start_percent +
                         ((chunk_index - 1) *
                          (end_percent - start_percent) /
                          chunk_count) ))"
            )

            printf '\r\033[K%sFlashing super — %d%%%s' \
                "$GREEN" \
                "$completed_percent" \
                "$RESET"

            sleep 0.12
        done

        wait "$pid"
        rc=$?

        if (( rc != 0 )); then

            printf \
                '\r\033[K%sFlashing super — Failed ❌%s\n' \
                "$RED" \
                "$RESET"

            printf '\n%sFastboot error:%s\n' \
                "$RED" \
                "$RESET"

            if [[ -s "$output_file" ]]; then

                printf '%s' "$RED"

                cat "$output_file"

                printf '%s\n' "$RESET"
            fi

            return "$rc"
        fi

        progress=$(
            printf '%d' \
                "$(( start_percent +
                     (chunk_index *
                      (end_percent - start_percent) /
                      chunk_count) ))"
        )

        (( progress > end_percent )) &&
            progress="$end_percent"

        printf '\r\033[K%sFlashing super — %d%%%s' \
            "$GREEN" \
            "$progress" \
            "$RESET"

    done < <(
        tail -n +"$plan_line_index" \
            "$TMP_DIR/stock_plan"
    )

    progress="$end_percent"

    printf \
        '\r\033[K%sFlashing super — %d%%%s\n' \
        "$GREEN" \
        "$progress" \
        "$RESET"

    return 0
}

# ============================================================
# FLASH STOCK ROM
# ============================================================

flash_stock_rom() {

    clear_screen
    show_header

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║          FLASH STOCK ROM             ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n\n' "$RESET"

    printf 'Enter stock ROM directory:\n\n'

    read -r stock_dir

    stock_dir="$(resolve_path "$stock_dir")"

    if [[ ! -d "$stock_dir" ]]; then

        printf '%sDirectory not found.%s\n' \
            "$RED" \
            "$RESET"

        pause_failure
        return
    fi

    printf '\n'
    printf 'Searching for flashfile.xml...\n'

    local xml

    xml="$(find_flashfile_xml "$stock_dir")"

    if [[ -z "$xml" ]]; then

        printf '%sflashfile.xml not found.%s\n' \
            "$RED" \
            "$RESET"

        pause_failure
        return
    fi

    printf '%sFounded "flashfile.xml"%s\n\n' \
        "$GREEN" \
        "$RESET"

    if ! require_fastboot_device; then
        pause_failure
        return
    fi

    printf '\n'

    local plan="$TMP_DIR/stock_plan"

    if ! parse_flashfile_xml "$xml" \
        >"$plan" \
        2>"$TMP_DIR/xml_error"
    then

        printf '%sFailed to parse flashfile.xml.%s\n' \
            "$RED" \
            "$RESET"

        if [[ -s "$TMP_DIR/xml_error" ]]; then

            printf '%s' "$RED"

            cat "$TMP_DIR/xml_error"

            printf '%s\n' "$RESET"
        fi

        pause_failure
        return
    fi

    if grep -q '^unsupported' "$plan"; then

        printf '%sUnsupported XML operation found.%s\n' \
            "$RED" \
            "$RESET"

        grep '^unsupported' "$plan"

        pause_failure
        return
    fi

    if ! validate_flash_files "$xml" "$plan"; then

        pause_failure
        return
    fi

    local flash_total

    flash_total="$(count_flash_steps "$plan")"

    if (( flash_total <= 0 )); then

        printf \
            '%sNo flash operations found in flashfile.xml.%s\n' \
            "$RED" \
            "$RESET"

        pause_failure
        return
    fi

    printf '%sFlash steps found: %d%s\n\n' \
        "$GREEN" \
        "$flash_total" \
        "$RESET"

    printf 'Starting stock ROM flashing...\n\n'

    local xml_dir
    local type
    local arg1
    local arg2
    local fullpath

    local flash_index=0
    local plan_index=1
    local rc
    local super_count

    xml_dir="$(dirname "$xml")"

    mapfile -t PLAN_LINES < "$plan"

    local plan_count="${#PLAN_LINES[@]}"

    while (( plan_index <= plan_count )); do

        IFS=$'\t' read -r \
            type \
            arg1 \
            arg2 \
            <<< "${PLAN_LINES[$((plan_index - 1))]}"

        case "$type" in

            flash)

                if [[ "$arg1" == "super" ]]; then

                    flash_index=$((flash_index + 1))

                    flash_super_group \
                        "$plan_index" \
                        "$flash_index" \
                        "$flash_total" \
                        "$xml_dir"

                    rc=$?

                    if (( rc != 0 )); then

                        failed

                        pause_failure
                        return
                    fi

                    super_count="$SUPER_GROUP_COUNT"

                    flash_index=$(
                        printf '%d' \
                            "$(( flash_index + super_count - 1 ))"
                    )

                    plan_index=$(
                        printf '%d' \
                            "$(( plan_index + super_count ))"
                    )

                    continue
                fi

                flash_index=$((flash_index + 1))

                fullpath="$xml_dir/$arg2"

                flash_partition_with_progress \
                    "$arg1" \
                    "$fullpath" \
                    "$flash_index" \
                    "$flash_total"

                rc=$?

                if (( rc != 0 )); then

                    printf '\n%sFastboot error:%s\n' \
                        "$RED" \
                        "$RESET"

                    if [[ -s "$TMP_DIR/fastboot_output" ]]; then

                        printf '%s' "$RED"

                        cat "$TMP_DIR/fastboot_output"

                        printf '%s\n' "$RESET"
                    fi

                    failed

                    pause_failure
                    return
                fi

                ;;

            erase)

                printf '%sErasing %s...%s\n' \
                    "$GREEN" \
                    "$arg1" \
                    "$RESET"

                if fastboot erase "$arg1" \
                    >"$TMP_DIR/fastboot_output" \
                    2>&1
                then

                    success

                else

                    failed

                    printf '\n%sFastboot error:%s\n' \
                        "$RED" \
                        "$RESET"

                    if [[ -s "$TMP_DIR/fastboot_output" ]]; then

                        printf '%s' "$RED"

                        cat "$TMP_DIR/fastboot_output"

                        printf '%s\n' "$RESET"
                    fi

                    pause_failure
                    return
                fi

                ;;

            getvar)

                fastboot getvar "$arg1" \
                    >"$TMP_DIR/fastboot_output" \
                    2>&1 || true

                ;;

            oem)

                printf '%sRunning OEM step...%s\n' \
                    "$GREEN" \
                    "$RESET"

                read -r -a oem_args <<< "$arg1"

                if fastboot oem "${oem_args[@]}" \
                    >"$TMP_DIR/fastboot_output" \
                    2>&1
                then

                    success

                else

                    failed

                    printf '\n%sFastboot error:%s\n' \
                        "$RED" \
                        "$RESET"

                    if [[ -s "$TMP_DIR/fastboot_output" ]]; then

                        printf '%s' "$RED"

                        cat "$TMP_DIR/fastboot_output"

                        printf '%s\n' "$RESET"
                    fi

                    pause_failure
                    return
                fi

                ;;

            *)

                printf \
                    '%sUnsupported operation: %s%s\n' \
                    "$RED" \
                    "$type" \
                    "$RESET"

                pause_failure
                return
                ;;

        esac

        plan_index=$((plan_index + 1))

    done

    printf '\n'

    printf '%sStock ROM flashing completed.%s\n' \
        "$GREEN" \
        "$RESET"

    success

    flash_complete_menu
}

# ============================================================
# ADB SIDELOAD
# ============================================================

adb_sideload_rom() {

    clear_screen
    show_header

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║         ADB SIDELOAD                 ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n\n' "$RESET"

    printf 'Enter path to ROM zip:\n\n'

    read -r rom

    rom="$(resolve_path "$rom")"

    if [[ ! -f "$rom" ]]; then

        printf '%sROM zip not found.%s\n' \
            "$RED" \
            "$RESET"

        pause_failure
        return
    fi

    if ! require_adb_sideload; then
        pause_failure
        return
    fi

    printf '\n'
    printf 'Starting ADB sideload...\n\n'

    local output_file="$TMP_DIR/adb_sideload_output"

    local pid
    local last_percent=""
    local percent=""
    local rc

    : > "$output_file"

    (
        adb sideload "$rom" \
            >"$output_file" \
            2>&1
    ) &

    pid=$!

    while kill -0 "$pid" 2>/dev/null; do

        percent="$(
            grep -oE '[0-9]{1,3}%' \
                "$output_file" \
                2>/dev/null |
            tail -n 1 |
            tr -d '%' ||
            true
        )"

        if [[ -n "$percent" &&
              "$percent" != "$last_percent" ]]; then

            if (( percent > 100 )); then
                percent=100
            fi

            printf \
                '\r\033[K%sSideloading — %s%%%s' \
                "$GREEN" \
                "$percent" \
                "$RESET"

            last_percent="$percent"
        fi

        sleep 0.15
    done

    wait "$pid"
    rc=$?

    if (( rc == 0 )); then

        printf \
            '\r\033[K%sSideloading — 100%%%s\n' \
            "$GREEN" \
            "$RESET"

        printf '\n'

        success

        flash_complete_menu

        return
    fi

    printf \
        '\r\033[K%sSideloading — Failed ❌%s\n\n' \
        "$RED" \
        "$RESET"

    printf '%sADB error:%s\n' \
        "$RED" \
        "$RESET"

    if [[ -s "$output_file" ]]; then

        printf '%s' "$RED"

        cat "$output_file"

        printf '%s\n' "$RESET"
    fi

    failed

    pause_failure
}

# ============================================================
# BOOT TWRP
# ============================================================

boot_twrp() {

    clear_screen
    show_header

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║            BOOT TWRP                 ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n\n' "$RESET"

    printf 'Enter path to TWRP img:\n\n'

    read -r twrp

    twrp="$(resolve_path "$twrp")"

    if [[ ! -f "$twrp" ]]; then

        printf '%sTWRP image not found.%s\n' \
            "$RED" \
            "$RESET"

        pause_failure
        return
    fi

    if ! require_fastboot_device; then
        pause_failure
        return
    fi

    printf '\n'

    printf '%sBooting TWRP...%s\n' \
        "$GREEN" \
        "$RESET"

    local output_file="$TMP_DIR/twrp_output"

    if fastboot boot "$twrp" \
        >"$output_file" \
        2>&1
    then

        success
        return
    fi

    failed

    printf '\n%sFastboot error:%s\n' \
        "$RED" \
        "$RESET"

    if [[ -s "$output_file" ]]; then

        printf '%s' "$RED"

        cat "$output_file"

        printf '%s\n' "$RESET"
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

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║           CUSTOM ROM FLASH           ║\n'
        printf '╠══════════════════════════════════════╣\n'
        printf '║                                      ║\n'
        printf '║  1. ADB Sideload                     ║\n'
        printf '║  2. Boot TWRP                        ║\n'
        printf '║                                      ║\n'
        printf '║  3. Back                             ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

        case "$choice" in

            1)
                adb_sideload_rom
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

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║              REBOOT                  ║\n'
        printf '╠══════════════════════════════════════╣\n'
        printf '║                                      ║\n'
        printf '║  1. adb reboot recovery              ║\n'
        printf '║  2. adb reboot bootloader            ║\n'
        printf '║  3. fastboot reboot recovery         ║\n'
        printf '║                                      ║\n'
        printf '║  4. Back                             ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

        case "$choice" in

            1)

                clear_screen
                show_header

                if ! require_adb_device; then
                    pause_failure
                    continue
                fi

                printf '\n'

                if adb reboot recovery \
                    >/dev/null 2>&1
                then
                    success
                else
                    failed
                fi

                ;;

            2)

                clear_screen
                show_header

                if ! require_adb_device; then
                    pause_failure
                    continue
                fi

                printf '\n'

                if adb reboot bootloader \
                    >/dev/null 2>&1
                then
                    success
                else
                    failed
                fi

                ;;

            3)

                clear_screen
                show_header

                if ! require_fastboot_device; then
                    pause_failure
                    continue
                fi

                printf '\n'

                if fastboot reboot recovery \
                    >/dev/null 2>&1
                then
                    success
                else
                    failed
                fi

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

    clear_screen
    show_header

    printf '%s' "$GREEN"

    printf '╔══════════════════════════════════════╗\n'
    printf '║             WIPE DATA                ║\n'
    printf '╠══════════════════════════════════════╣\n'
    printf '║                                      ║\n'
    printf '║  Do you want to wipe data?           ║\n'
    printf '║                                      ║\n'
    printf '║  1. YES                              ║\n'
    printf '║  2. NO                               ║\n'
    printf '║                                      ║\n'
    printf '╚══════════════════════════════════════╝\n'

    printf '%s\n' "$RESET"

    while true; do

        read -r -p "Select [y/n]: " answer

        case "${answer,,}" in

            y)
                break
                ;;

            n)
                return
                ;;

            *)
                ;;
        esac

    done

    if ! require_fastboot_device; then
        pause_failure
        return
    fi

    printf '\n'
    printf 'Wiping data...\n'

    if fastboot -w \
        >"$TMP_DIR/wipe_data" \
        2>&1
    then

        printf '%sData wipe — Successful ✅%s\n' \
            "$GREEN" \
            "$RESET"

    else

        printf '%sData wipe — Failed ❌%s\n' \
            "$RED" \
            "$RESET"

        printf '\n%s' "$RED"

        cat "$TMP_DIR/wipe_data"

        printf '%s\n' "$RESET"

        pause_failure
        return
    fi
}

# ============================================================
# FLASH COMPLETE MENU
# ============================================================

flash_complete_menu() {

    while true; do

        printf '\n'

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║          FLASH COMPLETE              ║\n'
        printf '╠══════════════════════════════════════╣\n'
        printf '║                                      ║\n'
        printf '║  1. Reboot To Recovery               ║\n'
        printf '║  2. Reboot To System                 ║\n'
        printf '║                                      ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

        case "$choice" in

            1)

                printf '\n'
                printf 'Do you want to Reboot To Recovery?\n'

                read -r -p "Select [y/n]: " answer

                case "${answer,,}" in

                    y)

                        if check_fastboot_device &&
                           fastboot reboot recovery \
                               >/dev/null 2>&1
                        then

                            success

                        else

                            failed

                        fi

                        return
                        ;;

                    n)
                        return
                        ;;

                esac

                ;;

            2)

                printf '\n'
                printf 'Do you want to Reboot To System?\n'

                read -r -p "Select [y/n]: " answer

                case "${answer,,}" in

                    y)

                        if check_fastboot_device &&
                           fastboot reboot \
                               >/dev/null 2>&1
                        then

                            success

                        else

                            failed

                        fi

                        return
                        ;;

                    n)
                        return
                        ;;

                esac

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

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║                                      ║\n'
        printf '║  1. Flash Stock ROM                  ║\n'
        printf '║  2. Flash Custom ROM                 ║\n'
        printf '║  3. Reboot                           ║\n'
        printf '║  4. Wipe Data                        ║\n'
        printf '║  5. Exit                             ║\n'
        printf '║                                      ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

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
                exit 0
                ;;

        esac

    done
}

# ============================================================
# START
# ============================================================

cleanup

startup_setup

main_menu  else

        printf '%sData wipe — Failed ❌%s\n' \
            "$RED" \
            "$RESET"

        printf '\n%s' "$RED"

        cat "$TMP_DIR/wipe_data"

        printf '%s\n' "$RESET"

        pause_failure
        return
    fi
}

# ============================================================
# FLASH COMPLETE MENU
# ============================================================

flash_complete_menu() {

    while true; do

        printf '\n'

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║          FLASH COMPLETE              ║\n'
        printf '╠══════════════════════════════════════╣\n'
        printf '║                                      ║\n'
        printf '║  1. Reboot To Recovery               ║\n'
        printf '║  2. Reboot To System                 ║\n'
        printf '║                                      ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

        case "$choice" in

            1)

                printf '\n'
                printf 'Do you want to Reboot To Recovery?\n'

                read -r -p "Select [y/n]: " answer

                case "${answer,,}" in

                    y)

                        if check_fastboot_device &&
                           fastboot reboot recovery \
                               >/dev/null 2>&1
                        then

                            success

                        else

                            failed

                        fi

                        return
                        ;;

                    n)
                        return
                        ;;

                esac

                ;;

            2)

                printf '\n'
                printf 'Do you want to Reboot To System?\n'

                read -r -p "Select [y/n]: " answer

                case "${answer,,}" in

                    y)

                        if check_fastboot_device &&
                           fastboot reboot \
                               >/dev/null 2>&1
                        then

                            success

                        else

                            failed

                        fi

                        return
                        ;;

                    n)
                        return
                        ;;

                esac

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

        printf '%s' "$GREEN"

        printf '╔══════════════════════════════════════╗\n'
        printf '║                                      ║\n'
        printf '║  1. Flash Stock ROM                  ║\n'
        printf '║  2. Flash Custom ROM                 ║\n'
        printf '║  3. Reboot                           ║\n'
        printf '║  4. Wipe Data                        ║\n'
        printf '║  5. Exit                             ║\n'
        printf '║                                      ║\n'
        printf '╚══════════════════════════════════════╝\n'

        printf '%s\n' "$RESET"

        read -r -p "Select: " choice

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
                exit 0
                ;;

        esac

    done
}

# ============================================================
# START
# ============================================================

cleanup

startup_setup

main_menu

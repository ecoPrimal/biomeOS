#!/system/bin/sh
#═══════════════════════════════════════════════════════════════════════════════
# GAIA SENSORIUM v2 — Full Pixel 8a Sensor Daemon (Android-compatible grep)
#═══════════════════════════════════════════════════════════════════════════════

BIOMEOS_ROOT="/data/local/tmp/biomeos"
STATE_DIR="$BIOMEOS_ROOT/sensorium"
mkdir -p "$STATE_DIR"

CYCLE=${1:-15}
echo "GAIA SENSORIUM v2 starting — cycle=${CYCLE}s"

while true; do
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Battery (direct sysfs — fastest, no grep needed)
    BAT_LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo -1)
    BAT_STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo "unknown")
    BAT_TEMP=$(cat /sys/class/power_supply/battery/temp 2>/dev/null || echo 0)
    BAT_VOLT=$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null || echo 0)
    BAT_CURRENT=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null || echo 0)
    BAT_HEALTH=$(cat /sys/class/power_supply/battery/health 2>/dev/null || echo "unknown")
    USB_ONLINE=$(cat /sys/class/power_supply/usb/online 2>/dev/null || echo 0)

    # Thermal zones
    THERMAL_JSON="["
    FIRST=true
    for tz in /sys/class/thermal/thermal_zone*/; do
        [ ! -d "$tz" ] && continue
        TTYPE=$(cat "${tz}type" 2>/dev/null || echo "unknown")
        TTEMP=$(cat "${tz}temp" 2>/dev/null || echo 0)
        if [ "$FIRST" = true ]; then FIRST=false; else THERMAL_JSON="${THERMAL_JSON},"; fi
        THERMAL_JSON="${THERMAL_JSON}{\"zone\":\"${TTYPE}\",\"temp_mc\":${TTEMP}}"
    done
    THERMAL_JSON="${THERMAL_JSON}]"

    # WiFi — parse without -P flag
    WIFI_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    WIFI_DUMP=$(dumpsys wifi 2>/dev/null)
    WIFI_RSSI=$(echo "$WIFI_DUMP" | grep 'rssi=' | tail -1 | sed 's/.*rssi=\(-\?[0-9]*\).*/\1/' 2>/dev/null || echo "0")
    WIFI_FREQ=$(echo "$WIFI_DUMP" | grep ' f=' | tail -1 | sed 's/.*f=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
    WIFI_LINK=$(echo "$WIFI_DUMP" | grep 'link=' | tail -1 | sed 's/.*link=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
    WIFI_SSID=$(echo "$WIFI_DUMP" | grep 'SSID:' | head -1 | sed 's/.*SSID: "\([^"]*\)".*/\1/' 2>/dev/null || echo "")

    # Memory
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    MEM_PCT=$(awk "BEGIN {printf \"%.1f\", ($MEM_TOTAL - $MEM_AVAIL) * 100 / $MEM_TOTAL}")

    # Storage
    STOR_LINE=$(df /data | tail -1)
    STOR_TOTAL=$(echo "$STOR_LINE" | awk '{print $2}')
    STOR_USED=$(echo "$STOR_LINE" | awk '{print $3}')
    STOR_AVAIL=$(echo "$STOR_LINE" | awk '{print $4}')

    # Display
    DISP_DUMP=$(dumpsys display 2>/dev/null)
    SCREEN_STATE=$(echo "$DISP_DUMP" | grep 'state ON\|state OFF' | head -1 | sed 's/.*state //' | awk '{print $1}')
    BRIGHTNESS=$(echo "$DISP_DUMP" | grep 'mCachedBrightnessInfo.brightness=' | head -1 | sed 's/.*brightness=//' | awk '{print $1}')
    [ -z "$SCREEN_STATE" ] && SCREEN_STATE="unknown"
    [ -z "$BRIGHTNESS" ] && BRIGHTNESS="0"

    # CPU + uptime
    UPTIME=$(awk '{print $1}' /proc/uptime)
    CPU_LOAD=$(awk '{print $1}' /proc/loadavg)

    # Bluetooth
    BT_STATE=$(settings get global bluetooth_on 2>/dev/null || echo -1)

    # Cellular
    CELL_TYPE=$(getprop gsm.network.type 2>/dev/null || echo "none")

    # biomeOS processes
    BD_ALIVE="false"
    SB_ALIVE="false"
    DM_ALIVE="false"
    netstat -tlnp 2>/dev/null | grep -q ":9900" && BD_ALIVE="true"
    netstat -tlnp 2>/dev/null | grep -q ":9902" && SB_ALIVE="true"
    netstat -tlnp 2>/dev/null | grep -q ":8088" && DM_ALIVE="true"

    # Audio
    MEDIA_VOL=$(settings get system volume_music 2>/dev/null || echo -1)

    # Accelerometer (last known value if available)
    ACCEL=$(dumpsys sensorservice 2>/dev/null | grep -A2 "Linear Acceleration" | grep "last" | head -1 | awk '{print $NF}' 2>/dev/null || echo "0")

    # Temperature (battery temp is most reliable)
    BAT_TEMP_C=$(awk "BEGIN {printf \"%.1f\", $BAT_TEMP / 10}")
    BAT_VOLT_V=$(awk "BEGIN {printf \"%.3f\", $BAT_VOLT / 1000000}")
    BAT_CUR_MA=$(awk "BEGIN {printf \"%.1f\", $BAT_CURRENT / 1000}")

    # Write full state
    cat > "$STATE_DIR/sense.json" << SENSE_EOF
{
  "ts": "$TS",
  "device": "pixel8a",
  "gate": "grapheneGate",
  "family": "8ff3b864a4bc589a",
  "battery": {
    "level": $BAT_LEVEL,
    "status": "$BAT_STATUS",
    "temp_c": $BAT_TEMP_C,
    "voltage_v": $BAT_VOLT_V,
    "current_ma": $BAT_CUR_MA,
    "health": "$BAT_HEALTH",
    "usb_power": $USB_ONLINE
  },
  "wifi": {
    "ssid": "$WIFI_SSID",
    "rssi_dbm": $WIFI_RSSI,
    "freq_mhz": $WIFI_FREQ,
    "link_mbps": $WIFI_LINK,
    "ip": "$WIFI_IP"
  },
  "memory": {
    "total_kb": $MEM_TOTAL,
    "available_kb": $MEM_AVAIL,
    "used_pct": $MEM_PCT
  },
  "storage": {
    "total_kb": $STOR_TOTAL,
    "used_kb": $STOR_USED,
    "avail_kb": $STOR_AVAIL
  },
  "display": {
    "state": "$SCREEN_STATE",
    "brightness": $BRIGHTNESS,
    "resolution": "1080x2400",
    "refresh_hz": 120
  },
  "thermal": $THERMAL_JSON,
  "system": {
    "uptime_s": $UPTIME,
    "cpu_load": $CPU_LOAD,
    "bluetooth": $BT_STATE,
    "media_volume": $MEDIA_VOL
  },
  "cellular": {
    "type": "$CELL_TYPE"
  },
  "primals": {
    "beardog": $BD_ALIVE,
    "songbird": $SB_ALIVE,
    "dromedary": $DM_ALIVE
  }
}
SENSE_EOF

    echo "$TS bat=${BAT_LEVEL}% wifi=${WIFI_RSSI}dBm mem=${MEM_PCT}% cpu=${CPU_LOAD}"
    sleep $CYCLE
done

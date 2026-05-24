#!/usr/bin/env bash
# kingdom function: fetch_weather_line

fetch_weather_line () {
  # Opt-out via kingdom.json.welcome.weather = false
  local enabled=$(jq -r '.welcome.weather // true' "$KJSON" 2>/dev/null)
  [ "$enabled" = "false" ] && return 0

  # Geolocation
  local loc=$(curl -s --max-time 3 https://ipapi.co/json/ 2>/dev/null)
  [ -z "$loc" ] && return 0
  local city=$(echo "$loc" | jq -r '.city // empty')
  local lat=$(echo "$loc" | jq -r '.latitude // empty')
  local lon=$(echo "$loc" | jq -r '.longitude // empty')
  [ -z "$lat" ] || [ -z "$lon" ] && return 0

  # Weather
  local wx=$(curl -s --max-time 3 \
    "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code&timezone=auto" 2>/dev/null)
  [ -z "$wx" ] && return 0
  local temp=$(echo "$wx" | jq -r '.current.temperature_2m // empty')
  local feels=$(echo "$wx" | jq -r '.current.apparent_temperature // empty')
  local code=$(echo "$wx" | jq -r '.current.weather_code // empty')
  [ -z "$temp" ] && return 0

  # WMO code → emoji + label
  local emoji label
  case "$code" in
    0)     emoji="☀️";  label="clear" ;;
    1|2)   emoji="🌤️"; label="partly cloudy" ;;
    3)     emoji="☁️";  label="overcast" ;;
    45|48) emoji="🌫️"; label="fog" ;;
    51|53|55|56|57|61|63|65|66|67)
           emoji="🌧️"; label="rain" ;;
    71|73|75|77) emoji="❄️"; label="snow" ;;
    80|81|82)    emoji="🌦️"; label="showers" ;;
    95|96|99)    emoji="⛈️"; label="thunderstorm" ;;
    *)     emoji="🌍";  label="weather" ;;
  esac

  printf '%s  %s · %s°C · %s · feels like %s°C\n' "$emoji" "$city" "$temp" "$label" "$feels"
}

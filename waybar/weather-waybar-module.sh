#!/bin/bash

# Weather module wrapper - ported from the New Wave rice.
# To enable it: get a free OpenWeatherMap API key, put it in
# ~/.config/waybar/weather.py (line: appid = "...") and set YOUR latitude and
# longitude below (see ~/changes.md).

WEATHER_PATH=$HOME/.config/waybar/weather.py

LAT="<YOUR_LAT_HERE>"
LON="<YOUR_LON_HERE>"

# Stay silent until the module is configured
case "$LAT" in
    *YOUR*|"") exit 0 ;;
esac

$WEATHER_PATH --lat "$LAT" --lon "$LON" --output-format '{"text": "{{current.icon}} {{current.temperature}}°C", "alt": "{{city}}: {{current.temperature}}°C, {{current.description_long}} -> {{next.temperature}}°C, {{next.description_long}}", "tooltip": "{{city}}: {{current.temperature_min}}°C -> {{current.temperature_max}}°C"}'

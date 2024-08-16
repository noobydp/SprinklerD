#!/bin/bash
#
#  openweatherAPI        = your Openweather API key below, it's free to get one 
#  lat                   = your latitude
#  lon                   = your longitude
#  probabilityOver       = Enable rain delay if probability of rain today is grater than this number. 
#                          Range is 0 to 1, so 0.5 is 50%
#  sprinklerdEnableDelay = the URL to SprinklerD
#
# The below are NOT valid, you MUST chaneg them to your information.
openweatherAPI='xxxx'
lat='-31.9333'
lon='115.8333'

probabilityOver=1.0 # 1.0 means don't set delay from this script, use the SprinklerD config (webUI) to decide if to set delay

sprinklerdEnableDelay="http://localhost/?type=option&option=24hdelay&state=reset"
sprinklerdProbability="http://localhost/?type=sensor&sensor=chanceofrain&value="

echoerr() { printf "%s\n" "$*" >&2; }
echomsg() { if [ -t 1 ]; then echo "$@" 1>&2; fi; }

command -v curl >/dev/null 2>&1 || { echoerr "curl is not installed.  Aborting!"; exit 1; }
command -v jq >/dev/null 2>&1 || { echoerr "jq is not installed.  Aborting!"; exit 1; }
command -v bc >/dev/null 2>&1 || { echoerr "bc not installed.  Aborting!"; exit 1; }

openweatherJSON=$(curl -s "https://api.openweathermap.org/data/2.5/onecall?lat="$lat"&lon="$lon"&appid="$openweatherAPI"&exclude=current,minutely,hourly,alerts")

if [ $? -ne 0 ]; then
    echoerr "Error reading OpenWeather URL, please check!"
    echoerr "Maybe you didn't configure your API and location?"
    exit 1;
fi

openweatherRainJSON=$(curl -s "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$openweatherAPI")

if [ $? -ne 0 ]; then
    echoerr "Error reading OpenWeather Rain URL, please check!"
    echoerr "Maybe you didn't configure your API and location?"
    exit 1;
fi


# Fetch the 'rain.3h' value if it exists (default to 0 if it doesn't)
rainMM=$(echo $openweatherRainJSON | jq '.rain["3h"] // 0')

# Check if 'jq' encountered an error
if [ $? -ne 0 ]; then
    echoerr "Error reading OpenWeather Rain JSON, please check!"
    exit 1;
fi

# Convert the rain from mm to inches (1 inch = 25.4 mm)
rainInches=$(echo "scale=4; $rainMM / 25.4" | bc)

echomsg "Rain in the last 3 hours: $rainInches inches"

# Prepare the URL for the request
sprinklerdRainTotal="http://localhost/?type=sensor&sensor=raintotal&value=$rainInches"

# Send the request to the server
curl -s "$sprinklerdRainTotal" > /dev/null




probability=$(echo $openweatherJSON | jq '.["daily"][0].pop' )

#if [ $? -ne 0 ]; then
if [ "$probability" == "null" ]; then
    echoerr "Error reading OpenWeather JSON, please check!"
    exit 1;
fi


echomsg -n "Probability of rain today is "`echo "$probability * 100" | bc`"%"

curl -s "$sprinklerdProbability`echo \"$probability * 100\" | bc`" > /dev/null

if (( $(echo "$probability > $probabilityOver" | bc -l) )); then
  echomsg -n ", enabeling rain delay"
  curl -s "$sprinklerdEnableDelay" > /dev/null
fi

echomsg ""

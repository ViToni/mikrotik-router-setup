#!/bin/sh

if [ "" == "$1" ]; then
    echo "No file passed. Quitting."
    exit 1
fi
if [ ! -f "$1" ]; then
    echo "File: '"$1"' does not exist. Quitting."
    exit 1
fi

# create static DHCP leases
cat "$1" | jq -r '.network|=sort_by(.ip | split(".") | map(tonumber) ) | .network[] | select(.static_dhcp == "1") | select(.mac != "") | select(.ip != "")  | @text "  add client-id=1:\(.mac) mac-address=\(.mac) address=\(.ip) comment=\"\(.name)\""' | (echo "/ip dhcp-server lease"; cat)

# add DNS entries for static leases
cat "$1" | jq -r '.network|=sort_by(.ip | split(".") | map(tonumber) ) | .network[] | select(.static_dhcp == "1") | select(.name != "") | select(.ip != "") | @text "  add name=\"\(.name)\" address=\(.ip)"' | (echo "/ip dns static"; cat)

#!/bin/sh

usage() {
    echo "Usage:"
    echo "    $(basename $0) filename"
    exit 1
}

if [ $# -ne 1 ] || [ "-h" == "$1" ] || [ "--help" == "$1" ]; then
    usage
fi

if [ "" == "$1" ]; then
    echo "Empty file name passed. Quitting."
    usage
fi
if [ ! -f "$1" ]; then
    echo "File: '"$1"' does not exist. Quitting."
    exit 1
fi
filename=$1

BASE_FILTER=
BASE_FILTER=$BASE_FILTER'.network|=sort_by(.ip | split(".") | map(tonumber) )'
BASE_FILTER=$BASE_FILTER' | .network[]'
BASE_FILTER=$BASE_FILTER' | select(.static_dhcp == "1")'
BASE_FILTER=$BASE_FILTER' | select(.ip != "")'

# create static DHCP leases
DHCP_LEASES=$BASE_FILTER
DHCP_LEASES=$DHCP_LEASES' | select(.mac != "")'
DHCP_LEASES=$DHCP_LEASES' | @text "  add client-id=1:\(.mac) mac-address=\(.mac) address=\(.ip) comment=\"\(.name)\""'
jq -r "$DHCP_LEASES" "$filename" | (echo "/ip dhcp-server lease"; cat)

# add DNS entries for static leases
DNS_ENTRIES=$BASE_FILTER
DNS_ENTRIES=$DNS_ENTRIES' | select(.name != "")'
DNS_ENTRIES=$DNS_ENTRIES' | @text "  add name=\"\(.name)\" address=\(.ip)"'
jq -r "$DNS_ENTRIES" "$filename" | (echo "/ip dns static"; cat)

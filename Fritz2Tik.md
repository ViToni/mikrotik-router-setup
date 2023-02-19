# Migrating existing data from Fritz!Box

Documentation of steps to export data from a Fritz!Box and mangle it into a format for import into MikroTik routers.

## Exporting existing data from Fritz!Box

The Fritz!Box (tested with v7.29) provides an API to query data from the router:

```URL
http://fritz.box/query.lua?sid=<session-id>&network=landevice:settings/landevice/list(<variable-list>)
```

### Building the query

The session ID is part of any URL within the web interface when logged in.

The list of [available properties](https://boxmatrix.info/wiki/Property:landevice) is quite extensive.
The list of properties needed for the purpose of data migration is:

|Variable     |Description                         |
|-------------|------------------------------------|
|`mac`        |MAC address of device               |
|`ip`         |Current / assigned IP address       |
|`name`       |Name of device (can bes user given) |
|`dhcp`       |Does the network device use DHCP at all? (Static IP configured on the device itself). |
|`static_dhcp`|Is DHCP configured for this device to always have the same address?|
|`active`     |                                    |
|`online`     |                                    |

Resulting query:

```URL
http://fritz.box/query.lua?sid=<session-id>&network=landevice:settings/landevice/list(mac,ip,name,dhcp,static_dhcp,active,online)
```

### Data result

The returned data has the `JSON` format and is expected to be saved as `landevices.json` for the next steps.

```JSON
{"network":[
    {
        "_node":"landevice0",
        "online":"0",
        "name":"Android-3",
        "active":"0",
        "dhcp":"1",
        "mac":"01:23:45:67:89:AB",
        "static_dhcp":"0",
        "ip":"10.0.234.1"
    },
    {
        "_node":"landevice1",
        "online":"0",
        "name":"Android-5",
        "active":"0",
        "dhcp":"1",
        "mac":"12:23:34:45:56:67",
        "static_dhcp":"1",
        "ip":"10.0.25.11"
    },
    {
        "_node":"landevice2",
        "online":"1",
        "name":"Notebook-1",
        "active":"0",
        "dhcp":"1",
        "mac":"22:33:44:55:66:77",
        "static_dhcp":"1",
        "ip":"10.0.25.2"
    },
    {
        "_node":"landevice3",
        "online":"0",
        "name":"Entertain",
        "active":"1",
        "dhcp":"0",
        "mac":"30:D3:EE:EE:EE:EE",
        "static_dhcp":"0",
        "ip":""
    }
]}
```

This data is also available as sample file: [landevices.json](data/landevices.json).

### Converting the data

The returned `JSON` data can be easily queried and manipulated with [jq](https://stedolan.github.io/jq/).

#### Converting the data for DHCP leases

DHCP leases can be configured such as

```RouterOS
/ip dhcp-server lease
  add client-id=1:22:33:44:55:66:77 mac-address=22:33:44:55:66:77 address=10.0.25.2 comment="Notebook-1"
  add client-id=1:12:23:34:45:56:67 mac-address=12:23:34:45:56:67 address=10.0.25.11 comment="Android-5"
```

##### References

* MikroTik
  * [DHCP Server / Leases](https://wiki.mikrotik.com/wiki/Manual:IP/DHCP_Server#Leases)

#### Sort by IP address (lexically)

```sh
cat data/landevices.json | jq -c '.network|=sort_by(.ip) | .network[] | del(._node)'
```

Output:

```JSON
{"online":"0","name":"Entertain","active":"1","dhcp":"0","mac":"30:D3:EE:EE:EE:EE","static_dhcp":"0","ip":""}
{"online":"0","name":"Android-3","active":"0","dhcp":"1","mac":"01:23:45:67:89:AB","static_dhcp":"0","ip":"10.0.234.1"}
{"online":"0","name":"Android-5","active":"0","dhcp":"1","mac":"12:23:34:45:56:67","static_dhcp":"1","ip":"10.0.25.11"}
{"online":"1","name":"Notebook-1","active":"0","dhcp":"1","mac":"22:33:44:55:66:77","static_dhcp":"1","ip":"10.0.25.2"}
```

##### Sort by IP address (numerically)

```sh
cat data/landevices.json | jq  -c '.network|=sort_by(.ip | split(".") | map(tonumber)) | .network[] | del(._node)'
```

Output:

```JSON
{"online":"0","name":"Entertain","active":"1","dhcp":"0","mac":"30:D3:EE:EE:EE:EE","static_dhcp":"0","ip":""}
{"online":"1","name":"Notebook-1","active":"0","dhcp":"1","mac":"22:33:44:55:66:77","static_dhcp":"1","ip":"10.0.25.2"}
{"online":"0","name":"Android-5","active":"0","dhcp":"1","mac":"12:23:34:45:56:67","static_dhcp":"1","ip":"10.0.25.11"}
{"online":"0","name":"Android-3","active":"0","dhcp":"1","mac":"01:23:45:67:89:AB","static_dhcp":"0","ip":"10.0.234.1"}
```

###### References

* https://github.com/stedolan/jq/issues/708#issuecomment-75394871

#### Filter entries

Entries need to have a MAC, an IP address and need to have been used for static assignments.

```sh
cat data/landevices.json | jq -c '.network[] | select(.static_dhcp == "1") | select(.mac != "") | select(.ip != "") | del(._node)'
```

Output:

```JSON
{"online":"0","name":"Android-5","active":"0","dhcp":"1","mac":"12:23:34:45:56:67","static_dhcp":"1","ip":"10.0.25.11"}
{"online":"1","name":"Notebook-1","active":"0","dhcp":"1","mac":"22:33:44:55:66:77","static_dhcp":"1","ip":"10.0.25.2"}
```

#### Output in MikroTik format

```sh
cat data/landevices.json | jq '.network[] | @sh "add client-id=1:\(.mac) mac-address=\(.mac) address=\(.ip) comment=\"\(.name)\""'
```

```txt
"add client-id=1:'01:23:45:67:89:AB' mac-address='01:23:45:67:89:AB' address='10.0.234.1' comment=\"'Android-3'\""
"add client-id=1:'12:23:34:45:56:67' mac-address='12:23:34:45:56:67' address='10.0.25.11' comment=\"'Android-5'\""
"add client-id=1:'22:33:44:55:66:77' mac-address='22:33:44:55:66:77' address='10.0.25.2' comment=\"'Notebook-1'\""
"add client-id=1:'30:D3:EE:EE:EE:EE' mac-address='30:D3:EE:EE:EE:EE' address='' comment=\"'Entertain'\""
```

#### Output in MikroTik format (without outer quotes)

```sh
cat data/landevices.json | jq -r '.network[] | @sh "add client-id=1:\(.mac) mac-address=\(.mac) address=\(.ip) comment=\"\(.name)\""'
```

`-r` is short for `--raw-output`

Output:

```RouterOS
add client-id=1:'01:23:45:67:89:AB' mac-address='01:23:45:67:89:AB' address='10.0.234.1' comment="'Android-3'"
add client-id=1:'12:23:34:45:56:67' mac-address='12:23:34:45:56:67' address='10.0.25.11' comment="'Android-5'"
add client-id=1:'22:33:44:55:66:77' mac-address='22:33:44:55:66:77' address='10.0.25.2' comment="'Notebook-1'"
add client-id=1:'30:D3:EE:EE:EE:EE' mac-address='30:D3:EE:EE:EE:EE' address='' comment="'Entertain'"
```

#### Cleaned data formatted for MikroTik DHCP leases

```sh
cat data/landevices.json | jq -r '.network|=sort_by(.ip | split(".") | map(tonumber) ) | .network[] | select(.static_dhcp == "1") | select(.mac != "") | select(.ip != "")  | @text "  add client-id=1:\(.mac) mac-address=\(.mac) address=\(.ip) comment=\"\(.name)\""' | (echo "/ip dhcp-server lease"; cat)
```

Output:

```RouterOS
/ip dhcp-server lease
  add client-id=1:22:33:44:55:66:77 mac-address=22:33:44:55:66:77 address=10.0.25.2 comment="Notebook-1"
  add client-id=1:12:23:34:45:56:67 mac-address=12:23:34:45:56:67 address=10.0.25.11 comment="Android-5"
```

#### Add static DNS record for known hosts

```sh
cat data/landevices.json | jq -r '.network|=sort_by(.ip | split(".") | map(tonumber) ) | .network[] | select(.static_dhcp == "1") | select(.name != "") | select(.ip != "") | @text "  add name=\"\(.name)\" address=\(.ip)"' | (echo "/ip dns static"; cat)
```

Output:

```RouterOS
/ip dns static
  add name="Notebook-1" address=10.0.25.2
  add name="Android-5" address=10.0.25.11
```

##### References

* MikroTik
  * [Setting static DNS record for each DHCP lease](https://wiki.mikrotik.com/wiki/Setting_static_DNS_record_for_each_DHCP_lease)

### Shell script

The [shell script](scripts/fritz/fritz2tik.sh) combines both functions and takes a given file as argument.

```sh
scripts/fritz2tik.sh data/landevices.json
```

Output:

```RouterOS
/ip dhcp-server lease
  add client-id=1:22:33:44:55:66:77 mac-address=22:33:44:55:66:77 address=10.0.25.2 comment="Notebook-1"
  add client-id=1:12:23:34:45:56:67 mac-address=12:23:34:45:56:67 address=10.0.25.11 comment="Android-5"
/ip dns static
  add name="Notebook-1" address=10.0.25.2
  add name="Android-5" address=10.0.25.11
```

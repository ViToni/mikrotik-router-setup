#!rsc
#
# Requires RouterOS
#
# MikroTik script to update the DNS entry when Internet connection has been
# established via PPP.
#
# Assign this script in the PPP profile as "on-up" script and assign the
# profile to the PPPoE connection.
#
# Permissions required:
#   - read
#   - test (to execute ping)
#

:local notSetYet "Sync URL not set up yet";

# get name of script
:local serviceName [:jobname];  # eg. "FreeDNS"
:local syncURL;                 # eg. "http://sync.afraid.org/u/your_token/"

# abort if the URL hasn't been set up by user yet
:if ( !("$syncURL"~"^http")) do={
    :log error "$serviceName: $notSetYet";
    :error $notSetYet;
}

{
    :local maxDelay 10;
    :local counter 0;

    # check if Internet is up, pinging the nameserver of Cloudflare in this case
    :while ([:typeof ([:ping address=1.1.1.1 count=1 as-value]->"time")] = "nothing") do={
        :set counter ($counter + 1);

        # if max delay has been exceeded: abort
        :if ($counter > $maxDelay) do={
            :local msg "Failed to detect Internet => no update";

            :log warning "$serviceName: $msg";
            :error $msg;
        } else={
            # bit of delay between attempts
            :delay 500ms;
        }
    }
}

:do {
    # call update endpoint and store response
    :local result [/tool fetch url="$syncURL" as-value output=user]
    :if ($result->"status" = "finished") do={
        # add a new line as sentinel in case "data" has none
        :local response ($result->"data" . "\n") ;

        # retrieve only the first line of $response
        :local endOfFirstLine ([:find $response "\n"]);
        :set response ([:pick $response 0 $endOfFirstLine]);

        :log info "$serviceName: $response";
        :put $response;
    }
} on-error={
    :log warning "$serviceName: Failure while calling update endpoint";
}

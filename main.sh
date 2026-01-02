#!/usr/bin/env sh
set -euo pipefail

trap 'nft destroy table netdev countryblock; if pgrep curl; then pgrep curl | xargs kill -INT; fi; kill -INT $!; exit 0' INT TERM KILL

CONF_FILE=/tmp/countryblock.nft

reset_conf_file() {
    echo "destroy table netdev countryblock" >"$CONF_FILE"
    echo "table netdev countryblock {" >>"$CONF_FILE"
}

process_zone_file() {
    local zonefile="$1"
    local country="$2"
    local ip_type="$3"

    echo "  set countryblock-$country {
    type $ip_type
    flags interval, timeout
    auto-merge
    elements = {" >>"$CONF_FILE"

    if ! awk 'NF{print "      " $0 " timeout 1d,"}' "$zonefile" | sed '$s/,$//' >>"$CONF_FILE"; then
        return 1
    fi

    echo "    }
  }" >>"$CONF_FILE"
}

update_ipv4() {
    for country in $COUNTRIES; do
        local zonefile_name="${country}-aggregated.zone"
        local zonefile_remote="https://www.ipdeny.com/ipblocks/data/aggregated/${zonefile_name}"
        local zonefile="/tmp/ipv4/${zonefile_name}"
        curl -fsS -m 15 "$zonefile_remote" -o "$zonefile" -z "$zonefile" || return 1
        printf "Downloaded IPv4 %b zone file %b to %b\n" "$country" "$zonefile_remote" "$zonefile"

        # Add each IP address from the downloaded list into the ipset
        if [ -s "$zonefile" ]; then
            process_zone_file "$zonefile" "${country}4" "ipv4_addr" || return 1
        else
            echo "Error: Zone file $zonefile empty or not found."
        fi
    done
}

update_ipv6() {
    for country in $COUNTRIES; do
        local zonefile_name="${country}-aggregated.zone"
        local zonefile_remote="https://www.ipdeny.com/ipv6/ipaddresses/aggregated/${zonefile_name}"
        local zonefile="/tmp/ipv6/${zonefile_name}"
        curl -fsS -m 15 "$zonefile_remote" -o "$zonefile" -z "$zonefile" || return 1
        printf "Downloaded IPv6 %b zone file %b to %b\n" "$country" "$zonefile_remote" "$zonefile"

        # Add each IP address from the downloaded list into the ipset
        if [ -s "$zonefile" ]; then
            process_zone_file "$zonefile" "${country}6" "ipv6_addr" || return 1
        else
            echo "Error: Zone file $zonefile empty or not found."
        fi
    done
}

finalize_conf_file() {
    # does netdev have a single priority? https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks#Priority_within_hook
    echo "  chain countryblock-ingress-chain {
    type filter hook ingress device ${INTERFACE} priority 0; policy accept;
    ip protocol tcp tcp flags ack accept
    ip protocol tcp tcp flags syn,ack accept
    ip6 nexthdr tcp tcp flags ack accept
    ip6 nexthdr tcp tcp flags syn,ack accept" >>"$CONF_FILE"

    if [ -s "$IP_WHITELIST_FILE" ]; then
         cat "$IP_WHITELIST_FILE" >>"$CONF_FILE"
    fi

    for country in $COUNTRIES; do
        if [ -s "/tmp/ipv4/${country}-aggregated.zone" ]; then
            echo "    ip saddr @countryblock-${country}4 drop" >>"$CONF_FILE"
        fi
        if [ -s "/tmp/ipv6/${country}-aggregated.zone" ]; then
            echo "    ip6 saddr @countryblock-${country}6 drop" >>"$CONF_FILE"
        fi
    done

    echo "  }
}" >>"$CONF_FILE"
}

update_conf_file() {
    reset_conf_file
    update_ipv4 || return 1
    update_ipv6 || return 1
    finalize_conf_file
}

mkdir -p /tmp/ipv4 /tmp/ipv6
update_conf_file

while nft -cf "$CONF_FILE"; do
    nft -f "$CONF_FILE"
    echo "Updated nftables successfully."
    sleep "${UPDATE_PERIOD:-24h}" &
    wait $!
    update_conf_file
done

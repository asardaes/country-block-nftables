A simple Alpine container with a script that uses [ipdeny](https://www.ipdeny.com) and `nftables` to block IPs of whole countries.

Required environment variables:

- `INTERFACE`: name of the network interface that shall be the filtering target (see `sudo ip link show`)
- `COUNTRIES`: space-separated list of 2-letter country codes *but lower-case*

Optionally, specify a file in `IP_WHITELIST_FILE` with valid rules that should be inserted before the dropping rules.
It should contain lines like:

```
    ip saddr 127.0.0.1 accept
```

See [sample compose file](compose.yaml).

IMPORTANT: the rules currently use the `netdev` family, so they'd even block incoming traffic that's related to outgoing requests.
To prevent this, there are rules to accept incoming TCP packets that have any flag *in addition to* SYN set,
so you should ensure you have some rules in ip/ip6 tables that drop anything that's not a response using connection tracking:

```
ct state != { related, established } drop
```

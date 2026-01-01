A simple Alpine container with a script that uses [ipdeny](https://www.ipdeny.com) and `nftables` to block IPs of whole countries.

Required environment variables:

- `INTERFACE`: name of the network interface (see `sudo ip link show`)
- `COUNTRIES`: space-separated list of 2-letter country codes *but lower-case*

See [sample compose file](compose.yaml).

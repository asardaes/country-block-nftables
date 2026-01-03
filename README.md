A simple Alpine container with a script that uses [ipdeny](https://www.ipdeny.com) and `nftables` to block IPs of whole countries.

Environment variables:

- `INTERFACE`: name of the network interface that shall be the filtering target (see `sudo ip link show`)
- `COUNTRIES`: space-separated list of 2-letter country codes *but lower-case*
- `UPDATE_PERIOD`: something that `sleep` understands, defaults to `24h`

Optionally, specify a file in `IP_WHITELIST_FILE` with valid rules that should be inserted before the dropping rules.
It should contain lines like:

```
    ip saddr 127.0.0.1 accept
```

See [sample compose file](compose.yaml).

IMPORTANT: the rules use the `netdev` family by default, so they'd even block incoming traffic that's related to outgoing requests.
To prevent this, the rules only block packets where only the TCP SYN flag is set.
If you want to block everything for certain countries, set an environment variable `COUNTRIES_STRICT` with the same format as `COUNTRIES`
(although potentially with different content).
If you want to block everything for all `COUNTRIES`, set `COUNTRIES_STRICT` to `true`.

If your machine doesn't support `netdev`, set `NFT_NETDEV` to `false` to use an `inet` family instead.
In that case you can also set `INPUT_HOOK_PRIORITY` (defaults to -50) and omit `INTERFACE`.

# Keenetic encrypted DNS script

This script configures encrypted DNS on KeeneticOS from the BusyBox/Entware shell.

It adds only these upstreams:

- DoH: Cloudflare
- DoH: Quad9
- DoH: AdGuard unfiltered
- DoT fallback: Cloudflare, Quad9, AdGuard unfiltered

The script uses Keenetic's native command client, usually `ndmc` or `ndmq`. It does not require OpenWrt `uci`.

## Download and run on router

SSH into the router as `root`, then run:

```sh
cd /tmp
wget -O apply-encrypted-dns.sh https://ward-sentry.github.io/scipts/apply-encrypted-dns.sh
chmod +x apply-encrypted-dns.sh
./apply-encrypted-dns.sh
```

If `wget` has TLS/certificate issues, try:

```sh
cd /tmp
curl -L -o apply-encrypted-dns.sh https://ward-sentry.github.io/scipts/apply-encrypted-dns.sh
chmod +x apply-encrypted-dns.sh
./apply-encrypted-dns.sh
```

## Dry run

To print commands without applying them:

```sh
cd /tmp
DRY_RUN=1 ./apply-encrypted-dns.sh
```

## Requirements

The router shell should have one of these Keenetic command clients:

- `ndmc`
- `ndmq`

Check:

```sh
which ndmc
which ndmq
```

If both are missing, the script cannot change native Keenetic DNS settings from the shell.

## Check

After running the script:

```sh
ps | grep -Ei 'stubby|dotproxy|dnsmasq|https' | grep -v grep
cat /tmp/run/dotproxy-*.yml 2>/dev/null
```

You can also check from a LAN client:

```sh
nslookup openai.com 192.168.1.1
```

Replace `192.168.1.1` with your router IP if needed.

## Notes

During cleanup, Keenetic may print `no such server` for DNS servers that were not configured before. That is OK.

Expected Keenetic CLI commands look like this:

```text
ip name-server https://dns.cloudflare.com/dns-query
ip name-server 1.1.1.1 tls cloudflare-dns.com
```

## Backup

Before changing settings, the script saves:

```text
/opt/var/backups/keenetic-dns-YYYYMMDD-HHMMSS/running-config.txt
```

Use that file as a reference if you need to restore the previous DNS settings manually.

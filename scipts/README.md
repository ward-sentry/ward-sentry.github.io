# Encrypted DNS router script

This script configures encrypted DNS on an OpenWrt-like router:

- DoH: Cloudflare, Quad9, AdGuard unfiltered
- DoT fallback: Cloudflare, Quad9, AdGuard unfiltered

## Download and run on router

SSH into the router as root, then run:

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

## Requirements

The router should have:

- `uci`
- `dnsmasq`
- `stubby` for DoT fallback
- `https-dns-proxy` for DoH

If `https-dns-proxy` is missing, the script skips DoH and prints a warning.

## Check

After running the script:

```sh
nslookup openai.com 127.0.0.1
logread | grep -Ei 'stubby|https-dns|dnsmasq'
```

You can also check active DNS processes:

```sh
ps | grep -Ei 'stubby|https-dns|dnsmasq' | grep -v grep
```

## Backup and rollback

Before changing configs, the script creates a backup:

```text
/root/dns-backup-YYYYMMDD-HHMMSS
```

To rollback manually, copy files back from that directory, for example:

```sh
cp /root/dns-backup-YYYYMMDD-HHMMSS/dhcp /etc/config/dhcp
cp /root/dns-backup-YYYYMMDD-HHMMSS/stubby /etc/config/stubby
cp /root/dns-backup-YYYYMMDD-HHMMSS/https-dns-proxy /etc/config/https-dns-proxy

/etc/init.d/stubby restart
/etc/init.d/https-dns-proxy restart
/etc/init.d/dnsmasq restart
```

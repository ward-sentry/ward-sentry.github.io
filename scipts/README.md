# Keenetic Encrypted DNS

Install KeeneticOS components first:

- DNS-over-HTTPS
- DNS-over-TLS

Use DoH first. Use DoT as fallback.

## DoH

DoH:

```text
DNS_URL: https://dns.cloudflare.com/dns-query
```

DoH:

```text
DNS_URL: https://dns.quad9.net/dns-query
```

DoH:

```text
DNS_URL: https://unfiltered.adguard-dns.com/dns-query
```

echo "=== DNS warmup ==="
nslookup "$DOMAIN" 127.0.0.1
nslookup "$DOMAIN" 192.168.87.1 2>/dev/null || true
nslookup "$DOMAIN" 192.168.1.1 2>/dev/null || true

echo "=== Resolved IPs ==="
nslookup "$DOMAIN" 127.0.0.1 | awk '/^Address [0-9]+: / {print $3} /^Address: / {print $2}'

echo "=== Route to resolved IPs ==="
for ip in $(nslookup "$DOMAIN" 127.0.0.1 | awk '/^Address [0-9]+: / {print $3} /^Address: / {print $2}' | grep -E '^[0-9]+\.' | sort -u); do
echo "--- $ip"
ip route get "$ip"
done
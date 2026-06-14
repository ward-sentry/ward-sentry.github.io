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

## DoT Fallback

DoT:

```text
DNS_URL: 1.1.1.1
DOMAIN_TLS: cloudflare-dns.com
```

DoT:

```text
DNS_URL: 1.0.0.1
DOMAIN_TLS: cloudflare-dns.com
```

DoT:

```text
DNS_URL: 9.9.9.9
DOMAIN_TLS: dns.quad9.net
```

DoT:

```text
DNS_URL: 149.112.112.112
DOMAIN_TLS: dns.quad9.net
```

DoT:

```text
DNS_URL: 94.140.14.140
DOMAIN_TLS: unfiltered.adguard-dns.com
```

DoT:

```text
DNS_URL: 94.140.14.141
DOMAIN_TLS: unfiltered.adguard-dns.com
```

## Keenetic CLI Format

```text
dns-proxy
https upstream https://dns.cloudflare.com/dns-query dnsm
https upstream https://dns.quad9.net/dns-query dnsm
https upstream https://unfiltered.adguard-dns.com/dns-query dnsm
tls upstream 1.1.1.1 sni cloudflare-dns.com
tls upstream 1.0.0.1 sni cloudflare-dns.com
tls upstream 9.9.9.9 sni dns.quad9.net
tls upstream 149.112.112.112 sni dns.quad9.net
tls upstream 94.140.14.140 sni unfiltered.adguard-dns.com
tls upstream 94.140.14.141 sni unfiltered.adguard-dns.com
exit
system configuration save
```

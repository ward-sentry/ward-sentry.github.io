#!/bin/sh
set -eu

# Apply DoT/DoH upstreams on an OpenWrt-like router.

DOT_PORT="${DOT_PORT:-5453}"
DOH_BASE_PORT="${DOH_BASE_PORT:-5053}"
BACKUP_DIR="/root/dns-backup-$(date +%Y%m%d-%H%M%S)"

DOT_FALLBACK_RESOLVERS="
1.1.1.1 cloudflare-dns.com
1.0.0.1 cloudflare-dns.com
9.9.9.9 dns.quad9.net
149.112.112.112 dns.quad9.net
94.140.14.140 unfiltered.adguard-dns.com
94.140.14.141 unfiltered.adguard-dns.com
"

DOH_RESOLVERS="
https://dns.cloudflare.com/dns-query
https://dns.quad9.net/dns-query
https://unfiltered.adguard-dns.com/dns-query
"

need_root() {
	if [ "$(id -u)" != "0" ]; then
		echo "Run as root."
		exit 1
	fi
}

need_uci() {
	if ! command -v uci >/dev/null 2>&1; then
		echo "uci not found. This script expects OpenWrt/Entware-style UCI config."
		exit 1
	fi
}

backup_configs() {
	mkdir -p "$BACKUP_DIR"
	for cfg in dhcp stubby https-dns-proxy; do
		[ -f "/etc/config/$cfg" ] && cp "/etc/config/$cfg" "$BACKUP_DIR/$cfg"
	done
	echo "Backup saved to $BACKUP_DIR"
}

service_restart() {
	name="$1"
	if [ -x "/etc/init.d/$name" ]; then
		"/etc/init.d/$name" restart || true
	fi
}

service_enable() {
	name="$1"
	if [ -x "/etc/init.d/$name" ]; then
		"/etc/init.d/$name" enable || true
	fi
}

configure_stubby_dot() {
	if ! command -v stubby >/dev/null 2>&1 && [ ! -x /etc/init.d/stubby ]; then
		echo "stubby not found; skipping DoT. Install package: stubby"
		return
	fi

	uci -q delete stubby
	uci set stubby.global=stubby
	uci set stubby.global.manual='0'
	uci set stubby.global.trigger='wan'
	uci add_list stubby.global.dns_transport='GETDNS_TRANSPORT_TLS'
	uci set stubby.global.tls_authentication='1'
	uci set stubby.global.tls_query_padding_blocksize='128'
	uci set stubby.global.edns_client_subnet_private='1'
	uci set stubby.global.idle_timeout='10000'
	uci set stubby.global.round_robin_upstreams='1'
	uci add_list stubby.global.listen_address="127.0.0.1@$DOT_PORT"

	echo "$DOT_FALLBACK_RESOLVERS" | while read -r ip host; do
		[ -n "${ip:-}" ] || continue
		section="$(uci add stubby resolver)"
		uci set "stubby.$section.address=$ip"
		uci set "stubby.$section.tls_auth_name=$host"
	done

	uci commit stubby
	service_enable stubby
	service_restart stubby
	echo "DoT configured on 127.0.0.1#$DOT_PORT"
}

configure_https_doh() {
	if [ ! -x /etc/init.d/https-dns-proxy ]; then
		echo "https-dns-proxy not found; skipping DoH. Install package: https-dns-proxy"
		return
	fi

	uci -q delete https-dns-proxy
	port="$DOH_BASE_PORT"

	echo "$DOH_RESOLVERS" | while read -r url; do
		[ -n "${url:-}" ] || continue
		section="$(uci add https-dns-proxy https-dns-proxy)"
		uci set "https-dns-proxy.$section.resolver_url=$url"
		uci set "https-dns-proxy.$section.listen_addr=127.0.0.1"
		uci set "https-dns-proxy.$section.listen_port=$port"
		uci set "https-dns-proxy.$section.bootstrap_dns=1.1.1.1,9.9.9.9"
		uci set "https-dns-proxy.$section.user=nobody"
		uci set "https-dns-proxy.$section.group=nogroup"
		port=$((port + 1))
	done

	uci commit https-dns-proxy
	service_enable https-dns-proxy
	service_restart https-dns-proxy
	echo "DoH configured on 127.0.0.1#$DOH_BASE_PORT and following ports"
}

configure_dnsmasq() {
	uci set dhcp.@dnsmasq[0].noresolv='1'

	while uci -q delete dhcp.@dnsmasq[0].server; do :; done

	if [ -x /etc/init.d/https-dns-proxy ]; then
		port="$DOH_BASE_PORT"
		echo "$DOH_RESOLVERS" | while read -r url; do
			[ -n "${url:-}" ] || continue
			uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$port"
			port=$((port + 1))
		done
	fi

	uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$DOT_PORT"

	uci commit dhcp
	service_restart dnsmasq
	echo "dnsmasq now uses DoH first and DoT as fallback"
}

print_status() {
	echo
	echo "Configured upstreams:"
	echo "$DOH_RESOLVERS" | awk 'NF { printf "DoH  %s\n", $1 }'
	echo "$DOT_FALLBACK_RESOLVERS" | awk 'NF { printf "DoT fallback  %-16s %s\n", $1, $2 }'
	echo
	echo "Check:"
	echo "  nslookup openai.com 127.0.0.1"
	echo "  logread | grep -Ei 'stubby|https-dns|dnsmasq'"
}

need_root
need_uci
backup_configs
configure_stubby_dot
configure_https_doh
configure_dnsmasq
print_status

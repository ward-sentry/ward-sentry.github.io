#!/bin/sh
set -eu

# Apply encrypted DNS on KeeneticOS from BusyBox/Entware shell.
# Primary upstreams: DoH. Fallback upstreams: DoT.

BACKUP_DIR="/opt/var/backups/keenetic-dns-$(date +%Y%m%d-%H%M%S)"
DRY_RUN="${DRY_RUN:-0}"

DOT_REMOVE="
94.140.14.14 dns.adguard-dns.com
94.140.15.15 dns.adguard-dns.com
1.1.1.1 cloudflare-dns.com
1.0.0.1 cloudflare-dns.com
9.9.9.9 dns.quad9.net
149.112.112.112 dns.quad9.net
94.140.14.140 unfiltered.adguard-dns.com
94.140.14.141 unfiltered.adguard-dns.com
"

DOH_REMOVE="
https://dns.quad9.net/dns-query
https://dns.cloudflare.com/dns-query
https://unfiltered.adguard-dns.com/dns-query
https://xbox-dns.ru/dns-query
https://dns.malw.link/dns-query
"

DOT_ADD="
1.1.1.1 cloudflare-dns.com
1.0.0.1 cloudflare-dns.com
9.9.9.9 dns.quad9.net
149.112.112.112 dns.quad9.net
94.140.14.140 unfiltered.adguard-dns.com
94.140.14.141 unfiltered.adguard-dns.com
"

DOH_ADD="
https://dns.cloudflare.com/dns-query
https://dns.quad9.net/dns-query
https://unfiltered.adguard-dns.com/dns-query
"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

find_ndm_client() {
	for bin in ndmc /bin/ndmc /usr/bin/ndmc /sbin/ndmc /usr/sbin/ndmc; do
		if command -v "$bin" >/dev/null 2>&1; then
			NDM_BIN="$(command -v "$bin")"
			NDM_MODE="ndmc-c"
			return
		fi
		if [ -x "$bin" ]; then
			NDM_BIN="$bin"
			NDM_MODE="ndmc-c"
			return
		fi
	done

	for bin in ndmq /bin/ndmq /usr/bin/ndmq /sbin/ndmq /usr/sbin/ndmq; do
		if command -v "$bin" >/dev/null 2>&1; then
			NDM_BIN="$(command -v "$bin")"
			NDM_MODE="ndmq-p"
			return
		fi
		if [ -x "$bin" ]; then
			NDM_BIN="$bin"
			NDM_MODE="ndmq-p"
			return
		fi
	done

	NDM_BIN=""
	NDM_MODE=""
}

run_ndm() {
	cmd="$1"

	if [ "$DRY_RUN" = "1" ]; then
		echo "+ $cmd"
		return 0
	fi

	echo "+ $cmd"
	case "$NDM_MODE" in
		ndmc-c)
			"$NDM_BIN" -c "$cmd"
			;;
		ndmc-args)
			# shellcheck disable=SC2086
			"$NDM_BIN" $cmd
			;;
		ndmq-p)
			"$NDM_BIN" -p "$cmd"
			;;
		*)
			die "unknown NDM client mode"
			;;
	esac
}

probe_ndm_client() {
	find_ndm_client
	[ -n "$NDM_BIN" ] || die "ndmc/ndmq not found. Run this from KeeneticOS shell, not pure Entware chroot."

	if "$NDM_BIN" -c "show version" >/dev/null 2>&1; then
		NDM_MODE="ndmc-c"
		return
	fi

	# Some builds accept a command as positional arguments.
	if "$NDM_BIN" show version >/dev/null 2>&1; then
		NDM_MODE="ndmc-args"
		return
	fi

	if "$NDM_BIN" -p "show version" >/dev/null 2>&1; then
		NDM_MODE="ndmq-p"
		return
	fi

	die "found $NDM_BIN, but could not execute a test command through it"
}

backup_running_config() {
	mkdir -p "$BACKUP_DIR"

	if [ "$DRY_RUN" = "1" ]; then
		echo "DRY_RUN=1: skipping backup"
		return
	fi

	if run_ndm_capture "show running-config" > "$BACKUP_DIR/running-config.txt"; then
		echo "Backup saved to $BACKUP_DIR/running-config.txt"
	else
		echo "Could not save running-config backup; continuing anyway."
	fi
}

run_ndm_capture() {
	cmd="$1"
	case "$NDM_MODE" in
		ndmc-c)
			"$NDM_BIN" -c "$cmd"
			;;
		ndmc-args)
			# shellcheck disable=SC2086
			"$NDM_BIN" $cmd
			;;
		ndmq-p)
			"$NDM_BIN" -p "$cmd"
			;;
		*)
			return 1
			;;
	esac
}

run_ndm_script() {
	script="$1"

	if [ "$DRY_RUN" = "1" ]; then
		printf '%s\n' "$script" | sed 's/^/+ /'
		return 0
	fi

	printf '%s\n' "$script" | "$NDM_BIN"
}

build_dns_proxy_script() {
	{
		echo "dns-proxy"

		echo "$DOH_REMOVE" | while read -r url; do
			[ -n "${url:-}" ] || continue
			echo "no https upstream $url"
		done

		echo "$DOT_REMOVE" | while read -r ip host; do
			[ -n "${ip:-}" ] || continue
			echo "no tls upstream $ip"
		done

		echo "$DOH_ADD" | while read -r url; do
			[ -n "${url:-}" ] || continue
			echo "https upstream $url dnsm"
		done

		echo "$DOT_ADD" | while read -r ip host; do
			[ -n "${ip:-}" ] || continue
			echo "tls upstream $ip sni $host"
		done

		echo "exit"
		echo "system configuration save"
	}
}

apply_dns_proxy_config() {
	echo "Applying DNS proxy upstreams..."
	run_ndm_script "$(build_dns_proxy_script)"
}

print_status() {
	echo
	echo "Configured upstreams:"
	echo "$DOH_ADD" | awk 'NF { printf "DoH          %s\n", $1 }'
	echo "$DOT_ADD" | awk 'NF { printf "DoT fallback %-16s %s\n", $1, $2 }'
	echo
	echo "Check on router:"
	echo "  ps | grep -Ei 'stubby|dotproxy|dnsmasq|https' | grep -v grep"
	echo "  cat /tmp/run/dotproxy-*.yml 2>/dev/null"
	echo
	echo "Backup:"
	echo "  $BACKUP_DIR/running-config.txt"
}

probe_ndm_client
echo "Using $NDM_BIN ($NDM_MODE)"
backup_running_config
apply_dns_proxy_config
print_status

opkg update
opkg install ca-certificates wget-ssl
opkg remove wget-nossl

mkdir -p /opt/etc/opkg
echo "src/gz nfqws2-keenetic https://nfqws.github.io/nfqws2-keenetic/all" > /opt/etc/opkg/nfqws2-keenetic.conf

opkg update
opkg install nfqws2-keenetic

echo "src/gz nfqws-keenetic-web https://nfqws.github.io/nfqws-keenetic-web/all" > /opt/etc/opkg/nfqws-keenetic-web.conf

opkg update
opkg install nfqws-keenetic-web
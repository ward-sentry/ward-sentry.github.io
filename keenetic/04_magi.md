wget -qO- http://bin.magitrickle.dev/packages/add_repo.sh | sh

opkg update && opkg install magitrickle

/opt/etc/init.d/S99magitrickle start
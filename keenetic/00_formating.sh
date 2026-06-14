#!/bin/sh
set -eu

# Interactive macOS helper for formatting a USB flash drive partition as ext4.
# Requires Homebrew e2fsprogs: brew install e2fsprogs

MKFS_EXT4="${MKFS_EXT4:-/opt/homebrew/opt/e2fsprogs/sbin/mkfs.ext4}"
DEFAULT_LABEL="${DEFAULT_LABEL:-KEENETIC}"

say() {
	printf '%s\n' "$*"
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || die "command not found: $1"
}

read_line() {
	prompt="$1"
	printf '%s' "$prompt" >&2
	IFS= read -r value
	printf '%s' "$value"
}

is_external_disk() {
	disk="$1"
	diskutil info "/dev/$disk" | grep -q 'Protocol:.*USB\|External:.*Yes'
}

disk_size_line() {
	disk="$1"
	diskutil info "/dev/$disk" | awk -F: '/Disk Size/ { sub(/^[ \t]+/, "", $2); print $2; exit }'
}

partition_exists() {
	partition="$1"
	diskutil info "/dev/$partition" >/dev/null 2>&1
}

print_disk_list() {
	say
	say "Current disks:"
	diskutil list
	say
}

confirm_danger() {
	disk="$1"
	partition="$2"
	label="$3"

	say
	say "About to ERASE:"
	say "  Disk:      /dev/$disk"
	say "  Partition: /dev/$partition"
	say "  Label:     $label"
	say "  Size:      $(disk_size_line "$disk")"
	say
	say "Everything on /dev/$partition will be destroyed."
	say

	answer="$(read_line "Format /dev/$partition as ext4? [y/N]: ")"
	case "$answer" in
		y|Y|yes|YES)
			;;
		*)
			die "aborting"
			;;
	esac
}

format_ext4() {
	disk="$1"
	partition="$2"
	label="$3"

	say
	say "Unmounting /dev/$disk..."
	diskutil unmountDisk "/dev/$disk"

	say
	say "Formatting /dev/r$partition as ext4..."
	say "macOS will ask for your administrator password."
	sudo "$MKFS_EXT4" -F -L "$label" "/dev/r$partition"

	say
	say "Done. Ejecting /dev/$disk..."
	diskutil eject "/dev/$disk" || true

	say
	say "Formatted /dev/$partition as ext4 with label '$label'."
	say "macOS may not mount ext4 in Finder; Keenetic/Linux should see it."
}

main() {
	require_command diskutil
	[ -x "$MKFS_EXT4" ] || die "mkfs.ext4 not found at $MKFS_EXT4. Install it with: brew install e2fsprogs"

	print_disk_list

	disk="$(read_line "Enter USB disk identifier, for example disk6: ")"
	case "$disk" in
		disk[0-9]*)
			;;
		*)
			die "expected disk identifier like disk6"
			;;
	esac

	[ "$disk" != "disk0" ] || die "refusing to format internal disk0"
	diskutil info "/dev/$disk" >/dev/null 2>&1 || die "/dev/$disk not found"

	if ! is_external_disk "$disk"; then
		say
		diskutil info "/dev/$disk"
		say
		die "/dev/$disk does not look like an external USB disk"
	fi

	say
	say "Selected disk info:"
	diskutil info "/dev/$disk" | grep -E 'Device Identifier|Device Node|Whole|Protocol|External|Disk Size|Media Name'

	partition="${disk}s1"

	case "$partition" in
		"${disk}"s[0-9]*)
			;;
		*)
			die "partition must belong to /dev/$disk, for example ${disk}s1"
			;;
	esac

	partition_exists "$partition" || die "/dev/$partition not found"

	label="$DEFAULT_LABEL"

	case "$label" in
		*[!A-Za-z0-9_-]*)
			die "label may contain only letters, numbers, underscore, and dash"
			;;
	esac

	confirm_danger "$disk" "$partition" "$label"
	format_ext4 "$disk" "$partition" "$label"
}

main "$@"

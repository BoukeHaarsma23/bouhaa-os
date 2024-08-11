#! /bin/bash
# largely copied from steamos revery stuff. Thanks valve!

set -eu

die() { echo >&2 "!! $*"; exit 1; }
readvar() { IFS= read -r -d '' "$1" || true; }

# Partition numbers on ideal target device, by index
FS_ESP=1
FS_EFI_A=2
FS_EFI_B=3
FS_ROOT_A=4
FS_ROOT_B=5
FS_VAR_A=6
FS_VAR_B=7
FS_HOME=8

diskpart() { echo "$DISK$DISK_SUFFIX$1"; }

##
## Util colors and such
##

err() {
  echo >&2
  eerr "Imaging error occured, see above and restart process."
  sleep infinity
}
trap err ERR

_sh_c_colors=0
[[ -n $TERM && -t 1 && ${TERM,,} != dumb ]] && _sh_c_colors="$(tput colors 2>/dev/null || echo 0)"
sh_c() { [[ $_sh_c_colors -le 0 ]] || ( IFS=\; && echo -n $'\e['"${*:-0}m"; ); }

sh_quote() { echo "${@@Q}"; }
estat()    { echo >&2 "$(sh_c 32 1)::$(sh_c) $*"; }
emsg()     { echo >&2 "$(sh_c 34 1)::$(sh_c) $*"; }
ewarn()    { echo >&2 "$(sh_c 33 1);;$(sh_c) $*"; }
einfo()    { echo >&2 "$(sh_c 30 1)::$(sh_c) $*"; }
eerr()     { echo >&2 "$(sh_c 31 1)!!$(sh_c) $*"; }
die() { local msg="$*"; [[ -n $msg ]] || msg="script terminated"; eerr "$msg"; exit 1; }
showcmd() { showcmd_unquoted "${@@Q}"; }
showcmd_unquoted() { echo >&2 "$(sh_c 30 1)+$(sh_c) $*"; }
cmd() { showcmd "$@"; "$@"; }

# Helper to format
fmt_ext4()  { [[ $# -eq 2 && -n $1 && -n $2 ]] || die; cmd sudo mkfs.ext4 -F -L "$1" "$2"; }
fmt_fat32() { [[ $# -eq 2 && -n $1 && -n $2 ]] || die; cmd sudo mkfs.vfat -n"$1" "$2"; }

onexit=()
exithandler() {
  for func in "${onexit[@]}"; do
    "$func"
  done
}
trap exithandler EXIT

##
## Main
##

device_output=`lsblk --list -n -o name,model,size,type | grep disk | tr -s ' ' '\t'`

while read -r line; do
	name=/dev/`echo "$line" | cut -f 1`
	model=`echo "$line" | cut -f 2`
	size=`echo "$line" | cut -f 3`
	device_list+=($name)
	device_list+=("$model ($size)")
done <<< "$device_output"

DISK=$(whiptail --nocancel --menu "Choose a disk to install to:" 20 50 5 "${device_list[@]}" 3>&1 1>&2 2>&3)
if [[ $DISK == *"nvme"* ]]; then
  DISK_SUFFIX=p
else
  DISK_SUFFIX=""
fi
# Partition table, sfdisk format
readvar PARTITION_TABLE <<END_PARTITION_TABLE
  label: gpt
  ${DISK}${DISK_SUFFIX}1: name="esp",      size=    64MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  ${DISK}${DISK_SUFFIX}2: name="efi-A",    size=    32MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
  ${DISK}${DISK_SUFFIX}3: name="efi-B",    size=    32MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
  ${DISK}${DISK_SUFFIX}4: name="rootfs-A", size=  5120MiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
  ${DISK}${DISK_SUFFIX}5: name="rootfs-B", size=  5120MiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
  ${DISK}${DISK_SUFFIX}6: name="var-A",    size=   256MiB, type=4D21B016-B534-45C2-A9FB-5C16E091FD2D
  ${DISK}${DISK_SUFFIX}7: name="var-B",    size=   256MiB, type=4D21B016-B534-45C2-A9FB-5C16E091FD2D
  ${DISK}${DISK_SUFFIX}8: name="home",                     type=933AC7E1-2EB4-4F13-B844-0E14E2AEF915
END_PARTITION_TABLE

# Writing partition table to Disk
estat "Writing partition table to ${DISK}"
echo "$PARTITION_TABLE" | sfdisk "$DISK"
estat "Creating var partitions"
fmt_ext4  var  "$(diskpart $FS_VAR_A)"
fmt_ext4  var  "$(diskpart $FS_VAR_B)"

# Setup home partition
estat "Creating home partition..."
cmd sudo mkfs.ext4 -F -O casefold -T huge -L home "$(diskpart $FS_HOME)"
estat "Remove the reserved blocks on the home partition..."
tune2fs -m 0 "$(diskpart $FS_HOME)"

# Set up ESP/EFI boot partitions
estat "Creating boot partitions"
fmt_fat32 esp  "$(diskpart $FS_ESP)"
fmt_fat32 efi  "$(diskpart $FS_EFI_A)"
fmt_fat32 efi  "$(diskpart $FS_EFI_B)"

# Freeze our rootfs
estat "Freezing rootfs"
unfreeze() { fsfreeze -u /; }
onexit+=(unfreeze)
cmd fsfreeze -f /


#!/usr/bin/env bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -euxo pipefail

IMAGE_USER=ec2-user

tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
yum install -y yum-plugin-fastestmirror http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum makecache fast

packages=(
    "git"
    "ntp"
    "iptables"
    "xfsprogs"
    "lvm2"
    "device-mapper-libs"
    "libvirt-devel"
    "yum-plugin-versionlock"
    "procps-ng"
    "mdadm"
    "sysstat"
    "docker-engine-1.11.2"
  )

yum install -y ${packages[@]}

usermod -a -G docker "${IMAGE_USER}"

TARGET_DISK=/dev/md0
MDADM_CONF=/etc/mdadm/mdadm.conf
LVG=lxc
TARGET_DISK=/dev/xvdb

pvcreate ${TARGET_DISK}
vgcreate ${LVG} ${TARGET_DISK}

SWAP_MAX_SIZE=$(vgdisplay --units M ${LVG} | grep "VG Size" | awk '{ print mem=int(0.07*$3); }')
lvcreate -n swap -L $(grep MemTotal /proc/meminfo | awk -v MAXMEM=${SWAP_MAX_SIZE} '{ mem=int($2/(2*1024)); if(mem>MAXMEM) mem=MAXMEM; print mem; }')m ${LVG}
lvcreate -n data -l 100%FREE ${LVG}

mkswap /dev/${LVG}/swap
mkfs.xfs -K -n ftype=1 /dev/${LVG}/data

DATA_MOUNT_OPTIONS="defaults,pquota,prjquota,x-systemd.requires=cloud-init.service,discard"

echo "/dev/${LVG}/swap swap       swap  swap  0 0" >> /etc/fstab
echo "/dev/${LVG}/data /mnt/data  xfs   ${DATA_MOUNT_OPTIONS}  0 0" >> /etc/fstab

mkdir /mnt/data

mount -a
swapon -a
chown -R ${IMAGE_USER}:${IMAGE_USER} /mnt/data
install -d -m 0700 -o ${IMAGE_USER} -g docker /mnt/data/docker

systemctl is-enabled docker || systemctl enable docker
systemctl start docker

sysctl -w vm.max_map_count=262144

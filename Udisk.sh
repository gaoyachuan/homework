#!/bin/bash
# cpoy rhel6.iso to pxeserver's directory /tmp
file=/tmp/rhel-server-6.6-x86_64-dvd.iso
if [ ! -f $file ];then
echo 'please copy rhel iso to /tmp and name="rhel-server-6.6-x86_64-dvd.iso"'
exit 1
fi
# cpoy grub-0.97-77.el6.x86_64.rpm to pxeserver's directory /tmp
file=/tmp/grub-0.97-77.el6.x86_64.rpm
if [ ! -f $file ];then
echo 'please copy rhel iso to /tmp and name="grub-0.97-77.el6.x86_64.rpm"'
exit 1
fi
#init system
setenforcec 0
iptables -F
# set yum repo
echo "[dvd]
name=dvd
baseurl=file:///media
enabled=1
gpgcheck=0" > /etc/yum.repos.d/dvd.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-*
yum clean all
yum makecache 
yum repolist
mount -o loop /tmp/rhel-server-6.6-x86_64-dvd.iso /media
# U disk script
upn=$(df |grep   '/media' |awk  -F " "  '{print  $1}')
up=${upn%?}
umount /media/*
dd if=/dev/zero of=/dev/sdb bs=500 count=1
# fdisk
# fdisk /dev/sdb
echo "n
p
1


w
" | fdisk $up
# partprobe /dev/sdb
partprobe $up
# mkfs.ext4 /dev/sdb1
mkfs.ext4 $up
mkdir /mnt/usb
# mount /dev/sdb1  /mnt/usb/
mount $upn  /mnt/usb/
mkdir -p /dev/shm/usb
yum -y install filesystem bash coreutils passwd shadow-utils openssh-clients rpm yum net-tools bind-utils vim-enhanced findutils lvm2 util-linux-ng --installroot=/dev/shm/usb/
cp -arv /dev/shm/usb/* /mnt/usb/
cp /boot/vmlinuz-2.6.32-504.el6.x86_64  /mnt/usb/boot/
cp /boot/initramfs-2.6.32-504.el6.x86_64.img  /mnt/usb/boot/
cp -arv /lib/modules/2.6.32-504.el6.x86_64/  /mnt/usb/lib/modules/
rpm -ivh grub-0.97-77.el6.x86_64.rpm --root=/mnt/usb/ --nodeps --force
# grub-install --root-directory=/mnt/usb/  --recheck  /dev/sdb
grub-install --root-directory=/mnt/usb/  --recheck  $up
cp /boot/grub/grub.conf /mnt/usb/boot/grub/
# blkid  /dev/sdb1 
uu=$(blkid $upn |awk  -F '"'  '{print  $2}')
# vim /mnt/usb/boot/grub/grub.conf
echo "default=0
timeout=5
splashimage=(hd0,0)/boot/grub/splash.xpm.gz
title Red Hat Enterprise Linux 6 (2.6.32-504.el6.x86_64)
	root (hd0,0)
	kernel /boot/vmlinuz-2.6.32-504.el6.x86_64 ro root=UUID=$uu  rd_NO_LUKS LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto  KEYBOARDTYPE=pc KEYTABLE=us biosdevname=0 rd_NO_DM quiet
	initrd /boot/initramfs-2.6.32-504.el6.x86_64.img
" > /mnt/usb/boot/grub/grub.conf
cp /etc/skel/.bash* /mnt/usb/root/
# chroot /mnt/usb/
# exit
# vim /mnt/usb/etc/sysconfig/network
echo "NETWORKING=yes
HOSTNAME=magoo.org
" > /mnt/usb/etc/sysconfig/network
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/
# vim  /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0
sed -i 's/dhcp/static/' /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0
echo "DEVICE=eth0
ONBOOT=yes
USERCTL=no
IPADDR=192.168.0.123
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
" >> /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0
# vim /mnt/usb/etc/fstab
echo "UUID=$uu / ext4 defaults 0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
" > /mnt/usb/etc/fstab
# grub-md5-crypt 
#Password:redhat
#Retype password:redhat 
#$1$OMPqT/$Iz9AJ.3u3UROIDosqEfE2.
# vim /mnt/usb/etc/shadow 
echo "root:$1$OMPqT/$Iz9AJ.3u3UROIDosqEfE2.:15937:0:99999:7:::" > /mnt/usb/etc/shadow
sync
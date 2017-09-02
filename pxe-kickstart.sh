#！/bin/bash
#cpoy rhel7.iso to pxeserver's directory /mnt
file=/mnt/rhel-server-7.2-x86_64-dvd.iso
if [ ! -f $file ];then
echo 'please copy rhel iso to /mnt and name="rhel-server-7.2-x86_64-dvd.iso"'
exit 1
fi
#init system
systemctl stop firewalld
systemctl stop iptables
systemctl stop ip6tables
systemctl stop ebtables
setenforce 0
#set ip
nmcli connection modify eno16777736 ipv4.method manual ipv4.addresses 192.168.202.9/24 ipv4.gateway 192.168.202.2 ipv4.dns 192.168.202.2 connection.autoconnect yes
nmcli connection up eno16777736
#set yum repo
echo "/mnt/rhel-server-7.2-x86_64-dvd.iso /media iso9660 ro 0 0" >> /etc/fstab
mount -a
echo "[dvd]
name=dvd
baseurl=file:///media
enabled=1
gpgcheck=0" > /etc/yum.repos.d/dvd.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-*
yum clean all
yum makecache 
yum repolist
#set hostname
hostnamectl set-hostname pxeserver
#install dhcp
yum -y install dhcp
echo 'allow booting;
allow bootp;

option domain-name "pxeserver.example.com";
option domain-name-servers 192.168.202.2;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

subnet 192.168.202.0 netmask 255.255.255.0 {
  range 192.168.202.50 192.168.202.60;
  option domain-name-servers 192.168.202.2;
  option domain-name "pxeserver.example.com";
  option routers 192.168.202.9;
  option broadcast-address 192.168.202.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.202.9;
  filename "pxelinux.0";
}

class "foo" {
  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
}

shared-network 224-29 {
  subnet 10.17.224.0 netmask 255.255.255.0 {
    option routers rtr-224.example.org;
  }
  subnet 10.0.29.0 netmask 255.255.255.0 {
    option routers rtr-29.example.org;
  }
  pool {
    allow members of "foo";
    range 10.17.224.10 10.17.224.250;
  }
  pool {
    deny members of "foo";
    range 10.0.29.10 10.0.29.230;
  }
}
' > /etc/dhcp/dhcpd.conf
systemctl enable dhcpd
sleep 3
systemctl start dhcpd
#install xinetd tftp
yum -y install xinetd.x86_64 tftp-server.x86_64 
sed -i 's/disable.*/disable			= no/' /etc/xinetd.d/tftp
systemctl enable xinetd
sleep 3
systemctl start xinetd
#install syslinux  
yum -y install syslinux
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
#cpoy file to tftp
cp /media/isolinux/vesamenu.c32 /var/lib/tftpboot/
cp /media/isolinux/boot.msg /var/lib/tftpboot/
cp /media/isolinux/vmlinuz /var/lib/tftpboot/
cp /media/isolinux/initrd.img /var/lib/tftpboot/
#make default
mkdir /var/lib/tftpboot/pxelinux.cfg
echo "
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.202.9/ks.cfg

" > /var/lib/tftpboot/pxelinux.cfg/default
#install httpd
yum -y install httpd
systemctl enable httpd
sleep 3
systemctl start httpd
#make ks.cfg
echo '
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext redhat
# System timezone
timezone Asia/Shanghai
# Use network installation
url --url="http://192.168.202.9/dvd"
# System language
lang en_US
# Firewall configuration
firewall --disabled
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# SELinux configuration
selinux --disabled

# Network information
network  --bootproto=dhcp --device=eth0
# Reboot after installation
reboot
# System bootloader configuration
bootloader --location=none
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype="xfs" --size=200
part / --fstype="xfs" --grow --size=1

%post
useradd demo
echo 123456 | passwd --stdin demo
%end

%packages
@^graphical-server-environment
@base
@compat-libraries
@core
@desktop-debugging
@dial-up
@dns-server
@fonts
@ftp-server
@gnome-desktop
@guest-agents
@guest-desktop-agents
@input-methods
@internet-browser
@mail-server
@mariadb
@multimedia
@print-client
@virtualization-client
@virtualization-hypervisor
@virtualization-tools
@x11

%end

' > /var/www/html/ks.cfg
chown apache. /var/www/html/ks.cfg
#make http-dvd
mkdir /var/www/html/dvd
#mount /mnt/rhel-server-7.2-x86_64-dvd.iso /var/www/html/dvd
mount /mnt/rhel-server-7.2-x86_64-dvd.iso /var/www/html/dvd
echo 'pex-server build finish!'
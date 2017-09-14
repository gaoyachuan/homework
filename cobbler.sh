#！/bin/bash
#cpoy rhel6.iso to pxeserver's directory /mnt
file1=/mnt/rhel-server-6.6-x86_64-dvd.iso
if [ ! -f $file1 ];then
echo 'please copy rhel iso to /mnt and name="rhel-server-6.6-x86_64-dvd.iso"'
exit 1
else
echo 'iso is ready!'
fi

file2=/mnt/cobbler_soft/libyaml-0.1.4-2.3.x86_64.rpm
if [ ! -f $file2 ];then
echo 'please copy cobbler_soft folder to /mnt/'
exit 1
else
echo 'soft is ready!'
fi
#init system
#set ip
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "IPADDR=192.168.0.1
PREFIX=24
GATEWAY=192.168.0.254
DNS=192.168.0.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth0
service network restart
#set hostname
sed -i 's/HOSTNAME.*/HOSTNAME=cobblerserver/' /etc/sysconfig/network
hostname cobblerserver
sed -i 's/$/&.cobblerserver/g' /etc/hosts
#set yum repo
echo "[dvd]
name=dvd
baseurl=file:///media
enabled=1
gpgcheck=0" > /etc/yum.repos.d/dvd.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-*
yum clean all
yum makecache 
yum repolist
mount -o loop /mnt/rhel-server-6.6-x86_64-dvd.iso /media
#install cobbler and depends
yum -y localinstall /mnt/cobbler_soft/libyaml-0.1.4-2.3.x86_64.rpm
yum -y localinstall /mnt/cobbler_soft/PyYAML-3.10-3.1.el6.x86_64.rpm 
yum -y localinstall /mnt/cobbler_soft/koan-2.6.9-1.el6.noarch.rpm 
yum -y localinstall /mnt/cobbler_soft/Django14-1.4.20-1.el6.noarch.rpm 
yum -y localinstall /mnt/cobbler_soft/cobbler-2.6.3-1.el6.noarch.rpm 
yum -y localinstall /mnt/cobbler_soft/cobbler-web-2.6.3-1.el6.noarch.rpm
sleep 3
#config cobbler
service cobblerd restart
chkconfig cobblerd on
sed -i 's/next_server.*/next_server: 192.168.0.1/' /etc/cobbler/settings
sed -i 's/server: 127.*/server: 192.168.0.1/' /etc/cobbler/settings
setenforce 0
yum -y install syslinux
yum -y install rsync
yum -y install xinetd
chkconfig tftp on
service xinetd start
chkconfig xinetd on
iptables -F
yum -y install pykickstart
sysps=`openssl passwd -1 -salt 'random-phrase-here' 'redhat'`
sed -i "s/default_password.*/default_password_crypted: \"$sysps\"/" /etc/cobbler/settings
yum -y install fence-agents
#cobbler import mirror
mkdir -p /yum
mount -o loop /mnt/rhel-server-6.6-x86_64-dvd.iso /yum
cobbler import --path=/yum --name=rhel-server-6.6-x86_64 --arch=x86_64
sleep 3
#config dhcp
yum -y install dhcp
sed -i 's/192.168.1.0/192.168.0.0/' /etc/cobbler/dhcp.template
sed -i 's/192.168.1.5/192.168.0.254/' /etc/cobbler/dhcp.template 
sed -i 's/192.168.1.100/192.168.0.100/' /etc/cobbler/dhcp.template
sed -i 's/192.168.1.1/192.168.0.254/' /etc/cobbler/dhcp.template
sed -i 's/192.168.1.254/192.168.0.110/' /etc/cobbler/dhcp.template
sed -i  's/manage_dhcp.*/manage_dhcp: 1/' /etc/cobbler/settings
#cobbler sync
/etc/init.d/cobblerd restart
cobbler sync
echo 'cobbler-server build finish!'

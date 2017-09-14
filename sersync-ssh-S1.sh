##！/bin/bash
#cpoy rhel6.iso to pxeserver's directory /mnt
file1=/mnt/rhel-server-6.6-x86_64-dvd.iso
if [ ! -f $file1 ];then
echo 'please copy rhel iso to /mnt and name="rhel-server-6.6-x86_64-dvd.iso"'
exit 1
else
echo 'iso is ready!'
fi
#init system
setenforce 0
iptables -F
#set ip
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "IPADDR=172.16.1.25
PREFIX=24
GATEWAY=172.16.1.254
DNS=172.16.1.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth0
#set rsync
echo "
#Rsync server
uid = root
gid = root
use chroot = no
max connections = 2000
timeout = 600
pid file =/var/run/rsyncd.pid
lock file =/var/run/rsync.lock
log file = /var/log/rsyncd.log
ignore errors 
read only = false
list = false
hosts allow = 172.16.1.0/24
hosts deny = 0.0.0.0/32
auth users = rsync_backup
secrets file =/etc/rsync.password

[www]
comment = www 
path = /data/www/

#rsync_config____________end
" > vim /etc/rsyncd.conf
#set password_file
echo "rsync_backup:redhat" >/etc/rsync.password
chmod 600 /etc/rsync.password  
#set start with system
rsync --daemon
echo "
# rsync server progress
/usr/bin/rsync --daemon
" >> /etc/rc.local
#set sync_folder
mkdir -p /data/www
#set ssh-key
echo "



"|ssh-keygen -t rsa
ssh-copy-id -i /root/.ssh/id_rsa.pub root@172.16.1.20
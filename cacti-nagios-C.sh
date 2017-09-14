#！/bin/bash
#cpoy rhel7.iso to pxeserver's directory /mnt
file=/mnt/rhel-server-7.2-x86_64-dvd.iso
if [ ! -f $file ];then
echo 'please copy rhel iso to /mnt and name="rhel-server-7.2-x86_64-dvd.iso"'
exit 1
fi
file2=/root/pkg/nagios-3.5.1-1.el7.x86_64.rpm
if [ ! -f $file2 ];then
echo 'please copy nagios pkg folder to /root/'
exit 1
else
echo 'soft is ready!'
fi
file3=/root/nrpe-2.12.tar
if [ ! -f $file3 ];then
echo 'please copy nrpe tar to /root/'
exit 1
else
echo 'soft is ready!'
fi
#init system
systemctl stop firewalld
systemctl stop iptables
systemctl stop ip6tables
systemctl stop ebtables
setenforce 0
#set softer
yum install -y net-snmp-*
#set /etc/snmp/snmpd.conf
#将41行（各有不同，请自行查找）下的default更改为127.0.0.1
sed -i '41s/default/192.168.0.10/' /etc/snmp/snmpd.conf
#将62行（各有不同，请自行查找）下的systemview更改为all
sed -i '62s/systemview/all/' /etc/snmp/snmpd.conf
#将85行（各有不同，请自行查找）下的#注释掉
sed -i '85s/#//' /etc/snmp/snmpd.conf
#set start snmp
systemctl start snmpd.service

#set nagios
yum -y localinstall *.rpm
tar xf nrpe-2.12.tar
cd nrpe-2.12/

yum -y install gcc
yum -y install xinetd
yum -y install openssl-devel
./configure 
make all
make install-plugin
make install-daemon
make install-daemon-config
make install-xinetd

sed -i 's/127.0.0.1/127.0.0.1 172.25.1.10/' /etc/xinetd.d/nrpe

echo "nrpe 5666/tcp # nrpe" >> /etc/services

sed  '/^command.*$/d' /usr/local/nagios/etc/nrpe.cfg
echo "
command[check_user]=/usr/lib64/nagios/plugins/check_users -w 5 -c 10
command[check_load]=/usr/lib64/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_root]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /
command[check_zombie_procs]=/usr/lib64/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/lib64/nagios/plugins/check_procs -w 150 -c 200 
command[check_swap]=/usr/lib64/nagios/plugins/check_swap -w 20% -c 10%
" >> /usr/local/nagios/etc/nrpe.cfg

systemctl restart  xinetd
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
file3=/root/pkg/cacti-0.8.8f.tar.gz
if [ ! -f $file3 ];then
echo 'please copy cacti file to /root/'
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
yum -y install httpd*
yum -y install php* 
yum -y install mariadb*
yum -y install net-snmp*
yum -y install rrdtool rrdtool-devel rrdtool-php rrdtool-perl
yum install gd gd-devel php-gd
#set /etc/snmp/snmpd.conf
#将41行（各有不同，请自行查找）下的default更改为127.0.0.1
sed -i '41s/default/127.0.0.1/' /etc/snmp/snmpd.conf
#将62行（各有不同，请自行查找）下的systemview更改为all
sed -i '62s/systemview/all/' /etc/snmp/snmpd.conf
#将85行（各有不同，请自行查找）下的#注释掉
sed -i '85s/#//' /etc/snmp/snmpd.conf
#set start snmp
systemctl start snmpd.service
#set MariaDB
systemctl start mariadb.service
 
mysqladmin -u root -p password "redhat"
mysql -uroot -predhat -e "  
grant all privileges on *.* to root@localhost identified by ‘wang’ with grant option;
flush privileges;
create database cacti default character set utf8;
grant all privileges on cacti.* to cacti@localhost identified by ‘cacti’ with grant option;
flush privileges;
quit"
#set cacti
tar -zxvf cacti-0.8.8f.tar.gz
mv cacti-0.8.8f /var/www/html/cacti 
mysql -ucacti -pcacti cacti < /var/www/html/cacti/cacti.sql 

#set global.php config.php
sed 's/$database_username = "cactiuser"/$database_username = "cacti"/' /var/www/html/cacti/include/config.php
sed 's/$database_password = "cactiuser"/$database_password = "redhat"/' /var/www/html/cacti/include/config.php
sed 's/$database_username = "cactiuser"/$database_username = "cacti"/' /var/www/html/cacti/include/global.php
sed 's/$database_password = "cactiuser"/$database_password = "redhat"/' /var/www/html/cacti/include/global.php

useradd –r –M cacti 
chown –R cacti /var/www/html/cacti/rra/ 
chown –R cacti /var/www/html/cacti/log/ 
 
#set crontab
echo '*/5 * * * * php /var/www/html/cacti/poller.php > /dev/null 2>&1' > /var/spool/cron/root
 
systemctl start httpd.service
 
timedatectl set-local-rtc yes
date +%s 

#set nagios：
yum localinstall *.rpm

htpasswd -c /etc/nagios/passwd nagiosadmin
cat /etc/nagios/passwd 
systemctl restart httpd

#set nagois
echo "
define command{
      command_name check_nrpe       
      command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}
" >> /etc/nagios/objects/commands.cfg

echo "
define host{
     use                     linux-server                                                         
     host_name               serverb.pod1.example.com
     alias                   serverb1
     address                 172.25.1.11
}
define hostgroup{
     hostgroup_name  uplooking-servers 
     alias           uplooking 
     members         serverb.pod1.example.com     
}
# 定义监控服务
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description load
     check_command check_nrpe!check_load
}
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description user
     check_command check_nrpe!check_user
}
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description root
     check_command check_nrpe!check_root
}
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description zombie
     check_command check_nrpe!check_zombie_procs
}
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description procs
     check_command check_nrpe!check_total_procs
}
define service{
     use generic-service
     host_name serverb.pod1.example.com
     service_description swap
     check_command check_nrpe!check_swap
}
" > /etc/nagios/objects/serverb.cfg

echo "cfg_file=/etc/nagios/objects/serverb.cfg" >>/etc/nagios/nagios.cfg

nagios -v /etc/nagios/nagios.cfg
/usr/lib64/nagios/plugins/check_nrpe -H 192.168.153.135
NRPE v2.12
/usr/lib64/nagios/plugins/check_nrpe -H 192.168.153.135 -c check_swap
SWAP OK - 100% free (10238 MB out of 10238 MB) |swap=10238MB;2047;1023;0;10238
systemctl restart nagios
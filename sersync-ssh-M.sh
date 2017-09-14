##！/bin/bash
#cpoy rhel6.iso to pxeserver's directory /mnt
file1=/mnt/rhel-server-6.6-x86_64-dvd.iso
if [ ! -f $file1 ];then
echo 'please copy rhel iso to /mnt and name="rhel-server-6.6-x86_64-dvd.iso"'
exit 1
else
echo 'iso is ready!'
fi

file2=/mnt/sersync2.5.4_64bit_binary_stable_final.tar
if [ ! -f $file2 ];then
echo 'please copy sersync tar to /mnt/'
exit 1
else
echo 'soft is ready!'
fi
#init system
setenforce 0
iptables -F
#set ip
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "IPADDR=172.16.1.20
PREFIX=24
GATEWAY=172.16.1.254
DNS=172.16.1.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth0
#set password_file
echo "redhat" > /etc/rsync.password
chmod 600 /etc/rsync.password
#set sync_floder
mkdir -p /data/www
touch /data/www/www.log
#set sersync
tar xzvf /mnt/sersync2.5.4_64bit_binary_stable_final.tar.gz -C /usr/local/
mv /usr/local/GNU-Linux-x86 /usr/local/sersync
#set xml
echo "<?xml version="1.0" encoding="ISO-8859-1"?>
<head version="2.5">
    <host hostip="localhost" port="8008"></host>
    <debug start="false"/>
    <fileSystem xfs="false"/>
    <filter start="false">
	<exclude expression="(.*)\.svn"></exclude>
	<exclude expression="(.*)\.gz"></exclude>
	<exclude expression="^info/*"></exclude>
	<exclude expression="^static/*"></exclude>
    </filter>
    <inotify>
	<delete start="true"/>
	<createFolder start="true"/>
	<createFile start="false"/>
	<closeWrite start="true"/>
	<moveFrom start="true"/>
	<moveTo start="true"/>
	<attrib start="false"/>
	<modify start="false"/>
    </inotify>

    <sersync>
	<localpath watch="/data/www">
	    <remote ip="172.16.1.25" name="/data/www"/>
	    <remote ip="172.16.1.26" name="/data/www"/>
	</localpath>
	<rsync>
	    <commonParams params="-artuz"/>
	    <auth start="true" users="rsync_backup" passwordfile="/etc/rsync.pas"/>
	    <userDefinedPort start="true" port="22"/><!-- port=874 -->
	    <timeout start="false" time="100"/><!-- timeout=100 -->
	    <ssh start="true"/>
	</rsync>
	<failLog path="/usr/local/sersync/logs/rsync_fail_log.sh" timeToExecute="60"/><!--default every 60mins execute once-->
	<crontab start="false" schedule="600"><!--600mins-->
	    <crontabfilter start="false">
		<exclude expression="*.php"></exclude>
		<exclude expression="info/*"></exclude>
	    </crontabfilter>
	</crontab>
	<plugin start="false" name="command"/>
    </sersync>

    <plugin name="command">
	<param prefix="/bin/sh" suffix="" ignoreError="true"/>	<!--prefix /opt/tongbu/mmm.sh suffix-->
	<filter start="false">
	    <include expression="(.*)\.php"/>
	    <include expression="(.*)\.sh"/>
	</filter>
    </plugin>

    <plugin name="socket">
	<localpath watch="/opt/tongbu">
	    <deshost ip="192.168.138.20" port="8009"/>
	</localpath>
    </plugin>
    <plugin name="refreshCDN">
	<localpath watch="/data0/htdocs/cms.xoyo.com/site/">
	    <cdninfo domainname="ccms.chinacache.com" port="80" username="xxxx" passwd="xxxx"/>
	    <sendurl base="http://pic.xoyo.com/cms"/>
	    <regexurl regex="false" match="cms.xoyo.com/site([/a-zA-Z0-9]*).xoyo.com/images"/>
	</localpath>
    </plugin>
</head>" > /usr/local/sersync/confxml_ssh.xml

#set env and start
echo "PATH=$PATH:/usr/local/sersync/" >> /etc/profile
source /etc/profile
/usr/local/sersync/sersync2  -d -r -o /usr/local/sersync/confxml.xml
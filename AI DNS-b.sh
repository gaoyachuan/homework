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
hostnamectl set-hostname serverb
#set ip
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "IPADDR=192.168.0.2
PREFIX=24
GATEWAY=192.168.0.254
DNS=192.168.0.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth1
echo "IPADDR=192.168.1.2
PREFIX=24
GATEWAY=192.168.1.254
DNS=192.168.1.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth1
sed -i 's/dhcp/none/' /etc/sysconfig/network-scripts/ifcfg-eth2
echo "IPADDR=192.168.2.2
PREFIX=24
GATEWAY=192.168.2.254
DNS=192.168.2.254
" >> /etc/sysconfig/network-scripts/ifcfg-eth1
#set software
yum -y install bind
#set named.conf
echo "
#acl dx_acl { 192.168.0.0/24; };
#acl wt_acl { 192.168.1.0/24; };
#acl other_acl { 192.168.2.0/24; };


options {
	listen-on port 53 { 127.0.0.1;any; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
	allow-query     { localhost;any; };
	recursion yes;

	dnssec-enable no;
	dnssec-validation no;
	dnssec-lookaside auto;

	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.iscdlv.key";

	managed-keys-directory "/var/named/dynamic";
        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

view dx {
        match-clients      { 192.168.0.0/24; };
#	allow-query	   { dx_acl; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
        zone "uplooking.com" {
                type slave;
                file "/var/named/slaves/uplooking.com.dx";
#                transfer-source 192.168.0.2;
                masters { 192.168.0.1; };
         };
        include "/etc/named.rfc1912.zones";
};

view wt {
        match-clients      { 192.168.1.0/24; };
#	allow-query	   { wt_acl; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
        zone "uplooking.com" {
                type slave;
                file "/var/named/slaves/uplooking.com.wt";
#                transfer-source 192.168.1.2;
                masters { 192.168.1.1; };
         };
        include "/etc/named.rfc1912.zones";
};

view others {
        match-clients      { 192.168.2.0/24; };
#	allow-query	   { other_acl; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
        zone "uplooking.com" {
                type slave;
                file "/var/named/slaves/uplooking.com.other";
#                transfer-source 192.168.2.2;
                masters { 192.168.2.1; };
         };
        include "/etc/named.rfc1912.zones";
};

	include "/etc/named.root.key";
" > /etc/named.conf
service named restart
ll /var/named/slaves
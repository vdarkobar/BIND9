BIND9 (Master)

```
sudo apt -y install bind9 bind9-utils bind9-dnsutils bind9-doc -y
```
```
sudo nano /etc/hosts
```
```
#change: 
127.0.0.1	localhost
127.0.0.1	dns01 dns01
#to:
127.0.0.1	localhost
192.168.1.223	dns01 dns01.home.local
```
Prevent cloud-init to change hosts file, 
```
sudo nano /etc/cloud/cloud.cfg
#comment out modules: 
 - set_hostname
 - update_hostname
 - update_etc_hosts
```
```
sudo reboot
```
```
sudo rm /etc/resolv.conf && \
sudo nano /etc/resolv.conf
```
```
# add:
nameserver 192.168.1.223
```
```
sudo chattr +i /etc/resolv.conf
#to undo this command: sudo chattr -i /etc/resolv.conf
```

Prepare firewall:
```
sudo ufw status numbered && \
sudo ufw allow 53/tcp comment 'DNS port 53/tcp' && \
sudo ufw allow 53/udp comment 'DNS port 53/udp'
```
```
sudo mkdir /etc/bind/zones && \
sudo mkdir /var/log/named && \
sudo chown bind:bind /var/log/named
```
```
sudo cp /etc/default/named /etc/default/named.backup && \
sudo cp /etc/bind/named.conf /etc/bind/named.conf.backup && \
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.backup && \
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.backup
```
To run the named service on IPv4 only:
```
sudo nano /etc/default/named
```
```
# add:
OPTIONS="-4 -u bind"
```
Configure logging:
```
sudo nano /etc/bind/named.conf.logging
```
```
logging {
    channel query_log {
        file "/var/log/named/queries.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    channel client_log {
        file "/var/log/named/client.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    channel simple_log {
        file "/var/log/named/simple.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    category queries { query_log; };
    category client { client_log; };
    category default { simple_log; };
};
```
```
sudo nano /etc/bind/named.conf
```
```
# add:
include "/etc/bind/named.conf.logging";
```
```
sudo systemctl restart named
```
```
sudo tail -f /var/log/named/simple.log
sudo tail -f /var/log/named/queries.log
sudo tail -f /var/log/named/client.log
```

-----------------------------------------------------------------------

```
sudo truncate -s 0 /etc/bind/named.conf.options && \
sudo nano /etc/bind/named.conf.options
```
```
acl trustedclients {
	192.168.12.0/24;
	192.168.11.0/24;
	192.168.10.0/24;
	192.168.1.0/24;
	10.10.10.0/24;
};

options {
	directory "/var/cache/bind";

	allow-transfer { none; };
	allow-query { localhost; trustedclients; };
        listen-on port 53 { localhost; 192.168.1.223; };
	recursion yes;
	allow-recursion { trustedclients; };
#	forwarders {
#		9.9.9.9;
#	};

	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	
	dnssec-validation auto;

};
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo truncate -s 0 /etc/bind/named.conf.local && \
sudo nano /etc/bind/named.conf.local
```
```
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";

zone "home.lan" {
	type master;
	file "/etc/bind/zones/db.home.lan";
	allow-transfer { 192.168.1.224; };
};

# Declaring reverse zones:

zone "12.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/db.12.168.192";
	allow-transfer { 192.168.1.224; };
};

zone "11.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/db.11.168.192";
	allow-transfer { 192.168.1.224; };
};
	
zone "10.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/db.10.168.192";
	allow-transfer { 192.168.1.224; };
};


zone "1.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/db.1.168.192";
	allow-transfer { 192.168.1.224; };
};

zone "10.10.10.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/db.10.10.10";
	allow-transfer { 192.168.1.224; };
};
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

Forward zone:
```
sudo nano /etc/bind/zones/db.home.lan			#internal.home-network.me
```
```
;
; BIND data file for home.lan
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
			      1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                             60 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; 192.168.1.0/24 - A Records
pve02	IN	A	192.168.1.12 ;
pve03	IN	A	192.168.1.13 ;
pihole	IN	A	192.168.1.16 ;
dns01	IN	A	192.168.1.223 ;
dns02	IN	A	192.168.1.224 ;


; 192.168.10.0/24 - A Records
npm	IN	A	192.168.10.112 ;

; 192.168.11.0/24 - A Records


; 192.168.12.0/24 - A Records


; 10.10.10.0/24 - A Records

```
```
sudo named-checkzone home.lan /etc/bind/zones/db.home.lan
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

Create respective reverse zone file(s) for resolving the PTR (Pointer) records:

```
sudo nano /etc/bind/zones/db.1.168.192
```
```
;
; BIND reverse data file for 192.168.1.0/24 (home.lan) zone
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
			      1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; Revers A-Records - 192.168.1.0/24
12      IN      PTR     pve02.home.lan.
13      IN      PTR     pve03.home.lan.
16      IN      PTR     pihole.home.lan.
223	IN	PTR	dns01.home.lan.
223	IN	PTR	dns02.home.lan.
```
```
sudo named-checkzone 1.168.192.in-addr.arpa /etc/bind/zones/db.1.168.192
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo nano /etc/bind/zones/db.10.168.192
```
```
;
; BIND reverse data file for 192.168.10.0/24 (home.lan) zone
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
			      1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; Revers A-Records - 192.168.10.0/24
112     IN      PTR     npm.home.lan.
```
```
sudo named-checkzone 10.168.192.in-addr.arpa /etc/bind/zones/db.10.168.192
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo nano /etc/bind/zones/db.11.168.192

```
```
;
; BIND reverse data file for 192.168.11.0/24 (home.lan) zone
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
			      1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; Revers A-Records - 192.168.11.0/24
#112     IN      PTR     npm.home.lan.
```
```
sudo named-checkzone 11.168.192.in-addr.arpa /etc/bind/zones/db.11.168.192
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo nano /etc/bind/zones/db.12.168.192
```
```
;
; BIND reverse data file for 192.168.12.0/24 (home.lan) zone
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
                       20231006         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; Revers A-Records - 192.168.12.0/24
#112     IN      PTR     npm.home.lan.
```
```
sudo named-checkzone 12.168.192.in-addr.arpa /etc/bind/zones/db.12.168.192
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo nano /etc/bind/zones/db.10.10.10
```
```
;
; BIND reverse data file for 10.10.10.0/24 (home.lan) zone
;
$TTL    604800
@       IN      SOA     dns01.home.lan. darko.home.lan. (
                       20231006         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns01.home.lan.
        IN      NS      dns02.home.lan.

; Revers A-Records - 10.10.10.0/24
#112     IN      PTR     npm.home.lan.
```
```
sudo named-checkzone 10.10.10.in-addr.arpa /etc/bind/zones/db.10.10.10
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

Check DNS
```
dig npm.home.lan
dig -x 192.168.10.112
```

-----------------------------------------------------------------------

BIND9 (Slave)

```
sudo apt -y install bind9 bind9-utils bind9-dnsutils bind9-doc -y
```
```
sudo nano /etc/hosts
```
```
#change: 
127.0.0.1	localhost
127.0.0.1	dns02 dns02
#to:
127.0.0.1	localhost
192.168.1.224	dns02 dns02.home.local
```
Prevent cloud-init to change hosts file, 
```
sudo nano /etc/cloud/cloud.cfg
#comment out modules: 
 - set_hostname
 - update_hostname
 - update_etc_hosts
```
```
sudo reboot
```
```
sudo rm /etc/resolv.conf && \
sudo nano /etc/resolv.conf
```
```
# add:
nameserver 192.168.1.224
```
```
sudo chattr +i /etc/resolv.conf
#to undo this command: sudo chattr -i /etc/resolv.conf
```

Prepare firewall:
```
sudo ufw status numbered && \
sudo ufw allow 53/tcp comment 'DNS port 53/tcp' && \
sudo ufw allow 53/udp comment 'DNS port 53/udp'
```
```
sudo mkdir /etc/bind/zones && \
sudo mkdir /var/log/named && \
sudo chown bind:bind /var/log/named
```
```
sudo cp /etc/default/named /etc/default/named.backup && \
sudo cp /etc/bind/named.conf /etc/bind/named.conf.backup && \
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.backup && \
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.backup
```
To run the named service on IPv4 only:
```
sudo nano /etc/default/named
```
```
# add:
OPTIONS="-4 -u bind"
```
Configure logging:
```
sudo nano /etc/bind/named.conf.logging
```
```
logging {
    channel query_log {
        file "/var/log/named/queries.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    channel client_log {
        file "/var/log/named/client.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    channel simple_log {
        file "/var/log/named/simple.log" versions 3 size 5m;
        severity info;
        print-severity yes;
        print-time yes;
    };

    category queries { query_log; };
    category client { client_log; };
    category default { simple_log; };
};
```
```
sudo nano /etc/bind/named.conf
```
```
# add:
include "/etc/bind/named.conf.logging";
```
```
sudo systemctl restart named
```
```
sudo tail -f /var/log/named/simple.log
sudo tail -f /var/log/named/queries.log
sudo tail -f /var/log/named/client.log
```

-----------------------------------------------------------------------

```
sudo truncate -s 0 /etc/bind/named.conf.options && \
sudo nano /etc/bind/named.conf.options
```
```
acl trustedclients {
	192.168.12.0/24;
	192.168.11.0/24;
	192.168.10.0/24;
	192.168.1.0/24;
	10.10.10.0/24;
};

options {
	directory "/var/cache/bind";

	allow-transfer { none; };
	allow-query { localhost; trustedclients; };
        listen-on port 53 { localhost; 192.168.1.224; };
	recursion yes;
	allow-recursion { trustedclients; };
#	forwarders {
#		9.9.9.9;
#	};

	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	
	dnssec-validation auto;

};
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

```
sudo truncate -s 0 /etc/bind/named.conf.local && \
sudo nano /etc/bind/named.conf.local
```
```
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";

zone "home.lan" {
	type slave;
	file "db.home.lan";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};

# Declaring reverse zones:

zone "12.168.192.in-addr.arpa" {
	type slave;
	file "db.12.168.192";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};

zone "11.168.192.in-addr.arpa" {
	type slave;
	file "db.11.168.192";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};
	
zone "10.168.192.in-addr.arpa" {
	type slave;
	file "db.10.168.192";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};

zone "1.168.192.in-addr.arpa" {
	type slave;
	file "db.1.168.192";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};

zone "10.10.10.in-addr.arpa" {
	type slave;
	file "db.10.10.10";
	masters { 192.168.1.223; };
	allow-notify { 192.168.1.223; };
};
```
```
sudo systemctl restart named
```

-----------------------------------------------------------------------

test zone transfer to slave:
```
ls /var/cache/bind/ | grep home.lan
```

```
named-checkconf
```









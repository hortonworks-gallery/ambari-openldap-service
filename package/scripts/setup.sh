#!/bin/bash
set -e 

#"hortonworks"
export LDAP_PASSWORD=$1
#"admin"
export LDAP_ADMIN_USER=$2
#"hortonworks"
export DOMAIN=$3

#"~/security-workshops/ldif"
export LDIFF_DIR=$4

echo "Starting script with password: $1 adminuser: $2 domain: $3"

#yum install -y openldap-servers openldap-clients

#enabled logging
if [ ! -d "/var/log/slapd" ]
then
	mkdir /var/log/slapd
fi
chmod 755 /var/log/slapd/
chown ldap:ldap /var/log/slapd/
sed -i "/local4.*/d" /etc/rsyslog.conf

#copy paste the next 4 lines together
cat >> /etc/rsyslog.conf << EOF
local4.*                        /var/log/slapd/slapd.log
EOF

service rsyslog restart

cd /etc/pki/tls/certs
echo US > input.txt
echo California >> input.txt
echo Palo Alto >> input.txt
echo Hortonworks >> input.txt
echo Sales >> input.txt
echo sandbox >> input.txt
echo test@test.com >> input.txt
echo >> input.txt

make slapd.pem < input.txt
rm -f input.txt

#check the cert
openssl x509 -in slapd.pem -noout -text

chmod 640 slapd.pem
chown :ldap slapd.pem
if [ ! -e "/etc/openldap/certs/slapd.pem" ]
then
	ln -s /etc/pki/tls/certs/slapd.pem /etc/openldap/certs/slapd.pem
fi

cd /root

echo $LDAP_PASSWORD > passwd.txt
chmod 600 passwd.txt
export HASH=`slappasswd -T passwd.txt`
rm -f passwd.txt

/bin/cp -f /usr/share/openldap-servers/slapd.conf.obsolete /etc/openldap/slapd.conf
/bin/cp -f /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

sed -i "s/my-domain/$DOMAIN/g" /etc/openldap/slapd.conf
sed -i "s/Manager/$LDAP_ADMIN_USER/g" /etc/openldap/slapd.conf
sed -i "s#TLSCertificateFile.*#TLSCertificateFile /etc/pki/tls/certs/ca-bundle.crt#g" /etc/openldap/slapd.conf
sed -i "s#TLSCertificateKeyFile.*#TLSCertificateKeyFile /etc/pki/tls/certs/slapd.pem#g" /etc/openldap/slapd.conf
sed -i "s#TLSCACertificatePath.*#TLSCACertificateFile /etc/pki/tls/certs/ca-bundle.crt#g" /etc/openldap/slapd.conf
#sed -i "s:# rootpw.*\{.*:rootpw $HASH:g" /etc/openldap/slapd.conf
echo "rootpw $HASH" >> /etc/openldap/slapd.conf

sed -i "s#SLAPD_LDAPS.*#SLAPD_LDAPS=yes#g" /etc/sysconfig/ldap


echo "BASE dc=$DOMAIN,dc=com" >> /etc/openldap/ldap.conf
echo "URI ldap://localhost"  >> /etc/openldap/ldap.conf
echo "TLS_REQCERT never" >> /etc/openldap/ldap.conf

rm -rf /etc/openldap/slapd.d/*

#Setup  structure
sed -i "s/dc=hortonworks/dc=$DOMAIN/g" $LDIFF_DIR/*.ldif
slapadd -v -n 2 -l $LDIFF_DIR/base.ldif 
slapadd -v -n 2 -l $LDIFF_DIR/groups.ldif
slapadd -v -n 2 -l $LDIFF_DIR/users.ldif

chown -R ldap:ldap /var/lib/ldap
chown -R ldap:ldap /etc/openldap/slapd.d

slaptest -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d
chkconfig --level 235 slapd on
service slapd start

#yum install -y phpldapadmin

sed -i "s#Deny from all#Allow from all#g" /etc/httpd/conf.d/phpldapadmin.conf

sed -i "s#^\$servers->setValue('login','attr','uid');#//\$servers->setValue('login','attr','uid');#g" /etc/phpldapadmin/config.php

chkconfig httpd on
service httpd restart

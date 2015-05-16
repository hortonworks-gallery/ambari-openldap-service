#!/bin/bash

#
# Parse the args
#
LDAP_PASSWORD="$1"
LDAP_ADMIN_USER="$2"
LDAP_DOMAIN="$3"
LDAP_LDIF_DIR="$4"
echo -e "\n####  Installing OpenLDAP with the following args:
	password: $LDAP_PASSWORD
	admin user: $LDAP_ADMIN_USER
	ldap domain: $LDAP_DOMAIN
	ldif dir: $LDAP_LDIF_DIR
"

#
# Install EPEL repo
#
echo -e "\n####  Installing the EPEL repo"
cd /tmp && wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm && rpm -ivh epel-release-6-8.noarch.rpm


#
# Install OpenLDAP
#
#echo -e "\n####  Installing OpenLDAP"
#yum install -y openldap-servers openldap-clients


#
# Start slapd on boot
#
echo -e "\n####  Enabling slapd to start on boot"
chkconfig --level 2345 slapd on


#
# Enabling logging
#
echo -e "\n####  Enabling OpenLDAP logging"
if [ ! -d "/var/log/slapd" ]; then
    mkdir /var/log/slapd
fi
chmod 755 /var/log/slapd/
chown ldap:ldap /var/log/slapd/
sed -i "/local4.*/d" /etc/rsyslog.conf

cat >> /etc/rsyslog.conf << EOF
local4.*                        /var/log/slapd/slapd.log
EOF
service rsyslog restart

#
# Copy DB_CONFIG and fix ownership
#
echo -e "\n####  Copying DB_CONFIG and fixing ownership"
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown -R ldap:ldap /var/lib/ldap /etc/openldap


#
# Start slapd
#
echo -e "\n####  Starting slapd"
service slapd start


#
# Set the domain suffix
#
echo -e "\n####  Setting the domain suffix"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}bdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $LDAP_DOMAIN

EOF

#
# Set the admin user
#
echo -e "\n####  Setting the admin user"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}bdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=$LDAP_ADMIN_USER,$LDAP_DOMAIN

EOF

#
# Set the admin user password
#
echo -e "\n####  Setting the admin password"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}bdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $LDAP_PASSWORD

EOF

#
# Set the config obj admin user
#
echo -e "\n####  Setting the config obj admin user"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=$LDAP_ADMIN_USER,cn=config

EOF


#
# Set the config obj admin password
#
echo -e "\n####  Setting the config obj admin password"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $LDAP_PASSWORD

EOF


#
# Stop slapd
#
echo -e "\n####  Stopping slapd"
service slapd stop


#
# Enable memberof and refint overlays
#
echo -e "\n####  Enabling memberof and refint overlays"
slapadd -v -n 0 -l $LDAP_LDIF_DIR/memberof_config.ldif
slapadd -v -n 0 -l $LDAP_LDIF_DIR/refint_config.ldif


#
# Fix ownership
#
echo -e "\n####  Fixing ownership"
chown -R ldap:ldap /var/lib/ldap /etc/openldap


#
# Start slapd
#
echo -e "\n####  Starting slapd"
service slapd start


#
# Add the base ou's
#
echo -e "\n####  Adding the base OU's"
ldapadd -D cn=$LDAP_ADMIN_USER,$LDAP_DOMAIN -w $LDAP_PASSWORD -f $LDAP_LDIF_DIR/base.ldif


#
# Add the admin user
#
echo -e "\n####  Adding the admin user"
ldapadd -D "cn=$LDAP_ADMIN_USER,$LDAP_DOMAIN" -h 127.0.0.1 -w $LDAP_PASSWORD <<EOF
dn: cn=admin,dc=hortonworks,dc=com
objectclass:top
objectclass:person
objectclass:organizationalPerson
objectclass:inetOrgPerson
objectclass:posixaccount
cn: admin
sn: admin
uid: admin
homedirectory:/home/admin
uidNumber: 75000029
gidNumber: 75000006
userPassword: $LDAP_PASSWORD
description: Rootdn

EOF

#
# Add the admin users and groups
#
echo -e "\n####  Adding the admin users and groups"
ldapadd -D cn=$LDAP_ADMIN_USER,$LDAP_DOMAIN -w $LDAP_PASSWORD -f $LDAP_LDIF_DIR/adminusers.ldif

#
# Add the end users and groups
#
echo -e "\n####  Adding the end users and groups"
ldapadd -D cn=$LDAP_ADMIN_USER,$LDAP_DOMAIN -w $LDAP_PASSWORD -f $LDAP_LDIF_DIR/endusers.ldif


#
# Install phpldapadmin
#
#echo -e "\n####  Installing phpldapadmin"
#yum install -y phpldapadmin

#
# Configure phpldapadmin
#
echo -e "\n####  Configuring phpldapadmin"
sed -i "s#Deny from all#Allow from all#g" /etc/httpd/conf.d/phpldapadmin.conf
sed -i "s#^\$servers->setValue('login','attr','uid');#//\$servers->setValue('login','attr','uid');#g" /etc/phpldapadmin/config.php

#
# Start httpd on boot
#
echo -e "\n####  Starting and enabling httpd to start on boot"
chkconfig --level 2345 httpd on
service httpd start

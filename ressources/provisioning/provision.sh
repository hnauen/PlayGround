#!/usr/bin/env bash

# --------------------------------------------------
# Load config

# Simple bash-based parser for YAML
# see: http://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script
function parse_yaml {
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\):|\1|" \
  -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
  -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
      vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
      printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

function load_yaml {
  eval $(parse_yaml $1)
}

# parse_yaml /vagrant/ressources/provisioning/config.yaml
load_yaml /vagrant/ressources/provisioning/config.yaml


# --------------------------------------------------
# Pick required values from config.yaml

HOSTNAME=$provisioning_vm_hostname
SERVERNAME=$provisioning_server_name
MYSQLPASSWORD=$provisioning_mysql_password
PROJECTFOLDER=$provisioning_server_name


# --------------------------------------------------
# Update / upgrade system
sudo apt-get update
sudo apt-get -y upgrade


# --------------------------------------------------
# Create project folder
sudo mkdir -p "/var/www/html/${PROJECTFOLDER}"


# --------------------------------------------------
# Install Build-Tools

# Install git
sudo apt-get -y install git


# --------------------------------------------------
# Install Apache
sudo apt-get install -y apache2
sudo a2enmod rewrite
sudo a2enmod ssl

# Setup server name
sudo echo "ServerName ${HOSTNAME}" > /etc/apache2/conf-available/servername.conf
sudo a2enconf servername

# Setup php debug config
PHPDEBUG=$(cat <<EOF
php_flag display_startup_errors on
php_flag display_errors on
php_flag html_errors on
php_flag log_errors on
php_flag ignore_repeated_errors off
php_flag ignore_repeated_source off
php_flag report_memleaks on
php_value error_reporting -1
php_value log_errors_max_len 0
php_value error_log /vagrant/log/${SERVERNAME}-php.log
EOF
)
sudo echo "${PHPDEBUG}" > /etc/apache2/conf-available/php-debug.conf
sudo a2enconf php-debug

# Setup hosts file
VHOSTS=$(cat <<EOF
<VirtualHost *:80>
    ServerName ${SERVERNAME}
    ServerAlias *.${SERVERNAME}
    DocumentRoot /var/www/html/${PROJECTFOLDER}
    <Directory "/var/www/html/${PROJECTFOLDER}">
        AllowOverride All
        Require all granted
    </Directory>
    CustomLog /vagrant/log/${SERVERNAME}-access.log combined
    ErrorLog /vagrant/log/${SERVERNAME}-error.log
</VirtualHost>
<VirtualHost *:443>
    ServerName ${SERVERNAME}
    ServerAlias *.${SERVERNAME}
    DocumentRoot /var/www/html/${PROJECTFOLDER}
    <Directory "/var/www/html/${PROJECTFOLDER}">
        AllowOverride All
        Require all granted
    </Directory>
    CustomLog /vagrant/log/${SERVERNAME}-access.log combined
    ErrorLog /vagrant/log/${SERVERNAME}-error.log
    # enable SSL
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/${SERVERNAME}.crt
    SSLCertificateKeyFile /etc/ssl/private/${SERVERNAME}.key
</VirtualHost>
EOF
)
sudo echo "${VHOSTS}" > /etc/apache2/sites-available/${SERVERNAME}.conf
sudo a2ensite ${SERVERNAME}

# Create SSL-Certificate
OPENSSLCNF=$(cat <<EOF
[ req ]
distinguished_name              = req_distinguished_name
string_mask                     = nombstr
req_extensions                  = v3_req
[ req_distinguished_name ]
[ v3_req ]
subjectAltName                  = DNS:${SERVERNAME}, DNS:*.${SERVERNAME}
EOF
)
sudo echo  "${OPENSSLCNF}"  > ${SERVERNAME}.cnf
sudo openssl req -nodes -x509 -newkey rsa:4096 \
          -config ${SERVERNAME}.cnf \
          -keyout /etc/ssl/private/${SERVERNAME}.key \
          -out /etc/ssl/certs/${SERVERNAME}.crt \
          -days 3560 \
          -subj "/C=DE/ST=Hamburg/L=Hamburg/O=${HOSTNAME}/OU=${SERVERNAME}/CN=${SERVERNAME}"
sudo rm ${SERVERNAME}.cnf


# --------------------------------------------------
# Install PHP
sudo apt-get install -y php5

# Install mcrypt
sudo apt-get install php5-mcrypt
sudo php5enmod mcrypt

# Install Composer
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Install xDebug
sudo apt-get install -y php5-xdebug
XDEBUGCONF=$(cat <<EOF
zend_extension=xdebug.so
xdebug.default_enable=1
xdebug.idekey=${SERVERNAME}
xdebug.remote_port=9000
xdebug.remote_connect_back=1
xdebug.remote_enable=1
xdebug.remote_autostart=1
EOF
)
sudo echo "${XDEBUGCONF}" > /etc/php5/mods-available/xdebug.ini


# --------------------------------------------------
# Install MySQL

# Install MySQL and give password to installer
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MYSQLPASSWORD}"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MYSQLPASSWORD}"
sudo apt-get -y install mysql-server
sudo apt-get install php5-mysql

# Install phpmyadmin and give password(s) to installer
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${MYSQLPASSWORD}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${MYSQLPASSWORD}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${MYSQLPASSWORD}"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install phpmyadmin


# --------------------------------------------------
# Cleanup

# finally restart apache
sudo apachectl restart

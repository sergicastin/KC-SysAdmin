#!/bin/bash

#Actualización de repositorios
apt-get update

#Configurar disco
mkdir /mnt/dbstorage
mkfs.ext4 /dev/sdb
mount /dev/sdb /mnt/dbstorage

LINE_TO_ADD="/dev/sdb          /mnt/dbstorage               ext4               defaults             0 2"
echo "$LINE_TO_ADD" | sudo tee -a /etc/fstab > /dev/null

#Instalación de los paquetes
apt install net-tools
apt-get install -y nginx mariadb-server mariadb-common php-fpm php-mysql expect php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip

#Config BD Storage
chown -R mysql:mysql /mnt/dbstorage
systemctl stop mariadb
cp -R -p /var/lib/mysql/* /mnt/dbstorage
CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
NEW_DATADIR="/mnt/dbstorage"
sudo sed -i -E "s|^#(datadir\s*=\s*).*|\1$NEW_DATADIR|" "$CONFIG_FILE"
systemctl start mariadb

#Configuración de Nginx
cat <<EOF >> /etc/nginx/sites-available/wordpress
# Managed by installation script - Do not change
server {
    listen 8081;
    root /var/www/wordpress;
    index index.php index.html index.htm
index.nginx-debian.html;
    server_name localhost;
    location / {
    try_files \$uri \$uri/ =404;
    }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    location ~ /\.ht {
    deny all;
    }
}
EOF

#Crear enlace simbólico
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/

#Habilitar los servicios de Nginx y PHP
sudo systemctl enable nginx
sudo systemctl enable php8.1-fpm
sudo systemctl start nginx
sudo systemctl start php8.1-fpm

#sudo systemctl status nginx
#sudo systemctl status php8.1-fpm

#Securizar la BD
db_root_password="keepcoding"
mysql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED BY 'keepcoding';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_

#Creación de la BBDD para wordpress
mysql -u root -p"${db_root_password}" << EOF
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE
utf8_unicode_ci;
GRANT ALL ON wordpress.* TO 'wordpressuser'@'localhost' IDENTIFIED BY
'keepcoding';
FLUSH PRIVILEGES;
EOF

#Wordpress last release
wget https://wordpress.org/latest.tar.gz
tar -xf latest.tar.gz -C /var/www/

#Configuraremos la conexión a BBDD en el fichero wp-config.php
cat <<EOF >> /var/www/wordpress/wp-config.php
<?php

define( 'DB_NAME', 'wordpress' );

/** Database username */
define( 'DB_USER', 'wordpressuser' );

/** Database password */
define( 'DB_PASSWORD', 'keepcoding' );

/** Database hostname */
define( 'DB_HOST', 'localhost' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

\$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

#Nos aseguraremos de que el directorio /var/www/wordpress es del usuario y grupo www-data
chown -R www-data:www-data /var/www/wordpress/

#Reiniciamos servicios
systemctl restart nginx
systemctl restart php8.1-fpm

#Instalación ELastic
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install filebeat

#Config Filebeat

filebeat modules enable system
filebeat modules enable nginx


cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
sed -i 's/type: filestream/type: log/g' /etc/filebeat/filebeat.yml
sed -i 's/enabled: false/enabled: true/g' /etc/filebeat/filebeat.yml
sed -i '/- \/var\/log\/\*\.log/a \ \ \ \ - /var/log/nginx/*.log\n\ \ \ \ - /var/log/mysql/*.log' /etc/filebeat/filebeat.yml
sed -i 's/#output.logstash:/output.logstash:/g' /etc/filebeat/filebeat.yml
sed -i 's/#hosts: \["localhost:5044"\]/hosts: \["192.168.70.3:5044"\]/g' /etc/filebeat/filebeat.yml
sed -i 's/^output.elasticsearch:/#output.elasticsearch:/g' /etc/filebeat/filebeat.yml
sed -i 's/^ *hosts: \["localhost:9200"\]/#&/g' /etc/filebeat/filebeat.yml

systemctl enable filebeat --now
systemctl restart filebeat

echo "¡El script se ejecutó correctamente!"
#!/bin/bash
# @author: Seb Dangerfield
# http://www.sebdangerfield.me.uk/?p=513

# Modify the following to match your system
APACHE_CONFIG='/etc/apache2/sites-available'
APACHE_SITES_ENABLED='/etc/apache2/sites-enabled'
WEB_SERVER_GROUP='www-data'
APACHE_INIT='/etc/init.d/apache2'
DOMAIN='arkheewebdev.com'
WEB_ROOTS='/var/www'

SERVER_IP=$(hostname -I | awk '{print $1}')
CURRENT_DIR=$(pwd)

# vérifie qu'on est root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi


# choix du nom du site
echo -e " • Veuillez entrer un nom de sous-domaine qui donnera une url de type \e[4m[votre sous domaine].$DOMAIN\e[0m:"
read HOSTNAME
if [ -z $HOSTNAME ]; then
    echo "Pas de nom de site, pas de script !"
    exit
fi


# Create a new user!
echo -e " • Entrez le nom du nouvel utilisateur qui sera créé pour ce site (\e[4m$HOSTNAME\e[0m):"
read USERNAME
if [ -z $USERNAME ]; then
	USERNAME=$HOSTNAME
fi
adduser $USERNAME
HOME_DIR=$(eval echo ~$USERNAME)


# Choose webroot
DEFAULT_PUBLIC_HTML_DIR="$WEB_ROOTS/$HOSTNAME/httpdocs"
echo -e " • Entrez le webroot (\e[4m$DEFAULT_PUBLIC_HTML_DIR\e[0m):"
read PUBLIC_HTML_DIR
if [ -z $PUBLIC_HTML_DIR ]; then
	PUBLIC_HTML_DIR=$DEFAULT_PUBLIC_HTML_DIR
fi


# Choose php version
PHP_FPM_VERSIONS=($(cd /etc/php && ls))
LATEST_VERSION=${PHP_FPM_VERSIONS[-1]}
echo -e " • Choisissez la version de PHP-FPM parmi les versions suivantes : ${PHP_FPM_VERSIONS[*]} (\e[4m$LATEST_VERSION\e[0m):"
read PHP_VERSION
if [ -z $PHP_VERSION ]; then
	PHP_VERSION=$LATEST_VERSION
fi
PHP_INI_DIR="/etc/php/$PHP_VERSION/fpm/pool.d"
PHP_FPM_INIT="/etc/init.d/php$PHP_VERSION-fpm"


# Now we need to copy the virtual host template
CONFIG=$APACHE_CONFIG/$HOSTNAME.$DOMAIN.conf
cp $CURRENT_DIR/apache.conf.template $CONFIG
sed -i "s/__SERVER_IP__/$SERVER_IP/g" $CONFIG
sed -i "s/__DOMAIN__/$DOMAIN/g" $CONFIG
sed -i "s/__HOSTNAME__/$HOSTNAME/g" $CONFIG
sed -i "s/__PUBLIC_HTML_DIR__/${PUBLIC_HTML_DIR//\//\\/}/g" $CONFIG
sed -i "s/__WEB_ROOTS__/${WEB_ROOTS//\//\\/}/g" $CONFIG

echo -e " • Combien de serveurs FPM souhaitez vous (\e[4m4\e[0m):"
read FPM_SERVERS
if [ -z $FPM_SERVERS ]; then
	FPM_SERVERS=4
fi
echo -e " • Min number of FPM servers would you like (\e[4m3\e[0m):"
read MIN_SERVERS
if [ -z $MIN_SERVERS ]; then
	MIN_SERVERS=3
fi
echo -e " • Max number of FPM servers would you like (\e[4m5\e[0m):"
read MAX_SERVERS
if [ -z $MAX_SERVERS ]; then
	MAX_SERVERS=5
fi


# Now we need to create a new php fpm pool config
FPMCONF="$PHP_INI_DIR/$HOSTNAME.pool.conf"

cp $CURRENT_DIR/pool.conf.template $FPMCONF

sed -i "s/__HOSTNAME__/$HOSTNAME/g" $FPMCONF
sed -i "s/__DOMAIN__/$DOMAIN/g" $FPMCONF
sed -i "s/__HOME_DIR__/${HOME_DIR//\//\\/}/g" $FPMCONF
sed -i "s/__START_SERVERS__/$FPM_SERVERS/g" $FPMCONF
sed -i "s/__MIN_SERVERS__/$MIN_SERVERS/g" $FPMCONF
sed -i "s/__MAX_SERVERS__/$MAX_SERVERS/g" $FPMCONF
sed -i "s/__MAX_CHILDS__/$((MAX_SERVERS+START_SERVERS))/g" $FPMCONF

a2ensite $HOSTNAME.$DOMAIN.conf

# set file perms and create required dirs!
chmod 600 $CONFIG
mkdir -p $PUBLIC_HTML_DIR $WEB_ROOTS/$USERNAME/sock
chmod 750 $WEB_ROOTS/$USERNAME -R
chown $USERNAME:$USERNAME $WEB_ROOTS/$USERNAME -R

$APACHE_INIT reload
$PHP_FPM_INIT restart

echo "<?php phpinfo();" > $PUBLIC_HTML_DIR/info.php

SUCCESS=$(wget -q -O - "https://$HOSTNAME.$DOMAIN/info.php" | grep -c "PHP Version $PHP_VERSION")
if [ "$SUCCESS" -eq "1" ]; then
	MSG="a été créé pour l'user \e[4m$HOSTNAME\e[0m dans la bonne humeur ;)\n • Son webroot est \e[4m$PUBLIC_HTML_DIR\e[0m !"
else
	MSG="n'est pas accessible hélas :/"
fi

echo -e "\n • Le site \e[4mhttps://$HOSTNAME.$DOMAIN\e[0m $MSG\n"

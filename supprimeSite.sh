#!/bin/bash

# Modify the following to match your system
APACHE_CONFIG='/etc/apache2/sites-available'
APACHE_INIT='/etc/init.d/apache2'
DOMAIN='arkheewebdev.com'
WEB_ROOTS='/var/www'

# vérifie qu'on est root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi



ENABLED_URLS=$( grep -h /etc/apache2/sites-enabled/* -e 'ServerName ' | sed -E "s/ServerName (\w+).$DOMAIN*/\1/" | sort -u)
ASSEMBLED_ENABLED_URLS=$(printf ",\e[4m%s\e[0m" ${ENABLED_URLS[@]})
ASSEMBLED_ENABLED_URLS=${ASSEMBLED_ENABLED_URLS:1}

# choix du nom du site
echo -e " • Veuillez entrer un nom du site à supprimer parmi [$ASSEMBLED_ENABLED_URLS].$DOMAIN:"
read HOSTNAME
HOSTNAME=${HOSTNAME,,}
if [ -z $HOSTNAME ]; then
    echo "Pas de nom de site, pas de script !"
    exit
fi

# retrieve php version
PHP_VERSION=$( ls /etc/php/**/fpm/pool.d/$HOSTNAME.pool.conf | sed -E "s/.+php\/([a-z0-9.]+)\/(.+)/\1/" )
PHP_INI_DIR="/etc/php/$PHP_VERSION/fpm/pool.d"
PHP_FPM_INIT="/etc/init.d/php$PHP_VERSION-fpm"

# stop php-fpm processes
$PHP_FPM_INIT stop


# disable site & remove conf
a2dissite $HOSTNAME.$DOMAIN.conf
rm -f $APACHE_CONFIG/$HOSTNAME.$DOMAIN.conf
rm -f /var/lib/apache2/site/enabled_by_admin/$HOSTNAME.$DOMAIN

# remove phpfpm conf
rm -f /etc/php/**/fpm/pool.d/$HOSTNAME.pool.conf

# remove user
userdel $HOSTNAME
groupdel $HOSTNAME
rm -rf /var/www/$HOSTNAME

# remove webroot but ask before
rm -ri $WEB_ROOTS/$HOSTNAME

# remove logs
rm -f /var/log/apache2/access.$HOSTNAME.$DOMAIN.log
rm -f /var/log/apache2/error.$HOSTNAME.$DOMAIN.log

# restart fpm
$PHP_FPM_INIT start
$APACHE_INIT reload

echo -e "\n • Le site \e[4mhttps://$HOSTNAME.$DOMAIN\e[0m à été supprimé.\n"

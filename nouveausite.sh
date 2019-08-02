#!/bin/bash
# @author: Seb Dangerfield
# http://www.sebdangerfield.me.uk/?p=513

# Modify the following to match your system
APACHE_CONFIG='/etc/apache2/sites-available'
WEB_SERVER_GROUP='www-data'
APACHE_INIT='/etc/init.d/apache2'
DOMAIN='arkheewebdev.com'
WEB_ROOTS='/var/www'

SERVER_IP=$(hostname -I | awk '{print $1}')
SCRIPT=$(realpath $0)
CURRENT_DIR=$(dirname $SCRIPT)

# vérifie qu'on est root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    sudo /bin/bash $0 "$@"
    exit $?
fi

# choix du nom du site
echo -e " • Veuillez entrer un nom de sous-domaine qui donnera une url de type \e[4m[votre sous domaine]\e[0m.$DOMAIN:"
read HOSTNAME
HOSTNAME=${HOSTNAME,,}
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
# /!\ Le home dir n'est pas dans /home !
HOME_DIR="/var/www/${HOSTNAME}"
SOCKET="$HOME_DIR/sock/${$HOSTNAME}_fpm.sock"

adduser --home $HOME_DIR --gecos "" --disabled-password $USERNAME
echo "alias ll='ls -lah --color=auto'" > $HOME_DIR/.bashrc
chown -R $USERNAME:$USERNAME $HOME_DIR

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
sed -i "s/__SOCKET__/${SOCKET//\//\\/}/g" $CONFIG
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
sed -i "s/__SOCKET__/${SOCKET//\//\\/}/g" $FPMCONF
sed -i "s/__START_SERVERS__/$FPM_SERVERS/g" $FPMCONF
sed -i "s/__MIN_SERVERS__/$MIN_SERVERS/g" $FPMCONF
sed -i "s/__MAX_SERVERS__/$MAX_SERVERS/g" $FPMCONF
sed -i "s/__MAX_CHILDS__/$((MAX_SERVERS+START_SERVERS))/g" $FPMCONF

# Autorise user www-data à accéder (lecture) aux fichiers du groupe de l'user ($USERNAME = groupe)
usermod -aG $USERNAME $WEB_SERVER_GROUP

# set file perms and create required dirs!
chmod 600 $CONFIG
mkdir -p $PUBLIC_HTML_DIR $WEB_ROOTS/$HOSTNAME/{sock,log}
chmod 750 $WEB_ROOTS/$HOSTNAME -R
chown $USERNAME:$USERNAME $WEB_ROOTS/$HOSTNAME -R

# conf ssh
mkdir -p $HOME_DIR/.ssh
chmod 700 $HOME_DIR/.ssh
cat authorized_keys > $HOME_DIR/.ssh/authorized_keys
chmod 644 $HOME_DIR/.ssh/authorized_keys

a2ensite $HOSTNAME.$DOMAIN.conf

$APACHE_INIT reload
$PHP_FPM_INIT restart

echo "Site "$HOSTNAME" en place" > $PUBLIC_HTML_DIR/index.php
echo "<?php phpinfo();" > $PUBLIC_HTML_DIR/info.php
chown $USERNAME:$USERNAME $PUBLIC_HTML_DIR/{index.php,info.php} -R

SUCCESS=$(wget -q -O - "https://$HOSTNAME.$DOMAIN/info.php" | grep -c "PHP Version $PHP_VERSION")
if [ "$SUCCESS" -eq "1" ]; then
	MSG="a été créé pour l'user \e[4m$HOSTNAME\e[0m dans la bonne humeur ;)\n • Son webroot est \e[4m$PUBLIC_HTML_DIR\e[0m !"
else
	MSG="n'est pas accessible hélas :/"
fi

echo -e "\n • Le site \e[4mhttps://$HOSTNAME.$DOMAIN\e[0m $MSG\n"

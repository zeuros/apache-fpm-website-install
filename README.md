# apache-fpm-website-install
><b>facilite la création d'un site sous apache avec php-fpm (user spécifique par webroot)</b>
### Ce script
>- Crée un user dont les droits sont restreints à son home (/var/www/USER) dans lequel on met aussi le webroot
- crée un site vierge utilisant avec php-fpm, contenant info.php
- vérifie avec un wget le fonctionnement du site

# Etapes
- Mettre les clés des développeurs dans le fichier authorized_keys qui doit être situé à côté du script
- lancer le script
- entrer un nom d'(utilisateur/webroot)
- appuyer sur entrée plusieurs fois

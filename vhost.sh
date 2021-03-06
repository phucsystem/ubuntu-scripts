#!/bin/bash

###################################################
## Automatic Apache2 virtual host install script ##
## Jim Cronqvist <jim.cronqvist@gmail.com>       ##
## Updated: 2015-12-10                           ##
###################################################

# Confirm function that will be used later for yes and no questions.
Confirm () {
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        read -p "${1:-Are you sure?} [$prompt]: " reply

        #Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        case ${reply:-$2} in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
        esac
    done
}


# Abort if not root.
if [ "$(id -u)" -ne "0" ] ; then
echo "This script needs to be ran from a user with root permissions.";
    exit 1;
fi

# Check for 2 passed arguments, otherwise abort.
if [ $# -lt 2 ] ; then
    echo "You have not passed the correct number of arguments. This script should be used with the following syntax:"
    echo "sudo bash vhost.sh example.com /var/www/example.com"
    echo "or with SSL:"
    echo "sudo bash vhost.sh example.com /var/www/example.com --ssl"
    echo ""
    exit 1;
fi

SSL=0
if echo $* | grep -e " --ssl" -q ; then
    SSL=1
    
    if [ $(apache2ctl -M | grep ssl_module | wc -l) -eq 0 ]; then
        echo "SSL is not enabled and the reload of the configuration file in the end of this script will fail if you continue."
        echo "Issue the following command to enable ssl: sudo a2enmod ssl"
        echo ""
        read -p "Please press enter to continue anyway."
    fi
fi

if [ $SSL -eq 1 ]; then
    virtual_host="<VirtualHost *:443>
        ServerName $1
        #ServerAlias $1
        DocumentRoot $2
        <Directory $2>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Order allow,deny
            Allow from all
        </Directory>
        
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/ssl_certificate.crt
        SSLCertificateKeyFile /etc/apache2/ssl/$1.key
        SSLCertificateChainFile /etc/apache2/ssl/IntermediateCA.crt
        <FilesMatch \"\.(cgi|shtml|phtml|php)$\">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch \"MSIE [2-6]\" \
            nokeepalive ssl-unclean-shutdown \
            downgrade-1.0 force-response-1.0
        BrowserMatch \"MSIE [17-9]\" ssl-unclean-shutdown
    </VirtualHost>"
else
    virtual_host="<VirtualHost *:80>
        ServerName $1
        #ServerAlias $1
        DocumentRoot $2
        <Directory $2>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Order allow,deny
            Allow from all
        </Directory>
    </VirtualHost>"
fi

if [ $SSL -eq 1 ]; then
    sudo bash -c "echo '$virtual_host' > /etc/apache2/sites-available/$1.ssl.conf"
    echo "The site $1.ssl.conf has been created."
    cat /etc/apache2/sites-available/$1.ssl.conf
    
    if [ -f  "/etc/apache2/ssl/$1.key" ]; then
        a2ensite $1.ssl.conf
        service apache2 reload
    else
        if Confirm "The SSL certificate was not found, do you want to create a self signed certificate?" Y; then
            sudo mkdir /etc/apache2/ssl
            sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/$1.key -out /etc/apache2/ssl/ssl_certificate.crt -subj "/C=/ST=/L=/O=/CN= "
            sudo cp /etc/apache2/ssl/ssl_certificate.crt /etc/apache2/ssl/IntermediateCA.crt
            sudo a2ensite $1.ssl.conf && sudo service apache2 reload
        else
            echo ""
            echo "The SSL certificate was not found, please make sure that the files exist before you enable this site. Ones that is done, enable it with the command:"
            echo "sudo a2ensite $1.ssl.conf && sudo service apache2 reload"
            echo ""
        fi
    fi
else
    sudo bash -c "echo '$virtual_host' > /etc/apache2/sites-available/$1.conf"
    echo "The site $1.conf has been created."
    cat /etc/apache2/sites-available/$1.conf
    a2ensite $1.conf
    service apache2 reload
fi

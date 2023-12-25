#!/bin/bash

check_error() {
    if [ $? -ne 0 ]; then
        echo "Error encountered. Exiting script."
        exit 1
    fi
}

remove_nginx() {
    sudo cp -r /etc/nginx/sites-available /home/$USER/backup/nginx/sites-available
    sudo cp -r /etc/nginx/sites-enabled /home/$USER/backup/nginx/sites-enabled
    sudo cp /etc/nginx/nginx.conf /home/$USER/backup/nginx/nginx.conf

    sudo apt-get remove --auto-remove -y nginx nginx-common nginx-core
    sudo apt-get purge --auto-remove -y nginx nginx-common nginx-core
    check_error

    sudo rm -rf /etc/nginx /var/log/nginx /var/lib/nginx /var/cache/nginx /run/nginx.pid /run/nginx 2>/dev/null 
    check_error
}

remove_supervisor() {
    sudo cp /etc/supervisor/supervisord.conf /home/$USER/backup/supervisor/supervisord.conf
    sudo cp -r /etc/supervisor/conf.d/ /home/$USER/backup/supervisor/conf.d/

    sudo apt-get remove --auto-remove -y supervisor
    sudo apt-get purge --auto-remove -y supervisor
    check_error
}

remove_nginx_supervisor() {
    remove_nginx
    remove_supervisor
}

setup_nginx() {
    sudo usermod -a -G www-data $USER
    sudo chown -R $USER:www-data /var/www /var/log/nginx /var/lib/nginx 2>/dev/null
    sudo chmod -R 775 /var/www /var/log/nginx /var/lib/nginx 2>/dev/null

    mkdir -p /var/www/monorepo && cp -rf ./src/* /var/www/monorepo/
    sudo cp -rf ./config/nginx/conf.d/* /etc/nginx/sites-available/

    # Remove existing sites-enabled and create symbolic links
    if [ "$(ls -A /etc/nginx/sites-enabled/)" ]; then
        sudo rm /etc/nginx/sites-enabled/*
        check_error
    fi

    for file in /etc/nginx/sites-available/*; do
        link="/etc/nginx/sites-enabled/$(basename "$file")"
        if [ ! -e "$link" ]; then
            sudo ln -s "$file" "$link"
            check_error
        fi
    done
}

install_php_versions() {
    local php_versions=("8.2" "7.4")
    
    for version in "${php_versions[@]}"; do
        # Install common PHP extensions
        sudo apt-get install -y php$version-cli php$version-fpm php$version-common php$version-mysql php$version-curl php$version-gd php$version-mbstring php$version-xml php$version-zip \
            php$version-bcmath php$version-xdebug php$version-redis php$version-memcached php$version-mongodb php$version-imagick php$version-intl

        sudo cp ./config/php/local.ini /etc/php/$version/cli/conf.d/99-local.ini
        sudo cp ./config/php/local.ini /etc/php/$version/fpm/conf.d/99-local.ini
        
        sudo systemctl stop php$version-fpm
        sudo systemctl disable php$version-fpm
        check_error
    done
}

setup_composer() {
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
        check_error
    fi
}

install_nvm() {
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
    check_error

    # Source NVM to use it immediately
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    source ~/.bashrc
    check_error
}

generate_ssl_certificate() {
    sudo openssl req -nodes -x509 -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/localhost.key -out /etc/ssl/certs/localhost.crt -subj "/CN=localhost"
    check_error

    sudo chmod 644 /etc/ssl/certs/localhost.crt
    sudo chmod 644 /etc/ssl/private/localhost.key
}

###############################################
# Main script
###############################################

sudo apt update && sudo apt upgrade -y
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:ondrej/nginx-mainline
sudo apt-get update

# Install essential development tools
sudo apt install -y build-essential nginx git curl vim unzip memcached redis-server supervisor cron

#PHP
install_php_versions
sudo update-alternatives --set php /usr/bin/php8.2

sudo apt install php-codesniffer -y
#phpcs src/backend/index.php #to check errors
#phpcbf src/backend/index.php #to fix errors

setup_composer
if which composer >/dev/null; then
    composer global require squizlabs/php_codesniffer --dev #phpcs
fi

#NVM
install_nvm
nvm install 16.18.1
nvm install 20.10.0 # --lts
#nvm use 16.18.1

if ! command -v yarn &> /dev/null; then
    npm install -g yarn
    check_error
fi

#Nginx
generate_ssl_certificate
setup_nginx
check_error

#Supervisor configuration
mkdir -p /home/$USER/backup/supervisor/conf.d/
sudo cp -r /etc/supervisor/conf.d/ /home/$USER/backup/supervisor/conf.d/
sudo cp ./config/supervisor/nginx-php-fpm.conf /etc/supervisor/conf.d/nginx-php-fpm.conf
sudo cp ./config/supervisor/cron.conf /etc/supervisor/conf.d/cron.conf
sudo cp ./config/supervisor/redis.conf /etc/supervisor/conf.d/redis.conf
sudo cp ./config/supervisor/memcached.conf /etc/supervisor/conf.d/memcached.conf
sudo chmod -R 755 /etc/supervisor/conf.d/

sudo systemctl stop nginx redis-server memcached 
sudo systemctl disable nginx redis-server memcached
check_error

sudo systemctl enable supervisor && sudo systemctl start supervisor
sudo supervisorctl reread && sudo supervisorctl update && sudo supervisorctl restart all && sudo supervisorctl status all

sudo apt-get autoremove -y
sudo apt-get clean -y

echo "Development environment setup completed."

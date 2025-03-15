
# Exit on any error
set -e

# Check if script is run as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Minimum PHP version
MIN_PHP_VERSION="7.4"

# Function to compare version numbers
version_compare() {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 240
        fi
    done
    return 0
}

# Prompt user for PHP version with minimum check
echo "Which PHP version would you like to install (e.g., 8.3, 8.2)? Default is 8.3. Minimum is $MIN_PHP_VERSION."
read -p "Enter PHP version: " php_version
php_version=${php_version:-8.3}
if ! [[ "$php_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid PHP version format. Please use a format like '8.3' or '8.2'."
    exit 1
fi
version_compare "$php_version" "$MIN_PHP_VERSION"
if [ $? -eq 240 ]; then
    echo "PHP version must be at least $MIN_PHP_VERSION."
    exit 1
fi

# Update package list
echo "Updating package list..."
apt-get update -y

# Install prerequisites
echo "Installing prerequisites..."
apt-get install -y curl apt-transport-https lsb-release gnupg software-properties-common git ufw

# Install Apache
echo "Installing Apache..."
apt-get install -y apache2
systemctl enable apache2
systemctl start apache2

# Configure UFW for Apache Full
echo "Configuring UFW firewall for Apache Full..."
ufw allow 'Apache Full'
ufw allow 'OpenSSH' # Prevent SSH lockout
ufw enable
ufw status

# Add Ondřej PHP repository
echo "Adding Ondřej PHP repository..."
add-apt-repository -y ppa:ondrej/php
apt-get update -y

# Install PHP and all requested extensions (with gd instead of imagick)
echo "Installing PHP $php_version and required extensions..."
apt-get install -y php${php_version} \
    php${php_version}-cli \
    php${php_version}-fpm \
    php${php_version}-curl \
    php${php_version}-mbstring \
    php${php_version}-xml \
    php${php_version}-bcmath \
    php${php_version}-zip \
    php${php_version}-tokenizer \
    php${php_version}-ctype \
    php${php_version}-fileinfo \
    php${php_version}-intl \
    php${php_version}-json \
    php${php_version}-pdo \
    php${php_version}-mysql \
    php${php_version}-sqlite3 \
    php${php_version}-gd \
    php${php_version}-dev \
    libapache2-mod-php${php_version}

# Install php-redis
echo "Installing php-redis..."
apt-get install -y php${php_version}-redis

# Install Composer
echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Install Node.js 20
echo "Installing Node.js 20 and npm..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Supervisor
echo "Installing Supervisor..."
apt-get install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# Prompt for Git repository and directory name
echo "Please provide the Git repository URL for your Laravel project."
read -p "Git repository URL: " git_repo_url
if [ -z "$git_repo_url" ]; then
    echo "Git repository URL cannot be empty."
    exit 1
fi

echo "Enter the directory name for your project (will be created in /var/www/html/)."
read -p "Directory name: " project_dir
if [ -z "$project_dir" ]; then
    echo "Directory name cannot be empty."
    exit 1
fi

# Define project path
PROJECT_PATH="/var/www/html/$project_dir"
DOMAIN_NAME="$project_dir.local"

# Clone the Git repository
echo "Cloning repository into $PROJECT_PATH..."
mkdir -p "$PROJECT_PATH"
git clone "$git_repo_url" "$PROJECT_PATH"

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data "$PROJECT_PATH"
chmod -R 775 "$PROJECT_PATH/storage" "$PROJECT_PATH/bootstrap/cache" 2>/dev/null || true

# Create Apache virtual host
echo "Creating virtual host for $DOMAIN_NAME..."
cat > /etc/apache2/sites-available/"$project_dir.conf" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    DocumentRoot $PROJECT_PATH/public

    <Directory $PROJECT_PATH/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$project_dir-error.log
    CustomLog \${APACHE_LOG_DIR}/$project_dir-access.log combined
</VirtualHost>
EOF

# Enable the virtual host and rewrite module
echo "Enabling virtual host and rewrite module..."
a2ensite "$project_dir.conf"
a2enmod rewrite
systemctl restart apache2

# Configure Supervisor for Laravel queue
echo "Configuring Supervisor for Laravel queue..."
cat > /etc/supervisor/conf.d/"$project_dir-queue.conf" <<EOF
[program:${project_dir}-queue]
process_name=%(program_name)s_%(process_num)02d
command=php $PROJECT_PATH/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=$PROJECT_PATH/storage/logs/queue.log
stopwaitsecs=3600
EOF

# Reload Supervisor to apply configuration
echo "Reloading Supervisor configuration..."
supervisorctl reread
supervisorctl update
supervisorctl start "$project_dir-queue:*"

# Navigate to project directory
cd "$PROJECT_PATH" || exit

# Run Composer install
echo "Running composer install..."
composer install --no-interaction --optimize-autoloader

# Install npm dependencies and build assets
echo "Installing npm dependencies and building assets..."
npm install
npm run build

# Set up .env
echo "Setting up .env file..."
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "Copied .env.example to .env."
else
    echo "No .env.example found. Please create .env manually."
fi

# Generate Laravel application key
echo "Generating Laravel application key..."
php artisan key:generate

# Guide user for next steps
echo "Setup complete!"
echo "1. Edit $PROJECT_PATH/.env to configure your database and queue settings:"
echo "   - Update DB_CONNECTION, DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD."
echo "   - Set QUEUE_CONNECTION (e.g., 'redis' or 'database') for the queue worker."
echo "   - Example: nano $PROJECT_PATH/.env"
echo "2. After configuring .env, run migrations manually:"
echo "   cd $PROJECT_PATH && php artisan migrate"
echo "3. Access your site at: http://$DOMAIN_NAME (add $DOMAIN_NAME to /etc/hosts if needed, e.g., '127.0.0.1 $DOMAIN_NAME')."
echo "4. Supervisor is running the queue worker. Check status with: supervisorctl status"

# Verify installations
echo "Verifying installations..."
echo "PHP Version:"
php -v
echo "Loaded PHP extensions:"
php -m | grep -E "curl|mbstring|xml|bcmath|zip|tokenizer|ctype|fileinfo|intl|json|pdo|mysql|sqlite3|redis|gd" && echo "All requested extensions are loaded!" || echo "Some extensions may be missing."
echo "Composer Version:"
composer --version
echo "Node.js Version:"
node -v
echo "npm Version:"
npm -v
echo "Apache status:"
systemctl status apache2 --no-pager | head -n 3
echo "Supervisor status:"
supervisorctl status
# Cloud Laravel Deploy

An automated Bash script to set up a Laravel project on an Ubuntu server with Apache, PHP, MySQL, Node.js, and Supervisor. This script simplifies the deployment process by installing all necessary dependencies, configuring Apache virtual hosts, and setting up queue workers.

## Features
- Installs and configures Apache, PHP, MySQL, Node.js, Composer, and Supervisor
- Allows users to choose their PHP version (minimum 7.4, default 8.3)
- Clones a Laravel project from a Git repository
- Configures Apache virtual host for the Laravel project
- Sets up Supervisor for queue workers
- Installs necessary PHP extensions for Laravel
- Automates environment setup and dependency installation

## Prerequisites
- A fresh Ubuntu server (20.04 or later)
- Root or sudo access
- A Laravel project repository (Git URL required)

## Installation & Usage
### Step 1: Clone the repository
```bash
cd /opt  # Or any directory you prefer
sudo git clone https://github.com/PreciousGariya/cloud-laravel-deploy.git
cd cloud-laravel-deploy
```

### Step 2: Run the script
```bash
sudo chmod +x setup_apache_laravel.sh
sudo ./setup_apache_laravel.sh
```

### Step 3: Follow the prompts
- Choose the PHP version
- Provide the Laravel Git repository URL
- Enter the directory name for your Laravel project

### Step 4: Finalize setup
- Edit the `.env` file to configure database and queue settings
- Run migrations manually:
  ```bash
  php artisan migrate
  ```
- If using a local domain, add an entry to `/etc/hosts`:
  ```bash
  127.0.0.1 your-project.local
  ```

## Post-Deployment Verification
Run the following commands to verify the installation:
```bash
php -v          # Check PHP version
composer --version  # Check Composer version
node -v        # Check Node.js version
npm -v         # Check npm version
systemctl status apache2  # Verify Apache status
supervisorctl status      # Check Supervisor queue worker
```

## Issues & Contributions

If you encounter any issues, have suggestions, or want to contribute, feel free to comment or push changes via a pull request.

## Support

If you find this project helpful, consider supporting me with a coffee! [☕💙💖 Buy me a coffee](https://buymeacoffee.com/preciousgariya)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author
[Precious Gariya](https://github.com/PreciousGariya)


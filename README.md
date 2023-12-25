# Development Environment Setup Script

This script, `dev_env_setup.sh`, automates the process of setting up a development environment on a Linux system. It installs and configures various tools and services, including Nginx, PHP, Composer, NVM(node version manager), and Supervisor.

## What the Script Does
Here's a brief overview of what the script does:

1. Updates the system's package lists and upgrades all installed packages.
2. Installs essential development tools like git, curl, vim & unzip.
3. Installs and configures multiple versions(7.4, 8.2) of PHP.
4. Installs and configures Composer.
5. Installs and configures NVM and Node.js(16.18, 20.10).
6. Installs and configures Nginx.
7. Generates an SSL certificate for localhost.
8. Installs and configures Supervisor.
9. Cleans up unnecessary packages.

## Usage

To use this script, you need to have `bash` installed on your system.

Edit hosts file
- **Windows:** C:\Windows\System32\drivers\etc\hosts
- **macOS and Linux:** /etc/hosts

```text
127.0.0.1 api.monorepo.test
127.0.0.1 monorepo.test
```
Make sure to give the script execute permissions before running it:

```bash
chmod +x dev_env_setup.sh
```
You can run the script with the following command:

```bash
./dev_env_setup.sh
```

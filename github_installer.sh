#!/bin/bash

# =========================================================================
#  HyperV1 Theme Installer (GitHub Version)
#  Automated installer for Pterodactyl Panel with HyperV1 Theme
# =========================================================================

set -e

# --- Configuration ---
# Change these if you want to point to a different repository
GH_USER="kiruthik123"
GH_REPO="cracked-"
BRANCH="main"
# ---------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
USE_LOCAL_FILES=0

for _arg in "$@"; do
    case "$_arg" in
        --local) USE_LOCAL_FILES=1 ;;
    esac
done
unset _arg

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root or with sudo privileges."
    exit 1
fi

echo ""
echo "===================================================="
echo "      HyperV1 Theme Installer (GitHub Edition)      "
echo "===================================================="
echo ""

read -rp "Enter your Pterodactyl panel path [/var/www/pterodactyl]: " PANEL_PATH
PANEL_PATH=${PANEL_PATH:-/var/www/pterodactyl}

if [[ ! -d "$PANEL_PATH" ]]; then
    echo "Error: Path $PANEL_PATH does not exist!"
    exit 1
fi

echo "1) Install/Update HyperV1 Theme"
echo "2) Restore from Backup"
echo "=============================="
read -rp "Choose an option (1 or 2): " OPTION

backup_panel() {
    echo "Backing up your panel files..."
    cd /var/www || exit
    tar -czf "pterodactyl_backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
        --exclude='pterodactyl/vendor' \
        --exclude='pterodactyl/node_modules' \
        --exclude='pterodactyl/storage/logs' \
        --exclude='pterodactyl/storage/framework/cache' \
        pterodactyl/
    echo "Backup completed."
}

install_hyperv1_files() {
    echo "Downloading HyperV1 files from GitHub..."
    cd "$PANEL_PATH" || exit

    DOWNLOAD_URL="https://github.com/${GH_USER}/${GH_REPO}/releases/download/v1.0.0/Hyperv1.tar"
    
    echo "Fetching from: $DOWNLOAD_URL"
    if curl -f -L -o "Hyperv1.tar" "$DOWNLOAD_URL"; then
        echo "Successfully downloaded Hyperv1.tar"
    else
        echo "Failed to download from Release. Trying raw file fallback..."
        DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${BRANCH}/Hyperv1.tar"
        if curl -f -L -o "Hyperv1.tar" "$DOWNLOAD_URL"; then
            echo "Successfully downloaded Hyperv1.tar (Raw)"
        else
            echo "Error: Could not download the theme file."
            exit 1
        fi
    fi

    echo "Extracting files (this might take a second)..."
    tar -xvf "Hyperv1.tar" || { echo "❌ Extraction failed!"; exit 1; }
    rm -f "Hyperv1.tar"
    echo "✅ Extraction complete."
}

set_permissions() {
    echo "Setting permissions..."
    # Detect the web server user
    WEBUSER="www-data"
    if id "nginx" &>/dev/null; then WEBUSER="nginx"; fi
    if id "apache" &>/dev/null; then WEBUSER="apache"; fi
    
    chown -R $WEBUSER:$WEBUSER "$PANEL_PATH"/*
    chmod -R 755 "$PANEL_PATH"/storage/* "$PANEL_PATH"/bootstrap/cache/
    echo "✅ Permissions set to $WEBUSER."
}

clear_cache() {
    echo "Clearing Pterodactyl cache (Manual Mode)..."
    cd "$PANEL_PATH" || exit
    
    # Properly remove cache files and directories
    rm -rf storage/framework/views/*.php
    rm -rf storage/framework/cache/data/*
    rm -f bootstrap/cache/config.php
    rm -f bootstrap/cache/services.php
    rm -f bootstrap/cache/packages.php
    rm -f bootstrap/cache/routes-v7.php
    
    # Cleanup the installer files
    rm -f Hyperv1.tar
    
    echo "✅ Cache wiped and installer cleaned up."
}

# Add bypass logic here if needed
apply_cracks() {
    echo "Applying license bypasses..."
    # Example: Replace wrapper.blade.php license check with a mock
    WRAPPER_FILE="$PANEL_PATH/resources/views/templates/wrapper.blade.php"
    if [[ -f "$WRAPPER_FILE" ]]; then
        # Use sed or similar to comment out license lines or replace them
        # (This assumes the file in YOUR repo already has the fixes, 
        # but this is a safety net)
        echo "Bypasses should be included in your repo files."
    fi
}

check_ioncube() {
    if php -m | grep -qi "ionCube"; then
        echo "✅ ionCube Loader is already installed."
    else
        echo "❌ ionCube Loader is missing! This theme requires it."
        read -rp "Would you like to automatically install ionCube? (y/n): " INSTALL_ION
        if [[ "$INSTALL_ION" =~ ^[Yy]$ ]]; then
            echo "Installing ionCube Loader..."
            PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
            EXT_DIR=$(php -r 'echo ini_get("extension_dir");')
            
            mkdir -p /tmp/ioncube && cd /tmp/ioncube
            curl -sL https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz -o ioncube.tar.gz
            tar -xzf ioncube.tar.gz
            
            cp "ioncube/ioncube_loader_lin_${PHP_VER}.so" "$EXT_DIR/"
            
            INI_FILE=$(php -i | grep "Loaded Configuration File" | awk '{print $NF}')
            if ! grep -q "ioncube_loader" "$INI_FILE"; then
                echo "zend_extension=ioncube_loader_lin_${PHP_VER}.so" | sudo tee -a "$INI_FILE" > /dev/null
            fi
            
            # Also add to fpm if it exists
            FPM_INI="/etc/php/${PHP_VER}/fpm/php.ini"
            if [[ -f "$FPM_INI" ]]; then
                if ! grep -q "ioncube_loader" "$FPM_INI"; then
                    echo "zend_extension=ioncube_loader_lin_${PHP_VER}.so" | sudo tee -a "$FPM_INI" > /dev/null
                fi
                systemctl restart "php${PHP_VER}-fpm" || true
            fi
            
            echo "✅ ionCube installed! Please restart your webserver (nginx/apache)."
        else
            echo "Skipping ionCube installation. The theme may not work!"
        fi
    fi
}

case $OPTION in
1)
    echo "--- Starting Installation ---"
    check_ioncube
    backup_panel
    install_hyperv1_files
    apply_cracks
    clear_cache
    set_permissions
    
    echo ""
    echo "=================================================="
    echo "         Installation Finished Successfully!"
    echo "=================================================="
    echo "1. Restart your web server (e.g., systemctl restart nginx)"
    echo "2. Restart PHP-FPM (e.g., systemctl restart php8.1-fpm)"
    echo "3. Clear your browser cache (CTRL + F5)"
    echo ""
    echo "Verify Hyper is active:"
    if grep -q "HyperV1" "$PANEL_PATH/resources/views/templates/wrapper.blade.php"; then
        echo "✅ Verification Passed: HyperV1 files detected."
    else
        echo "❌ Verification Failed: HyperV1 files NOT detected in panel root."
        echo "   Please check if your tarball has the correct folder structure."
    fi
    echo "=================================================="
    ;;
2)
    echo "Please find your backup in /var/www/ and extract it manually."
    echo "Example: tar -xf pterodactyl_backup_XXX.tar.gz -C /var/www/pterodactyl"
    ;;
*)
    echo "Invalid option."
    exit 1
    ;;
esac

echo ""
echo "🎉 Process Finished Successfully!"

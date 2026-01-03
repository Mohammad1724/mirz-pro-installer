#!/bin/bash
# =============================================
# Mirza Pro Manager - Version 3.4.0
# =============================================

# ===================== Global Variables =====================
MIRZA_PATH="/var/www/mirzapro"
BACKUP_PATH="/root/mirza_backups"
LOG_FILE="/var/log/mirza_manager.log"
CONFIG_FILE="$MIRZA_PATH/config.php"

# ===================== Colors =====================
RED='\e[1;31m'
GREEN='\e[1;92m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;96m'
WHITE='\e[1;37m'
NC='\e[0m'

# ===================== Logging =====================
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ===================== Logo =====================
mirza_logo() {
    clear
    echo -e "${CYAN}"
    cat << EOF
███╗   ███╗██╗██████╗ ███████╗ █████╗     ██████╗ ██████╗  ██████╗ 
████╗ ████║██║██╔══██╗╚══███╔╝██╔══██╗    ██╔══██╗██╔══██╗██╔═══██╗
██╔████╔██║██║██████╔╝  ███╔╝ ███████║    ██████╔╝██████╔╝██║   ██║
██║╚██╔╝██║██║██╔══██╗ ███╔╝  ██╔══██║    ██╔═══╝ ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║██║  ██║███████╗██║  ██║    ██║     ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝
                    Version 3.4.0 - Simplified
EOF
    echo -e "${NC}"
}

# ===================== Wait for APT =====================
wait_for_apt() {
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo -e "${YELLOW}Waiting for apt locks to be released...${NC}"
        sleep 10
    done
}

# ===================== Input Validation =====================
validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_bot_token() {
    local token=$1
    if [[ ! "$token" =~ ^[0-9]+:[A-Za-z0-9_-]{35,}$ ]]; then
        return 1
    fi
    return 0
}

# ===================== Install Mirza =====================
install_mirza() {
    mirza_logo
    echo -e "${CYAN}                  Starting Mirza Pro Installation${NC}\n"
    
    echo -e "${YELLOW}Select Mirza Pro Version to Install:${NC}"
    echo -e "1) Original Version (mahdiMGF2)"
    echo -e "2) Modified Version (Mmd-Amir)"
    read -p "Choice (1-2): " repo_choice
    
    case $repo_choice in
        2)
            REPO_URL="https://github.com/Mmd-Amir/mirza_pro.git"
            REPO_NAME="Mmd-Amir"
            ;;
        *)
            REPO_URL="https://github.com/mahdiMGF2/mirza_pro.git"
            REPO_NAME="mahdiMGF2 (Official)"
            ;;
    esac

    wait_for_apt
    [[ ! $(command -v openssl) ]] && apt-get install -y openssl
    [[ ! $(command -v dig) ]] && apt-get install -y dnsutils
    
    if ! apt-cache search php8.2 | grep -q php8.2; then
        apt-get install -y software-properties-common gnupg
        add-apt-repository ppa:ondrej/php -y
        wait_for_apt
        apt-get update
    fi

    while true; do
        read -p "Domain (e.g., bot.example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then break; else echo -e "${RED}Invalid domain format!${NC}"; fi
    done
    
    while true; do
        read -p "Bot Token: " BOT_TOKEN
        if validate_bot_token "$BOT_TOKEN"; then break; else echo -e "${RED}Invalid token!${NC}"; fi
    done

    read -p "Admin ID (numeric): " ADMIN_ID
    read -p "Bot Username (without @): " BOT_USERNAME

    echo -e "\n${YELLOW}Marzban Version Configuration:${NC}"
    read -p "Are you using Marzban Panel v1.0.0 or higher? (y/N): " IS_NEW_MARZBAN
    if [[ "$IS_NEW_MARZBAN" =~ ^([yY][eE][sS]|[yY])$ ]]; then MARZBAN_VAL="true"; else MARZBAN_VAL="false"; fi

    read -p "Database Name (Enter = mirzapro): " DB_NAME; DB_NAME=${DB_NAME:-mirzapro}
    read -p "Database User (Enter = mirza_user): " DB_USER; DB_USER=${DB_USER:-mirza_user}
    read -s -p "Database Password (Enter = auto-generate): " DB_PASS_INPUT; echo ""

    if [[ -z "$DB_PASS_INPUT" ]]; then
        DB_PASS=$(openssl rand -base64 32 | tr -d /=+ | cut -c -32)
    else
        DB_PASS="$DB_PASS_INPUT"
    fi

    echo "$DB_PASS" > /root/mirza_pass.txt
    chmod 600 /root/mirza_pass.txt

    wait_for_apt
    echo -e "${YELLOW}Installing packages...${NC}"
    apt-get install -y apache2 mariadb-server git curl ufw phpmyadmin certbot python3-certbot-apache \
        php8.2 libapache2-mod-php8.2 php8.2-{mysql,curl,mbstring,xml,zip,gd,bcmath} php8.2-zip 2>/dev/null

    ufw allow 22/tcp >/dev/null 2>&1
    ufw allow 'Apache Full' >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    a2enmod rewrite ssl headers >/dev/null 2>&1

    mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    rm -rf "$MIRZA_PATH"
    git clone "$REPO_URL" "$MIRZA_PATH"
    chown -R www-data:www-data "$MIRZA_PATH"
    chmod -R 755 "$MIRZA_PATH"

    cat > "$CONFIG_FILE" <<EOF
<?php
if(!defined("index")) define("index", true);
\$dbname     = '$DB_NAME';
\$usernamedb = '$DB_USER';
\$passworddh = '$DB_PASS';
\$connect = mysqli_connect("localhost", \$usernamedb, \$passworddh, \$dbname);
if (!\$connect) die("Database connection failed!");
mysqli_set_charset(\$connect, "utf8mb4");
try {
    \$pdo = new PDO("mysql:host=localhost;dbname=$DB_NAME;charset=utf8mb4", \$usernamedb, \$passworddh, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
} catch(Exception \$e) { die("PDO connection error"); }
\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = 'https://$DOMAIN';
\$usernamebot  = '$BOT_USERNAME';
\$new_marzban  = $MARZBAN_VAL;
?>
EOF

    cat > /etc/apache2/sites-available/mirzapro.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $MIRZA_PATH
    <Directory $MIRZA_PATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    Alias /phpmyadmin /usr/share/phpmyadmin
</VirtualHost>
EOF

    a2ensite mirzapro.conf >/dev/null 2>&1
    a2dissite 000-default.conf >/dev/null 2>&1
    
    cd "$MIRZA_PATH" || return
    [ ! -f version ] && echo "3.0" > version
    if [ -f alireza_single.php ]; then
        mv alireza_single.php alireza.php 2>/dev/null
        sed -i "s|require_once __DIR__ . '/alireza_single.php';|require_once __DIR__ . '/alireza.php';|g" panels.php
    fi
    if [ -f table.php ]; then
        sudo -u www-data php table.php >/dev/null 2>&1
    fi
    chown -R www-data:www-data "$MIRZA_PATH"

    certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --redirect -m admin@$DOMAIN >/dev/null 2>&1
    curl -s "https://api.telegram.org/bot$BOT_TOKEN/setWebhook?url=https://$DOMAIN/index.php" >/dev/null
    systemctl restart apache2
    echo -e "${GREEN}Installation completed! Source: $REPO_NAME${NC}"
}

# ===================== Telegram Auto Backup Setup =====================
setup_telegram_backup() {
    mirza_logo
    echo -e "${CYAN}Checking for Backup PHP file...${NC}"
    BACKUP_FILE=$(grep -rl "mysqldump" "$MIRZA_PATH" | grep ".php" | head -n 1)
    if [[ -n "$BACKUP_FILE" ]]; then
        read -p "Enable Auto-Backup to Telegram at 03:00 AM? (y/N): " cron_confirm
        if [[ "$cron_confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/php $BACKUP_FILE") | crontab -
            echo -e "${GREEN}Scheduled! ✅${NC}"
        fi
    else
        echo -e "${RED}Backup PHP file not found!${NC}"
    fi
}

# ===================== Simplified Log Viewer =====================
view_logs() {
    mirza_logo
    echo -e "${YELLOW}=== Most Important Logs ===${NC}\n"
    echo -e "${CYAN}1. Critical PHP & Apache Errors (Last 30 lines)${NC}"
    echo -e "${CYAN}2. Installer Manager Log (Action history)${NC}"
    echo -e "0. Back to menu\n"
    read -p "Select choice: " log_c
    case $log_c in
        1)
            echo -e "\n${RED}--- Apache/PHP Error Log ---${NC}"
            tail -n 30 /var/log/apache2/mirza_error.log 2>/dev/null || tail -n 30 /var/log/apache2/error.log
            ;;
        2)
            echo -e "\n${GREEN}--- Manager History ---${NC}"
            tail -n 30 "$LOG_FILE"
            ;;
        *) return 0 ;;
    esac
}

# ===================== Standard Functions =====================
delete_mirza() {
    mirza_logo
    read -p "Type 'DELETE' to confirm: " confirm
    if [[ "$confirm" == "DELETE" ]]; then
        DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        a2dissite mirzapro.conf 2>/dev/null
        rm -rf "$MIRZA_PATH" /etc/apache2/sites-available/mirzapro.conf
        mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null
        systemctl restart apache2
        echo -e "${GREEN}Deleted successfully.${NC}"
    fi
}

update_mirza() {
    mirza_logo
    if [[ -d "$MIRZA_PATH" ]]; then
        cp "$CONFIG_FILE" /tmp/config.php.backup
        cd "$MIRZA_PATH" && git fetch origin && git reset --hard origin/main
        cp /tmp/config.php.backup "$CONFIG_FILE"
        systemctl restart apache2
        echo -e "${GREEN}Updated successfully.${NC}"
    fi
}

backup_mirza() {
    mirza_logo
    local ts=$(date +%Y%m%d_%H%M%S)
    local bn="mirza_local_$ts"
    mkdir -p "$BACKUP_PATH/$bn"
    cp -r "$MIRZA_PATH" "$BACKUP_PATH/$bn/files"
    echo -e "${GREEN}Local backup created at $BACKUP_PATH${NC}"
}

service_status() {
    mirza_logo
    systemctl is-active apache2 mariadb
    free -m | awk 'NR==2{printf "RAM: %s/%sMB\n", $3, $2}'
}

restart_services() {
    systemctl restart apache2 mariadb
    echo -e "${GREEN}Restarted services successfully.${NC}"
}

webhook_status() {
    mirza_logo
    TOKEN=$(grep -oE "[0-9]+:[A-Za-z0-9_-]{35,}" "$CONFIG_FILE" 2>/dev/null)
    curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo"
}

# ===================== Main Menu =====================
main_menu() {
    while true; do
        mirza_logo
        echo -e "${YELLOW}       Mirza Pro Manager - Version 3.4.0${NC}\n"
        echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${WHITE}║  1.  Install Mirza Pro (2 Sources)               ║${NC}"
        echo -e "${WHITE}║  2.  Delete Mirza Pro                            ║${NC}"
        echo -e "${WHITE}║  3.  Update Mirza Pro                            ║${NC}"
        echo -e "${WHITE}║  4.  Local Backup                                ║${NC}"
        echo -e "${WHITE}║  5.  Restore Backup (Files Only)                 ║${NC}"
        echo -e "${WHITE}║  6.  View Logs (Simplified)                      ║${NC}"
        echo -e "${WHITE}║  7.  Service Status                              ║${NC}"
        echo -e "${WHITE}║  8.  Restart Services                            ║${NC}"
        echo -e "${WHITE}║  9.  Change Bot Settings (new_marzban etc.)      ║${NC}"
        echo -e "${WHITE}║  10. Webhook Status                              ║${NC}"
        echo -e "${WHITE}║  11. Setup Telegram Auto-Backup 🤖               ║${NC}"
        echo -e "${WHITE}║  12. Edit config.php                             ║${NC}"
        echo -e "${RED}║  0.  Exit                                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}\n"
        read -p "Choose: " choice
        case $choice in
            1) install_mirza ;; 2) delete_mirza ;; 3) update_mirza ;; 4) backup_mirza ;;
            5) read -p "Check $BACKUP_PATH. Press Enter..." dummy ;; 
            6) view_logs ;; 7) service_status ;;
            8) restart_services ;; 
            9) nano "$CONFIG_FILE" ;; 10) webhook_status ;;
            11) setup_telegram_backup ;; 12) nano "$CONFIG_FILE" ;;
            0) exit 0 ;;
        esac
        read -p "Press Enter to return..." dummy
    done
}

if [[ $EUID -ne 0 ]]; then exit 1; fi
mkdir -p "$BACKUP_PATH"
main_menu
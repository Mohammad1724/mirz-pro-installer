#!/bin/bash
# =============================================
# Mirza Pro Manager - Version 3.2.0
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
                    Version 3.2.0 - Ultimate Edition
EOF
    echo -e "${NC}"
}

# ===================== Wait for APT =====================
wait_for_apt() {
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo -e "${YELLOW}Waiting for apt locks to be released... (10 seconds)${NC}"
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

validate_admin_id() {
    local admin_id=$1
    if [[ ! "$admin_id" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# ===================== DNS Check =====================
check_dns() {
    local domain=$1
    local server_ip=$(curl -s ifconfig.me)
    local domain_ip=$(dig +short "$domain" | head -n1)
    
    if [[ "$server_ip" == "$domain_ip" ]]; then
        echo -e "${GREEN}DNS is correctly pointed to this server ✅${NC}"
        return 0
    else
        echo -e "${RED}DNS mismatch!${NC}"
        echo -e "${YELLOW}Server IP: $server_ip${NC}"
        echo -e "${YELLOW}Domain IP: $domain_ip${NC}"
        return 1
    fi
}

# ===================== Fix Mirza Errors =====================
fix_mirza_errors() {
    cd "$MIRZA_PATH" || return 1
    echo -e "${CYAN}Applying fixes and adjustments...${NC}"
    log_message "Starting fix_mirza_errors"

    [ ! -f version ] && echo "3.0" > version
    chown www-data:www-data version 2>/dev/null
    chmod 644 version 2>/dev/null

    for file in *.php; do
        [[ -f "$file" ]] || continue
        sed -i 's|define("index",.*);|if(!defined("index")) define("index", true);|g' "$file" 2>/dev/null
        sed -i 's|require_once("config.php");|if(!defined("index")) require_once("config.php");|g' "$file" 2>/dev/null
        sed -i 's|include("config.php");|if(!defined("index")) include("config.php");|g' "$file" 2>/dev/null
        sed -i 's|require("config.php");|if(!defined("index")) require("config.php");|g' "$file" 2>/dev/null
    done

    if [ -f alireza_single.php ]; then
        echo -e "${CYAN}Renaming alireza_single.php to alireza.php ...${NC}"
        mv alireza_single.php alireza.php 2>/dev/null
        sed -i "s|require_once __DIR__ . '/alireza_single.php';|require_once __DIR__ . '/alireza.php';|g" panels.php
        echo -e "${GREEN}Renaming completed successfully${NC}"
    fi

    if [ ! -f table.php ]; then
        curl -s -o table.php https://raw.githubusercontent.com/mahdiMGF2/mirza_pro/main/table.php
    fi

    if [ -f table.php ]; then
        sudo -u www-data php table.php >/dev/null 2>&1
        rm -f table.php
    fi

    chown -R www-data:www-data "$MIRZA_PATH" 2>/dev/null
    chmod -R 755 "$MIRZA_PATH" 2>/dev/null
    log_message "fix_mirza_errors completed"
}

# ===================== Install Mirza =====================
install_mirza() {
    mirza_logo
    echo -e "${CYAN}                  Starting Mirza Pro Installation${NC}\n"
    log_message "Starting installation"
    
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
        if validate_domain "$DOMAIN"; then break; else echo -e "${RED}Invalid domain!${NC}"; fi
    done
    
    check_dns "$DOMAIN"

    while true; do
        read -p "Bot Token: " BOT_TOKEN
        if validate_bot_token "$BOT_TOKEN"; then break; else echo -e "${RED}Invalid token!${NC}"; fi
    done

    while true; do
        read -p "Admin ID (numeric): " ADMIN_ID
        if validate_admin_id "$ADMIN_ID"; then break; else echo -e "${RED}Invalid Admin ID!${NC}"; fi
    done

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

    mirza_logo
    echo -e "${YELLOW}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│ Domain:       $DOMAIN${NC}"
    echo -e "${WHITE}│ Token:        ${BOT_TOKEN:0:15}...${NC}"
    echo -e "${WHITE}│ Admin ID:     $ADMIN_ID${NC}"
    echo -e "${WHITE}│ New Marzban:  $MARZBAN_VAL${NC}"
    echo -e "${YELLOW}└────────────────────────────────────────────────────┘${NC}\n"
    read -p "Is everything correct? (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1

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
    git clone https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_PATH"
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
    fix_mirza_errors

    echo -e "${YELLOW}Getting SSL...${NC}"
    certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --redirect -m admin@$DOMAIN >/dev/null 2>&1
    
    curl -s "https://api.telegram.org/bot$BOT_TOKEN/setWebhook?url=https://$DOMAIN/index.php" >/dev/null
    systemctl restart apache2

    echo -e "${GREEN}Installation completed! DB Password saved to /root/mirza_pass.txt${NC}"
    log_message "Installation completed"
}

# ===================== Telegram Auto Backup Setup =====================
setup_telegram_backup() {
    mirza_logo
    echo -e "${CYAN}Searching for Backup PHP file...${NC}"
    
    # جستجوی فایل بکاپی که شامل کدهای mysqldump باشد
    BACKUP_FILE=$(grep -rl "mysqldump" "$MIRZA_PATH" | grep ".php" | head -n 1)
    
    if [[ -n "$BACKUP_FILE" ]]; then
        echo -e "${GREEN}Found Backup File: $BACKUP_FILE${NC}"
        read -p "Do you want to enable Auto-Backup to Telegram every day at 03:00 AM? (y/N): " cron_confirm
        if [[ "$cron_confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/php $BACKUP_FILE") | crontab -
            echo -e "${GREEN}Auto-Backup scheduled successfully! ✅${NC}"
            log_message "Telegram Auto-Backup enabled for $BACKUP_FILE"
        fi
    else
        echo -e "${RED}Backup PHP file not found in $MIRZA_PATH!${NC}"
    fi
}

# ===================== Other Menu Functions =====================
delete_mirza() {
    mirza_logo
    read -p "Type 'DELETE' to confirm removal: " confirm
    if [[ "$confirm" == "DELETE" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE")
            DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE")
            mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; DROP USER IF EXISTS '$DB_USER'@'localhost';"
        fi
        rm -rf "$MIRZA_PATH" /etc/apache2/sites-available/mirzapro.conf
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
        fix_mirza_errors
        systemctl restart apache2
        echo -e "${GREEN}Updated successfully.${NC}"
    fi
}

backup_mirza() {
    mirza_logo
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="mirza_local_$timestamp"
    mkdir -p "$BACKUP_PATH/$backup_name"
    cp -r "$MIRZA_PATH" "$BACKUP_PATH/$backup_name/files"
    if [[ -f "$CONFIG_FILE" ]]; then
        DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE")
        DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE")
        DB_PASS=$(grep -oP "\\\$passworddh\s*=\s*'\K[^']+" "$CONFIG_FILE")
        mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_PATH/$backup_name/database.sql" 2>/dev/null
    fi
    cd "$BACKUP_PATH" && tar -czf "${backup_name}.tar.gz" "$backup_name" && rm -rf "$backup_name"
    echo -e "${GREEN}Local backup created at: $BACKUP_PATH/${backup_name}.tar.gz${NC}"
}

restore_backup() {
    mirza_logo
    local backups=($(ls "$BACKUP_PATH"/*.tar.gz 2>/dev/null))
    if [[ ${#backups[@]} -eq 0 ]]; then echo "No backups."; return 1; fi
    for i in "${!backups[@]}"; do echo -e "${GREEN}$((i+1)).${NC} $(basename "${backups[$i]}")"; done
    read -p "Select number: " choice
    local selected="${backups[$((choice-1))]}"
    local temp_dir=$(mktemp -d)
    tar -xzf "$selected" -C "$temp_dir"
    local b_name=$(ls "$temp_dir")
    rm -rf "$MIRZA_PATH" && cp -r "$temp_dir/$b_name/files" "$MIRZA_PATH"
    chown -R www-data:www-data "$MIRZA_PATH"
    rm -rf "$temp_dir"
    systemctl restart apache2
    echo -e "${GREEN}Files restored.${NC}"
}

view_logs() {
    mirza_logo
    echo -e "1. Apache Error  2. Apache Access  3. Manager Log"
    read -p "Choice: " lc
    case $lc in
        1) tail -n 50 /var/log/apache2/mirza_error.log ;;
        2) tail -n 50 /var/log/apache2/mirza_access.log ;;
        3) tail -n 50 "$LOG_FILE" ;;
    esac
}

live_log_monitor() {
    mirza_logo
    echo -e "1. Apache Error  2. Apache Access  3. Bot Requests (Filtered)"
    read -p "Choice: " lmon
    case $lmon in
        1) tail -f /var/log/apache2/mirza_error.log ;;
        2) tail -f /var/log/apache2/mirza_access.log ;;
        3) tail -f /var/log/apache2/mirza_access.log | grep --line-buffered "POST.*index.php" ;;
    esac
}

service_status() {
    mirza_logo
    echo -ne "Apache2: "; systemctl is-active --quiet apache2 && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}"
    echo -ne "MariaDB: "; systemctl is-active --quiet mariadb && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}"
    df -h / | awk 'NR==2{print "Disk: "$3"/"$2" ("$5")"}'
    free -m | awk 'NR==2{printf "RAM: %s/%sMB\n", $3, $2}'
}

restart_services() {
    systemctl restart apache2 mariadb
    echo -e "${GREEN}Services restarted.${NC}"
}

change_bot_settings() {
    mirza_logo
    echo -e "1. Token  2. Admin ID  3. Marzban Version (true/false)"
    read -p "Choice: " cbs
    case $cbs in
        1) read -p "Token: " nt; sed -i "s|\$APIKEY\s*=\s*'[^']*'|\$APIKEY = '$nt'|" "$CONFIG_FILE" ;;
        2) read -p "Admin: " na; sed -i "s|\$adminnumber\s*=\s*'[^']*'|\$adminnumber = '$na'|" "$CONFIG_FILE" ;;
        3) read -p "New Marzban: " nm; sed -i "s|\$new_marzban\s*=\s*[^;]*;|\$new_marzban = $nm;|" "$CONFIG_FILE" ;;
    esac
    systemctl restart apache2
}

webhook_status() {
    mirza_logo
    TOKEN=$(grep -oE "[0-9]+:[A-Za-z0-9_-]{35,}" "$CONFIG_FILE" 2>/dev/null)
    curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo" | python3 -m json.tool 2>/dev/null || curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo"
}

# ===================== Main Menu =====================
main_menu() {
    while true; do
        mirza_logo
        echo -e "${YELLOW}       Mirza Pro Manager - Ultimate Edition${NC}\n"
        echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${WHITE}║  1.  Install Mirza Pro                           ║${NC}"
        echo -e "${WHITE}║  2.  Delete Mirza Pro                            ║${NC}"
        echo -e "${WHITE}║  3.  Update Mirza Pro                            ║${NC}"
        echo -e "${WHITE}║  4.  Local Backup (Files + DB)                   ║${NC}"
        echo -e "${WHITE}║  5.  Restore Backup                              ║${NC}"
        echo -e "${WHITE}║  6.  View Logs                                   ║${NC}"
        echo -e "${WHITE}║  7.  Live Log Monitor                            ║${NC}"
        echo -e "${WHITE}║  8.  Service Status                              ║${NC}"
        echo -e "${WHITE}║  9.  Restart Services                            ║${NC}"
        echo -e "${WHITE}║  10. Change Bot Settings                         ║${NC}"
        echo -e "${WHITE}║  11. Webhook Status                              ║${NC}"
        echo -e "${WHITE}║  12. Setup Telegram Auto-Backup 🤖               ║${NC}"
        echo -e "${WHITE}║  13. Edit config.php                             ║${NC}"
        echo -e "${RED}║  0.  Exit                                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}\n"
        read -p "Choose an option (0-13): " choice
        case $choice in
            1) install_mirza ;; 2) delete_mirza ;; 3) update_mirza ;; 4) backup_mirza ;;
            5) restore_backup ;; 6) view_logs ;; 7) live_log_monitor ;; 8) service_status ;;
            9) restart_services ;; 10) change_bot_settings ;; 11) webhook_status ;;
            12) setup_telegram_backup ;;
            13) [[ -f "$CONFIG_FILE" ]] && nano "$CONFIG_FILE" && systemctl restart apache2 ;;
            0) exit 0 ;;
        esac
        read -p "Press Enter to return to menu..." dummy
    done
}

if [[ $EUID -ne 0 ]]; then echo -e "${RED}Run as root!${NC}"; exit 1; fi
mkdir -p "$BACKUP_PATH"
log_message "Manager Started"
main_menu
#!/bin/bash
# =============================================
# Mirza Pro Manager - Version 3.0.0
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
                    Version 3.0.0 - Enhanced
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
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]; then
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

validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-zA-Z][a-zA-Z0-9_]{4,31}$ ]]; then
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
        echo -e "${GREEN}DNS is correctly pointed to this server${NC}"
        return 0
    else
        echo -e "${RED}DNS mismatch!${NC}"
        echo -e "${YELLOW}Server IP: $server_ip${NC}"
        echo -e "${YELLOW}Domain IP: $domain_ip${NC}"
        return 1
    fi
}

# ===================== Disk Space Check =====================
check_disk_space() {
    local required_mb=$1
    local available_mb=$(df / | tail -1 | awk '{print int($4/1024)}')
    
    if [[ $available_mb -lt $required_mb ]]; then
        echo -e "${RED}Not enough disk space! Required: ${required_mb}MB, Available: ${available_mb}MB${NC}"
        return 1
    fi
    return 0
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
        if sudo -u www-data php table.php >/dev/null 2>&1; then
            echo -e "${GREEN}Tables created successfully${NC}"
        else
            echo -e "${YELLOW}Tables likely already exist${NC}"
        fi
        rm -f table.php
    fi

    chown -R www-data:www-data "$MIRZA_PATH" 2>/dev/null
    chmod -R 755 "$MIRZA_PATH" 2>/dev/null
    
    log_message "fix_mirza_errors completed"
    echo -e "${GREEN}All fixes applied - Mirza Pro is ready${NC}\n"
}

# ===================== Install Mirza =====================
install_mirza() {
    mirza_logo
    echo -e "${CYAN}                  Starting Mirza Pro Installation${NC}\n"
    log_message "Starting installation"
    
    if ! check_disk_space 500; then
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
    fi
    
    wait_for_apt

    [[ ! $(command -v openssl) ]] && apt-get install -y openssl
    [[ ! $(command -v dig) ]] && apt-get install -y dnsutils
    
    if ! apt-cache search php8.2 | grep -q php8.2; then
        apt-get install -y software-properties-common gnupg
        add-apt-repository ppa:ondrej/php -y
        wait_for_apt
        apt-get update
    fi

    # Get and validate domain
    while true; do
        read -p "Domain (e.g., bot.example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            echo -e "${RED}Invalid domain format! Please try again.${NC}"
        fi
    done
    
    # Check DNS
    echo -e "${YELLOW}Checking DNS...${NC}"
    if ! check_dns "$DOMAIN"; then
        read -p "DNS not pointed correctly. Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
    fi

    # Get and validate token
    while true; do
        read -p "Bot Token: " BOT_TOKEN
        if validate_bot_token "$BOT_TOKEN"; then
            break
        else
            echo -e "${RED}Invalid bot token format! (Example: 123456789:ABCdefGHI...)${NC}"
        fi
    done

    # Get and validate Admin ID
    while true; do
        read -p "Admin ID (numeric): " ADMIN_ID
        if validate_admin_id "$ADMIN_ID"; then
            break
        else
            echo -e "${RED}Admin ID must be numeric!${NC}"
        fi
    done

    # Get and validate username
    while true; do
        read -p "Bot Username (without @): " BOT_USERNAME
        if validate_username "$BOT_USERNAME"; then
            break
        else
            echo -e "${RED}Invalid username! (5-32 characters, start with letter)${NC}"
        fi
    done

    read -p "Database Name (Enter = mirzapro): " DB_NAME
    DB_NAME=${DB_NAME:-mirzapro}
    
    read -p "Database User (Enter = mirza_user): " DB_USER
    DB_USER=${DB_USER:-mirza_user}
    
    read -s -p "Database Password (Enter = auto-generate): " DB_PASS_INPUT
    echo ""

    if [[ -z "$DB_PASS_INPUT" ]]; then
        DB_PASS=$(openssl rand -base64 32 | tr -d /=+ | cut -c -32)
        echo -e "${YELLOW}Auto-generated database password${NC}"
    else
        DB_PASS="$DB_PASS_INPUT"
    fi

    mirza_logo
    echo -e "${YELLOW}+----------------------------------------------------+${NC}"
    echo -e "${YELLOW}|                  Preview Information               |${NC}"
    echo -e "${WHITE}| Domain:       $DOMAIN${NC}"
    echo -e "${WHITE}| Token:        ${BOT_TOKEN:0:20}...${NC}"
    echo -e "${WHITE}| Admin ID:     $ADMIN_ID${NC}"
    echo -e "${WHITE}| Bot Username: $BOT_USERNAME${NC}"
    echo -e "${WHITE}| Database:     $DB_NAME${NC}"
    echo -e "${WHITE}| DB User:      $DB_USER${NC}"
    echo -e "${WHITE}| DB Password:  ********** (hidden)${NC}"
    echo -e "${YELLOW}+----------------------------------------------------+${NC}\n"
    
    read -p "Is everything correct? (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1

    # Save password securely
    echo "$DB_PASS" > /root/mirza_pass.txt
    chmod 600 /root/mirza_pass.txt

    wait_for_apt
    echo -e "${YELLOW}Installing packages...${NC}"
    log_message "Installing packages"
    
    apt-get install -y apache2 mariadb-server git curl ufw phpmyadmin certbot python3-certbot-apache \
        php8.2 libapache2-mod-php8.2 php8.2-{mysql,curl,mbstring,xml,zip,gd,bcmath} 2>&1 | tee -a "$LOG_FILE"

    ufw allow 22/tcp >/dev/null 2>&1
    ufw allow OpenSSH >/dev/null 2>&1
    ufw allow 'Apache Full' >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    a2enmod rewrite >/dev/null 2>&1
    a2enmod ssl >/dev/null 2>&1
    a2enmod headers >/dev/null 2>&1

    mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    log_message "Database created: $DB_NAME"

    rm -rf "$MIRZA_PATH"
    if git clone https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_PATH"; then
        chown -R www-data:www-data "$MIRZA_PATH"
        chmod -R 755 "$MIRZA_PATH"
        log_message "Repository cloned successfully"
    else
        echo -e "${RED}Failed to clone repository!${NC}"
        log_message "ERROR: Failed to clone repository"
        return 1
    fi

    # Create config.php
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
} catch(Exception \$e) {
    die("PDO connection error");
}

\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = 'https://$DOMAIN';
\$usernamebot  = '$BOT_USERNAME';
?>
EOF

    chown www-data:www-data "$CONFIG_FILE"
    chmod 640 "$CONFIG_FILE"

    # Apache VirtualHost
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
    ErrorLog \${APACHE_LOG_DIR}/mirza_error.log
    CustomLog \${APACHE_LOG_DIR}/mirza_access.log combined
</VirtualHost>
EOF

    a2ensite mirzapro.conf >/dev/null 2>&1
    a2dissite 000-default.conf >/dev/null 2>&1

    fix_mirza_errors

    echo -e "${YELLOW}Getting SSL certificate...${NC}"
    if certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --redirect -m admin@$DOMAIN 2>&1 | tee -a "$LOG_FILE"; then
        echo -e "${GREEN}SSL certificate obtained successfully${NC}"
        log_message "SSL certificate obtained"
    else
        echo -e "${YELLOW}SSL failed - you can try manually later${NC}"
        log_message "WARNING: SSL certificate failed"
    fi

    echo -e "${YELLOW}Setting webhook...${NC}"
    WEBHOOK_RESULT=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/setWebhook?url=https://$DOMAIN/index.php")
    if echo "$WEBHOOK_RESULT" | grep -q '"ok":true'; then
        echo -e "${GREEN}Webhook set successfully${NC}"
        log_message "Webhook set successfully"
    else
        echo -e "${YELLOW}Webhook not set - set it manually later${NC}"
        log_message "WARNING: Webhook not set"
    fi

    systemctl restart apache2

    mirza_logo
    echo -e "${GREEN}+==================================================+${NC}"
    echo -e "${GREEN}|        Installation completed successfully!      |${NC}"
    echo -e "${GREEN}| Your domain:      https://$DOMAIN${NC}"
    echo -e "${GREEN}| phpMyAdmin:       https://$DOMAIN/phpmyadmin${NC}"
    echo -e "${GREEN}| Database info:    /root/mirza_pass.txt           |${NC}"
    echo -e "${GREEN}| Install log:      $LOG_FILE${NC}"
    echo -e "${GREEN}+==================================================+${NC}\n"
    echo -e "${YELLOW}     Go to your bot and send /start${NC}\n"
    
    log_message "Installation completed successfully"
}

# ===================== Delete Mirza =====================
delete_mirza() {
    mirza_logo
    echo -e "${RED}+==================================================+${NC}"
    echo -e "${RED}|           WARNING: DELETE MIRZA PRO              |${NC}"
    echo -e "${RED}|      This will remove ALL data permanently!      |${NC}"
    echo -e "${RED}+==================================================+${NC}\n"
    
    echo -e "${YELLOW}This will delete:${NC}"
    echo -e "  - $MIRZA_PATH (all files)"
    echo -e "  - Database and user"
    echo -e "  - Apache configuration"
    echo -e "  - SSL certificates\n"
    
    read -p "Are you SURE? Type 'DELETE' to confirm: " confirm
    if [[ "$confirm" != "DELETE" ]]; then
        echo -e "${GREEN}Cancelled.${NC}"
        return 0
    fi
    
    # Backup before delete
    read -p "Create backup before deletion? (Y/n): " backup_confirm
    if [[ "$backup_confirm" != "n" && "$backup_confirm" != "N" ]]; then
        backup_mirza "pre-delete"
    fi
    
    log_message "Starting deletion process"
    
    # Extract database info
    if [[ -f "$CONFIG_FILE" ]]; then
        DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
    fi
    
    echo -e "${YELLOW}Stopping Apache...${NC}"
    systemctl stop apache2
    
    echo -e "${YELLOW}Removing Apache configuration...${NC}"
    a2dissite mirzapro.conf 2>/dev/null
    a2dissite mirzapro-le-ssl.conf 2>/dev/null
    rm -f /etc/apache2/sites-available/mirzapro.conf
    rm -f /etc/apache2/sites-available/mirzapro-le-ssl.conf
    a2ensite 000-default.conf 2>/dev/null
    
    echo -e "${YELLOW}Removing files...${NC}"
    rm -rf "$MIRZA_PATH"
    
    echo -e "${YELLOW}Removing database...${NC}"
    if [[ -n "$DB_NAME" ]]; then
        mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
        echo -e "${GREEN}Database '$DB_NAME' dropped${NC}"
    fi
    
    if [[ -n "$DB_USER" ]]; then
        mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null
        mysql -e "FLUSH PRIVILEGES;"
        echo -e "${GREEN}User '$DB_USER' dropped${NC}"
    fi
    
    echo -e "${YELLOW}Restarting Apache...${NC}"
    systemctl start apache2
    
    log_message "Deletion completed"
    
    echo -e "\n${GREEN}+==================================================+${NC}"
    echo -e "${GREEN}|         Mirza Pro deleted successfully!          |${NC}"
    echo -e "${GREEN}+==================================================+${NC}\n"
}

# ===================== Update Mirza =====================
update_mirza() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|              UPDATE MIRZA PRO                    |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    if [[ ! -d "$MIRZA_PATH" ]]; then
        echo -e "${RED}Mirza Pro is not installed!${NC}"
        return 1
    fi
    
    log_message "Starting update process"
    
    # Backup before update
    echo -e "${YELLOW}Creating backup before update...${NC}"
    backup_mirza "pre-update"
    
    # Save config.php
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" /tmp/config.php.backup
        echo -e "${GREEN}Config backed up${NC}"
    fi
    
    cd "$MIRZA_PATH" || return 1
    
    echo -e "${YELLOW}Fetching updates from GitHub...${NC}"
    
    git fetch origin 2>&1 | tee -a "$LOG_FILE"
    git reset --hard origin/main 2>&1 | tee -a "$LOG_FILE"
    
    # Restore config.php
    if [[ -f /tmp/config.php.backup ]]; then
        cp /tmp/config.php.backup "$CONFIG_FILE"
        rm /tmp/config.php.backup
        echo -e "${GREEN}Config restored${NC}"
    fi
    
    fix_mirza_errors
    
    chown -R www-data:www-data "$MIRZA_PATH"
    chmod -R 755 "$MIRZA_PATH"
    chmod 640 "$CONFIG_FILE"
    
    systemctl restart apache2
    
    log_message "Update completed"
    
    echo -e "\n${GREEN}+==================================================+${NC}"
    echo -e "${GREEN}|         Mirza Pro updated successfully!          |${NC}"
    echo -e "${GREEN}+==================================================+${NC}\n"
}

# ===================== Backup =====================
backup_mirza() {
    local backup_type=${1:-"manual"}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="mirza_backup_${backup_type}_${timestamp}"
    local backup_dir="$BACKUP_PATH/$backup_name"
    
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|              BACKUP MIRZA PRO                    |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    if [[ ! -d "$MIRZA_PATH" ]]; then
        echo -e "${RED}Mirza Pro is not installed!${NC}"
        return 1
    fi
    
    log_message "Starting backup: $backup_name"
    
    mkdir -p "$backup_dir"
    
    echo -e "${YELLOW}Backing up files...${NC}"
    cp -r "$MIRZA_PATH" "$backup_dir/files"
    echo -e "${GREEN}Files backed up${NC}"
    
    # Backup database
    if [[ -f "$CONFIG_FILE" ]]; then
        DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        DB_PASS=$(grep -oP "\\\$passworddh\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        
        if [[ -n "$DB_NAME" ]]; then
            echo -e "${YELLOW}Backing up database...${NC}"
            mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$backup_dir/database.sql" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Database backed up${NC}"
            else
                echo -e "${YELLOW}Database backup failed (trying without password)...${NC}"
                mysqldump "$DB_NAME" > "$backup_dir/database.sql" 2>/dev/null
            fi
        fi
    fi
    
    # Compress
    echo -e "${YELLOW}Compressing backup...${NC}"
    cd "$BACKUP_PATH"
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_dir"
    
    local backup_size=$(du -h "${backup_name}.tar.gz" | cut -f1)
    
    log_message "Backup completed: ${backup_name}.tar.gz ($backup_size)"
    
    echo -e "\n${GREEN}+==================================================+${NC}"
    echo -e "${GREEN}|            Backup created successfully!          |${NC}"
    echo -e "${GREEN}+==================================================+${NC}"
    echo -e "${WHITE}Location: $BACKUP_PATH/${backup_name}.tar.gz${NC}"
    echo -e "${WHITE}Size: $backup_size${NC}\n"
    
    echo -e "${YELLOW}All backups:${NC}"
    ls -lh "$BACKUP_PATH"/*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
}

# ===================== Restore Backup =====================
restore_backup() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|             RESTORE MIRZA PRO                    |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo -e "${RED}No backups found!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Available backups:${NC}\n"
    
    local backups=($(ls -t "$BACKUP_PATH"/*.tar.gz 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${RED}No backups found!${NC}"
        return 1
    fi
    
    local i=1
    for backup in "${backups[@]}"; do
        local name=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        echo -e "  ${GREEN}$i.${NC} $name ${YELLOW}($size - $date)${NC}"
        ((i++))
    done
    
    echo ""
    read -p "Select backup number (or 0 to cancel): " selection
    
    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        return 0
    fi
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -gt ${#backups[@]} ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        return 1
    fi
    
    local selected_backup="${backups[$((selection-1))]}"
    
    echo -e "\n${RED}WARNING: This will overwrite current installation!${NC}"
    read -p "Continue? (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 0
    
    log_message "Starting restore from: $(basename $selected_backup)"
    
    echo -e "${YELLOW}Extracting backup...${NC}"
    local temp_dir=$(mktemp -d)
    tar -xzf "$selected_backup" -C "$temp_dir"
    
    local backup_name=$(ls "$temp_dir")
    
    echo -e "${YELLOW}Restoring files...${NC}"
    rm -rf "$MIRZA_PATH"
    cp -r "$temp_dir/$backup_name/files" "$MIRZA_PATH"
    chown -R www-data:www-data "$MIRZA_PATH"
    chmod -R 755 "$MIRZA_PATH"
    echo -e "${GREEN}Files restored${NC}"
    
    # Restore database
    if [[ -f "$temp_dir/$backup_name/database.sql" ]]; then
        echo -e "${YELLOW}Restoring database...${NC}"
        
        if [[ -f "$CONFIG_FILE" ]]; then
            DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
            DB_USER=$(grep -oP "\\\$usernamedb\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
            DB_PASS=$(grep -oP "\\\$passworddh\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
            
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$temp_dir/$backup_name/database.sql" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Database restored${NC}"
            else
                echo -e "${YELLOW}Database restore failed - try manually${NC}"
            fi
        fi
    fi
    
    rm -rf "$temp_dir"
    
    systemctl restart apache2
    
    log_message "Restore completed"
    
    echo -e "\n${GREEN}+==================================================+${NC}"
    echo -e "${GREEN}|           Restore completed successfully!        |${NC}"
    echo -e "${GREEN}+==================================================+${NC}\n"
}

# ===================== View Logs =====================
view_logs() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|                   VIEW LOGS                      |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    echo -e "${GREEN}Select log to view:${NC}\n"
    echo -e "  1. Apache Error Log (last 50 lines)"
    echo -e "  2. Apache Access Log (last 50 lines)"
    echo -e "  3. Mirza Manager Log"
    echo -e "  4. PHP Error Log"
    echo -e "  5. System Log (syslog)"
    echo -e "  0. Back to menu\n"
    
    read -p "Select option: " log_choice
    
    case $log_choice in
        1)
            echo -e "\n${YELLOW}=== Apache Error Log (last 50 lines) ===${NC}\n"
            tail -n 50 /var/log/apache2/mirza_error.log 2>/dev/null || tail -n 50 /var/log/apache2/error.log
            ;;
        2)
            echo -e "\n${YELLOW}=== Apache Access Log (last 50 lines) ===${NC}\n"
            tail -n 50 /var/log/apache2/mirza_access.log 2>/dev/null || tail -n 50 /var/log/apache2/access.log
            ;;
        3)
            echo -e "\n${YELLOW}=== Mirza Manager Log ===${NC}\n"
            if [[ -f "$LOG_FILE" ]]; then
                tail -n 50 "$LOG_FILE"
            else
                echo "No manager log found"
            fi
            ;;
        4)
            echo -e "\n${YELLOW}=== PHP Error Log (last 50 lines) ===${NC}\n"
            tail -n 50 /var/log/php*error.log 2>/dev/null || echo "PHP error log not found"
            ;;
        5)
            echo -e "\n${YELLOW}=== System Log (last 50 lines) ===${NC}\n"
            tail -n 50 /var/log/syslog
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
}

# ===================== Live Log Monitor =====================
live_log_monitor() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|              LIVE LOG MONITOR                    |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    echo -e "${GREEN}Select log to monitor (real-time):${NC}\n"
    echo -e "  1. Apache Error Log"
    echo -e "  2. Apache Access Log"
    echo -e "  3. All Apache Logs (error + access)"
    echo -e "  4. Mirza Manager Log"
    echo -e "  5. PHP Error Log"
    echo -e "  6. System Log"
    echo -e "  7. Bot Requests (filter access log)"
    echo -e "  0. Back to menu\n"
    
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}\n"
    
    read -p "Select option: " monitor_choice
    
    case $monitor_choice in
        1)
            echo -e "\n${CYAN}=== Live Apache Error Log ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            tail -f /var/log/apache2/mirza_error.log 2>/dev/null || tail -f /var/log/apache2/error.log
            ;;
        2)
            echo -e "\n${CYAN}=== Live Apache Access Log ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            tail -f /var/log/apache2/mirza_access.log 2>/dev/null || tail -f /var/log/apache2/access.log
            ;;
        3)
            echo -e "\n${CYAN}=== Live All Apache Logs ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            tail -f /var/log/apache2/mirza_error.log /var/log/apache2/mirza_access.log 2>/dev/null || \
            tail -f /var/log/apache2/error.log /var/log/apache2/access.log
            ;;
        4)
            echo -e "\n${CYAN}=== Live Mirza Manager Log ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            if [[ -f "$LOG_FILE" ]]; then
                tail -f "$LOG_FILE"
            else
                echo "Manager log not found. Creating..."
                touch "$LOG_FILE"
                tail -f "$LOG_FILE"
            fi
            ;;
        5)
            echo -e "\n${CYAN}=== Live PHP Error Log ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            local php_log=$(find /var/log -name "*php*error*" 2>/dev/null | head -1)
            if [[ -n "$php_log" ]]; then
                tail -f "$php_log"
            else
                echo "PHP error log not found"
            fi
            ;;
        6)
            echo -e "\n${CYAN}=== Live System Log ===${NC}"
            echo -e "${YELLOW}Monitoring... (Ctrl+C to stop)${NC}\n"
            tail -f /var/log/syslog
            ;;
        7)
            echo -e "\n${CYAN}=== Live Bot Requests ===${NC}"
            echo -e "${YELLOW}Monitoring POST requests to index.php... (Ctrl+C to stop)${NC}\n"
            tail -f /var/log/apache2/mirza_access.log 2>/dev/null | grep --line-buffered "POST.*index.php" || \
            tail -f /var/log/apache2/access.log | grep --line-buffered "POST.*index.php"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
}

# ===================== Service Status =====================
service_status() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|               SERVICE STATUS                     |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    # Apache
    echo -ne "${WHITE}Apache2:      ${NC}"
    if systemctl is-active --quiet apache2; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    # MariaDB/MySQL
    echo -ne "${WHITE}MariaDB:      ${NC}"
    if systemctl is-active --quiet mariadb; then
        echo -e "${GREEN}Running${NC}"
    elif systemctl is-active --quiet mysql; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    # PHP-FPM
    echo -ne "${WHITE}PHP-FPM:      ${NC}"
    if systemctl is-active --quiet php8.2-fpm 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    elif systemctl is-active --quiet php-fpm 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${YELLOW}Not installed/Using mod_php${NC}"
    fi
    
    # UFW
    echo -ne "${WHITE}UFW Firewall: ${NC}"
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}Active${NC}"
    else
        echo -e "${RED}Inactive${NC}"
    fi
    
    # Mirza Pro Installation
    echo -ne "${WHITE}Mirza Pro:    ${NC}"
    if [[ -d "$MIRZA_PATH" ]] && [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${GREEN}Installed${NC}"
    else
        echo -e "${RED}Not installed${NC}"
    fi
    
    echo -e "\n${YELLOW}-------------------------------------------------${NC}\n"
    
    # Server Resources
    echo -e "${WHITE}Server Resources:${NC}\n"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "  CPU Usage:     ${CYAN}${cpu_usage}%${NC}"
    
    # RAM
    local ram_info=$(free -m | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3/1024, $2/1024, $3*100/$2}')
    echo -e "  RAM Usage:     ${CYAN}${ram_info}${NC}"
    
    # Disk
    local disk_info=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
    echo -e "  Disk Usage:    ${CYAN}${disk_info}${NC}"
    
    # Uptime
    local uptime_info=$(uptime -p)
    echo -e "  Uptime:        ${CYAN}${uptime_info}${NC}"
    
    echo -e "\n${YELLOW}-------------------------------------------------${NC}\n"
    
    # Database Connection Test
    echo -ne "${WHITE}Database Connection: ${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        DB_NAME=$(grep -oP "\\\$dbname\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
        if mysql -e "USE $DB_NAME" 2>/dev/null; then
            echo -e "${GREEN}Connected${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    else
        echo -e "${YELLOW}Config not found${NC}"
    fi
    
    # Webhook Status
    echo -ne "${WHITE}Webhook Status:      ${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        local TOKEN=$(grep -oE "[0-9]+:[A-Za-z0-9_-]{35,}" "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$TOKEN" ]]; then
            local webhook_info=$(curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo")
            if echo "$webhook_info" | grep -q '"url":"https://'; then
                echo -e "${GREEN}Active${NC}"
            else
                echo -e "${RED}Not set${NC}"
            fi
        else
            echo -e "${YELLOW}Token not found${NC}"
        fi
    else
        echo -e "${YELLOW}Config not found${NC}"
    fi
    
    echo ""
}

# ===================== Restart Services =====================
restart_services() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|              RESTART SERVICES                    |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    echo -e "${GREEN}Select service to restart:${NC}\n"
    echo -e "  1. Apache2"
    echo -e "  2. MariaDB/MySQL"
    echo -e "  3. PHP-FPM"
    echo -e "  4. All Services"
    echo -e "  0. Back to menu\n"
    
    read -p "Select option: " service_choice
    
    case $service_choice in
        1)
            echo -e "${YELLOW}Restarting Apache2...${NC}"
            systemctl restart apache2
            if systemctl is-active --quiet apache2; then
                echo -e "${GREEN}Apache2 restarted successfully${NC}"
                log_message "Apache2 restarted"
            else
                echo -e "${RED}Apache2 failed to start!${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}Restarting MariaDB...${NC}"
            systemctl restart mariadb 2>/dev/null || systemctl restart mysql
            if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql; then
                echo -e "${GREEN}MariaDB restarted successfully${NC}"
                log_message "MariaDB restarted"
            else
                echo -e "${RED}MariaDB failed to start!${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}Restarting PHP-FPM...${NC}"
            systemctl restart php8.2-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null
            echo -e "${GREEN}PHP-FPM restart attempted${NC}"
            log_message "PHP-FPM restarted"
            ;;
        4)
            echo -e "${YELLOW}Restarting all services...${NC}"
            systemctl restart apache2
            systemctl restart mariadb 2>/dev/null || systemctl restart mysql
            systemctl restart php8.2-fpm 2>/dev/null
            echo -e "${GREEN}All services restarted${NC}"
            log_message "All services restarted"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
}

# ===================== Change Bot Settings =====================
change_bot_settings() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|             CHANGE BOT SETTINGS                  |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Config file not found!${NC}"
        return 1
    fi
    
    # Show current settings
    echo -e "${YELLOW}Current Settings:${NC}\n"
    
    local current_token=$(grep -oP "\\\$APIKEY\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
    local current_admin=$(grep -oP "\\\$adminnumber\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
    local current_domain=$(grep -oP "\\\$domainhosts\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
    local current_username=$(grep -oP "\\\$usernamebot\s*=\s*'\K[^']+" "$CONFIG_FILE" 2>/dev/null)
    
    echo -e "  Bot Token:    ${CYAN}${current_token:0:20}...${NC}"
    echo -e "  Admin ID:     ${CYAN}${current_admin}${NC}"
    echo -e "  Domain:       ${CYAN}${current_domain}${NC}"
    echo -e "  Bot Username: ${CYAN}${current_username}${NC}"
    
    echo -e "\n${GREEN}What do you want to change?${NC}\n"
    echo -e "  1. Bot Token"
    echo -e "  2. Admin ID"
    echo -e "  3. Domain"
    echo -e "  4. Bot Username"
    echo -e "  5. Change All"
    echo -e "  0. Back to menu\n"
    
    read -p "Select option: " setting_choice
    
    case $setting_choice in
        1)
            while true; do
                read -p "New Bot Token: " new_token
                if validate_bot_token "$new_token"; then
                    sed -i "s|\$APIKEY\s*=\s*'[^']*'|\$APIKEY = '$new_token'|" "$CONFIG_FILE"
                    echo -e "${GREEN}Token updated${NC}"
                    
                    read -p "Update webhook? (Y/n): " update_webhook
                    if [[ "$update_webhook" != "n" && "$update_webhook" != "N" ]]; then
                        local domain=$(grep -oP "\\\$domainhosts\s*=\s*'\K[^']+" "$CONFIG_FILE" | sed 's|https://||')
                        curl -s "https://api.telegram.org/bot$new_token/setWebhook?url=https://$domain/index.php" | grep -q '"ok":true' && \
                            echo -e "${GREEN}Webhook updated${NC}" || echo -e "${YELLOW}Webhook update failed${NC}"
                    fi
                    break
                else
                    echo -e "${RED}Invalid token format! Try again.${NC}"
                fi
            done
            ;;
        2)
            while true; do
                read -p "New Admin ID: " new_admin
                if validate_admin_id "$new_admin"; then
                    sed -i "s|\$adminnumber\s*=\s*'[^']*'|\$adminnumber = '$new_admin'|" "$CONFIG_FILE"
                    echo -e "${GREEN}Admin ID updated${NC}"
                    break
                else
                    echo -e "${RED}Admin ID must be numeric!${NC}"
                fi
            done
            ;;
        3)
            while true; do
                read -p "New Domain (e.g., bot.example.com): " new_domain
                if validate_domain "$new_domain"; then
                    sed -i "s|\$domainhosts\s*=\s*'[^']*'|\$domainhosts = 'https://$new_domain'|" "$CONFIG_FILE"
                    echo -e "${GREEN}Domain updated${NC}"
                    echo -e "${YELLOW}Note: You may need to update Apache config and SSL certificate${NC}"
                    break
                else
                    echo -e "${RED}Invalid domain format!${NC}"
                fi
            done
            ;;
        4)
            while true; do
                read -p "New Bot Username (without @): " new_username
                if validate_username "$new_username"; then
                    sed -i "s|\$usernamebot\s*=\s*'[^']*'|\$usernamebot = '$new_username'|" "$CONFIG_FILE"
                    echo -e "${GREEN}Username updated${NC}"
                    break
                else
                    echo -e "${RED}Invalid username format!${NC}"
                fi
            done
            ;;
        5)
            echo -e "${YELLOW}Changing all settings...${NC}\n"
            
            while true; do
                read -p "New Bot Token: " new_token
                validate_bot_token "$new_token" && break
                echo -e "${RED}Invalid token!${NC}"
            done
            
            while true; do
                read -p "New Admin ID: " new_admin
                validate_admin_id "$new_admin" && break
                echo -e "${RED}Invalid Admin ID!${NC}"
            done
            
            while true; do
                read -p "New Domain: " new_domain
                validate_domain "$new_domain" && break
                echo -e "${RED}Invalid domain!${NC}"
            done
            
            while true; do
                read -p "New Bot Username: " new_username
                validate_username "$new_username" && break
                echo -e "${RED}Invalid username!${NC}"
            done
            
            sed -i "s|\$APIKEY\s*=\s*'[^']*'|\$APIKEY = '$new_token'|" "$CONFIG_FILE"
            sed -i "s|\$adminnumber\s*=\s*'[^']*'|\$adminnumber = '$new_admin'|" "$CONFIG_FILE"
            sed -i "s|\$domainhosts\s*=\s*'[^']*'|\$domainhosts = 'https://$new_domain'|" "$CONFIG_FILE"
            sed -i "s|\$usernamebot\s*=\s*'[^']*'|\$usernamebot = '$new_username'|" "$CONFIG_FILE"
            
            echo -e "${GREEN}All settings updated${NC}"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            return 1
            ;;
    esac
    
    log_message "Bot settings changed"
    systemctl restart apache2
}

# ===================== Webhook Status =====================
webhook_status() {
    mirza_logo
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|               WEBHOOK STATUS                     |${NC}"
    echo -e "${CYAN}+==================================================+${NC}\n"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Config file not found!${NC}"
        return 1
    fi
    
    local TOKEN=$(grep -oE "[0-9]+:[A-Za-z0-9_-]{35,}" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$TOKEN" ]]; then
        echo -e "${RED}Bot token not found in config!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Fetching webhook info...${NC}\n"
    
    local webhook_info=$(curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo")
    
    local url=$(echo "$webhook_info" | grep -oP '"url":"\K[^"]+')
    local pending=$(echo "$webhook_info" | grep -oP '"pending_update_count":\K[0-9]+')
    local last_error=$(echo "$webhook_info" | grep -oP '"last_error_message":"\K[^"]+')
    local last_error_date=$(echo "$webhook_info" | grep -oP '"last_error_date":\K[0-9]+')
    
    echo -e "${WHITE}Webhook URL:      ${NC}${CYAN}${url:-Not set}${NC}"
    echo -e "${WHITE}Pending Updates:  ${NC}${CYAN}${pending:-0}${NC}"
    
    if [[ -n "$last_error" ]]; then
        echo -e "${WHITE}Last Error:       ${NC}${RED}${last_error}${NC}"
        if [[ -n "$last_error_date" ]]; then
            local error_date=$(date -d "@$last_error_date" '+%Y-%m-%d %H:%M:%S')
            echo -e "${WHITE}Error Date:       ${NC}${RED}${error_date}${NC}"
        fi
    else
        echo -e "${WHITE}Last Error:       ${NC}${GREEN}None${NC}"
    fi
    
    echo -e "\n${GREEN}Options:${NC}\n"
    echo -e "  1. Reset Webhook"
    echo -e "  2. Delete Webhook"
    echo -e "  3. Test Bot Connection"
    echo -e "  0. Back to menu\n"
    
    read -p "Select option: " webhook_choice
    
    case $webhook_choice in
        1)
            local domain=$(grep -oP "\\\$domainhosts\s*=\s*'\K[^']+" "$CONFIG_FILE" | sed 's|https://||')
            echo -e "${YELLOW}Setting webhook...${NC}"
            local result=$(curl -s "https://api.telegram.org/bot$TOKEN/setWebhook?url=https://$domain/index.php")
            if echo "$result" | grep -q '"ok":true'; then
                echo -e "${GREEN}Webhook set successfully${NC}"
            else
                echo -e "${RED}Failed to set webhook${NC}"
                echo "$result"
            fi
            ;;
        2)
            echo -e "${YELLOW}Deleting webhook...${NC}"
            local result=$(curl -s "https://api.telegram.org/bot$TOKEN/deleteWebhook")
            if echo "$result" | grep -q '"ok":true'; then
                echo -e "${GREEN}Webhook deleted${NC}"
            else
                echo -e "${RED}Failed to delete webhook${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}Testing bot connection...${NC}"
            local result=$(curl -s "https://api.telegram.org/bot$TOKEN/getMe")
            if echo "$result" | grep -q '"ok":true'; then
                local bot_name=$(echo "$result" | grep -oP '"first_name":"\K[^"]+')
                local bot_username=$(echo "$result" | grep -oP '"username":"\K[^"]+')
                echo -e "${GREEN}Bot is working!${NC}"
                echo -e "${WHITE}Name: ${CYAN}$bot_name${NC}"
                echo -e "${WHITE}Username: ${CYAN}@$bot_username${NC}"
            else
                echo -e "${RED}Bot connection failed!${NC}"
                echo "$result"
            fi
            ;;
        0)
            return 0
            ;;
    esac
}

# ===================== Main Menu =====================
main_menu() {
    while true; do
        mirza_logo
        echo -e "${YELLOW}       Mirza Pro Manager - Enhanced Edition${NC}\n"
        
        echo -e "${GREEN}+==================================================+${NC}"
        echo -e "${WHITE}|  ${GREEN}1.${NC}  Install Mirza Pro                         |${NC}"
        echo -e "${WHITE}|  ${RED}2.${NC}  Delete Mirza Pro                          |${NC}"
        echo -e "${WHITE}|  ${CYAN}3.${NC}  Update Mirza Pro                          |${NC}"
        echo -e "${WHITE}|  ${YELLOW}4.${NC}  Backup Mirza Pro                          |${NC}"
        echo -e "${WHITE}|  ${YELLOW}5.${NC}  Restore Backup                            |${NC}"
        echo -e "${WHITE}|  ${BLUE}6.${NC}  View Logs                                 |${NC}"
        echo -e "${WHITE}|  ${BLUE}7.${NC}  Live Log Monitor                          |${NC}"
        echo -e "${WHITE}|  ${BLUE}8.${NC}  Service Status                            |${NC}"
        echo -e "${WHITE}|  ${BLUE}9.${NC}  Restart Services                          |${NC}"
        echo -e "${WHITE}|  ${CYAN}10.${NC} Change Bot Settings                       |${NC}"
        echo -e "${WHITE}|  ${CYAN}11.${NC} Webhook Status                            |${NC}"
        echo -e "${WHITE}|  ${YELLOW}12.${NC} Edit config.php                           |${NC}"
        echo -e "${RED}|  0.  Exit                                      |${NC}"
        echo -e "${GREEN}+==================================================+${NC}\n"
        
        read -p "Choose an option (0-12): " choice

        case $choice in
            1) install_mirza ;;
            2) delete_mirza ;;
            3) update_mirza ;;
            4) backup_mirza ;;
            5) restore_backup ;;
            6) view_logs ;;
            7) live_log_monitor ;;
            8) service_status ;;
            9) restart_services ;;
            10) change_bot_settings ;;
            11) webhook_status ;;
            12) 
                if [[ -f "$CONFIG_FILE" ]]; then
                    nano "$CONFIG_FILE"
                    systemctl restart apache2
                else
                    echo -e "${RED}Config file not found!${NC}"
                fi
                ;;
            0) 
                mirza_logo
                echo -e "${YELLOW}Goodbye!${NC}\n"
                log_message "Manager exited"
                exit 0 
                ;;
            *) 
                echo -e "${RED}Please choose a number between 0 and 12!${NC}"
                sleep 1 
                ;;
        esac
        
        echo ""
        read -p "Press Enter to return to menu..." dummy
    done
}

# ===================== Start =====================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${NC}"
    exit 1
fi

mkdir -p "$BACKUP_PATH"

log_message "========== Manager Started =========="

main_menu
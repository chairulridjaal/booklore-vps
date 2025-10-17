#!/bin/bash

#############################################
# 📚 BookLore Auto Installer Script
# Self-Hosted BookLore on VPS with Docker
#############################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════╗
║                                              ║
║      📚 BookLore Auto Installer 📚          ║
║   Self-Hosted E-Book Manager with Docker    ║
║                                              ║
╚══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
INSTALL_DIR="${HOME}/booklore"
DB_PASSWORD="booklore_secure_$(date +%s)"
ROOT_PASSWORD="root_secure_$(date +%s)"
TIMEZONE="Asia/Jakarta"
BOOKLORE_PORT="6060"

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}📋 Konfigurasi Instalasi:${NC}"
echo -e "   📁 Direktori: ${INSTALL_DIR}"
echo -e "   🔐 Database Password: ${DB_PASSWORD}"
echo -e "   🌍 Timezone: ${TIMEZONE}"
echo -e "   🔌 Port: ${BOOKLORE_PORT}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Ask for confirmation
read -p "$(echo -e ${GREEN}Lanjutkan instalasi? [Y/n]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo -e "${RED}❌ Instalasi dibatalkan${NC}"
    exit 1
fi

# Step 1: Update system
echo -e "\n${BLUE}[1/6]${NC} ${GREEN}🔄 Update sistem...${NC}"
sudo apt update -qq && sudo apt upgrade -y -qq

# Step 2: Install Docker
echo -e "\n${BLUE}[2/6]${NC} ${GREEN}🐳 Menginstall Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker berhasil diinstall${NC}"
else
    echo -e "${YELLOW}⚠️  Docker sudah terinstall, skip...${NC}"
fi

# Step 3: Install Docker Compose
echo -e "\n${BLUE}[3/6]${NC} ${GREEN}🔧 Menginstall Docker Compose plugin...${NC}"
if ! docker compose version &> /dev/null; then
    sudo apt install docker-compose-plugin -y -qq
    echo -e "${GREEN}✅ Docker Compose berhasil diinstall${NC}"
else
    echo -e "${YELLOW}⚠️  Docker Compose sudah terinstall, skip...${NC}"
fi

# Step 4: Create project directory
echo -e "\n${BLUE}[4/6]${NC} ${GREEN}📁 Membuat direktori project...${NC}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Create subdirectories
mkdir -p data books bookdrop mariadb

# Step 5: Create docker-compose.yml
echo -e "\n${BLUE}[5/6]${NC} ${GREEN}📝 Membuat file docker-compose.yml...${NC}"
cat > "${INSTALL_DIR}/docker-compose.yml" << EOF
services:
  booklore:
    image: booklore/booklore:latest
    container_name: booklore
    environment:
      - TZ=${TIMEZONE}
      - DATABASE_URL=jdbc:mariadb://mariadb:3306/booklore
      - DATABASE_USERNAME=booklore
      - DATABASE_PASSWORD=${DB_PASSWORD}
      - BOOKLORE_PORT=${BOOKLORE_PORT}
    depends_on:
      mariadb:
        condition: service_healthy
    ports:
      - "${BOOKLORE_PORT}:${BOOKLORE_PORT}"
    volumes:
      - ./data:/app/data
      - ./books:/books
      - ./bookdrop:/bookdrop
    restart: unless-stopped

  mariadb:
    image: lscr.io/linuxserver/mariadb:11.4.5
    container_name: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=${ROOT_PASSWORD}
      - MYSQL_DATABASE=booklore
      - MYSQL_USER=booklore
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - ./mariadb:/config
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mariadb-admin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 10
EOF

echo -e "${GREEN}✅ File docker-compose.yml berhasil dibuat${NC}"

# Save credentials
cat > "${INSTALL_DIR}/.env" << EOF
# BookLore Credentials
# Generated on: $(date)

DATABASE_PASSWORD=${DB_PASSWORD}
ROOT_PASSWORD=${ROOT_PASSWORD}
TIMEZONE=${TIMEZONE}
BOOKLORE_PORT=${BOOKLORE_PORT}
EOF

chmod 600 "${INSTALL_DIR}/.env"

# Step 6: Start containers
echo -e "\n${BLUE}[6/6]${NC} ${GREEN}🚀 Menjalankan BookLore...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "\n${YELLOW}⏳ Menunggu services siap...${NC}"
sleep 10

# Check if containers are running
if docker ps | grep -q booklore && docker ps | grep -q mariadb; then
    echo -e "\n${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                              ║${NC}"
    echo -e "${GREEN}║    ✅ BookLore berhasil diinstall! 🎉       ║${NC}"
    echo -e "${GREEN}║                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo -e "\n${BLUE}📍 Akses aplikasi di:${NC}"
    echo -e "   🌐 http://localhost:${BOOKLORE_PORT}"
    
    # Try to get public IP
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
    if [ ! -z "$PUBLIC_IP" ]; then
        echo -e "   🌐 http://${PUBLIC_IP}:${BOOKLORE_PORT}"
    fi
    
    echo -e "\n${BLUE}📁 Lokasi instalasi:${NC} ${INSTALL_DIR}"
    echo -e "${BLUE}🔐 Kredensial tersimpan di:${NC} ${INSTALL_DIR}/.env"
    
    echo -e "\n${YELLOW}📝 Command berguna:${NC}"
    echo -e "   • Cek status: ${GREEN}docker ps${NC}"
    echo -e "   • Lihat logs: ${GREEN}docker compose logs -f${NC}"
    echo -e "   • Stop: ${GREEN}docker compose stop${NC}"
    echo -e "   • Start: ${GREEN}docker compose start${NC}"
    echo -e "   • Restart: ${GREEN}docker compose restart${NC}"
    echo -e "   • Uninstall: ${GREEN}docker compose down -v${NC}"
    
else
    echo -e "\n${RED}❌ Ada error saat menjalankan container${NC}"
    echo -e "${YELLOW}Cek logs dengan: docker compose logs${NC}"
    exit 1
fi

echo -e "\n${GREEN}✨ Selamat menggunakan BookLore! ✨${NC}\n"

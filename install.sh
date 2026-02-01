#!/bin/bash
#
# WallPimp Installation Script
# Installs wallpaper manager, slideshow daemon, and systemd services
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  WALLPIMP INSTALLER                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_pm() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
PM=$(detect_pm)

echo -e "${GREEN}Distribution: ${YELLOW}$DISTRO${NC}"
echo -e "${GREEN}Package Manager: ${YELLOW}$PM${NC}"

install_dependencies() {
    echo -e "\n${CYAN}Installing dependencies...${NC}"
    
    case $PM in
        pacman)
            echo -e "${YELLOW}Using pacman (Arch Linux)${NC}"
            sudo pacman -S --needed --noconfirm \
                python python-pip \
                python-requests python-tqdm python-pillow python-colorama \
                gcc make \
                feh \
                xfce4-settings xfconf || true
            
            sudo pacman -S --needed --noconfirm \
                nitrogen imagemagick ffmpeg || true
            ;;
            
        apt)
            echo -e "${YELLOW}Using apt (Debian/Ubuntu)${NC}"
            sudo apt update
            sudo apt install -y \
                python3 python3-pip \
                python3-requests python3-tqdm python3-pil python3-colorama \
                gcc make feh nitrogen imagemagick ffmpeg || true
            ;;
            
        dnf)
            echo -e "${YELLOW}Using dnf (Fedora)${NC}"
            sudo dnf install -y \
                python3 python3-pip \
                python3-requests python3-tqdm python3-pillow python3-colorama \
                gcc make feh nitrogen ImageMagick ffmpeg || true
            ;;
            
        zypper)
            echo -e "${YELLOW}Using zypper (openSUSE)${NC}"
            sudo zypper install -y \
                python3 python3-pip \
                python3-requests python3-tqdm python3-Pillow python3-colorama \
                gcc make feh nitrogen ImageMagick ffmpeg || true
            ;;
            
        *)
            echo -e "${RED}Unknown package manager${NC}"
            echo "Install: python3, pip, requests, tqdm, Pillow, colorama, gcc, make, feh"
            read -p "Press Enter to continue..."
            ;;
    esac
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

compile_daemon() {
    echo -e "\n${CYAN}Compiling slideshow daemon...${NC}"
    
    if [ ! -f "wallpimp_daemon.c" ]; then
        echo -e "${RED}Error: wallpimp_daemon.c not found${NC}"
        exit 1
    fi
    
    gcc -O2 -Wall -o wallpimp_daemon wallpimp_daemon.c
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Daemon compiled${NC}"
    else
        echo -e "${RED}Compilation failed${NC}"
        exit 1
    fi
}

install_files() {
    echo -e "\n${CYAN}Installing files...${NC}"
    
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.config/systemd/user"
    mkdir -p "$HOME/.config/wallpimp"
    mkdir -p "$HOME/Pictures/Wallpapers"
    
    if [ -f "wallpimp.py" ]; then
        cp wallpimp.py "$HOME/.local/bin/wallpimp"
        chmod +x "$HOME/.local/bin/wallpimp"
        echo -e "${GREEN}✓ Installed wallpimp${NC}"
    else
        echo -e "${RED}Error: wallpimp.py not found${NC}"
        exit 1
    fi
    
    if [ -f "wallpimp_daemon" ]; then
        cp wallpimp_daemon "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/wallpimp_daemon"
        echo -e "${GREEN}✓ Installed daemon${NC}"
    else
        echo -e "${RED}Error: wallpimp_daemon not found${NC}"
        exit 1
    fi
    
    if [ -f "wallpimp-slideshow.service" ]; then
        cp wallpimp-slideshow.service "$HOME/.config/systemd/user/"
        echo -e "${GREEN}✓ Installed service${NC}"
    fi
    
    if [ -f "wallpimp-slideshow.timer" ]; then
        cp wallpimp-slideshow.timer "$HOME/.config/systemd/user/"
        echo -e "${GREEN}✓ Installed timer${NC}"
    fi
    
    systemctl --user daemon-reload
    echo -e "${GREEN}✓ Systemd reloaded${NC}"
}

setup_path() {
    echo -e "\n${CYAN}Setting up PATH...${NC}"
    
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        if [ -f "$HOME/.bashrc" ]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            echo -e "${GREEN}✓ Added to .bashrc${NC}"
        fi
        
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
            echo -e "${GREEN}✓ Added to .zshrc${NC}"
        fi
        
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo -e "${GREEN}✓ PATH configured${NC}"
    fi
}

post_install() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              INSTALLATION COMPLETE!                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CYAN}Quick Start:${NC}"
    echo -e "  1. Run: ${YELLOW}source ~/.bashrc${NC} or open new terminal"
    echo -e "  2. Run: ${YELLOW}wallpimp${NC}"
    echo -e "  3. Download wallpapers from Downloads menu"
    echo -e "  4. Start slideshow from Slideshow Control menu"
    
    echo -e "\n${CYAN}Manual Control:${NC}"
    echo -e "  ${YELLOW}systemctl --user start wallpimp-slideshow.timer${NC}"
    echo -e "  ${YELLOW}systemctl --user enable wallpimp-slideshow.timer${NC}"
    
    echo -e "\n${GREEN}Enjoy WallPimp! 🎨${NC}"
}

main() {
    install_dependencies
    compile_daemon
    install_files
    setup_path
    post_install
}

main

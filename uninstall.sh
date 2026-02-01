#!/bin/bash
#
# WallPimp Uninstaller
#

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                  WALLPIMP UNINSTALLER                        ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}This will remove WallPimp from your system.${NC}"
echo -e "${YELLOW}Wallpaper files will NOT be deleted.${NC}\n"

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Uninstall cancelled${NC}"
    exit 0
fi

echo -e "\n${CYAN}Stopping and disabling services...${NC}"
systemctl --user stop wallpimp-slideshow.timer 2>/dev/null || true
systemctl --user stop wallpimp-slideshow.service 2>/dev/null || true
systemctl --user disable wallpimp-slideshow.timer 2>/dev/null || true
systemctl --user disable wallpimp-slideshow.service 2>/dev/null || true
echo -e "${GREEN}✓ Services stopped${NC}"

echo -e "\n${CYAN}Removing files...${NC}"

# Remove binaries
rm -f "$HOME/.local/bin/wallpimp"
rm -f "$HOME/.local/bin/wallpimp_daemon"
echo -e "${GREEN}✓ Removed binaries${NC}"

# Remove systemd files
rm -f "$HOME/.config/systemd/user/wallpimp-slideshow.service"
rm -f "$HOME/.config/systemd/user/wallpimp-slideshow.timer"
systemctl --user daemon-reload
echo -e "${GREEN}✓ Removed systemd services${NC}"

# Ask about config
echo -e "\n${YELLOW}Remove configuration? (wallpapers will be kept)${NC}"
read -p "Remove config? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.config/wallpimp"
    echo -e "${GREEN}✓ Configuration removed${NC}"
else
    echo -e "${YELLOW}Configuration kept in ~/.config/wallpimp${NC}"
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 UNINSTALL COMPLETE                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${CYAN}Your wallpapers are still in:${NC}"
echo -e "${YELLOW}~/Pictures/Wallpapers${NC} (or your custom directory)"

echo -e "\n${CYAN}To fully remove everything including wallpapers:${NC}"
echo -e "${YELLOW}rm -rf ~/Pictures/Wallpapers${NC}"
echo -e "${YELLOW}rm -rf ~/.config/wallpimp${NC}"

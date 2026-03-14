#!/bin/bash

###############################################################################
# install.sh
#
# Installer for DataCenter Log Manager.
# - Copies the main script to ~/.local/bin/
# - Creates a .desktop launcher on the desktop and in the app menu
# - Installs a custom icon
# - Verifies required dependencies
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# To uninstall:
#   ./install.sh --uninstall
###############################################################################

set -euo pipefail

# --- Paths ---
APP_NAME="DataCenter Log Manager"
APP_BINARY="datacenter_log_manager.sh"
INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="dclogmanager.desktop"
DESKTOP_SHORTCUT="$HOME/Desktop/$DESKTOP_FILE"
ICON_NAME="dclogmanager"
ICON_FILE="$ICON_DIR/$ICON_NAME.png"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}  →${NC} $1"; }
success() { echo -e "${GREEN}  ✔${NC} $1"; }
warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
error()   { echo -e "${RED}  ✘${NC} $1"; }


###############################################################################
# UNINSTALL
###############################################################################

uninstall() {
    echo ""
    echo "Uninstalling $APP_NAME..."

    rm -f "$INSTALL_DIR/$APP_BINARY"        && success "Removed $INSTALL_DIR/$APP_BINARY"
    rm -f "$DESKTOP_DIR/$DESKTOP_FILE"      && success "Removed app menu entry"
    rm -f "$DESKTOP_SHORTCUT"               && success "Removed desktop shortcut"
    rm -f "$ICON_FILE"                      && success "Removed icon"

    # Update desktop database
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

    echo ""
    success "Uninstall complete."
    echo ""
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
    exit 0
fi


###############################################################################
# DEPENDENCY CHECK
###############################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   DataCenter Log Manager — Installer     ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
info "Checking dependencies..."

MISSING=()
for dep in zenity curl ssh ping tar systemctl; do
    if command -v "$dep" &>/dev/null; then
        success "$dep found"
    else
        error  "$dep NOT found"
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    warning "Missing dependencies: ${MISSING[*]}"
    echo ""
    echo    "  Install them with:"
    echo -e "  ${YELLOW}sudo dnf install ${MISSING[*]}${NC}"
    echo ""
    read -rp "  Continue installation anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi


###############################################################################
# VERIFY SOURCE FILES
###############################################################################

echo ""
info "Verifying source files..."

if [ ! -f "$APP_BINARY" ]; then
    error "Cannot find '$APP_BINARY' in the current directory."
    error "Run this installer from the project root folder."
    exit 1
fi
success "$APP_BINARY found"


###############################################################################
# CREATE DIRECTORIES
###############################################################################

echo ""
info "Creating installation directories..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DESKTOP_DIR"
success "Directories ready"


###############################################################################
# INSTALL ICON
# Generates a simple SVG icon and converts to PNG if ImageMagick is available.
# Falls back to a basic terminal icon from the system theme if not.
###############################################################################

echo ""
info "Installing icon..."

# Create a simple SVG icon
SVG_ICON="/tmp/${ICON_NAME}.svg"
cat > "$SVG_ICON" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Background -->
  <rect width="64" height="64" rx="10" fill="#1e2a3a"/>
  <!-- Server rack body -->
  <rect x="12" y="10" width="40" height="44" rx="3" fill="#2c3e50"/>
  <!-- Rack units -->
  <rect x="15" y="14" width="34" height="7" rx="2" fill="#27ae60"/>
  <rect x="15" y="24" width="34" height="7" rx="2" fill="#2980b9"/>
  <rect x="15" y="34" width="34" height="7" rx="2" fill="#2980b9"/>
  <rect x="15" y="44" width="34" height="7" rx="2" fill="#e67e22"/>
  <!-- LED dots -->
  <circle cx="44" cy="17.5" r="2" fill="#2ecc71"/>
  <circle cx="44" cy="27.5" r="2" fill="#2ecc71"/>
  <circle cx="44" cy="37.5" r="2" fill="#e74c3c"/>
  <circle cx="44" cy="47.5" r="2" fill="#f39c12"/>
</svg>
SVGEOF

# Try to convert SVG to PNG using ImageMagick or rsvg-convert
if command -v convert &>/dev/null; then
    convert -background none "$SVG_ICON" "$ICON_FILE" 2>/dev/null \
        && success "Icon installed (ImageMagick)" \
        || warning "Icon conversion failed — using system fallback"
elif command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 64 -h 64 "$SVG_ICON" -o "$ICON_FILE" 2>/dev/null \
        && success "Icon installed (rsvg-convert)" \
        || warning "Icon conversion failed — using system fallback"
else
    # No converter available — copy SVG directly (some DEs support SVG icons)
    cp "$SVG_ICON" "${ICON_FILE%.png}.svg"
    ICON_FILE="${ICON_FILE%.png}.svg"
    warning "No image converter found. Using SVG icon directly."
    info "For a better icon, install: sudo dnf install librsvg2-tools"
fi

rm -f "$SVG_ICON"


###############################################################################
# INSTALL SCRIPT
###############################################################################

echo ""
info "Installing script to $INSTALL_DIR..."

cp "$APP_BINARY" "$INSTALL_DIR/$APP_BINARY"
chmod +x "$INSTALL_DIR/$APP_BINARY"
success "Script installed"

# Add ~/.local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warning "~/.local/bin is not in your PATH"
    info "Adding it to ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    success "Added to ~/.bashrc (restart terminal or run: source ~/.bashrc)"
fi


###############################################################################
# CREATE .desktop FILE
###############################################################################

echo ""
info "Creating desktop launcher..."

DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=GUI tool for data center log management and node monitoring
Exec=$INSTALL_DIR/$APP_BINARY
Icon=$ICON_FILE
Terminal=false
Categories=System;Monitor;Network;
Keywords=log;datacenter;server;node;ssh;ftp;monitoring;
StartupNotify=true"

# Install in app menu (~/.local/share/applications)
echo "$DESKTOP_CONTENT" > "$DESKTOP_DIR/$DESKTOP_FILE"
chmod 644 "$DESKTOP_DIR/$DESKTOP_FILE"
success "App menu entry created"

# Install on Desktop
if [ -d "$HOME/Desktop" ]; then
    echo "$DESKTOP_CONTENT" > "$DESKTOP_SHORTCUT"
    chmod +x "$DESKTOP_SHORTCUT"

    # GNOME requires marking the .desktop as trusted to allow double-click launch
    if command -v gio &>/dev/null; then
        gio set "$DESKTOP_SHORTCUT" metadata::trusted true 2>/dev/null \
            && success "Desktop shortcut created and marked as trusted" \
            || warning "Desktop shortcut created — you may need to right-click → Allow Launching"
    else
        success "Desktop shortcut created"
        warning "Right-click the icon → 'Allow Launching' to enable double-click"
    fi
else
    warning "~/Desktop not found — skipping desktop shortcut"
fi

# Refresh GNOME app menu
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true


###############################################################################
# DONE
###############################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Installation complete!                 ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  You can now launch the app:"
echo ""
echo -e "  ${CYAN}1.${NC} Double-click the icon on your Desktop"
echo -e "  ${CYAN}2.${NC} Search 'DataCenter' in the GNOME app menu"
echo -e "  ${CYAN}3.${NC} Run from terminal: ${YELLOW}datacenter_log_manager.sh${NC}"
echo ""
echo "  To uninstall:"
echo -e "  ${YELLOW}./install.sh --uninstall${NC}"
echo ""
#!/bin/bash

# Function to validate hex color input
validate_hex_color() {
    local color="$1"
    if [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        return 0
    elif [[ "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        color="#$color"
        echo "$color"
        return 0
    else
        echo "Invalid hex color: $color" >&2
        return 1
    fi
}

# Function to calculate foreground color (white or black)
calculate_foreground_color() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    local lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
    
    if [ $lum -gt 128 ]; then
        echo "#000000"
    else
        echo "#ffffff"
    fi
}

# Function to calculate darker color
calculate_darker_color() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Darken by 10%
    r=$((r * 90 / 100))
    g=$((g * 90 / 100))
    b=$((b * 90 / 100))
    
    printf "#%02x%02x%02x\n" $r $g $b
}

# Function to change accent color in GNOME Shell CSS files
change_shell_accent() {
    local css_file="$1"
    local new_accent="$2"
    
    if [ ! -f "$css_file" ]; then
        echo "Warning: CSS file not found: $css_file"
        return 1
    fi
    
    local fg_color=$(calculate_foreground_color "$new_accent")
    
    # Replace accent color variables
    sed -i "s/-st-accent-color/${new_accent}/g" "$css_file"
    sed -i "s/-st-accent-fg-color/${fg_color}/g" "$css_file"
    
    echo "  Updated: $(basename "$css_file")"
}

# Function to extract Adwaita theme
extract_adwaita_theme() {
    echo "Extracting Adwaita GNOME Shell theme..."
    
    # Define theme paths
    LIGHT_TARGET="$HOME/.themes/Adwaita-shell-custom-light/gnome-shell"
    DARK_TARGET="$HOME/.themes/Adwaita-shell-custom-dark/gnome-shell"
    
    # Clean existing directories
    rm -rf "$HOME/.themes/Adwaita-shell-custom-light" "$HOME/.themes/Adwaita-shell-custom-dark"
    
    # Create directories
    mkdir -p "$LIGHT_TARGET" "$DARK_TARGET"
    
    # Extract SVG files and CSS variants once
    TEMP_DIR=$(mktemp -d)
    for resource in $(gresource list /usr/share/gnome-shell/gnome-shell-theme.gresource); do
        filename="${resource#/org/gnome/shell/theme/}"
        mkdir -p "$TEMP_DIR/$(dirname "$filename")"
        gresource extract /usr/share/gnome-shell/gnome-shell-theme.gresource \
            "$resource" > "$TEMP_DIR/$filename" 2>/dev/null
    done
    
    # Copy all SVG and CSS files (except the variant files we're renaming)
    for file in "$TEMP_DIR"/*; do
        basefile=$(basename "$file")
        
        # Skip the main CSS variant files (we'll handle these separately)
        if [[ "$basefile" != "gnome-shell-light.css" ]] && \
           [[ "$basefile" != "gnome-shell-dark.css" ]]; then
            cp "$file" "$LIGHT_TARGET/"
            cp "$file" "$DARK_TARGET/"
        fi
    done
    
    # Create the main CSS files by renaming variants
    cp "$TEMP_DIR/gnome-shell-light.css" "$LIGHT_TARGET/gnome-shell.css"
    cp "$TEMP_DIR/gnome-shell-dark.css" "$DARK_TARGET/gnome-shell.css"
    
    # Clean up temp
    rm -rf "$TEMP_DIR"
    
    echo "Theme extracted to:"
    echo "  Light: $HOME/.themes/Adwaita-shell-custom-light/"
    echo "  Dark:  $HOME/.themes/Adwaita-shell-custom-dark/"
}

# Function to apply accent color to GTK themes
apply_gtk_accent() {
    local accent_color="$1"
    local gtk3_file="$HOME/.config/gtk-3.0/gtk.css"
    local gtk4_file="$HOME/.config/gtk-4.0/gtk.css"
    local darker_accent=$(calculate_darker_color "$accent_color")
    
    echo "Applying accent color to GTK themes..."
    
    # Ensure gsettings command exists
    command -v gsettings >/dev/null || { echo "Error: gsettings not found."; exit 1; }
    
    # Set accent color in GNOME settings
    echo "  Setting GNOME accent color via gsettings..."
    gsettings set org.gnome.desktop.interface accent-color "$accent_color"
    
    # Create GTK4 CSS directory and file
    mkdir -p "$(dirname "$gtk4_file")"
    cat <<EOF > "$gtk4_file"
:root {
  --accent-custom: $accent_color;
  --accent-bg-color: var(--accent-custom);
}

@define-color accent_color $accent_color;
@define-color accent_bg_color $accent_color;

/* Apply accent color to suggested buttons */
button.suggested-action {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
  border: none;
}

button.suggested-action:hover {
  background-color: $darker_accent;
}

button.suggested-action:active {
  background-color: $darker_accent;
}

/* Progress bars */
progressbar progress {
  background-color: $accent_color;
}

/* Checkboxes and radio buttons only - switches keep default colors */
checkbutton check:checked,
radiobutton radio:checked {
  background-color: $accent_color;
}

/* Primary toolbuttons (like in header bars) */
button.primary:not(.suggested-action):not(.destructive-action) {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
  border: none;
}

button.primary:not(.suggested-action):not(.destructive-action):hover {
  background-color: $darker_accent;
}

/* Accent colored text */
.accent,
label.accent {
  color: $accent_color;
}

EOF
    
    # Create GTK3 CSS directory and file
    mkdir -p "$(dirname "$gtk3_file")"
    cat <<EOF > "$gtk3_file"
@define-color accent_custom $accent_color;
@define-color accent_bg_color $accent_color;

/* Apply accent color to suggested buttons */
button.suggested-action {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
  border: none;
}

button.suggested-action:hover {
  background-color: $darker_accent;
}

button.suggested-action:active {
  background-color: $darker_accent;
}

/* Progress bars */
progressbar progress {
  background-color: $accent_color;
}

/* Checkboxes and radio buttons only - switches keep default colors */
checkbutton check:checked,
radiobutton radio:checked {
  background-color: $accent_color;
}

/* Primary toolbuttons (like in header bars) */
button.primary:not(.suggested-action):not(.destructive-action) {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
  border: none;
}

button.primary:not(.suggested-action):not(.destructive-action):hover {
  background-color: $darker_accent;
}

/* Accent colored text */
.accent,
label.accent {
  color: $accent_color;
}

EOF
    
    echo "GTK theme files created:"
    echo "  $gtk3_file"
    echo "  $gtk4_file"
}

# Function to create desktop icons extension CSS override
create_desktop_icons_css() {
    local accent_color="$1"
    local fg_color=$(calculate_foreground_color "$accent_color")
    local css_file="$HOME/.config/com.desktop.ding/stylesheet-override.css"
    
    echo "Creating Desktop Icons extension CSS override..."
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$css_file")"
    
    # Create the CSS file
    cat <<EOF > "$css_file"
/* Minimal: only change colors — nothing else */

/* Primary accent the extension references */
@define-color theme_selected_accent_color $accent_color;

/* Common named selection colors (cover GTK/Adwaita and many apps) */
@define-color theme_selected_bg_color    $accent_color;
@define-color theme_selected_fg_color    $fg_color;

/* Legacy/alternate names (some themes/apps still use these) */
@define-color selected_bg_color  $accent_color;
@define-color selected_fg_color  $fg_color;

/* Ensure extension-specific names resolve to the theme variables */
@define-color desktop_icons_bg_color @theme_selected_accent_color;
@define-color desktop_icons_fg_color @theme_selected_fg_color;
EOF
    
    echo "  Created: $css_file"
}

# Function to patch desktop icons extension JavaScript
patch_desktop_icons_extension() {
    local accent_color="$1"
    
    # Remove # if present for conversion
    local hex="${accent_color#\#}"
    
    # Convert hex to decimal RGB
    local r_dec=$((0x${hex:0:2}))
    local g_dec=$((0x${hex:2:2}))
    local b_dec=$((0x${hex:4:2}))
    
    # Convert to floats (0-1) with 10 decimal places
    local r=$(echo "scale=10; $r_dec / 255" | bc)
    local g=$(echo "scale=10; $g_dec / 255" | bc)
    local b=$(echo "scale=10; $b_dec / 255" | bc)
    
    EXTDIR="$HOME/.local/share/gnome-shell/extensions/gtk4-ding@smedius.gitlab.com"
    FILE="$EXTDIR/app/desktopGrid.js"
    
    if [ ! -f "$FILE" ]; then
        echo "Warning: Desktop Icons extension not found at: $FILE"
        echo "  Skipping JavaScript patch (extension may not be installed)"
        return 1
    fi
    
    echo "Patching $FILE to use $accent_color for rubberband and drop highlights..."
    
    # Create backup
    backup_file="$FILE.backup.$(date +%s)"
    cp "$FILE" "$backup_file"
    echo "  Created backup: $backup_file"
    
    # Replace direct this.Prefs.selectColor.* occurrences
    sed -i \
        -e "s/red:[[:space:]]*this\.Prefs\.selectColor\.red,/red: ${r},/g" \
        -e "s/green:[[:space:]]*this\.Prefs\.selectColor\.green,/green: ${g},/g" \
        -e "s/blue:[[:space:]]*this\.Prefs\.selectColor\.blue,/blue: ${b},/g" \
        "$FILE"
    
    # Replace inverted occurrences like "1.0 - this.Prefs.selectColor.*"
    sed -i \
        -e "s/red:[[:space:]]*1\.0[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.red,/red: ${r},/g" \
        -e "s/green:[[:space:]]*1\.0[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.green,/green: ${g},/g" \
        -e "s/blue:[[:space:]]*1\.0[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.blue,/blue: ${b},/g" \
        "$FILE"
    
    echo "  Patch applied successfully."
    
    # Try reloading the extension (best-effort)
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading extension (disable/enable)..."
        gnome-extensions disable gtk4-ding@smedius.gitlab.com >/dev/null 2>&1 || true
        sleep 0.25
        gnome-extensions enable gtk4-ding@smedius.gitlab.com >/dev/null 2>&1 || true
        echo "  Reload command sent."
    else
        echo "  Note: 'gnome-extensions' command not found."
        echo "  Please reload the extension manually or restart GNOME Shell."
    fi
    
    echo "  Done. Test rubberband selection and drop/grid highlights — they should now use $accent_color."
}

# Function to set the shell theme to dark variant
set_shell_theme_dark() {
    echo "Setting GNOME Shell theme to dark variant..."
    
    # Check if user-theme extension is enabled
    if command -v gsettings >/dev/null; then
        # Try to set the shell theme to the dark variant
        gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-shell-custom-dark' 2>/dev/null
        
        # Check if the command succeeded
        if [ $? -eq 0 ]; then
            echo "  Shell theme set to Adwaita-shell-custom-dark"
        else
            echo "  Note: Could not set shell theme automatically."
            echo "  You may need to enable the User Themes extension and set it manually."
        fi
    else
        echo "  Note: gsettings not available, cannot set shell theme."
    fi
}

# Function to reset everything
reset_theme() {
    echo "========================================"
    echo "Resetting theme customizations..."
    echo "========================================"
    
    # Remove custom shell themes
    echo "Removing custom shell themes..."
    rm -rf "$HOME/.themes/Adwaita-shell-custom-light" 2>/dev/null
    rm -rf "$HOME/.themes/Adwaita-shell-custom-dark" 2>/dev/null
    
    # Remove GTK CSS files
    echo "Removing GTK CSS files..."
    rm -f "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null
    rm -f "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null
    
    # Remove Desktop Icons extension CSS override
    echo "Removing Desktop Icons extension CSS..."
    rm -f "$HOME/.config/com.desktop.ding/stylesheet-override.css" 2>/dev/null
    rmdir "$HOME/.config/com.desktop.ding" 2>/dev/null || true
    
    # Note: We don't automatically restore JS backup since user might want to keep modifications
    echo "Note: Desktop Icons extension JavaScript backups (if any) were kept in:"
    echo "  ~/.local/share/gnome-shell/extensions/gtk4-ding@smedius.gitlab.com/app/"
    echo "  Files ending with .backup.[timestamp]"
    
    # Reset GNOME accent color to default blue for dark theme
    echo "Resetting GNOME accent color to default..."
    if command -v gsettings >/dev/null; then
        # Default blue for dark theme (Adwaita dark uses #1c71d8)
        gsettings reset org.gnome.desktop.interface accent-color 2>/dev/null
        echo "  GNOME accent color reset to default"
    fi
    
    # Reset shell theme
    echo "Resetting GNOME Shell theme..."
    if command -v gsettings >/dev/null; then
        gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null
        echo "  Shell theme reset to default"
    fi
    
    echo ""
    echo "========================================"
    echo "Reset complete!"
    echo "========================================"
    echo ""
    echo "The following has been removed/reset:"
    echo "  ✓ Custom shell themes in ~/.themes/"
    echo "  ✓ GTK CSS files in ~/.config/gtk-3.0/ and ~/.config/gtk-4.0/"
    echo "  ✓ Desktop Icons extension CSS override"
    echo "  ✓ GNOME accent color (reset to default)"
    echo "  ✓ GNOME Shell theme (reset to default)"
    echo ""
    echo "You may need to:"
    echo "  1. Log out and back in for changes to take effect"
    echo "  2. Restart applications to see GTK changes"
    echo "  3. Restart GNOME Shell: Alt+F2, type 'r', press Enter"
    echo "  4. For Desktop Icons extension: disable and re-enable it"
    echo ""
    
    exit 0
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Change Adwaita accent colors in GNOME"
    echo ""
    echo "Options:"
    echo "  --reset     Remove all customizations and reset to defaults"
    echo "  --help      Show this help message"
    echo ""
    echo "Without options: Run the interactive accent color changer"
    exit 0
}

# Check for command line arguments
if [ "$1" = "--reset" ]; then
    reset_theme
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
fi

# Main script
clear
echo "========================================"
echo "Adwaita Accent Color Changer"
echo "========================================"
echo "This script will:"
echo "  1. Extract Adwaita GNOME Shell themes"
echo "  2. Apply your chosen accent color to shell themes"
echo "  3. Apply accent color to GTK3/GTK4 themes"
echo "  4. Apply accent color to Desktop Icons extension"
echo "  5. Set the GNOME accent color in system settings"
echo "  6. Set GNOME Shell to use the dark variant"
echo ""
echo "To reset everything: $0 --reset"
echo "========================================"

# Ask for confirmation
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Get accent color
while true; do
    echo ""
    echo "Enter hex color (e.g., #308280) or 'exit' to quit:"
    read -p "Color: " accent_color
    
    if [[ "$accent_color" == "exit" ]]; then
        echo "Exiting."
        exit 0
    fi
    
    if validate_hex_color "$accent_color"; then
        # If validate_hex_color returned a corrected color (without # prefix), use it
        if [[ "$accent_color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
            accent_color="#$accent_color"
        fi
        break
    fi
done

echo ""
echo "Using accent color: $accent_color"
echo ""

# Step 1: Extract Adwaita themes
extract_adwaita_theme

echo ""
echo "Applying accent color to GNOME Shell themes..."
change_shell_accent "$HOME/.themes/Adwaita-shell-custom-light/gnome-shell/gnome-shell.css" "$accent_color"
change_shell_accent "$HOME/.themes/Adwaita-shell-custom-dark/gnome-shell/gnome-shell.css" "$accent_color"

echo ""
# Step 2: Apply to GTK themes
apply_gtk_accent "$accent_color"

echo ""
# Step 3: Apply to Desktop Icons extension
create_desktop_icons_css "$accent_color"
patch_desktop_icons_extension "$accent_color"

echo ""
# Step 4: Set shell theme to dark variant
set_shell_theme_dark

echo ""
echo "========================================"
echo "Theme customization complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  • GNOME Shell themes created with accent: $accent_color"
echo "  • GTK3/GTK4 themes configured"
echo "  • Desktop Icons extension configured (CSS + JavaScript patch)"
echo "  • GNOME accent color set via gsettings"
echo "  • GNOME Shell theme set to dark variant"
echo ""
echo "To complete setup:"
echo "  1. Install GNOME Tweaks if not already installed:"
echo "     sudo apt install gnome-tweaks"
echo ""
echo "  2. Enable User Themes extension:"
echo "     a. Open GNOME Extensions"
echo "     b. Enable 'User Themes' extension"
echo ""
echo "  3. Apply the shell theme in GNOME Tweaks:"
echo "     Appearance → Shell → Select 'Adwaita-shell-custom-dark'"
echo ""
echo "  4. Restart applications to see GTK changes"
echo "  5. Log out and back in for full system changes"
echo ""
echo "Restart GNOME Shell: Alt+F2, type 'r', press Enter"
echo ""
echo "Note: If Desktop Icons extension doesn't update immediately,"
echo "      disable and re-enable it in GNOME Extensions."
echo ""
echo "To reset everything: $0 --reset"
echo "========================================"

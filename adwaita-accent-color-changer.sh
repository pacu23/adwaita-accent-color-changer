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
    local backup_number=$(date +%s)
    local gtk3_file="$HOME/.config/gtk-3.0/gtk.css"
    local gtk4_file="$HOME/.config/gtk-4.0/gtk.css"
    
    echo "Applying accent color to GTK themes..."
    
    # Ensure gsettings command exists
    command -v gsettings >/dev/null || { echo "Error: gsettings not found."; exit 1; }
    
    # Set accent color in GNOME settings
    echo "  Setting GNOME accent color via gsettings..."
    gsettings set org.gnome.desktop.interface accent-color "$accent_color"
    
    # Create backups of existing files
    for file in "$gtk3_file" "$gtk4_file"; do
        if [ -f "$file" ]; then
            cp "$file" "${file}.${backup_number}.bak"
            echo "  Backup created: ${file}.${backup_number}.bak"
        fi
    done
    
    # Create GTK4 CSS
    mkdir -p "$(dirname "$gtk4_file")"
    cat <<EOF > "$gtk4_file"
:root {
  --accent-custom: $accent_color;
  --accent-bg-color: var(--accent-custom);
}

@define-color accent_color $accent_color;
@define-color accent_bg_color $accent_color;

/* Apply accent color to selected items */
* {
  -gtk-secondary-caret-color: $accent_color;
}

selection,
.selection,
*:selected,
*:selected:focus {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
}

button.suggested-action {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
}

button.suggested-action:hover {
  background-color: $(echo "$accent_color" | sed 's/#//' | awk '{printf "#%02x%02x%02x", 
    int(0.9*strtonum("0x" substr($1,1,2))), 
    int(0.9*strtonum("0x" substr($1,3,2))), 
    int(0.9*strtonum("0x" substr($1,5,2)))}');
}

progressbar progress {
  background-color: $accent_color;
}

EOF
    
    # Create GTK3 CSS
    mkdir -p "$(dirname "$gtk3_file")"
    cat <<EOF > "$gtk3_file"
@define-color accent_custom $accent_color;
@define-color accent_bg_color $accent_color;

/* Apply accent color to selected items */
* {
  -GtkWidget-secondary-caret-color: $accent_color;
}

*:selected,
*:selected:focus {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
}

button.suggested-action {
  background-color: $accent_color;
  color: $(calculate_foreground_color "$accent_color");
}

button.suggested-action:hover {
  background-color: $(echo "$accent_color" | sed 's/#//' | awk '{printf "#%02x%02x%02x", 
    int(0.9*strtonum("0x" substr($1,1,2))), 
    int(0.9*strtonum("0x" substr($1,3,2))), 
    int(0.9*strtonum("0x" substr($1,5,2)))}');
}

progressbar progress {
  background-color: $accent_color;
}

EOF
    
    echo "GTK theme files created:"
    echo "  $gtk3_file"
    echo "  $gtk4_file"
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

# Main script
clear
echo "========================================"
echo "Adwaita Accent Color Changer"
echo "========================================"
echo "This script will:"
echo "  1. Extract fresh Adwaita GNOME Shell themes"
echo "  2. Apply your chosen accent color to shell themes"
echo "  3. Apply the same accent color to GTK3/GTK4 themes"
echo "  4. Set the GNOME accent color in system settings"
echo "  5. Set GNOME Shell to use the dark variant"
echo ""
echo "Warning: This will overwrite existing theme files!"
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
# Step 3: Set shell theme to dark variant
set_shell_theme_dark

echo ""
echo "========================================"
echo "Theme customization complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  • GNOME Shell themes created with accent: $accent_color"
echo "  • GTK3/GTK4 themes configured"
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
echo "========================================"

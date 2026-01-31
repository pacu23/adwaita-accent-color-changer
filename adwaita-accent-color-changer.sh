#!/bin/bash

# Force decimal separator to be dot for the entire script
export LC_NUMERIC=C

# Global variable for foreground color (white by default)
FOREGROUND_COLOR="#ffffff"

# Function to check if we're running in GNOME
check_gnome() {
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] || [ "$XDG_CURRENT_DESKTOP" = "ubuntu:GNOME" ] || 
       [ "$XDG_SESSION_DESKTOP" = "gnome" ] || [ "$DESKTOP_SESSION" = "gnome" ]; then
        return 0
    elif command -v gnome-shell >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if extension exists
extension_exists() {
    local ext_id="$1"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_id"
    
    if [ -d "$ext_dir" ]; then
        return 0
    else
        return 1
    fi
}

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

# Function to prompt user for foreground color choice
prompt_foreground_color() {
    local accent_color="$1"
    
    echo ""
    echo "========================================"
    echo "Foreground Color Selection"
    echo "========================================"
    echo "By default, foreground text on accent-colored elements is WHITE (#ffffff)."
    echo ""
    echo "With your chosen accent color: $accent_color"
    echo ""
    echo "Would you like to use BLACK (#000000) text instead of white?"
    echo "This may be preferred for very light accent colors."
    echo ""
    
    read -p "Use BLACK text instead of WHITE? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        FOREGROUND_COLOR="#000000"
        echo "Using BLACK foreground color: $FOREGROUND_COLOR"
    else
        FOREGROUND_COLOR="#ffffff"
        echo "Using WHITE foreground color: $FOREGROUND_COLOR"
    fi
    
    echo ""
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

# Function to calculate lighter color
calculate_lighter_color() {
    local hex="${1#\#}"
    local percent="$2"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Calculate lighter color (inverse of darkening)
    r=$((r + (255 - r) * percent / 100))
    g=$((g + (255 - g) * percent / 100))
    b=$((b + (255 - b) * percent / 100))
    
    # Clamp to 255
    r=$((r > 255 ? 255 : r))
    g=$((g > 255 ? 255 : g))
    b=$((b > 255 ? 255 : b))
    
    printf "#%02x%02x%02x\n" $r $g $b
}

# Function to convert hex color to RGB floats (0-1) with C decimal point (locale-safe)
hex_to_rgb_floats() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Use awk in C locale to guarantee dot as decimal separator and leading zero
    LC_NUMERIC=C awk -v R="$r" -v G="$g" -v B="$b" 'BEGIN{printf "%.10f %.10f %.10f", R/255, G/255, B/255}'
}

# Function to apply accent color to GTK themes (desktop-agnostic)
apply_gtk_accent() {
    local accent_color="$1"
    local gtk3_file="$HOME/.config/gtk-3.0/gtk.css"
    local gtk4_file="$HOME/.config/gtk-4.0/gtk.css"
    local darker_accent=$(calculate_darker_color "$accent_color")
    
    echo "Applying accent color to GTK themes..."
    echo "  (This works on any desktop environment with GTK3/GTK4 apps)"
    
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
  color: $FOREGROUND_COLOR;
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
  color: $FOREGROUND_COLOR;
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
  color: $FOREGROUND_COLOR;
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
  color: $FOREGROUND_COLOR;
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
    echo ""
    echo "Note: Restart GTK applications to see changes."
}

# Function to check if adw-gtk3 themes exist
check_adw_gtk3_exists() {
    local light_found=0
    local dark_found=0
    
    # Check in various locations
    local locations=(
        "/usr/share/themes"
        "$HOME/.local/share/themes"
    )
    
    echo "Searching for adw-gtk3 themes..."
    
    for location in "${locations[@]}"; do
        if [ -d "$location/adw-gtk3" ]; then
            light_found=1
            echo "  Found adw-gtk3 in: $location"
        fi
        if [ -d "$location/adw-gtk3-dark" ]; then
            dark_found=1
            echo "  Found adw-gtk3-dark in: $location"
        fi
    done
    
    if [ $light_found -eq 0 ]; then
        echo "❌ adw-gtk3 theme not found!"
    fi
    if [ $dark_found -eq 0 ]; then
        echo "❌ adw-gtk3-dark theme not found!"
    fi
    
    if [ $light_found -eq 1 ] && [ $dark_found -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

# Function to apply Firefox fix (creates symlinked themes)
apply_firefox_fix() {
    echo ""
    echo "========================================"
    echo "Firefox/Thunderbird GTK Theme Fix"
    echo "========================================"
    echo "Firefox and Thunderbird have a quirk: they ignore GTK CSS overrides"
    echo "when the current theme name contains 'adwaita', 'adw', or 'adw-gtk3'."
    echo ""
    echo "This fix creates custom-named theme directories with symlinks to"
    echo "adw-gtk3's gtk-3.0 and gtk-4.0 directories."
    echo ""
    
    echo "Applying Firefox/Thunderbird fix..."
    
    # Check if adw-gtk3 themes exist
    if ! check_adw_gtk3_exists; then
        echo ""
        echo "❌ adw-gtk3 themes not found in standard locations!"
        echo "   Please install adw-gtk3 theme first."
        echo "   On Ubuntu/Debian: sudo apt install adw-gtk3-theme"
        echo "   On Fedora: sudo dnf install adw-gtk3-theme"
        echo "   Or download from: https://github.com/lassekongo83/adw-gtk3"
        return 1
    fi
    
    # Create .local/share/themes directory if it doesn't exist
    mkdir -p "$HOME/.local/share/themes"
    
    # Find adw-gtk3 and adw-gtk3-dark themes
    local light_source=""
    local dark_source=""
    
    # Check in various locations
    local locations=(
        "/usr/share/themes"
        "$HOME/.local/share/themes"
    )
    
    for location in "${locations[@]}"; do
        if [ -d "$location/adw-gtk3" ] && [ -z "$light_source" ]; then
            light_source="$location/adw-gtk3"
            echo "Using adw-gtk3 from: $light_source"
        fi
        if [ -d "$location/adw-gtk3-dark" ] && [ -z "$dark_source" ]; then
            dark_source="$location/adw-gtk3-dark"
            echo "Using adw-gtk3-dark from: $dark_source"
        fi
    done
    
    if [ -z "$light_source" ] || [ -z "$dark_source" ]; then
        echo "❌ Could not find both adw-gtk3 and adw-gtk3-dark themes"
        return 1
    fi
    
    # Remove existing directories if they exist
    echo "Removing existing custom theme directories if any..."
    rm -rf "$HOME/.local/share/themes/gtk-custom" 2>/dev/null
    rm -rf "$HOME/.local/share/themes/gtk-custom-dark" 2>/dev/null
    
    # Create gtk-custom theme directory structure
    echo "Creating gtk-custom theme directory..."
    mkdir -p "$HOME/.local/share/themes/gtk-custom"
    
    # Create symlinks for gtk-3.0 and gtk-4.0 directories
    if [ -d "$light_source/gtk-3.0" ]; then
        ln -sf "$light_source/gtk-3.0" "$HOME/.local/share/themes/gtk-custom/gtk-3.0"
        echo "  Created symlink: gtk-3.0 → $light_source/gtk-3.0"
    else
        echo "  Warning: gtk-3.0 directory not found in $light_source"
    fi
    
    if [ -d "$light_source/gtk-4.0" ]; then
        ln -sf "$light_source/gtk-4.0" "$HOME/.local/share/themes/gtk-custom/gtk-4.0"
        echo "  Created symlink: gtk-4.0 → $light_source/gtk-4.0"
    else
        echo "  Warning: gtk-4.0 directory not found in $light_source"
    fi
    
    # Create index.theme for light variant
    cat <<EOF > "$HOME/.local/share/themes/gtk-custom/index.theme"
[X-GNOME-Metatheme]
Name=gtk-custom
Type=X-GNOME-Metatheme
Comment=adw-gtk3 theme
Encoding=UTF-8
GtkTheme=gtk-custom
EOF
    echo "  Created index.theme for gtk-custom"
    
    # Create gtk-custom-dark theme directory structure
    echo "Creating gtk-custom-dark theme directory..."
    mkdir -p "$HOME/.local/share/themes/gtk-custom-dark"
    
    # Create symlinks for gtk-3.0 and gtk-4.0 directories
    if [ -d "$dark_source/gtk-3.0" ]; then
        ln -sf "$dark_source/gtk-3.0" "$HOME/.local/share/themes/gtk-custom-dark/gtk-3.0"
        echo "  Created symlink: gtk-3.0 → $dark_source/gtk-3.0"
    else
        echo "  Warning: gtk-3.0 directory not found in $dark_source"
    fi
    
    if [ -d "$dark_source/gtk-4.0" ]; then
        ln -sf "$dark_source/gtk-4.0" "$HOME/.local/share/themes/gtk-custom-dark/gtk-4.0"
        echo "  Created symlink: gtk-4.0 → $dark_source/gtk-4.0"
    else
        echo "  Warning: gtk-4.0 directory not found in $dark_source"
    fi
    
    # Create custom index.theme for dark variant
    cat <<EOF > "$HOME/.local/share/themes/gtk-custom-dark/index.theme"
[X-GNOME-Metatheme]
Name=gtk-custom-dark
Type=X-GNOME-Metatheme
Comment=adw-gtk3-dark theme
Encoding=UTF-8
GtkTheme=gtk-custom-dark
EOF
    echo "  Created index.theme for gtk-custom-dark"
    
    echo ""
    echo "✅ Firefox/Thunderbird fix applied!"
    echo ""
    echo "Created custom theme directories:"
    echo "  • $HOME/.local/share/themes/gtk-custom/"
    echo "  • $HOME/.local/share/themes/gtk-custom-dark/"
    echo ""
    
    return 0
}

# Function to convert symlinks to actual copies for Flatpak compatibility
convert_symlinks_to_copies() {
    local theme_dir="$1"
    local theme_name="$2"
    
    if [ ! -d "$theme_dir" ]; then
        return 1
    fi
    
    echo "Converting symlinks to copies in $theme_dir..."
    
    # Remove symlinks first if they exist
    if [ -L "$theme_dir/gtk-3.0" ]; then
        rm -f "$theme_dir/gtk-3.0"
    fi
    if [ -L "$theme_dir/gtk-4.0" ]; then
        rm -f "$theme_dir/gtk-4.0"
    fi
    
    # Find the source themes
    local light_source=""
    local dark_source=""
    
    # Check in various locations
    local locations=(
        "/usr/share/themes"
        "$HOME/.local/share/themes"
    )
    
    for location in "${locations[@]}"; do
        if [ -d "$location/adw-gtk3" ] && [ -z "$light_source" ]; then
            light_source="$location/adw-gtk3"
        fi
        if [ -d "$location/adw-gtk3-dark" ] && [ -z "$dark_source" ]; then
            dark_source="$location/adw-gtk3-dark"
        fi
    done
    
    if [ -z "$light_source" ] || [ -z "$dark_source" ]; then
        echo "❌ Could not find both adw-gtk3 and adw-gtk3-dark themes"
        return 1
    fi
    
    # Determine which source to use based on theme name
    local source_dir=""
    if [[ "$theme_name" == *"gtk-custom" && "$theme_name" != *"dark"* ]]; then
        source_dir="$light_source"
    elif [[ "$theme_name" == *"gtk-custom-dark" ]]; then
        source_dir="$dark_source"
    fi
    
    if [ -z "$source_dir" ]; then
        echo "  Warning: Could not determine source for $theme_name"
        return 1
    fi
    
    # Copy gtk-3.0 directory
    if [ -d "$source_dir/gtk-3.0" ]; then
        cp -r "$source_dir/gtk-3.0" "$theme_dir/gtk-3.0"
        echo "  Copied gtk-3.0 from $source_dir"
    else
        echo "  Warning: gtk-3.0 directory not found in $source_dir"
    fi
    
    # Copy gtk-4.0 directory
    if [ -d "$source_dir/gtk-4.0" ]; then
        cp -r "$source_dir/gtk-4.0" "$theme_dir/gtk-4.0"
        echo "  Copied gtk-4.0 from $source_dir"
    else
        echo "  Warning: gtk-4.0 directory not found in $source_dir"
    fi
}

# Function to apply Flatpak fix
apply_flatpak_fix() {
    echo ""
    echo "========================================"
    echo "Flatpak Theme Fix"
    echo "========================================"
    echo "Flatpak applications run in a sandbox and may not have access to"
    echo "your GTK theme configuration files."
    echo ""
    echo "This fix will:"
    echo "  1. Convert symlinked themes to copies (for Flatpak compatibility)"
    echo "  2. Allow Flatpak apps to read your GTK theme configs"
    echo ""
    
    echo "Applying Flatpak fix..."
    
    # Check if flatpak is installed
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "❌ Flatpak is not installed. Skipping Flatpak fix."
        return 1
    fi
    
    # Check if gtk-custom-dark theme exists
    if [ ! -d "$HOME/.local/share/themes/gtk-custom-dark" ]; then
        echo "❌ gtk-custom-dark theme not found."
        echo "   Please apply Firefox fix first."
        return 1
    fi
    
    echo "Converting symlinked themes to copies for Flatpak compatibility..."
    
    # Convert symlinks to copies
    convert_symlinks_to_copies "$HOME/.local/share/themes/gtk-custom" "gtk-custom"
    convert_symlinks_to_copies "$HOME/.local/share/themes/gtk-custom-dark" "gtk-custom-dark"
    
    echo ""
    echo "Setting Flatpak permissions..."
    
    # Allow Flatpak apps to read GTK config files
    sudo flatpak override --filesystem=xdg-config/gtk-3.0
    if [ $? -eq 0 ]; then
        echo "  ✓ Allowed Flatpak access to gtk-3.0 config"
    else
        echo "  ✗ Failed to allow access to gtk-3.0 config"
    fi
    
    sudo flatpak override --filesystem=xdg-config/gtk-4.0
    if [ $? -eq 0 ]; then
        echo "  ✓ Allowed Flatpak access to gtk-4.0 config"
    else
        echo "  ✗ Failed to allow access to gtk-4.0 config"
    fi
    
    # Allow Flatpak apps to read custom themes
    sudo flatpak override --filesystem=xdg-data/themes
    if [ $? -eq 0 ]; then
        echo "  ✓ Allowed Flatpak access to custom themes"
    else
        echo "  ✗ Failed to allow access to custom themes"
    fi
    
    echo ""
    echo "✅ Flatpak fix applied!"
    echo "   Flatpak applications will now follow your system theme (gtk-custom-dark)."
    
    return 0
}

# Function to apply gtk-custom-dark theme
apply_gtk_custom_dark_theme() {
    echo "Setting system GTK theme to gtk-custom-dark..."
    
    if command -v gsettings >/dev/null; then
        # Set the GTK theme to gtk-custom-dark
        gsettings set org.gnome.desktop.interface gtk-theme 'gtk-custom-dark' 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "  GTK theme set to gtk-custom-dark"
        else
            echo "  Note: Could not set GTK theme automatically."
            echo "  Please set your GTK theme to 'gtk-custom-dark' manually."
        fi
    else
        echo "  Note: gsettings not found. Cannot set GTK theme automatically."
        echo "  Please set your GTK theme to 'gtk-custom-dark' manually."
    fi
}

# GNOME-specific functions below
# Only run if user confirms they want GNOME-specific features

# Function to extract Adwaita theme
extract_adwaita_theme() {
    echo "Extracting Adwaita GNOME Shell theme..."
    
    # Define theme paths in ~/.local/share/themes
    LIGHT_TARGET="$HOME/.local/share/themes/shell-custom/gnome-shell"
    DARK_TARGET="$HOME/.local/share/themes/shell-custom-dark/gnome-shell"
    
    # Clean existing directories
    rm -rf "$HOME/.local/share/themes/shell-custom" "$HOME/.local/share/themes/shell-custom-dark"
    
    # Create directories
    mkdir -p "$LIGHT_TARGET" "$DARK_TARGET"
    
    # Check if gnome-shell-theme.gresource exists
    if [ ! -f "/usr/share/gnome-shell/gnome-shell-theme.gresource" ]; then
        echo "❌ GNOME Shell theme resource not found at /usr/share/gnome-shell/gnome-shell-theme.gresource"
        echo "   Make sure you're running GNOME Shell"
        return 1
    fi
    
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
    
    # Create index.theme for shell-custom
    cat <<EOF > "$HOME/.local/share/themes/shell-custom/index.theme"
[X-GNOME-Metatheme]
Name=shell-custom
Type=X-GNOME-Metatheme
Comment=Custom GNOME Shell theme
Encoding=UTF-8
GtkTheme=shell-custom
EOF
    
    # Create index.theme for shell-custom-dark
    cat <<EOF > "$HOME/.local/share/themes/shell-custom-dark/index.theme"
[X-GNOME-Metatheme]
Name=shell-custom-dark
Type=X-GNOME-Metatheme
Comment=Custom GNOME Shell dark theme
Encoding=UTF-8
GtkTheme=shell-custom-dark
EOF
    
    echo "Theme extracted to:"
    echo "  Light: $HOME/.local/share/themes/shell-custom/"
    echo "  Dark:  $HOME/.local/share/themes/shell-custom-dark/"
}

# Function to change accent color in GNOME Shell CSS files
change_shell_accent() {
    local css_file="$1"
    local new_accent="$2"
    
    if [ ! -f "$css_file" ]; then
        echo "Warning: CSS file not found: $css_file"
        return 1
    fi
    
    local lighten_4=$(calculate_lighter_color "$new_accent" 4)
    local lighten_8=$(calculate_lighter_color "$new_accent" 8)
    
    # FIRST restore original values if they exist in backup
    local backup_file="${css_file}.backup.original"
    if [ -f "$backup_file" ]; then
        echo "  Restoring original CSS from backup..."
        cp "$backup_file" "$css_file"
    else
        # Create backup of original file before first modification
        cp "$css_file" "$backup_file"
    fi
    
    # Replace accent color variables
    sed -i "s/-st-accent-color/${new_accent}/g" "$css_file"
    sed -i "s/-st-accent-fg-color/${FOREGROUND_COLOR}/g" "$css_file"
    
    # Replace st-lighten function calls with actual colors
    sed -i "s/st-lighten(-st-accent-color, 4%)/${lighten_4}/g" "$css_file"
    sed -i "s/st-lighten(-st-accent-color, 8%)/${lighten_8}/g" "$css_file"
    
    echo "  Updated: $(basename "$css_file")"
}

# Function to set GNOME accent color via gsettings
set_gnome_accent_color() {
    local accent_color="$1"
    
    echo "Setting GNOME accent color via gsettings..."
    
    # Ensure gsettings command exists
    if ! command -v gsettings >/dev/null; then
        echo "  Warning: gsettings not found. Skipping GNOME accent color setting."
        return 1
    fi
    
    # Convert hex to RGB tuple (0-1)
    local hex="${accent_color#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Create RGB tuple string with dot decimal separator using LC_NUMERIC=C
    local rgb_tuple="($(echo "scale=3; $r/255" | bc -l), $(echo "scale=3; $g/255" | bc -l), $(echo "scale=3; $b/255" | bc -l))"
    
    # Set using gsettings
    gsettings set org.gnome.desktop.interface accent-color "$rgb_tuple"
    
    echo "  GNOME accent color set to: $accent_color"
    return 0
}

# Function to create desktop icons extension CSS override
create_desktop_icons_css() {
    local accent_color="$1"
    local css_file="$HOME/.config/com.desktop.ding/stylesheet-override.css"
    
    echo "Creating Desktop Icons extension CSS override..."
    
    # Check if extension exists
    if ! extension_exists "gtk4-ding@smedius.gitlab.com"; then
        echo "  Desktop Icons extension not found. Skipping."
        return 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$css_file")"
    
    # Create the CSS file - this will overwrite existing file, which is what we want
    cat <<EOF > "$css_file"
/* Minimal: only change colors — nothing else */

/* Primary accent the extension references */
@define-color theme_selected_accent_color $accent_color;

/* Common named selection colors (cover GTK/Adwaita and many apps) */
@define-color theme_selected_bg_color    $accent_color;
@define-color theme_selected_fg_color    $FOREGROUND_COLOR;

/* Legacy/alternate names (some themes/apps still use these) */
@define-color selected_bg_color  $accent_color;
@define-color selected_fg_color  $FOREGROUND_COLOR;

/* Ensure extension-specific names resolve to the theme variables */
@define-color desktop_icons_bg_color @theme_selected_accent_color;
@define-color desktop_icons_fg_color @theme_selected_fg_color;
EOF
    
    echo "  Created/Updated: $css_file"
    return 0
}

# FIXED: Function to patch desktop icons extension JavaScript - NOW HANDLES RE-RUNS PROPERLY
patch_desktop_icons_extension() {
    local accent_color="$1"
    local ext_id="gtk4-ding@smedius.gitlab.com"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_id"
    local js_file="$ext_dir/app/desktopGrid.js"
    
    echo "Patching Desktop Icons extension JavaScript (rubberband selection)..."
    
    # Check if extension exists
    if ! extension_exists "$ext_id"; then
        echo "  Desktop Icons extension not found. Skipping JavaScript patch."
        return 1
    fi
    
    if [ ! -f "$js_file" ]; then
        echo "  Warning: Desktop Icons extension JavaScript file not found at: $js_file"
        echo "  JavaScript patch skipped"
        return 1
    fi
    
    # Check if we have an original backup
    local original_backup="${js_file}.original"
    if [ ! -f "$original_backup" ]; then
        echo "  Creating backup of original JavaScript file..."
        cp "$js_file" "$original_backup"
    else
        echo "  Restoring from original backup for fresh patching..."
        cp "$original_backup" "$js_file"
    fi
    
    # Convert hex to RGB floats (locale-safe)
    read -r r g b <<< "$(hex_to_rgb_floats "$accent_color")"
    
    echo "  Using RGB floats: $r $g $b"
    
    # Create timestamped backup
    cp "$js_file" "$js_file.backup.$(date +%s)" 2>/dev/null || true
    
    # Replace occurrences of this.Prefs.selectColor.* with computed floats
    sed -i -E "s/this\.Prefs\.selectColor\.red/${r}/g" "$js_file"
    sed -i -E "s/this\.Prefs\.selectColor\.green/${g}/g" "$js_file"
    sed -i -E "s/this\.Prefs\.selectColor\.blue/${b}/g" "$js_file"
    
    # Replace expressions like "1.0 - this.Prefs.selectColor.red" with the complement if present
    sed -i -E "s/1(\.0)?[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.red/${r}/g" "$js_file"
    sed -i -E "s/1(\.0)?[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.green/${g}/g" "$js_file"
    sed -i -E "s/1(\.0)?[[:space:]]*-[[:space:]]*this\.Prefs\.selectColor\.blue/${b}/g" "$js_file"
    
    echo "  JavaScript file patched (backup created)."
    
    # Try to reload the extension
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading extension..."
        gnome-extensions disable "$ext_id" >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable "$ext_id" >/dev/null 2>&1 || true
        echo "  Extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
    
    return 0
}

# FIXED: Function to patch Color Picker extension stylesheets - NOW HANDLES RE-RUNS PROPERLY
patch_color_picker_extension() {
    local accent_color="$1"
    local ext_id="color-picker@tuberry"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_id"
    local dark_css="$ext_dir/stylesheet-dark.css"
    local light_css="$ext_dir/stylesheet-light.css"
    
    echo "Patching Color Picker extension stylesheets..."
    
    # Check if extension exists
    if ! extension_exists "$ext_id"; then
        echo "  Color Picker extension not found. Skipping."
        return 1
    fi
    
    echo "  Using accent color: $accent_color"
    echo "  Note: Using normal accent color (no lightening)"
    
    # Patch dark stylesheet if it exists
    if [ -f "$dark_css" ]; then
        echo "  Patching dark stylesheet..."
        
        # Check if we have an original backup
        local dark_original="${dark_css}.original"
        if [ ! -f "$dark_original" ]; then
            cp "$dark_css" "$dark_original"
        else
            # Restore from original before patching
            cp "$dark_original" "$dark_css"
        fi
        
        # Create timestamped backup
        cp "$dark_css" "$dark_css.backup.$(date +%s)" 2>/dev/null || true
        
        # Apply patches
        sed -i "s/-st-accent-color/${accent_color}/g" "$dark_css"
        sed -i -E "s/st-lighten\([^,]+,[[:space:]]*[0-9]+%\)/${accent_color}/g" "$dark_css"
        sed -i -E "s/st-lighten\([^)]+\)/${accent_color}/g" "$dark_css"
        
        echo "    Dark stylesheet patched"
    else
        echo "  Warning: Dark stylesheet not found: $dark_css"
    fi
    
    # Patch light stylesheet if it exists
    if [ -f "$light_css" ]; then
        echo "  Patching light stylesheet..."
        
        # Check if we have an original backup
        local light_original="${light_css}.original"
        if [ ! -f "$light_original" ]; then
            cp "$light_css" "$light_original"
        else
            # Restore from original before patching
            cp "$light_original" "$light_css"
        fi
        
        # Create timestamped backup
        cp "$light_css" "$light_css.backup.$(date +%s)" 2>/dev/null || true
        
        # Apply patches
        sed -i "s/-st-accent-color/${accent_color}/g" "$light_css"
        sed -i -E "s/st-lighten\([^,]+,[[:space:]]*[0-9]+%\)/${accent_color}/g" "$light_css"
        sed -i -E "s/st-lighten\([^)]+\)/${accent_color}/g" "$light_css"
        
        echo "    Light stylesheet patched"
    else
        echo "  Warning: Light stylesheet not found: $light_css"
    fi
    
    echo "  Color Picker extension patched"
    
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading Color Picker extension..."
        gnome-extensions disable "$ext_id" >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable "$ext_id" >/dev/null 2>&1 || true
        echo "  Color Picker extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
    
    return 0
}

# FIXED: Function to patch Privacy Indicators Accent Color extension stylesheets - NOW HANDLES RE-RUNS PROPERLY
patch_privacy_indicators_extension() {
    local accent_color="$1"
    local ext_id="privacy-indicators-accent-color@sopht.li"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_id"
    local base_css="$ext_dir/stylesheet.css"
    local dark_css="$ext_dir/stylesheet-dark.css"
    local light_css="$ext_dir/stylesheet-light.css"
    
    echo "Patching Privacy Indicators Accent Color extension..."
    
    # Check if extension exists
    if ! extension_exists "$ext_id"; then
        echo "  Privacy Indicators extension not found. Skipping."
        return 1
    fi
    
    echo "  Using accent color: $accent_color"
    echo "  Foreground color: $FOREGROUND_COLOR"
    
    # Helper function to patch a single CSS file
    patch_css_file() {
        local css_file="$1"
        local accent_color="$2"
        
        if [ ! -f "$css_file" ]; then
            return 1
        fi
        
        # Check if we have an original backup
        local original_file="${css_file}.original"
        if [ ! -f "$original_file" ]; then
            cp "$css_file" "$original_file"
        else
            # Restore from original before patching
            cp "$original_file" "$css_file"
        fi
        
        # Create timestamped backup
        cp "$css_file" "$css_file.backup.$(date +%s)" 2>/dev/null || true
        
        # Apply patches
        sed -i \
            -e "s/-st-accent-color/${accent_color}/g" \
            -e "s/-st-accent-fg-color/${FOREGROUND_COLOR}/g" \
            "$css_file"
        
        # Replace st-lighten calls
        sed -i -E "s/st-lighten\(-st-accent-color,[[:space:]]*[0-9]+%\)/${accent_color}/g" "$css_file"
        
        # For dark stylesheet only, also replace st-darken
        if [[ "$css_file" == *"dark"* ]]; then
            local darken_10=$(calculate_darker_color "#ffffff")
            local darken_20=$(calculate_darker_color "$darken_10")
            sed -i -E "s/st-darken\(#FFFFFF,[[:space:]]*10%\)/${darken_10}/g" "$css_file"
            sed -i -E "s/st-darken\(#FFFFFF,[[:space:]]*20%\)/${darken_20}/g" "$css_file"
        fi
        
        return 0
    }
    
    # Patch each file
    if [ -f "$base_css" ]; then
        echo "  Patching base stylesheet..."
        patch_css_file "$base_css" "$accent_color"
        echo "    Base stylesheet patched"
    else
        echo "  Warning: Base stylesheet not found: $base_css"
    fi
    
    if [ -f "$dark_css" ]; then
        echo "  Patching dark stylesheet..."
        patch_css_file "$dark_css" "$accent_color"
        echo "    Dark stylesheet patched"
    else
        echo "  Warning: Dark stylesheet not found: $dark_css"
    fi
    
    if [ -f "$light_css" ]; then
        echo "  Patching light stylesheet..."
        patch_css_file "$light_css" "$accent_color"
        echo "    Light stylesheet patched"
    else
        echo "  Warning: Light stylesheet not found: $light_css"
    fi
    
    echo "  Privacy Indicators extension patched"
    
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading Privacy Indicators extension..."
        gnome-extensions disable "$ext_id" >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable "$ext_id" >/dev/null 2>&1 || true
        echo "  Privacy Indicators extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
    
    return 0
}

# Function to apply GNOME Shell themes to GDM
apply_gdm_theme() {
    echo ""
    echo "========================================"
    echo "Apply Themes to GDM (Login Screen)"
    echo "========================================"
    echo "Note: This copies both Light and Dark themes to /usr/share"
    echo "      GDM cannot see user themes in ~/.local/share/themes/"
    echo ""
    
    read -p "Apply custom themes to GDM? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping GDM theming."
        return 0
    fi
    
    # Check sudo
    if ! sudo -v; then
        echo "❌ Need sudo privileges to copy themes to /usr/share"
        return 1
    fi
    
    # Check if themes exist
    if [ ! -d "$HOME/.local/share/themes/shell-custom-dark" ] || [ ! -d "$HOME/.local/share/themes/shell-custom" ]; then
        echo "❌ Custom themes not found in ~/.local/share/themes/"
        echo "   Run the script without GDM option first to create themes"
        return 1
    fi
    
    # Copy BOTH themes to system directory
    echo "  Copying DARK theme to /usr/share/themes/..."
    sudo cp -r "$HOME/.local/share/themes/shell-custom-dark" "/usr/share/themes/"
    echo "  Copying LIGHT theme to /usr/share/themes/..."
    sudo cp -r "$HOME/.local/share/themes/shell-custom" "/usr/share/themes/"
    
    # Set permissions
    sudo chmod -R 755 "/usr/share/themes/shell-custom-dark"
    sudo chmod -R 755 "/usr/share/themes/shell-custom"
    
    echo "✅ Both themes copied to system directory"
    echo ""
    
    # Instructions
    echo "How to Apply Theme to GDM:"
    echo ""
    echo "1. Open 'GDM Settings' application."
    echo "2. Go to the 'Appearance' tab."
    echo "3. In the 'Shell theme' dropdown, you should now see:"
    echo "     • shell-custom-dark"
    echo "     • shell-custom"
    echo "4. Select your preferred variant and click 'Apply'."
    echo ""
    echo "Note: The 'default-pure' entry is created by GDM Settings as a"
    echo "fallback. You can safely ignore it. To remove it, run:"
    echo "    sudo rm -rf /usr/share/themes/default-pure"
    echo ""
    echo "Log out to see the changes on your login screen."
    echo ""
    
    return 0
}

# Function to set the shell theme to dark variant
set_shell_theme_dark() {
    echo "Setting GNOME Shell theme to dark variant..."
    
    # Check if user-theme extension is enabled
    if command -v gsettings >/dev/null; then
        # Try to set the shell theme to the dark variant
        gsettings set org.gnome.shell.extensions.user-theme name 'shell-custom-dark' 2>/dev/null
        
        # Check if the command succeeded
        if [ $? -eq 0 ]; then
            echo "  Shell theme set to shell-custom-dark"
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
    
    # Remove custom shell themes (GNOME-specific)
    echo "Removing custom shell themes..."
    rm -rf "$HOME/.local/share/themes/shell-custom" 2>/dev/null
    rm -rf "$HOME/.local/share/themes/shell-custom-dark" 2>/dev/null
    
    # Remove GTK CSS files (desktop-agnostic)
    echo "Removing GTK CSS files..."
    rm -f "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null
    rm -f "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null
    
    # Remove Desktop Icons extension CSS override (GNOME-specific)
    echo "Removing Desktop Icons extension CSS..."
    rm -f "$HOME/.config/com.desktop.ding/stylesheet-override.css" 2>/dev/null
    rmdir "$HOME/.config/com.desktop.ding" 2>/dev/null || true
    
    # Restore original Desktop Icons extension JavaScript (GNOME-specific)
    echo "Restoring Desktop Icons extension JavaScript..."
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/gtk4-ding@smedius.gitlab.com"
    local js_file="$ext_dir/app/desktopGrid.js"
    
    # Restore from original backup if it exists
    local original_backup="${js_file}.original"
    if [ -f "$original_backup" ]; then
        cp "$original_backup" "$js_file" 2>/dev/null && echo "  JavaScript restored from original backup"
        rm -f "$original_backup" 2>/dev/null || true
    fi
    
    # Clean up all backup files
    rm -f "$js_file.backup."* 2>/dev/null || true
    rm -f "${js_file}.original" 2>/dev/null || true
    
    # Restore original Color Picker extension stylesheets (GNOME-specific)
    echo "Restoring Color Picker extension..."
    local color_picker_dir="$HOME/.local/share/gnome-shell/extensions/color-picker@tuberry"
    if [ -d "$color_picker_dir" ]; then
        # Restore dark stylesheet
        local dark_original="${color_picker_dir}/stylesheet-dark.css.original"
        if [ -f "$dark_original" ]; then
            cp "$dark_original" "${color_picker_dir}/stylesheet-dark.css" 2>/dev/null
            echo "  Dark stylesheet restored from original"
            rm -f "$dark_original" 2>/dev/null || true
        fi
        
        # Restore light stylesheet
        local light_original="${color_picker_dir}/stylesheet-light.css.original"
        if [ -f "$light_original" ]; then
            cp "$light_original" "${color_picker_dir}/stylesheet-light.css" 2>/dev/null
            echo "  Light stylesheet restored from original"
            rm -f "$light_original" 2>/dev/null || true
        fi
        
        # Clean up backup files
        rm -f "$color_picker_dir/stylesheet-dark.css.backup."* 2>/dev/null || true
        rm -f "$color_picker_dir/stylesheet-light.css.backup."* 2>/dev/null || true
        rm -f "$color_picker_dir/stylesheet-dark.css.original" 2>/dev/null || true
        rm -f "$color_picker_dir/stylesheet-light.css.original" 2>/dev/null || true
    fi
    
    # Restore original Privacy Indicators extension stylesheets (GNOME-specific)
    echo "Restoring Privacy Indicators extension..."
    local privacy_dir="$HOME/.local/share/gnome-shell/extensions/privacy-indicators-accent-color@sopht.li"
    if [ -d "$privacy_dir" ]; then
        # Restore base stylesheet
        local base_original="${privacy_dir}/stylesheet.css.original"
        if [ -f "$base_original" ]; then
            cp "$base_original" "${privacy_dir}/stylesheet.css" 2>/dev/null
            echo "  Base stylesheet restored from original"
            rm -f "$base_original" 2>/dev/null || true
        fi
        
        # Restore dark stylesheet
        local dark_original="${privacy_dir}/stylesheet-dark.css.original"
        if [ -f "$dark_original" ]; then
            cp "$dark_original" "${privacy_dir}/stylesheet-dark.css" 2>/dev/null
            echo "  Dark stylesheet restored from original"
            rm -f "$dark_original" 2>/dev/null || true
        fi
        
        # Restore light stylesheet
        local light_original="${privacy_dir}/stylesheet-light.css.original"
        if [ -f "$light_original" ]; then
            cp "$light_original" "${privacy_dir}/stylesheet-light.css" 2>/dev/null
            echo "  Light stylesheet restored from original"
            rm -f "$light_original" 2>/dev/null || true
        fi
        
        # Clean up backup files
        rm -f "$privacy_dir/stylesheet.css.backup."* 2>/dev/null || true
        rm -f "$privacy_dir/stylesheet-dark.css.backup."* 2>/dev/null || true
        rm -f "$privacy_dir/stylesheet-light.css.backup."* 2>/dev/null || true
        rm -f "$privacy_dir/stylesheet.css.original" 2>/dev/null || true
        rm -f "$privacy_dir/stylesheet-dark.css.original" 2>/dev/null || true
        rm -f "$privacy_dir/stylesheet-light.css.original" 2>/dev/null || true
    fi
    
    # Remove GDM themes if they exist (GNOME-specific)
    echo "Removing GDM themes..."
    if [ -d "/usr/share/themes/shell-custom-dark" ]; then
        sudo rm -rf "/usr/share/themes/shell-custom-dark" 2>/dev/null
        echo "  GDM dark theme removed"
    fi
    if [ -d "/usr/share/themes/shell-custom" ]; then
        sudo rm -rf "/usr/share/themes/shell-custom" 2>/dev/null
        echo "  GDM light theme removed"
    fi
    # Also remove default-pure if it exists
    if [ -d "/usr/share/themes/default-pure" ]; then
        sudo rm -rf "/usr/share/themes/default-pure" 2>/dev/null
        echo "  GDM default-pure theme removed"
    fi
    
    # Remove shell theme backups (GNOME-specific)
    echo "Removing shell theme backups..."
    rm -f "$HOME/.local/share/themes/shell-custom/gnome-shell/gnome-shell.css.backup.original" 2>/dev/null || true
    rm -f "$HOME/.local/share/themes/shell-custom-dark/gnome-shell/gnome-shell.css.backup.original" 2>/dev/null || true
    
    # Remove Firefox fix directories
    echo "Removing Firefox fix directories..."
    if [ -d "$HOME/.local/share/themes/gtk-custom" ]; then
        rm -rf "$HOME/.local/share/themes/gtk-custom" 2>/dev/null && echo "  Removed gtk-custom directory"
    fi
    if [ -d "$HOME/.local/share/themes/gtk-custom-dark" ]; then
        rm -rf "$HOME/.local/share/themes/gtk-custom-dark" 2>/dev/null && echo "  Removed gtk-custom-dark directory"
    fi
    
    # Remove old copied themes (legacy)
    echo "Removing old copied themes..."
    if [ -d "$HOME/.local/share/themes/custom-copied" ]; then
        rm -rf "$HOME/.local/share/themes/custom-copied" 2>/dev/null && echo "  Removed custom-copied directory"
    fi
    if [ -d "$HOME/.local/share/themes/custom-copied-dark" ]; then
        rm -rf "$HOME/.local/share/themes/custom-copied-dark" 2>/dev/null && echo "  Removed custom-copied-dark directory"
    fi
    if [ -d "$HOME/.themes/custom-flatpak" ]; then
        rm -rf "$HOME/.themes/custom-flatpak" 2>/dev/null && echo "  Removed custom-flatpak directory"
    fi
    if [ -d "$HOME/.themes/custom-flatpak-dark" ]; then
        rm -rf "$HOME/.themes/custom-flatpak-dark" 2>/dev/null && echo "  Removed custom-flatpak-dark directory"
    fi
    
    # Reset Flatpak overrides
    echo "Resetting Flatpak overrides..."
    if command -v flatpak >/dev/null 2>&1; then
        sudo flatpak override --system --reset 2>/dev/null && echo "  Flatpak overrides reset"
    else
        echo "  Flatpak not installed, skipping Flatpak reset"
    fi
    
    # Reset GNOME accent color to default blue for dark theme (GNOME-specific)
    echo "Resetting GNOME accent color to default..."
    if command -v gsettings >/dev/null; then
        # Default blue for dark theme (Adwaita dark uses #1c71d8)
        gsettings reset org.gnome.desktop.interface accent-color 2>/dev/null
        echo "  GNOME accent color reset to default"
    fi
    
    # Reset shell theme (GNOME-specific)
    echo "Resetting GNOME Shell theme..."
    if command -v gsettings >/dev/null; then
        gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null
        echo "  Shell theme reset to default"
    fi
    
    # Reset GTK theme (GNOME-specific)
    echo "Resetting GTK theme..."
    if command -v gsettings >/dev/null; then
        gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null
        echo "  GTK theme reset to default"
    fi
    
    echo ""
    echo "========================================"
    echo "Reset complete!"
    echo "========================================"
    echo ""
    echo "The following has been removed/reset:"
    echo "  ✓ Custom shell themes in ~/.local/share/themes/"
    echo "  ✓ GTK CSS files in ~/.config/gtk-3.0/ and ~/.config/gtk-4.0/"
    echo "  ✓ Desktop Icons extension CSS override"
    echo "  ✓ Desktop Icons extension JavaScript (restored from backup)"
    echo "  ✓ Color Picker extension stylesheets (restored from backup)"
    echo "  ✓ Privacy Indicators extension stylesheets (restored from backup)"
    echo "  ✓ GDM themes in /usr/share/themes/"
    echo "  ✓ Firefox fix directories (gtk-custom, gtk-custom-dark)"
    echo "  ✓ Old copied themes"
    echo "  ✓ Flatpak overrides"
    echo "  ✓ GNOME accent color (reset to default)"
    echo "  ✓ GNOME Shell theme (reset to default)"
    echo "  ✓ GNOME GTK theme (reset to default)"
    echo ""
    echo "You may need to:"
    echo "  1. Log out and back in for changes to take effect"
    echo "  2. Restart applications to see GTK changes"
    echo "  3. Restart GNOME Shell: Alt+F2, type 'r', press Enter"
    echo "  4. Disable and re-enable extensions to restore their original state"
    echo ""
    
    exit 0
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Change GTK accent colors with optional GNOME-specific enhancements"
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
echo "GTK Accent Color Changer"
echo "========================================"
echo "This script will:"
echo "  1. Apply your chosen accent color to GTK3/GTK4 themes"
echo ""
echo "If you're using GNOME, additional options will be available:"
echo "  • Apply accent color to GNOME Shell themes"
echo "  • Apply Firefox/Thunderbird theme fix"
echo "  • Apply Flatpak theme fix"
echo "  • Patch GNOME extensions (if installed)"
echo "  • Apply themes to GDM login screen"
echo "  • Set GNOME accent color in system settings"
echo ""
echo "Note: GTK theme changes work on any desktop environment"
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

# Prompt for foreground color choice
prompt_foreground_color "$accent_color"

# Step 1: Apply GTK overrides (always run, desktop-agnostic)
apply_gtk_accent "$accent_color"

echo ""
# Check if we're in GNOME and ask about GNOME-specific features
if check_gnome; then
    echo "========================================"
    echo "GNOME-Specific Features"
    echo "========================================"
    echo "Detected GNOME desktop environment."
    echo "Additional GNOME-specific theming options are available."
    echo ""
    
    read -p "Apply GNOME-specific theming? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        
        # Step 2: Apply Firefox/Thunderbird fix (creates symlinked themes)
        apply_firefox_fix
        
        # Step 3: Set system theme to gtk-custom-dark
        apply_gtk_custom_dark_theme
        
        echo ""
        # Ask if user wants Flatpak fix
        read -p "Apply Flatpak fix (convert symlinks to copies for Flatpak compatibility)? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            apply_flatpak_fix
        else
            echo "Skipping Flatpak fix. Themes remain as symlinks."
        fi
        
        echo ""
        # Step 4: Extract Adwaita themes (GNOME-specific)
        extract_adwaita_theme
        
        echo ""
        echo "Applying accent color to GNOME Shell themes..."
        if [ -f "$HOME/.local/share/themes/shell-custom/gnome-shell/gnome-shell.css" ]; then
            change_shell_accent "$HOME/.local/share/themes/shell-custom/gnome-shell/gnome-shell.css" "$accent_color"
        fi
        if [ -f "$HOME/.local/share/themes/shell-custom-dark/gnome-shell/gnome-shell.css" ]; then
            change_shell_accent "$HOME/.local/share/themes/shell-custom-dark/gnome-shell/gnome-shell.css" "$accent_color"
        fi
        
        echo ""
        # Step 5: Set GNOME accent color (GNOME-specific)
        set_gnome_accent_color "$accent_color"
        
        echo ""
        # Step 6: Create Desktop Icons extension CSS override (GNOME-specific)
        create_desktop_icons_css "$accent_color"
        
        echo ""
        # Step 7: Patch Desktop Icons extension JavaScript (GNOME-specific)
        patch_desktop_icons_extension "$accent_color"
        
        echo ""
        # Step 8: Patch Color Picker extension stylesheets (GNOME-specific)
        patch_color_picker_extension "$accent_color"
        
        echo ""
        # Step 9: Patch Privacy Indicators extension stylesheets (GNOME-specific)
        patch_privacy_indicators_extension "$accent_color"
        
        echo ""
        # Step 10: Apply to GDM (optional, GNOME-specific)
        apply_gdm_theme
        
        echo ""
        # Step 11: Set shell theme to dark variant (GNOME-specific)
        set_shell_theme_dark
        
    else
        echo "Skipping GNOME-specific theming."
    fi
else
    echo "========================================"
    echo "Note: GNOME desktop not detected"
    echo "========================================"
    echo "Only GTK theme overrides were applied."
    echo "GNOME-specific features are not available."
    echo ""
fi

echo ""
echo "========================================"
echo "Theme customization complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  • GTK3/GTK4 themes configured with accent: $accent_color"
echo "  • Foreground text color: $FOREGROUND_COLOR"
if check_gnome && [[ $REPLY =~ ^[Yy]$ ]] 2>/dev/null; then
    if [ -d "$HOME/.local/share/themes/gtk-custom" ] || [ -d "$HOME/.local/share/themes/gtk-custom-dark" ]; then
        echo "  • Firefox/Thunderbird fix applied"
        echo "  • System GTK theme set to gtk-custom-dark"
    fi
    if [[ $REPLY =~ ^[Yy]$ ]] 2>/dev/null && [ -f "$HOME/.local/share/themes/gtk-custom-dark/index.theme" ]; then
        if [ ! -L "$HOME/.local/share/themes/gtk-custom-dark/gtk-3.0" ]; then
            echo "  • Flatpak fix applied (themes converted to copies)"
        else
            echo "  • Flatpak fix NOT applied (themes remain as symlinks)"
        fi
    fi
    echo "  • GNOME Shell themes created"
    echo "  • GNOME accent color set via gsettings"
    echo "  • GNOME extensions patched (if installed)"
fi

echo ""
echo "Next steps:"
echo "  1. Restart GTK applications to see changes"
if check_gnome && [[ $REPLY =~ ^[Yy]$ ]] 2>/dev/null; then
    echo "  2. System theme set to 'gtk-custom-dark'"
    echo "  3. Restart Firefox/Thunderbird"
    if [ -f "$HOME/.local/share/themes/gtk-custom-dark/index.theme" ]; then
        if [ ! -L "$HOME/.local/share/themes/gtk-custom-dark/gtk-3.0" ]; then
            echo "  4. Flatpak apps can access the copied themes"
        else
            echo "  4. Flatpak apps CANNOT access symlinked themes (apply Flatpak fix if needed)"
        fi
    fi
    echo "  5. Enable User Themes extension in GNOME Extensions"
    echo "  6. Set shell theme to 'shell-custom-dark' in GNOME Tweaks"
    echo "  7. Restart GNOME Shell: Alt+F2, type 'r', press Enter"
fi
echo ""
echo "To reset everything: $0 --reset"
echo "========================================"

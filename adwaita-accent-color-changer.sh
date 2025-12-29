#!/bin/bash

# Force decimal separator to be dot for the entire script
export LC_NUMERIC=C

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

# Function to change accent color in GNOME Shell CSS files
change_shell_accent() {
    local css_file="$1"
    local new_accent="$2"
    
    if [ ! -f "$css_file" ]; then
        echo "Warning: CSS file not found: $css_file"
        return 1
    fi
    
    local fg_color=$(calculate_foreground_color "$new_accent")
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
    sed -i "s/-st-accent-fg-color/${fg_color}/g" "$css_file"
    
    # Replace st-lighten function calls with actual colors
    sed -i "s/st-lighten(-st-accent-color, 4%)/${lighten_4}/g" "$css_file"
    sed -i "s/st-lighten(-st-accent-color, 8%)/${lighten_8}/g" "$css_file"
    
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

# FIXED: Function to apply accent color to GTK themes with proper gsettings format
apply_gtk_accent() {
    local accent_color="$1"
    local gtk3_file="$HOME/.config/gtk-3.0/gtk.css"
    local gtk4_file="$HOME/.config/gtk-4.0/gtk.css"
    local darker_accent=$(calculate_darker_color "$accent_color")
    
    echo "Applying accent color to GTK themes..."
    
    # Ensure gsettings command exists
    command -v gsettings >/dev/null || { echo "Error: gsettings not found."; exit 1; }
    
    # Set accent color in GNOME settings - FIXED: Use proper RGB tuple format
    echo "  Setting GNOME accent color via gsettings..."
    
    # Convert hex to RGB tuple (0-1)
    local hex="${accent_color#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Create RGB tuple string with dot decimal separator using LC_NUMERIC=C
    local rgb_tuple="($(echo "scale=3; $r/255" | bc -l), $(echo "scale=3; $g/255" | bc -l), $(echo "scale=3; $b/255" | bc -l))"
    
    # Set using gsettings
    gsettings set org.gnome.desktop.interface accent-color "$rgb_tuple"
    
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
    
    # Create the CSS file - this will overwrite existing file, which is what we want
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
    
    echo "  Created/Updated: $css_file"
}

# Diagnostic function to check line 1167
diagnose_desktop_icons_js() {
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/gtk4-ding@smedius.gitlab.com"
    local js_file="$ext_dir/app/desktopGrid.js"
    
    echo "=== Checking Desktop Icons Extension ==="
    
    if [ ! -f "$js_file" ]; then
        echo "ERROR: File not found!"
        return 1
    fi
    
    # Show the specific lines with selection colors
    echo ""
    echo "Lines with selection colors:"
    grep -n -B2 -A2 "Prefs.selectColor" "$js_file" | head -30
    
    return 0
}

# FIXED: Function to patch desktop icons extension JavaScript - NOW HANDLES RE-RUNS PROPERLY
patch_desktop_icons_extension() {
    local accent_color="$1"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/gtk4-ding@smedius.gitlab.com"
    local js_file="$ext_dir/app/desktopGrid.js"
    
    echo "Patching Desktop Icons extension JavaScript (rubberband selection)..."
    
    if [ ! -f "$js_file" ]; then
        echo "  Warning: Desktop Icons extension not found at: $js_file"
        echo "  JavaScript patch skipped (extension may not be installed)"
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
    
    # Small verification
    echo ""
    echo "  Sample patched lines near first match (if any):"
    grep -n -E "(red:|green:|blue:).*(${r}|${g}|${b})" "$js_file" | head -n 10 || echo "  (No immediate matches shown)"
    
    # Try to reload the extension
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading extension..."
        gnome-extensions disable gtk4-ding@smedius.gitlab.com >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable gtk4-ding@smedius.gitlab.com >/dev/null 2>&1 || true
        echo "  Extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
}

# FIXED: Function to patch Color Picker extension stylesheets - NOW HANDLES RE-RUNS PROPERLY
patch_color_picker_extension() {
    local accent_color="$1"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/color-picker@tuberry"
    local dark_css="$ext_dir/stylesheet-dark.css"
    local light_css="$ext_dir/stylesheet-light.css"
    
    echo "Patching Color Picker extension stylesheets..."
    
    if [ ! -d "$ext_dir" ]; then
        echo "  Warning: Color Picker extension not found at: $ext_dir"
        echo "  Skipping Color Picker patch (extension may not be installed)"
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
        gnome-extensions disable color-picker@tuberry >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable color-picker@tuberry >/dev/null 2>&1 || true
        echo "  Color Picker extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
}

# FIXED: Function to patch Privacy Indicators Accent Color extension stylesheets - NOW HANDLES RE-RUNS PROPERLY
patch_privacy_indicators_extension() {
    local accent_color="$1"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/privacy-indicators-accent-color@sopht.li"
    local base_css="$ext_dir/stylesheet.css"
    local dark_css="$ext_dir/stylesheet-dark.css"
    local light_css="$ext_dir/stylesheet-light.css"
    
    echo "Patching Privacy Indicators Accent Color extension..."
    
    if [ ! -d "$ext_dir" ]; then
        echo "  Warning: Privacy Indicators extension not found at: $ext_dir"
        echo "  Skipping Privacy Indicators patch (extension may not be installed)"
        return 1
    fi
    
    local fg_color=$(calculate_foreground_color "$accent_color")
    
    echo "  Using accent color: $accent_color"
    echo "  Foreground color: $fg_color"
    
    # Helper function to patch a single CSS file
    patch_css_file() {
        local css_file="$1"
        local accent_color="$2"
        local fg_color="$3"
        
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
            -e "s/-st-accent-fg-color/${fg_color}/g" \
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
        patch_css_file "$base_css" "$accent_color" "$fg_color"
        echo "    Base stylesheet patched"
    else
        echo "  Warning: Base stylesheet not found: $base_css"
    fi
    
    if [ -f "$dark_css" ]; then
        echo "  Patching dark stylesheet..."
        patch_css_file "$dark_css" "$accent_color" "$fg_color"
        echo "    Dark stylesheet patched"
    else
        echo "  Warning: Dark stylesheet not found: $dark_css"
    fi
    
    if [ -f "$light_css" ]; then
        echo "  Patching light stylesheet..."
        patch_css_file "$light_css" "$accent_color" "$fg_color"
        echo "    Light stylesheet patched"
    else
        echo "  Warning: Light stylesheet not found: $light_css"
    fi
    
    echo "  Privacy Indicators extension patched"
    
    if command -v gnome-extensions >/dev/null 2>&1; then
        echo "  Reloading Privacy Indicators extension..."
        gnome-extensions disable privacy-indicators-accent-color@sopht.li >/dev/null 2>&1 || true
        sleep 0.5
        gnome-extensions enable privacy-indicators-accent-color@sopht.li >/dev/null 2>&1 || true
        echo "  Privacy Indicators extension reloaded"
    else
        echo "  Note: 'gnome-extensions' command not found"
        echo "  Please restart GNOME Shell or disable/enable the extension manually"
    fi
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
    
    # Restore original Desktop Icons extension JavaScript
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
    
    # Restore original Color Picker extension stylesheets
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
    
    # Restore original Privacy Indicators extension stylesheets
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
    
    # Remove shell theme backups
    echo "Removing shell theme backups..."
    rm -f "$HOME/.themes/Adwaita-shell-custom-light/gnome-shell/gnome-shell.css.backup.original" 2>/dev/null || true
    rm -f "$HOME/.themes/Adwaita-shell-custom-dark/gnome-shell/gnome-shell.css.backup.original" 2>/dev/null || true
    
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
    echo "  ✓ Desktop Icons extension JavaScript (restored from backup)"
    echo "  ✓ Color Picker extension stylesheets (restored from backup)"
    echo "  ✓ Privacy Indicators extension stylesheets (restored from backup)"
    echo "  ✓ GNOME accent color (reset to default)"
    echo "  ✓ GNOME Shell theme (reset to default)"
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
echo "  4. Create Desktop Icons extension CSS override"
echo "  5. Patch Desktop Icons extension JavaScript (rubberband)"
echo "  6. Patch Color Picker extension stylesheets"
echo "  7. Patch Privacy Indicators extension stylesheets"
echo "  8. Set the GNOME accent color in system settings"
echo "  9. Set GNOME Shell to use the dark variant"
echo ""
echo "Note: JavaScript patches modify extension files directly"
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
# Step 3: Create Desktop Icons extension CSS override
create_desktop_icons_css "$accent_color"

echo ""
# Step 4: Patch Desktop Icons extension JavaScript
patch_desktop_icons_extension "$accent_color"

echo ""
# Step 5: Patch Color Picker extension stylesheets
patch_color_picker_extension "$accent_color"

echo ""
# Step 6: Patch Privacy Indicators extension stylesheets
patch_privacy_indicators_extension "$accent_color"

echo ""
# Step 7: Set shell theme to dark variant
set_shell_theme_dark

echo ""
echo "========================================"
echo "Theme customization complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  • GNOME Shell themes created with accent: $accent_color"
echo "  • GTK3/GTK4 themes configured"
echo "  • Desktop Icons extension CSS override created"
echo "  • Desktop Icons extension JavaScript patched (rubberband)"
echo "  • Color Picker extension stylesheets patched"
echo "  • Privacy Indicators extension stylesheets patched"
echo "  • GNOME accent color set via gsettings"
echo "  • GNOME Shell theme set to dark variant"
echo ""
echo "Important Notes:"
echo "  1. Desktop Icons:"
echo "     • CSS override: ~/.config/com.desktop.ding/stylesheet-override.css"
echo "     • JavaScript patch: Modified extension file with backup"
echo "  2. Color Picker: Modified extension stylesheets with backup"
echo "  3. Privacy Indicators: Modified extension stylesheets with backup"
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
echo "  6. If extensions don't update, disable and re-enable them"
echo ""
echo "Restart GNOME Shell: Alt+F2, type 'r', press Enter"
echo ""
echo "To reset everything: $0 --reset"
echo "========================================"

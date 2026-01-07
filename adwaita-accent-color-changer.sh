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

# MINIMAL FIX: Function to apply accent color to Firefox (URL bar + site selection only)
apply_firefox_accent() {
    local accent_color="$1"
    local darker_accent=$(calculate_darker_color "$accent_color")
    
    echo "========================================"
    echo "Firefox Accent Color Integration"
    echo "========================================"
    echo "Note: This requires the 'firefox-gnome-theme' to be installed."
    echo "      You can install it via the 'addwater' GUI installer."
    echo ""
    
    read -p "Apply accent color to Firefox? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping Firefox integration."
        return 0
    fi
    
    # Clear any previous profile_dir
    local profile_dir=""
    
    # Step 1: Try multiple methods to detect Firefox profile
    echo "Detecting Firefox profile directory..."
    
    # Method 1: Check if user already has a known profile path
    local known_path="$HOME/.mozilla/firefox/3bmln68y.default-release"
    if [ -d "$known_path" ] && [ -d "$known_path/chrome" ]; then
        profile_dir="$known_path"
        echo "  Found known profile: $profile_dir"
    fi
    
    # Method 2: Look for default-release profiles
    if [ -z "$profile_dir" ] && [ -d "$HOME/.mozilla/firefox" ]; then
        local possible_profiles=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -5)
        if [ -n "$possible_profiles" ]; then
            local profile_count=$(echo "$possible_profiles" | wc -l)
            if [ "$profile_count" -eq 1 ]; then
                profile_dir="$possible_profiles"
                echo "  Found single default-release profile: $profile_dir"
            else
                echo "  Found multiple profiles:"
                echo "$possible_profiles" | nl -w2 -s': '
                read -p "  Enter profile number (or 'skip'): " profile_num
                if [[ "$profile_num" =~ ^[0-9]+$ ]]; then
                    profile_dir=$(echo "$possible_profiles" | sed -n "${profile_num}p")
                fi
            fi
        fi
    fi
    
    # Method 3: Parse profiles.ini for the Default=1 profile
    if [ -z "$profile_dir" ] && [ -f "$HOME/.mozilla/firefox/profiles.ini" ]; then
        echo "  Parsing profiles.ini..."
        
        # Look for the profile with Default=1
        local default_profile=$(awk -F= '
            /^\[Profile/ { profile="" }
            /^Default=1/ { default_found=1 }
            /^Path=/ && default_found { 
                profile=$2; 
                default_found=0;
            }
            END { print profile }
        ' "$HOME/.mozilla/firefox/profiles.ini")
        
        if [ -n "$default_profile" ]; then
            local full_path="$HOME/.mozilla/firefox/$default_profile"
            if [ -d "$full_path" ]; then
                profile_dir="$full_path"
                echo "  Found default profile from profiles.ini: $profile_dir"
            fi
        fi
    fi
    
    # Step 2: If auto-detection failed, guide user to about:support
    if [ -z "$profile_dir" ] || [ ! -d "$profile_dir" ]; then
        echo ""
        echo "Please follow these steps:"
        echo "  1. Open Firefox"
        echo "  2. Type 'about:support' in the address bar and press Enter"
        echo "  3. Find the section called 'Application Basics'"
        echo "  4. Look for 'Profile Directory'"
        echo "  5. Click the 'Open Directory' button"
        echo "  6. A file manager will open - that's your profile directory"
        echo ""
        echo "The path should look something like:"
        echo "  /home/yourname/.mozilla/firefox/xxxxxxxx.default-release"
        echo ""
        
        while true; do
            read -p "Enter the full path to your Firefox profile directory (or 'skip'): " profile_dir
            
            if [ -z "$profile_dir" ] || [ "$profile_dir" = "skip" ]; then
                echo "Skipping Firefox integration."
                return 0
            fi
            
            # Expand tilde and handle relative paths
            profile_dir="${profile_dir/#\~/$HOME}"
            
            # Make sure it's an absolute path
            if [[ ! "$profile_dir" = /* ]]; then
                profile_dir="$PWD/$profile_dir"
            fi
            
            # Check if directory exists
            if [ ! -d "$profile_dir" ]; then
                echo "❌ Directory not found: $profile_dir"
                echo "   Please check the path and try again."
                continue
            fi
            
            # Check for chrome directory (firefox-gnome-theme should be here)
            if [ ! -d "$profile_dir/chrome" ]; then
                echo "⚠️  Directory exists but 'chrome' subdirectory not found."
                echo "   Make sure firefox-gnome-theme is installed in this profile."
                read -p "   Continue anyway? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            break
        done
    fi
    
    echo ""
    echo "✅ Using profile directory: $profile_dir"
    
    # Step 3: Check/create directories with proper permissions
    local chrome_dir="$profile_dir/chrome"
    local theme_dir="$chrome_dir/firefox-gnome-theme"
    local custom_css="$theme_dir/customChrome.css"
    local custom_content="$theme_dir/customContent.css"
    
    # Create chrome directory if it doesn't exist
    if [ ! -d "$chrome_dir" ]; then
        echo "  Creating chrome directory..."
        mkdir -p "$chrome_dir" || {
            echo "❌ Failed to create chrome directory."
            echo "   Check permissions for: $profile_dir"
            return 1
        }
    fi
    
    # Check if firefox-gnome-theme is installed
    if [ ! -d "$theme_dir" ]; then
        echo ""
        echo "❌ ERROR: firefox-gnome-theme not found!"
        echo "   Expected directory: $theme_dir"
        echo ""
        echo "Please install it first using one of these methods:"
        echo ""
        echo "METHOD 1: GUI Installer (Recommended)"
        echo "  1. Open Firefox"
        echo "  2. Go to: https://addons.mozilla.org/firefox/addon/addwater/"
        echo "  3. Click 'Add to Firefox'"
        echo "  4. Follow the installation instructions"
        echo ""
        echo "METHOD 2: Command Line Installer"
        echo "  Run this command in terminal:"
        echo "  curl -s -o- https://raw.githubusercontent.com/rafaelmardojai/firefox-gnome-theme/master/scripts/install-by-curl.sh | bash"
        echo ""
        read -p "Press Enter after installation, or any key to skip Firefox theming..."
        echo
        
        # Check again after user claims to have installed
        if [ ! -d "$theme_dir" ]; then
            echo "Theme still not found. Skipping Firefox integration."
            return 1
        fi
    fi
    
    echo "  ✅ firefox-gnome-theme found at: $theme_dir"
    
    # Step 4: Create MINIMAL custom CSS files
    echo ""
    echo "Creating minimal custom CSS files..."
    
    # Create customChrome.css - ONLY Firefox UI fixes
    echo "  Creating customChrome.css..."
    cat <<EOF > "$custom_css"
/* Custom accent color for Firefox GNOME Theme */
/* Generated by GNOME theme script - $(date) */
/* MINIMAL: Only fixes browser UI, leaves websites untouched */

:root {
  --gnome-accent-bg: $accent_color !important;
  --gnome-accent: $darker_accent !important;
  --gnome-accent-active: $(calculate_lighter_color "$accent_color" 10) !important;
}

:root[lwt-sidebar] {
  --gnome-accent-bg: $accent_color !important;
  --gnome-accent: $darker_accent !important;
}

/* Selection colors for BROWSER UI only */
*::selection {
  background-color: $accent_color !important;
}

/* URL bar & SEARCH BAR text selection - dimmed/transparent style */
.urlbar-input::selection,
#urlbar-input::selection,
.searchbar-textbox::selection {
  background-color: color-mix(in srgb, $accent_color 40%, transparent) !important;
}
EOF
    
    # Create customContent.css - MINIMAL: Only site selection + scrollbars
    echo "  Creating customContent.css..."
    cat <<EOF > "$custom_content"
/* MINIMAL custom content styles for Firefox */
/* Generated by GNOME theme script - $(date) */
/* Only changes scrollbars and text selection on websites - nothing else! */


/* Apply accent to TEXT SELECTION ON WEB PAGES only */
::selection {
  background-color: $accent_color !important;
  color: #ffffff !important;
EOF
    
    # Verify files were created
    if [ ! -f "$custom_css" ]; then
        echo "❌ Failed to create $custom_css"
        echo "   Check write permissions for: $theme_dir"
        echo "   You can try: chmod 755 \"$theme_dir\""
        return 1
    fi
    
    if [ ! -f "$custom_content" ]; then
        echo "⚠️  Failed to create $custom_content (but customChrome.css was created)"
    fi
    
    echo "  ✅ Minimal CSS files created successfully!"
    echo "     - $custom_css (browser UI only)"
    echo "     - $custom_content (site selection + scrollbars only)"
    
    # Step 5: Check and display Firefox preference instructions
    echo ""
    echo "For the theme to work, you MUST set these preferences in Firefox:"
    echo ""
    echo "  1. Open Firefox"
    echo "  2. Type 'about:config' in the address bar"
    echo "  3. Click 'Accept the Risk and Continue'"
    echo "  4. Search for each preference below and set it to 'true'"
    echo ""
    echo "Required preferences:"
    echo "  • toolkit.legacyUserProfileCustomizations.stylesheets = true"
    echo "  • svg.context-properties.content.enabled = true"
    echo ""
    echo "How to set:"
    echo "  - Double-click the preference name to toggle it to 'true'"
    echo "  - Or right-click → 'Modify' → 'true' → OK"
    echo ""
    echo "After setting these preferences:"
    echo "  1. Completely close and restart Firefox"
    echo "  2. You should now have:"
    echo "     • Dimmed text selection in URL/search bars"
    echo "     • Your accent color for text selection on websites"
    echo "     • Accent-colored scrollbars"
    echo "     • All website colors remain UNCHANGED"
    echo ""
    
    # Check if preferences are already set
    local prefs_file="$profile_dir/prefs.js"
    if [ -f "$prefs_file" ]; then
        echo "Checking existing preferences..."
        local pref1_set=$(grep -c '"toolkit.legacyUserProfileCustomizations.stylesheets".*true' "$prefs_file" 2>/dev/null || true)
        local pref2_set=$(grep -c '"svg.context-properties.content.enabled".*true' "$prefs_file" 2>/dev/null || true)
        
        if [ "$pref1_set" -gt 0 ] && [ "$pref2_set" -gt 0 ]; then
            echo "✅ Both required preferences are already set!"
        else
            echo "⚠️  Some preferences may not be set correctly."
        fi
    fi
    
    read -p "Press Enter when you're ready to continue..."
    
    echo ""
    echo "========================================"
    echo "Firefox Configuration Summary"
    echo "========================================"
    echo "Profile directory: $profile_dir"
    echo "Theme directory:   $theme_dir"
    echo "Custom CSS files:  ✅ Created"
    echo ""
    echo "IMPORTANT: This minimal approach ONLY affects:"
    echo "  • Firefox UI text selection (dimmed in URL/search bars)"
    echo "  • Website text selection (your accent color)"
    echo "  • Scrollbar colors"
    echo ""
    echo "All website colors (links, buttons, text) remain UNTOUCHED."
    echo ""
    echo "To troubleshoot:"
    echo "  - Check file permissions: ls -la \"$theme_dir/\""
    echo "  - Verify CSS content: cat \"$custom_css\""
    echo "  - Restart Firefox in terminal: firefox --safe-mode"
    echo ""
    
    return 0
}

# Function to apply GNOME Shell themes to GDM
apply_gdm_theme() {
    echo ""
    echo "========================================"
    echo "Apply Themes to GDM (Login Screen)"
    echo "========================================"
    echo "Note: This copies both Light and Dark themes to /usr/share"
    echo "      GDM cannot see user themes in ~/.themes/"
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
    if [ ! -d "$HOME/.themes/Adwaita-shell-custom-dark" ] || [ ! -d "$HOME/.themes/Adwaita-shell-custom-light" ]; then
        echo "❌ Custom themes not found in ~/.themes/"
        echo "   Run the script without GDM option first to create themes"
        return 1
    fi
    
    # Copy BOTH themes to system directory
    echo "  Copying DARK theme to /usr/share/themes/..."
    sudo cp -r "$HOME/.themes/Adwaita-shell-custom-dark" "/usr/share/themes/"
    echo "  Copying LIGHT theme to /usr/share/themes/..."
    sudo cp -r "$HOME/.themes/Adwaita-shell-custom-light" "/usr/share/themes/"
    
    # Set permissions
    sudo chmod -R 755 "/usr/share/themes/Adwaita-shell-custom-dark"
    sudo chmod -R 755 "/usr/share/themes/Adwaita-shell-custom-light"
    
    echo "✅ Both themes copied to system directory"
    echo ""
    
    # Instructions
    echo "How to Apply Theme to GDM:"
    echo ""
    echo "1. Open 'GDM Settings' application."
    echo "2. Go to the 'Appearance' tab."
    echo "3. In the 'Shell theme' dropdown, you should now see:"
    echo "     • Adwaita-shell-custom-dark"
    echo "     • Adwaita-shell-custom-light"
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
    
    # Remove Firefox customizations
    echo "Removing Firefox customizations..."
    find "$HOME/.mozilla/firefox" -name "customChrome.css" -delete 2>/dev/null
    find "$HOME/.mozilla/firefox" -name "customContent.css" -delete 2>/dev/null
    find "$HOME/.mozilla/firefox" -name "customChrome.css.backup.*" -delete 2>/dev/null
    find "$HOME/.mozilla/firefox" -name "customContent.css.backup.*" -delete 2>/dev/null
    echo "  Firefox CSS files removed"
    
    # Remove GDM themes if they exist
    echo "Removing GDM themes..."
    if [ -d "/usr/share/themes/Adwaita-shell-custom-dark" ]; then
        sudo rm -rf "/usr/share/themes/Adwaita-shell-custom-dark" 2>/dev/null
        echo "  GDM dark theme removed"
    fi
    if [ -d "/usr/share/themes/Adwaita-shell-custom-light" ]; then
        sudo rm -rf "/usr/share/themes/Adwaita-shell-custom-light" 2>/dev/null
        echo "  GDM light theme removed"
    fi
    # Also remove default-pure if it exists
    if [ -d "/usr/share/themes/default-pure" ]; then
        sudo rm -rf "/usr/share/themes/default-pure" 2>/dev/null
        echo "  GDM default-pure theme removed"
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
    echo "  ✓ Firefox custom CSS files"
    echo "  ✓ GDM themes in /usr/share/themes/"
    echo "  ✓ GNOME accent color (reset to default)"
    echo "  ✓ GNOME Shell theme (reset to default)"
    echo ""
    echo "You may need to:"
    echo "  1. Log out and back in for changes to take effect"
    echo "  2. Restart applications to see GTK changes"
    echo "  3. Restart GNOME Shell: Alt+F2, type 'r', press Enter"
    echo "  4. Disable and re-enable extensions to restore their original state"
    echo "  5. Restart Firefox to clear theme customizations"
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
echo "  8. Apply accent color to Firefox (optional)"
echo "  9. Apply themes to GDM login screen (optional)"
echo "  10. Set the GNOME accent color in system settings"
echo "  11. Set GNOME Shell to use the dark variant"
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
# Step 7: Apply to Firefox (optional)
apply_firefox_accent "$accent_color"

echo ""
# Step 8: Apply to GDM (optional)
apply_gdm_theme

echo ""
# Step 9: Set shell theme to dark variant
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
echo "  • Firefox custom CSS files created (if selected)"
echo "  • GDM themes applied (if selected)"
echo "  • GNOME accent color set via gsettings"
echo "  • GNOME Shell theme set to dark variant"
echo ""
echo "Firefox theming (minimal approach):"
echo "  • URL/search bar: Dimmed text selection"
echo "  • Websites: Your accent color for text selection + scrollbars"
echo "  • All website colors (links, buttons, text): UNTOUCHED"
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

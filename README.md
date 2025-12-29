# adwaita-accent-color-changer
An amateur, AI-generated script that changes the accent color of GTK3/Libadwaita and the Adwaita GNOME shell theme with a user-specified hex value.

Based on adw-colors' accent color changer (https://github.com/lassekongo83/adw-colors/tree/main/scripts/accent-color-change).
Extracts the gresources of the Adwaita GNOME shell theme to ~/.themes (light and dark). Tested on GNOME 49.

Added a --reset function (sh adwaita-accent-color-changer.sh --reset).

Required: adw-gtk3 theme and User Themes extension for applying the shell theme.

Could be used on other DEs for theming adw-gtk3 and Libadwaita apps. Gtk-engine-murrine may be required. I haven't tested it but it worked with adw-colors' script.

Known issues (need help): Firefox and some elements (illustrations in GNOME settings, ~~color picker extension~~, ~~Gtk4 desktop icons extension~~) aren't themed and instead follow system accent color.

Included a fix for Gtk4 desktop icons – first part applies overrides to ~/.config/com.desktop.ding/stylesheet-override.css, but the second modifies the extension js, as that controls the selection grid highlight and the rubberband color, so it might disappear after extension update – just rerun the script then.

Added a similar fix for color picker. If something breaks, reinstall the extensions.

Theme Adwaita-colors icons: https://github.com/pacu23/adwaita-colors-icons-customizer

<img width="831" height="767" alt="image" src="https://github.com/user-attachments/assets/4bde5f2d-bbdb-49fa-b975-ae123fb052e1" />

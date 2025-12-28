# adwaita-accent-color-changer
An amateur, AI-generated script that changes the accent color of GTK3/Libadwaita and the Adwaita GNOME shell theme with a user-specified hex value.

Based on adw-colors' accent color changer (https://github.com/lassekongo83/adw-colors/tree/main/scripts/accent-color-change).
Extracts the gresources of the Adwaita GNOME shell theme to ~/.themes (light and dark). Tested on GNOME 49.

Added a --reset function (sh adwaita-accent-color-changer.sh --reset).

Required: adw-gtk3 theme and User Themes extension for applying the shell theme.

Could be used on other DEs for theming adw-gtk3 and Libadwaita apps. Gtk-engine-murrine may be required. I haven't tested it but it worked with adw-colors' script.

Some parts of GNOME will still retain the accent color that's specified in GNOME settings. Currently I don't know of an easy way to change that, since it's hard coded into C, so make sure to select a color in settings that would go well with yours, or slate for neutrality.

<img width="831" height="767" alt="image" src="https://github.com/user-attachments/assets/4bde5f2d-bbdb-49fa-b975-ae123fb052e1" />

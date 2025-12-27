# adwaita-accent-color-changer-script
An amateur, AI-generated script that changes the accent color of GTK3/Libadwaita and the Adwaita GNOME shell theme with a user-specified hex value.

Based on adw-colors' accent color changer (https://github.com/lassekongo83/adw-colors/tree/main/scripts/accent-color-change).
Extracts the gresources of the Adwaita GNOME shell theme to ~/.themes (light and dark). Tested on GNOME 49.

As a side effect, the accent color now appears as a selection color on buttons, where it would be gray in default Adwaita. For example in Nautilus, in the side panel. I'm gonna keep that since it might be better. If someone cares about it being removed, do tell.

Required: adw-gtk3 theme and User Themes extension for applying the shell theme.

Could be used on other DEs for theming adw-gtk3 and Libadwaita apps. Gtk-engine-murrine may be required. I haven't tested it but it worked with adw-colors' script.

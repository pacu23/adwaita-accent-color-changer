# adwaita-accent-color-changer
AI-generated script that changes the accent color of GTK3/Libadwaita and the Adwaita GNOME shell theme with a user-specified hex value.

Based on adw-colors' accent color changer (https://github.com/lassekongo83/adw-colors/tree/main/scripts/accent-color-change).
Extracts the gresources of the Adwaita GNOME shell theme to ~/.local/share/themes. Tested on Arch.

Added a --reset function (sh adwaita-accent-color-changer.sh --reset).

**Required: glib2-devel (on Arch, for extracting gresource), adw-gtk3 theme and User Themes extension for applying the shell theme.**

Could be used on other DEs for theming adw-gtk3 and Libadwaita apps. Gtk-engine-murrine may be required. I haven't tested it but it worked with adw-colors' script.

Included optional copying of the shell themes to /usr/share so they are available for GDM, apply via GDM Settings application.

Included a fix for Firefox and Thunderbird: if using adw-gtk3, they do not accept .config overrides and instead follow GNOME's system accent color, due to theme name detection, that's why adw-gtk3 theme optionally gets cloned with symlinked content in .local/share/themes and renamed.

Added Flatpak fix. Aside from the usual permissions for reading .config/gtk-3.0 and gtk-4.0, there's a complication when using with Firefox fix, as your system theme is technically not adw-gtk3, so Flatpak doesn't automatically use the adw-gtk3 package. I don't know how to force it to use it, so instead it uses local theme, the contents of it copied from adw-gtk3, not symlinked, as it can't read symlinks to /usr/share. Also this needs to be set as system theme, it seems, for some apps to obey it.

Included a fix for the following extensions: Gtk4 desktop icons, Accent privacy indicators, Color picker. Modifying the extension's files in ~/.local/share/gnome-shell/extensions (if installed there). It might reset after an update, so just rerun the script. If something breaks, just reinstall the extensions.

If something else needs a fix, tell me.

Note: the illustrations in GNOME settings are hardcoded to follow the GNOME accents, so pick whatever you like from there.

Theme Adwaita-colors icons: https://github.com/pacu23/adwaita-colors-icons-customizer

<img width="831" height="767" alt="image" src="https://github.com/user-attachments/assets/4bde5f2d-bbdb-49fa-b975-ae123fb052e1" />

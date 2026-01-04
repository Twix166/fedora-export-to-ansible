# Rice assets export (fonts/themes/icons)

## What this exports
User-level assets commonly used for ricing:
- Fonts: `~/.local/share/fonts`, `~/.fonts`, plus `~/.config/fontconfig` if present
- Themes: `~/.themes`, `~/.local/share/themes`
- Icons: `~/.icons`, `~/.local/share/icons`
- KDE extras (if present): color schemes, Plasma look-and-feel, desktop themes, Aurorae, wallpapers, SDDM themes
- GTK settings dirs: `~/.config/gtk-3.0`, `~/.config/gtk-4.0`

Files are stored under:
- `files/rice-assets/`

## Apply from your main playbook
In `site.yml`, import this task file **as your user**:

```yaml
- name: Restore rice assets (fonts/themes/icons)
  import_tasks: rice-assets.yml
  become: false
  vars:
    rice_home: "/home/{{ target_user }}"

#!/usr/bin/env bash
set -euo pipefail

# export-rice-assets-to-ansible.sh
# Exports user fonts/themes/icons into an Ansible-friendly bundle.
#
# Output:
#  - files/rice-assets/...  (copied assets)
#  - rice-assets.yml        (tasks to restore)
#  - rice-assets-manifest.txt (what was exported)
#  - rice-assets-packages.txt (optional: related RPM packages if detectable)

OUTDIR="${1:-ansible-export}"
FILESDIR="$OUTDIR/files"
ASSETSDIR="$FILESDIR/rice-assets"

mkdir -p "$ASSETSDIR"

MANIFEST="$OUTDIR/rice-assets-manifest.txt"
PKGMANIFEST="$OUTDIR/rice-assets-packages.txt"
TASKS="$OUTDIR/rice-assets.yml"
README="$OUTDIR/README-rice-assets.md"

# Where user rice assets commonly live
ASSET_PATHS=(
  "$HOME/.local/share/fonts"
  "$HOME/.fonts"
  "$HOME/.themes"
  "$HOME/.icons"
  "$HOME/.local/share/icons"
  "$HOME/.local/share/themes"
  "$HOME/.config/fontconfig"          # fontconfig user overrides
  "$HOME/.config/gtk-3.0"             # GTK theming used by many apps even on KDE
  "$HOME/.config/gtk-4.0"
)

echo "[*] Exporting rice assets (fonts/themes/icons)..."
: > "$MANIFEST"

copy_one() {
  local src="$1"
  local rel="${src#$HOME/}"
  local dst="$ASSETSDIR/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  printf "%s\n" "$src" >> "$MANIFEST"
}

# Copy user assets if present
for p in "${ASSET_PATHS[@]}"; do
  if [[ -d "$p" || -f "$p" ]]; then
    copy_one "$p"
  fi
done

# Also capture common KDE user theme/icon locations (safe if missing)
EXTRA_PATHS=(
  "$HOME/.local/share/color-schemes"
  "$HOME/.local/share/plasma/look-and-feel"
  "$HOME/.local/share/plasma/desktoptheme"
  "$HOME/.local/share/aurorae/themes"
  "$HOME/.local/share/wallpapers"
  "$HOME/.local/share/sddm/themes"
)

for p in "${EXTRA_PATHS[@]}"; do
  if [[ -d "$p" || -f "$p" ]]; then
    copy_one "$p"
  fi
done

# Create a helpful manifest of what fonts/themes/icons exist
echo "[*] Writing package hints (best-effort)..."
: > "$PKGMANIFEST"

if command -v rpm >/dev/null 2>&1; then
  # Best-effort: try to identify RPM packages that own exported files.
  # This works for files under /usr, but user assets won't map to RPMs.
  # Still useful if you also have system theme files referenced in configs.
  {
    echo "# Best-effort RPM owners for theme/icon/font files referenced by your system"
    echo "# (User assets under \$HOME usually won't have RPM owners.)"
    echo
  } >> "$PKGMANIFEST"

  # Look for system theme/icon/font references from KDE/GTK config files we exported (if present)
  # and attempt to find owning RPM packages for matching system paths.
  # This is deliberately conservative.
  REF_FILES=(
    "$HOME/.config/kdeglobals"
    "$HOME/.config/gtk-3.0/settings.ini"
    "$HOME/.config/gtk-4.0/settings.ini"
  )

  tmp_refs="$(mktemp)"
  trap 'rm -f "$tmp_refs"' EXIT

  for rf in "${REF_FILES[@]}"; do
    [[ -f "$rf" ]] || continue
    cat "$rf" >> "$tmp_refs"
    echo >> "$tmp_refs"
  done

  # Extract some likely system paths if present
  # (This won't catch everything; it's just a hint list.)
  grep -Eo '(/usr/share/(fonts|icons|themes)/[^"'\'' ]+)' "$tmp_refs" \
    | sort -u \
    | while IFS= read -r sp; do
        if rpm -qf "$sp" >/dev/null 2>&1; then
          rpm -qf "$sp"
        fi
      done \
    | sort -u >> "$PKGMANIFEST" || true
fi

echo "[*] Writing Ansible tasks..."

cat > "$TASKS" <<'YAML'
---
# Restore fonts/themes/icons (rice assets) into the user's home.
# Run these tasks as the user (become: false), but ensure the destination is correct
# by providing rice_home if your play uses become: true at the top.

- name: Set rice_home default to user's HOME if not provided
  ansible.builtin.set_fact:
    rice_home: "{{ rice_home | default(lookup('env','HOME')) }}"

- name: Ensure base directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - "{{ rice_home }}/.local/share"
    - "{{ rice_home }}/.local/share/fonts"
    - "{{ rice_home }}/.local/share/icons"
    - "{{ rice_home }}/.themes"
    - "{{ rice_home }}/.icons"

- name: Restore rice assets bundle into home directory
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/files/rice-assets/"
    dest: "{{ rice_home }}/"
    mode: preserve

- name: Refresh font cache (if fc-cache exists)
  ansible.builtin.command: fc-cache -f
  changed_when: false
  failed_when: false
YAML

cat > "$README" <<'MD'
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
MD
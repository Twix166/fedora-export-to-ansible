#!/usr/bin/env bash
set -euo pipefail

# export-kde-dconf-to-ansible.sh
# Exports:
#  - dconf dump (if dconf exists)
#  - KDE Plasma user settings (selected ~/.config + ~/.local/share)
# Generates:
#  - files/dconf_dump.txt
#  - files/kde-config/... (copied files)
#  - dconf.yml, kde.yml, site-kde-dconf.yml

OUTDIR="${1:-ansible-export}"
FILESDIR="$OUTDIR/files"
KDE_OUT="$FILESDIR/kde-config"
DCONF_OUT="$FILESDIR/dconf_dump.txt"

mkdir -p "$KDE_OUT"
mkdir -p "$FILESDIR"

echo "[*] Exporting dconf (if available)..."
if command -v dconf >/dev/null 2>&1; then
  # Dump everything; you can narrow later if desired.
  dconf dump / > "$DCONF_OUT" || true
else
  # Create an empty file so Ansible tasks can skip gracefully.
  : > "$DCONF_OUT"
fi

echo "[*] Exporting KDE Plasma config files..."

# Curated list of KDE/Plasma config files that commonly matter.
# Add/remove entries as you like.
KDE_CONFIG_FILES=(
  "$HOME/.config/kdeglobals"
  "$HOME/.config/kwinrc"
  "$HOME/.config/kscreenlockerrc"
  "$HOME/.config/kcminputrc"
  "$HOME/.config/kglobalshortcutsrc"
  "$HOME/.config/plasmarc"
  "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  "$HOME/.config/plasma-localerc"
  "$HOME/.config/plasmashellrc"
  "$HOME/.config/khotkeysrc"
  "$HOME/.config/konsolerc"
  "$HOME/.config/dolphinrc"
  "$HOME/.config/krunnerrc"
  "$HOME/.config/gtkrc-2.0"
  "$HOME/.config/gtk-3.0/settings.ini"
  "$HOME/.config/gtk-4.0/settings.ini"
)

# Curated KDE dirs that often include themes/icons/layout bits.
KDE_CONFIG_DIRS=(
  "$HOME/.config/gtk-3.0"
  "$HOME/.config/gtk-4.0"
  "$HOME/.local/share/color-schemes"
  "$HOME/.local/share/konsole"
  "$HOME/.local/share/plasma"
  "$HOME/.local/share/plasma-systemmonitor"
  "$HOME/.local/share/kxmlgui5"
  "$HOME/.local/share/kxmlgui6"
  "$HOME/.local/share/kactivitymanagerd"
  "$HOME/.local/share/icons"
  "$HOME/.local/share/fonts"
  "$HOME/.themes"
  "$HOME/.icons"
)

# Copy files preserving relative paths under kde-config/
copy_one() {
  local src="$1"
  local rel
  rel="${src#$HOME/}"
  local dst="$KDE_OUT/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

# Copy selected config files if they exist
for f in "${KDE_CONFIG_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    copy_one "$f"
  fi
done

# Copy selected directories if they exist
for d in "${KDE_CONFIG_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    copy_one "$d"
  fi
done

# Also copy ALL KDE-ish rc files (safe + helps completeness), but avoid huge stuff.
# This grabs most ~/.config/*rc, plus plasma/applets config.
echo "[*] Exporting additional KDE rc files from ~/.config..."
find "$HOME/.config" -maxdepth 1 -type f \
  \( -name '*rc' -o -name 'k*' -o -name 'plasma*' \) \
  ! -name '*.lock' ! -name '*.bak' \
  -print0 \
  | while IFS= read -r -d '' f; do
      copy_one "$f"
    done

echo "[*] Writing Ansible task files..."

# dconf restore tasks
cat > "$OUTDIR/dconf.yml" <<'YAML'
---
- name: Restore dconf settings (user)
  become: false
  block:
    - name: Check if dconf dump exists and is non-empty
      ansible.builtin.stat:
        path: "{{ playbook_dir }}/files/dconf_dump.txt"
      register: dconf_dump

    - name: Load dconf database from dump
      ansible.builtin.shell: |
        set -euo pipefail
        dconf load / < "{{ playbook_dir }}/files/dconf_dump.txt"
      args:
        executable: /bin/bash
      when:
        - dconf_dump.stat.exists
        - dconf_dump.stat.size | int > 0
YAML

# KDE restore tasks
cat > "$OUTDIR/kde.yml" <<'YAML'
---
- name: Restore KDE/Plasma user configuration files
  become: false
  block:
    - name: Ensure ~/.config exists
      ansible.builtin.file:
        path: "{{ ansible_env.HOME }}/.config"
        state: directory
        mode: "0755"

    - name: Ensure ~/.local/share exists
      ansible.builtin.file:
        path: "{{ ansible_env.HOME }}/.local/share"
        state: directory
        mode: "0755"

    - name: Copy KDE config bundle into home directory
      ansible.builtin.copy:
        src: "{{ playbook_dir }}/files/kde-config/"
        dest: "{{ ansible_env.HOME }}/"
        mode: preserve

    - name: Note about applying KDE changes
      ansible.builtin.debug:
        msg: >
          KDE settings restored. Some changes require logging out/in.
          Optionally restart Plasma: kquitapp6 plasmashell && kstart6 plasmashell
YAML

# A small standalone playbook you can run or import tasks from
cat > "$OUTDIR/site-kde-dconf.yml" <<'YAML'
---
- name: Restore KDE and dconf settings (local user)
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: /usr/bin/python3

  tasks:
    - import_tasks: kde.yml
    - import_tasks: dconf.yml
YAML

cat > "$OUTDIR/README-kde-dconf.md" <<'MD'
# KDE + dconf export -> Ansible

## What this exports
- dconf dump: `files/dconf_dump.txt` (if `dconf` exists)
- KDE Plasma settings: copied from your home into `files/kde-config/`

## Apply (standalone)
```bash
ansible-playbook -i localhost, site-kde-dconf.yml
MD
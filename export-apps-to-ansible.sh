#!/usr/bin/env bash
set -euo pipefail

# export-to-ansible.sh
# Exports Fedora DNF (user-installed) packages + Flatpaks to an Ansible playbook.

OUTDIR="${1:-ansible-export}"
mkdir -p "$OUTDIR"

# Files
PLAYBOOK="$OUTDIR/site.yml"
VARS_DNF="$OUTDIR/vars_dnf.yml"
VARS_FLATPAK="$OUTDIR/vars_flatpak.yml"
README="$OUTDIR/README.md"

echo "[*] Exporting DNF user-installed packages..."
if ! command -v dnf >/dev/null 2>&1; then
  echo "ERROR: dnf not found." >&2
  exit 1
fi

# dnf repoquery is in dnf-plugins-core on some systems, but often present.
if ! dnf repoquery --help >/dev/null 2>&1; then
  echo "ERROR: 'dnf repoquery' not available. Install with: sudo dnf install -y dnf-plugins-core" >&2
  exit 1
fi

{
  echo "---"
  echo "dnf_packages:"
  dnf -q repoquery --userinstalled --qf '%{name}\n' \
    | tr -s '[:space:]' '\n' \
    | sed '/^$/d' \
    | sort -u \
    | awk '{printf "  - \"%s\"\n", $0}'
} > "$VARS_DNF"

echo "[*] Exporting Flatpaks (user + system)..."
if command -v flatpak >/dev/null 2>&1; then
  # Flatpak app IDs look like: com.valvesoftware.Steam
  # We export installed apps/runtimes separately by scope.
  FLATPAK_USER="$(flatpak list --user --app --columns=application 2>/dev/null | sed '/^\s*$/d' | sort -u || true)"
  FLATPAK_SYSTEM="$(flatpak list --system --app --columns=application 2>/dev/null | sed '/^\s*$/d' | sort -u || true)"

  {
    echo "---"
    echo "flatpak_user_apps:"
    if [[ -n "$FLATPAK_USER" ]]; then
      while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        echo "  - $app"
      done <<< "$FLATPAK_USER"
    else
      echo "  - []"
    fi

    echo ""
    echo "flatpak_system_apps:"
    if [[ -n "$FLATPAK_SYSTEM" ]]; then
      while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        echo "  - $app"
      done <<< "$FLATPAK_SYSTEM"
    else
      echo "  - []"
    fi
  } > "$VARS_FLATPAK"
else
  {
    echo "---"
    echo "flatpak_user_apps: []"
    echo "flatpak_system_apps: []"
  } > "$VARS_FLATPAK"
fi

echo "[*] Writing playbook..."
cat > "$PLAYBOOK" <<'YAML'
---
- name: Configure Fedora workstation apps
  hosts: localhost
  connection: local
  become: true
  gather_facts: true

  vars_files:
    - vars_dnf.yml
    - vars_flatpak.yml

  tasks:
    - name: Ensure DNF packages are installed
    # Note: package module uses dnf on Fedora
      ansible.builtin.package:
        name: "{{ dnf_packages }}"
        state: present

    - name: Ensure Flatpak is installed (if any Flatpaks are listed)
      ansible.builtin.package:
        name: flatpak
        state: present
      when: (flatpak_user_apps | length > 0) or (flatpak_system_apps | length > 0)

    - name: Ensure Flathub remote exists (common default)
      community.general.flatpak_remote:
        name: flathub
        state: present
        flatpakrepo_url: "https://dl.flathub.org/repo/flathub.flatpakrepo"
      when: (flatpak_user_apps | length > 0) or (flatpak_system_apps | length > 0)

    - name: Install user Flatpak apps
      become: false
      community.general.flatpak:
        name: "{{ flatpak_user_apps }}"
        state: present
        method: user
        remote: flathub
      when: flatpak_user_apps is defined and (flatpak_user_apps | length > 0) and (flatpak_user_apps[0] != [])

    - name: Install system Flatpak apps
      community.general.flatpak:
        name: "{{ flatpak_system_apps }}"
        state: present
        method: system
        remote: flathub
      when: flatpak_system_apps is defined and (flatpak_system_apps | length > 0) and (flatpak_system_apps[0] != [])
YAML

cat > "$README" <<'MD'
# Fedora app export -> Ansible

## What this includes
- DNF/RPM packages: `dnf repoquery --userinstalled` (explicit installs)
- Flatpak apps: user + system scopes

## Run
1) Install Ansible and the Flatpak collection:
```bash
sudo dnf install -y ansible
ansible-galaxy collection install community.general
MD

# Fedora app export -> Ansible

## What this includes
- DNF/RPM packages: `dnf repoquery --userinstalled` (explicit installs)
- Flatpak apps: user + system scopes

## Run
1) Install Ansible and the Flatpak collection:
```bash
sudo dnf install -y ansible
ansible-galaxy collection install community.general

# KDE + dconf export -> Ansible

## What this exports
- dconf dump: `files/dconf_dump.txt` (if `dconf` exists)
- KDE Plasma settings: copied from your home into `files/kde-config/`

## Apply (standalone)
```bash
ansible-playbook -i localhost, site-kde-dconf.yml

# Exported DNF enabled repos -> Ansible

## What this does
Exports the *repo IDs* that are enabled on this machine and generates:
- `vars_repos.yml`
- `repos.yml` (tasks to enable those repo IDs)

## Apply
From your Ansible folder:

```bash
ansible-galaxy collection install community.general
ansible-playbook -K -i localhost, site.yml

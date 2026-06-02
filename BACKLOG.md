# Backlog

Backlog items are grouped by horizon rather than commitment. Promote items into `TODO.md` when they are ready to be actively worked.

## Exporter features

- Detect RPM Fusion and other third-party repos with enablement tasks.
- Normalize KDE/dconf output to reduce noisy diffs.
- Capture fonts, GTK themes, icons, shortcuts, and application defaults as separate roles.

## Restore features

- Build a role-based restore playbook with tags for packages, repos, desktop settings, and assets.
- Add preflight checks for Fedora version compatibility.
- Add backup of existing dotfiles/settings before applying changes.

## Developer experience

- Package scripts as a Python CLI.
- Add CI with linting, unit tests, and Ansible checks.

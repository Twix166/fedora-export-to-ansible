# Roadmap

This roadmap describes a practical path from the current repository state toward a more maintainable, reproducible project. Dates are deliberately omitted; sequence matters more than calendar promises.

## Phase 1 - One-button export

- Unify the current export scripts behind one command.
- Make output deterministic and easy to diff.
- Add basic tests and syntax validation.

## Phase 2 - One-button restore

- Create tagged Ansible roles/playbooks for reinstalling packages and desktop configuration.
- Add preflight, backup, and dry-run support.
- Document a clean Fedora restore walkthrough.

## Phase 3 - Shareable workstation profile

- Separate personal assets from generic reusable roles.
- Support multiple Fedora/KDE versions where practical.
- Publish examples that help others bootstrap their own exporter.

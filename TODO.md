# TODO

This document captures the current working priorities for this repository. It is intentionally lightweight: keep it updated as work lands, and move completed items into release notes or the README when they become permanent behaviour.

## Immediate priorities

- [ ] Create a single export command that runs package, repo, dconf, KDE, theme, icon, and font collection.
- [ ] Create a single apply command/playbook for restoring onto a vanilla Fedora install.
- [ ] Add `--dry-run` and `--output-dir` options so exports are repeatable and reviewable.
- [ ] Add tests for package list parsing and repository detection.
- [ ] Document exactly which exported files are personal/stateful and which are safe to share.

## Quality checks

- [ ] Run Ansible syntax checks on generated playbooks.
- [ ] Add sample fixtures for DNF, Flatpak, dconf, and KDE exports.

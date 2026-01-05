# Export to Ansible

This script generates an Ansible file based on the configuration of your Fedora system. This means that you can add apps, make config changes and customisations manually and have the script detect them and export them to an Ansible playbook.

## What happens?

Application detection - The script creates two application lists. One for DNF and one for Flatpak. It writes those lists to two separate *vars_* YAML files.

DNF Repository detection - The script detects which repos are enabled and generates a playbook

dconf and KDE settings detection - Collect all the settings for KDE and dconf and create tasks and a playbook

Themes detection - Export all themes, icons and font settings to a task

## Things to do

1. Create a single main script that can run all exports
1. Create a single script that can run all playbooks or configurations on a vanilla install of Fedora

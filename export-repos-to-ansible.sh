#!/usr/bin/env bash
set -euo pipefail

# export-dnf-repos-to-ansible.sh
# Exports enabled DNF repo IDs into vars + an Ansible task file.

OUTDIR="${1:-ansible-export}"
mkdir -p "$OUTDIR"

VARS_REPOS="$OUTDIR/vars_repos.yml"
TASKS_REPOS="$OUTDIR/repos.yml"
README="$OUTDIR/README-repos.md"

command -v dnf >/dev/null 2>&1 || { echo "ERROR: dnf not found." >&2; exit 1; }

echo "[*] Exporting enabled DNF repositories..."

# Try a couple of formats because DNF4 vs DNF5 output differs.
# We want a clean list of repo IDs, one per line.
get_enabled_repos() {
  # DNF5 often supports --json for repolist
  if dnf repolist --help 2>/dev/null | grep -q -- '--json'; then
    # Parse minimal JSON without jq (best-effort, but usually stable)
    # If you have jq installed, you can swap this for a proper jq parse.
    dnf -q repolist --enabled --json \
      | tr '{},[]' '\n' \
      | sed -n 's/^[[:space:]]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    return
  fi

  # Classic text output: extract first column repo id lines.
  # "repolist:" line and headers should be ignored.
  dnf -q repolist --enabled 2>/dev/null \
    | sed -e '1,5{/repo id/d;}' \
    | awk '
        BEGIN{inlist=0}
        /repo id/ {inlist=1; next}
        /^repolist:/ {next}
        NF==0 {next}
        inlist==1 {print $1}
      '
}

REPOS="$(get_enabled_repos | sed '/^\s*$/d' | sort -u)"

if [[ -z "${REPOS}" ]]; then
  echo "ERROR: Could not determine enabled repos from 'dnf repolist --enabled' output." >&2
  exit 1
fi

# Write vars file
{
  echo "---"
  echo "dnf_enabled_repos:"
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    printf "  - \"%s\"\n" "$repo"
  done <<< "$REPOS"
} > "$VARS_REPOS"

# Write task file (includeable from your main playbook)
cat > "$TASKS_REPOS" <<'YAML'
---
# Enable exported DNF repos
# Requires: ansible-galaxy collection install community.general
- name: Ensure exported DNF repos are enabled
  community.general.dnf_config_manager:
    name: "{{ dnf_enabled_repos }}"
    state: enabled
YAML

# README
cat > "$README" <<'MD'
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
MD

#!/usr/bin/env bash
set -euo pipefail

# export-dnf-repos-to-ansible.sh
# Exports enabled DNF repo IDs into vars + generates an Ansible task file that
# enables them by editing /etc/yum.repos.d/*.repo (DNF5-safe; Fedora 43).

OUTDIR="${1:-ansible-export}"
mkdir -p "$OUTDIR"

VARS_REPOS="$OUTDIR/vars_repos.yml"
TASKS_REPOS="$OUTDIR/repos.yml"
README="$OUTDIR/README-repos.md"

command -v dnf >/dev/null 2>&1 || { echo "ERROR: dnf not found." >&2; exit 1; }

echo "[*] Exporting enabled DNF repositories..."

get_enabled_repos() {
  # Prefer JSON if supported (DNF5 commonly has it)
  if dnf repolist --help 2>/dev/null | grep -q -- '--json'; then
    dnf -q repolist --enabled --json \
      | tr '{},[]' '\n' \
      | sed -n 's/^[[:space:]]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    return
  fi

  # Fallback: parse text output
  dnf -q repolist --enabled 2>/dev/null \
    | awk '
        BEGIN{inlist=0}
        /repo id/ {inlist=1; next}
        /^repolist:/ {next}
        NF==0 {next}
        inlist==1 {print $1}
      '
}

# Make sure we have one repo id per line, no whitespace surprises
REPOS="$(get_enabled_repos | tr -s '[:space:]' '\n' | sed '/^$/d' | sort -u)"

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

echo "[*] Writing repos.yml (DNF5-safe)..."
cat > "$TASKS_REPOS" <<'YAML'
---
# Enable exported DNF repos by editing repo files directly (DNF5-safe).
# We can't loop over a block, so we loop over an include_tasks.

- name: Check if /etc/yum.repos.d exists
  ansible.builtin.stat:
    path: /etc/yum.repos.d
  register: yum_repos_d

- name: Enable exported DNF repos
  ansible.builtin.include_tasks: _enable_one_repo.yml
  loop: "{{ dnf_enabled_repos }}"
  loop_control:
    label: "{{ item }}"
  when: yum_repos_d.stat.exists and yum_repos_d.stat.isdir
YAML

cat > "$OUTDIR/_enable_one_repo.yml" <<'YAML'
---
# Enables a single repo id = {{ item }}

- name: Find repo file containing section [{{ item }}]
  ansible.builtin.shell: |
    set -euo pipefail
    grep -Rsl --include='*.repo' -m1 -E '^\[{{ item | regex_escape() }}\]\s*$' /etc/yum.repos.d || true
  args:
    executable: /bin/bash
  register: repo_file_match
  changed_when: false
  no_log: true

- name: Enable repo {{ item }} in matched file
  ansible.builtin.ini_file:
    path: "{{ repo_file_match.stdout }}"
    section: "{{ item }}"
    option: enabled
    value: "1"
    no_extra_spaces: true
  when: repo_file_match.stdout | length > 0
YAML


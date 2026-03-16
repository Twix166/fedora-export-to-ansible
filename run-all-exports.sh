#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/Twix166/fedora-export-to-ansible/main"
WORKDIR="${TMPDIR:-/tmp}/fedora-export-to-ansible.$$"
OUTPUT_DIR="${1:-$PWD/ansible-export}"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

echo "==> Checking environment"
need_cmd bash
need_cmd curl

if [[ -r /etc/fedora-release ]]; then
  echo "Fedora detected: $(< /etc/fedora-release)"
else
  echo "Warning: this does not look like Fedora. Continuing anyway." >&2
fi

mkdir -p "$WORKDIR" "$OUTPUT_DIR"
cd "$WORKDIR"

echo "==> Downloading exporter scripts from GitHub"
scripts=(
  export-repos-to-ansible.sh
  export-apps-to-ansible.sh
  export-themes-to-ansible.sh
  export-dconf-kde-settings-to-ansible.sh
)

for script in "${scripts[@]}"; do
  curl -fsSLo "$script" "${REPO_RAW_BASE}/${script}"
  chmod +x "$script"
done

echo "==> Running exporters into: $OUTPUT_DIR"
for script in "${scripts[@]}"; do
  echo "----> $script"
  "./$script" "$OUTPUT_DIR"
done

echo
echo "Done."
echo "Your Ansible export is in:"
echo "  $OUTPUT_DIR"

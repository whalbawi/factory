#!/usr/bin/env bash
# Factory installer — installs Factory skills for Claude Code.
#
# Usage:
#   ./install.sh              # interactive — prompts for install mode
#   ./install.sh --global     # install to ~/.claude/skills/
#   ./install.sh --local      # install to ./skills/ in the current project
#   ./install.sh --uninstall  # remove globally installed Factory skills

set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$FACTORY_DIR/skills"
GLOBAL_DIR="$HOME/.claude/skills"

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' RED='' RESET=''
fi

info()  { echo -e "${GREEN}[ok]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[warn]${RESET} $1"; }
error() { echo -e "${RED}[error]${RESET} $1" >&2; }

# Verify the skills source directory exists
if [ ! -d "$SKILLS_SRC" ]; then
  error "Cannot find skills/ directory at $SKILLS_SRC"
  error "Run this script from the Factory repository root."
  exit 1
fi

# Collect skill names
skills=()
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skills+=("$(basename "$skill_dir")")
done

if [ ${#skills[@]} -eq 0 ]; then
  error "No skills found in $SKILLS_SRC"
  exit 1
fi

install_global() {
  echo ""
  echo -e "${BOLD}Installing Factory skills globally to $GLOBAL_DIR${RESET}"
  echo ""

  mkdir -p "$GLOBAL_DIR"

  for name in "${skills[@]}"; do
    target="$GLOBAL_DIR/$name"

    # If a symlink or directory already exists, back it up
    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ -L "$target" ]; then
        existing=$(readlink "$target")
        if [ "$existing" = "$SKILLS_SRC/$name" ]; then
          info "$name — already linked, skipping"
          continue
        fi
      fi
      warn "$name — backing up existing to ${target}.bak"
      rm -rf "${target}.bak"
      mv "$target" "${target}.bak"
    fi

    # Symlink the entire skill directory so future files are included
    ln -s "$SKILLS_SRC/$name" "$target"
    info "$name — linked"
  done

  echo ""
  echo -e "${BOLD}Installed ${#skills[@]} skills.${RESET}"
  echo "Skills are symlinked — updates to the Factory repo are reflected immediately."
  echo ""
  echo "Try it: type /factory in any Claude Code session."
}

install_local() {
  local dest="${1:-.}/skills"

  echo ""
  echo -e "${BOLD}Installing Factory skills locally to $dest${RESET}"
  echo ""

  mkdir -p "$dest"

  for name in "${skills[@]}"; do
    target="$dest/$name"

    if [ -d "$target" ]; then
      warn "$name — already exists, overwriting"
      rm -rf "$target"
    fi

    # Copy the entire skill directory (SKILL.md + any supporting files)
    cp -r "$SKILLS_SRC/$name" "$target"
    info "$name — copied"
  done

  echo ""
  echo -e "${BOLD}Installed ${#skills[@]} skills to $dest${RESET}"
  echo "Skills are copied — they will not receive updates from the Factory repo."
  echo "To update, re-run: $0 --local"
}

uninstall_global() {
  echo ""
  echo -e "${BOLD}Uninstalling Factory skills from $GLOBAL_DIR${RESET}"
  echo ""

  removed=0
  for name in "${skills[@]}"; do
    target="$GLOBAL_DIR/$name"

    if [ -L "$target" ]; then
      existing=$(readlink "$target")
      if [[ "$existing" == *"/factory/"* ]]; then
        rm "$target"
        info "$name — removed"
        removed=$((removed + 1))

        # Restore backup if one exists
        if [ -e "${target}.bak" ]; then
          mv "${target}.bak" "$target"
          info "$name — restored backup"
        fi
      else
        warn "$name — symlink points elsewhere ($existing), skipping"
      fi
    elif [ -d "$target" ]; then
      warn "$name — is a directory (not a Factory symlink), skipping"
    else
      # Not installed
      true
    fi
  done

  echo ""
  if [ $removed -gt 0 ]; then
    echo -e "${BOLD}Removed $removed skills.${RESET}"
  else
    echo "No Factory skills found to remove."
  fi
}

show_usage() {
  echo "Factory Installer"
  echo ""
  echo "Usage:"
  echo "  ./install.sh              Interactive mode"
  echo "  ./install.sh --global     Install to ~/.claude/skills/ (symlinks)"
  echo "  ./install.sh --local      Install to ./skills/ (copies)"
  echo "  ./install.sh --uninstall  Remove globally installed Factory skills"
  echo ""
  echo "Skills found: ${skills[*]}"
}

# Parse arguments
case "${1:-}" in
  --global)
    install_global
    ;;
  --local)
    install_local "${2:-.}"
    ;;
  --uninstall)
    uninstall_global
    ;;
  --help|-h)
    show_usage
    ;;
  "")
    # Interactive mode
    echo ""
    echo -e "${BOLD}Factory Installer${RESET}"
    echo ""
    echo "Found ${#skills[@]} skills: ${skills[*]}"
    echo ""
    echo "How would you like to install?"
    echo ""
    echo "  1) Global   — symlink to ~/.claude/skills/"
    echo "               Available in all projects. Auto-updates with repo."
    echo ""
    echo "  2) Local    — copy to ./skills/ in the current directory"
    echo "               Versioned with your project. Manual updates."
    echo ""
    echo "  3) Cancel"
    echo ""
    read -rp "Choice [1/2/3]: " choice

    case "$choice" in
      1) install_global ;;
      2) install_local "." ;;
      3) echo "Cancelled." ;;
      *) error "Invalid choice: $choice"; exit 1 ;;
    esac
    ;;
  *)
    error "Unknown option: $1"
    show_usage
    exit 1
    ;;
esac

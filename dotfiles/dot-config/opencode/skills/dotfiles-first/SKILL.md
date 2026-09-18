---
name: dotfiles-first
description: Route config and setup tweaks to the nixos-dotfiles repo. Use this skill whenever the user asks to tweak configs, update skills, change editor/shell/tool setup, or adjust anything in ~/.config or ~/ dotfiles — even if they do not mention dotfiles explicitly. The live config paths are read-only nix-store symlinks; the dotfiles repo is the only writable source.
---

# Dotfiles-first

This machine's configs are managed by home-manager from
`~/Projects/nixos-dotfiles`. The live paths (`~/.config/...`, etc.)
are symlinks into the nix store and are **read-only**. Never edit them
in place and never treat "read-only file system" as a dead end — it
means you are editing the wrong copy.

## Rules

- Any request touching configs, skills, editor/shell/tool setup, or
  `~/.config` / `~/` dotfiles belongs in `~/Projects/nixos-dotfiles`.
- Path mapping: `dotfiles/dot-<name>/...` in the repo maps to
  `~/...`  on the machine. `dot-` prefix becomes `dot`: `dot-config`
  → `.config`, `dot-local` → `.local`, `dot-zshrc` → `.zshrc`, etc.
  - Example: live `~/.config/opencode/skills/cli-first-repos/SKILL.md`
    is sourced from
    `dotfiles/dot-config/opencode/skills/cli-first-repos/SKILL.md`.
- Wiring lives alongside: `home/`, `modules/`, `hosts/` (nix), plus
  `install.sh` / `verify.sh` at the repo root. If a config file alone
  does not take effect, check whether a nix module references it
  (e.g. `home/apps/dotfiles.nix`).
- After editing, do not commit, push, or rebuild unless asked. Report
  what changed and tell the user to rebuild when ready — rebuilding is
  their step.

## Why

Editing the live symlink target fails with "read-only file system",
and even if a write succeeded it would be wiped on the next rebuild.
The dotfiles repo is versioned, so changes there survive rebuilds and
apply to every session afterward. This is also why "update a skill"
means editing the skill source under
`dotfiles/dot-config/opencode/skills/<name>/SKILL.md`, not the
symlinked copy under `~/.config/opencode/skills/`.

## Examples

**Example 1 — tweak a skill:**
User: "update that cli skill to also cover GitLab"
Do: edit
`~/Projects/nixos-dotfiles/dotfiles/dot-config/opencode/skills/cli-first-repos/SKILL.md`,
then say "rebuild when ready".
Don't: attempt to write `~/.config/opencode/skills/...` and stop at
the read-only error.

**Example 2 — change tool config:**
User: "switch my terminal font"
Do: find the terminal config under `~/Projects/nixos-dotfiles/dotfiles/`
(e.g. `dot-config/kitty/`, `dot-config/ghostty/`), edit there, report,
await rebuild.
Don't: edit `~/.config/kitty/` directly.

**Example 3 — new setup instruction:**
User: "remember that I prefer X for all future sessions"
Do: if it is a repo-data habit, extend the relevant skill in dotfiles;
if it is machine setup, put it in the right dotfiles path or nix
module. Never store machine setup in a project's working tree.

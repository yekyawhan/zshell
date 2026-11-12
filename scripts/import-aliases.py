#!/usr/bin/env python3
"""Carry a user's existing shell aliases/exports into local.zsh.

Why: the installer replaces ~/.zshrc. Anyone who kept aliases inline in their old
~/.zshrc (or in ~/.bashrc / ~/.bash_aliases) would silently lose them. This script
harvests the functional lines from those files and writes them into
~/.config/y3kh/local.zsh, which .zshrc sources LAST — so the new shell has both the
themed setup and the user's own aliases, with nothing lost.

Usage:
    import-aliases.py [--into PATH] [--dry-run] FILE [FILE ...]

Behaviour:
  * only alias / export / one-line function definitions are taken
  * comment-only lines and shell boilerplate are dropped
  * lines that look like they carry a secret are SKIPPED and reported
  * the result is written into a marked block, so re-running replaces it instead
    of appending duplicates
  * a line already present elsewhere in the target file is not repeated
"""

import argparse
import datetime
import os
import re
import shutil
import sys

BEGIN = "# ─── imported from your previous shell config (zshell installer) ───"
END = "# ─── end of imported block ───"

ALIAS_RE = re.compile(r"^\s*alias\s+([A-Za-z0-9_.:-]+)\s*=")
EXPORT_RE = re.compile(r"^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=")
FUNC_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{[^{}]*\}\s*;?\s*$")
FUNC_NAME_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)")

# things that are part of a stock shell config or belong to the theme, not the user
BOILERPLATE = re.compile(
    r"(oh-my-zsh|oh-my-posh|ZSH_THEME|ZSH=|plugins=\(|compinit|autoload|p10k|"
    r"zstyle\s|fzf-tab|zsh-autosuggestions|zsh-syntax-highlighting|"
    r"HISTSIZE|HISTFILESIZE|SAVEHIST|HISTFILE|HISTCONTROL|histappend|"
    r"checkwinsize|shopt\s|dircolors|lesspipe|debian_chroot|"
    r"bash_completion|case\s+\$-|^\s*return|^\s*fi\b|^\s*done\b|"
    r"^\s*source\s|^\s*\.\s+/|^\s*\.\s+~|"
    r"y3kh/local\.zsh|Antigravity|nvm\.sh)",
    re.I,
)
SECRETISH = re.compile(
    r"(sudo\s+-S|echo\s+'[^']*'\s*\|\s*sudo|password|passwd|token|secret|"
    r"api[-_]?key|PRIVATE KEY|BEGIN OPENSSH|AWS_SECRET|Bearer\s)",
    re.I,
)


def harvest(path):
    """Return (taken, skipped_secret, unreadable) for one file."""
    taken, secrets = [], []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        return [], [], str(exc)

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if BOILERPLATE.search(stripped):
            continue
        is_functional = (
            ALIAS_RE.match(line) or EXPORT_RE.match(line) or FUNC_RE.match(line)
        )
        if not is_functional:
            continue
        m = FUNC_NAME_RE.match(line)
        if m and not FUNC_RE.match(line):
            continue                      # multi-line function: leave it alone
        if SECRETISH.search(stripped):
            secrets.append((path, line))
            continue
        taken.append((path, line.strip()))
    return taken, secrets, None


def strip_block(text):
    """Remove a previously imported block (idempotent re-runs)."""
    out, skip = [], False
    for line in text.splitlines():
        if line.strip().startswith(BEGIN.strip()):
            skip = True
            continue
        if line.strip().startswith(END.strip()):
            skip = False
            continue
        if not skip:
            out.append(line)
    return "\n".join(out).rstrip("\n") + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--into", default=os.path.expanduser("~/.config/y3kh/local.zsh"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    sources = [f for f in args.files if f and os.path.isfile(f)]
    if not sources:
        print("  · no previous shell config found to import from")
        return 0

    target = args.into
    try:
        existing = open(target, encoding="utf-8", errors="replace").read()
    except OSError:
        existing = ""
    if not existing:
        print(f"  ! {target} not found — nothing to import into")
        return 1

    taken, secrets = [], []
    for src in sources:
        t, s, err = harvest(src)
        taken += t
        secrets += s
        if err:
            print(f"  · skipped {src}: {err}")

    if not taken and not secrets:
        print(f"  · {len(sources)} shell config file(s) read — nothing to carry over")
        return 0

    base = strip_block(existing)
    present = set(base.splitlines())

    kept, seen = [], set()
    for src, line in taken:
        key = re.sub(r"\s+", " ", line)
        if key in seen or line in present:
            continue
        seen.add(key)
        kept.append((src, line))

    if not kept and not secrets:
        print("  · your aliases are already present — nothing new to import")
        return 0

    if kept:
        stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        block = [BEGIN,
                 f"# imported {stamp} from: " + ", ".join(os.path.basename(s) for s in sources),
                 ""]
        by_src = {}
        for src, line in kept:
            by_src.setdefault(os.path.basename(src), []).append(line)
        for src, lines in by_src.items():
            block.append(f"# ── from {src} ──")
            block += lines
            block.append("")
        block.append(END)
        new_text = base.rstrip("\n") + "\n\n" + "\n".join(block) + "\n"

        if args.dry_run:
            print(f"  + would carry over {len(kept)} lines into {target}")
        else:
            shutil.copy2(target, target + ".before-import")
            with open(target, "w", encoding="utf-8") as fh:
                fh.write(new_text)
            print(f"  ✔ carried over {len(kept)} alias/export lines into {target}")
            print(f"    (previous copy: {os.path.basename(target)}.before-import)")

    if secrets:
        names = ", ".join(sorted({os.path.basename(p) for p, _ in secrets}))
        print(f"  ! {len(secrets)} line(s) in {names} looked like they contain a secret")
        print("    and were NOT imported. Check them yourself if you still want them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

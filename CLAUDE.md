# CLAUDE.md

Guidance for Claude Code when working in this repo. Keep this file under 200 lines.

## What this repo is

Personal dotfiles for a mise + direnv + uv Python workflow plus an interactive
zsh setup (oh-my-zsh + Powerlevel10k). `install.sh` symlinks the mise/direnv
config and **copies** `zsh/` into `$HOME`. See `README.md` for the layout.

The repo is **public**. Treat every file and every commit as world-readable.

## Hard rules

1. **Never commit secrets.** No tokens, passwords, private keys, internal IPs
   or hostnames. Real credentials live in `~/.local/user-secrets/` (git-ignored)
   and are scaffolded from `examples/*.example` with empty values only.
2. **Scan for secrets before every push.** Run `gitleaks git` (full history)
   and `gitleaks dir` (working tree) and confirm both report no leaks. If either
   finds something, stop: remove it, rewrite history if it was committed, and
   rescan. Do not push, and do not "fix it in a follow-up".
3. **Never push directly to `main`.** `main` is protected by a GitHub ruleset
   with no bypass actors, including the repo owner. Every change goes through a
   branch and a pull request, then a merge via the PR.
4. **No force pushes, no history rewrites on `main`.** If history must be
   rewritten to purge a secret, say so explicitly and get confirmation first.
5. **Per-host config stays out of the repo.** Machine-specific PATH entries,
   aliases and ssh shortcuts belong in `~/.zshrc.local`, which is git-ignored.

## Secrets scanning: three layers

All three must stay in place. Do not weaken or remove any of them.

| Layer | Where | What it does |
| --- | --- | --- |
| GitHub | repo settings | Secret scanning + push protection reject pushes server-side |
| git | `.githooks/pre-push` | gitleaks scans the pushed range and working tree; blocks on a leak |
| Claude Code | `.claude/settings.json` | PreToolUse hook scans before any Bash command containing `git push`; blocks on a leak or if gitleaks is missing |

Setup once per clone:

```sh
brew install gitleaks            # macOS; Arch/CachyOS: sudo pacman -S gitleaks
git config core.hooksPath .githooks
```

`install.sh` does both (gitleaks only if missing).

If the Claude Code hook blocks a push, the reason is in its stderr. Fix the
underlying leak; never bypass the hook by rewording the command.

## Branch and PR workflow

```sh
git switch -c <topic>
# ...edit, commit...
gitleaks git --no-banner . && gitleaks dir --no-banner .
git push -u origin <topic>
gh pr create --fill
gh pr merge --squash --delete-branch   # after review
```

Rules enforced on `main` by the ruleset: pull request required, linear history,
no force pushes, no deletions, conversation resolution required. Required
approvals are 0 because a solo owner cannot approve their own PR.

## Conventions

- Shell scripts: `bash` with `set -euo pipefail`; check with `bash -n`. The zsh
  files are checked with `zsh -n`.
- `install.sh` must stay idempotent and back up anything it replaces.
- Commit messages: short imperative subject, body explains why.
- Do not add tools to `install.sh` unless a tracked file actually uses them.

# Git workflow (OpenWrite mega-repo)

This repository is a **product workspace** plus **local reference clones** of other apps. Git is configured so only OpenWrite sources and documentation are versioned.

## Branch strategy

- **`main`** — always buildable; merge via PR or fast-forward after review.
- **Feature branches** — `feature/<short-topic>`, `fix/<issue>`, or `chore/<task>` branched from `main`; rebase or merge `main` before opening a PR.

## Commit message style

Use [Conventional Commits](https://www.conventionalcommits.org/) in the imperative mood:

- `feat:` — user-visible capability
- `fix:` — bug fix
- `docs:` — documentation only
- `chore:` — tooling, repo hygiene, non-product code
- `refactor:` — behavior-preserving structure change

Example: `feat: add vault unlock with Keychain-backed passphrase`

Keep the subject line under ~72 characters; add a body when context is non-obvious.

## What is tracked vs reference-only

| Tracked | Reference-only (ignored) |
|---------|---------------------------|
| `OpenWrite/` — Xcode app, Swift sources | `reor-main/`, `AFFiNE-canary/`, `anytype-ts-develop/` |
| `docs/` — master plan, this file | `logseq-master/`, `massCode-main/`, `rem-main/` |
| Root `README.md`, `.gitignore` | `buffer/` (Buffer.app binary), empty Obsidian placeholder |
| OpenWrite-specific config at repo root (when added) | `node_modules/`, `dist/`, `build/` inside clones |

Reference trees are for **reading and comparison**, not for shipping in OpenWrite. Do not `git add` them unless you deliberately adopt [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) or subtree vendoring.

### REM / rem copy folders

If you add a local **Rem** or similar upstream copy, ignore it via root `.gitignore`:

- `rem/` — generic folder name
- `rem-main/` — already ignored (current layout)
- `REM*/` — any `REM`-prefixed copy directory

Document the exact folder name in this table when you add one.

## Submodule alternative

Instead of ignoring large clones, you can pin them as **submodules** pointing at upstream URLs:

```bash
git submodule add <url> reor-main
```

Submodules record a commit SHA in the parent repo; teammates run `git submodule update --init --recursive`. Use submodules only when you need reproducible reference versions in CI; otherwise keep clones local and ignored (default for this workspace).

## Daily commands

```bash
/opt/homebrew/bin/git status
/opt/homebrew/bin/git add OpenWrite/ docs/ README.md
/opt/homebrew/bin/git commit -m "feat: ..."
```

Use Homebrew Git (`/opt/homebrew/bin/git`) when it differs from Apple’s `/usr/bin/git`.

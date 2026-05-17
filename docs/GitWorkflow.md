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

Reference trees stay **out of git** by default (local clones). Product code lives in `OpenWrite/`. What you may **copy or port** into `OpenWrite/` depends on license — not on whether the tree is tracked.

### What may be copied into `OpenWrite/` vs not

| Path | License | In `OpenWrite/` |
|------|---------|-----------------|
| `reor-main/` | AGPL-3.0 | **Yes** — port/adapt with **link/comply** (notices, source offer, counsel as needed) |
| `logseq-master/` | AGPL-3.0 | **Yes** — same as Reor |
| `massCode-main/` | AGPL-3.0 | **Yes** — same as Reor |
| `AFFiNE-canary/` | MIT (frontend) · EE (`packages/backend/server`) | **Yes** for MIT frontend code/patterns + attribution; **no** EE server or BlockSuite bundle |
| `rem-main/`, `rem/`, `REM*/` | MIT | **Yes** — preserve MIT copyright in file or `NOTICE` |
| `anytype-ts-develop/` | ASAL 1.0 | **No** — inspiration-only; do not commit ported Anytype snippets |
| `buffer/` | Proprietary | **No** — binary/UX reference only |

Do not `git add` reference trees unless you deliberately adopt [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules). When porting, follow [Contributing/DocumentationStandards.md](./Contributing/DocumentationStandards.md) for attribution.

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

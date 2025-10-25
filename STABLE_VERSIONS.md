# Stable versions and rollback points

This file records stable tags and branches you can use to quickly and safely roll back the repository to a known-good state. Keep this file up to date whenever you create an annotated release tag or a stable branch.

## Current stable entries

- Name: v2.5.2
  - Tag: `v2.5.2`
  - Commit: `32771c2150f86146c9b15dc49f6d170a48d87356`
  - Branch: `main`
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v2.5.2
  - Created: 2025-10-25

- Name: v2.5.1
  - Tag: `v2.5.1`
  - Commit: `a5f05c828361aa1744f285ad43c327c2e9d1d9d4`
  - Branch: `main`
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v2.5.1
  - Created: 2025-10-24

- Name: v1.1
  - Tag: `v1.1`
  - Commit: `000e0fe218a2d53af6b26dfdc08a6c6da18307a4`
  - Branch: `stable/v1.1` (pushed to `origin/stable/v1.1`)
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v1.1
  - Created: 2025-10-10

## Why this file exists

If you need to revert to a safe state quickly (for example after a problematic change), this file gives you an explicit tag and branch to check out. The `stable/*` branches are intended as protected rollback points — they should only be updated intentionally (for small hotfixes) and not for routine development.

## Quick recovery commands

Switch to the stable branch (safe, editable):

```bash
git fetch origin
git checkout stable/v1.1
```

Create a hotfix branch from the stable point:

```bash
git checkout -b hotfix/from-v1.1 stable/v1.1
# make fix, commit
git push origin hotfix/from-v1.1
```

Inspect the tag information:

```bash
git show v1.1
git tag -n v1.1
```

Force-reset `main` to the stable point (dangerous; only when you really want to override history):

```bash
git checkout main
git reset --hard stable/v1.1
git push --force-with-lease origin main
```

## How to add a new stable entry

When you create a new annotated tag and push it as a release, add a short entry here and (optionally) create a `stable/<tag>` branch that points to that tag. Example:

```bash
# create annotated tag
git tag -a v1.2 -m "v1.2 — description"
git push origin v1.2

# create stable branch from tag and push
git branch stable/v1.2 v1.2
git push origin stable/v1.2
```

## Notes

- This file is intentionally simple plain text in the repository root so it is visible to other collaborators and any external automation that reads the repository.
- If you prefer a different location or machine-readable format (JSON/YAML), we can add that and keep both in sync.

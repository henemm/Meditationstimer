> MOVED TO DOCS/archive on 2025-10-12 — archival copy of stable versions list

````markdown
# Stable versions and rollback points

This file records stable tags and branches you can use to quickly and safely roll back the repository to a known-good state. Keep this file up to date whenever you create an annotated release tag or a stable branch.

## Current stable entries

- Name: v1.1
  - Tag: `v1.1`
  - Commit: `000e0fe218a2d53af6b26dfdc08a6c6da18307a4`
  - Branch: `stable/v1.1` (pushed to `origin/stable/v1.1`)
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v1.1
  - Created: 2025-10-10

## Why this file exists

If you need to revert to a safe state quickly (for example after a problematic change), this file gives you an explicit tag and branch to check out. The `stable/*` branches are intended as protected rollback points  they should only be updated intentionally (for small hotfixes) and not for routine development.

````

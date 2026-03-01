# Sync co partials/templates

Purpose: copy this repo's `partials/` + `templates/` into `~/Code/_system` without deleting anything else.

## Usage

```bash
scripts/sync-co.sh            # push (repo -> ~/Code/_system)
scripts/sync-co.sh pull       # pull (~/Code/_system -> repo)
scripts/sync-co.sh -n          # dry run
CO_SYSTEM_ROOT=~/Code/_system scripts/sync-co.sh
```

Notes:
- Overwrites matching paths; does not delete other partials/templates.
- Requires `partials/` or `templates/` to exist in this repo.

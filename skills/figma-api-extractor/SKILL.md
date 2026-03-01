---
name: figma-api-extractor
description: Extract Figma frame trees and image renders via Figma REST API without Desktop MCP. Use for headless SSH/CI work, MCP startup failures, frame inventories, or downloading PNG/SVG/JPG outputs from Figma file/node URLs.
---

# Figma API Extractor

Use this skill when Figma Desktop MCP is unavailable or unstable and you still need frame/image extraction.

## Quick Start
1. Set token in env: `export FIGMA_TOKEN=...` (or `FIGMA_ACCESS_TOKEN`).
   Optional autoload: put token in `~/.config/env/figma.env` (`FIGMA_TOKEN=...`), sourced by shell profile.
2. Run extractor:
`python3 scripts/figma_extract.py --url "<figma-url>" --top-level-only --desktop-only --images --download-images --out /tmp/figma-out`

## Workflow
1. Parse `file_key` and `node_id` from URL.
2. Read node tree from Figma API (`/v1/files/{file_key}/nodes`).
3. Extract frames:
`top-level` mode: direct child frames of the target node.
`all-frames` mode: recursive frame scan.
4. Optional desktop filter (`--desktop-only`, min size flags).
5. Optional image URL fetch/download (`/v1/images/{file_key}`).

## Outputs
- `frames.json`: extracted frame metadata (`id`, `name`, `depth`, bbox)
- `image-urls.json`: frame id -> signed image URL (if `--images`)
- `images/`: downloaded files (if `--download-images`)

## Scripts
- `scripts/figma_extract.py`: main extractor
- `scripts/sync_harness_skill.sh`: symlink this skill into codex/cc/oc homes

## Notes
- Never hardcode or commit PAT tokens.
- Use env vars for secrets.
- Signed image URLs expire; regenerate when needed.

#!/usr/bin/env python3
"""Headless Figma frame + image extractor via REST API."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

API_BASE = "https://api.figma.com/v1"
DEFAULT_ENV_FILES = [
    Path.home() / ".config/env/figma.env",
    Path.home() / ".config/env/global.env",
]


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def request_json(url: str, token: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"X-Figma-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        die(f"figma api {exc.code}: {body}")
    except urllib.error.URLError as exc:
        die(f"network error: {exc}")


def load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            os.environ.setdefault(key, value)


def parse_url(url: str) -> tuple[str, str]:
    parsed = urllib.parse.urlparse(url)
    parts = [p for p in parsed.path.split("/") if p]
    if len(parts) < 2 or parts[0] not in {"design", "file"}:
        die("could not parse file key from URL")
    file_key = parts[1]

    query = urllib.parse.parse_qs(parsed.query)
    raw = query.get("node-id", [None])[0]
    if not raw:
        die("URL missing node-id query param")
    raw = urllib.parse.unquote(raw)
    node_id = raw.replace("-", ":")
    if ":" not in node_id:
        die("node-id format invalid")
    return file_key, node_id


def get_bbox(node: dict[str, Any]) -> dict[str, float | None]:
    bbox = node.get("absoluteBoundingBox") or {}
    return {
        "x": bbox.get("x"),
        "y": bbox.get("y"),
        "width": bbox.get("width"),
        "height": bbox.get("height"),
    }


def frame_record(node: dict[str, Any], depth: int) -> dict[str, Any]:
    b = get_bbox(node)
    return {
        "id": node.get("id"),
        "name": node.get("name"),
        "type": node.get("type"),
        "depth": depth,
        "x": b["x"],
        "y": b["y"],
        "width": b["width"],
        "height": b["height"],
        "child_count": len(node.get("children", [])),
    }


def collect_frames_recursive(node: dict[str, Any], depth: int = 0) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if node.get("type") == "FRAME":
        out.append(frame_record(node, depth))
    for child in node.get("children", []):
        out.extend(collect_frames_recursive(child, depth + 1))
    return out


def collect_top_level_frames(node: dict[str, Any]) -> list[dict[str, Any]]:
    children = node.get("children", [])
    frames = [frame_record(ch, 1) for ch in children if ch.get("type") == "FRAME"]
    if frames:
        return frames
    if node.get("type") == "FRAME":
        return [frame_record(node, 0)]
    return []


def is_desktop(frame: dict[str, Any], min_width: float, min_height: float) -> bool:
    w = frame.get("width") or 0
    h = frame.get("height") or 0
    return bool(w >= min_width and h >= min_height)


def chunked(items: list[str], size: int) -> list[list[str]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def fetch_image_urls(file_key: str, ids: list[str], token: str, fmt: str, scale: float) -> dict[str, str | None]:
    out: dict[str, str | None] = {}
    for group in chunked(ids, 80):
        params = urllib.parse.urlencode(
            {
                "ids": ",".join(group),
                "format": fmt,
                "scale": str(scale),
            }
        )
        url = f"{API_BASE}/images/{file_key}?{params}"
        data = request_json(url, token)
        images = data.get("images", {})
        for fig_id in group:
            out[fig_id] = images.get(fig_id)
    return out


def safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "-", value).strip("-") or "frame"


def download_images(
    image_urls: dict[str, str | None],
    frames_by_id: dict[str, dict[str, Any]],
    out_dir: Path,
    fmt: str,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    images_dir = out_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    for fig_id, url in image_urls.items():
        if not url:
            continue
        name = frames_by_id.get(fig_id, {}).get("name") or "frame"
        file_name = f"{safe_name(name)}__{fig_id.replace(':', '-')}.{fmt}"
        path = images_dir / file_name
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=60) as resp:
            path.write_bytes(resp.read())
        out.append({"id": fig_id, "path": str(path)})
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract Figma frames and images via REST API")
    parser.add_argument("--url", help="Figma URL with file key + node-id")
    parser.add_argument("--file-key", help="Figma file key (alternative to --url)")
    parser.add_argument("--node-id", help="Figma node id, ex: 8022:205381 (alternative to --url)")
    parser.add_argument("--token", help="PAT token; defaults to FIGMA_TOKEN env")
    parser.add_argument("--all-frames", action="store_true", help="Recursively include nested frames")
    parser.add_argument("--top-level-only", action="store_true", help="Only include direct child frames (default)")
    parser.add_argument("--desktop-only", action="store_true", help="Filter by min width/height")
    parser.add_argument("--min-width", type=float, default=1000)
    parser.add_argument("--min-height", type=float, default=700)
    parser.add_argument("--images", action="store_true", help="Fetch image URLs for selected frames")
    parser.add_argument("--download-images", action="store_true", help="Download images to output folder")
    parser.add_argument("--format", choices=["png", "jpg", "svg", "pdf"], default="png")
    parser.add_argument("--scale", type=float, default=2.0)
    parser.add_argument("--out", default="figma-output", help="Output directory")
    args = parser.parse_args()

    for env_file in DEFAULT_ENV_FILES:
        load_env_file(env_file)

    token = args.token or os.environ.get("FIGMA_TOKEN") or os.environ.get("FIGMA_ACCESS_TOKEN")
    if not token:
        die("missing token. set FIGMA_TOKEN/FIGMA_ACCESS_TOKEN or pass --token")

    if args.url:
        file_key, node_id = parse_url(args.url)
    else:
        if not args.file_key or not args.node_id:
            die("use --url OR --file-key + --node-id")
        file_key = args.file_key
        node_id = args.node_id.replace("-", ":")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    params = urllib.parse.urlencode({"ids": node_id})
    url = f"{API_BASE}/files/{file_key}/nodes?{params}"
    payload = request_json(url, token)

    nodes = payload.get("nodes", {})
    node_data = nodes.get(node_id) or nodes.get(node_id.replace(":", "-"))
    if not node_data and nodes:
        node_data = next(iter(nodes.values()))
    if not node_data:
        die("node not found in API response")

    root = node_data.get("document")
    if not root:
        die("response missing document")

    top_level_mode = args.top_level_only or not args.all_frames
    frames = collect_top_level_frames(root) if top_level_mode else collect_frames_recursive(root)

    if args.desktop_only:
        frames = [f for f in frames if is_desktop(f, args.min_width, args.min_height)]

    frames_path = out_dir / "frames.json"
    frames_path.write_text(json.dumps(frames, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    frames_by_id = {f["id"]: f for f in frames if f.get("id")}
    image_urls: dict[str, str | None] = {}
    downloads: list[dict[str, str]] = []

    if args.images and frames_by_id:
        image_urls = fetch_image_urls(file_key, list(frames_by_id.keys()), token, args.format, args.scale)
        (out_dir / "image-urls.json").write_text(
            json.dumps(image_urls, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    if args.download_images and image_urls:
        downloads = download_images(image_urls, frames_by_id, out_dir, args.format)
        (out_dir / "downloads.json").write_text(
            json.dumps(downloads, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    print(f"file_key={file_key}")
    print(f"node_id={node_id}")
    print(f"frames={len(frames)} -> {frames_path}")
    if args.images:
        print(f"image_urls={len([v for v in image_urls.values() if v])}")
    if args.download_images:
        print(f"downloads={len(downloads)} -> {out_dir / 'images'}")


if __name__ == "__main__":
    main()

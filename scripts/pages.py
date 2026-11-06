#!/usr/bin/env python3
"""Render the GitHub Pages site that distributes the Ad Hoc builds (used by publish-pages.sh).

Commands:
  build  --dir DIR --base-url URL   Write manifest.plist, build.json and index.html for one
                                    build folder. Metadata comes from environment variables
                                    (see BUILD_FIELDS). The IPA and the icons must already be
                                    in DIR.
  site   --root DIR --keep N        Delete branch builds beyond the newest N (main builds are
                                    always kept) and write the landing page (index.html) and
                                    builds.json for every folder that has a build.json.
"""

from __future__ import annotations

import argparse
import datetime
import html
import json
import os
import plistlib
import shutil
import sys
import urllib.parse
from pathlib import Path

STABLE = "stable"

# build.json field → environment variable.
BUILD_FIELDS = {
    "tag": "TAG",
    "channel": "CHANNEL",
    "version": "APP_VERSION",
    "build_number": "BUILD_NUMBER",
    "bundle_id": "BUNDLE_ID",
    "app_name": "APP_TITLE",
    "branch": "BRANCH",
    "commit": "COMMIT_SHA",
    "commit_title": "COMMIT_TITLE",
    "run_url": "RUN_URL",
    "devices": "DEVICE_COUNT",
}


def install_url(manifest_url: str) -> str:
    return "itms-services://?action=download-manifest&url=" + urllib.parse.quote(manifest_url, safe="")


def load_builds(root: Path) -> list[dict]:
    builds = []
    for meta in sorted(root.glob("*/build.json")):
        try:
            build = json.loads(meta.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        build["folder"] = meta.parent.name
        builds.append(build)
    return builds


def newest_first(build: dict) -> tuple:
    return (build.get("created_at", ""), int(build.get("run_number", 0) or 0))


def version_key(build: dict) -> tuple:
    parts = []
    for piece in str(build.get("version", "0")).split("."):
        parts.append(int(piece) if piece.isdigit() else 0)
    return tuple(parts)


# ---------------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------------

STYLE = """
:root{--bg:#f4f6fb;--card:#fff;--text:#1d2547;--muted:#5d6584;--line:#e3e7f1;--accent:#f2703a;--accent-text:#fff;--badge:#e8edf8}
@media (prefers-color-scheme:dark){:root{--bg:#0b1030;--card:#151c44;--text:#eef1fa;--muted:#a5acc8;--line:#262f5e;--accent:#ff8a5b;--accent-text:#1b1030;--badge:#232c5c}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
main{max-width:680px;margin:0 auto;padding:28px 16px 48px}
header{display:flex;gap:16px;align-items:center;margin-bottom:20px}
header img{width:76px;height:76px;border-radius:18px;box-shadow:0 4px 14px rgba(0,0,0,.18)}
h1{font-size:1.45rem;margin:0}
h2{font-size:1.05rem;margin:28px 0 10px}
p{margin:.3rem 0}
.muted{color:var(--muted)}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin:12px 0}
.button{display:inline-block;background:var(--accent);color:var(--accent-text);text-decoration:none;font-weight:600;padding:12px 18px;border-radius:12px;margin:6px 8px 6px 0}
.button.secondary{background:var(--badge);color:var(--text)}
.badge{display:inline-block;font-size:.75rem;font-weight:600;padding:2px 8px;border-radius:999px;background:var(--badge);margin-left:6px;vertical-align:middle}
.badge.stable{background:#2f9e5b;color:#fff}
.title{font-weight:600}
dl{display:grid;grid-template-columns:auto 1fr;gap:4px 12px;margin:10px 0 0}
dt{color:var(--muted)}
dd{margin:0;word-break:break-word}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.9em}
.row{display:flex;justify-content:space-between;align-items:baseline;gap:12px;flex-wrap:wrap}
"""


def page(title: str, body: str) -> str:
    return (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        f"<title>{html.escape(title)}</title>\n<style>{STYLE}</style>\n</head>\n"
        f"<body>\n<main>\n{body}\n</main>\n</body>\n</html>\n"
    )


def format_date(value: str) -> str:
    try:
        moment = datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except (TypeError, ValueError):
        return html.escape(str(value or ""))
    return moment.strftime("%Y-%m-%d %H:%M UTC")


def badge(build: dict) -> str:
    if build.get("channel") == STABLE:
        return '<span class="badge stable">Stable</span>'
    return '<span class="badge">Pre-release</span>'


def build_page(build: dict) -> str:
    e = html.escape
    commit = str(build.get("commit", ""))
    rows = [
        ("Version", f"{e(build['version'])} ({e(str(build['build_number']))})"),
        ("Branch", f"<code>{e(build.get('branch', ''))}</code>"),
        ("Commit", f"<code>{e(commit[:7])}</code> {e(build.get('commit_title', ''))}"),
        ("Built", format_date(build.get("created_at", ""))),
        ("Devices", e(str(build.get("devices", "?")))),
    ]
    details = "".join(f"<dt>{label}</dt><dd>{value}</dd>" for label, value in rows)
    run_link = ""
    if build.get("run_url"):
        run_link = f' · <a href="{e(build["run_url"])}">Workflow run</a>'
    body = f"""
<header>
  <img src="icon-512.png" alt="">
  <div>
    <h1>{e(build['app_name'])}</h1>
    <p class="muted"><code>{e(build['tag'])}</code>{badge(build)}</p>
  </div>
</header>
<div class="card">
  <p class="title">{e(build.get('commit_title', ''))}</p>
  <a class="button" href="{e(build['install_url'])}">Install on iPhone</a>
  <a class="button secondary" href="{e(build['ipa'])}">Download IPA</a>
  <dl>{details}</dl>
</div>
<div class="card muted">
  <p>Open this page in Safari on a registered iPhone and tap <b>Install on iPhone</b>.
  Only devices whose UDID was registered before this build was made can install it.</p>
  <p>If iOS asks for it, turn on <b>Settings › Privacy &amp; Security › Developer Mode</b>.</p>
</div>
<p class="muted"><a href="../">All builds</a>{run_link}</p>
"""
    return page(f"{build['app_name']} {build['tag']}", body)


def site_page(builds: list[dict], latest_stable: dict | None) -> str:
    e = html.escape
    newest = builds[0] if builds else None
    icon = f'<img src="{e(newest["folder"])}/icon-512.png" alt="">' if newest else ""
    name = e(newest["app_name"]) if newest else "Builds"
    if latest_stable:
        hero = f"""
<div class="card">
  <p class="title">Latest stable version: <code>{e(latest_stable['tag'])}</code></p>
  <p class="muted">{e(latest_stable.get('commit_title', ''))}</p>
  <a class="button" href="{e(latest_stable['install_url'])}">Install latest stable</a>
  <a class="button secondary" href="{e(latest_stable['folder'])}/">Details</a>
</div>"""
    else:
        hero = '<div class="card"><p class="muted">There is no stable build from <code>main</code> yet.</p></div>'
    items = []
    for build in builds:
        items.append(f"""
<div class="card">
  <div class="row">
    <span class="title"><code>{e(build['tag'])}</code>{badge(build)}</span>
    <span class="muted">{format_date(build.get('created_at', ''))}</span>
  </div>
  <p>{e(build.get('commit_title', ''))}</p>
  <p class="muted">Version {e(build['version'])} ({e(str(build['build_number']))}) · branch <code>{e(build.get('branch', ''))}</code></p>
  <a class="button" href="{e(build['install_url'])}">Install</a>
  <a class="button secondary" href="{e(build['folder'])}/">Details</a>
</div>""")
    body = f"""
<header>
  {icon}
  <div>
    <h1>{name}</h1>
    <p class="muted">Ad Hoc builds for registered iPhones. Open this page in Safari on the iPhone.</p>
  </div>
</header>
{hero}
<h2>All builds ({len(builds)})</h2>
{''.join(items) if items else '<p class="muted">No builds yet.</p>'}
"""
    return page(f"{newest['app_name'] if newest else 'Builds'} builds", body)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def command_build(arguments: argparse.Namespace) -> int:
    folder = Path(arguments.dir)
    base_url = arguments.base_url.rstrip("/") + "/"
    build = {field: os.environ.get(variable, "") for field, variable in BUILD_FIELDS.items()}
    missing = [BUILD_FIELDS[field] for field in ("tag", "version", "build_number", "bundle_id", "app_name") if not build[field]]
    if missing:
        print(f"Missing environment variables: {', '.join(missing)}", file=sys.stderr)
        return 1
    ipas = sorted(folder.glob("*.ipa"))
    if len(ipas) != 1:
        print(f"Expected exactly one .ipa in {folder}", file=sys.stderr)
        return 1
    ipa = ipas[0]
    tag_url = base_url + urllib.parse.quote(build["tag"]) + "/"
    manifest_url = tag_url + "manifest.plist"

    manifest = {
        "items": [
            {
                "assets": [
                    {"kind": "software-package", "url": tag_url + urllib.parse.quote(ipa.name)},
                    {"kind": "display-image", "url": tag_url + "icon-57.png"},
                    {"kind": "full-size-image", "url": tag_url + "icon-512.png"},
                ],
                "metadata": {
                    "bundle-identifier": build["bundle_id"],
                    "bundle-version": build["version"],
                    "kind": "software",
                    "title": build["app_name"],
                },
            }
        ]
    }
    with open(folder / "manifest.plist", "wb") as handle:
        plistlib.dump(manifest, handle, fmt=plistlib.FMT_XML)

    build.update(
        {
            "commit_short": build["commit"][:7],
            "created_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "run_number": int(os.environ.get("GITHUB_RUN_NUMBER", "0") or 0),
            "ipa": ipa.name,
            "ipa_size": ipa.stat().st_size,
            "page_url": tag_url,
            "manifest_url": manifest_url,
            "install_url": install_url(manifest_url),
            "signed": True,
        }
    )
    (folder / "build.json").write_text(json.dumps(build, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (folder / "index.html").write_text(build_page(build), encoding="utf-8")
    print(f"Rendered {folder.name}: {tag_url}")
    return 0


def command_site(arguments: argparse.Namespace) -> int:
    root = Path(arguments.root)
    builds = sorted(load_builds(root), key=newest_first, reverse=True)

    branch_builds = [build for build in builds if build.get("channel") != STABLE]
    protected = set(arguments.protect or [])
    removed = []
    kept_branch = 0
    for build in branch_builds:
        if kept_branch < arguments.keep or build["folder"] in protected:
            kept_branch += 1
            continue
        shutil.rmtree(root / build["folder"], ignore_errors=True)
        removed.append(build["folder"])
    if removed:
        print(f"Removed {len(removed)} old branch build(s): {', '.join(removed)}")
    builds = [build for build in builds if build["folder"] not in removed]

    stable_builds = [build for build in builds if build.get("channel") == STABLE]
    latest_stable = max(stable_builds, key=version_key) if stable_builds else None

    index = [{key: value for key, value in build.items() if key != "folder"} for build in builds]
    (root / "builds.json").write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (root / "index.html").write_text(site_page(builds, latest_stable), encoding="utf-8")
    print(f"Site lists {len(builds)} build(s): {len(stable_builds)} stable, {len(builds) - len(stable_builds)} pre-release.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    build.add_argument("--dir", required=True)
    build.add_argument("--base-url", required=True)
    build.set_defaults(handler=command_build)
    site = commands.add_parser("site")
    site.add_argument("--root", required=True)
    site.add_argument("--keep", type=int, default=20)
    site.add_argument("--protect", action="append", help="Folder that must never be removed")
    site.set_defaults(handler=command_site)
    arguments = parser.parse_args()
    return arguments.handler(arguments)


if __name__ == "__main__":
    sys.exit(main())

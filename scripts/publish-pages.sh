#!/usr/bin/env bash
# Publishes one signed build to GitHub Pages: branch gh-pages, one folder per tag.
#
# Every publish rewrites gh-pages as a single orphan commit, so old IPAs never pile up
# in the git history. Only folders that contain a build.json are carried over (the
# branch may have been created from the source code). All main (stable) builds are
# kept, plus the newest $BRANCH_KEEP branch builds. If another build publishes at the
# same time, the lease check rejects the push and the whole publish is retried.
#
# Required environment:
#   TAG, CHANNEL (stable|branch), IPA_PATH, ICON_57, ICON_512, BUNDLE_ID, APP_VERSION,
#   BUILD_NUMBER, APP_TITLE, COMMIT_SHA, COMMIT_TITLE, BRANCH, GITHUB_REPOSITORY
# Optional environment:
#   DEVICE_COUNT, RUN_URL, BRANCH_KEEP (20), MAX_ATTEMPTS (5), GH_TOKEN (for `gh api`)
# Outputs ($GITHUB_OUTPUT): base_url, page_url, manifest_url, install_url, pages_enabled
#
# Written for the bash 3.2 that ships with macOS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git rev-parse --show-toplevel)"
GIT_DIR_ABS="$(git -C "$REPO_DIR" rev-parse --absolute-git-dir)"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
BRANCH_KEEP="${BRANCH_KEEP:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"

for name in TAG CHANNEL IPA_PATH ICON_57 ICON_512 BUNDLE_ID APP_VERSION BUILD_NUMBER \
  APP_TITLE COMMIT_SHA COMMIT_TITLE BRANCH GITHUB_REPOSITORY; do
  if [ -z "${!name:-}" ]; then
    echo "::error::publish-pages.sh: $name is not set" >&2
    exit 1
  fi
done

export GIT_AUTHOR_NAME="github-actions[bot]"
export GIT_AUTHOR_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

PAGES_ENABLED=false

# The Pages URL from the API, or https://<owner>.github.io/<repo>/ before Pages is enabled.
resolve_base_url() {
  local url=""
  if command -v gh >/dev/null 2>&1; then
    url="$(gh api "repos/$GITHUB_REPOSITORY/pages" --jq '.html_url // empty' 2>/dev/null || true)"
  fi
  if [ -n "$url" ]; then
    PAGES_ENABLED=true
  else
    local owner
    owner="$(printf '%s' "${GITHUB_REPOSITORY%%/*}" | tr '[:upper:]' '[:lower:]')"
    url="https://$owner.github.io/${GITHUB_REPOSITORY#*/}/"
  fi
  url="https://${url#*://}"
  case "$url" in
    */) ;;
    *) url="$url/" ;;
  esac
  BASE_URL="$url"
}

WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pages.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

resolve_base_url
echo "Pages URL: $BASE_URL"

# The folder of this build: IPA, icons, manifest.plist, index.html and build.json.
BUILD_DIR="$WORK/build/$TAG"
mkdir -p "$BUILD_DIR"
cp "$IPA_PATH" "$BUILD_DIR/$(basename "$IPA_PATH")"
cp "$ICON_57" "$BUILD_DIR/icon-57.png"
cp "$ICON_512" "$BUILD_DIR/icon-512.png"
python3 "$SCRIPT_DIR/pages.py" build --dir "$BUILD_DIR" --base-url "$BASE_URL"

publish_once() {
  local site="$WORK/site" previous="$WORK/previous" index="$WORK/index"
  local remote_sha="" heads folder name tree commit
  rm -rf "$site" "$previous" "$index"
  mkdir -p "$site" "$previous"

  heads="$(git -C "$REPO_DIR" ls-remote --heads origin "refs/heads/$PAGES_BRANCH")" || return 1
  if [ -n "$heads" ]; then
    git -C "$REPO_DIR" fetch --quiet --no-tags origin \
      "+refs/heads/$PAGES_BRANCH:refs/remotes/origin/$PAGES_BRANCH" || return 1
    remote_sha="$(git -C "$REPO_DIR" rev-parse "refs/remotes/origin/$PAGES_BRANCH")" || return 1
    git -C "$REPO_DIR" archive "$remote_sha" | tar -x -C "$previous" || return 1
  fi

  # Carry over earlier builds only; anything without a build.json is dropped.
  for folder in "$previous"/*/; do
    [ -d "$folder" ] || continue
    folder="${folder%/}"
    name="$(basename "$folder")"
    [ "$name" = "$TAG" ] && continue
    [ -f "$folder/build.json" ] || continue
    cp -R "$folder" "$site/$name" || return 1
  done
  cp -R "$BUILD_DIR" "$site/$TAG" || return 1

  python3 "$SCRIPT_DIR/pages.py" site --root "$site" --keep "$BRANCH_KEEP" --protect "$TAG" || return 1
  touch "$site/.nojekyll"

  # A single orphan commit with the whole site. --force keeps *.ipa even if ignored.
  GIT_INDEX_FILE="$index" git -C "$site" --git-dir="$GIT_DIR_ABS" --work-tree="$site" \
    add -A --force . || return 1
  tree="$(GIT_INDEX_FILE="$index" git --git-dir="$GIT_DIR_ABS" write-tree)" || return 1
  commit="$(git --git-dir="$GIT_DIR_ABS" commit-tree "$tree" -m "Publish $TAG")" || return 1

  # An empty expected value means "the branch must not exist yet".
  git -C "$REPO_DIR" push --quiet --force-with-lease="refs/heads/$PAGES_BRANCH:$remote_sha" \
    origin "$commit:refs/heads/$PAGES_BRANCH"
}

attempt=1
until publish_once; do
  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    echo "::error::Could not publish $TAG to $PAGES_BRANCH after $attempt attempts" >&2
    exit 1
  fi
  delay=$((attempt * 5))
  echo "Publishing failed (another build may have published at the same time); retrying in ${delay}s"
  sleep "$delay"
  attempt=$((attempt + 1))
done

PAGE_URL="${BASE_URL}${TAG}/"
MANIFEST_URL="${PAGE_URL}manifest.plist"
INSTALL_URL="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["install_url"])' "$BUILD_DIR/build.json")"

echo "Published $TAG: $PAGE_URL"
if [ "$PAGES_ENABLED" != true ]; then
  echo "::warning::GitHub Pages is not enabled yet. Open Settings › Pages and deploy from the branch $PAGES_BRANCH, folder / (root)."
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "base_url=$BASE_URL"
    echo "page_url=$PAGE_URL"
    echo "manifest_url=$MANIFEST_URL"
    echo "install_url=$INSTALL_URL"
    echo "pages_enabled=$PAGES_ENABLED"
  } >> "$GITHUB_OUTPUT"
fi

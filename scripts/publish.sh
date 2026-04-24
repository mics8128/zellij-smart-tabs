#!/usr/bin/env bash
set -euo pipefail

current_version="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n 1)"
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Could not parse Cargo.toml version: $current_version" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Worktree is dirty. Commit or stash changes before publishing." >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [ -z "$current_branch" ]; then
  echo "Could not determine the current branch." >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "$current_version"
patch_version="${major}.${minor}.$((patch + 1))"
minor_version="${major}.$((minor + 1)).0"
major_version="$((major + 1)).0.0"

echo "Current version: $current_version"
echo
echo "Select release bump:"
echo "  1) patch: $patch_version"
echo "  2) minor: $minor_version"
echo "  3) major: $major_version"
echo "  4) custom"
printf "Choice [1]: "
read -r choice
choice="${choice:-1}"

case "$choice" in
  1) next_version="$patch_version" ;;
  2) next_version="$minor_version" ;;
  3) next_version="$major_version" ;;
  4)
    printf "Version: "
    read -r next_version
    ;;
  *)
    echo "Invalid choice: $choice" >&2
    exit 1
    ;;
esac

if [[ ! "$next_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: $next_version" >&2
  exit 1
fi

tag="v${next_version}"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag already exists locally: $tag" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
  echo "Tag already exists on origin: $tag" >&2
  exit 1
fi

echo
echo "Publishing $tag"
echo "This will:"
echo "  - update Cargo.toml and Cargo.lock"
echo "  - run fmt, tests, clippy, and release build"
echo "  - commit the version bump"
echo "  - create and push $tag"
echo
printf "Continue? [y/N] "
read -r confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled."
    exit 0
    ;;
esac

NEXT_VERSION="$next_version" perl -0pi -e 's/(\[package\][\s\S]*?^version = ")[^"]+(")/$1$ENV{NEXT_VERSION}$2/m' Cargo.toml
cargo check --target "$(rustc -vV | sed -n 's/^host: //p')"

cargo fmt --check
make test
make lint
make build

git add Cargo.toml Cargo.lock
git commit -m "chore: release $tag"
git tag "$tag"
git push origin "HEAD:${current_branch}"
git push origin "$tag"

echo "Published $tag. GitHub Actions will build and attach zellij-smart-tabs.wasm to the release."

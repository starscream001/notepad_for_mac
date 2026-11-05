#!/bin/bash
set -euo pipefail
VERSION="$(cat VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION"; exit 1; }
if [[ "$GITHUB_REF" == refs/heads/main ]]; then
  HEAD_SHA="$(gh api "repos/$GH_REPO/git/ref/heads/main" --jq '.object.sha')"
  if [[ "$HEAD_SHA" != "$GITHUB_SHA" ]]; then
    echo "A newer commit is available; keeping this build in Actions only."
    exit 0
  fi
fi
retry() {
  local attempt
  for attempt in 1 2 3; do
    if "$@"; then return 0; fi
    if [[ "$attempt" != 3 ]]; then sleep "$((attempt * 2))"; fi
  done
  return 1
}
# Publish from a draft so a public version always includes its application files.
# Published numbered versions are immutable; reruns resume an unfinished draft.
publish_version() {
  local version="$1" target="$2" source="$3" newest="$4" stage="$5" state
  local notes="docs/releases/v${version}.md"
  test -f "$notes"
  if state="$(gh release view "v$version" --json isDraft --jq '.isDraft' 2>/dev/null)"; then
    if [[ "$state" == "false" ]]; then
      echo "v$version is already published; preserving its files."
      return 0
    fi
  else
    retry gh release create "v$version" --target "$target" --title "Notepad Mac $version" --notes-file "$notes" --draft
  fi
  mkdir -p "$stage"
  cp "$source" "$stage/Notepad-Mac-universal.zip"
  (cd "$stage" && sha256sum Notepad-Mac-universal.zip > Notepad-Mac-universal.zip.sha256)
  local extras=() file
  if [[ "$newest" == "true" ]]; then
    for file in dist/*.exe dist/*.AppImage dist/*.deb; do
      [[ -f "$file" ]] || continue
      cp "$file" "$stage/"
      (cd "$stage" && sha256sum "$(basename "$file")" > "$(basename "$file").sha256")
      extras+=("$stage/$(basename "$file")" "$stage/$(basename "$file").sha256")
    done
  fi
  # Resume drafts without deleting valid uploaded files after transient API failures.
  local asset digest remote expected
  for file in "$stage/Notepad-Mac-universal.zip" "$stage/Notepad-Mac-universal.zip.sha256" "${extras[@]}"; do
    asset="$(basename "$file")"
    digest="$(sha256sum "$file" | cut -d ' ' -f 1)"
    remote="$(gh api "repos/$GH_REPO/releases?per_page=100" --paginate --jq ".[] | select(.tag_name == \"v$version\") | .assets[] | select(.name == \"$asset\") | [.digest, .size, .state] | @tsv")"
    expected="$(printf 'sha256:%s\t%s\tuploaded' "$digest" "$(wc -c < "$file" | tr -d ' ')")"
    if [[ -n "$remote" ]]; then
      [[ "$remote" == "$expected" ]] || { echo "Draft asset mismatch: $asset; refusing replacement."; return 1; }
      echo "Verified existing draft asset: $asset"
    else
      retry gh release upload "v$version" "$file"
    fi
  done
  retry gh release edit "v$version" --title "Notepad Mac $version" --notes-file "$notes" --draft=false --prerelease=false --latest="$newest"
}
# Register the original tested 0.1 build once, using its original source revision
# and existing Actions artifact (not a rebuild with newer sources).
BASELINE_STATE="$(gh release view v0.1.0 --json isDraft --jq '.isDraft' 2>/dev/null || true)"
if [[ "$BASELINE_STATE" != "false" ]]; then
  retry gh run download 41819225600 --repo "$GH_REPO" --name Notepad-Mac-universal --dir baseline
  (cd baseline && sha256sum -c Notepad-Mac-0.1.0-universal.zip.sha256)
  publish_version 0.1.0 e743960459aaa76cf92eaac7253aad5ce3608329 baseline/Notepad-Mac-0.1.0-universal.zip false release-0.1
fi
(cd dist && sha256sum -c "Notepad-Mac-${VERSION}-universal.zip.sha256")
publish_version "$VERSION" "$GITHUB_SHA" "dist/Notepad-Mac-${VERSION}-universal.zip" true release-current
# Keep the former moving 'latest' tag only as a clearly marked historical preview.
# All public download buttons now use GitHub's standard /releases/latest route.
if gh release view latest >/dev/null 2>&1; then
  printf '%s\n' 'Архивная предварительная сборка. Актуальные версии, описание изменений и готовое приложение: https://github.com/starscream001/notepad_for_mac/releases/latest' > archive-notes.md
  retry gh release edit latest --title 'Архив · предварительная сборка' --notes-file archive-notes.md --prerelease=true --latest=false
fi
# Delete only old numbered release installers, after successful publication.
RELEASE_VERSION="$VERSION" node scripts/release-retention.cjs

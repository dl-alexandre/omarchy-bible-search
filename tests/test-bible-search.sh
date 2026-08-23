#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BIN="$REPO_ROOT/bin/omarchy-bible-search"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  grep -Fq -- "$needle" <<< "$haystack" || fail "expected output to contain: $needle"
}

search_output="$($BIN search 'For God so loved the world')"
assert_contains "$search_output" $'RESULT\tJOH 3:16\t'

reference_output="$($BIN search 'John 2:1')"
assert_contains "$reference_output" $'RESULT\tJOH 2:1\t'

chapter_output="$($BIN search 'John 2:')"
assert_contains "$chapter_output" $'RESULT\tJOH 2:1\t'

if grep -Fn -- '"bash", "-c"' "$REPO_ROOT/Panel.qml"; then
  fail 'clipboard path still crosses a shell boundary'
fi
assert_contains "$(sed -n '1,125p' "$REPO_ROOT/Panel.qml")" 'Quickshell.execDetached(["wl-copy", "--", text])'

assert_contains "$(sed -n '1,170p' "$BIN")" 'sha256sum --check --strict --status'
assert_contains "$(sed -n '1,170p' "$BIN")" 'unzip -tq'
assert_contains "$(sed -n '1,170p' "$BIN")" '--max-filesize'
assert_contains "$(sed -n '1,180p' "$BIN")" "stat -c '%s'"

setup_root="$(mktemp -d)"
fake_path="$setup_root/fake-bin"
fake_home="$setup_root/home"
mkdir -p "$fake_path"
ln -s "$REPO_ROOT/tests/fake-curl" "$fake_path/curl"
mkdir -p "$setup_root/plugin/bin"
cp -- "$BIN" "$setup_root/plugin/bin/omarchy-bible-search"

if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$REPO_ROOT/README.md" \
  BIBLE_SEARCH_HOME="$fake_home" \
  "$setup_root/plugin/bin/omarchy-bible-search" setup >"$setup_root/setup.out" 2>"$setup_root/setup.err"; then
  fail 'setup accepted an archive with the wrong checksum'
fi

assert_contains "$(< "$setup_root/setup.err")" 'failed SHA-256 verification'
[[ ! -e "$fake_home/cache/engwebp_vpl.zip.part" ]] || fail 'checksum failure left an archive partial'
[[ ! -e "$fake_home/cache/engwebp_vpl.txt.part" ]] || fail 'checksum failure left a corpus partial'
if find "$fake_home" -maxdepth 1 -type d -name 'books.new.*' -print -quit | grep -q .; then
  fail 'checksum failure left a staging directory'
fi

printf 'PASS: Bible Search focused tests\n'

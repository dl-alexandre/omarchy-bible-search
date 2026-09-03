#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
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

# Panel.qml is a Qt6/Quickshell QML file: it imports "qs.Commons"/"qs.Ui",
# Quickshell's own workspace-relative module scheme, which only resolves
# inside a running Quickshell shell. qmllint can't follow that import, so it
# always reports the custom shell component types (PanelActionButton,
# CursorSurface, BorderSurface, ...) as unresolved, and reports hundreds of
# "unqualified access" warnings that are ordinary in Quickshell QML. None of
# that indicates a real problem, so this check does not treat qmllint
# warnings as failures. What it does catch is a genuine parse/syntax error
# (unbalanced braces, invalid property syntax, ...), which qmllint reports
# as a nonzero exit regardless of import resolution. Use Qt6's qmllint
# specifically: Qt5's (often just `qmllint` on PATH) chokes on this file's
# Qt6-only syntax and exits nonzero with no output even when the file is
# fine, which is not a signal we can use.
resolve_qmllint() {
  local candidate
  for candidate in qmllint6 /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/libexec/qmllint qmllint; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    "$candidate" --version 2>&1 | grep -q ' 6\.' || continue
    printf '%s' "$candidate"
    return 0
  done
  return 1
}

if qmllint_bin="$(resolve_qmllint)"; then
  for qml_file in Panel.qml BarWidget.qml NarrationController.qml; do
    "$qmllint_bin" "$REPO_ROOT/$qml_file" >/dev/null 2>&1 \
      || fail "$qml_file failed to parse ($qmllint_bin exited non-zero)"
  done
else
  printf 'SKIP: no Qt6 qmllint found, skipping QML syntax check\n' >&2
fi

search_output="$($BIN search 'For God so loved the world')"
assert_contains "$search_output" $'RESULT\tJohn 3:16\t'

reference_output="$($BIN search 'Jn 2:1')"
assert_contains "$reference_output" $'RESULT\tJohn 2:1\t'
assert_contains "$reference_output" $'RESULT\tJohn 2:10\t'

hosea_output="$($BIN search 'Hosea 1:1')"
assert_contains "$hosea_output" $'RESULT\tHosea 1:1\t'
assert_contains "$hosea_output" $'RESULT\tHosea 1:10\t'

chapter_output="$($BIN search 'John 2:')"
assert_contains "$chapter_output" $'RESULT\tJohn 2:1\t'

range_output="$($BIN search '1 Cor 13:4-7')"
assert_contains "$range_output" $'RESULT\t1 Corinthians 13:4\t'
assert_contains "$range_output" $'RESULT\t1 Corinthians 13:7\t'

chapter_read_output="$($BIN chapter 'Jn 3')"
assert_contains "$chapter_read_output" $'RESULT\tJohn 3:16\t'

catalog_output="$($BIN catalog)"
assert_contains "$catalog_output" $'BOOK\tGenesis\t50'
assert_contains "$catalog_output" $'BOOK\tRevelation\t22'
[[ "$(grep -c $'^BOOK\t' <<< "$catalog_output")" -eq 66 ]] || fail 'catalog did not contain all 66 books'

state_root="$(mktemp -d)"
state_output="$(BIBLE_SEARCH_HOME="$state_root/data" "$BIN" state-init)"
assert_contains "$state_output" $'STATE\t'
[[ -d "$state_root/data" ]] || fail 'state-init did not create the user data directory'
rm -rf -- "$state_root"

voice_status_output="$($BIN voice-status)"
assert_contains "$voice_status_output" $'VOICE\t'

daily_root="$(mktemp -d)"
daily_first="$(BIBLE_SEARCH_HOME="$daily_root" "$BIN" daily)"
daily_same_day="$(BIBLE_SEARCH_HOME="$daily_root" "$BIN" daily)"
[[ "$daily_first" == "$daily_same_day" ]] || fail 'daily verse changed within the same day'
assert_contains "$daily_first" $'RESULT\t'
rm -rf -- "$daily_root"

invalid_range_output="$($BIN search 'John 3:17-16')"
assert_contains "$invalid_range_output" $'STATUS\tInvalid reference range: John 3:17-16'

read_output="$($BIN read 'John 3:16')"
assert_contains "$read_output" 'JOH 3:16 '

# Panel.qml / BarWidget.qml: a small set of invariant checks. These check
# that a known-bad pattern is absent (unavailable import, a shell-crossing
# clipboard call, a UI entry point that was deliberately removed, narration
# being killed as a side effect of closing the panel) rather than pinning
# exact source text, so they don't break on an ordinary refactor.
panel_source="$(< "$REPO_ROOT/Panel.qml")"

if grep -Fq -- 'QtQuick.Accessibility' "$REPO_ROOT/Panel.qml"; then
  fail 'Panel.qml imports unavailable QtQuick.Accessibility'
fi
if grep -Fn -- '"bash", "-c"' "$REPO_ROOT/Panel.qml"; then
  fail 'clipboard path still crosses a shell boundary'
fi
if grep -Fq -- 'id: browseButton' <<< "$panel_source"; then
  fail 'Browse Books still appears in the widget UI'
fi

close_block="$(sed -n '/function close()/,/^  }/p' "$REPO_ROOT/Panel.qml")"
if grep -Fq -- 'root.stopNarration()' <<< "$close_block"; then
  fail 'closing the anchored panel stopped narration'
fi

# CLI safety properties that are cheap to pin directly and don't move with
# ordinary QML refactors (they live in bin/omarchy-bible-search).
assert_contains "$(< "$BIN")" "readonly PIPER_MODEL=\"\$PIPER_ROOT/voices/en_US-ryan-medium.onnx\""
assert_contains "$(< "$BIN")" "paplay \"\$speech_file\""
assert_contains "$(< "$BIN")" 'trap cleanup_speech EXIT INT TERM'
assert_contains "$(< "$BIN")" "kill \"\$speech_child\" 2>/dev/null || true"
assert_contains "$(< "$BIN")" 'daily_verse()'
assert_contains "$(< "$BIN")" 'command -v ffprobe >/dev/null 2>&1 || die "ffprobe is required for neural voice timing"'
assert_contains "$(< "$BIN")" "\"\$CACHE_ROOT\"/speech.*.wav) rm -f -- \"\$speech_file\""
assert_contains "$(< "$BIN")" 'sha256sum --check --strict --status'
assert_contains "$(< "$BIN")" 'unzip -tq'
assert_contains "$(< "$BIN")" '--max-filesize'
assert_contains "$(< "$BIN")" "stat -c '%s'"

speed_output=""
if speed_output="$("$BIN" prepare-speech "test" 2 2>&1)"; then
  fail 'prepare-speech accepted an out-of-range speed'
fi
assert_contains "$speed_output" 'speech speed must be 0.85, 1, or 1.15'

long_text="$(head -c 4001 /dev/zero | tr '\0' 'a')"
long_speech_output=""
if long_speech_output="$("$BIN" prepare-speech "$long_text" 2>&1)"; then
  fail 'prepare-speech accepted text over the 4000-character limit'
fi
assert_contains "$long_speech_output" 'exceeds the 4000-character limit'

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

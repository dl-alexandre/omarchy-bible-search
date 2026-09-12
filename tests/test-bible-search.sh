#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly BIN="$REPO_ROOT/bin/omarchy-bible-search"
readonly SETUP_HELPER="$REPO_ROOT/bin/omarchy-bible-search-setup.py"

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
  for qml_file in Panel.qml BarWidget.qml NarrationController.qml ReaderState.qml; do
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

doctor_output="$($BIN doctor)"
assert_contains "$doctor_output" $'STATUS\tbooks\t'
if grep -Fq 'gpu-ui' <<< "$doctor_output"; then
  fail 'doctor still reports gpu-ui'
fi
if grep -Fq 'gpu-ui' "$BIN"; then
  fail 'CLI still mentions gpu-ui'
fi

if [[ -e "$REPO_ROOT/bin/omarchy-bible-search-ui" ]]; then
  fail 'gpu-ui wrapper bin/omarchy-bible-search-ui is still present'
fi

tts_override_output="$(BIBLE_TTS_BIN=/bin/true "$BIN" voice-status)"
assert_contains "$tts_override_output" $'VOICE\ttrue'
if grep -Fq $'VOICE\tpiper' <<< "$tts_override_output"; then
  fail 'BIBLE_TTS_BIN did not override piper in voice-status'
fi
tts_doctor_output="$(BIBLE_TTS_BIN=/bin/true "$BIN" doctor)"
assert_contains "$tts_doctor_output" $'STATUS\tvoice\t/bin/true'

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
if grep -Eq -- 'id: browseButton|function browse\(' <<< "$panel_source"; then
  fail 'Browse Books is still in the widget'
fi
if grep -Eq -- 'id: headerTitle|id: iconBadge' <<< "$panel_source"; then
  fail 'hidden panel header is still in Panel.qml'
fi
if grep -Eq -- 'browse_corpus|omarchy-bible-search browse' "$BIN"; then
  fail 'CLI still has the fff browse command'
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
assert_contains "$(< "$BIN")" "python3 \"\$SCRIPT_ROOT/bin/omarchy-bible-search-setup.py\""
assert_contains "$(< "$BIN")" "--max-corpus-bytes \"\$WEB_CORPUS_MAX_BYTES\""
assert_contains "$(< "$SETUP_HELPER")" 'os.O_NOFOLLOW'
assert_contains "$(< "$SETUP_HELPER")" 'os.replace(stage_name, final_name, src_dir_fd=parent, dst_dir_fd=parent)'
assert_contains "$(< "$SETUP_HELPER")" 'os.rename('
assert_contains "$(< "$SETUP_HELPER")" 'hashlib.sha256()'
assert_contains "$(< "$SETUP_HELPER")" 'zipfile.ZipFile'
if grep -Fq 'engwebp_vpl.zip.part' "$BIN"; then
  fail 'setup still uses a predictable archive .part path'
fi
if grep -Fq 'books.new.$$' "$BIN"; then
  fail 'setup still uses a predictable books.new.$$ staging directory'
fi

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
planted="$setup_root/planted-target"
mkdir -p "$fake_path" "$fake_home/cache"
ln -s "$REPO_ROOT/tests/fake-curl" "$fake_path/curl"
printf 'planted\n' > "$planted"
ln -s "$planted" "$fake_home/cache/engwebp_vpl.zip.part"
ln -s "$planted" "$fake_home/cache/engwebp_vpl.txt.part"
mkdir -p "$setup_root/plugin/bin"
cp -- "$BIN" "$setup_root/plugin/bin/omarchy-bible-search"
cp -- "$SETUP_HELPER" "$setup_root/plugin/bin/omarchy-bible-search-setup.py"

if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$REPO_ROOT/README.md" \
  BIBLE_SEARCH_HOME="$fake_home" \
  "$setup_root/plugin/bin/omarchy-bible-search" setup >"$setup_root/setup.out" 2>"$setup_root/setup.err"; then
  fail 'setup accepted an archive with the wrong checksum'
fi

assert_contains "$(< "$setup_root/setup.err")" 'failed SHA-256 verification'
[[ "$(< "$planted")" == $'planted' ]] || fail 'setup followed a planted cache symlink'
[[ -L "$fake_home/cache/engwebp_vpl.zip.part" ]] || fail 'setup replaced a planted archive symlink'
if find "$fake_home" -name 'stage.*' -print -quit | grep -q .; then
  fail 'checksum failure left a random staging path'
fi
if find "$fake_home" -maxdepth 1 -type d -name 'books.new.*' -print -quit | grep -q .; then
  fail 'checksum failure left a staging directory'
fi

assert_no_setup_staging() {
  local root="$1"
  [[ ! -d "$root" ]] && return 0
  if find "$root" -name 'stage.*' -print -quit | grep -q .; then
    fail "setup left staging paths under $root"
  fi
}

curl_failure_home="$setup_root/curl-failure-home"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_EXIT=22 \
  FAKE_CURL_SOURCE="$REPO_ROOT/README.md" \
  BIBLE_SEARCH_HOME="$curl_failure_home" \
  "$setup_root/plugin/bin/omarchy-bible-search" setup >"$setup_root/curl-failure.out" 2>"$setup_root/curl-failure.err"; then
  fail 'setup accepted a failed download'
fi
assert_contains "$(< "$setup_root/curl-failure.err")" 'curl failed while downloading'
assert_no_setup_staging "$curl_failure_home"

python3 - "$setup_root/good.zip" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr(
        "engwebp_vpl.txt",
        "GEN 1:1 In the beginning God created the heavens and the earth.\n"
        "GEN 1:2 The earth was formless and empty.\n"
        "JOH 1:1 In the beginning was the Word.\n",
    )
PY
good_sha256="$(sha256sum "$setup_root/good.zip" | awk '{print $1}')"
good_home="$setup_root/good-home"
if ! PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/good.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$good_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$good_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/good.out" 2>"$setup_root/good.err"; then
  cat "$setup_root/good.err" >&2
  fail 'secure setup rejected a valid archive'
fi
assert_contains "$(< "$setup_root/good.out")" 'Installed WEBP'
assert_contains "$(< "$good_home/books/Genesis.txt")" 'GEN 1:1'
assert_contains "$(< "$good_home/books/John.txt")" 'JOH 1:1'
[[ -f "$good_home/cache/engwebp_vpl.zip" ]] || fail 'secure setup did not install the archive cache'
[[ -f "$good_home/cache/engwebp_vpl.txt" ]] || fail 'secure setup did not install the corpus cache'
assert_no_setup_staging "$good_home"

oversize_home="$setup_root/oversize-home"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/good.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$oversize_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$good_sha256" \
  --max-download-bytes 8 \
  --max-corpus-bytes 1048576 >"$setup_root/oversize.out" 2>"$setup_root/oversize.err"; then
  fail 'secure setup accepted an oversized download'
fi
assert_contains "$(< "$setup_root/oversize.err")" 'exceeds the 8-byte size limit'
assert_no_setup_staging "$oversize_home"

printf 'not a ZIP archive\n' > "$setup_root/bad.zip"
bad_sha256="$(sha256sum "$setup_root/bad.zip" | awk '{print $1}')"
bad_home="$setup_root/bad-home"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/bad.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$bad_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$bad_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/bad.out" 2>"$setup_root/bad.err"; then
  fail 'secure setup accepted a malformed archive'
fi
assert_contains "$(< "$setup_root/bad.err")" 'ZIP integrity validation'
assert_no_setup_staging "$bad_home"

python3 - "$setup_root/multi.zip" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("engwebp_vpl.txt", "GEN 1:1 Safe\n")
    archive.writestr("../outside.txt", "must not be extracted\n")
PY
multi_sha256="$(sha256sum "$setup_root/multi.zip" | awk '{print $1}')"
multi_home="$setup_root/multi-home"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/multi.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$multi_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$multi_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/multi.out" 2>"$setup_root/multi.err"; then
  fail 'secure setup accepted an archive with an unexpected member'
fi
assert_contains "$(< "$setup_root/multi.err")" 'exactly one engwebp_vpl.txt member'
[[ ! -e "$setup_root/outside.txt" ]] || fail 'archive traversal escaped the staging directory'
assert_no_setup_staging "$multi_home"

symlink_target="$setup_root/symlink-target"
symlink_home="$setup_root/symlink-home"
mkdir -p "$symlink_target"
ln -s "$symlink_target" "$symlink_home"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/good.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$symlink_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$good_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/symlink.out" 2>"$setup_root/symlink.err"; then
  fail 'secure setup followed a symlinked data root'
fi
assert_contains "$(< "$setup_root/symlink.err")" 'refusing symlink'

unsafe_parent="$setup_root/unsafe-parent"
unsafe_home="$unsafe_parent/home"
mkdir -p "$unsafe_parent"
chmod 0777 "$unsafe_parent"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/good.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$unsafe_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$good_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/unsafe.out" 2>"$setup_root/unsafe.err"; then
  fail 'secure setup accepted a writable ancestor'
fi
assert_contains "$(< "$setup_root/unsafe.err")" 'group/world-writable directory'

book_link_home="$setup_root/book-link-home"
mkdir -p "$book_link_home/cache"
ln -s "$planted" "$book_link_home/books"
if PATH="$fake_path:$PATH" \
  FAKE_CURL_SOURCE="$setup_root/good.zip" \
  python3 "$SETUP_HELPER" \
  --data-root "$book_link_home" \
  --url 'https://example.invalid/engwebp_vpl.zip' \
  --sha256 "$good_sha256" \
  --max-download-bytes 1048576 \
  --max-corpus-bytes 1048576 >"$setup_root/book-link.out" 2>"$setup_root/book-link.err"; then
  fail 'secure setup followed a symlinked book directory'
fi
assert_contains "$(< "$setup_root/book-link.err")" 'refusing to replace symlink book directory'

printf 'PASS: Bible Search focused tests\n'

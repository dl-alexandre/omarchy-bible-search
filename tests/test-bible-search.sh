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

panel_source="$(< "$REPO_ROOT/Panel.qml")"

if grep -Fq -- 'QtQuick.Accessibility' "$REPO_ROOT/Panel.qml"; then
  fail 'Panel.qml imports unavailable QtQuick.Accessibility'
fi
if grep -Fn -- '"bash", "-c"' "$REPO_ROOT/Panel.qml"; then
  fail 'clipboard path still crosses a shell boundary'
fi
assert_contains "$panel_source" 'copyProc.command = ["wl-copy", "--", text]'
assert_contains "$panel_source" 'Quickshell.execDetached(["omarchy-launch-tui", root.scriptPath, "browse"])'
assert_contains "$panel_source" 'property int searchGeneration: 0'
assert_contains "$panel_source" 'property bool searchStopPending: false'
assert_contains "$panel_source" 'root.activeSearchGeneration !== root.searchGeneration'
assert_contains "$panel_source" 'readonly property var ttsCandidates: ["espeak-ng", "espeak", "spd-say"]'
assert_contains "$panel_source" 'ttsProc.command = [root.ttsEngine, "--", row.verse]'
assert_contains "$panel_source" 'chapterProc.command = [root.scriptPath, "chapter", match[1] + " " + match[2]]'
assert_contains "$panel_source" 'function stopNarration()'
assert_contains "$panel_source" 'property var narrationWords: []'
assert_contains "$panel_source" 'readonly property real narrationProgress:'
assert_contains "$panel_source" 'function skipNarration(delta)'
assert_contains "$panel_source" 'text: "Read along"'
assert_contains "$panel_source" 'property bool readerMode: false'
assert_contains "$panel_source" 'function buildReaderPages(queue)'
assert_contains "$panel_source" 'function turnReaderPage(targetPage)'
assert_contains "$panel_source" 'function adjacentChapter(direction)'
assert_contains "$panel_source" 'function advanceReaderChapter(direction)'
assert_contains "$panel_source" 'function canMoveReader(direction)'
assert_contains "$panel_source" 'function moveReaderVerse(delta)'
assert_contains "$panel_source" 'property bool readerPaginated: true'
assert_contains "$panel_source" 'function applyReaderLayout(paginated)'
assert_contains "$panel_source" 'function cyclePanelTab(direction)'
assert_contains "$panel_source" 'function cycleReaderChrome(direction)'
assert_contains "$panel_source" 'root.cyclePanelTab(direction)'
assert_contains "$panel_source" 'function openReader(index)'
assert_contains "$panel_source" 'function requestNarration(queue, mode, startIndex)'
assert_contains "$panel_source" 'root.requestNarration(root.readerChapterQueue, "chapter", root.readerSelectedVerseIndex)'
assert_contains "$panel_source" 'text: "Library"'
assert_contains "$panel_source" '"From here" : "Chapter"'
assert_contains "$panel_source" 'property bool readerTurning: false'
assert_contains "$panel_source" 'property real readerTurnAngle: 0'
assert_contains "$panel_source" 'property real readerTurnProgress: 0'
assert_contains "$panel_source" 'property bool readerDragging: false'
assert_contains "$panel_source" 'property real readerDragStartX: 0'
assert_contains "$panel_source" 'property int readerTurnCancelDuration: 220'
assert_contains "$panel_source" 'readonly property var readerTurnPage:'
assert_contains "$panel_source" 'function beginReaderCornerDrag(direction, startX)'
assert_contains "$panel_source" 'function updateReaderCornerDrag(currentX)'
assert_contains "$panel_source" 'function finishReaderCornerDrag()'
assert_contains "$panel_source" 'id: readerPageCancel'
assert_contains "$panel_source" 'id: readerIncomingPage'
assert_contains "$panel_source" 'id: readerBackCornerFold'
assert_contains "$panel_source" 'id: readerFolioPulseAnimation'
assert_contains "$panel_source" 'readerDragWasActive'
assert_contains "$panel_source" 'function focusReaderKeyboard()'
assert_contains "$panel_source" 'onReaderModeChanged: {'
assert_contains "$panel_source" 'root.stopReaderTurnAnimations()'
assert_contains "$panel_source" 'onReaderLibraryOpenChanged: if (root.readerMode) root.focusReaderKeyboard()'
assert_contains "$panel_source" 'Keys.priority: Keys.BeforeItem'
assert_contains "$panel_source" 'event.key === Qt.Key_PageDown'
assert_contains "$panel_source" 'event.key === Qt.Key_PageUp'
assert_contains "$panel_source" 'root.turnReaderPage(0)'
assert_contains "$panel_source" 'root.turnReaderPage(root.readerPages.length - 1)'
assert_contains "$panel_source" 'event.key === Qt.Key_N'
assert_contains "$panel_source" 'event.key === Qt.Key_P'
assert_contains "$panel_source" 'text === "o" || text === "O"'
assert_contains "$panel_source" 'id: readerKeyboardHint'
assert_contains "$panel_source" 'id: readerSpineShadow'
assert_contains "$panel_source" 'root.readerTurnProgress * Style.space(36)'
assert_contains "$panel_source" 'id: readerPageContent'
assert_contains "$panel_source" 'id: readerPageSwapTimer'
assert_contains "$panel_source" 'id: readerMasthead'
assert_contains "$panel_source" 'id: readerPageProgress'
assert_contains "$panel_source" 'id: readerPaperInset'
assert_contains "$panel_source" 'id: readerCornerFold'
assert_contains "$panel_source" 'ShapePath {'
assert_contains "$panel_source" 'id: readerStopButton'
assert_contains "$panel_source" 'text: "Stop"'
assert_contains "$panel_source" 'id: readerLibrary'
assert_contains "$panel_source" 'id: readerChapterGrid'
assert_contains "$panel_source" 'function toggleCurrentBookmark()'
assert_contains "$panel_source" 'function recordRecent()'
assert_contains "$panel_source" 'atomicWrites: true'
assert_contains "$panel_source" 'stateFile.setText(JSON.stringify({'
assert_contains "$panel_source" 'if (root.reduceMotion) {'
assert_contains "$panel_source" 'function calibrateNarrationTiming()'
assert_contains "$panel_source" 'root.calibrateNarrationTiming()'
assert_contains "$panel_source" 'text: "REDUCED MOTION"'
assert_contains "$panel_source" 'property bool readerStateHydrated: false'
assert_contains "$panel_source" 'if (root.readerStateHydrated) return'
assert_contains "$panel_source" 'function moveLibraryCursor(dx, dy)'
assert_contains "$panel_source" 'function activateLibraryCursor()'
assert_contains "$panel_source" 'onTabRequested: function(direction)'
assert_contains "$panel_source" '"No saved verses yet"'
assert_contains "$panel_source" '"No recent chapters yet"'
assert_contains "$panel_source" 'id: reducedMotionMouse'
assert_contains "$panel_source" 'PanelToolTip {'
assert_contains "$panel_source" 'root.readerActionFeedback = "Saved " + row.reference'
assert_contains "$panel_source" 'delegate: CursorSurface {'
assert_contains "$panel_source" 'function removeBookmarkAt(index)'
assert_contains "$panel_source" 'onDeleteRequested: {'
assert_contains "$panel_source" 'tooltipText: "Remove from Saved"'
assert_contains "$panel_source" '"↑↓ select  ·  ENTER open  ·  X remove"'
assert_contains "$panel_source" 'id: panelScroll'
assert_contains "$panel_source" 'ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff'
assert_contains "$panel_source" 'contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(560))'
assert_contains "$panel_source" '"No books match “" + root.readerBookFilter + "”"'
assert_contains "$panel_source" 'text: "Press Escape to clear the filter."'
assert_contains "$panel_source" 'function installVoiceEngine()'
assert_contains "$panel_source" 'Quickshell.execDetached(["omarchy-launch-terminal", "omarchy", "pkg", "add", "espeak-ng"])'
assert_contains "$panel_source" 'if (root.ttsChecked && !root.ttsAvailable && !ttsDetectProc.running) root.detectTts()'
assert_contains "$panel_source" 'id: voiceSetupCard'
assert_contains "$panel_source" 'text: "Reading aloud needs a local voice"'
assert_contains "$panel_source" 'text: "CHECK AGAIN"'
assert_contains "$panel_source" 'property bool piperReady: false'
assert_contains "$panel_source" 'id: voiceStatusProc'
assert_contains "$panel_source" 'speechPrepareProc.command = [root.scriptPath, "prepare-speech", row.verse, String(root.narrationSpeed)]'
assert_contains "$panel_source" 'var voicePrefix = root.usePiper ? "Neural voice · " : "Reading · "'
assert_contains "$panel_source" 'id: resultCardContent'
assert_contains "$panel_source" 'id: resultCopyMouse'
assert_contains "$(< "$BIN")" "readonly PIPER_MODEL=\"\$PIPER_ROOT/voices/en_US-ryan-medium.onnx\""
assert_contains "$(< "$BIN")" "(( \${#text} <= 4000 ))"
assert_contains "$(< "$BIN")" "paplay \"\$speech_file\""
assert_contains "$(< "$BIN")" 'trap cleanup_speech EXIT INT TERM'
assert_contains "$(< "$BIN")" "kill \"\$speech_child\" 2>/dev/null || true"
assert_contains "$panel_source" 'property int narrationWarmupRemainingMs: 0'
assert_contains "$panel_source" 'ttsProc.command = ["paplay", root.preparedSpeechPath]'
assert_contains "$panel_source" 'root.narrationEstimatedMs = Math.max(700, Number(durationMs) || root.narrationEstimatedMs)'
assert_contains "$panel_source" 'function wordCadenceWeight(word)'
assert_contains "$panel_source" 'function narrationCadenceWeight()'
assert_contains "$panel_source" 'var spokenDuration = Math.max(1, root.narrationEstimatedMs - leadIn)'
assert_contains "$panel_source" 'interval: 40'
assert_contains "$panel_source" 'id: speechPrefetchProc'
assert_contains "$panel_source" 'function startSpeechPrefetch()'
assert_contains "$panel_source" 'root.prefetchRequestIndex = nextIndex'
assert_contains "$panel_source" 'root.prefetchedSpeechIndex === root.narrationIndex'
assert_contains "$panel_source" 'root.startSpeechPrefetch()'
assert_contains "$panel_source" 'function cleanupPrefetchedSpeech()'
assert_contains "$panel_source" 'function rotateTopicSuggestions()'
assert_contains "$panel_source" 'model: root.topicSuggestions'
assert_contains "$panel_source" 'var hour = new Date().getHours()'
assert_contains "$panel_source" 'function toggleNarrationPause()'
assert_contains "$panel_source" 'function resumeNarrationProcessBeforeCancel()'
assert_contains "$panel_source" '["kill", root.narrationPaused ? "-STOP" : "-CONT", String(ttsProc.processId)]'
assert_contains "$panel_source" 'id: narrationCompleteTimer'
assert_contains "$panel_source" 'root.narrationCardPinned = false'
assert_contains "$panel_source" 'property real narrationSpeed: 1.0'
assert_contains "$panel_source" 'property string preferredVoice: "male"'
assert_contains "$panel_source" 'property bool dailyOnOpen: true'
assert_contains "$panel_source" 'id: settingsPanel'
assert_contains "$panel_source" 'root.prefetchedSpeechReference === row.reference'
assert_contains "$panel_source" 'root.topSpeechReady ? "Read"'
assert_contains "$(< "$BIN")" 'speech speed must be 0.85, 1, or 1.15'
if "$BIN" prepare-speech "test" 2 >/dev/null 2>&1; then
  fail 'prepare-speech accepted an out-of-range speed'
fi
assert_contains "$panel_source" 'function showDailyVerse()'
assert_contains "$panel_source" 'id: dailyProc'
assert_contains "$panel_source" 'id: dailySuggestion'
assert_contains "$panel_source" 'onClicked: root.showDailyVerse()'
assert_contains "$panel_source" 'enabled: !dailyProc.running'
assert_contains "$panel_source" 'text: dailyProc.running ? "…" : "Daily"'
assert_contains "$panel_source" 'function parseDailyOutput(raw)'
assert_contains "$panel_source" 'property bool dailyView: false'
assert_contains "$panel_source" 'root.dailyView = true'
assert_contains "$panel_source" 'resultModel.append({ reference: fields[1], verse: fields.slice(2).join(" ") })'
assert_contains "$panel_source" 'if (root.dailyOnOpen && root.query.trim() === "" && resultModel.count === 0 && !dailyProc.running)'
assert_contains "$panel_source" 'visible: !root.readerMode && !root.settingsOpen'
assert_contains "$panel_source" 'text: dailyProc.running ?'
assert_contains "$panel_source" 'function preloadTopSpeech()'
assert_contains "$panel_source" 'id: topSpeechProc'
assert_contains "$panel_source" 'root.topSpeechReference === row.reference && root.topSpeechVerse === row.verse'
assert_contains "$panel_source" 'root.startPiperPlayback(topPath, topDuration, row)'
assert_contains "$panel_source" 'readonly property bool readAlongDuplicatesTop:'
assert_contains "$panel_source" 'visible: !(index === 0 && root.readAlongDuplicatesTop)'
assert_contains "$panel_source" '["comfort", "anxiety", "courage", "rest", "grief", "healing"]'
if grep -Fq -- 'id: browseButton' <<< "$panel_source"; then
  fail 'Browse Books still appears in the widget UI'
fi
assert_contains "$(< "$BIN")" 'daily_verse()'
assert_contains "$(< "$BIN")" 'command -v ffprobe >/dev/null 2>&1 || die "ffprobe is required for neural voice timing"'
assert_contains "$(< "$BIN")" "\"\$CACHE_ROOT\"/speech.*.wav) rm -f -- \"\$speech_file\""

close_block="$(sed -n '/function close()/,/^  }/p' "$REPO_ROOT/Panel.qml")"
if grep -Fq -- 'root.stopNarration()' <<< "$close_block"; then
  fail 'closing the anchored panel stopped narration'
fi

assert_contains "$(< "$BIN")" 'sha256sum --check --strict --status'
assert_contains "$(< "$BIN")" 'unzip -tq'
assert_contains "$(< "$BIN")" '--max-filesize'
assert_contains "$(< "$BIN")" "stat -c '%s'"

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

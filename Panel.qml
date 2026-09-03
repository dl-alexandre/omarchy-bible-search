import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "dev.alexandre.bible-search"
  ipcTarget: "dev.alexandre.bible-search"
  manageIpc: true

  property var anchorItem: null
  property var hostWidget: null
  property string query: ""
  property bool dailyView: false
  property string statusText: "Search by word, phrase, or reference."
  property int selectedIndex: 0
  property int searchGeneration: 0
  property int activeSearchGeneration: 0
  property int pendingSearchGeneration: 0
  property string activeSearchQuery: ""
  property string pendingSearchQuery: ""
  property bool searchStopPending: false
  property string copyFeedback: ""
  property bool copyFailed: false
  property string copyReference: ""
  readonly property var ttsCandidates: ["espeak-ng", "espeak", "spd-say"]
  property int ttsCandidateIndex: 0
  property bool ttsChecked: false
  property string ttsEngine: ""
  property bool piperReady: false
  property bool narrationPaused: false
  property real narrationSpeed: 1.0
  property string preferredVoice: "male"
  property bool dailyOnOpen: true
  property bool settingsOpen: false
  property string narrationStatus: ""
  property var narrationQueue: []
  property int narrationIndex: 0
  property string narrationMode: ""
  property int narrationGeneration: 0
  property int ttsProcessGeneration: 0
  property bool narrationStopPending: false
  property var pendingNarrationQueue: []
  property string pendingNarrationMode: ""
  property int pendingNarrationIndex: 0
  property int pendingNarrationGeneration: 0
  property int chapterRequestGeneration: 0
  property int activeChapterRequest: 0
  property int narrationWordIndex: 0
  property int narrationElapsedMs: 0
  property int narrationWarmupRemainingMs: 0
  property int narrationLeadInMs: 110
  property string preparedSpeechPath: ""
  property string prefetchedSpeechPath: ""
  property int prefetchedSpeechDurationMs: 0
  property int prefetchedSpeechIndex: -1
  property string prefetchedSpeechReference: ""
  property string prefetchedSpeechVerse: ""
  property int prefetchRequestIndex: -1
  property int prefetchRequestGeneration: 0
  property string topSpeechPath: ""
  property int topSpeechDurationMs: 0
  property string topSpeechReference: ""
  property string topSpeechVerse: ""
  property int narrationEstimatedMs: 0
  property int narrationWpm: 165
  property real narrationTimingScale: 1.0
  property double narrationVerseStartedAt: 0
  property var narrationWords: []
  property var narrationCumulativeWeights: []
  property real narrationCadenceTotal: 1
  property bool narrationCardPinned: false
  property bool readerMode: false
  property bool readerLoading: false
  property string readerChapterLabel: ""
  property var readerChapterQueue: []
  property var readerPages: []
  property int readerPageIndex: 0
  property int readerSelectedVerseIndex: 0
  property string chapterLoadPurpose: ""
  property bool readerTurning: false
  property int readerTurnTargetPage: 0
  property int readerTurnDirection: 1
  property real readerTurnAngle: 0
  property real readerTurnProgress: 0
  property bool readerDragging: false
  property bool readerDragMoved: false
  property bool readerDragWasActive: false
  property bool readerTurnCrossesChapter: false
  property real readerDragStartX: 0
  property int readerTurnApproachDuration: 340
  property int readerTurnSettleDuration: 420
  property int readerTurnCancelDuration: 220
  property real readerFolioPulse: 0
  property bool readerLibraryOpen: false
  property string readerLibraryTab: "books"
  property string readerBookFilter: ""
  property string readerCatalogBook: "Genesis"
  property int readerCatalogChapterCount: 50
  property bool catalogLoaded: false
  property string readerPendingReference: ""
  property int readerRestorePage: -1
  property int readerRestoreVerse: -1
  property bool readerStateReady: false
  property bool readerStateLoading: true
  property bool readerStateHydrated: false
  property var readerSavedPosition: null
  property bool reduceMotion: false
  property string readerLibraryFocus: "books"
  property int readerBookCursor: 0
  property int readerChapterCursor: 0
  property int readerListCursor: 0
  property string readerActionFeedback: ""
  property var topicSuggestions: ["faith", "comfort", "wisdom", "love"]
  property int topicSuggestionOffset: -1
  readonly property bool usePiper: root.piperReady && root.preferredVoice === "male"
  readonly property bool ttsAvailable: root.usePiper || (root.ttsEngine !== "" && root.ttsEngine !== "piper")
  readonly property bool narrationActive: ttsProc.running || speechPrepareProc.running || speechPrefetchProc.running || chapterProc.running || root.narrationStopPending
  readonly property bool readAlongVisible: root.narrationCardPinned && root.narrationQueue.length > 0
  readonly property bool readAlongDuplicatesTop: root.readAlongVisible && resultModel.count > 0
    && root.narrationDisplayRow && root.narrationDisplayRow.reference === resultModel.get(0).reference
  readonly property bool topSpeechReady: resultModel.count > 0 && root.topSpeechPath !== ""
    && root.topSpeechReference === resultModel.get(0).reference && root.topSpeechVerse === resultModel.get(0).verse
  readonly property int narrationDisplayIndex: root.narrationQueue.length === 0
    ? -1
    : Math.min(root.narrationIndex, root.narrationQueue.length - 1)
  readonly property real narrationProgress: root.narrationQueue.length === 0
    ? 0
      : Math.min(1, (root.narrationIndex + (root.narrationMode !== ""
      ? (root.narrationWordIndex + 1) / Math.max(1, root.narrationWords.length)
      : 1)) / root.narrationQueue.length)
  readonly property bool readerHasPages: root.readerPages.length > 0
  readonly property var currentReaderPage: root.readerHasPages
    ? root.readerPages[Math.max(0, Math.min(root.readerPageIndex, root.readerPages.length - 1))]
    : null
  readonly property var readerTurnPage: root.readerHasPages
    && root.readerTurnTargetPage >= 0
    && root.readerTurnTargetPage < root.readerPages.length
    ? root.readerPages[root.readerTurnTargetPage]
    : null
  readonly property int readerFocusVerseIndex: root.readerSelectedVerseIndex
  readonly property string readerStatePath: {
    var dataHome = Quickshell.env("XDG_DATA_HOME")
    if (dataHome === "") dataHome = Quickshell.env("HOME") + "/.local/share"
    return dataHome + "/omarchy-bible-search/reader-state.json"
  }

  readonly property string scriptPath: {
    var path = String(Qt.resolvedUrl("bin/omarchy-bible-search"))
    if (path.indexOf("file://") === 0) path = path.substring(7)
    return decodeURIComponent(path)
  }

  readonly property color popupForeground: Color.popups.text

  function focusReaderKeyboard() {
    Qt.callLater(function() {
      if (root.opened && root.readerMode && keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function open() {
    root.controller.show()
    root.rotateTopicSuggestions()
    if (root.ttsChecked && !root.ttsAvailable && !ttsDetectProc.running) root.detectTts()
    if (root.dailyOnOpen && root.query.trim() === "" && resultModel.count === 0 && !dailyProc.running) {
      root.showDailyVerse()
    } else if (root.query.trim() !== "" && resultModel.count === 0 && !searchProc.running && !root.searchStopPending) {
      root.searchGeneration++
      root.statusText = "Searching…"
      searchTimer.restart()
    }
    Qt.callLater(function() {
      if (root.readerMode) keyCatcher.forceActiveFocus()
      else searchField.forceActiveFocus()
    })
  }

  function rotateTopicSuggestions() {
    var hour = new Date().getHours()
    var moment = hour < 6 ? ["peace", "rest", "comfort", "prayer", "hope", "trust"]
      : hour < 12 ? ["purpose", "wisdom", "gratitude", "strength", "guidance", "faith"]
      : hour < 18 ? ["patience", "courage", "work", "justice", "mercy", "perseverance"]
      : ["peace", "family", "reflection", "forgiveness", "rest", "thanksgiving"]
    var categories = [
      moment,
      ["faith", "hope", "prayer", "worship", "grace", "salvation"],
      ["comfort", "anxiety", "courage", "rest", "grief", "healing"],
      ["love", "forgiveness", "family", "friendship", "mercy", "justice"]
    ]
    root.topicSuggestionOffset = (root.topicSuggestionOffset + 1) % 36
    var next = []
    for (var i = 0; i < categories.length; i++) {
      var topic = categories[i][(root.topicSuggestionOffset * (i + 1) + i * 2) % categories[i].length]
      next.push(topic)
    }
    root.topicSuggestions = next
  }

  function showDailyVerse() {
    if (dailyProc.running) return
    root.dailyView = true
    resultModel.clear()
    root.selectedIndex = 0
    root.statusText = "Choosing today’s verse…"
    dailyProc.running = true
  }

  function parseDailyOutput(raw) {
    resultModel.clear()
    var lines = raw.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.indexOf("RESULT\t") !== 0) continue
      var fields = line.split("\t")
      if (fields.length < 3) continue
      resultModel.append({ reference: fields[1], verse: fields.slice(2).join(" ") })
      break
    }
    root.selectedIndex = 0
    if (resultModel.count > 0) {
      root.statusText = "Today · " + resultModel.get(0).reference
      root.preloadTopSpeech()
    } else {
      root.statusText = "Today’s verse was unavailable"
    }
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function showSearch() {
    root.readerMode = false
    root.readerLibraryOpen = false
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function scheduleSearch() {
    root.searchGeneration++
    root.selectedIndex = 0
    root.copyFeedback = ""
    root.copyFailed = false
    copyFeedbackTimer.stop()
    root.statusText = root.query.trim() === ""
      ? "Search by word, phrase, or reference."
      : "Searching…"
    searchTimer.restart()
  }

  function startSearch(searchQuery, generation) {
    if (generation !== root.searchGeneration || searchQuery !== root.query) return
    if (searchQuery.trim() === "") {
      resultModel.clear()
      root.statusText = "Search by word, phrase, or reference."
      return
    }
    root.activeSearchGeneration = generation
    root.activeSearchQuery = searchQuery
    root.statusText = "Searching…"
    searchProc.command = [root.scriptPath, "search", searchQuery]
    searchProc.running = true
  }

  function detectTts() {
    if (ttsDetectProc.running) return
    root.ttsChecked = false
    root.ttsEngine = ""
    root.ttsCandidateIndex = 0
    ttsDetectProc.command = [root.ttsCandidates[0], "--version"]
    ttsDetectProc.running = true
    if (!voiceStatusProc.running) voiceStatusProc.running = true
  }

  function installVoiceEngine() {
    root.narrationStatus = "Install espeak-ng in the terminal, then choose Check again."
    Quickshell.execDetached(["omarchy-launch-terminal", "omarchy", "pkg", "add", "espeak-ng"])
  }

  function runSearch() {
    var searchQuery = root.query
    var generation = root.searchGeneration

    if (root.searchStopPending) {
      root.pendingSearchQuery = searchQuery
      root.pendingSearchGeneration = generation
      return
    }

    if (searchProc.running) {
      root.pendingSearchQuery = searchQuery
      root.pendingSearchGeneration = generation
      root.searchStopPending = true
      searchProc.running = false
      return
    }

    root.startSearch(searchQuery, generation)
  }

  function parseSearchOutput(raw) {
    resultModel.clear()
    var lines = String(raw || "").split("\n")
    var found = 0
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length >= 2 && parts[0] === "STATUS") {
        root.statusText = parts.slice(1).join(" ")
      } else if (parts.length >= 3 && parts[0] === "RESULT") {
        resultModel.append({ reference: parts[1], verse: parts.slice(2).join(" ") })
        found++
      }
    }
    if (found > 0) {
      root.statusText = found + " result" + (found === 1 ? "" : "s") + " · click to copy"
      root.preloadTopSpeech()
    }
    root.selectedIndex = 0
  }

  function moveSelection(delta) {
    if (resultModel.count === 0) return
    root.selectedIndex = (root.selectedIndex + delta + resultModel.count) % resultModel.count
    resultList.contentY = Math.max(0, Math.min(
      resultList.contentHeight - resultList.height,
      root.selectedIndex * Style.space(72)
    ))
  }

  function activateSelected() {
    if (resultModel.count > 0) copyResult(root.selectedIndex)
  }

  function browse() {
    root.close()
    Quickshell.execDetached(["omarchy-launch-tui", root.scriptPath, "browse"])
  }

  function showNarrationUnavailable() {
    root.narrationStatus = root.ttsChecked
      ? "No local voice engine found · install espeak-ng, espeak, or speech-dispatcher"
      : "Checking for a local voice engine…"
  }

  function queueFromOutput(raw) {
    var lines = String(raw || "").split("\n")
    var queue = []
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length >= 3 && parts[0] === "RESULT") {
        queue.push({ reference: parts[1], verse: parts.slice(2).join(" ") })
      }
    }
    return queue
  }

  function wordsFor(text) {
    var trimmed = String(text || "").trim()
    return trimmed === "" ? [] : trimmed.split(/\s+/)
  }

  function wordDurationMs(word) {
    var value = String(word || "")
    var duration = 60000 / Math.max(80, root.narrationWpm)
    duration *= 1 + Math.min(0.7, Math.max(0, value.length - 5) * 0.035)
    if (/[,;:]$/.test(value)) duration += 90
    if (/[.!?]$/.test(value)) duration += 220
    return Math.round(duration * Math.max(0.55, Math.min(1.9, root.narrationTimingScale)))
  }

  function wordCadenceWeight(word) {
    var value = String(word || "")
    var spoken = value.replace(/^[“‘\"'([{]+|[”’\"')\]}.,;:!?—–-]+$/g, "")
    var weight = 0.72 + Math.min(0.92, Math.max(1, spoken.length) * 0.075)
    if (/[-—–]$/.test(value)) weight += 0.32
    if (/[,;:]$/.test(value)) weight += 0.42
    if (/[.!?][”’\"']?$/.test(value)) weight += 0.78
    return weight
  }

  function narrationCadenceWeight() {
    // Computes the cumulative cadence-weight array for the current
    // root.narrationWords ONCE (called when a verse begins narrating),
    // so the per-tick highlight update never has to re-run the
    // regex-heavy wordCadenceWeight() for every word in the verse.
    var total = 0
    var cumulative = []
    for (var i = 0; i < root.narrationWords.length; i++) {
      total += root.wordCadenceWeight(root.narrationWords[i])
      cumulative.push(total)
    }
    root.narrationCumulativeWeights = cumulative
    root.narrationCadenceTotal = Math.max(1, total)
    return root.narrationCadenceTotal
  }

  function baseNarrationMs(words) {
    var total = 0
    for (var i = 0; i < words.length; i++) {
      var value = String(words[i] || "")
      var duration = 60000 / Math.max(80, root.narrationWpm)
      duration *= 1 + Math.min(0.7, Math.max(0, value.length - 5) * 0.035)
      if (/[,;:]$/.test(value)) duration += 90
      if (/[.!?]$/.test(value)) duration += 220
      total += Math.round(duration)
    }
    return Math.max(700, total)
  }

  function calibrateNarrationTiming() {
    if (root.narrationVerseStartedAt <= 0 || root.narrationWords.length === 0) return
    var elapsed = Date.now() - root.narrationVerseStartedAt
    var baseline = root.baseNarrationMs(root.narrationWords)
    if (elapsed < 250 || baseline <= 0) return
    var observed = Math.max(0.55, Math.min(1.9, elapsed / baseline))
    root.narrationTimingScale = Math.max(0.55, Math.min(1.9,
      (root.narrationTimingScale * 0.72) + (observed * 0.28)))
  }

  function estimateNarrationMs(words) {
    var total = 0
    for (var i = 0; i < words.length; i++) total += root.wordDurationMs(words[i])
    return Math.max(700, total)
  }

  function updateNarrationWord() {
    var leadIn = root.piperReady ? root.narrationLeadInMs : 0
    if (root.narrationElapsedMs <= leadIn) {
      root.narrationWordIndex = 0
      return
    }
    var spokenDuration = Math.max(1, root.narrationEstimatedMs - leadIn)
    var cadencePosition = Math.min(1, (root.narrationElapsedMs - leadIn) / spokenDuration)
      * root.narrationCadenceTotal
    var weights = root.narrationCumulativeWeights
    for (var i = 0; i < weights.length; i++) {
      if (cadencePosition < weights[i]) {
        root.narrationWordIndex = i
        return
      }
    }
    root.narrationWordIndex = Math.max(0, root.narrationWords.length - 1)
  }

  function advanceNarrationWord() {
    if (!ttsProc.running || root.narrationWords.length === 0) return
    if (root.narrationWarmupRemainingMs > 0) {
      root.narrationWarmupRemainingMs = Math.max(0, root.narrationWarmupRemainingMs - narrationHighlightTimer.interval)
      return
    }
    root.narrationElapsedMs = Math.min(root.narrationEstimatedMs, root.narrationElapsedMs + narrationHighlightTimer.interval)
    root.updateNarrationWord()
  }

  function narrationRowAt(offset) {
    var index = root.narrationDisplayIndex + offset
    if (index < 0 || index >= root.narrationQueue.length) return null
    return root.narrationQueue[index]
  }

  function beginNarration(queue, mode, generation, startIndex) {
    if (generation !== root.narrationGeneration || queue.length === 0) return
    root.narrationQueue = queue
    root.narrationIndex = Math.max(0, Math.min(startIndex || 0, queue.length - 1))
    root.narrationMode = mode
    root.narrationStatus = mode === "chapter"
      ? "Reading chapter · " + queue.length + " verses"
      : "Reading " + queue[0].reference
    root.speakNext(generation)
  }

  function continuePendingNarration() {
    root.narrationStopPending = false
    var nextQueue = root.pendingNarrationQueue
    var nextMode = root.pendingNarrationMode
    var nextIndex = root.pendingNarrationIndex
    var nextGeneration = root.pendingNarrationGeneration
    root.pendingNarrationQueue = []
    root.pendingNarrationMode = ""
    root.pendingNarrationIndex = 0
    root.pendingNarrationGeneration = 0
    if (nextQueue.length > 0 && nextGeneration === root.narrationGeneration) {
      Qt.callLater(function() { root.beginNarration(nextQueue, nextMode, nextGeneration, nextIndex) })
    }
  }

  function cleanupPreparedSpeech() {
    if (root.preparedSpeechPath === "") return
    Quickshell.execDetached([root.scriptPath, "speech-cleanup", root.preparedSpeechPath])
    root.preparedSpeechPath = ""
  }

  function cleanupPrefetchedSpeech() {
    if (speechPrefetchProc.running) speechPrefetchProc.running = false
    if (root.prefetchedSpeechPath !== "") {
      Quickshell.execDetached([root.scriptPath, "speech-cleanup", root.prefetchedSpeechPath])
    }
    root.prefetchedSpeechPath = ""
    root.prefetchedSpeechDurationMs = 0
    root.prefetchedSpeechIndex = -1
    root.prefetchedSpeechReference = ""
    root.prefetchedSpeechVerse = ""
    root.prefetchRequestIndex = -1
    root.prefetchRequestGeneration = 0
  }

  function cleanupTopSpeech() {
    if (topSpeechProc.running) topSpeechProc.running = false
    if (root.topSpeechPath !== "") {
      Quickshell.execDetached([root.scriptPath, "speech-cleanup", root.topSpeechPath])
    }
    root.topSpeechPath = ""
    root.topSpeechDurationMs = 0
    root.topSpeechReference = ""
    root.topSpeechVerse = ""
  }

  function preloadTopSpeech() {
    if (!root.usePiper || resultModel.count === 0 || topSpeechProc.running) return
    var row = resultModel.get(0)
    if (root.topSpeechPath !== "" && root.topSpeechReference === row.reference
        && root.topSpeechVerse === row.verse) return
    root.cleanupTopSpeech()
    root.topSpeechReference = row.reference
    root.topSpeechVerse = row.verse
    topSpeechProc.command = [root.scriptPath, "prepare-speech", row.verse, String(root.narrationSpeed)]
    topSpeechProc.running = true
  }

  function setNarrationSpeed(speed) {
    root.narrationSpeed = Math.max(0.85, Math.min(1.15, Number(speed) || 1))
    root.cleanupTopSpeech()
    root.preloadTopSpeech()
    root.scheduleReaderStateSave()
  }

  function toggleNarrationPause() {
    if (!ttsProc.running || ttsProc.processId <= 0) {
      if (resultModel.count > 0) root.readVerse(root.selectedIndex)
      return
    }
    root.narrationPaused = !root.narrationPaused
    Quickshell.execDetached(["kill", root.narrationPaused ? "-STOP" : "-CONT", String(ttsProc.processId)])
    root.narrationStatus = root.narrationPaused ? "Paused · Space to resume" : "Reading · " + root.narrationDisplayRow.reference
  }

  function resumeNarrationProcessBeforeCancel() {
    if (!root.narrationPaused || !ttsProc.running || ttsProc.processId <= 0) return
    Quickshell.execDetached(["kill", "-CONT", String(ttsProc.processId)])
    root.narrationPaused = false
  }

  function startPiperPlayback(path, durationMs, row) {
    root.preparedSpeechPath = path
    root.narrationEstimatedMs = Math.max(700, Number(durationMs) || root.narrationEstimatedMs)
    root.narrationElapsedMs = 0
    root.narrationWordIndex = 0
    root.narrationVerseStartedAt = Date.now()
    root.narrationStatus = "Neural voice · " + (row ? row.reference : "reading")
    ttsProc.command = ["paplay", root.preparedSpeechPath]
    ttsProc.running = true
    root.startSpeechPrefetch()
  }

  function startSpeechPrefetch() {
    if (!root.usePiper || speechPrefetchProc.running) return
    var nextIndex = root.narrationIndex + 1
    var nextRow = null
    if (root.narrationMode === "chapter" && nextIndex < root.narrationQueue.length) {
      nextRow = root.narrationQueue[nextIndex]
    } else if (root.narrationMode === "verse" && root.selectedIndex + 1 < resultModel.count) {
      nextIndex = -2
      nextRow = resultModel.get(root.selectedIndex + 1)
    }
    if (!nextRow) return
    root.cleanupPrefetchedSpeech()
    root.prefetchRequestIndex = nextIndex
    root.prefetchRequestGeneration = root.narrationGeneration
    root.prefetchedSpeechReference = nextRow.reference
    root.prefetchedSpeechVerse = nextRow.verse
    speechPrefetchProc.command = [root.scriptPath, "prepare-speech", nextRow.verse, String(root.narrationSpeed)]
    speechPrefetchProc.running = true
  }

  function requestNarration(queue, mode, startIndex) {
    if (!root.ttsAvailable) {
      root.showNarrationUnavailable()
      return
    }
    if (!queue || queue.length === 0) return
    var firstIndex = Math.max(0, Math.min(startIndex || 0, queue.length - 1))
    root.narrationCardPinned = true
    var firstRow = queue[firstIndex]
    if (root.prefetchedSpeechPath === "" || root.prefetchedSpeechReference !== firstRow.reference
        || root.prefetchedSpeechVerse !== firstRow.verse) root.cleanupPrefetchedSpeech()

    if (chapterProc.running) {
      root.chapterRequestGeneration++
      chapterProc.running = false
    }

    root.narrationGeneration++
    var generation = root.narrationGeneration
    if (root.narrationStopPending || ttsProc.running || speechPrepareProc.running) {
      root.pendingNarrationQueue = queue
      root.pendingNarrationMode = mode
      root.pendingNarrationIndex = firstIndex
      root.pendingNarrationGeneration = generation
      if (!root.narrationStopPending) {
        root.narrationStopPending = true
        if (ttsProc.running) {
          root.resumeNarrationProcessBeforeCancel()
          ttsProc.running = false
        }
        if (speechPrepareProc.running) speechPrepareProc.running = false
      }
      return
    }
    root.beginNarration(queue, mode, generation, firstIndex)
  }

  function readVerse(index) {
    if (index < 0 || index >= resultModel.count) return
    var row = resultModel.get(index)
    root.requestNarration([{ reference: row.reference, verse: row.verse }], "verse")
  }

  function readChapter(index) {
    if (index < 0 || index >= resultModel.count) return
    if (!root.ttsAvailable) {
      root.showNarrationUnavailable()
      return
    }
    if (chapterProc.running) {
      root.narrationStatus = "A chapter is already loading"
      return
    }

    var row = resultModel.get(index)
    var match = String(row.reference || "").match(/^(.+)\s+([0-9]+):[0-9]+$/)
    if (!match) {
      root.narrationStatus = "Select a verse with a chapter reference first"
      return
    }

    root.stopNarration()
    root.chapterLoadPurpose = "narration"
    root.readerChapterLabel = match[1] + " " + match[2]
    root.chapterRequestGeneration++
    root.activeChapterRequest = root.chapterRequestGeneration
    root.narrationMode = "chapter"
    root.narrationStatus = "Loading " + match[1] + " " + match[2] + "…"
    chapterProc.command = [root.scriptPath, "chapter", match[1] + " " + match[2]]
    chapterProc.running = true
  }

  function chapterDetails(reference) {
    var match = String(reference || "").match(/^(.+)\s+([0-9]+):[0-9]+$/)
    return match ? { book: match[1], chapter: match[2] } : null
  }

  function currentChapterParts() {
    var match = String(root.readerChapterLabel || "").match(/^(.+)\s+([0-9]+)$/)
    return match ? { book: match[1], chapter: Number(match[2]) } : null
  }

  function catalogIndexForBook(book) {
    var needle = String(book || "").toLowerCase()
    for (var i = 0; i < bookCatalogModel.count; i++) {
      if (String(bookCatalogModel.get(i).bookName).toLowerCase() === needle) return i
    }
    return -1
  }

  function adjacentChapter(direction) {
    var current = root.currentChapterParts()
    if (!current || direction === 0 || bookCatalogModel.count === 0) return null
    var idx = root.catalogIndexForBook(current.book)
    if (idx < 0) return null
    var book = bookCatalogModel.get(idx)
    var chapter = current.chapter + direction
    if (chapter >= 1 && chapter <= Number(book.chapterCount))
      return { book: book.bookName, chapter: chapter }
    var nextIdx = idx + direction
    if (nextIdx < 0 || nextIdx >= bookCatalogModel.count) return null
    var nextBook = bookCatalogModel.get(nextIdx)
    return direction > 0
      ? { book: nextBook.bookName, chapter: 1 }
      : { book: nextBook.bookName, chapter: Number(nextBook.chapterCount) }
  }

  function canMoveReader(direction) {
    if (!root.readerHasPages) return false
    var target = root.readerPageIndex + direction
    if (target >= 0 && target < root.readerPages.length) return true
    return root.adjacentChapter(direction) !== null
  }

  function advanceReaderChapter(direction) {
    if (chapterProc.running || root.readerLoading) return false
    var next = root.adjacentChapter(direction)
    if (!next) {
      root.readerActionFeedback = direction > 0 ? "End of the Bible" : "Beginning of the Bible"
      readerActionFeedbackTimer.restart()
      return false
    }
    root.stopReaderTurnAnimations()
    root.readerTurning = false
    root.readerTurnCrossesChapter = false
    root.readerTurnAngle = 0
    root.readerTurnProgress = 0
    var landAtEnd = direction < 0
    root.openReaderChapter(next.book, next.chapter, "", landAtEnd ? 9999 : 0, landAtEnd ? 9999 : 0)
    return true
  }

  function buildReaderPages(queue) {
    var pages = []
    var start = 0
    var wordCount = 0
    var wordsPerPage = 95

    for (var i = 0; i < queue.length; i++) {
      var verseWords = root.wordsFor(queue[i].verse).length
      if (i > start && wordCount + verseWords > wordsPerPage) {
        pages.push({ start: start, end: i - 1, verses: queue.slice(start, i) })
        start = i
        wordCount = 0
      }
      wordCount += verseWords
    }
    if (start < queue.length) pages.push({ start: start, end: queue.length - 1, verses: queue.slice(start) })
    return pages
  }

  function readerPageForVerse(index) {
    for (var i = 0; i < root.readerPages.length; i++) {
      if (index >= root.readerPages[i].start && index <= root.readerPages[i].end) return i
    }
    return -1
  }

  function setReaderChapter(queue, label) {
    root.readerChapterQueue = queue
    root.readerPages = root.buildReaderPages(queue)
    root.readerChapterLabel = label
    root.readerPageIndex = 0
    root.readerSelectedVerseIndex = 0
  }

  function parseCatalogOutput(raw) {
    bookCatalogModel.clear()
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length === 3 && parts[0] === "BOOK") {
        bookCatalogModel.append({ bookName: parts[1], chapterCount: Number(parts[2]) })
      }
    }
    root.catalogLoaded = bookCatalogModel.count > 0
    root.filterBookCatalog()
    if (root.catalogLoaded) root.selectCatalogBook(bookCatalogModel.get(0).bookName, bookCatalogModel.get(0).chapterCount)
  }

  function filterBookCatalog() {
    bookDisplayModel.clear()
    var needle = root.readerBookFilter.trim().toLowerCase()
    for (var i = 0; i < bookCatalogModel.count; i++) {
      var row = bookCatalogModel.get(i)
      if (needle === "" || String(row.bookName).toLowerCase().indexOf(needle) >= 0) {
        bookDisplayModel.append({ bookName: row.bookName, chapterCount: row.chapterCount })
      }
    }
    root.readerBookCursor = Math.max(0, Math.min(root.readerBookCursor, Math.max(0, bookDisplayModel.count - 1)))
    if (bookDisplayModel.count > 0) {
      var selected = bookDisplayModel.get(root.readerBookCursor)
      root.selectCatalogBook(selected.bookName, selected.chapterCount)
    }
  }

  function selectCatalogBook(book, chapterCount) {
    root.readerCatalogBook = book
    root.readerCatalogChapterCount = chapterCount
    chapterPickerModel.clear()
    for (var i = 1; i <= chapterCount; i++) chapterPickerModel.append({ chapterNumber: i })
    root.readerChapterCursor = 0
  }

  function setLibraryTab(tab) {
    root.readerLibraryTab = tab
    root.readerLibraryFocus = tab === "books" ? "books" : "list"
    root.readerListCursor = 0
  }

  function moveLibraryCursor(dx, dy) {
    if (root.readerLibraryTab === "books") {
      if (dx !== 0) root.readerLibraryFocus = dx > 0 ? "chapters" : "books"
      if (dy !== 0 && root.readerLibraryFocus === "books" && bookDisplayModel.count > 0) {
        root.readerBookCursor = Math.max(0, Math.min(bookDisplayModel.count - 1, root.readerBookCursor + dy))
        var book = bookDisplayModel.get(root.readerBookCursor)
        root.selectCatalogBook(book.bookName, book.chapterCount)
        readerBookList.positionViewAtIndex(root.readerBookCursor, ListView.Contain)
      } else if (root.readerLibraryFocus === "chapters" && chapterPickerModel.count > 0) {
        var columns = Math.max(1, Math.floor(readerChapterGrid.width / readerChapterGrid.cellWidth))
        var delta = dx !== 0 ? dx : dy * columns
        root.readerChapterCursor = Math.max(0, Math.min(chapterPickerModel.count - 1, root.readerChapterCursor + delta))
        readerChapterGrid.positionViewAtIndex(root.readerChapterCursor, GridView.Contain)
      }
    } else {
      var model = root.readerLibraryTab === "saved" ? bookmarkModel : recentModel
      if (dy !== 0 && model.count > 0) {
        root.readerListCursor = Math.max(0, Math.min(model.count - 1, root.readerListCursor + dy))
        readerStoredList.positionViewAtIndex(root.readerListCursor, ListView.Contain)
      }
    }
  }

  function activateLibraryCursor() {
    if (root.readerLibraryTab === "books") {
      if (root.readerLibraryFocus === "books" && bookDisplayModel.count > 0) {
        var book = bookDisplayModel.get(root.readerBookCursor)
        root.selectCatalogBook(book.bookName, book.chapterCount)
        root.readerLibraryFocus = "chapters"
      } else if (chapterPickerModel.count > 0) {
        root.openReaderChapter(root.readerCatalogBook, chapterPickerModel.get(root.readerChapterCursor).chapterNumber, "", -1, -1)
      }
    } else {
      var model = root.readerLibraryTab === "saved" ? bookmarkModel : recentModel
      if (model.count > 0) root.openStoredReader(model.get(root.readerListCursor))
    }
  }

  function cycleLibraryTab(direction) {
    var tabs = ["books", "saved", "recent"]
    var index = tabs.indexOf(root.readerLibraryTab)
    root.setLibraryTab(tabs[(index + direction + tabs.length) % tabs.length])
  }

  function openReaderChapter(book, chapter, targetReference, restorePage, restoreVerse) {
    root.stopNarration()
    root.readerMode = true
    root.readerLibraryOpen = false
    root.readerLoading = true
    root.readerPages = []
    root.readerChapterQueue = []
    root.readerChapterLabel = book + " " + chapter
    root.readerPendingReference = targetReference || ""
    root.readerRestorePage = restorePage === undefined ? -1 : restorePage
    root.readerRestoreVerse = restoreVerse === undefined ? -1 : restoreVerse
    root.readerPageIndex = 0
    root.readerSelectedVerseIndex = 0
    root.chapterLoadPurpose = "reader"
    root.chapterRequestGeneration++
    root.activeChapterRequest = root.chapterRequestGeneration
    root.narrationStatus = "Opening " + root.readerChapterLabel + "…"
    chapterProc.command = [root.scriptPath, "chapter", root.readerChapterLabel]
    chapterProc.running = true
    root.focusReaderKeyboard()
  }

  function openStoredReader(row) {
    if (!row) return
    var details = root.chapterDetails(row.reference || "")
    if (!details && row.chapterLabel) details = root.chapterDetails(row.chapterLabel + ":1")
    if (!details) return
    root.openReaderChapter(details.book, details.chapter, row.reference || "", row.pageIndex, row.verseIndex)
  }

  function stopReaderTurnAnimations() {
    readerPageTurn.stop()
    readerPageCancel.stop()
    readerPageSwapTimer.stop()
    readerPageResetTimer.stop()
  }

  function beginReaderCornerDrag(direction, startX) {
    if (root.reduceMotion || !root.readerHasPages || root.readerTurning) return false
    var targetPage = root.readerPageIndex + direction
    var inChapter = targetPage >= 0 && targetPage < root.readerPages.length
    if (!inChapter && !root.adjacentChapter(direction)) return false

    root.stopReaderTurnAnimations()
    root.readerTurnCrossesChapter = !inChapter
    root.readerTurnTargetPage = inChapter ? targetPage : root.readerPageIndex
    root.readerTurnDirection = direction
    root.readerDragging = true
    root.readerDragMoved = false
    root.readerDragWasActive = false
    root.readerDragStartX = startX
    root.readerTurnAngle = 0
    root.readerTurnProgress = 0
    root.readerTurning = true
    return true
  }

  function updateReaderCornerDrag(currentX) {
    if (!root.readerDragging) return
    var distance = root.readerTurnDirection > 0
      ? root.readerDragStartX - currentX
      : currentX - root.readerDragStartX
    var travel = Math.max(1, readerPageSurface.width * 0.42)
    var ratio = Math.max(0, Math.min(1, distance / travel))
    root.readerDragMoved = root.readerDragMoved || Math.abs(distance) > 3
    root.readerTurnProgress = ratio * 0.5
    root.readerTurnAngle = 0
  }

  function finishReaderCornerDrag() {
    if (!root.readerDragging) return
    var ratio = Math.max(0, Math.min(1, root.readerTurnProgress * 2))
    var wasDrag = root.readerDragMoved
    root.readerDragging = false
    root.readerDragWasActive = wasDrag
    root.readerTurnCancelDuration = Math.max(120, Math.round(ratio * 300))
    root.stopReaderTurnAnimations()

    if (!wasDrag) {
      root.readerTurning = false
      root.readerTurnAngle = 0
      root.readerTurnProgress = 0
      return
    }

    if (ratio >= 0.46) {
      if (root.readerTurnCrossesChapter) {
        root.advanceReaderChapter(root.readerTurnDirection)
        return
      }
      root.readerTurnApproachDuration = Math.max(70, Math.round((1 - ratio) * 200))
      root.readerTurnSettleDuration = 240
      readerPageSwapTimer.restart()
      readerPageResetTimer.restart()
      readerPageTurn.restart()
    } else {
      readerPageCancel.restart()
    }
  }

  function turnReaderPage(targetPage) {
    if (!root.readerHasPages || root.readerTurning) return
    var nextPage = Math.max(0, Math.min(targetPage, root.readerPages.length - 1))
    if (nextPage === root.readerPageIndex) return
    if (root.reduceMotion) {
      root.readerPageIndex = nextPage
      root.readerTurning = false
      root.readerTurnAngle = 0
      root.readerTurnProgress = 0
      return
    }
    root.stopReaderTurnAnimations()
    root.readerDragWasActive = false
    root.readerTurnTargetPage = nextPage
    root.readerTurnDirection = nextPage > root.readerPageIndex ? 1 : -1
    root.readerTurnApproachDuration = 200
    root.readerTurnSettleDuration = 240
    root.readerTurning = true
    root.readerTurnAngle = 0
    root.readerTurnProgress = 0
    readerPageSwapTimer.restart()
    readerPageResetTimer.restart()
    readerPageTurn.restart()
  }

  function moveReaderPage(delta) {
    var direction = delta > 0 ? 1 : -1
    var target = root.readerPageIndex + delta
    if (target < 0 || target >= root.readerPages.length) {
      root.advanceReaderChapter(direction)
    } else {
      root.turnReaderPage(target)
    }
    root.focusReaderKeyboard()
  }

  function syncReaderPageToVerse(index) {
    var page = root.readerPageForVerse(index)
    if (page >= 0 && page !== root.readerPageIndex) root.turnReaderPage(page)
  }

  function openReader(index) {
    if (index < 0 || index >= resultModel.count) return
    var details = root.chapterDetails(resultModel.get(index).reference)
    if (!details) {
      root.statusText = "Select a verse with a chapter reference first"
      return
    }

    root.openReaderChapter(details.book, details.chapter, resultModel.get(index).reference, -1, -1)
  }

  function modelRows(model, limit) {
    var rows = []
    for (var i = 0; i < Math.min(model.count, limit); i++) {
      var source = model.get(i)
      var row = {}
      for (var key in source) row[key] = source[key]
      rows.push(row)
    }
    return rows
  }

  function loadReaderState(raw) {
    if (root.readerStateHydrated) return
    root.readerStateLoading = true
    var state = {}
    try { state = JSON.parse(String(raw || "{}")) } catch (error) { state = {} }
    bookmarkModel.clear()
    recentModel.clear()
    var bookmarks = Array.isArray(state.bookmarks) ? state.bookmarks.slice(0, 30) : []
    var recents = Array.isArray(state.recents) ? state.recents.slice(0, 12) : []
    for (var i = 0; i < bookmarks.length; i++) bookmarkModel.append(bookmarks[i])
    for (var j = 0; j < recents.length; j++) recentModel.append(recents[j])
    root.readerSavedPosition = state.position || null
    root.reduceMotion = state.reduceMotion === true
    root.dailyOnOpen = state.dailyOnOpen !== false
    root.preferredVoice = state.preferredVoice === "system" ? "system" : "male"
    root.narrationSpeed = [0.85, 1, 1.15].indexOf(Number(state.narrationSpeed)) >= 0 ? Number(state.narrationSpeed) : 1
    var scale = Number(state.narrationTimingScale || 1)
    root.narrationTimingScale = Math.max(0.55, Math.min(1.9, isNaN(scale) ? 1 : scale))
    root.readerStateLoading = false
    root.readerStateReady = true
    root.readerStateHydrated = true
  }

  function saveReaderState() {
    if (!root.readerStateReady || root.readerStateLoading) return
    var position = root.readerSavedPosition
    if (root.readerHasPages && root.readerChapterQueue[root.readerSelectedVerseIndex]) {
      position = {
        chapterLabel: root.readerChapterLabel,
        reference: root.readerChapterQueue[root.readerSelectedVerseIndex].reference,
        pageIndex: root.readerPageIndex,
        verseIndex: root.readerSelectedVerseIndex
      }
      root.readerSavedPosition = position
    }
    stateFile.setText(JSON.stringify({
      version: 1,
      position: position,
      bookmarks: root.modelRows(bookmarkModel, 30),
      recents: root.modelRows(recentModel, 12),
      reduceMotion: root.reduceMotion,
      dailyOnOpen: root.dailyOnOpen,
      preferredVoice: root.preferredVoice,
      narrationSpeed: root.narrationSpeed,
      narrationTimingScale: root.narrationTimingScale
    }, null, 2) + "\n")
  }

  function scheduleReaderStateSave() {
    if (root.readerStateReady && !root.readerStateLoading) readerStateSaveTimer.restart()
  }

  function currentReaderBookmarkIndex() {
    var row = root.readerChapterQueue[root.readerSelectedVerseIndex]
    if (!row) return -1
    for (var i = 0; i < bookmarkModel.count; i++) {
      if (bookmarkModel.get(i).reference === row.reference) return i
    }
    return -1
  }

  function toggleCurrentBookmark() {
    var row = root.readerChapterQueue[root.readerSelectedVerseIndex]
    if (!row) return
    var existing = root.currentReaderBookmarkIndex()
    if (existing >= 0) {
      bookmarkModel.remove(existing)
      root.readerActionFeedback = "Removed " + row.reference + " from Saved"
    } else {
      bookmarkModel.insert(0, {
      reference: row.reference, verse: row.verse, chapterLabel: root.readerChapterLabel,
      pageIndex: root.readerPageIndex, verseIndex: root.readerSelectedVerseIndex,
      savedAt: Date.now()
      })
      root.readerActionFeedback = "Saved " + row.reference
    }
    while (bookmarkModel.count > 30) bookmarkModel.remove(bookmarkModel.count - 1)
    root.scheduleReaderStateSave()
    readerActionFeedbackTimer.restart()
  }

  function removeBookmarkAt(index) {
    if (index < 0 || index >= bookmarkModel.count) return
    var reference = bookmarkModel.get(index).reference
    bookmarkModel.remove(index)
    root.readerListCursor = Math.max(0, Math.min(root.readerListCursor, Math.max(0, bookmarkModel.count - 1)))
    root.readerActionFeedback = "Removed " + reference + " from Saved"
    root.scheduleReaderStateSave()
    readerActionFeedbackTimer.restart()
  }

  function recordRecent() {
    var row = root.readerChapterQueue[root.readerSelectedVerseIndex]
    if (!row) return
    for (var i = recentModel.count - 1; i >= 0; i--) {
      if (recentModel.get(i).chapterLabel === root.readerChapterLabel) recentModel.remove(i)
    }
    recentModel.insert(0, {
      reference: row.reference, chapterLabel: root.readerChapterLabel,
      pageIndex: root.readerPageIndex, verseIndex: root.readerSelectedVerseIndex,
      openedAt: Date.now()
    })
    while (recentModel.count > 12) recentModel.remove(recentModel.count - 1)
    root.scheduleReaderStateSave()
  }

  function readReaderSelectedVerse() {
    if (!root.readerChapterQueue[root.readerSelectedVerseIndex]) return
    var row = root.readerChapterQueue[root.readerSelectedVerseIndex]
    root.requestNarration([{ reference: row.reference, verse: row.verse }], "verse")
  }

  function readReaderChapter() {
    if (root.readerChapterQueue.length === 0) return
    root.requestNarration(root.readerChapterQueue, "chapter", root.readerSelectedVerseIndex)
  }

  function speakNext(generation) {
    if (generation !== root.narrationGeneration || root.narrationQueue.length === 0) return
    if (root.narrationIndex >= root.narrationQueue.length) {
      root.narrationStatus = root.narrationMode === "chapter" ? "Chapter finished" : "Finished reading"
      root.narrationMode = ""
      root.scheduleReaderStateSave()
      return
    }
    var row = root.narrationQueue[root.narrationIndex]
    if (root.narrationMode === "chapter") {
      var chapterIndex = root.readerChapterQueue.indexOf(row)
      root.readerSelectedVerseIndex = chapterIndex >= 0 ? chapterIndex : root.narrationIndex
      if (root.readerMode) root.syncReaderPageToVerse(root.readerSelectedVerseIndex)
    }
    root.narrationWords = root.wordsFor(row.verse)
    root.narrationCadenceWeight()
    root.narrationWordIndex = 0
    root.narrationElapsedMs = 0
    root.narrationWarmupRemainingMs = 0
    root.narrationEstimatedMs = root.estimateNarrationMs(root.narrationWords)
    root.narrationVerseStartedAt = 0
    var voicePrefix = root.usePiper ? "Neural voice · " : "Reading · "
    root.narrationStatus = root.narrationMode === "chapter"
      ? voicePrefix + row.reference + " · " + (root.narrationIndex + 1) + "/" + root.narrationQueue.length
      : voicePrefix + row.reference
    root.ttsProcessGeneration = generation
    if (root.usePiper) {
      if (root.narrationMode === "verse" && root.topSpeechPath !== ""
          && root.topSpeechReference === row.reference && root.topSpeechVerse === row.verse) {
        var topPath = root.topSpeechPath
        var topDuration = root.topSpeechDurationMs
        root.topSpeechPath = ""
        root.topSpeechDurationMs = 0
        root.topSpeechReference = ""
        root.topSpeechVerse = ""
        root.startPiperPlayback(topPath, topDuration, row)
        return
      }
      if (root.prefetchedSpeechPath !== "" && ((root.prefetchedSpeechIndex === root.narrationIndex)
          || (root.prefetchedSpeechReference === row.reference && root.prefetchedSpeechVerse === row.verse))) {
        var readyPath = root.prefetchedSpeechPath
        var readyDuration = root.prefetchedSpeechDurationMs
        root.prefetchedSpeechPath = ""
        root.prefetchedSpeechDurationMs = 0
        root.prefetchedSpeechIndex = -1
        root.prefetchedSpeechReference = ""
        root.prefetchedSpeechVerse = ""
        root.startPiperPlayback(readyPath, readyDuration, row)
        return
      }
      if (speechPrefetchProc.running) speechPrefetchProc.running = false
      root.narrationStatus = "Preparing neural voice · " + row.reference
      speechPrepareProc.command = [root.scriptPath, "prepare-speech", row.verse, String(root.narrationSpeed)]
      speechPrepareProc.running = true
      return
    } else if (root.ttsEngine === "spd-say") {
      ttsProc.command = [root.ttsEngine, "--wait", "--", row.verse]
    } else {
      ttsProc.command = [root.ttsEngine, "--", row.verse]
    }
    root.narrationVerseStartedAt = Date.now()
    ttsProc.running = true
  }

  function skipNarration(delta) {
    if (root.narrationQueue.length < 2 || root.narrationMode === "") return
    var nextIndex = root.narrationIndex + delta
    if (nextIndex < 0 || nextIndex >= root.narrationQueue.length) return

    root.narrationGeneration++
    var generation = root.narrationGeneration
    root.pendingNarrationQueue = root.narrationQueue
    root.pendingNarrationMode = root.narrationMode
    root.pendingNarrationIndex = nextIndex
    root.pendingNarrationGeneration = generation
    root.cleanupPrefetchedSpeech()
    if (ttsProc.running || speechPrepareProc.running) {
      root.narrationStopPending = true
      if (ttsProc.running) {
        root.resumeNarrationProcessBeforeCancel()
        ttsProc.running = false
      }
      if (speechPrepareProc.running) speechPrepareProc.running = false
    } else {
      root.beginNarration(root.narrationQueue, root.narrationMode, generation, nextIndex)
      root.pendingNarrationQueue = []
      root.pendingNarrationMode = ""
      root.pendingNarrationIndex = 0
      root.pendingNarrationGeneration = 0
    }
  }

  function stopNarration() {
    root.narrationGeneration++
    root.narrationCardPinned = false
    root.narrationQueue = []
    root.narrationIndex = 0
    root.narrationMode = ""
    root.chapterRequestGeneration++
    root.pendingNarrationQueue = []
    root.pendingNarrationMode = ""
    root.pendingNarrationIndex = 0
    root.pendingNarrationGeneration = 0
    root.cleanupPrefetchedSpeech()
    root.cleanupPreparedSpeech()
    if (ttsProc.running || speechPrepareProc.running) {
      root.narrationStopPending = true
      if (ttsProc.running) {
        root.resumeNarrationProcessBeforeCancel()
        ttsProc.running = false
      }
      if (speechPrepareProc.running) speechPrepareProc.running = false
    } else {
      root.narrationStopPending = false
    }
    if (chapterProc.running) chapterProc.running = false
    if (root.ttsChecked && !root.ttsAvailable) root.showNarrationUnavailable()
    else if (root.narrationStatus !== "") root.narrationStatus = "Stopped"
    root.scheduleReaderStateSave()
  }

  function copyResult(index) {
    if (index < 0 || index >= resultModel.count) return
    if (copyProc.running) {
      root.copyFeedback = "Copy already in progress"
      root.copyFailed = true
      copyFeedbackTimer.restart()
      return
    }
    var row = resultModel.get(index)
    var text = row.reference + " — " + row.verse
    root.copyReference = row.reference
    root.copyFeedback = "Copying " + row.reference + "…"
    root.copyFailed = false
    copyProc.command = ["wl-copy", "--", text]
    copyProc.running = true
  }

  ListModel { id: resultModel }
  ListModel { id: bookCatalogModel }
  ListModel { id: bookDisplayModel }
  ListModel { id: chapterPickerModel }
  ListModel { id: bookmarkModel }
  ListModel { id: recentModel }

  onReaderBookFilterChanged: root.filterBookCatalog()
  onReaderModeChanged: {
    if (root.readerMode) root.focusReaderKeyboard()
    else {
      root.stopReaderTurnAnimations()
      root.readerDragging = false
      root.readerTurning = false
      root.readerTurnAngle = 0
      root.readerTurnProgress = 0
    }
  }
  onReaderLibraryOpenChanged: if (root.readerMode) root.focusReaderKeyboard()
  onReaderPageIndexChanged: {
    root.scheduleReaderStateSave()
  }
  onReaderSelectedVerseIndexChanged: root.scheduleReaderStateSave()
  onReduceMotionChanged: root.scheduleReaderStateSave()

  Timer {
    id: searchTimer
    interval: 120
    repeat: false
    onTriggered: root.runSearch()
  }

  Timer {
    id: narrationHighlightTimer
    interval: 40
    repeat: true
    running: ttsProc.running && !root.narrationPaused && root.narrationWords.length > 0
    onTriggered: root.advanceNarrationWord()
  }

  Timer {
    id: narrationCompleteTimer
    interval: 1400
    repeat: false
    onTriggered: {
      if (!root.narrationActive && root.narrationMode === "") {
        root.narrationCardPinned = false
        root.narrationQueue = []
      }
    }
  }

  SequentialAnimation {
    id: readerPageTurn
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerTurnAngle"
        to: 0
        duration: root.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: root
        property: "readerTurnProgress"
        to: 0.5
        duration: root.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
    }
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerTurnAngle"
        to: 0
        duration: root.readerTurnSettleDuration
        easing.type: Easing.InOutCubic
      }
      NumberAnimation {
        target: root
        property: "readerTurnProgress"
        to: 1
        duration: root.readerTurnSettleDuration
        easing.type: Easing.InOutCubic
      }
    }
  }

  SequentialAnimation {
    id: readerPageCancel
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerTurnAngle"
        to: 0
        duration: root.readerTurnCancelDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: root
        property: "readerTurnProgress"
        to: 0
        duration: root.readerTurnCancelDuration
        easing.type: Easing.OutCubic
      }
    }
    ScriptAction {
      script: {
        root.readerTurning = false
        root.readerDragWasActive = false
        root.readerTurnCrossesChapter = false
        root.readerTurnAngle = 0
        root.readerTurnProgress = 0
      }
    }
  }

  SequentialAnimation {
    id: readerFolioPulseAnimation
    NumberAnimation {
      target: root
      property: "readerFolioPulse"
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: root
      property: "readerFolioPulse"
      to: 0
      duration: 260
      easing.type: Easing.InOutCubic
    }
  }

  Component.onCompleted: {
    root.detectTts()
    catalogProc.running = true
    stateInitProc.running = true
  }

  FileView {
    id: stateFile
    path: root.readerStatePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadReaderState(text())
    onLoadFailed: root.loadReaderState("{}")
    onFileChanged: reload()
  }

  Timer {
    id: readerStateSaveTimer
    interval: 180
    repeat: false
    onTriggered: root.saveReaderState()
  }

  Timer {
    id: readerActionFeedbackTimer
    interval: 1800
    repeat: false
    onTriggered: root.readerActionFeedback = ""
  }

  Timer {
    id: copyFeedbackTimer
    interval: 2200
    repeat: false
    onTriggered: {
      root.copyFeedback = ""
      root.copyFailed = false
    }
  }

  Timer {
    id: readerPageSwapTimer
    interval: root.readerTurnApproachDuration
    repeat: false
    onTriggered: {
      if (!root.readerTurning) return
      root.readerPageIndex = root.readerTurnTargetPage
      root.readerTurnAngle = root.readerTurnDirection > 0 ? 86 : -86
    }
  }

  Timer {
    id: readerPageResetTimer
    interval: root.readerTurnApproachDuration + root.readerTurnSettleDuration
    repeat: false
    onTriggered: {
      root.readerTurning = false
      root.readerDragging = false
      root.readerDragWasActive = false
      root.readerTurnAngle = 0
      root.readerTurnProgress = 0
      root.readerTurnApproachDuration = 340
      root.readerTurnSettleDuration = 420
    }
  }

  Process {
    id: dailyProc
    command: [root.scriptPath, "daily"]
    running: false
    stdout: StdioCollector { id: dailyOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.statusText = "Could not choose today’s verse"
        return
      }
      root.parseDailyOutput(dailyOutput.text)
    }
  }

  Process {
    id: catalogProc
    command: [root.scriptPath, "catalog"]
    running: false
    stdout: StdioCollector { id: catalogOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseCatalogOutput(catalogOutput.text)
    }
  }

  Process {
    id: stateInitProc
    command: [root.scriptPath, "state-init"]
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) stateFile.reload()
      else root.loadReaderState("{}")
    }
  }

  Process {
    id: searchProc
    running: false
    stdout: StdioCollector {
      id: searchOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.searchStopPending) {
        root.searchStopPending = false
        var nextQuery = root.pendingSearchQuery
        var nextGeneration = root.pendingSearchGeneration
        root.pendingSearchQuery = ""
        root.pendingSearchGeneration = 0
        if (root.opened && nextQuery.trim() !== "") {
          Qt.callLater(function() { root.startSearch(nextQuery, nextGeneration) })
        }
        return
      }

      if (!root.opened
          || root.activeSearchGeneration !== root.searchGeneration
          || root.activeSearchQuery !== root.query) return

      if (exitCode !== 0) {
        resultModel.clear()
        root.statusText = "Search failed"
        return
      }
      root.parseSearchOutput(searchOutput.text)
    }
  }

  Process {
    id: voiceStatusProc
    command: [root.scriptPath, "voice-status"]
    running: false
    stdout: StdioCollector { id: voiceStatusOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.piperReady = exitCode === 0 && String(voiceStatusOutput.text).indexOf("VOICE\tpiper") >= 0
      if (root.piperReady) {
        root.ttsChecked = true
        if (root.narrationStatus.indexOf("No local voice") === 0) root.narrationStatus = "Neural voice ready"
        root.preloadTopSpeech()
      }
    }
  }

  Process {
    id: ttsDetectProc
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.ttsEngine = String(root.ttsCandidates[root.ttsCandidateIndex])
        root.ttsChecked = true
        return
      }
      if (root.ttsCandidateIndex + 1 < root.ttsCandidates.length) {
        root.ttsCandidateIndex++
        Qt.callLater(function() {
          ttsDetectProc.command = [root.ttsCandidates[root.ttsCandidateIndex], "--version"]
          ttsDetectProc.running = true
        })
      } else {
        root.ttsChecked = true
        root.showNarrationUnavailable()
      }
    }
  }

  Process {
    id: chapterProc
    running: false
    stdout: StdioCollector {
      id: chapterOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.activeChapterRequest !== root.chapterRequestGeneration) return
      if (exitCode !== 0) {
        root.readerLoading = false
        root.narrationStatus = "Could not load that chapter"
        root.narrationMode = ""
        return
      }
      var queue = root.queueFromOutput(chapterOutput.text)
      if (queue.length === 0) {
        root.readerLoading = false
        root.narrationStatus = "No verses found in that chapter"
        root.narrationMode = ""
        return
      }
      var chapterLabel = root.readerChapterLabel
      root.setReaderChapter(queue, chapterLabel)
      var focusIndex = root.readerRestoreVerse
      if (focusIndex < 0 && root.readerPendingReference !== "") {
        for (var i = 0; i < queue.length; i++) {
          if (queue[i].reference === root.readerPendingReference) { focusIndex = i; break }
        }
      }
      root.readerSelectedVerseIndex = Math.max(0, Math.min(focusIndex < 0 ? 0 : focusIndex, queue.length - 1))
      var focusPage = root.readerPageForVerse(root.readerSelectedVerseIndex)
      if (root.readerRestorePage >= 0) focusPage = Math.min(root.readerRestorePage, root.readerPages.length - 1)
      root.readerPageIndex = Math.max(0, focusPage)
      root.readerPendingReference = ""
      root.readerRestorePage = -1
      root.readerRestoreVerse = -1
      root.readerLoading = false
      if (root.chapterLoadPurpose === "reader") {
        root.chapterLoadPurpose = ""
        root.narrationMode = ""
        root.narrationQueue = []
        root.narrationStatus = queue.length + " verses · " + root.readerPages.length + " pages"
        root.recordRecent()
      } else {
        root.chapterLoadPurpose = ""
        root.requestNarration(queue, "chapter")
      }
    }
  }

  Process {
    id: topSpeechProc
    running: false
    stdout: StdioCollector { id: topSpeechOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var parts = String(topSpeechOutput.text).trim().split("\t")
      var validAudio = exitCode === 0 && parts.length === 3 && parts[0] === "AUDIO"
      var current = resultModel.count > 0 ? resultModel.get(0) : null
      if (!current || current.reference !== root.topSpeechReference || current.verse !== root.topSpeechVerse) {
        if (validAudio) Quickshell.execDetached([root.scriptPath, "speech-cleanup", parts[1]])
        root.topSpeechReference = ""
        root.topSpeechVerse = ""
        Qt.callLater(function() { root.preloadTopSpeech() })
        return
      }
      if (!validAudio) return
      root.topSpeechPath = parts[1]
      root.topSpeechDurationMs = Math.max(700, Number(parts[2]) || 700)
    }
  }

  Process {
    id: speechPrepareProc
    running: false
    stdout: StdioCollector { id: speechPrepareOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.narrationStopPending) {
        root.continuePendingNarration()
        return
      }
      if (root.ttsProcessGeneration !== root.narrationGeneration) return
      if (exitCode !== 0) {
        root.narrationStatus = "Neural voice preparation failed"
        root.narrationMode = ""
        return
      }
      var parts = String(speechPrepareOutput.text).trim().split("\t")
      if (parts.length !== 3 || parts[0] !== "AUDIO") {
        root.narrationStatus = "Neural voice returned invalid audio"
        root.narrationMode = ""
        return
      }
      var row = root.narrationQueue[root.narrationIndex]
      root.startPiperPlayback(parts[1], parts[2], row)
    }
  }

  Process {
    id: speechPrefetchProc
    running: false
    stdout: StdioCollector { id: speechPrefetchOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0
          || root.prefetchRequestGeneration !== root.narrationGeneration
          || root.prefetchRequestIndex === -1) {
        root.prefetchRequestIndex = -1
        root.prefetchRequestGeneration = 0
        return
      }
      var parts = String(speechPrefetchOutput.text).trim().split("\t")
      if (parts.length !== 3 || parts[0] !== "AUDIO") {
        root.prefetchRequestIndex = -1
        root.prefetchRequestGeneration = 0
        return
      }
      root.prefetchedSpeechPath = parts[1]
      root.prefetchedSpeechDurationMs = Math.max(700, Number(parts[2]) || 700)
      root.prefetchedSpeechIndex = root.prefetchRequestIndex
      root.prefetchRequestIndex = -1
      root.prefetchRequestGeneration = 0
    }
  }

  Process {
    id: ttsProc
    running: false
    onExited: function(exitCode) {
      root.narrationPaused = false
      root.cleanupPreparedSpeech()
      if (root.narrationStopPending) {
        root.continuePendingNarration()
        return
      }
      if (root.ttsProcessGeneration !== root.narrationGeneration) return
      if (exitCode !== 0) {
        root.narrationStatus = "Voice engine failed"
        root.narrationMode = ""
        return
      }
      root.calibrateNarrationTiming()
      root.narrationIndex++
      if (root.narrationIndex >= root.narrationQueue.length) narrationCompleteTimer.restart()
      Qt.callLater(function() { root.speakNext(root.narrationGeneration) })
    }
  }

  Process {
    id: copyProc
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.copyFeedback = "Copied " + root.copyReference
        root.copyFailed = false
      } else {
        root.copyFeedback = "Could not copy · is wl-copy available?"
        root.copyFailed = true
      }
      copyFeedbackTimer.restart()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(500))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus || readerBookFilterField.activeFocus
      onCloseRequested: {
        if (root.readerLibraryOpen) root.readerLibraryOpen = false
        else root.close()
      }
      onMoveRequested: function(dx, dy) {
        if (root.readerMode && root.readerLibraryOpen) {
          root.moveLibraryCursor(dx, dy)
        } else if (root.readerMode) {
          if (dx !== 0) root.moveReaderPage(dx > 0 ? 1 : -1)
          else if (dy !== 0) root.moveReaderPage(dy > 0 ? 1 : -1)
        } else if (dy !== 0) {
          root.moveSelection(dy)
        }
      }
      onActivateRequested: {
        if (root.readerMode && root.readerLibraryOpen) root.activateLibraryCursor()
        else if (root.readerMode) root.readReaderSelectedVerse()
        else root.activateSelected()
      }
      onTabRequested: function(direction) {
        if (root.readerMode && root.readerLibraryOpen) root.cycleLibraryTab(direction)
      }
      onDeleteRequested: {
        if (root.readerMode && root.readerLibraryOpen && root.readerLibraryTab === "saved") {
          root.removeBookmarkAt(root.readerListCursor)
        }
      }
      onTextKey: function(text) {
        if (!root.readerMode) {
          if ((text === "o" || text === "O") && resultModel.count > 0) root.openReader(root.selectedIndex)
          else if (text === "r" || text === "R") root.readVerse(root.selectedIndex)
          else if (text === " ") root.toggleNarrationPause()
          return
        }
        if (text === "b" || text === "B") root.readerLibraryOpen = !root.readerLibraryOpen
        else if (text === "/" && root.readerLibraryOpen && root.readerLibraryTab === "books") readerBookFilterField.forceActiveFocus()
        else if ((text === "n" || text === "N") && !root.readerLibraryOpen) root.moveReaderPage(1)
        else if ((text === "p" || text === "P") && !root.readerLibraryOpen) root.moveReaderPage(-1)
        else if ((text === "s" || text === "S") && !root.readerLibraryOpen) root.toggleCurrentBookmark()
        else if ((text === "r" || text === "R") && root.readerSavedPosition) root.openStoredReader(root.readerSavedPosition)
      }

      // PanelKeyCatcher owns the standard arrows and Vim directions. These
      // explicit page keys fill the gaps without changing the shared shell
      // component, and the focus guard keeps them local to Book View.
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (keyCatcher.blocked || !root.readerMode || root.readerLibraryOpen) return
        if (event.key === Qt.Key_PageDown) {
          root.moveReaderPage(1)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.moveReaderPage(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Home) {
          root.turnReaderPage(0)
          root.focusReaderKeyboard()
          event.accepted = true
        } else if (event.key === Qt.Key_End) {
          root.turnReaderPage(root.readerPages.length - 1)
          root.focusReaderKeyboard()
          event.accepted = true
        } else if (event.key === Qt.Key_N && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
          root.moveReaderPage(1)
          event.accepted = true
        } else if (event.key === Qt.Key_P && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
          root.moveReaderPage(-1)
          event.accepted = true
        }
      }

      ScrollView {
        id: panelScroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: panelScroll.contentItem
          property: "interactive"
          value: content.implicitHeight > panelScroll.height
        }

        Column {
          id: content
          width: panelScroll.availableWidth
          spacing: Style.spacing.md

        Item {
          id: header
          width: parent.width
          height: Math.max(Style.space(36), headerTitle.implicitHeight + headerSubtitle.implicitHeight + Style.space(4))

          BorderSurface {
            id: iconBadge
            width: Style.space(36)
            height: Style.space(36)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Style.hoverFillFor(root.popupForeground, Color.accent)
            borderSpec: Border.flat(Color.accent, 1)
            radius: Style.cornerRadius

            Text {
              anchors.centerIn: parent
              text: "󰂿"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }
          }

          Column {
            anchors.left: iconBadge.right
            anchors.leftMargin: Style.spacing.sm
            anchors.right: headerActions.left
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: headerTitle
              text: "Bible Search"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: headerSubtitle
              text: "Search by word, phrase, or reference"
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.62
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            PanelActionButton {
              id: settingsButton
              iconText: "󰒓"
              tooltipText: "Reading settings"
              foreground: root.popupForeground
              hoverColor: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              focusable: true
              hasCursor: root.settingsOpen
              onClicked: root.settingsOpen = !root.settingsOpen
            }

            Text {
              id: closeHint
              text: "ESC"
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.62
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        BorderSurface {
          id: settingsPanel
          width: parent.width
          visible: !root.readerMode && root.settingsOpen
          height: visible ? settingsColumn.implicitHeight + Style.spacing.md * 2 : 0
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.popupForeground, Color.accent)
          borderSpec: Border.flat(Color.popups.border, 1)

          Column {
            id: settingsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.sm

            Text {
              text: "READING SETTINGS"
              color: root.popupForeground
              opacity: 0.7
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }

            Row {
              spacing: Style.spacing.sm
              Text { text: "Voice"; width: Style.space(90); color: root.popupForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              Repeater {
                model: [{ label: "Male neural", value: "male" }, { label: "System", value: "system" }]
                delegate: PanelActionButton {
                  required property var modelData
                  size: modelData.value === "male" ? Style.space(92) : Style.space(66)
                  implicitHeight: Style.space(26); height: implicitHeight
                  iconText: modelData.label
                  foreground: root.preferredVoice === modelData.value ? Color.accent : root.popupForeground
                  hoverColor: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.caption
                  bordered: true
                  onClicked: {
                    root.preferredVoice = modelData.value
                    root.cleanupTopSpeech(); root.preloadTopSpeech(); root.scheduleReaderStateSave()
                  }
                }
              }
            }

            Row {
              spacing: Style.spacing.sm
              Text { text: "Speed"; width: Style.space(90); color: root.popupForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              Repeater {
                model: [0.85, 1, 1.15]
                delegate: PanelActionButton {
                  required property real modelData
                  size: Style.space(54); implicitHeight: Style.space(26); height: implicitHeight
                  iconText: modelData + "×"
                  foreground: root.narrationSpeed === modelData ? Color.accent : root.popupForeground
                  hoverColor: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.caption
                  bordered: true
                  onClicked: root.setNarrationSpeed(modelData)
                }
              }
            }

            Row {
              spacing: Style.spacing.sm
              PanelActionButton {
                size: Style.space(146); implicitHeight: Style.space(26); height: implicitHeight
                iconText: root.dailyOnOpen ? "Daily on open · On" : "Daily on open · Off"
                foreground: root.dailyOnOpen ? Color.accent : root.popupForeground
                hoverColor: Color.accent; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                fontSize: Style.font.caption; bordered: true
                onClicked: { root.dailyOnOpen = !root.dailyOnOpen; root.scheduleReaderStateSave() }
              }
              PanelActionButton {
                size: Style.space(142); implicitHeight: Style.space(26); height: implicitHeight
                iconText: root.reduceMotion ? "Reduced motion · On" : "Reduced motion · Off"
                foreground: root.reduceMotion ? Color.accent : root.popupForeground
                hoverColor: Color.accent; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                fontSize: Style.font.caption; bordered: true
                onClicked: { root.reduceMotion = !root.reduceMotion; root.scheduleReaderStateSave() }
              }
            }
          }
        }

        Item {
          id: readerView
          width: parent.width
          visible: root.readerMode
          height: visible ? readerColumn.implicitHeight : 0

          Column {
            id: readerColumn
            width: parent.width
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Rectangle {
                id: readerSearchButton
                width: Style.space(72)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: readerSearchMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerSearchLabel
                  anchors.centerIn: parent
                  text: "Search"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerSearchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.showSearch()
                }
              }

              Rectangle {
                id: readerLibraryButton
                width: Style.space(72)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.readerLibraryOpen || readerLibraryMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: root.readerLibraryOpen ? Color.accent : Color.popups.border

                Text {
                  id: readerLibraryLabel
                  anchors.centerIn: parent
                  text: "Library"
                  textFormat: Text.PlainText
                  color: root.readerLibraryOpen ? Color.accent : root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerLibraryMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.readerLibraryOpen = !root.readerLibraryOpen
                    root.focusReaderKeyboard()
                  }
                }
              }

              Item {
                width: Math.max(0, parent.width - readerPageCount.implicitWidth - readerSearchButton.width - readerLibraryButton.width - parent.spacing * 2)
                height: 1
              }

              Text {
                id: readerPageCount
                text: root.readerHasPages ? (root.readerPageIndex + 1) + " / " + root.readerPages.length : ""
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.58
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            BorderSurface {
              id: readerLibrary
              width: parent.width
              height: root.readerLibraryOpen ? Style.space(350) : 0
              visible: root.readerLibraryOpen
              radius: Style.cornerRadius
              color: Color.popups.background
              borderSpec: Border.flat(Color.popups.border, 1)
              clip: true

              Column {
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                spacing: Style.spacing.xs

                Row {
                  width: parent.width
                  spacing: Style.spacing.xs

                  Repeater {
                    model: [
                      { key: "books", label: "BOOKS" },
                      { key: "saved", label: "SAVED" },
                      { key: "recent", label: "RECENT" }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      width: libraryTabLabel.implicitWidth + Style.space(18)
                      height: Style.space(26)
                      radius: Style.cornerRadius
                      color: root.readerLibraryTab === modelData.key
                        ? Style.focusFillFor(root.popupForeground, Color.accent) : "transparent"
                      border.width: 1
                      border.color: root.readerLibraryTab === modelData.key ? Color.accent : Color.popups.border
                      Text {
                        id: libraryTabLabel
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: root.readerLibraryTab === parent.modelData.key ? Color.accent : root.popupForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: root.readerLibraryTab === parent.modelData.key
                      }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setLibraryTab(parent.modelData.key)
                      }
                    }
                  }

                  Item { width: Math.max(0, parent.width - Style.space(270)); height: 1 }

                  Rectangle {
                    visible: root.readerSavedPosition !== null
                    width: visible ? resumeLabel.implicitWidth + Style.space(18) : 0
                    height: Style.space(26)
                    radius: Style.cornerRadius
                    color: resumeMouse.containsMouse ? Style.hoverFillFor(root.popupForeground, Color.accent) : "transparent"
                    border.width: 1
                    border.color: Color.accent
                    Text {
                      id: resumeLabel
                      anchors.centerIn: parent
                      text: "RESUME"
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    MouseArea {
                      id: resumeMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.openStoredReader(root.readerSavedPosition)
                    }
                    PanelToolTip {
                      visible: resumeMouse.containsMouse
                      text: root.readerSavedPosition ? "Continue at " + root.readerSavedPosition.reference : "Continue reading"
                      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    }
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(256)

                  Item {
                    anchors.fill: parent
                    visible: root.readerLibraryTab === "books"

                    TextField {
                      id: readerBookFilterField
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      height: implicitHeight
                      placeholderText: "Find a book…"
                      text: root.readerBookFilter
                      onTextChanged: root.readerBookFilter = text
                      Keys.onEscapePressed: {
                        if (text !== "") {
                          text = ""
                        } else {
                          focus = false
                          keyCatcher.forceActiveFocus()
                        }
                      }
                    }

                    ListView {
                      id: readerBookList
                      anchors.left: parent.left
                      anchors.top: readerBookFilterField.bottom
                      anchors.topMargin: Style.spacing.xs
                      anchors.bottom: parent.bottom
                      width: Style.space(190)
                      clip: true
                      model: bookDisplayModel
                      spacing: Style.space(2)
                      delegate: CursorSurface {
                        required property string bookName
                        required property int chapterCount
                        required property int index
                        width: readerBookList.width
                        height: Style.space(28)
                        hasCursor: root.readerLibraryFocus === "books" && root.readerBookCursor === index
                        current: root.readerCatalogBook === bookName
                        foreground: root.popupForeground
                        accent: Color.accent
                        Text {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.spacing.sm
                          anchors.verticalCenter: parent.verticalCenter
                          text: bookName
                          color: root.readerLibraryFocus === "books" && root.readerBookCursor === index ? Color.accent : root.popupForeground
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.bodySmall
                        }
                        MouseArea {
                          id: bookMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.readerBookCursor = index
                            root.readerLibraryFocus = "books"
                            root.selectCatalogBook(bookName, chapterCount)
                          }
                        }
                        HoverHandler {
                          onHoveredChanged: if (hovered) {
                            root.readerBookCursor = index
                            root.readerLibraryFocus = "books"
                          }
                        }
                      }
                    }

                    Column {
                      anchors.left: readerBookList.right
                      anchors.leftMargin: Style.spacing.sm
                      anchors.right: parent.right
                      anchors.top: readerBookFilterField.bottom
                      anchors.topMargin: Style.spacing.xs
                      anchors.bottom: parent.bottom
                      spacing: Style.spacing.xs
                      Text {
                        text: root.readerCatalogBook + "  ·  " + root.readerCatalogChapterCount + " chapters"
                        color: root.popupForeground
                        opacity: 0.64
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                      GridView {
                        id: readerChapterGrid
                        width: parent.width
                        height: parent.height - Style.space(24)
                        clip: true
                        model: chapterPickerModel
                        cellWidth: Style.space(44)
                        cellHeight: Style.space(36)
                        delegate: CursorSurface {
                          required property int chapterNumber
                          required property int index
                          width: Style.space(36)
                          height: Style.space(30)
                          hasCursor: root.readerLibraryFocus === "chapters" && root.readerChapterCursor === index
                          foreground: root.popupForeground
                          accent: Color.accent
                          bordered: true
                          Text {
                            anchors.centerIn: parent
                            text: chapterNumber
                            color: parent.hasCursor ? Color.accent : root.popupForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.bodySmall
                          }
                          MouseArea {
                            id: chapterMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.readerChapterCursor = index
                              root.readerLibraryFocus = "chapters"
                              root.openReaderChapter(root.readerCatalogBook, chapterNumber, "", -1, -1)
                            }
                          }
                          HoverHandler {
                            onHoveredChanged: if (hovered) {
                              root.readerChapterCursor = index
                              root.readerLibraryFocus = "chapters"
                            }
                          }
                        }
                      }
                    }

                    Column {
                      x: 0
                      y: readerBookFilterField.y + readerBookFilterField.height
                      width: parent.width
                      height: Math.max(0, parent.height - y)
                      visible: bookDisplayModel.count === 0 && root.readerBookFilter.trim() !== ""
                      spacing: Style.spacing.xs
                      Item {
                        width: 1
                        height: Style.space(72)
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No books match “" + root.readerBookFilter + "”"
                        textFormat: Text.PlainText
                        color: root.popupForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press Escape to clear the filter."
                        textFormat: Text.PlainText
                        color: root.popupForeground
                        opacity: 0.5
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  ListView {
                    id: readerStoredList
                    anchors.fill: parent
                    visible: root.readerLibraryTab === "saved" || root.readerLibraryTab === "recent"
                    clip: true
                    spacing: Style.spacing.xs
                    model: root.readerLibraryTab === "saved" ? bookmarkModel : recentModel
                    delegate: CursorSurface {
                      required property string reference
                      required property string chapterLabel
                      required property int pageIndex
                      required property int verseIndex
                      required property int index
                      width: ListView.view.width
                      height: Style.space(48)
                      hasCursor: root.readerLibraryFocus === "list" && root.readerListCursor === index
                      foreground: root.popupForeground
                      accent: Color.accent
                      bordered: true
                      Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.spacing.sm
                        anchors.right: savedDeleteButton.left
                        anchors.rightMargin: Style.spacing.xs
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                          text: reference
                          color: root.popupForeground
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.bodySmall
                          font.bold: true
                        }
                        Text {
                          text: chapterLabel + "  ·  page " + (pageIndex + 1)
                          color: root.popupForeground
                          opacity: 0.48
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                        }
                      }
                      MouseArea {
                        id: savedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.readerListCursor = index
                          root.readerLibraryFocus = "list"
                          root.openStoredReader({ reference: reference, chapterLabel: chapterLabel, pageIndex: pageIndex, verseIndex: verseIndex })
                        }
                      }
                      HoverHandler {
                        onHoveredChanged: if (hovered) {
                          root.readerListCursor = index
                          root.readerLibraryFocus = "list"
                        }
                      }
                      PanelActionButton {
                        id: savedDeleteButton
                        anchors.right: parent.right
                        anchors.rightMargin: Style.spacing.xs
                        anchors.verticalCenter: parent.verticalCenter
                        z: 3
                        visible: root.readerLibraryTab === "saved"
                        enabled: visible
                        iconText: "󰆴"
                        tooltipText: "Remove from Saved"
                        foreground: root.popupForeground
                        hoverColor: Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onClicked: root.removeBookmarkAt(index)
                      }
                    }
                  }

                  Column {
                    anchors.centerIn: parent
                    visible: root.readerLibraryTab === "saved" ? bookmarkModel.count === 0
                      : root.readerLibraryTab === "recent" && recentModel.count === 0
                    spacing: Style.spacing.xs
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.readerLibraryTab === "saved" ? "No saved verses yet" : "No recent chapters yet"
                      color: root.popupForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.readerLibraryTab === "saved"
                        ? "Focus a verse and choose Save."
                        : "Open a chapter to begin your history."
                      color: root.popupForeground
                      opacity: 0.5
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.spacing.xs
                  Text {
                    text: root.readerActionFeedback !== ""
                      ? root.readerActionFeedback
                      : root.catalogLoaded
                        ? (root.readerLibraryTab === "saved" ? "↑↓ select  ·  ENTER open  ·  X remove" : "↑↓ select  ·  ENTER open  ·  TAB sections")
                        : "Loading the offline library…"
                    color: root.readerActionFeedback !== "" ? Color.accent : root.popupForeground
                    opacity: root.readerActionFeedback !== "" ? 1 : 0.48
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: root.readerActionFeedback !== ""
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Item { width: Math.max(0, parent.width - Style.space(270)); height: 1 }
                  Text {
                    text: "REDUCED MOTION"
                    color: root.reduceMotion ? Color.accent : root.popupForeground
                    opacity: root.reduceMotion ? 1 : 0.58
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Rectangle {
                    width: Style.space(34)
                    height: Style.space(18)
                    radius: height / 2
                    color: root.reduceMotion ? Color.accent : Style.normalFillFor(root.popupForeground, Color.accent)
                    Rectangle {
                      width: Style.space(14); height: width; radius: width / 2
                      y: Style.space(2)
                      x: root.reduceMotion ? parent.width - width - Style.space(2) : Style.space(2)
                      color: root.reduceMotion ? Color.popups.background : root.popupForeground
                    }
                    MouseArea {
                      id: reducedMotionMouse
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.reduceMotion = !root.reduceMotion
                    }
                    PanelToolTip {
                      visible: reducedMotionMouse.containsMouse
                      text: root.reduceMotion ? "Page turns change immediately" : "Animate page turns"
                      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    }
                  }
                }
              }
            }

            Item {
              id: readerMasthead
              visible: !root.readerLibraryOpen
              width: parent.width
              height: Style.space(36)

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: root.readerChapterLabel
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.heading
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: root.readerLoading
                    ? "Opening chapter…"
                    : root.narrationMode !== ""
                      ? "Reading along"
                      : "Click a verse to focus"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  opacity: 0.52
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Rectangle {
              id: readerPageProgressTrack
              visible: !root.readerLibraryOpen
              width: parent.width
              height: Style.space(2)
              radius: height / 2
              color: Style.normalFillFor(root.popupForeground, Color.accent)

              Rectangle {
                id: readerPageProgress
                width: root.readerHasPages
                  ? parent.width * ((root.readerPageIndex + 1) / root.readerPages.length)
                  : 0
                height: parent.height
                radius: height / 2
                color: Color.accent

                Behavior on width {
                  enabled: !root.reduceMotion
                  NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                }
              }
            }

            BorderSurface {
              id: readerPageSurface
              visible: !root.readerLibraryOpen
              width: parent.width
              height: root.readerLoading
                ? Style.space(230)
                : Math.min(Style.space(410), Math.max(Style.space(260), readerPageColumn.implicitHeight + Style.space(42)))
              radius: Style.cornerRadius
              color: Color.popups.background
              borderSpec: Border.flat(Color.popups.border, 1)
              clip: true

              BorderSurface {
                id: readerPaperInset
                anchors.fill: parent
                anchors.margins: Style.space(5)
                z: 0
                color: Style.normalFillFor(root.popupForeground, Color.accent)
                borderSpec: Border.flat(Style.normalBorderFor(root.popupForeground, Color.accent), 1)
                radius: Style.space(2)
              }

              Rectangle {
                id: readerPageBackdrop
                anchors.fill: parent
                z: 0
                color: Style.hoverFillFor(root.popupForeground, Color.accent)
                opacity: root.readerTurning ? 0.12 : 0
              }

              Rectangle {
                id: readerSpineShadow
                x: root.readerTurnDirection > 0 ? 0 : parent.width - width
                y: 0
                z: 0
                width: Style.space(4)
                height: parent.height
                color: root.popupForeground
                opacity: root.readerTurning ? 0.06 * Math.sin(Math.PI * root.readerTurnProgress) : 0
              }

              Item {
                id: readerIncomingPage
                x: 0
                y: readerPageContent.y
                width: readerPageContent.width
                height: Math.max(readerPageContent.height, incomingPageColumn.implicitHeight)
                z: 1
                visible: root.readerTurning && root.readerTurnPage !== null
                opacity: visible ? Math.min(1, root.readerTurnProgress * 1.4) : 0
                clip: true

                BorderSurface {
                  anchors.fill: parent
                  radius: Style.space(2)
                  color: Style.normalFillFor(root.popupForeground, Color.accent)
                  borderSpec: Border.flat(Style.normalBorderFor(root.popupForeground, Color.accent), 1)
                }

                Column {
                  id: incomingPageColumn
                  x: Style.spacing.xs
                  y: Style.spacing.xs
                  width: parent.width - Style.spacing.xs * 2
                  spacing: Style.spacing.sm

                  Repeater {
                    model: root.readerTurnPage ? root.readerTurnPage.verses : []

                    delegate: Column {
                      required property var modelData
                      width: incomingPageColumn.width
                      spacing: Style.spacing.xs

                      Text {
                        width: parent.width
                        text: modelData.reference
                        textFormat: Text.PlainText
                        color: root.popupForeground
                        opacity: 0.58
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        width: parent.width
                        text: modelData.verse
                        textFormat: Text.PlainText
                        color: root.popupForeground
                        opacity: 0.68
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        wrapMode: Text.WordWrap
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    text: root.readerTurnPage
                      ? root.readerChapterLabel + "  ·  " + (root.readerTurnTargetPage + 1) : ""
                    textFormat: Text.PlainText
                    color: root.popupForeground
                    opacity: 0.46
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }

              Item {
                id: readerPageContent
                y: Style.spacing.md
                width: parent.width - (Style.spacing.md * 2)
                height: readerPageColumn.implicitHeight
                z: 2
                opacity: root.readerTurning ? Math.max(0.2, 1 - root.readerTurnProgress) : 1
                x: root.readerTurning
                  ? (root.readerTurnDirection > 0 ? -1 : 1) * root.readerTurnProgress * Style.space(36)
                  : 0

                Column {
                  id: readerPageColumn
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    width: parent.width
                    visible: root.readerLoading
                    text: "Opening this chapter…"
                    textFormat: Text.PlainText
                    color: root.popupForeground
                    opacity: 0.62
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Repeater {
                    model: root.currentReaderPage ? root.currentReaderPage.verses : []

                    delegate: Item {
                      required property var modelData
                      required property int index
                      readonly property int absoluteIndex: root.currentReaderPage
                        ? root.currentReaderPage.start + index
                        : -1
                      readonly property bool focused: absoluteIndex === root.readerFocusVerseIndex
                      width: readerPageColumn.width
                      height: verseColumn.implicitHeight + Style.space(10)

                      BorderSurface {
                        anchors.fill: parent
                        radius: Style.space(3)
                        color: parent.focused
                          ? Style.focusFillFor(root.popupForeground, Color.accent)
                          : "transparent"
                        borderSpec: parent.focused
                          ? Border.flat(Color.accent, 1)
                          : Border.flat("transparent", 0)
                      }

                      Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.focused ? Style.space(3) : 1
                        color: Color.accent
                        opacity: parent.focused ? 1 : 0.18
                      }

                      Column {
                        id: verseColumn
                        x: Style.spacing.sm
                        y: Style.spacing.xs
                        width: parent.width - (Style.spacing.sm * 2)
                        spacing: Style.spacing.xs

                        Text {
                          width: parent.width
                          text: modelData.reference
                          textFormat: Text.PlainText
                          color: parent.parent.focused ? Color.accent : root.popupForeground
                          opacity: parent.parent.focused ? 1 : 0.58
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: parent.parent.focused
                        }

                        Flow {
                          id: readerWordFlow
                          width: parent.width
                          visible: parent.parent.focused && root.narrationMode !== "" && root.narrationWords.length > 0
                          spacing: Style.spacing.xs
                          height: childrenRect.height

                          Repeater {
                            model: readerWordFlow.visible ? root.narrationWords : []

                            delegate: Rectangle {
                              required property string modelData
                              required property int index
                              width: readerWordLabel.implicitWidth + Style.space(6)
                              height: readerWordLabel.implicitHeight + Style.space(4)
                              radius: Style.space(2)
                              color: index === root.narrationWordIndex ? Color.accent : "transparent"

                              Text {
                                id: readerWordLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                textFormat: Text.PlainText
                                color: index === root.narrationWordIndex ? Color.popups.background : root.popupForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: index === root.narrationWordIndex
                              }
                            }
                          }
                        }

                        Text {
                          width: parent.width
                          visible: !readerWordFlow.visible
                          text: modelData.verse
                          textFormat: Text.PlainText
                          color: root.popupForeground
                          opacity: parent.parent.focused ? 1 : 0.68
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.body
                          wrapMode: Text.WordWrap
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        z: 2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.readerSelectedVerseIndex = absoluteIndex
                        }
                      }

                    }
                  }

                  Item {
                    width: parent.width
                    visible: root.readerHasPages
                    height: Style.space(18)

                    Rectangle {
                      anchors.left: parent.left
                      anchors.right: readerPageFooter.left
                      anchors.rightMargin: Style.spacing.xs
                      anchors.verticalCenter: parent.verticalCenter
                      height: 1
                      color: Color.popups.border
                      opacity: 0.34
                    }

                    Text {
                      id: readerPageFooter
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.readerChapterLabel + "  ·  " + (root.readerPageIndex + 1)
                      textFormat: Text.PlainText
                      color: root.popupForeground
                      opacity: 0.46
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }

              Shape {
                id: readerBackCornerFold
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Style.space(22)
                height: Style.space(22)
                z: 3
                visible: root.canMoveReader(-1)
                opacity: readerBackCornerMouse.containsMouse || (root.readerDragging && root.readerTurnDirection < 0) ? 1 : 0.35
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                  fillColor: Style.normalFillFor(root.popupForeground, Color.accent)
                  strokeColor: Color.popups.border
                  strokeWidth: 1
                  startX: 0
                  startY: 0
                  PathLine { x: 0; y: readerBackCornerFold.height }
                  PathLine { x: readerBackCornerFold.width; y: readerBackCornerFold.height }
                  PathLine { x: 0; y: 0 }
                }

                Text {
                  anchors.left: parent.left
                  anchors.bottom: parent.bottom
                  anchors.leftMargin: Style.space(4)
                  anchors.bottomMargin: Style.space(2)
                  text: "‹"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  opacity: 0.7
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerBackCornerMouse
                  anchors.fill: parent
                  enabled: root.canMoveReader(-1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { root.beginReaderCornerDrag(-1, mouse.x) }
                  onPositionChanged: function(mouse) { root.updateReaderCornerDrag(mouse.x) }
                  onReleased: root.finishReaderCornerDrag()
                  onClicked: {
                    if (!root.readerDragWasActive) root.moveReaderPage(-1)
                  }
                }

                PanelToolTip {
                  visible: readerBackCornerMouse.containsMouse && !root.readerDragging
                  text: "Drag to turn to the previous page"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }

              Shape {
                id: readerCornerFold
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Style.space(22)
                height: Style.space(22)
                z: 3
                visible: root.canMoveReader(1)
                opacity: readerCornerMouse.containsMouse || (root.readerDragging && root.readerTurnDirection > 0) ? 1 : 0.35
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                  fillColor: Style.normalFillFor(root.popupForeground, Color.accent)
                  strokeColor: Color.popups.border
                  strokeWidth: 1
                  startX: readerCornerFold.width
                  startY: 0
                  PathLine { x: readerCornerFold.width; y: readerCornerFold.height }
                  PathLine { x: 0; y: readerCornerFold.height }
                  PathLine { x: readerCornerFold.width; y: 0 }
                }

                Text {
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.rightMargin: Style.space(4)
                  anchors.bottomMargin: Style.space(2)
                  text: "›"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  opacity: 0.7
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerCornerMouse
                  anchors.fill: parent
                  enabled: root.canMoveReader(1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { root.beginReaderCornerDrag(1, mouse.x) }
                  onPositionChanged: function(mouse) { root.updateReaderCornerDrag(mouse.x) }
                  onReleased: root.finishReaderCornerDrag()
                  onClicked: {
                    if (!root.readerDragWasActive) root.moveReaderPage(1)
                  }
                }

                PanelToolTip {
                  visible: readerCornerMouse.containsMouse && !root.readerDragging
                  text: "Drag to turn to the next page"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }
            }

            Row {
              id: readerNavRow
              visible: !root.readerLibraryOpen
              width: parent.width
              spacing: Style.spacing.xs
              readonly property int actionCount: 5 + (root.narrationActive ? 1 : 0)
              readonly property real actionWidth: (width - spacing * (actionCount - 1)) / actionCount

              Rectangle {
                id: readerPreviousButton
                enabled: root.canMoveReader(-1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: readerPreviousMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerPreviousLabel
                  anchors.centerIn: parent
                  text: "Prev"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerPreviousMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.moveReaderPage(-1)
                }
              }

              Rectangle {
                id: readerNextButton
                enabled: root.canMoveReader(1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: readerNextMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerNextLabel
                  anchors.centerIn: parent
                  text: "Next"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerNextMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.moveReaderPage(1)
                }
              }

              Rectangle {
                id: readerReadVerseButton
                enabled: root.readerHasPages
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: readerReadVerseMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerReadVerseLabel
                  anchors.centerIn: parent
                  text: "Read"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerReadVerseMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.readReaderSelectedVerse()
                }
              }

              Rectangle {
                id: readerReadChapterButton
                enabled: root.readerHasPages
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: readerReadChapterMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerReadChapterLabel
                  anchors.centerIn: parent
                  text: root.readerSelectedVerseIndex > 0 ? "From here" : "Chapter"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerReadChapterMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.readReaderChapter()
                }
              }

              Rectangle {
                id: readerBookmarkButton
                enabled: root.readerHasPages
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: readerBookmarkMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent) : "transparent"
                border.width: 1
                border.color: root.currentReaderBookmarkIndex() >= 0 ? Color.accent : Color.popups.border
                Text {
                  id: readerBookmarkLabel
                  anchors.centerIn: parent
                  text: root.currentReaderBookmarkIndex() >= 0 ? "Saved" : "Save"
                  color: root.currentReaderBookmarkIndex() >= 0 ? Color.accent : root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: readerBookmarkMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleCurrentBookmark()
                }
                PanelToolTip {
                  visible: readerBookmarkMouse.containsMouse
                  text: root.currentReaderBookmarkIndex() >= 0 ? "Remove focused verse from Saved" : "Save focused verse"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }

              Rectangle {
                id: readerStopButton
                visible: root.narrationActive
                width: visible ? readerNavRow.actionWidth : 0
                height: Style.space(28)
                radius: Style.cornerRadius
                color: readerStopMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: readerStopLabel
                  anchors.centerIn: parent
                  text: "Stop"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerStopMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.stopNarration()
                }
              }
            }

            Text {
              visible: !root.readerLibraryOpen
              width: parent.width
              text: root.narrationMode !== ""
                ? "← → turn into the next chapter  ·  Space pause"
                : "← → continues into the next chapter  ·  Enter read  ·  S save"
              textFormat: Text.PlainText
              id: readerKeyboardHint
              color: root.popupForeground
              opacity: 0.44
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.readerLibraryOpen
              width: parent.width
              text: "↑↓ select · Enter open · Tab switches sections · B closes Library"
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.44
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              visible: !root.readerLibraryOpen && root.readerActionFeedback !== ""
              width: parent.width
              text: root.readerActionFeedback
              textFormat: Text.PlainText
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        BorderSurface {
          id: voiceSetupCard
          width: parent.width
          visible: root.ttsChecked && !root.ttsAvailable
          height: visible ? voiceSetupRow.implicitHeight + Style.spacing.sm * 2 : 0
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.popupForeground, Color.accent)
          borderSpec: Border.flat(Color.popups.border, 1)

          Row {
            id: voiceSetupRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.xs

            Column {
              width: Math.max(0, parent.width - voiceInstallButton.width - voiceCheckButton.width - parent.spacing * 2)
              spacing: Style.space(2)
              Text {
                width: parent.width
                text: "Reading aloud needs a local voice"
                textFormat: Text.PlainText
                color: root.popupForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                width: parent.width
                text: "Install espeak-ng once; Bible text and speech remain offline."
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.52
                elide: Text.ElideRight
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: voiceInstallButton
              width: voiceInstallLabel.implicitWidth + Style.space(18)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: voiceInstallMouse.containsMouse ? Style.hoverFillFor(root.popupForeground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.accent
              Text {
                id: voiceInstallLabel
                anchors.centerIn: parent
                text: "INSTALL"
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              MouseArea {
                id: voiceInstallMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.installVoiceEngine()
              }
              PanelToolTip {
                visible: voiceInstallMouse.containsMouse
                text: "Open Omarchy’s package installer in a terminal"
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              }
            }

            Rectangle {
              id: voiceCheckButton
              width: voiceCheckLabel.implicitWidth + Style.space(18)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: voiceCheckMouse.containsMouse ? Style.hoverFillFor(root.popupForeground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.popups.border
              Text {
                id: voiceCheckLabel
                anchors.centerIn: parent
                text: "CHECK AGAIN"
                color: root.popupForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                id: voiceCheckMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detectTts()
              }
            }
          }
        }

        TextField {
          id: searchField
          width: parent.width
          visible: !root.readerMode
          height: visible ? implicitHeight : 0
          placeholderText: "Word, phrase, or John 3:16"
          foreground: root.popupForeground
          accent: Color.accent
          rightPadding: Style.space(56)
          text: root.query
          onTextChanged: {
            if (root.query !== text) root.query = text
            if (text.trim() !== "") root.dailyView = false
            root.scheduleSearch()
          }
          onAccepted: {
            searchField.focus = false
            keyCatcher.forceActiveFocus()
          }
          Keys.onEscapePressed: {
            searchField.focus = false
            keyCatcher.forceActiveFocus()
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "ENTER"
            textFormat: Text.PlainText
            color: root.popupForeground
            opacity: 0.48
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 0.8
          }
        }

        Flow {
          id: quickSearches
          width: parent.width
          visible: !root.readerMode && root.query.trim() === "" && !root.dailyView
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.xs

          Rectangle {
            id: dailySuggestion
            width: dailyChipLabel.implicitWidth + Style.space(20)
            height: Style.space(28)
            radius: height / 2
            color: dailyChipMouse.containsMouse
              ? Style.hoverFillFor(root.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.accent
            opacity: dailyProc.running ? 0.6 : 1

            Text {
              id: dailyChipLabel
              anchors.centerIn: parent
              text: dailyProc.running ? "…" : "Daily"
              textFormat: Text.PlainText
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: dailyChipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !dailyProc.running
              onClicked: root.showDailyVerse()
            }
          }

          Repeater {
            model: root.topicSuggestions

            delegate: Rectangle {
              required property string modelData
              width: chipLabel.implicitWidth + Style.space(20)
              height: Style.space(28)
              radius: height / 2
              color: chipMouse.containsMouse
                ? Style.hoverFillFor(root.popupForeground, Color.accent)
                : "transparent"
              border.width: 1
              border.color: Color.popups.border

              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.8
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  searchField.text = parent.modelData
                  searchField.forceActiveFocus()
                }
              }
            }
          }
        }

        Text {
          id: introText
          width: parent.width
          visible: !root.readerMode && root.query.trim() === "" && resultModel.count === 0
          height: visible ? implicitHeight : 0
          text: "Search a word, phrase, or reference. Click a verse to copy it."
          textFormat: Text.PlainText
          color: root.popupForeground
          opacity: 0.58
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          id: statusLabel
          width: parent.width
          visible: !root.readerMode && (root.query.trim() !== "" || root.dailyView)
          height: visible ? implicitHeight : 0
          text: root.copyFeedback !== "" ? root.copyFeedback : root.statusText
          textFormat: Text.PlainText
          color: root.copyFailed ? Color.urgent : root.copyFeedback !== "" ? Color.accent : root.popupForeground
          opacity: 0.64
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          id: narrationActions
          width: parent.width
          visible: !root.readerMode && (root.query.trim() !== "" || root.dailyView) && resultModel.count > 0
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.xs
          readonly property int actionCount: 3 + (root.narrationActive ? 1 : 0)
          readonly property real actionWidth: actionCount > 0
            ? (width - spacing * (actionCount - 1)) / actionCount
            : width

          Rectangle {
            id: readVerseButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: readVerseMouse.containsMouse
              ? Style.hoverFillFor(root.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.popups.border

            Text {
              id: readVerseLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: root.selectedIndex === 0 && topSpeechProc.running ? "Preparing…"
                : root.selectedIndex === 0 && root.topSpeechReady ? "Read"
                : "Read"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: readVerseMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.readVerse(root.selectedIndex)
            }
          }

          Rectangle {
            id: openBookButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: openBookMouse.containsMouse
              ? Style.hoverFillFor(root.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.popups.border

            Text {
              id: openBookLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Open book"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: openBookMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openReader(root.selectedIndex)
            }
          }

          Rectangle {
            id: readChapterButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: readChapterMouse.containsMouse
              ? Style.hoverFillFor(root.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.popups.border

            Text {
              id: readChapterLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Read chapter"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: readChapterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.readChapter(root.selectedIndex)
            }
          }

          Rectangle {
            id: stopNarrationButton
            visible: root.narrationActive
            width: visible ? narrationActions.actionWidth : 0
            height: Style.space(32)
            radius: Style.cornerRadius
            color: stopNarrationMouse.containsMouse
              ? Style.hoverFillFor(root.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.popups.border

            Text {
              id: stopNarrationLabel
              anchors.centerIn: parent
              text: "Stop"
              textFormat: Text.PlainText
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: stopNarrationMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.stopNarration()
            }
          }
        }

        Text {
          id: narrationStatusLabel
          width: parent.width
          visible: !root.readerMode && root.narrationStatus !== "" && !root.readAlongVisible
          height: visible ? implicitHeight : 0
          text: root.narrationStatus
          textFormat: Text.PlainText
          color: root.ttsAvailable ? root.popupForeground : Color.urgent
          opacity: 0.64
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Item {
          id: readAlongCard
          width: parent.width
          visible: !root.readerMode && root.readAlongVisible
          height: visible ? readAlongColumn.implicitHeight + (Style.spacing.sm * 2) : 0

          BorderSurface {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Style.hoverFillFor(root.popupForeground, Color.accent)
            borderSpec: Border.flat(Color.accent, 1)
          }

          Column {
            id: readAlongColumn
            x: Style.spacing.sm
            y: Style.spacing.sm
            width: parent.width - (Style.spacing.sm * 2)
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                text: "Read along"
                textFormat: Text.PlainText
                color: root.popupForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Item {
                width: Math.max(0, parent.width - readAlongState.implicitWidth - Style.spacing.xs)
                height: 1
              }

              Text {
                id: readAlongState
                text: root.narrationStatus
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.66
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(3)
              radius: height / 2
              color: Style.hoverFillFor(root.popupForeground, Color.accent)

              Rectangle {
                width: parent.width * root.narrationProgress
                height: parent.height
                radius: height / 2
                color: Color.accent
              }
            }

            Text {
              width: parent.width
              visible: root.narrationRowAt(-1) !== null
              text: root.narrationRowAt(-1) === null
                ? ""
                : root.narrationRowAt(-1).reference + "  " + root.narrationRowAt(-1).verse
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.38
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.narrationRowAt(0) === null ? "" : root.narrationRowAt(0).reference
              textFormat: Text.PlainText
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Flow {
              id: currentWordFlow
              width: parent.width
              spacing: Style.spacing.xs
              height: childrenRect.height

              Repeater {
                model: root.narrationWords

                delegate: Rectangle {
                  required property string modelData
                  required property int index
                  width: wordLabel.implicitWidth + Style.space(6)
                  height: wordLabel.implicitHeight + Style.space(4)
                  radius: Style.space(2)
                  color: index === root.narrationWordIndex && root.narrationMode !== ""
                    ? Color.accent
                    : "transparent"

                  Text {
                    id: wordLabel
                    anchors.centerIn: parent
                    text: parent.modelData
                    textFormat: Text.PlainText
                    color: index === root.narrationWordIndex && root.narrationMode !== ""
                      ? Color.popups.background
                      : root.popupForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: index === root.narrationWordIndex && root.narrationMode !== ""
                  }
                }
              }
            }

            Text {
              width: parent.width
              visible: root.narrationRowAt(1) !== null
              text: root.narrationRowAt(1) === null
                ? ""
                : root.narrationRowAt(1).reference + "  " + root.narrationRowAt(1).verse
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.38
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Rectangle {
                id: previousReadButton
                enabled: root.narrationMode !== "" && root.narrationIndex > 0
                width: previousReadLabel.implicitWidth + Style.space(20)
                height: Style.space(26)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: previousReadMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: previousReadLabel
                  anchors.centerIn: parent
                  text: "PREV"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: previousReadMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.skipNarration(-1)
                }
              }

              Rectangle {
                id: nextReadButton
                enabled: root.narrationMode !== "" && root.narrationIndex < root.narrationQueue.length - 1
                width: nextReadLabel.implicitWidth + Style.space(20)
                height: Style.space(26)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: nextReadMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: nextReadLabel
                  anchors.centerIn: parent
                  text: "NEXT"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: nextReadMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.skipNarration(1)
                }
              }

              Item {
                width: Math.max(0, parent.width - previousReadButton.width - nextReadButton.width - stopReadButton.width - (parent.spacing * 2))
                height: 1
              }

              Rectangle {
                id: stopReadButton
                visible: root.narrationActive
                width: visible ? stopReadLabel.implicitWidth + Style.space(20) : 0
                height: Style.space(26)
                radius: Style.cornerRadius
                color: stopReadMouse.containsMouse
                  ? Style.hoverFillFor(root.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: stopReadLabel
                  anchors.centerIn: parent
                  text: "STOP"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: stopReadMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.stopNarration()
                }
              }
            }

            Text {
              width: parent.width
              text: "Word timing is estimated for local speech."
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.42
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Flickable {
          id: resultList
          width: parent.width
          visible: !root.readerMode && (root.query.trim() !== "" || root.dailyView)
          height: visible ? Math.min(Style.space(320), Math.max(Style.space(96), resultStack.implicitHeight)) : 0
          clip: true
          contentWidth: width
          contentHeight: resultStack.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: resultStack
            width: resultList.width
            spacing: Style.spacing.xs

            Item {
              id: emptyState
              visible: resultModel.count === 0
              width: resultStack.width
              height: Style.space(96)

              Text {
                anchors.centerIn: parent
                text: dailyProc.running ? "Choosing today’s verse…"
                  : root.statusText.indexOf("Searching") === 0 ? "Searching the Bible…"
                  : root.statusText.indexOf("Could not") === 0 || root.statusText.indexOf("unavailable") >= 0
                    ? root.statusText : "No matching verses"
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.62
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            Column {
              id: resultColumn
              width: resultStack.width
              spacing: Style.spacing.xs
              visible: resultModel.count > 0

              Repeater {
                model: resultModel
                delegate: Item {
                  required property int index
                  required property string reference
                  required property string verse

                  width: resultColumn.width
                  visible: !(index === 0 && root.readAlongDuplicatesTop)
                  height: visible ? resultCardContent.implicitHeight + Style.spacing.sm * 2 : 0

                  BorderSurface {
                    anchors.fill: parent
                    radius: Style.cornerRadius
                    color: root.selectedIndex === index
                      ? Style.hoverFillFor(root.popupForeground, Color.accent)
                      : "transparent"
                    borderSpec: root.selectedIndex === index
                      ? Border.controlSpec("hover-cursor", root.popupForeground, Color.accent)
                      : Border.flat(Color.popups.border, 1)
                  }

                  MouseArea {
                    id: resultCopyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: root.copyResult(index)
                  }

                  Column {
                    id: resultCardContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.spacing.sm
                    spacing: Style.spacing.xs

                    Item {
                      width: parent.width
                      height: Math.max(referenceLabel.implicitHeight, cardActions.height)

                      Text {
                        id: referenceLabel
                        anchors.left: parent.left
                        anchors.right: cardActions.left
                        anchors.rightMargin: Style.spacing.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: reference
                        textFormat: Text.PlainText
                        color: root.popupForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Row {
                        id: cardActions
                        z: 4
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.spacing.xs
                        readonly property real chipWidth: Style.space(52)
                        readonly property real chipHeight: Style.space(24)

                        Rectangle {
                          id: readButton
                          width: cardActions.chipWidth
                          height: cardActions.chipHeight
                          radius: Style.cornerRadius
                          color: readMouse.containsMouse
                            ? Style.hoverFillFor(root.popupForeground, Color.accent)
                            : Style.normalFillFor(root.popupForeground, Color.accent)
                          border.width: 1
                          border.color: Color.popups.border

                          Text {
                            id: readChipLabel
                            anchors.centerIn: parent
                            text: "Read"
                            textFormat: Text.PlainText
                            color: root.popupForeground
                            opacity: 0.78
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                          }

                          MouseArea {
                            id: readMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.selectedIndex = index
                              root.readVerse(index)
                            }
                          }
                        }

                        Rectangle {
                          id: copyButton
                          width: cardActions.chipWidth
                          height: cardActions.chipHeight
                          radius: Style.cornerRadius
                          color: copyChipMouse.containsMouse
                            ? Style.hoverFillFor(root.popupForeground, Color.accent)
                            : Style.normalFillFor(root.popupForeground, Color.accent)
                          border.width: 1
                          border.color: Color.popups.border

                          Text {
                            id: copyChipLabel
                            anchors.centerIn: parent
                            text: "Copy"
                            textFormat: Text.PlainText
                            color: root.popupForeground
                            opacity: 0.78
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                          }

                          MouseArea {
                            id: copyChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.selectedIndex = index
                              root.copyResult(index)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      id: verseText
                      width: parent.width
                      text: verse
                      textFormat: Text.PlainText
                      color: root.popupForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      wrapMode: Text.WordWrap
                      lineHeight: 1.28
                      lineHeightMode: Text.ProportionalHeight
                    }
                  }
                }
              }
            }
          }
        }
        }
      }
    }
  }
}

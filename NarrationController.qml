import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: controller

  // Back-reference to the owning Panel (root). Anything this controller
  // needs that it doesn't own itself — scriptPath, resultModel, reader
  // state, the shared chapterProc, wordsFor(), preferredVoice, and the
  // derived usePiper/ttsAvailable properties — goes through panel.*.
  property var panel: null

  readonly property var ttsCandidates: ["espeak-ng", "espeak", "spd-say"]
  property int ttsCandidateIndex: 0
  property bool ttsChecked: false
  property string ttsEngine: ""
  property bool piperReady: false
  property bool narrationPaused: false
  property real narrationSpeed: 1.0
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

  function detectTts() {
    if (controller.ttsDetectProc.running) return
    controller.ttsChecked = false
    controller.ttsEngine = ""
    controller.ttsCandidateIndex = 0
    controller.ttsDetectProc.command = [controller.ttsCandidates[0], "--version"]
    controller.ttsDetectProc.running = true
    if (!controller.voiceStatusProc.running) controller.voiceStatusProc.running = true
  }

  function installVoiceEngine() {
    controller.narrationStatus = "Install espeak-ng in the terminal, then choose Check again."
    Quickshell.execDetached(["omarchy-launch-terminal", "omarchy", "pkg", "add", "espeak-ng"])
  }

  function showNarrationUnavailable() {
    controller.narrationStatus = controller.ttsChecked
      ? "No local voice engine found · install espeak-ng, espeak, or speech-dispatcher"
      : "Checking for a local voice engine…"
  }

  function wordDurationMs(word) {
    var value = String(word || "")
    var duration = 60000 / Math.max(80, controller.narrationWpm)
    duration *= 1 + Math.min(0.7, Math.max(0, value.length - 5) * 0.035)
    if (/[,;:]$/.test(value)) duration += 90
    if (/[.!?]$/.test(value)) duration += 220
    return Math.round(duration * Math.max(0.55, Math.min(1.9, controller.narrationTimingScale)))
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
    // narrationWords ONCE (called when a verse begins narrating), so the
    // per-tick highlight update never has to re-run the regex-heavy
    // wordCadenceWeight() for every word in the verse.
    var total = 0
    var cumulative = []
    for (var i = 0; i < controller.narrationWords.length; i++) {
      total += controller.wordCadenceWeight(controller.narrationWords[i])
      cumulative.push(total)
    }
    controller.narrationCumulativeWeights = cumulative
    controller.narrationCadenceTotal = Math.max(1, total)
    return controller.narrationCadenceTotal
  }

  function baseNarrationMs(words) {
    var total = 0
    for (var i = 0; i < words.length; i++) {
      var value = String(words[i] || "")
      var duration = 60000 / Math.max(80, controller.narrationWpm)
      duration *= 1 + Math.min(0.7, Math.max(0, value.length - 5) * 0.035)
      if (/[,;:]$/.test(value)) duration += 90
      if (/[.!?]$/.test(value)) duration += 220
      total += Math.round(duration)
    }
    return Math.max(700, total)
  }

  function calibrateNarrationTiming() {
    if (controller.narrationVerseStartedAt <= 0 || controller.narrationWords.length === 0) return
    var elapsed = Date.now() - controller.narrationVerseStartedAt
    var baseline = controller.baseNarrationMs(controller.narrationWords)
    if (elapsed < 250 || baseline <= 0) return
    var observed = Math.max(0.55, Math.min(1.9, elapsed / baseline))
    controller.narrationTimingScale = Math.max(0.55, Math.min(1.9,
      (controller.narrationTimingScale * 0.72) + (observed * 0.28)))
  }

  function estimateNarrationMs(words) {
    var total = 0
    for (var i = 0; i < words.length; i++) total += controller.wordDurationMs(words[i])
    return Math.max(700, total)
  }

  function updateNarrationWord() {
    var leadIn = controller.piperReady ? controller.narrationLeadInMs : 0
    if (controller.narrationElapsedMs <= leadIn) {
      controller.narrationWordIndex = 0
      return
    }
    var spokenDuration = Math.max(1, controller.narrationEstimatedMs - leadIn)
    var cadencePosition = Math.min(1, (controller.narrationElapsedMs - leadIn) / spokenDuration)
      * controller.narrationCadenceTotal
    var weights = controller.narrationCumulativeWeights
    for (var i = 0; i < weights.length; i++) {
      if (cadencePosition < weights[i]) {
        controller.narrationWordIndex = i
        return
      }
    }
    controller.narrationWordIndex = Math.max(0, controller.narrationWords.length - 1)
  }

  function advanceNarrationWord() {
    if (!controller.ttsProc.running || controller.narrationWords.length === 0) return
    if (controller.narrationWarmupRemainingMs > 0) {
      controller.narrationWarmupRemainingMs = Math.max(0, controller.narrationWarmupRemainingMs - controller.narrationHighlightTimer.interval)
      return
    }
    controller.narrationElapsedMs = Math.min(controller.narrationEstimatedMs, controller.narrationElapsedMs + controller.narrationHighlightTimer.interval)
    controller.updateNarrationWord()
  }

  function narrationRowAt(offset) {
    var index = panel.narrationDisplayIndex + offset
    if (index < 0 || index >= controller.narrationQueue.length) return null
    return controller.narrationQueue[index]
  }

  function beginNarration(queue, mode, generation, startIndex) {
    if (generation !== controller.narrationGeneration || queue.length === 0) return
    controller.narrationQueue = queue
    controller.narrationIndex = Math.max(0, Math.min(startIndex || 0, queue.length - 1))
    controller.narrationMode = mode
    controller.narrationStatus = mode === "chapter"
      ? "Reading chapter · " + queue.length + " verses"
      : "Reading " + queue[0].reference
    controller.speakNext(generation)
  }

  function continuePendingNarration() {
    controller.narrationStopPending = false
    var nextQueue = controller.pendingNarrationQueue
    var nextMode = controller.pendingNarrationMode
    var nextIndex = controller.pendingNarrationIndex
    var nextGeneration = controller.pendingNarrationGeneration
    controller.pendingNarrationQueue = []
    controller.pendingNarrationMode = ""
    controller.pendingNarrationIndex = 0
    controller.pendingNarrationGeneration = 0
    if (nextQueue.length > 0 && nextGeneration === controller.narrationGeneration) {
      Qt.callLater(function() { controller.beginNarration(nextQueue, nextMode, nextGeneration, nextIndex) })
    }
  }

  function cleanupPreparedSpeech() {
    if (controller.preparedSpeechPath === "") return
    Quickshell.execDetached([panel.scriptPath, "speech-cleanup", controller.preparedSpeechPath])
    controller.preparedSpeechPath = ""
  }

  function cleanupPrefetchedSpeech() {
    if (controller.speechPrefetchProc.running) controller.speechPrefetchProc.running = false
    if (controller.prefetchedSpeechPath !== "") {
      Quickshell.execDetached([panel.scriptPath, "speech-cleanup", controller.prefetchedSpeechPath])
    }
    controller.prefetchedSpeechPath = ""
    controller.prefetchedSpeechDurationMs = 0
    controller.prefetchedSpeechIndex = -1
    controller.prefetchedSpeechReference = ""
    controller.prefetchedSpeechVerse = ""
    controller.prefetchRequestIndex = -1
    controller.prefetchRequestGeneration = 0
  }

  function cleanupTopSpeech() {
    if (controller.topSpeechProc.running) controller.topSpeechProc.running = false
    if (controller.topSpeechPath !== "") {
      Quickshell.execDetached([panel.scriptPath, "speech-cleanup", controller.topSpeechPath])
    }
    controller.topSpeechPath = ""
    controller.topSpeechDurationMs = 0
    controller.topSpeechReference = ""
    controller.topSpeechVerse = ""
  }

  function preloadTopSpeech() {
    if (!panel.usePiper || panel.resultModel.count === 0 || controller.topSpeechProc.running) return
    var row = panel.resultModel.get(0)
    if (controller.topSpeechPath !== "" && controller.topSpeechReference === row.reference
        && controller.topSpeechVerse === row.verse) return
    controller.cleanupTopSpeech()
    controller.topSpeechReference = row.reference
    controller.topSpeechVerse = row.verse
    controller.topSpeechProc.command = [panel.scriptPath, "prepare-speech", row.verse, String(controller.narrationSpeed)]
    controller.topSpeechProc.running = true
  }

  function setNarrationSpeed(speed) {
    controller.narrationSpeed = Math.max(0.85, Math.min(1.15, Number(speed) || 1))
    controller.cleanupTopSpeech()
    controller.preloadTopSpeech()
    panel.scheduleReaderStateSave()
  }

  function toggleNarrationPause() {
    if (!controller.ttsProc.running || controller.ttsProc.processId <= 0) {
      if (panel.resultModel.count > 0) panel.readVerse(panel.selectedIndex)
      return
    }
    controller.narrationPaused = !controller.narrationPaused
    Quickshell.execDetached(["kill", controller.narrationPaused ? "-STOP" : "-CONT", String(controller.ttsProc.processId)])
    controller.narrationStatus = controller.narrationPaused ? "Paused · Space to resume" : "Reading · " + controller.narrationDisplayRow.reference
  }

  function resumeNarrationProcessBeforeCancel() {
    if (!controller.narrationPaused || !controller.ttsProc.running || controller.ttsProc.processId <= 0) return
    Quickshell.execDetached(["kill", "-CONT", String(controller.ttsProc.processId)])
    controller.narrationPaused = false
  }

  function startPiperPlayback(path, durationMs, row) {
    controller.preparedSpeechPath = path
    controller.narrationEstimatedMs = Math.max(700, Number(durationMs) || controller.narrationEstimatedMs)
    controller.narrationElapsedMs = 0
    controller.narrationWordIndex = 0
    controller.narrationVerseStartedAt = Date.now()
    controller.narrationStatus = "Neural voice · " + (row ? row.reference : "reading")
    controller.ttsProc.command = ["paplay", controller.preparedSpeechPath]
    controller.ttsProc.running = true
    controller.startSpeechPrefetch()
  }

  function startSpeechPrefetch() {
    if (!panel.usePiper || controller.speechPrefetchProc.running) return
    var nextIndex = controller.narrationIndex + 1
    var nextRow = null
    if (controller.narrationMode === "chapter" && nextIndex < controller.narrationQueue.length) {
      nextRow = controller.narrationQueue[nextIndex]
    } else if (controller.narrationMode === "verse" && panel.selectedIndex + 1 < panel.resultModel.count) {
      nextIndex = -2
      nextRow = panel.resultModel.get(panel.selectedIndex + 1)
    }
    if (!nextRow) return
    controller.cleanupPrefetchedSpeech()
    controller.prefetchRequestIndex = nextIndex
    controller.prefetchRequestGeneration = controller.narrationGeneration
    controller.prefetchedSpeechReference = nextRow.reference
    controller.prefetchedSpeechVerse = nextRow.verse
    controller.speechPrefetchProc.command = [panel.scriptPath, "prepare-speech", nextRow.verse, String(controller.narrationSpeed)]
    controller.speechPrefetchProc.running = true
  }

  function requestNarration(queue, mode, startIndex) {
    if (!panel.ttsAvailable) {
      controller.showNarrationUnavailable()
      return
    }
    if (!queue || queue.length === 0) return
    var firstIndex = Math.max(0, Math.min(startIndex || 0, queue.length - 1))
    controller.narrationCardPinned = true
    var firstRow = queue[firstIndex]
    if (controller.prefetchedSpeechPath === "" || controller.prefetchedSpeechReference !== firstRow.reference
        || controller.prefetchedSpeechVerse !== firstRow.verse) controller.cleanupPrefetchedSpeech()

    if (panel.chapterProc.running) {
      panel.chapterRequestGeneration++
      panel.chapterProc.running = false
    }

    controller.narrationGeneration++
    var generation = controller.narrationGeneration
    if (controller.narrationStopPending || controller.ttsProc.running || controller.speechPrepareProc.running) {
      controller.pendingNarrationQueue = queue
      controller.pendingNarrationMode = mode
      controller.pendingNarrationIndex = firstIndex
      controller.pendingNarrationGeneration = generation
      if (!controller.narrationStopPending) {
        controller.narrationStopPending = true
        if (controller.ttsProc.running) {
          controller.resumeNarrationProcessBeforeCancel()
          controller.ttsProc.running = false
        }
        if (controller.speechPrepareProc.running) controller.speechPrepareProc.running = false
      }
      return
    }
    controller.beginNarration(queue, mode, generation, firstIndex)
  }

  function speakNext(generation) {
    if (generation !== controller.narrationGeneration || controller.narrationQueue.length === 0) return
    if (controller.narrationIndex >= controller.narrationQueue.length) {
      controller.narrationStatus = controller.narrationMode === "chapter" ? "Chapter finished" : "Finished reading"
      controller.narrationMode = ""
      panel.scheduleReaderStateSave()
      return
    }
    var row = controller.narrationQueue[controller.narrationIndex]
    if (controller.narrationMode === "chapter") {
      var chapterIndex = panel.readerState.readerChapterQueue.indexOf(row)
      panel.readerState.readerSelectedVerseIndex = chapterIndex >= 0 ? chapterIndex : controller.narrationIndex
      if (panel.readerState.readerMode) panel.syncReaderPageToVerse(panel.readerState.readerSelectedVerseIndex)
    }
    controller.narrationWords = panel.wordsFor(row.verse)
    controller.narrationCadenceWeight()
    controller.narrationWordIndex = 0
    controller.narrationElapsedMs = 0
    controller.narrationWarmupRemainingMs = 0
    controller.narrationEstimatedMs = controller.estimateNarrationMs(controller.narrationWords)
    controller.narrationVerseStartedAt = 0
    var voicePrefix = panel.usePiper ? "Neural voice · " : "Reading · "
    controller.narrationStatus = controller.narrationMode === "chapter"
      ? voicePrefix + row.reference + " · " + (controller.narrationIndex + 1) + "/" + controller.narrationQueue.length
      : voicePrefix + row.reference
    controller.ttsProcessGeneration = generation
    if (panel.usePiper) {
      if (controller.narrationMode === "verse" && controller.topSpeechPath !== ""
          && controller.topSpeechReference === row.reference && controller.topSpeechVerse === row.verse) {
        var topPath = controller.topSpeechPath
        var topDuration = controller.topSpeechDurationMs
        controller.topSpeechPath = ""
        controller.topSpeechDurationMs = 0
        controller.topSpeechReference = ""
        controller.topSpeechVerse = ""
        controller.startPiperPlayback(topPath, topDuration, row)
        return
      }
      if (controller.prefetchedSpeechPath !== "" && ((controller.prefetchedSpeechIndex === controller.narrationIndex)
          || (controller.prefetchedSpeechReference === row.reference && controller.prefetchedSpeechVerse === row.verse))) {
        var readyPath = controller.prefetchedSpeechPath
        var readyDuration = controller.prefetchedSpeechDurationMs
        controller.prefetchedSpeechPath = ""
        controller.prefetchedSpeechDurationMs = 0
        controller.prefetchedSpeechIndex = -1
        controller.prefetchedSpeechReference = ""
        controller.prefetchedSpeechVerse = ""
        controller.startPiperPlayback(readyPath, readyDuration, row)
        return
      }
      if (controller.speechPrefetchProc.running) controller.speechPrefetchProc.running = false
      controller.narrationStatus = "Preparing neural voice · " + row.reference
      controller.speechPrepareProc.command = [panel.scriptPath, "prepare-speech", row.verse, String(controller.narrationSpeed)]
      controller.speechPrepareProc.running = true
      return
    } else if (controller.ttsEngine === "spd-say") {
      controller.ttsProc.command = [controller.ttsEngine, "--wait", "--", row.verse]
    } else {
      controller.ttsProc.command = [controller.ttsEngine, "--", row.verse]
    }
    controller.narrationVerseStartedAt = Date.now()
    controller.ttsProc.running = true
  }

  function skipNarration(delta) {
    if (controller.narrationQueue.length < 2 || controller.narrationMode === "") return
    var nextIndex = controller.narrationIndex + delta
    if (nextIndex < 0 || nextIndex >= controller.narrationQueue.length) return

    var generation = controller.narrationGeneration
    controller.pendingNarrationQueue = controller.narrationQueue
    controller.pendingNarrationMode = controller.narrationMode
    controller.pendingNarrationIndex = nextIndex
    controller.pendingNarrationGeneration = generation
    controller.cleanupPrefetchedSpeech()
    if (controller.ttsProc.running || controller.speechPrepareProc.running) {
      controller.narrationStopPending = true
      if (controller.ttsProc.running) {
        controller.resumeNarrationProcessBeforeCancel()
        controller.ttsProc.running = false
      }
      if (controller.speechPrepareProc.running) controller.speechPrepareProc.running = false
    } else {
      controller.beginNarration(controller.narrationQueue, controller.narrationMode, generation, nextIndex)
      controller.pendingNarrationQueue = []
      controller.pendingNarrationMode = ""
      controller.pendingNarrationIndex = 0
      controller.pendingNarrationGeneration = 0
    }
  }

  function stopNarration() {
    controller.narrationGeneration++
    controller.narrationCardPinned = false
    controller.narrationQueue = []
    controller.narrationIndex = 0
    controller.narrationMode = ""
    panel.chapterRequestGeneration++
    controller.pendingNarrationQueue = []
    controller.pendingNarrationMode = ""
    controller.pendingNarrationIndex = 0
    controller.pendingNarrationGeneration = 0
    controller.cleanupPrefetchedSpeech()
    controller.cleanupPreparedSpeech()
    if (controller.ttsProc.running || controller.speechPrepareProc.running) {
      controller.narrationStopPending = true
      if (controller.ttsProc.running) {
        controller.resumeNarrationProcessBeforeCancel()
        controller.ttsProc.running = false
      }
      if (controller.speechPrepareProc.running) controller.speechPrepareProc.running = false
    } else {
      controller.narrationStopPending = false
    }
    if (panel.chapterProc.running) panel.chapterProc.running = false
    if (controller.ttsChecked && !panel.ttsAvailable) controller.showNarrationUnavailable()
    else if (controller.narrationStatus !== "") controller.narrationStatus = "Stopped"
    panel.scheduleReaderStateSave()
  }

  property Timer narrationHighlightTimer: Timer {
    interval: 40
    repeat: true
    running: controller.ttsProc.running && !controller.narrationPaused && controller.narrationWords.length > 0
    onTriggered: controller.advanceNarrationWord()
  }

  property Timer narrationCompleteTimer: Timer {
    interval: 1400
    repeat: false
    onTriggered: {
      if (!panel.narrationActive && controller.narrationMode === "") {
        controller.narrationCardPinned = false
        controller.narrationQueue = []
      }
    }
  }

  property Process voiceStatusProc: Process {
    command: [panel.scriptPath, "voice-status"]
    running: false
    stdout: StdioCollector { id: voiceStatusOutput; waitForEnd: true }
    onExited: function(exitCode) {
      controller.piperReady = exitCode === 0 && String(voiceStatusOutput.text).indexOf("VOICE\tpiper") >= 0
      if (controller.piperReady) {
        controller.ttsChecked = true
        if (controller.narrationStatus.indexOf("No local voice") === 0) controller.narrationStatus = "Neural voice ready"
        controller.preloadTopSpeech()
      }
    }
  }

  property Process ttsDetectProc: Process {
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) {
        controller.ttsEngine = String(controller.ttsCandidates[controller.ttsCandidateIndex])
        controller.ttsChecked = true
        return
      }
      if (controller.ttsCandidateIndex + 1 < controller.ttsCandidates.length) {
        controller.ttsCandidateIndex++
        Qt.callLater(function() {
          controller.ttsDetectProc.command = [controller.ttsCandidates[controller.ttsCandidateIndex], "--version"]
          controller.ttsDetectProc.running = true
        })
      } else {
        controller.ttsChecked = true
        controller.showNarrationUnavailable()
      }
    }
  }

  property Process topSpeechProc: Process {
    running: false
    stdout: StdioCollector { id: topSpeechOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var parts = String(topSpeechOutput.text).trim().split("\t")
      var validAudio = exitCode === 0 && parts.length === 3 && parts[0] === "AUDIO"
      var current = panel.resultModel.count > 0 ? panel.resultModel.get(0) : null
      if (!current || current.reference !== controller.topSpeechReference || current.verse !== controller.topSpeechVerse) {
        if (validAudio) Quickshell.execDetached([panel.scriptPath, "speech-cleanup", parts[1]])
        controller.topSpeechReference = ""
        controller.topSpeechVerse = ""
        Qt.callLater(function() { controller.preloadTopSpeech() })
        return
      }
      if (!validAudio) return
      controller.topSpeechPath = parts[1]
      controller.topSpeechDurationMs = Math.max(700, Number(parts[2]) || 700)
    }
  }

  property Process speechPrepareProc: Process {
    running: false
    stdout: StdioCollector { id: speechPrepareOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (controller.narrationStopPending) {
        controller.continuePendingNarration()
        return
      }
      if (controller.ttsProcessGeneration !== controller.narrationGeneration) return
      if (exitCode !== 0) {
        controller.narrationStatus = "Neural voice preparation failed"
        controller.narrationMode = ""
        return
      }
      var parts = String(speechPrepareOutput.text).trim().split("\t")
      if (parts.length !== 3 || parts[0] !== "AUDIO") {
        controller.narrationStatus = "Neural voice returned invalid audio"
        controller.narrationMode = ""
        return
      }
      var row = controller.narrationQueue[controller.narrationIndex]
      controller.startPiperPlayback(parts[1], parts[2], row)
    }
  }

  property Process speechPrefetchProc: Process {
    running: false
    stdout: StdioCollector { id: speechPrefetchOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0
          || controller.prefetchRequestGeneration !== controller.narrationGeneration
          || controller.prefetchRequestIndex === -1) {
        controller.prefetchRequestIndex = -1
        controller.prefetchRequestGeneration = 0
        return
      }
      var parts = String(speechPrefetchOutput.text).trim().split("\t")
      if (parts.length !== 3 || parts[0] !== "AUDIO") {
        controller.prefetchRequestIndex = -1
        controller.prefetchRequestGeneration = 0
        return
      }
      controller.prefetchedSpeechPath = parts[1]
      controller.prefetchedSpeechDurationMs = Math.max(700, Number(parts[2]) || 700)
      controller.prefetchedSpeechIndex = controller.prefetchRequestIndex
      controller.prefetchRequestIndex = -1
      controller.prefetchRequestGeneration = 0
    }
  }

  property Process ttsProc: Process {
    running: false
    onExited: function(exitCode) {
      controller.narrationPaused = false
      controller.cleanupPreparedSpeech()
      if (controller.narrationStopPending) {
        controller.continuePendingNarration()
        return
      }
      if (controller.ttsProcessGeneration !== controller.narrationGeneration) return
      if (exitCode !== 0) {
        controller.narrationStatus = "Voice engine failed"
        controller.narrationMode = ""
        return
      }
      controller.calibrateNarrationTiming()
      controller.narrationIndex++
      if (controller.narrationIndex >= controller.narrationQueue.length) controller.narrationCompleteTimer.restart()
      Qt.callLater(function() { controller.speakNext(controller.narrationGeneration) })
    }
  }
}

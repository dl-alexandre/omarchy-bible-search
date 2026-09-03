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
  property string preferredVoice: "male"
  property bool dailyOnOpen: true
  property bool settingsOpen: false
  property int chapterRequestGeneration: 0
  property int activeChapterRequest: 0
  property string chapterLoadPurpose: ""
  property bool readerLibraryOpen: false
  property string readerLibraryTab: "books"
  property string readerBookFilter: ""
  property string readerCatalogBook: "Genesis"
  property int readerCatalogChapterCount: 50
  property bool catalogLoaded: false
  property bool readerStateReady: false
  property bool readerStateLoading: true
  property bool readerStateHydrated: false
  property var readerSavedPosition: null
  property bool reduceMotion: false
  property int searchChromeIndex: -1
  property string readerLibraryFocus: "books"
  property int readerBookCursor: 0
  property int readerChapterCursor: 0
  property int readerListCursor: 0
  property var topicSuggestions: ["faith", "comfort", "wisdom", "love"]
  property int topicSuggestionOffset: -1
  readonly property NarrationController narration: NarrationController {
    panel: root
  }
  readonly property ReaderState readerState: ReaderState {
    panel: root
  }

  readonly property bool usePiper: narration.piperReady && root.preferredVoice === "male"
  readonly property bool ttsAvailable: root.usePiper || (narration.ttsEngine !== "" && narration.ttsEngine !== "piper")
  readonly property bool narrationActive: narration.ttsProc.running || narration.speechPrepareProc.running || narration.speechPrefetchProc.running || chapterProc.running || narration.narrationStopPending
  readonly property bool readAlongVisible: narration.narrationCardPinned && narration.narrationQueue.length > 0
  readonly property bool readAlongDuplicatesTop: root.readAlongVisible && resultModel.count > 0
    && narration.narrationDisplayRow && narration.narrationDisplayRow.reference === resultModel.get(0).reference
  readonly property bool topSpeechReady: resultModel.count > 0 && narration.topSpeechPath !== ""
    && narration.topSpeechReference === resultModel.get(0).reference && narration.topSpeechVerse === resultModel.get(0).verse
  readonly property int narrationDisplayIndex: narration.narrationQueue.length === 0
    ? -1
    : Math.min(narration.narrationIndex, narration.narrationQueue.length - 1)
  readonly property real narrationProgress: narration.narrationQueue.length === 0
    ? 0
      : Math.min(1, (narration.narrationIndex + (narration.narrationMode !== ""
      ? (narration.narrationWordIndex + 1) / Math.max(1, narration.narrationWords.length)
      : 1)) / narration.narrationQueue.length)
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
      if (root.opened && readerState.readerMode && keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function open() {
    root.controller.show()
    root.rotateTopicSuggestions()
    if (narration.ttsChecked && !root.ttsAvailable && !narration.ttsDetectProc.running) narration.detectTts()
    if (root.dailyOnOpen && root.query.trim() === "" && resultModel.count === 0 && !dailyProc.running) {
      root.showDailyVerse()
    } else if (root.query.trim() !== "" && resultModel.count === 0 && !searchProc.running && !root.searchStopPending) {
      root.searchGeneration++
      root.statusText = "Searching…"
      searchTimer.restart()
    }
    Qt.callLater(function() {
      if (readerState.readerMode) keyCatcher.forceActiveFocus()
      else {
        root.searchChromeIndex = -1
        searchField.forceActiveFocus()
      }
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
      narration.preloadTopSpeech()
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
    readerState.readerMode = false
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
      narration.preloadTopSpeech()
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

  function readVerse(index) {
    if (index < 0 || index >= resultModel.count) return
    var row = resultModel.get(index)
    narration.requestNarration([{ reference: row.reference, verse: row.verse }], "verse")
  }

  function readChapter(index) {
    if (index < 0 || index >= resultModel.count) return
    if (!root.ttsAvailable) {
      narration.showNarrationUnavailable()
      return
    }
    if (chapterProc.running) {
      narration.narrationStatus = "A chapter is already loading"
      return
    }

    var row = resultModel.get(index)
    var match = String(row.reference || "").match(/^(.+)\s+([0-9]+):[0-9]+$/)
    if (!match) {
      narration.narrationStatus = "Select a verse with a chapter reference first"
      return
    }

    narration.stopNarration()
    root.chapterLoadPurpose = "narration"
    readerState.readerChapterLabel = match[1] + " " + match[2]
    root.chapterRequestGeneration++
    root.activeChapterRequest = root.chapterRequestGeneration
    narration.narrationMode = "chapter"
    narration.narrationStatus = "Loading " + match[1] + " " + match[2] + "…"
    chapterProc.command = [root.scriptPath, "chapter", match[1] + " " + match[2]]
    chapterProc.running = true
  }

  function chapterDetails(reference) {
    var match = String(reference || "").match(/^(.+)\s+([0-9]+):[0-9]+$/)
    return match ? { book: match[1], chapter: match[2] } : null
  }

  function currentChapterParts() {
    var match = String(readerState.readerChapterLabel || "").match(/^(.+)\s+([0-9]+)$/)
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

  function advanceReaderChapter(direction) {
    if (chapterProc.running || readerState.readerLoading) return false
    var next = root.adjacentChapter(direction)
    if (!next) {
      readerState.readerActionFeedback = direction > 0 ? "End of the Bible" : "Beginning of the Bible"
      readerActionFeedbackTimer.restart()
      return false
    }
    root.stopReaderTurnAnimations()
    readerState.readerTurning = false
    readerState.readerTurnCrossesChapter = false
    readerState.readerTurnAngle = 0
    readerState.readerTurnProgress = 0
    var landAtEnd = direction < 0
    root.openReaderChapter(next.book, next.chapter, "", landAtEnd ? 9999 : 0, landAtEnd ? 9999 : 0)
    return true
  }

  function scrollReaderVerseIntoView() {
    if (!readerPageFlick || readerState.readerChapterQueue.length === 0) return
    var n = readerState.readerChapterQueue.length
    var span = Math.max(0, readerPageFlick.contentHeight - readerPageFlick.height)
    readerPageFlick.contentY = span * (readerState.readerSelectedVerseIndex / Math.max(1, n - 1))
  }

  function readerChromeItems() {
    var items = ["search", "library"]
    if (!root.readerLibraryOpen) {
      items.push("prev", "next", "read", "from", "save")
      if (root.narrationActive) items.push("stop")
    }
    return items
  }

  function readerChromeIs(id) {
    var items = root.readerChromeItems()
    return readerState.readerChromeIndex >= 0 && readerState.readerChromeIndex < items.length && items[readerState.readerChromeIndex] === id
  }

  function cycleReaderChrome(direction) {
    var items = root.readerChromeItems()
    if (items.length === 0) return
    if (readerState.readerChromeIndex < 0)
      readerState.readerChromeIndex = direction > 0 ? 0 : items.length - 1
    else
      readerState.readerChromeIndex = (readerState.readerChromeIndex + direction + items.length) % items.length
    root.focusReaderKeyboard()
  }

  function activateReaderChrome() {
    var items = root.readerChromeItems()
    if (readerState.readerChromeIndex < 0 || readerState.readerChromeIndex >= items.length) {
      root.readReaderSelectedVerse()
      return
    }
    switch (items[readerState.readerChromeIndex]) {
    case "search":
      root.showSearch()
      break
    case "library":
      root.readerLibraryOpen = !root.readerLibraryOpen
      readerState.readerChromeIndex = 1
      break
    case "prev":
      root.moveReaderPage(-1)
      break
    case "next":
      root.moveReaderPage(1)
      break
    case "read":
      root.readReaderSelectedVerse()
      break
    case "from":
      root.readReaderChapter()
      break
    case "save":
      root.toggleCurrentBookmark()
      break
    case "stop":
      narration.stopNarration()
      break
    }
    root.focusReaderKeyboard()
  }

  function searchChromeItems() {
    var items = []
    if (resultModel.count > 0) {
      items.push("read", "book", "chapter")
      if (root.narrationActive) items.push("stop")
    }
    items.push("daily")
    for (var i = 0; i < root.topicSuggestions.length; i++) items.push("topic:" + i)
    return items
  }

  function searchChromeIs(id) {
    var items = root.searchChromeItems()
    return root.searchChromeIndex >= 0 && root.searchChromeIndex < items.length && items[root.searchChromeIndex] === id
  }

  function chromeFill(on, hovered) {
    if (on) {
      var a = Color.accent
      return Qt.rgba(a.r, a.g, a.b, 0.32)
    }
    if (hovered) return Style.hoverFillFor(root.popupForeground, Color.accent)
    return "transparent"
  }

  function chromeBorder(on) {
    return on ? Color.accent : Color.popups.border
  }

  function searchChromeCount() {
    return root.searchChromeItems().length
  }

  function cycleSearchChrome(direction) {
    var items = root.searchChromeItems()
    if (items.length === 0) return
    if (root.settingsOpen) {
      root.settingsOpen = false
      searchField.forceActiveFocus()
      root.searchChromeIndex = -1
      return
    }
    if (searchField.activeFocus) {
      searchField.focus = false
      keyCatcher.forceActiveFocus()
      root.searchChromeIndex = direction > 0 ? 0 : items.length - 1
      return
    }
    var next = root.searchChromeIndex + direction
    if (next < 0 || next >= items.length) {
      root.searchChromeIndex = -1
      searchField.forceActiveFocus()
      return
    }
    root.searchChromeIndex = next
    keyCatcher.forceActiveFocus()
  }

  function activateSearchChrome() {
    var items = root.searchChromeItems()
    if (root.searchChromeIndex < 0 || root.searchChromeIndex >= items.length) {
      root.activateSelected()
      return
    }
    var id = items[root.searchChromeIndex]
    if (id === "read") root.readVerse(root.selectedIndex)
    else if (id === "book") root.openReader(root.selectedIndex)
    else if (id === "chapter") root.readChapter(root.selectedIndex)
    else if (id === "stop") narration.stopNarration()
    else if (id === "daily") root.showDailyVerse()
    else if (id.indexOf("topic:") === 0) {
      var topic = root.topicSuggestions[Number(id.substring(6))]
      if (topic) {
        searchField.text = topic
        searchField.forceActiveFocus()
        root.searchChromeIndex = -1
      }
    }
  }

  function cyclePanelTab(direction) {
    if (readerState.readerMode && root.readerLibraryOpen) root.cycleLibraryTab(direction)
    else if (readerState.readerMode) root.cycleReaderChrome(direction)
    else root.cycleSearchChrome(direction)
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
    narration.stopNarration()
    readerState.readerMode = true
    root.readerLibraryOpen = false
    readerState.readerLoading = true
    readerState.readerPages = []
    readerState.readerChapterQueue = []
    readerState.readerChapterLabel = book + " " + chapter
    readerState.readerPendingReference = targetReference || ""
    readerState.readerRestorePage = restorePage === undefined ? -1 : restorePage
    readerState.readerRestoreVerse = restoreVerse === undefined ? -1 : restoreVerse
    readerState.readerPageIndex = 0
    readerState.readerSelectedVerseIndex = 0
    root.chapterLoadPurpose = "reader"
    root.chapterRequestGeneration++
    root.activeChapterRequest = root.chapterRequestGeneration
    narration.narrationStatus = "Opening " + readerState.readerChapterLabel + "…"
    chapterProc.command = [root.scriptPath, "chapter", readerState.readerChapterLabel]
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
    if (root.reduceMotion || !readerState.readerHasPages || readerState.readerTurning) return false
    var targetPage = readerState.readerPageIndex + direction
    var inChapter = targetPage >= 0 && targetPage < readerState.readerPages.length
    if (!inChapter && !root.adjacentChapter(direction)) return false

    root.stopReaderTurnAnimations()
    readerState.readerTurnCrossesChapter = !inChapter
    readerState.readerTurnTargetPage = inChapter ? targetPage : readerState.readerPageIndex
    readerState.readerTurnDirection = direction
    readerState.readerDragging = true
    readerState.readerDragMoved = false
    readerState.readerDragWasActive = false
    readerState.readerDragStartX = startX
    readerState.readerTurnAngle = 0
    readerState.readerTurnProgress = 0
    readerState.readerTurning = true
    return true
  }

  function updateReaderCornerDrag(currentX) {
    if (!readerState.readerDragging) return
    var distance = readerState.readerTurnDirection > 0
      ? readerState.readerDragStartX - currentX
      : currentX - readerState.readerDragStartX
    var travel = Math.max(1, readerPageSurface.width * 0.42)
    var ratio = Math.max(0, Math.min(1, distance / travel))
    readerState.readerDragMoved = readerState.readerDragMoved || Math.abs(distance) > 3
    readerState.readerTurnProgress = ratio * 0.5
    readerState.readerTurnAngle = 0
  }

  function finishReaderCornerDrag() {
    if (!readerState.readerDragging) return
    var ratio = Math.max(0, Math.min(1, readerState.readerTurnProgress * 2))
    var wasDrag = readerState.readerDragMoved
    readerState.readerDragging = false
    readerState.readerDragWasActive = wasDrag
    readerState.readerTurnCancelDuration = Math.max(120, Math.round(ratio * 300))
    root.stopReaderTurnAnimations()

    if (!wasDrag) {
      readerState.readerTurning = false
      readerState.readerTurnAngle = 0
      readerState.readerTurnProgress = 0
      return
    }

    if (ratio >= 0.46) {
      if (readerState.readerTurnCrossesChapter) {
        root.advanceReaderChapter(readerState.readerTurnDirection)
        return
      }
      readerState.readerTurnApproachDuration = Math.max(70, Math.round((1 - ratio) * 200))
      readerState.readerTurnSettleDuration = 240
      readerPageSwapTimer.restart()
      readerPageResetTimer.restart()
      readerPageTurn.restart()
    } else {
      readerPageCancel.restart()
    }
  }

  function turnReaderPage(targetPage) {
    if (!readerState.readerHasPages || readerState.readerTurning) return
    var nextPage = Math.max(0, Math.min(targetPage, readerState.readerPages.length - 1))
    if (nextPage === readerState.readerPageIndex) return
    if (root.reduceMotion) {
      readerState.readerPageIndex = nextPage
      readerState.readerTurning = false
      readerState.readerTurnAngle = 0
      readerState.readerTurnProgress = 0
      return
    }
    root.stopReaderTurnAnimations()
    readerState.readerDragWasActive = false
    readerState.readerTurnTargetPage = nextPage
    readerState.readerTurnDirection = nextPage > readerState.readerPageIndex ? 1 : -1
    readerState.readerTurnApproachDuration = 200
    readerState.readerTurnSettleDuration = 240
    readerState.readerTurning = true
    readerState.readerTurnAngle = 0
    readerState.readerTurnProgress = 0
    readerPageSwapTimer.restart()
    readerPageResetTimer.restart()
    readerPageTurn.restart()
  }

  function moveReaderPage(delta) {
    readerState.readerChromeIndex = -1
    var direction = delta > 0 ? 1 : -1
    var target = readerState.readerPageIndex + delta
    if (target < 0 || target >= readerState.readerPages.length) {
      root.advanceReaderChapter(direction)
    } else {
      root.turnReaderPage(target)
    }
    root.focusReaderKeyboard()
  }

  function syncReaderPageToVerse(index) {
    var page = readerState.readerPageForVerse(index)
    if (page >= 0 && page !== readerState.readerPageIndex) root.turnReaderPage(page)
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
    readerState.readerPaginated = state.readerPaginated !== false
    root.dailyOnOpen = state.dailyOnOpen !== false
    root.preferredVoice = state.preferredVoice === "system" ? "system" : "male"
    narration.narrationSpeed = [0.85, 1, 1.15].indexOf(Number(state.narrationSpeed)) >= 0 ? Number(state.narrationSpeed) : 1
    var scale = Number(state.narrationTimingScale || 1)
    narration.narrationTimingScale = Math.max(0.55, Math.min(1.9, isNaN(scale) ? 1 : scale))
    root.readerStateLoading = false
    root.readerStateReady = true
    root.readerStateHydrated = true
  }

  function saveReaderState() {
    if (!root.readerStateReady || root.readerStateLoading) return
    var position = root.readerSavedPosition
    if (readerState.readerHasPages && readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]) {
      position = {
        chapterLabel: readerState.readerChapterLabel,
        reference: readerState.readerChapterQueue[readerState.readerSelectedVerseIndex].reference,
        pageIndex: readerState.readerPageIndex,
        verseIndex: readerState.readerSelectedVerseIndex
      }
      root.readerSavedPosition = position
    }
    stateFile.setText(JSON.stringify({
      version: 1,
      position: position,
      bookmarks: root.modelRows(bookmarkModel, 30),
      recents: root.modelRows(recentModel, 12),
      reduceMotion: root.reduceMotion,
      readerPaginated: readerState.readerPaginated,
      dailyOnOpen: root.dailyOnOpen,
      preferredVoice: root.preferredVoice,
      narrationSpeed: narration.narrationSpeed,
      narrationTimingScale: narration.narrationTimingScale
    }, null, 2) + "\n")
  }

  function scheduleReaderStateSave() {
    if (root.readerStateReady && !root.readerStateLoading) readerStateSaveTimer.restart()
  }

  function currentReaderBookmarkIndex() {
    var row = readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]
    if (!row) return -1
    for (var i = 0; i < bookmarkModel.count; i++) {
      if (bookmarkModel.get(i).reference === row.reference) return i
    }
    return -1
  }

  function toggleCurrentBookmark() {
    var row = readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]
    if (!row) return
    var existing = root.currentReaderBookmarkIndex()
    if (existing >= 0) {
      bookmarkModel.remove(existing)
      readerState.readerActionFeedback = "Removed " + row.reference + " from Saved"
    } else {
      bookmarkModel.insert(0, {
      reference: row.reference, verse: row.verse, chapterLabel: readerState.readerChapterLabel,
      pageIndex: readerState.readerPageIndex, verseIndex: readerState.readerSelectedVerseIndex,
      savedAt: Date.now()
      })
      readerState.readerActionFeedback = "Saved " + row.reference
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
    readerState.readerActionFeedback = "Removed " + reference + " from Saved"
    root.scheduleReaderStateSave()
    readerActionFeedbackTimer.restart()
  }

  function recordRecent() {
    var row = readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]
    if (!row) return
    for (var i = recentModel.count - 1; i >= 0; i--) {
      if (recentModel.get(i).chapterLabel === readerState.readerChapterLabel) recentModel.remove(i)
    }
    recentModel.insert(0, {
      reference: row.reference, chapterLabel: readerState.readerChapterLabel,
      pageIndex: readerState.readerPageIndex, verseIndex: readerState.readerSelectedVerseIndex,
      openedAt: Date.now()
    })
    while (recentModel.count > 12) recentModel.remove(recentModel.count - 1)
    root.scheduleReaderStateSave()
  }

  function readReaderSelectedVerse() {
    if (!readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]) return
    var row = readerState.readerChapterQueue[readerState.readerSelectedVerseIndex]
    narration.requestNarration([{ reference: row.reference, verse: row.verse }], "verse")
  }

  function readReaderChapter() {
    if (readerState.readerChapterQueue.length === 0) return
    narration.requestNarration(readerState.readerChapterQueue, "chapter", readerState.readerSelectedVerseIndex)
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
    if (readerState.readerMode) root.focusReaderKeyboard()
    else {
      root.stopReaderTurnAnimations()
      readerState.readerDragging = false
      readerState.readerTurning = false
      readerState.readerTurnAngle = 0
      readerState.readerTurnProgress = 0
    }
  }
  onReaderLibraryOpenChanged: if (readerState.readerMode) root.focusReaderKeyboard()
  onReaderPageIndexChanged: {
    root.scheduleReaderStateSave()
    if (readerPageFlick) readerPageFlick.contentY = 0
  }
  onReaderSelectedVerseIndexChanged: root.scheduleReaderStateSave()
  onReduceMotionChanged: root.scheduleReaderStateSave()

  Timer {
    id: searchTimer
    interval: 120
    repeat: false
    onTriggered: root.runSearch()
  }

  SequentialAnimation {
    id: readerPageTurn
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerState.readerTurnAngle"
        to: 0
        duration: readerState.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: root
        property: "readerState.readerTurnProgress"
        to: 0.5
        duration: readerState.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
    }
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerState.readerTurnAngle"
        to: 0
        duration: readerState.readerTurnSettleDuration
        easing.type: Easing.InOutCubic
      }
      NumberAnimation {
        target: root
        property: "readerState.readerTurnProgress"
        to: 1
        duration: readerState.readerTurnSettleDuration
        easing.type: Easing.InOutCubic
      }
    }
  }

  SequentialAnimation {
    id: readerPageCancel
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "readerState.readerTurnAngle"
        to: 0
        duration: readerState.readerTurnCancelDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: root
        property: "readerState.readerTurnProgress"
        to: 0
        duration: readerState.readerTurnCancelDuration
        easing.type: Easing.OutCubic
      }
    }
    ScriptAction {
      script: {
        readerState.readerTurning = false
        readerState.readerDragWasActive = false
        readerState.readerTurnCrossesChapter = false
        readerState.readerTurnAngle = 0
        readerState.readerTurnProgress = 0
      }
    }
  }

  SequentialAnimation {
    id: readerFolioPulseAnimation
    NumberAnimation {
      target: root
      property: "readerState.readerFolioPulse"
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: root
      property: "readerState.readerFolioPulse"
      to: 0
      duration: 260
      easing.type: Easing.InOutCubic
    }
  }

  Component.onCompleted: {
    narration.detectTts()
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
    onTriggered: readerState.readerActionFeedback = ""
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
    interval: readerState.readerTurnApproachDuration
    repeat: false
    onTriggered: {
      if (!readerState.readerTurning) return
      readerState.readerPageIndex = readerState.readerTurnTargetPage
      readerState.readerTurnAngle = readerState.readerTurnDirection > 0 ? 86 : -86
    }
  }

  Timer {
    id: readerPageResetTimer
    interval: readerState.readerTurnApproachDuration + readerState.readerTurnSettleDuration
    repeat: false
    onTriggered: {
      readerState.readerTurning = false
      readerState.readerDragging = false
      readerState.readerDragWasActive = false
      readerState.readerTurnAngle = 0
      readerState.readerTurnProgress = 0
      readerState.readerTurnApproachDuration = 340
      readerState.readerTurnSettleDuration = 420
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
    id: chapterProc
    running: false
    stdout: StdioCollector {
      id: chapterOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.activeChapterRequest !== root.chapterRequestGeneration) return
      if (exitCode !== 0) {
        readerState.readerLoading = false
        narration.narrationStatus = "Could not load that chapter"
        narration.narrationMode = ""
        return
      }
      var queue = root.queueFromOutput(chapterOutput.text)
      if (queue.length === 0) {
        readerState.readerLoading = false
        narration.narrationStatus = "No verses found in that chapter"
        narration.narrationMode = ""
        return
      }
      var chapterLabel = readerState.readerChapterLabel
      readerState.setReaderChapter(queue, chapterLabel)
      var focusIndex = readerState.readerRestoreVerse
      if (focusIndex < 0 && readerState.readerPendingReference !== "") {
        for (var i = 0; i < queue.length; i++) {
          if (queue[i].reference === readerState.readerPendingReference) { focusIndex = i; break }
        }
      }
      readerState.readerSelectedVerseIndex = Math.max(0, Math.min(focusIndex < 0 ? 0 : focusIndex, queue.length - 1))
      var focusPage = readerState.readerPageForVerse(readerState.readerSelectedVerseIndex)
      if (readerState.readerRestorePage >= 0) focusPage = Math.min(readerState.readerRestorePage, readerState.readerPages.length - 1)
      readerState.readerPageIndex = Math.max(0, focusPage)
      readerState.readerPendingReference = ""
      readerState.readerRestorePage = -1
      readerState.readerRestoreVerse = -1
      readerState.readerLoading = false
      if (root.chapterLoadPurpose === "reader") {
        root.chapterLoadPurpose = ""
        narration.narrationMode = ""
        narration.narrationQueue = []
        narration.narrationStatus = queue.length + " verses · " + readerState.readerPages.length + " pages"
        root.recordRecent()
      } else {
        root.chapterLoadPurpose = ""
        narration.requestNarration(queue, "chapter")
      }
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
    contentWidth: popup.fittedContentWidth(Style.space(420))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus || readerBookFilterField.activeFocus
      onCloseRequested: {
        if (root.readerLibraryOpen) root.readerLibraryOpen = false
        else root.close()
      }
      onMoveRequested: function(dx, dy) {
        if (readerState.readerMode && root.readerLibraryOpen) {
          root.moveLibraryCursor(dx, dy)
        } else if (readerState.readerMode) {
          if (dx !== 0) root.moveReaderPage(dx > 0 ? 1 : -1)
          else if (dy !== 0) readerState.moveReaderVerse(dy)
        } else if (dy !== 0) {
          root.moveSelection(dy)
        }
      }
      onActivateRequested: {
        if (readerState.readerMode && root.readerLibraryOpen) root.activateLibraryCursor()
        else if (readerState.readerMode) root.activateReaderChrome()
        else root.activateSearchChrome()
      }
      onTabRequested: function(direction) {
        root.cyclePanelTab(direction)
      }
      onDeleteRequested: {
        if (readerState.readerMode && root.readerLibraryOpen && root.readerLibraryTab === "saved") {
          root.removeBookmarkAt(root.readerListCursor)
        }
      }
      onTextKey: function(text) {
        if (!readerState.readerMode) {
          if ((text === "o" || text === "O") && resultModel.count > 0) root.openReader(root.selectedIndex)
          else if (text === "r" || text === "R") root.readVerse(root.selectedIndex)
          else if (text === " ") narration.toggleNarrationPause()
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
        if (keyCatcher.blocked || !readerState.readerMode || root.readerLibraryOpen) return
        if (event.key === Qt.Key_PageDown) {
          root.moveReaderPage(1)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.moveReaderPage(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Home) {
          readerState.readerSelectedVerseIndex = 0
          if (readerState.readerPaginated) root.turnReaderPage(0)
          Qt.callLater(root.scrollReaderVerseIntoView)
          root.focusReaderKeyboard()
          event.accepted = true
        } else if (event.key === Qt.Key_End) {
          readerState.readerSelectedVerseIndex = Math.max(0, readerState.readerChapterQueue.length - 1)
          if (readerState.readerPaginated) root.turnReaderPage(readerState.readerPages.length - 1)
          Qt.callLater(root.scrollReaderVerseIntoView)
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
          spacing: Style.spacing.sm

        Item {
          id: header
          width: parent.width
          visible: false
          height: 0

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

        Column {
          id: settingsPanel
          width: parent.width
          visible: !readerState.readerMode && root.settingsOpen
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.md

          Item {
            width: parent.width
            height: Style.space(22)
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Settings"
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Done"
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsOpen = false
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs

            Text {
              text: "VOICE"
              color: root.popupForeground
              opacity: 0.55
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.4
            }

            Row {
              id: voiceRow
              width: parent.width
              spacing: Style.spacing.xs

              Repeater {
                model: [{ label: "Neural (male)", value: "male" }, { label: "System", value: "system" }]
                delegate: Rectangle {
                  required property var modelData
                  width: (voiceRow.width - voiceRow.spacing) / 2
                  height: Style.space(32)
                  radius: Style.cornerRadius
                  color: root.preferredVoice === modelData.value
                    ? Style.hoverFillFor(root.popupForeground, Color.accent)
                    : Style.normalFillFor(root.popupForeground, Color.accent)
                  border.width: 1
                  border.color: root.preferredVoice === modelData.value ? Color.accent : Color.popups.border

                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: root.preferredVoice === parent.modelData.value ? Color.accent : root.popupForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.preferredVoice = parent.modelData.value
                      narration.cleanupTopSpeech(); narration.preloadTopSpeech(); root.scheduleReaderStateSave()
                    }
                  }
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              Text {
                text: "READING SPEED"
                color: root.popupForeground
                opacity: 0.55
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.4
              }
              Item { width: Math.max(0, parent.width - speedCaption.implicitWidth - Style.space(90)); height: 1 }
              Text {
                id: speedCaption
                text: narration.narrationSpeed + "×"
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              id: speedRow
              width: parent.width
              spacing: Style.spacing.xs
              Repeater {
                model: [0.85, 1, 1.15]
                delegate: Rectangle {
                  required property real modelData
                  width: (speedRow.width - speedRow.spacing * 2) / 3
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: narration.narrationSpeed === modelData
                    ? Style.hoverFillFor(root.popupForeground, Color.accent)
                    : "transparent"
                  border.width: 1
                  border.color: narration.narrationSpeed === modelData ? Color.accent : Color.popups.border
                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData + "×"
                    color: narration.narrationSpeed === parent.modelData ? Color.accent : root.popupForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: narration.setNarrationSpeed(parent.modelData)
                  }
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs
            Text {
              text: "CHAPTER LAYOUT"
              color: root.popupForeground
              opacity: 0.55
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.4
            }
            Row {
              id: layoutRow
              width: parent.width
              spacing: Style.spacing.xs
              Repeater {
                model: [
                  { label: "Paginated", value: true },
                  { label: "Scroll chapter", value: false }
                ]
                delegate: Rectangle {
                  required property var modelData
                  width: (layoutRow.width - layoutRow.spacing) / 2
                  height: Style.space(32)
                  radius: Style.cornerRadius
                  color: readerState.readerPaginated === modelData.value
                    ? Style.hoverFillFor(root.popupForeground, Color.accent)
                    : Style.normalFillFor(root.popupForeground, Color.accent)
                  border.width: 1
                  border.color: readerState.readerPaginated === modelData.value ? Color.accent : Color.popups.border
                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: readerState.readerPaginated === parent.modelData.value ? Color.accent : root.popupForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: readerState.applyReaderLayout(parent.modelData.value)
                  }
                }
              }
            }
          }

          Row {
            width: parent.width
            height: Style.space(22)
            Text {
              text: "Daily verse on open"
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: Math.max(0, parent.width - Style.space(200) - dailySwitch.width); height: 1 }
            Rectangle {
              id: dailySwitch
              width: Style.space(34)
              height: Style.space(19)
              radius: height / 2
              anchors.verticalCenter: parent.verticalCenter
              color: root.dailyOnOpen ? Color.accent : Style.normalFillFor(root.popupForeground, Color.accent)
              Rectangle {
                width: Style.space(15); height: width; radius: width / 2
                y: Style.space(2)
                x: root.dailyOnOpen ? parent.width - width - Style.space(2) : Style.space(2)
                color: Color.popups.background
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.dailyOnOpen = !root.dailyOnOpen; root.scheduleReaderStateSave() }
              }
            }
          }

          Row {
            width: parent.width
            height: Style.space(22)
            Text {
              text: "REDUCED MOTION"
              color: root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: Math.max(0, parent.width - Style.space(200) - reduceSwitch.width); height: 1 }
            Rectangle {
              id: reduceSwitch
              width: Style.space(34)
              height: Style.space(19)
              radius: height / 2
              anchors.verticalCenter: parent.verticalCenter
              color: root.reduceMotion ? Color.accent : Style.normalFillFor(root.popupForeground, Color.accent)
              Rectangle {
                width: Style.space(15); height: width; radius: width / 2
                y: Style.space(2)
                x: root.reduceMotion ? parent.width - width - Style.space(2) : Style.space(2)
                color: Color.popups.background
              }
              MouseArea {
                id: reducedMotionMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.reduceMotion = !root.reduceMotion; root.scheduleReaderStateSave() }
              }
            }
          }
        }

        Item {
          id: readerView
          width: parent.width
          visible: readerState.readerMode
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
                color: root.chromeFill(root.readerChromeIs("search"), readerSearchMouse.containsMouse)
                border.width: root.readerChromeIs("search") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("search"))

                Text {
                  id: readerSearchLabel
                  anchors.centerIn: parent
                  text: "Search"
                  textFormat: Text.PlainText
                  color: root.readerChromeIs("search") ? Color.accent : root.popupForeground
                  font.bold: root.readerChromeIs("search")
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
                color: root.chromeFill(root.readerChromeIs("library") || root.readerLibraryOpen, readerLibraryMouse.containsMouse)
                border.width: root.readerChromeIs("library") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("library") || root.readerLibraryOpen)

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

            }

            Item {
              id: readerLibrary
              width: parent.width
              height: root.readerLibraryOpen ? Style.space(360) : 0
              visible: root.readerLibraryOpen
              clip: true

              Column {
                anchors.fill: parent
                spacing: Style.spacing.xs

                Row {
                  id: libraryTabRow
                  width: parent.width
                  height: Style.space(32)

                  Repeater {
                    model: [
                      { key: "books", label: "Books" },
                      { key: "saved", label: "Saved" },
                      { key: "recent", label: "Recent" }
                    ]
                    delegate: Item {
                      required property var modelData
                      width: libraryTabRow.width / 3
                      height: parent.height

                      Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: root.readerLibraryTab === parent.modelData.key ? root.popupForeground : root.popupForeground
                        opacity: root.readerLibraryTab === parent.modelData.key ? 1 : 0.5
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }

                      Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: root.readerLibraryTab === parent.modelData.key ? Color.accent : "transparent"
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setLibraryTab(parent.modelData.key)
                      }
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
                      placeholderText: "Filter books…"
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
                      width: Style.space(140)
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
                      GridView {
                        id: readerChapterGrid
                        width: parent.width
                        height: parent.height
                        clip: true
                        model: chapterPickerModel
                        cellWidth: Math.max(Style.space(32), Math.floor(width / 5))
                        cellHeight: cellWidth
                        delegate: Rectangle {
                          required property int chapterNumber
                          required property int index
                          width: readerChapterGrid.cellWidth - Style.space(6)
                          height: readerChapterGrid.cellHeight - Style.space(6)
                          radius: Style.space(5)
                          color: (root.readerLibraryFocus === "chapters" && root.readerChapterCursor === index)
                            ? Style.hoverFillFor(root.popupForeground, Color.accent)
                            : Style.normalFillFor(root.popupForeground, Color.accent)
                          border.width: 0
                          Text {
                            anchors.centerIn: parent
                            text: chapterNumber
                            color: (root.readerLibraryFocus === "chapters" && root.readerChapterCursor === index) ? Color.accent : root.popupForeground
                            opacity: (root.readerLibraryFocus === "chapters" && root.readerChapterCursor === index) ? 1 : 0.7
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
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

                Text {
                  width: parent.width
                  text: readerState.readerActionFeedback !== ""
                    ? readerState.readerActionFeedback
                    : root.catalogLoaded
                      ? (root.readerLibraryTab === "saved" ? "↑↓ select  ·  ENTER open  ·  X remove" : "↑↓ select  ·  ENTER open  ·  TAB sections")
                      : "Loading the offline library…"
                  color: readerState.readerActionFeedback !== "" ? Color.accent : root.popupForeground
                  opacity: readerState.readerActionFeedback !== "" ? 1 : 0.48
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: readerState.readerActionFeedback !== ""
                  wrapMode: Text.WordWrap
                }
              }
            }

            Item {
              id: readerMasthead
              visible: !root.readerLibraryOpen
              width: parent.width
              height: Style.space(40)

              Column {
                anchors.left: parent.left
                anchors.right: readerPageCount.left
                anchors.rightMargin: Style.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: readerState.readerChapterLabel
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.heading
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: readerState.readerLoading
                    ? "Opening chapter…"
                    : narration.narrationMode !== ""
                      ? "Reading along"
                      : "Click a verse to focus"
                  textFormat: Text.PlainText
                  color: root.popupForeground
                  opacity: 0.52
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: readerPageCount
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: !readerState.readerHasPages ? ""
                  : readerState.readerPaginated
                    ? (readerState.readerPageIndex + 1) + " / " + readerState.readerPages.length
                    : (readerState.readerSelectedVerseIndex + 1) + " / " + readerState.readerChapterQueue.length
                textFormat: Text.PlainText
                color: root.popupForeground
                opacity: 0.5
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: readerPageProgressTrack
              visible: !root.readerLibraryOpen && readerState.readerPaginated
              width: parent.width
              height: Style.space(2)
              radius: height / 2
              color: Style.normalFillFor(root.popupForeground, Color.accent)

              Rectangle {
                id: readerPageProgress
                width: readerState.readerHasPages
                  ? parent.width * ((readerState.readerPageIndex + 1) / readerState.readerPages.length)
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
              height: Style.space(300)
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
                opacity: readerState.readerTurning ? 0.12 : 0
              }

              Rectangle {
                id: readerSpineShadow
                x: readerState.readerTurnDirection > 0 ? 0 : parent.width - width
                y: 0
                z: 0
                width: Style.space(4)
                height: parent.height
                color: root.popupForeground
                opacity: readerState.readerTurning ? 0.06 * Math.sin(Math.PI * readerState.readerTurnProgress) : 0
              }

              Item {
                id: readerIncomingPage
                x: 0
                y: readerPageContent.y
                width: readerPageContent.width
                height: Math.max(readerPageContent.height, incomingPageColumn.implicitHeight)
                z: 1
                visible: readerState.readerTurning && readerState.readerTurnPage !== null
                opacity: visible ? Math.min(1, readerState.readerTurnProgress * 1.4) : 0
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
                    model: readerState.readerTurnPage ? readerState.readerTurnPage.verses : []

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
                    text: readerState.readerTurnPage
                      ? readerState.readerChapterLabel + "  ·  " + (readerState.readerTurnTargetPage + 1) : ""
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
                y: Style.spacing.sm
                width: parent.width - (Style.spacing.sm * 2)
                height: parent.height - Style.spacing.sm * 2
                z: 2
                opacity: readerState.readerTurning ? Math.max(0.2, 1 - readerState.readerTurnProgress) : 1
                x: readerState.readerTurning
                  ? (readerState.readerTurnDirection > 0 ? -1 : 1) * readerState.readerTurnProgress * Style.space(36)
                  : 0
                clip: true

                Flickable {
                  id: readerPageFlick
                  anchors.fill: parent
                  clip: true
                  contentWidth: width
                  contentHeight: readerPageColumn.implicitHeight
                  boundsBehavior: Flickable.StopAtBounds
                  flickableDirection: Flickable.VerticalFlick

                Column {
                  id: readerPageColumn
                  width: readerPageFlick.width
                  spacing: Style.spacing.sm

                  Text {
                    width: parent.width
                    visible: readerState.readerLoading
                    text: "Opening this chapter…"
                    textFormat: Text.PlainText
                    color: root.popupForeground
                    opacity: 0.62
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Repeater {
                    model: readerState.currentReaderPage ? readerState.currentReaderPage.verses : []

                    delegate: Item {
                      required property var modelData
                      required property int index
                      readonly property int absoluteIndex: readerState.currentReaderPage
                        ? readerState.currentReaderPage.start + index
                        : -1
                      readonly property bool focused: absoluteIndex === readerState.readerFocusVerseIndex
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
                        width: parent.focused ? Style.space(2) : 0
                        color: Color.accent
                        opacity: parent.focused ? 1 : 0
                      }

                      Column {
                        id: verseColumn
                        x: Style.spacing.sm
                        y: Style.spacing.xs
                        width: parent.width - (Style.spacing.sm * 2)
                        spacing: Style.spacing.xs

                        Text {
                          width: parent.width
                          visible: false
                          height: 0
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
                          visible: parent.parent.focused && narration.narrationMode !== "" && narration.narrationWords.length > 0
                          spacing: Style.spacing.xs
                          height: childrenRect.height

                          Repeater {
                            model: readerWordFlow.visible ? narration.narrationWords : []

                            delegate: Rectangle {
                              required property string modelData
                              required property int index
                              width: readerWordLabel.implicitWidth + Style.space(6)
                              height: readerWordLabel.implicitHeight + Style.space(4)
                              radius: Style.space(2)
                              color: index === narration.narrationWordIndex ? Color.accent : "transparent"

                              Text {
                                id: readerWordLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                textFormat: Text.PlainText
                                color: index === narration.narrationWordIndex ? Color.popups.background : root.popupForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: index === narration.narrationWordIndex
                              }
                            }
                          }
                        }

                        Text {
                          width: parent.width
                          visible: !readerWordFlow.visible
                          text: {
                            var ref = String(modelData.reference || "")
                            var colon = ref.lastIndexOf(":")
                            var n = colon >= 0 ? ref.substring(colon + 1) : ""
                            return n + "  " + modelData.verse
                          }
                          textFormat: Text.PlainText
                          color: root.popupForeground
                          opacity: parent.parent.focused ? 1 : 0.82
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.body
                          wrapMode: Text.WordWrap
                          lineHeight: 1.65
                          lineHeightMode: Text.ProportionalHeight
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        z: 2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          readerState.readerSelectedVerseIndex = absoluteIndex
                        }
                      }

                    }
                  }

                }
                }
              }

              Shape {
                id: readerBackCornerFold
                visible: false
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Style.space(22)
                height: Style.space(22)
                z: 3
                opacity: readerBackCornerMouse.containsMouse || (readerState.readerDragging && readerState.readerTurnDirection < 0) ? 1 : 0.35
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
                  enabled: readerState.canMoveReader(-1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { root.beginReaderCornerDrag(-1, mouse.x) }
                  onPositionChanged: function(mouse) { root.updateReaderCornerDrag(mouse.x) }
                  onReleased: root.finishReaderCornerDrag()
                  onClicked: {
                    if (!readerState.readerDragWasActive) root.moveReaderPage(-1)
                  }
                }

                PanelToolTip {
                  visible: readerBackCornerMouse.containsMouse && !readerState.readerDragging
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
                visible: false
                opacity: readerCornerMouse.containsMouse || (readerState.readerDragging && readerState.readerTurnDirection > 0) ? 1 : 0.35
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
                  enabled: readerState.canMoveReader(1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { root.beginReaderCornerDrag(1, mouse.x) }
                  onPositionChanged: function(mouse) { root.updateReaderCornerDrag(mouse.x) }
                  onReleased: root.finishReaderCornerDrag()
                  onClicked: {
                    if (!readerState.readerDragWasActive) root.moveReaderPage(1)
                  }
                }

                PanelToolTip {
                  visible: readerCornerMouse.containsMouse && !readerState.readerDragging
                  text: "Drag to turn to the next page"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }
            }

            Column {
              id: readerNavColumn
              visible: !root.readerLibraryOpen
              width: parent.width
              spacing: Style.spacing.xs

            Row {
              id: readerNavRow
              width: parent.width
              spacing: Style.spacing.xs
              readonly property real actionWidth: (width - spacing) / 2

              Rectangle {
                id: readerPreviousButton
                enabled: readerState.canMoveReader(-1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: root.chromeFill(root.readerChromeIs("prev"), readerPreviousMouse.containsMouse)
                border.width: root.readerChromeIs("prev") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("prev"))

                Text {
                  id: readerPreviousLabel
                  anchors.centerIn: parent
                  text: "Prev"
                  textFormat: Text.PlainText
                  color: root.readerChromeIs("prev") ? Color.accent : root.popupForeground
                  font.bold: root.readerChromeIs("prev")
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
                enabled: readerState.canMoveReader(1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: root.chromeFill(root.readerChromeIs("next"), readerNextMouse.containsMouse)
                border.width: root.readerChromeIs("next") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("next"))

                Text {
                  id: readerNextLabel
                  anchors.centerIn: parent
                  text: "Next"
                  textFormat: Text.PlainText
                  color: root.readerChromeIs("next") ? Color.accent : root.popupForeground
                  font.bold: root.readerChromeIs("next")
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
            }

            Row {
              id: readerActionRow
              width: parent.width
              spacing: Style.spacing.xs
              readonly property int actionCount: 3 + (root.narrationActive ? 1 : 0)
              readonly property real actionWidth: (width - spacing * (actionCount - 1)) / actionCount

              Rectangle {
                id: readerReadVerseButton
                enabled: readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: root.chromeFill(root.readerChromeIs("read"), readerReadVerseMouse.containsMouse)
                border.width: root.readerChromeIs("read") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("read"))

                Text {
                  id: readerReadVerseLabel
                  anchors.centerIn: parent
                  text: "Read"
                  textFormat: Text.PlainText
                  color: root.readerChromeIs("read") ? Color.accent : root.popupForeground
                  font.bold: root.readerChromeIs("read")
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
                enabled: readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: root.chromeFill(root.readerChromeIs("from"), readerReadChapterMouse.containsMouse)
                border.width: root.readerChromeIs("from") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("from"))

                Text {
                  id: readerReadChapterLabel
                  anchors.centerIn: parent
                  width: parent.width - Style.space(6)
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  text: readerState.readerSelectedVerseIndex > 0 ? "From here" : "Chapter"
                  textFormat: Text.PlainText
                  color: root.readerChromeIs("from") ? Color.accent : root.popupForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.readerChromeIs("from")
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
                enabled: readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: root.chromeFill(root.readerChromeIs("save"), readerBookmarkMouse.containsMouse)
                border.width: root.readerChromeIs("save") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("save") || root.currentReaderBookmarkIndex() >= 0)
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
                width: visible ? readerActionRow.actionWidth : 0
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.chromeFill(root.readerChromeIs("stop"), readerStopMouse.containsMouse)
                border.width: root.readerChromeIs("stop") ? 2 : 1
                border.color: root.chromeBorder(root.readerChromeIs("stop"))

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
                  onClicked: narration.stopNarration()
                }
              }
            }
            }

            Text {
              visible: !root.readerLibraryOpen
              width: parent.width
              text: readerState.readerPaginated
                ? "↑↓ verse  ·  ← → page  ·  Tab buttons  ·  Enter"
                : "↑↓ verse  ·  ← → chapter  ·  Tab buttons  ·  Enter"
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
              visible: !root.readerLibraryOpen && readerState.readerActionFeedback !== ""
              width: parent.width
              text: readerState.readerActionFeedback
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
          visible: narration.ttsChecked && !root.ttsAvailable
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
                onClicked: narration.installVoiceEngine()
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
                onClicked: narration.detectTts()
              }
            }
          }
        }

        TextField {
          id: searchField
          width: parent.width
          visible: !readerState.readerMode && !root.settingsOpen
          height: visible ? implicitHeight : 0
          placeholderText: "john 3:16"
          foreground: root.popupForeground
          accent: Color.accent
          rightPadding: Style.space(36)
          text: root.query
          onTextChanged: {
            if (root.query !== text) root.query = text
            if (text.trim() !== "") root.dailyView = false
            root.scheduleSearch()
          }
          onAccepted: {
            root.activateSelected()
          }
          Keys.onEscapePressed: {
            if (root.query !== "") {
              searchField.text = ""
              event.accepted = true
            } else {
              root.close()
            }
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) {
              root.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.moveSelection(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              root.moveSelection(5)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              root.moveSelection(-5)
              event.accepted = true
            }
          }
          Keys.onTabPressed: {
            event.accepted = true
            root.cycleSearchChrome(1)
          }
          Keys.onBacktabPressed: {
            event.accepted = true
            root.cycleSearchChrome(-1)
          }

          PanelActionButton {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: "Settings"
            foreground: root.popupForeground
            hoverColor: Color.accent
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            focusable: true
            hasCursor: root.settingsOpen
            onClicked: root.settingsOpen = !root.settingsOpen
          }
        }

        Flow {
          id: quickSearchesPlaceholder
          width: parent.width
          visible: false
          height: 0
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
          visible: false
          height: 0
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
          visible: !readerState.readerMode && !root.settingsOpen && (root.query.trim() !== "" || root.dailyView)
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
          visible: !readerState.readerMode && !root.settingsOpen && resultModel.count > 0
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
            color: root.chromeFill(root.searchChromeIs("read"), readVerseMouse.containsMouse)
            border.width: root.searchChromeIs("read") ? 2 : 1
            border.color: root.chromeBorder(root.searchChromeIs("read"))

            Text {
              id: readVerseLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: root.selectedIndex === 0 && narration.topSpeechProc.running ? "Preparing…"
                : root.selectedIndex === 0 && root.topSpeechReady ? "Read"
                : "Read"
              textFormat: Text.PlainText
              color: root.searchChromeIs("read") ? Color.accent : root.popupForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: root.searchChromeIs("read")
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
            color: root.chromeFill(root.searchChromeIs("book"), openBookMouse.containsMouse)
            border.width: root.searchChromeIs("book") ? 2 : 1
            border.color: root.chromeBorder(root.searchChromeIs("book"))

            Text {
              id: openBookLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Open book"
              textFormat: Text.PlainText
              color: root.searchChromeIs("book") ? Color.accent : root.popupForeground
              font.bold: root.searchChromeIs("book")
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
            color: root.chromeFill(root.searchChromeIs("chapter"), readChapterMouse.containsMouse)
            border.width: root.searchChromeIs("chapter") ? 2 : 1
            border.color: root.chromeBorder(root.searchChromeIs("chapter"))

            Text {
              id: readChapterLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Read chapter"
              textFormat: Text.PlainText
              color: root.searchChromeIs("chapter") ? Color.accent : root.popupForeground
              font.bold: root.searchChromeIs("chapter")
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
            color: root.chromeFill(root.searchChromeIs("stop"), stopNarrationMouse.containsMouse)
            border.width: root.searchChromeIs("stop") ? 2 : 1
            border.color: root.chromeBorder(root.searchChromeIs("stop"))

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
              onClicked: narration.stopNarration()
            }
          }
        }

        Text {
          id: narrationStatusLabel
          width: parent.width
          visible: !readerState.readerMode && narration.narrationStatus !== "" && !root.readAlongVisible
          height: visible ? implicitHeight : 0
          text: narration.narrationStatus
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
          visible: !readerState.readerMode && root.readAlongVisible
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
                text: narration.narrationStatus
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
              visible: narration.narrationRowAt(-1) !== null
              text: narration.narrationRowAt(-1) === null
                ? ""
                : narration.narrationRowAt(-1).reference + "  " + narration.narrationRowAt(-1).verse
              textFormat: Text.PlainText
              color: root.popupForeground
              opacity: 0.38
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: narration.narrationRowAt(0) === null ? "" : narration.narrationRowAt(0).reference
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
                model: narration.narrationWords

                delegate: Rectangle {
                  required property string modelData
                  required property int index
                  width: wordLabel.implicitWidth + Style.space(6)
                  height: wordLabel.implicitHeight + Style.space(4)
                  radius: Style.space(2)
                  color: index === narration.narrationWordIndex && narration.narrationMode !== ""
                    ? Color.accent
                    : "transparent"

                  Text {
                    id: wordLabel
                    anchors.centerIn: parent
                    text: parent.modelData
                    textFormat: Text.PlainText
                    color: index === narration.narrationWordIndex && narration.narrationMode !== ""
                      ? Color.popups.background
                      : root.popupForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: index === narration.narrationWordIndex && narration.narrationMode !== ""
                  }
                }
              }
            }

            Text {
              width: parent.width
              visible: narration.narrationRowAt(1) !== null
              text: narration.narrationRowAt(1) === null
                ? ""
                : narration.narrationRowAt(1).reference + "  " + narration.narrationRowAt(1).verse
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
                enabled: narration.narrationMode !== "" && narration.narrationIndex > 0
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
                  onClicked: narration.skipNarration(-1)
                }
              }

              Rectangle {
                id: nextReadButton
                enabled: narration.narrationMode !== "" && narration.narrationIndex < narration.narrationQueue.length - 1
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
                  onClicked: narration.skipNarration(1)
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
                  onClicked: narration.stopNarration()
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
          visible: !readerState.readerMode && !root.settingsOpen && (root.query.trim() !== "" || root.dailyView)
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
                  height: visible ? Math.max(Style.space(40), resultCardContent.implicitHeight + Style.space(16)) : 0

                  Rectangle {
                    anchors.fill: parent
                    color: root.selectedIndex === index
                      ? Style.hoverFillFor(root.popupForeground, Color.accent)
                      : "transparent"
                  }

                  MouseArea {
                    id: resultCopyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: root.copyResult(index)
                    onDoubleClicked: root.openReader(index)
                  }

                  Row {
                    id: resultCardContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.spacing.sm
                    anchors.rightMargin: Style.spacing.sm
                    spacing: Style.spacing.sm

                    Text {
                      id: referenceLabel
                      width: Style.space(78)
                      text: reference
                      textFormat: Text.PlainText
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      wrapMode: Text.WordWrap
                    }

                    Text {
                      id: verseText
                      width: Math.max(0, parent.width - referenceLabel.width - parent.spacing)
                      text: verse
                      textFormat: Text.PlainText
                      color: root.popupForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      wrapMode: Text.WordWrap
                      lineHeight: 1.5
                      lineHeightMode: Text.ProportionalHeight
                    }
                  }
                }
              }
            }
          }
        }

        Flow {
          id: searchChips
          width: parent.width
          visible: !readerState.readerMode && !root.settingsOpen
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.xs
          topPadding: Style.spacing.xs

          Rectangle {
            readonly property bool chipOn: root.dailyView || root.searchChromeIs("daily")
            width: dailyFooterLabel.implicitWidth + Style.space(20)
            height: Style.space(24)
            radius: height / 2
            color: root.chromeFill(chipOn, dailyFooterMouse.containsMouse)
            border.width: chipOn ? 2 : 1
            border.color: root.chromeBorder(chipOn)

            Text {
              id: dailyFooterLabel
              anchors.centerIn: parent
              text: "daily"
              textFormat: Text.PlainText
              color: parent.chipOn ? Color.accent : root.popupForeground
              opacity: parent.chipOn ? 1 : 0.8
              font.bold: parent.chipOn
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: dailyFooterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showDailyVerse()
            }
          }

          Repeater {
            model: root.topicSuggestions
            delegate: Rectangle {
              required property string modelData
              required property int index
              readonly property bool chipOn: root.searchChromeIs("topic:" + index)
                || root.query.trim().toLowerCase() === String(modelData).toLowerCase()
              width: topicChipLabel.implicitWidth + Style.space(20)
              height: Style.space(24)
              radius: height / 2
              color: root.chromeFill(chipOn, topicChipMouse.containsMouse)
              border.width: chipOn ? 2 : 1
              border.color: root.chromeBorder(chipOn)

              Text {
                id: topicChipLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: parent.chipOn ? Color.accent : root.popupForeground
                opacity: parent.chipOn ? 1 : 0.75
                font.bold: parent.chipOn
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: topicChipMouse
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
        }
      }
    }
  }
}

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
  property alias resultModel: resultModel
  property alias bookDisplayModel: bookDisplayModel
  property alias chapterPickerModel: chapterPickerModel
  property alias bookmarkModel: bookmarkModel
  property alias recentModel: recentModel
  property alias keyCatcher: keyCatcher
  property alias dailyProc: dailyProc
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
        searchViewInstance.searchField.forceActiveFocus()
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
    Qt.callLater(function() { searchViewInstance.searchField.forceActiveFocus() })
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
    searchViewInstance.resultList.contentY = Math.max(0, Math.min(
      searchViewInstance.resultList.contentHeight - searchViewInstance.resultList.height,
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
    if (!readerViewInstance.readerPageFlick || readerState.readerChapterQueue.length === 0) return
    var n = readerState.readerChapterQueue.length
    var span = Math.max(0, readerViewInstance.readerPageFlick.contentHeight - readerViewInstance.readerPageFlick.height)
    readerViewInstance.readerPageFlick.contentY = span * (readerState.readerSelectedVerseIndex / Math.max(1, n - 1))
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
      searchViewInstance.searchField.forceActiveFocus()
      root.searchChromeIndex = -1
      return
    }
    if (searchViewInstance.searchField.activeFocus) {
      searchViewInstance.searchField.focus = false
      keyCatcher.forceActiveFocus()
      root.searchChromeIndex = direction > 0 ? 0 : items.length - 1
      return
    }
    var next = root.searchChromeIndex + direction
    if (next < 0 || next >= items.length) {
      root.searchChromeIndex = -1
      searchViewInstance.searchField.forceActiveFocus()
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
        searchViewInstance.searchField.text = topic
        searchViewInstance.searchField.forceActiveFocus()
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
        readerViewInstance.readerLibrary.bookList.positionViewAtIndex(root.readerBookCursor, ListView.Contain)
      } else if (root.readerLibraryFocus === "chapters" && chapterPickerModel.count > 0) {
        var columns = Math.max(1, Math.floor(readerViewInstance.readerLibrary.chapterGrid.width / readerViewInstance.readerLibrary.chapterGrid.cellWidth))
        var delta = dx !== 0 ? dx : dy * columns
        root.readerChapterCursor = Math.max(0, Math.min(chapterPickerModel.count - 1, root.readerChapterCursor + delta))
        readerViewInstance.readerLibrary.chapterGrid.positionViewAtIndex(root.readerChapterCursor, GridView.Contain)
      }
    } else {
      var model = root.readerLibraryTab === "saved" ? bookmarkModel : recentModel
      if (dy !== 0 && model.count > 0) {
        root.readerListCursor = Math.max(0, Math.min(model.count - 1, root.readerListCursor + dy))
        readerViewInstance.readerLibrary.storedList.positionViewAtIndex(root.readerListCursor, ListView.Contain)
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
    var travel = Math.max(1, readerViewInstance.readerPageSurface.width * 0.42)
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
  onReaderLibraryOpenChanged: if (readerState.readerMode) root.focusReaderKeyboard()
  onReduceMotionChanged: root.scheduleReaderStateSave()

  // readerMode, readerPageIndex, and readerSelectedVerseIndex now live on
  // readerState (ReaderState.qml), not on root, so their auto-generated
  // onXChanged signals fire on readerState, not on root — a plain
  // onReaderModeChanged: handler here would be (and briefly was) invalid.
  Connections {
    target: readerState
    function onReaderModeChanged() {
      if (readerState.readerMode) root.focusReaderKeyboard()
      else {
        root.stopReaderTurnAnimations()
        readerState.readerDragging = false
        readerState.readerTurning = false
        readerState.readerTurnAngle = 0
        readerState.readerTurnProgress = 0
      }
    }
    function onReaderPageIndexChanged() {
      root.scheduleReaderStateSave()
      if (readerViewInstance.readerPageFlick) readerViewInstance.readerPageFlick.contentY = 0
    }
    function onReaderSelectedVerseIndexChanged() {
      root.scheduleReaderStateSave()
    }
  }

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
        target: readerState
        property: "readerTurnAngle"
        to: 0
        duration: readerState.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: readerState
        property: "readerTurnProgress"
        to: 0.5
        duration: readerState.readerTurnApproachDuration
        easing.type: Easing.OutCubic
      }
    }
    ParallelAnimation {
      NumberAnimation {
        target: readerState
        property: "readerTurnAngle"
        to: 0
        duration: readerState.readerTurnSettleDuration
        easing.type: Easing.InOutCubic
      }
      NumberAnimation {
        target: readerState
        property: "readerTurnProgress"
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
        target: readerState
        property: "readerTurnAngle"
        to: 0
        duration: readerState.readerTurnCancelDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: readerState
        property: "readerTurnProgress"
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
      target: readerState
      property: "readerFolioPulse"
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: readerState
      property: "readerFolioPulse"
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
      blocked: searchViewInstance.searchField.activeFocus || readerViewInstance.readerLibrary.bookFilterField.activeFocus
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
        else if (text === "/" && root.readerLibraryOpen && root.readerLibraryTab === "books") readerViewInstance.readerLibrary.bookFilterField.forceActiveFocus()
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

        SettingsView {
          id: settingsPanel
          panel: root
          narration: root.narration
          readerState: root.readerState
        }

        ReaderView {
          id: readerViewInstance
          panel: root
        }
        SearchView {
          id: searchViewInstance
          panel: root
        }
        }
      }
    }
  }
}

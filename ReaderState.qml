import QtQuick

QtObject {
  id: state

  // Back-reference to the owning Panel (root). Anything this state object
  // needs that it doesn't own itself — adjacentChapter(), wordsFor(),
  // scheduleReaderStateSave(), scrollReaderVerseIntoView(),
  // syncReaderPageToVerse(), advanceReaderChapter(), focusReaderKeyboard()
  // — goes through panel.*. Most of the reader's page-turn/drag animation
  // logic stays in root (it drives visual-tree ids like readerPageTurn/
  // readerPageCancel that live in Panel.qml's markup and haven't been
  // extracted yet), so this object holds reader *data*, not the full
  // reader controller.
  property var panel: null

  property bool readerMode: false
  property bool readerLoading: false
  property string readerChapterLabel: ""
  property var readerChapterQueue: []
  property var readerPages: []
  property int readerPageIndex: 0
  property int readerSelectedVerseIndex: 0
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
  property string readerPendingReference: ""
  property int readerRestorePage: -1
  property int readerRestoreVerse: -1
  property bool readerPaginated: true
  property int readerChromeIndex: -1
  property string readerActionFeedback: ""

  readonly property bool readerHasPages: state.readerPages.length > 0
  readonly property var currentReaderPage: state.readerHasPages
    ? state.readerPages[Math.max(0, Math.min(state.readerPageIndex, state.readerPages.length - 1))]
    : null
  readonly property var readerTurnPage: state.readerHasPages
    && state.readerTurnTargetPage >= 0
    && state.readerTurnTargetPage < state.readerPages.length
    ? state.readerPages[state.readerTurnTargetPage]
    : null
  readonly property int readerFocusVerseIndex: state.readerSelectedVerseIndex

  function canMoveReader(direction) {
    if (!state.readerHasPages) return false
    var target = state.readerPageIndex + direction
    if (target >= 0 && target < state.readerPages.length) return true
    return panel.adjacentChapter(direction) !== null
  }

  function buildReaderPages(queue) {
    var pages = []
    var start = 0
    var wordCount = 0
    var wordsPerPage = 95

    for (var i = 0; i < queue.length; i++) {
      var verseWords = panel.wordsFor(queue[i].verse).length
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
    for (var i = 0; i < state.readerPages.length; i++) {
      if (index >= state.readerPages[i].start && index <= state.readerPages[i].end) return i
    }
    return -1
  }

  function setReaderChapter(queue, label) {
    state.readerChapterQueue = queue
    state.readerPages = state.readerPaginated
      ? state.buildReaderPages(queue)
      : (queue.length ? [{ start: 0, end: queue.length - 1, verses: queue }] : [])
    state.readerChapterLabel = label
    state.readerPageIndex = 0
    state.readerSelectedVerseIndex = 0
  }

  function applyReaderLayout(paginated) {
    var verse = state.readerSelectedVerseIndex
    var label = state.readerChapterLabel
    var queue = state.readerChapterQueue
    state.readerPaginated = paginated
    if (queue && queue.length > 0) {
      state.setReaderChapter(queue, label)
      state.readerSelectedVerseIndex = Math.max(0, Math.min(verse, queue.length - 1))
      var page = state.readerPageForVerse(state.readerSelectedVerseIndex)
      state.readerPageIndex = Math.max(0, page)
      Qt.callLater(panel.scrollReaderVerseIntoView)
    }
    panel.scheduleReaderStateSave()
  }

  function moveReaderVerse(delta) {
    state.readerChromeIndex = -1
    var n = state.readerChapterQueue.length
    if (n === 0 || state.readerLoading) return
    var next = state.readerSelectedVerseIndex + delta
    if (next < 0) {
      panel.advanceReaderChapter(-1)
      return
    }
    if (next >= n) {
      panel.advanceReaderChapter(1)
      return
    }
    state.readerSelectedVerseIndex = next
    if (state.readerPaginated) panel.syncReaderPageToVerse(next)
    Qt.callLater(panel.scrollReaderVerseIntoView)
    panel.focusReaderKeyboard()
  }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: readerView
  property var panel: null

  // Exposed so root's page-turn/drag animation functions (which stay in
  // root -- they drive readerPageTurn/readerPageCancel/
  // readerPageSwapTimer/readerPageResetTimer, top-level Panel children
  // that reference visual state here) and moveLibraryCursor/
  // activateLibraryCursor/the keyCatcher focus-routing binding (which
  // reach into the nested LibraryView) can still get at these by id
  // from outside this file.
  property alias readerLibrary: readerLibrary
  property alias readerPageFlick: readerPageFlick
  property alias readerPageSurface: readerPageSurface

  width: parent.width
  visible: panel.readerState.readerMode
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
                color: panel.chromeFill(panel.readerChromeIs("search"), readerSearchMouse.containsMouse)
                border.width: panel.readerChromeIs("search") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("search"))

                Text {
                  id: readerSearchLabel
                  anchors.centerIn: parent
                  text: "Search"
                  textFormat: Text.PlainText
                  color: panel.readerChromeIs("search") ? Color.accent : panel.popupForeground
                  font.bold: panel.readerChromeIs("search")
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerSearchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.showSearch()
                }
              }

              Rectangle {
                id: readerLibraryButton
                width: Style.space(72)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: panel.chromeFill(panel.readerChromeIs("library") || panel.readerLibraryOpen, readerLibraryMouse.containsMouse)
                border.width: panel.readerChromeIs("library") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("library") || panel.readerLibraryOpen)

                Text {
                  id: readerLibraryLabel
                  anchors.centerIn: parent
                  text: "Library"
                  textFormat: Text.PlainText
                  color: panel.readerLibraryOpen ? Color.accent : panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerLibraryMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    panel.readerLibraryOpen = !panel.readerLibraryOpen
                    panel.focusReaderKeyboard()
                  }
                }
              }

            }

            LibraryView {
              id: readerLibrary
              panel: readerView.panel
            }

            Item {
              id: readerMasthead
              visible: !panel.readerLibraryOpen
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
                  text: panel.readerState.readerChapterLabel
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.heading
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: panel.readerState.readerLoading
                    ? "Opening chapter…"
                    : panel.narration.narrationMode !== ""
                      ? "Reading along"
                      : "Click a verse to focus"
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  opacity: 0.52
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: readerPageCount
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: !panel.readerState.readerHasPages ? ""
                  : panel.readerState.readerPaginated
                    ? (panel.readerState.readerPageIndex + 1) + " / " + panel.readerState.readerPages.length
                    : (panel.readerState.readerSelectedVerseIndex + 1) + " / " + panel.readerState.readerChapterQueue.length
                textFormat: Text.PlainText
                color: panel.popupForeground
                opacity: 0.5
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: readerPageProgressTrack
              visible: !panel.readerLibraryOpen && panel.readerState.readerPaginated
              width: parent.width
              height: Style.space(2)
              radius: height / 2
              color: Style.normalFillFor(panel.popupForeground, Color.accent)

              Rectangle {
                id: readerPageProgress
                width: panel.readerState.readerHasPages
                  ? parent.width * ((panel.readerState.readerPageIndex + 1) / panel.readerState.readerPages.length)
                  : 0
                height: parent.height
                radius: height / 2
                color: Color.accent

                Behavior on width {
                  enabled: !panel.reduceMotion
                  NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                }
              }
            }

            BorderSurface {
              id: readerPageSurface
              visible: !panel.readerLibraryOpen
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
                color: Style.normalFillFor(panel.popupForeground, Color.accent)
                borderSpec: Border.flat(Style.normalBorderFor(panel.popupForeground, Color.accent), 1)
                radius: Style.space(2)
              }

              Rectangle {
                id: readerPageBackdrop
                anchors.fill: parent
                z: 0
                color: Style.hoverFillFor(panel.popupForeground, Color.accent)
                opacity: panel.readerState.readerTurning ? 0.12 : 0
              }

              Rectangle {
                id: readerSpineShadow
                x: panel.readerState.readerTurnDirection > 0 ? 0 : parent.width - width
                y: 0
                z: 0
                width: Style.space(4)
                height: parent.height
                color: panel.popupForeground
                opacity: panel.readerState.readerTurning ? 0.06 * Math.sin(Math.PI * panel.readerState.readerTurnProgress) : 0
              }

              Item {
                id: readerIncomingPage
                x: 0
                y: readerPageContent.y
                width: readerPageContent.width
                height: Math.max(readerPageContent.height, incomingPageColumn.implicitHeight)
                z: 1
                visible: panel.readerState.readerTurning && panel.readerState.readerTurnPage !== null
                opacity: visible ? Math.min(1, panel.readerState.readerTurnProgress * 1.4) : 0
                clip: true

                BorderSurface {
                  anchors.fill: parent
                  radius: Style.space(2)
                  color: Style.normalFillFor(panel.popupForeground, Color.accent)
                  borderSpec: Border.flat(Style.normalBorderFor(panel.popupForeground, Color.accent), 1)
                }

                Column {
                  id: incomingPageColumn
                  x: Style.spacing.xs
                  y: Style.spacing.xs
                  width: parent.width - Style.spacing.xs * 2
                  spacing: Style.spacing.sm

                  Repeater {
                    model: panel.readerState.readerTurnPage ? panel.readerState.readerTurnPage.verses : []

                    delegate: Column {
                      required property var modelData
                      width: incomingPageColumn.width
                      spacing: Style.spacing.xs

                      Text {
                        width: parent.width
                        text: modelData.reference
                        textFormat: Text.PlainText
                        color: panel.popupForeground
                        opacity: 0.58
                        font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        width: parent.width
                        text: modelData.verse
                        textFormat: Text.PlainText
                        color: panel.popupForeground
                        opacity: 0.68
                        font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        wrapMode: Text.WordWrap
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    text: panel.readerState.readerTurnPage
                      ? panel.readerState.readerChapterLabel + "  ·  " + (panel.readerState.readerTurnTargetPage + 1) : ""
                    textFormat: Text.PlainText
                    color: panel.popupForeground
                    opacity: 0.46
                    font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
                opacity: panel.readerState.readerTurning ? Math.max(0.2, 1 - panel.readerState.readerTurnProgress) : 1
                x: panel.readerState.readerTurning
                  ? (panel.readerState.readerTurnDirection > 0 ? -1 : 1) * panel.readerState.readerTurnProgress * Style.space(36)
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
                    visible: panel.readerState.readerLoading
                    text: "Opening this chapter…"
                    textFormat: Text.PlainText
                    color: panel.popupForeground
                    opacity: 0.62
                    font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Repeater {
                    model: panel.readerState.currentReaderPage ? panel.readerState.currentReaderPage.verses : []

                    delegate: Item {
                      required property var modelData
                      required property int index
                      readonly property int absoluteIndex: panel.readerState.currentReaderPage
                        ? panel.readerState.currentReaderPage.start + index
                        : -1
                      readonly property bool focused: absoluteIndex === panel.readerState.readerFocusVerseIndex
                      width: readerPageColumn.width
                      height: verseColumn.implicitHeight + Style.space(10)

                      BorderSurface {
                        anchors.fill: parent
                        radius: Style.space(3)
                        color: parent.focused
                          ? Style.focusFillFor(panel.popupForeground, Color.accent)
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
                          color: parent.parent.focused ? Color.accent : panel.popupForeground
                          opacity: parent.parent.focused ? 1 : 0.58
                          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: parent.parent.focused
                        }

                        Flow {
                          id: readerWordFlow
                          width: parent.width
                          visible: parent.parent.focused && panel.narration.narrationMode !== "" && panel.narration.narrationWords.length > 0
                          spacing: Style.spacing.xs
                          height: childrenRect.height

                          Repeater {
                            model: readerWordFlow.visible ? panel.narration.narrationWords : []

                            delegate: Rectangle {
                              required property string modelData
                              required property int index
                              width: readerWordLabel.implicitWidth + Style.space(6)
                              height: readerWordLabel.implicitHeight + Style.space(4)
                              radius: Style.space(2)
                              color: index === panel.narration.narrationWordIndex ? Color.accent : "transparent"

                              Text {
                                id: readerWordLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                textFormat: Text.PlainText
                                color: index === panel.narration.narrationWordIndex ? Color.popups.background : panel.popupForeground
                                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: index === panel.narration.narrationWordIndex
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
                          color: panel.popupForeground
                          opacity: parent.parent.focused ? 1 : 0.82
                          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
                          panel.readerState.readerSelectedVerseIndex = absoluteIndex
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
                opacity: readerBackCornerMouse.containsMouse || (panel.readerState.readerDragging && panel.readerState.readerTurnDirection < 0) ? 1 : 0.35
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                  fillColor: Style.normalFillFor(panel.popupForeground, Color.accent)
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
                  color: panel.popupForeground
                  opacity: 0.7
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerBackCornerMouse
                  anchors.fill: parent
                  enabled: panel.readerState.canMoveReader(-1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { panel.beginReaderCornerDrag(-1, mouse.x) }
                  onPositionChanged: function(mouse) { panel.updateReaderCornerDrag(mouse.x) }
                  onReleased: panel.finishReaderCornerDrag()
                  onClicked: {
                    if (!panel.readerState.readerDragWasActive) panel.moveReaderPage(-1)
                  }
                }

                PanelToolTip {
                  visible: readerBackCornerMouse.containsMouse && !panel.readerState.readerDragging
                  text: "Drag to turn to the previous page"
                  fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
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
                opacity: readerCornerMouse.containsMouse || (panel.readerState.readerDragging && panel.readerState.readerTurnDirection > 0) ? 1 : 0.35
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                  fillColor: Style.normalFillFor(panel.popupForeground, Color.accent)
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
                  color: panel.popupForeground
                  opacity: 0.7
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerCornerMouse
                  anchors.fill: parent
                  enabled: panel.readerState.canMoveReader(1)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) { panel.beginReaderCornerDrag(1, mouse.x) }
                  onPositionChanged: function(mouse) { panel.updateReaderCornerDrag(mouse.x) }
                  onReleased: panel.finishReaderCornerDrag()
                  onClicked: {
                    if (!panel.readerState.readerDragWasActive) panel.moveReaderPage(1)
                  }
                }

                PanelToolTip {
                  visible: readerCornerMouse.containsMouse && !panel.readerState.readerDragging
                  text: "Drag to turn to the next page"
                  fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
                }
              }
            }

            Column {
              id: readerNavColumn
              visible: !panel.readerLibraryOpen
              width: parent.width
              spacing: Style.spacing.xs

            Row {
              id: readerNavRow
              width: parent.width
              spacing: Style.spacing.xs
              readonly property real actionWidth: (width - spacing) / 2

              Rectangle {
                id: readerPreviousButton
                enabled: panel.readerState.canMoveReader(-1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: panel.chromeFill(panel.readerChromeIs("prev"), readerPreviousMouse.containsMouse)
                border.width: panel.readerChromeIs("prev") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("prev"))

                Text {
                  id: readerPreviousLabel
                  anchors.centerIn: parent
                  text: "Prev"
                  textFormat: Text.PlainText
                  color: panel.readerChromeIs("prev") ? Color.accent : panel.popupForeground
                  font.bold: panel.readerChromeIs("prev")
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerPreviousMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.moveReaderPage(-1)
                }
              }

              Rectangle {
                id: readerNextButton
                enabled: panel.readerState.canMoveReader(1)
                width: readerNavRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: panel.chromeFill(panel.readerChromeIs("next"), readerNextMouse.containsMouse)
                border.width: panel.readerChromeIs("next") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("next"))

                Text {
                  id: readerNextLabel
                  anchors.centerIn: parent
                  text: "Next"
                  textFormat: Text.PlainText
                  color: panel.readerChromeIs("next") ? Color.accent : panel.popupForeground
                  font.bold: panel.readerChromeIs("next")
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerNextMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.moveReaderPage(1)
                }
              }
            }

            Row {
              id: readerActionRow
              width: parent.width
              spacing: Style.spacing.xs
              readonly property int actionCount: 3 + (panel.narrationActive ? 1 : 0)
              readonly property real actionWidth: (width - spacing * (actionCount - 1)) / actionCount

              Rectangle {
                id: readerReadVerseButton
                enabled: panel.readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: panel.chromeFill(panel.readerChromeIs("read"), readerReadVerseMouse.containsMouse)
                border.width: panel.readerChromeIs("read") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("read"))

                Text {
                  id: readerReadVerseLabel
                  anchors.centerIn: parent
                  text: "Read"
                  textFormat: Text.PlainText
                  color: panel.readerChromeIs("read") ? Color.accent : panel.popupForeground
                  font.bold: panel.readerChromeIs("read")
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerReadVerseMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.readReaderSelectedVerse()
                }
              }

              Rectangle {
                id: readerReadChapterButton
                enabled: panel.readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: panel.chromeFill(panel.readerChromeIs("from"), readerReadChapterMouse.containsMouse)
                border.width: panel.readerChromeIs("from") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("from"))

                Text {
                  id: readerReadChapterLabel
                  anchors.centerIn: parent
                  width: parent.width - Style.space(6)
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  text: panel.readerState.readerSelectedVerseIndex > 0 ? "From here" : "Chapter"
                  textFormat: Text.PlainText
                  color: panel.readerChromeIs("from") ? Color.accent : panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: panel.readerChromeIs("from")
                }

                MouseArea {
                  id: readerReadChapterMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.readReaderChapter()
                }
              }

              Rectangle {
                id: readerBookmarkButton
                enabled: panel.readerState.readerHasPages
                width: readerActionRow.actionWidth
                height: Style.space(28)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: panel.chromeFill(panel.readerChromeIs("save"), readerBookmarkMouse.containsMouse)
                border.width: panel.readerChromeIs("save") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("save") || panel.currentReaderBookmarkIndex() >= 0)
                Text {
                  id: readerBookmarkLabel
                  anchors.centerIn: parent
                  text: panel.currentReaderBookmarkIndex() >= 0 ? "Saved" : "Save"
                  color: panel.currentReaderBookmarkIndex() >= 0 ? Color.accent : panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: readerBookmarkMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.toggleCurrentBookmark()
                }
                PanelToolTip {
                  visible: readerBookmarkMouse.containsMouse
                  text: panel.currentReaderBookmarkIndex() >= 0 ? "Remove focused verse from Saved" : "Save focused verse"
                  fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
                }
              }

              Rectangle {
                id: readerStopButton
                visible: panel.narrationActive
                width: visible ? readerActionRow.actionWidth : 0
                height: Style.space(28)
                radius: Style.cornerRadius
                color: panel.chromeFill(panel.readerChromeIs("stop"), readerStopMouse.containsMouse)
                border.width: panel.readerChromeIs("stop") ? 2 : 1
                border.color: panel.chromeBorder(panel.readerChromeIs("stop"))

                Text {
                  id: readerStopLabel
                  anchors.centerIn: parent
                  text: "Stop"
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: readerStopMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.narration.stopNarration()
                }
              }
            }
            }

            Text {
              visible: !panel.readerLibraryOpen
              width: parent.width
              text: panel.readerState.readerPaginated
                ? "↑↓ verse  ·  ← → page  ·  Tab buttons  ·  Enter"
                : "↑↓ verse  ·  ← → chapter  ·  Tab buttons  ·  Enter"
              textFormat: Text.PlainText
              id: readerKeyboardHint
              color: panel.popupForeground
              opacity: 0.44
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              visible: panel.readerLibraryOpen
              width: parent.width
              text: "↑↓ select · Enter open · Tab switches sections · B closes Library"
              textFormat: Text.PlainText
              color: panel.popupForeground
              opacity: 0.44
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              visible: !panel.readerLibraryOpen && panel.readerState.readerActionFeedback !== ""
              width: parent.width
              text: panel.readerState.readerActionFeedback
              textFormat: Text.PlainText
              color: Color.accent
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }
          }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "dev.alexandre.bible-search"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string query: ""
  property string statusText: "Search by word, phrase, or reference."
  property int selectedIndex: 0

  readonly property string scriptPath: {
    var path = String(Qt.resolvedUrl("bin/omarchy-bible-search"))
    if (path.indexOf("file://") === 0) path = path.substring(7)
    return decodeURIComponent(path)
  }

  function open() {
    root.controller.show()
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function scheduleSearch() {
    root.selectedIndex = 0
    searchTimer.restart()
  }

  function runSearch() {
    resultModel.clear()
    if (root.query.trim() === "") {
      root.statusText = "Search by word, phrase, or reference."
      return
    }
    root.statusText = "Searching…"
    searchProc.command = [root.scriptPath, "search", root.query]
    searchProc.running = true
  }

  function parseSearchOutput(raw) {
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
    if (found > 0) root.statusText = found + " result" + (found === 1 ? "" : "s") + " · click to copy"
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

  function copyResult(index) {
    if (index < 0 || index >= resultModel.count) return
    var row = resultModel.get(index)
    var text = row.reference + " — " + row.verse
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
    root.close()
  }

  ListModel { id: resultModel }

  Timer {
    id: searchTimer
    interval: 120
    repeat: false
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    running: false
    stdout: StdioCollector {
      id: searchOutput
      waitForEnd: true
    }
    onExited: function() {
      if (root.opened) root.parseSearchOutput(searchOutput.text)
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
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveSelection(dy) }
      onActivateRequested: root.activateSelected()

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.md

        Item {
          id: header
          width: parent.width
          height: Style.space(46)

          BorderSurface {
            id: iconBadge
            width: Style.space(42)
            height: Style.space(42)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Style.hoverFillFor(root.barForeground, Color.accent)
            borderSpec: Border.flat(Color.accent, 1)
            radius: Style.cornerRadius

            Text {
              anchors.centerIn: parent
              text: "󰂿"
              textFormat: Text.PlainText
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
            }
          }

          Column {
            anchors.left: iconBadge.right
            anchors.leftMargin: Style.spacing.sm
            anchors.right: closeHint.left
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Text {
              id: headerTitle
              text: "Bible Search"
              textFormat: Text.PlainText
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              text: "Search by word, phrase, or reference"
              textFormat: Text.PlainText
              color: root.barForeground
              opacity: 0.62
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            id: closeHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "ESC"
            textFormat: Text.PlainText
            color: root.barForeground
            opacity: 0.62
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
        }

        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Search the Bible…"
          foreground: root.barForeground
          accent: Color.accent
          rightPadding: Style.space(54)
          text: root.query
          onTextChanged: {
            if (root.query !== text) root.query = text
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
            color: root.barForeground
            opacity: 0.48
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 0.8
          }
        }

        Row {
          id: quickSearches
          width: parent.width
          visible: root.query.trim() === "" && resultModel.count === 0
          spacing: Style.spacing.xs

          Repeater {
            model: ["love", "faith", "peace", "wisdom"]

            delegate: Rectangle {
              required property string modelData
              width: chipLabel.implicitWidth + Style.space(20)
              height: Style.space(28)
              radius: height / 2
              color: chipMouse.containsMouse
                ? Style.hoverFillFor(root.barForeground, Color.accent)
                : "transparent"
              border.width: 1
              border.color: Color.popups.border

              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: root.barForeground
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
          visible: root.query.trim() === "" && resultModel.count === 0
          text: "Try a theme, phrase, or verse reference. Click a result to copy it."
          textFormat: Text.PlainText
          color: root.barForeground
          opacity: 0.58
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          id: statusRow
          width: parent.width
          visible: root.query.trim() !== ""
          spacing: Style.spacing.sm

          Text {
            id: statusLabel
            width: Math.min(Style.space(260), implicitWidth)
            text: root.statusText
            textFormat: Text.PlainText
            color: root.barForeground
            opacity: 0.64
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Item {
            width: Math.max(0, parent.width - statusLabel.width - keyboardHint.implicitWidth - Style.spacing.sm)
            height: 1
          }

          Text {
            id: keyboardHint
            text: resultModel.count > 0 ? "↑ ↓  navigate · ENTER  copy" : ""
            textFormat: Text.PlainText
            color: root.barForeground
            opacity: 0.46
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Flickable {
          id: resultList
          width: parent.width
          visible: root.query.trim() !== ""
          height: Math.min(Style.space(320), Math.max(Style.space(96), resultStack.implicitHeight))
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
                text: root.statusText.indexOf("Searching") === 0 ? "Searching the Bible…" : "No matching verses"
                textFormat: Text.PlainText
                color: root.barForeground
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
                  height: Math.max(Style.space(82), verseText.implicitHeight + Style.space(40))

                  BorderSurface {
                    anchors.fill: parent
                    radius: Style.cornerRadius
                    color: root.selectedIndex === index
                      ? Style.hoverFillFor(root.barForeground, Color.accent)
                      : "transparent"
                    borderSpec: root.selectedIndex === index
                      ? Border.controlSpec("hover-cursor", root.barForeground, Color.accent)
                      : Border.flat(Color.popups.border, 1)
                  }

                  Column {
                    anchors.fill: parent
                    anchors.margins: Style.spacing.sm
                    spacing: Style.spacing.xs

                    Row {
                      width: parent.width

                      Text {
                        id: referenceLabel
                        text: reference
                        textFormat: Text.PlainText
                        color: root.barForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }

                      Item {
                        width: Math.max(0, parent.width - referenceLabel.implicitWidth - copyHint.implicitWidth - Style.spacing.sm)
                        height: 1
                      }

                      Text {
                        id: copyHint
                        text: "COPY"
                        textFormat: Text.PlainText
                        color: root.barForeground
                        opacity: 0.46
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 0.8
                      }
                    }

                    Text {
                      id: verseText
                      width: parent.width
                      text: verse
                      textFormat: Text.PlainText
                      color: root.barForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      wrapMode: Text.WordWrap
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: root.copyResult(index)
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

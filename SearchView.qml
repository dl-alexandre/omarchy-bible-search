import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: searchView
  property var panel: null

  // Exposed so root's keyboard-routing and focus functions
  // (showSearch/open/close, activateSelected, the keyCatcher blocked:
  // binding) can still reach these by id from outside this file.
  property alias searchField: searchField
  property alias resultList: resultList

  width: parent.width
  spacing: Style.spacing.sm

        BorderSurface {
          id: voiceSetupCard
          width: parent.width
          visible: panel.narration.ttsChecked && !panel.ttsAvailable
          height: visible ? voiceSetupRow.implicitHeight + Style.spacing.sm * 2 : 0
          radius: Style.cornerRadius
          color: Style.normalFillFor(panel.popupForeground, Color.accent)
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
                color: panel.popupForeground
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                width: parent.width
                text: "Install espeak-ng once; Bible text and speech remain offline."
                textFormat: Text.PlainText
                color: panel.popupForeground
                opacity: 0.52
                elide: Text.ElideRight
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              id: voiceInstallButton
              width: voiceInstallLabel.implicitWidth + Style.space(18)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: voiceInstallMouse.containsMouse ? Style.hoverFillFor(panel.popupForeground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.accent
              Text {
                id: voiceInstallLabel
                anchors.centerIn: parent
                text: "INSTALL"
                color: Color.accent
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              MouseArea {
                id: voiceInstallMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.narration.installVoiceEngine()
              }
              PanelToolTip {
                visible: voiceInstallMouse.containsMouse
                text: "Open Omarchy’s package installer in a terminal"
                fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
              }
            }

            Rectangle {
              id: voiceCheckButton
              width: voiceCheckLabel.implicitWidth + Style.space(18)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: voiceCheckMouse.containsMouse ? Style.hoverFillFor(panel.popupForeground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.popups.border
              Text {
                id: voiceCheckLabel
                anchors.centerIn: parent
                text: "CHECK AGAIN"
                color: panel.popupForeground
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                id: voiceCheckMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.narration.detectTts()
              }
            }
          }
        }

        TextField {
          id: searchField
          width: parent.width
          visible: !panel.readerState.readerMode && !panel.settingsOpen
          height: visible ? implicitHeight : 0
          placeholderText: "john 3:16"
          foreground: panel.popupForeground
          accent: Color.accent
          rightPadding: Style.space(36)
          text: panel.query
          onTextChanged: {
            if (panel.query !== text) panel.query = text
            if (text.trim() !== "") panel.dailyView = false
            panel.scheduleSearch()
          }
          onAccepted: {
            panel.activateSelected()
          }
          Keys.onEscapePressed: {
            if (panel.query !== "") {
              searchField.text = ""
              event.accepted = true
            } else {
              panel.close()
            }
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) {
              panel.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              panel.moveSelection(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              panel.moveSelection(5)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              panel.moveSelection(-5)
              event.accepted = true
            }
          }
          Keys.onTabPressed: {
            event.accepted = true
            panel.cycleSearchChrome(1)
          }
          Keys.onBacktabPressed: {
            event.accepted = true
            panel.cycleSearchChrome(-1)
          }

          PanelActionButton {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: "Settings"
            foreground: panel.popupForeground
            hoverColor: Color.accent
            fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
            focusable: true
            hasCursor: panel.settingsOpen
            onClicked: panel.settingsOpen = !panel.settingsOpen
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
              ? Style.hoverFillFor(panel.popupForeground, Color.accent)
              : "transparent"
            border.width: 1
            border.color: Color.accent
            opacity: panel.dailyProc.running ? 0.6 : 1

            Text {
              id: dailyChipLabel
              anchors.centerIn: parent
              text: panel.dailyProc.running ? "…" : "Daily"
              textFormat: Text.PlainText
              color: Color.accent
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: dailyChipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !panel.dailyProc.running
              onClicked: panel.showDailyVerse()
            }
          }

          Repeater {
            model: panel.topicSuggestions

            delegate: Rectangle {
              required property string modelData
              width: chipLabel.implicitWidth + Style.space(20)
              height: Style.space(28)
              radius: height / 2
              color: chipMouse.containsMouse
                ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                : "transparent"
              border.width: 1
              border.color: Color.popups.border

              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: panel.popupForeground
                opacity: 0.8
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
          color: panel.popupForeground
          opacity: 0.58
          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          id: statusLabel
          width: parent.width
          visible: !panel.readerState.readerMode && !panel.settingsOpen && (panel.query.trim() !== "" || panel.dailyView)
          height: visible ? implicitHeight : 0
          text: panel.copyFeedback !== "" ? panel.copyFeedback : panel.statusText
          textFormat: Text.PlainText
          color: panel.copyFailed ? Color.urgent : panel.copyFeedback !== "" ? Color.accent : panel.popupForeground
          opacity: 0.64
          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          id: narrationActions
          width: parent.width
          visible: !panel.readerState.readerMode && !panel.settingsOpen && panel.resultModel.count > 0
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.xs
          readonly property int actionCount: 3 + (panel.narrationActive ? 1 : 0)
          readonly property real actionWidth: actionCount > 0
            ? (width - spacing * (actionCount - 1)) / actionCount
            : width

          Rectangle {
            id: readVerseButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: panel.chromeFill(panel.searchChromeIs("read"), readVerseMouse.containsMouse)
            border.width: panel.searchChromeIs("read") ? 2 : 1
            border.color: panel.chromeBorder(panel.searchChromeIs("read"))

            Text {
              id: readVerseLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: panel.selectedIndex === 0 && panel.narration.topSpeechProc.running ? "Preparing…"
                : panel.selectedIndex === 0 && panel.topSpeechReady ? "Read"
                : "Read"
              textFormat: Text.PlainText
              color: panel.searchChromeIs("read") ? Color.accent : panel.popupForeground
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: panel.searchChromeIs("read")
            }

            MouseArea {
              id: readVerseMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.readVerse(panel.selectedIndex)
            }
          }

          Rectangle {
            id: openBookButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: panel.chromeFill(panel.searchChromeIs("book"), openBookMouse.containsMouse)
            border.width: panel.searchChromeIs("book") ? 2 : 1
            border.color: panel.chromeBorder(panel.searchChromeIs("book"))

            Text {
              id: openBookLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Open book"
              textFormat: Text.PlainText
              color: panel.searchChromeIs("book") ? Color.accent : panel.popupForeground
              font.bold: panel.searchChromeIs("book")
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: openBookMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.openReader(panel.selectedIndex)
            }
          }

          Rectangle {
            id: readChapterButton
            width: narrationActions.actionWidth
            height: Style.space(32)
            radius: Style.cornerRadius
            color: panel.chromeFill(panel.searchChromeIs("chapter"), readChapterMouse.containsMouse)
            border.width: panel.searchChromeIs("chapter") ? 2 : 1
            border.color: panel.chromeBorder(panel.searchChromeIs("chapter"))

            Text {
              id: readChapterLabel
              anchors.centerIn: parent
              width: parent.width - Style.space(8)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: "Read chapter"
              textFormat: Text.PlainText
              color: panel.searchChromeIs("chapter") ? Color.accent : panel.popupForeground
              font.bold: panel.searchChromeIs("chapter")
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: readChapterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.readChapter(panel.selectedIndex)
            }
          }

          Rectangle {
            id: stopNarrationButton
            visible: panel.narrationActive
            width: visible ? narrationActions.actionWidth : 0
            height: Style.space(32)
            radius: Style.cornerRadius
            color: panel.chromeFill(panel.searchChromeIs("stop"), stopNarrationMouse.containsMouse)
            border.width: panel.searchChromeIs("stop") ? 2 : 1
            border.color: panel.chromeBorder(panel.searchChromeIs("stop"))

            Text {
              id: stopNarrationLabel
              anchors.centerIn: parent
              text: "Stop"
              textFormat: Text.PlainText
              color: panel.popupForeground
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: stopNarrationMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.narration.stopNarration()
            }
          }
        }

        Text {
          id: narrationStatusLabel
          width: parent.width
          visible: !panel.readerState.readerMode && panel.narration.narrationStatus !== "" && !panel.readAlongVisible
          height: visible ? implicitHeight : 0
          text: panel.narration.narrationStatus
          textFormat: Text.PlainText
          color: panel.ttsAvailable ? panel.popupForeground : Color.urgent
          opacity: 0.64
          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Item {
          id: readAlongCard
          width: parent.width
          visible: !panel.readerState.readerMode && panel.readAlongVisible
          height: visible ? readAlongColumn.implicitHeight + (Style.spacing.sm * 2) : 0

          BorderSurface {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Style.hoverFillFor(panel.popupForeground, Color.accent)
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
                color: panel.popupForeground
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Item {
                width: Math.max(0, parent.width - readAlongState.implicitWidth - Style.spacing.xs)
                height: 1
              }

              Text {
                id: readAlongState
                text: panel.narration.narrationStatus
                textFormat: Text.PlainText
                color: panel.popupForeground
                opacity: 0.66
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(3)
              radius: height / 2
              color: Style.hoverFillFor(panel.popupForeground, Color.accent)

              Rectangle {
                width: parent.width * panel.narrationProgress
                height: parent.height
                radius: height / 2
                color: Color.accent
              }
            }

            Text {
              width: parent.width
              visible: panel.narration.narrationRowAt(-1) !== null
              text: panel.narration.narrationRowAt(-1) === null
                ? ""
                : panel.narration.narrationRowAt(-1).reference + "  " + panel.narration.narrationRowAt(-1).verse
              textFormat: Text.PlainText
              color: panel.popupForeground
              opacity: 0.38
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: panel.narration.narrationRowAt(0) === null ? "" : panel.narration.narrationRowAt(0).reference
              textFormat: Text.PlainText
              color: Color.accent
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Flow {
              id: currentWordFlow
              width: parent.width
              spacing: Style.spacing.xs
              height: childrenRect.height

              Repeater {
                model: panel.narration.narrationWords

                delegate: Rectangle {
                  required property string modelData
                  required property int index
                  width: wordLabel.implicitWidth + Style.space(6)
                  height: wordLabel.implicitHeight + Style.space(4)
                  radius: Style.space(2)
                  color: index === panel.narration.narrationWordIndex && panel.narration.narrationMode !== ""
                    ? Color.accent
                    : "transparent"

                  Text {
                    id: wordLabel
                    anchors.centerIn: parent
                    text: parent.modelData
                    textFormat: Text.PlainText
                    color: index === panel.narration.narrationWordIndex && panel.narration.narrationMode !== ""
                      ? Color.popups.background
                      : panel.popupForeground
                    font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: index === panel.narration.narrationWordIndex && panel.narration.narrationMode !== ""
                  }
                }
              }
            }

            Text {
              width: parent.width
              visible: panel.narration.narrationRowAt(1) !== null
              text: panel.narration.narrationRowAt(1) === null
                ? ""
                : panel.narration.narrationRowAt(1).reference + "  " + panel.narration.narrationRowAt(1).verse
              textFormat: Text.PlainText
              color: panel.popupForeground
              opacity: 0.38
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Rectangle {
                id: previousReadButton
                enabled: panel.narration.narrationMode !== "" && panel.narration.narrationIndex > 0
                width: previousReadLabel.implicitWidth + Style.space(20)
                height: Style.space(26)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: previousReadMouse.containsMouse
                  ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: previousReadLabel
                  anchors.centerIn: parent
                  text: "PREV"
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: previousReadMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.narration.skipNarration(-1)
                }
              }

              Rectangle {
                id: nextReadButton
                enabled: panel.narration.narrationMode !== "" && panel.narration.narrationIndex < panel.narration.narrationQueue.length - 1
                width: nextReadLabel.implicitWidth + Style.space(20)
                height: Style.space(26)
                radius: Style.cornerRadius
                opacity: enabled ? 1 : 0.36
                color: nextReadMouse.containsMouse
                  ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: nextReadLabel
                  anchors.centerIn: parent
                  text: "NEXT"
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: nextReadMouse
                  anchors.fill: parent
                  enabled: parent.enabled
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.narration.skipNarration(1)
                }
              }

              Item {
                width: Math.max(0, parent.width - previousReadButton.width - nextReadButton.width - stopReadButton.width - (parent.spacing * 2))
                height: 1
              }

              Rectangle {
                id: stopReadButton
                visible: panel.narrationActive
                width: visible ? stopReadLabel.implicitWidth + Style.space(20) : 0
                height: Style.space(26)
                radius: Style.cornerRadius
                color: stopReadMouse.containsMouse
                  ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                  : "transparent"
                border.width: 1
                border.color: Color.popups.border

                Text {
                  id: stopReadLabel
                  anchors.centerIn: parent
                  text: "STOP"
                  textFormat: Text.PlainText
                  color: panel.popupForeground
                  font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }

                MouseArea {
                  id: stopReadMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.narration.stopNarration()
                }
              }
            }

            Text {
              width: parent.width
              text: "Word timing is estimated for local speech."
              textFormat: Text.PlainText
              color: panel.popupForeground
              opacity: 0.42
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Flickable {
          id: resultList
          width: parent.width
          visible: !panel.readerState.readerMode && !panel.settingsOpen && (panel.query.trim() !== "" || panel.dailyView)
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
              visible: panel.resultModel.count === 0
              width: resultStack.width
              height: Style.space(96)

              Text {
                anchors.centerIn: parent
                text: panel.dailyProc.running ? "Choosing today’s verse…"
                  : panel.statusText.indexOf("Searching") === 0 ? "Searching the Bible…"
                  : panel.statusText.indexOf("Could not") === 0 || panel.statusText.indexOf("unavailable") >= 0
                    ? panel.statusText : "No matching verses"
                textFormat: Text.PlainText
                color: panel.popupForeground
                opacity: 0.62
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            Column {
              id: resultColumn
              width: resultStack.width
              spacing: Style.spacing.xs
              visible: panel.resultModel.count > 0

              Repeater {
                model: panel.resultModel
                delegate: Item {
                  required property int index
                  required property string reference
                  required property string verse

                  width: resultColumn.width
                  visible: !(index === 0 && panel.readAlongDuplicatesTop)
                  height: visible ? Math.max(Style.space(40), resultCardContent.implicitHeight + Style.space(16)) : 0

                  Rectangle {
                    anchors.fill: parent
                    color: panel.selectedIndex === index
                      ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                      : "transparent"
                  }

                  MouseArea {
                    id: resultCopyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: panel.selectedIndex = index
                    onClicked: panel.copyResult(index)
                    onDoubleClicked: panel.openReader(index)
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
                      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      wrapMode: Text.WordWrap
                    }

                    Text {
                      id: verseText
                      width: Math.max(0, parent.width - referenceLabel.width - parent.spacing)
                      text: verse
                      textFormat: Text.PlainText
                      color: panel.popupForeground
                      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
          visible: !panel.readerState.readerMode && !panel.settingsOpen
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.xs
          topPadding: Style.spacing.xs

          Rectangle {
            readonly property bool chipOn: panel.dailyView || panel.searchChromeIs("daily")
            width: dailyFooterLabel.implicitWidth + Style.space(20)
            height: Style.space(24)
            radius: height / 2
            color: panel.chromeFill(chipOn, dailyFooterMouse.containsMouse)
            border.width: chipOn ? 2 : 1
            border.color: panel.chromeBorder(chipOn)

            Text {
              id: dailyFooterLabel
              anchors.centerIn: parent
              text: "daily"
              textFormat: Text.PlainText
              color: parent.chipOn ? Color.accent : panel.popupForeground
              opacity: parent.chipOn ? 1 : 0.8
              font.bold: parent.chipOn
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: dailyFooterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.showDailyVerse()
            }
          }

          Repeater {
            model: panel.topicSuggestions
            delegate: Rectangle {
              required property string modelData
              required property int index
              readonly property bool chipOn: panel.searchChromeIs("topic:" + index)
                || panel.query.trim().toLowerCase() === String(modelData).toLowerCase()
              width: topicChipLabel.implicitWidth + Style.space(20)
              height: Style.space(24)
              radius: height / 2
              color: panel.chromeFill(chipOn, topicChipMouse.containsMouse)
              border.width: chipOn ? 2 : 1
              border.color: panel.chromeBorder(chipOn)

              Text {
                id: topicChipLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: parent.chipOn ? Color.accent : panel.popupForeground
                opacity: parent.chipOn ? 1 : 0.75
                font.bold: parent.chipOn
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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

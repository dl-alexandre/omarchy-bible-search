import QtQuick
import qs.Commons

Column {
  id: settingsView
  property var panel: null
  property var narration: null
  property var readerState: null

  width: parent.width
  visible: !readerState.readerMode && panel.settingsOpen
  height: visible ? implicitHeight : 0
  spacing: Style.spacing.md

  Item {
    width: parent.width
    height: Style.space(22)
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "Settings"
      color: panel.popupForeground
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "Done"
      color: Color.accent
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(6)
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.settingsOpen = false
      }
    }
  }

  Column {
    width: parent.width
    spacing: Style.spacing.xs

    Text {
      text: "VOICE"
      color: panel.popupForeground
      opacity: 0.55
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
          color: panel.preferredVoice === modelData.value
            ? Style.hoverFillFor(panel.popupForeground, Color.accent)
            : Style.normalFillFor(panel.popupForeground, Color.accent)
          border.width: 1
          border.color: panel.preferredVoice === modelData.value ? Color.accent : Color.popups.border

          Text {
            anchors.centerIn: parent
            text: parent.modelData.label
            color: panel.preferredVoice === parent.modelData.value ? Color.accent : panel.popupForeground
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              panel.preferredVoice = parent.modelData.value
              narration.cleanupTopSpeech(); narration.preloadTopSpeech(); panel.scheduleReaderStateSave()
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
        color: panel.popupForeground
        opacity: 0.55
        font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.4
      }
      Item { width: Math.max(0, parent.width - speedCaption.implicitWidth - Style.space(90)); height: 1 }
      Text {
        id: speedCaption
        text: narration.narrationSpeed + "×"
        color: Color.accent
        font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
            ? Style.hoverFillFor(panel.popupForeground, Color.accent)
            : "transparent"
          border.width: 1
          border.color: narration.narrationSpeed === modelData ? Color.accent : Color.popups.border
          Text {
            anchors.centerIn: parent
            text: parent.modelData + "×"
            color: narration.narrationSpeed === parent.modelData ? Color.accent : panel.popupForeground
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
      color: panel.popupForeground
      opacity: 0.55
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
            ? Style.hoverFillFor(panel.popupForeground, Color.accent)
            : Style.normalFillFor(panel.popupForeground, Color.accent)
          border.width: 1
          border.color: readerState.readerPaginated === modelData.value ? Color.accent : Color.popups.border
          Text {
            anchors.centerIn: parent
            text: parent.modelData.label
            color: readerState.readerPaginated === parent.modelData.value ? Color.accent : panel.popupForeground
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
      color: panel.popupForeground
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
      color: panel.dailyOnOpen ? Color.accent : Style.normalFillFor(panel.popupForeground, Color.accent)
      Rectangle {
        width: Style.space(15); height: width; radius: width / 2
        y: Style.space(2)
        x: panel.dailyOnOpen ? parent.width - width - Style.space(2) : Style.space(2)
        color: Color.popups.background
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { panel.dailyOnOpen = !panel.dailyOnOpen; panel.scheduleReaderStateSave() }
      }
    }
  }

  Row {
    width: parent.width
    height: Style.space(22)
    Text {
      text: "REDUCED MOTION"
      color: panel.popupForeground
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
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
      color: panel.reduceMotion ? Color.accent : Style.normalFillFor(panel.popupForeground, Color.accent)
      Rectangle {
        width: Style.space(15); height: width; radius: width / 2
        y: Style.space(2)
        x: panel.reduceMotion ? parent.width - width - Style.space(2) : Style.space(2)
        color: Color.popups.background
      }
      MouseArea {
        id: reducedMotionMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { panel.reduceMotion = !panel.reduceMotion; panel.scheduleReaderStateSave() }
      }
    }
  }
}

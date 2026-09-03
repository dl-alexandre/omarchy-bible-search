import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: libraryView
  property var panel: null

  // Exposed so root's keyboard-routing (blocked: ... .activeFocus) and
  // cursor-navigation functions (moveLibraryCursor/activateLibraryCursor,
  // which stay in root since they also touch search/reader/narration
  // state) can still reach these child views by id from outside this file.
  property alias bookFilterField: readerBookFilterField
  property alias bookList: readerBookList
  property alias chapterGrid: readerChapterGrid
  property alias storedList: readerStoredList

  width: parent.width
  height: panel.readerLibraryOpen ? Style.space(360) : 0
  visible: panel.readerLibraryOpen
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
            color: panel.readerLibraryTab === parent.modelData.key ? panel.popupForeground : panel.popupForeground
            opacity: panel.readerLibraryTab === parent.modelData.key ? 1 : 0.5
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: panel.readerLibraryTab === parent.modelData.key ? Color.accent : "transparent"
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.setLibraryTab(parent.modelData.key)
          }
        }
      }
    }

    Item {
      width: parent.width
      height: Style.space(256)

      Item {
        anchors.fill: parent
        visible: panel.readerLibraryTab === "books"

        TextField {
          id: readerBookFilterField
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: implicitHeight
          placeholderText: "Filter books…"
          text: panel.readerBookFilter
          onTextChanged: panel.readerBookFilter = text
          Keys.onEscapePressed: {
            if (text !== "") {
              text = ""
            } else {
              focus = false
              panel.keyCatcher.forceActiveFocus()
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
          model: panel.bookDisplayModel
          spacing: Style.space(2)
          delegate: CursorSurface {
            required property string bookName
            required property int chapterCount
            required property int index
            width: readerBookList.width
            height: Style.space(28)
            hasCursor: panel.readerLibraryFocus === "books" && panel.readerBookCursor === index
            current: panel.readerCatalogBook === bookName
            foreground: panel.popupForeground
            accent: Color.accent
            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              text: bookName
              color: panel.readerLibraryFocus === "books" && panel.readerBookCursor === index ? Color.accent : panel.popupForeground
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              id: bookMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                panel.readerBookCursor = index
                panel.readerLibraryFocus = "books"
                panel.selectCatalogBook(bookName, chapterCount)
              }
            }
            HoverHandler {
              onHoveredChanged: if (hovered) {
                panel.readerBookCursor = index
                panel.readerLibraryFocus = "books"
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
            model: panel.chapterPickerModel
            cellWidth: Math.max(Style.space(32), Math.floor(width / 5))
            cellHeight: cellWidth
            delegate: Rectangle {
              required property int chapterNumber
              required property int index
              width: readerChapterGrid.cellWidth - Style.space(6)
              height: readerChapterGrid.cellHeight - Style.space(6)
              radius: Style.space(5)
              color: (panel.readerLibraryFocus === "chapters" && panel.readerChapterCursor === index)
                ? Style.hoverFillFor(panel.popupForeground, Color.accent)
                : Style.normalFillFor(panel.popupForeground, Color.accent)
              border.width: 0
              Text {
                anchors.centerIn: parent
                text: chapterNumber
                color: (panel.readerLibraryFocus === "chapters" && panel.readerChapterCursor === index) ? Color.accent : panel.popupForeground
                opacity: (panel.readerLibraryFocus === "chapters" && panel.readerChapterCursor === index) ? 1 : 0.7
                font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                id: chapterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.readerChapterCursor = index
                  panel.readerLibraryFocus = "chapters"
                  panel.openReaderChapter(panel.readerCatalogBook, chapterNumber, "", -1, -1)
                }
              }
              HoverHandler {
                onHoveredChanged: if (hovered) {
                  panel.readerChapterCursor = index
                  panel.readerLibraryFocus = "chapters"
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
          visible: panel.bookDisplayModel.count === 0 && panel.readerBookFilter.trim() !== ""
          spacing: Style.spacing.xs
          Item {
            width: 1
            height: Style.space(72)
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No books match “" + panel.readerBookFilter + "”"
            textFormat: Text.PlainText
            color: panel.popupForeground
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Press Escape to clear the filter."
            textFormat: Text.PlainText
            color: panel.popupForeground
            opacity: 0.5
            font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      ListView {
        id: readerStoredList
        anchors.fill: parent
        visible: panel.readerLibraryTab === "saved" || panel.readerLibraryTab === "recent"
        clip: true
        spacing: Style.spacing.xs
        model: panel.readerLibraryTab === "saved" ? panel.bookmarkModel : panel.recentModel
        delegate: CursorSurface {
          required property string reference
          required property string chapterLabel
          required property int pageIndex
          required property int verseIndex
          required property int index
          width: ListView.view.width
          height: Style.space(48)
          hasCursor: panel.readerLibraryFocus === "list" && panel.readerListCursor === index
          foreground: panel.popupForeground
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
              color: panel.popupForeground
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              text: chapterLabel + "  ·  page " + (pageIndex + 1)
              color: panel.popupForeground
              opacity: 0.48
              font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
          MouseArea {
            id: savedMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              panel.readerListCursor = index
              panel.readerLibraryFocus = "list"
              panel.openStoredReader({ reference: reference, chapterLabel: chapterLabel, pageIndex: pageIndex, verseIndex: verseIndex })
            }
          }
          HoverHandler {
            onHoveredChanged: if (hovered) {
              panel.readerListCursor = index
              panel.readerLibraryFocus = "list"
            }
          }
          PanelActionButton {
            id: savedDeleteButton
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            z: 3
            visible: panel.readerLibraryTab === "saved"
            enabled: visible
            iconText: "󰆴"
            tooltipText: "Remove from Saved"
            foreground: panel.popupForeground
            hoverColor: Color.accent
            fontFamily: panel.bar ? panel.bar.fontFamily : Style.font.family
            onClicked: panel.removeBookmarkAt(index)
          }
        }
      }

      Column {
        anchors.centerIn: parent
        visible: panel.readerLibraryTab === "saved" ? panel.bookmarkModel.count === 0
          : panel.readerLibraryTab === "recent" && panel.recentModel.count === 0
        spacing: Style.spacing.xs
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: panel.readerLibraryTab === "saved" ? "No saved verses yet" : "No recent chapters yet"
          color: panel.popupForeground
          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: panel.readerLibraryTab === "saved"
            ? "Focus a verse and choose Save."
            : "Open a chapter to begin your history."
          color: panel.popupForeground
          opacity: 0.5
          font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    Text {
      width: parent.width
      text: panel.readerState.readerActionFeedback !== ""
        ? panel.readerState.readerActionFeedback
        : panel.catalogLoaded
          ? (panel.readerLibraryTab === "saved" ? "↑↓ select  ·  ENTER open  ·  X remove" : "↑↓ select  ·  ENTER open  ·  TAB sections")
          : "Loading the offline library…"
      color: panel.readerState.readerActionFeedback !== "" ? Color.accent : panel.popupForeground
      opacity: panel.readerState.readerActionFeedback !== "" ? 1 : 0.48
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: panel.readerState.readerActionFeedback !== ""
      wrapMode: Text.WordWrap
    }
  }
}

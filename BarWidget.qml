import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "dev.alexandre.bible-search"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  onBarChanged: injectPanel()

    BarIconButton {
      id: button
      anchors.fill: parent
      bar: root.bar
      text: "󰂿"
      slotSize: Style.bar.statusSlot
      tooltipText: "Bible Search"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}

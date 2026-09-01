import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "dev.alexandre.bible-search"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string scriptPath: {
    var path = String(Qt.resolvedUrl("bin/omarchy-bible-search"))
    if (path.indexOf("file://") === 0) path = path.substring(7)
    return decodeURIComponent(path)
  }

  readonly property string uiPath: {
    var path = String(Qt.resolvedUrl("bin/omarchy-bible-search-ui"))
    if (path.indexOf("file://") === 0) path = path.substring(7)
    return decodeURIComponent(path)
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    if ("pluginScriptPath" in target) target.pluginScriptPath = root.scriptPath
    if ("pluginUiPath" in target) target.pluginUiPath = root.uiPath
  }

  function open() {
    injectPanel()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
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
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("bible-search panel failed:", errorString ? errorString() : "unknown")
    }
  }

  IpcHandler {
    target: "dev.alexandre.bible-search"

    function debug(): string {
      var err = ""
      if (panelLoader.status === Loader.Error)
        err = panelLoader.sourceComponent ? panelLoader.sourceComponent.errorString() : "loader-error"
      var item = panelLoader.item
      return JSON.stringify({
        hasItem: !!item,
        status: panelLoader.status,
        opened: root.opened,
        hasBar: !!root.bar,
        error: err,
        scriptPath: item ? item.scriptPath : "",
        uiPath: item ? item.uiPath : ""
      })
    }

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }
}

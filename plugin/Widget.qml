import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "roubilibo.whatsapp-webapp"

  readonly property string unreadState:
    Quickshell.env("HOME") + "/.local/state/omarchy/whatsapp-unread.json"
  readonly property string toggleScript:
    Quickshell.env("HOME") + "/.local/bin/toggle-whatsapp"
  property int unreadCount: 0
  implicitWidth: Style.bar.statusSlot + (root.unreadCount > 0 ? Style.space(12) : 0)
  implicitHeight: barSize

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function parseState(raw) {
    try {
      var state = JSON.parse(String(raw || "{}"))
      root.unreadCount = Math.max(0, Number(state.unread) || 0)
    } catch (e) {
      root.unreadCount = 0
    }
  }

  Component.onCompleted: root.refresh()

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: stateProc
    command: ["cat", root.unreadState]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseState(text)
    }
  }

  Process { id: toggleProc }

  Text {
    anchors.centerIn: parent
    width: 16
    height: 16
    text: "\uf232"
    color: Color.foreground
    font.family: "Font Awesome 7 Brands"
    font.pixelSize: 13
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  Rectangle {
    visible: root.unreadCount > 0
    width: Math.max(Style.space(13), badgeText.implicitWidth + Style.space(6))
    height: Style.space(13)
    radius: height / 2
    color: "#d94b5b"
    anchors.right: parent.right
    anchors.top: parent.top

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
      color: "white"
      font.pixelSize: 8
      font.bold: true
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      toggleProc.command = [root.toggleScript]
      toggleProc.running = true
    }
  }
}

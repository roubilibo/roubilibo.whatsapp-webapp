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
  readonly property string closeScript:
    Quickshell.env("HOME") + "/.local/bin/close-whatsapp"
  readonly property string restartScript:
    Quickshell.env("HOME") + "/.local/bin/restart-whatsapp"
  property int unreadCount: 0
  property bool whatsappRunning: false
  property bool popupOpen: false
  readonly property bool showBadge: root.whatsappRunning && root.unreadCount > 0
  implicitWidth: Style.bar.statusSlot
  implicitHeight: barSize

  function refresh() {
    if (!stateProc.running) stateProc.running = true
    if (!clientsProc.running) clientsProc.running = true
  }

  function parseState(raw) {
    try {
      var state = JSON.parse(String(raw || "{}"))
      root.unreadCount = Math.max(0, Number(state.unread) || 0)
    } catch (e) {
      root.unreadCount = 0
    }
  }

  function parseClients(raw) {
    try {
      var clients = JSON.parse(String(raw || "[]"))
      root.whatsappRunning = clients.some(function(client) {
        var isWhatsapp = client.class === "chrome-web.whatsapp.com__-Default" ||
          client.initialClass === "chrome-web.whatsapp.com__-Default"
        return isWhatsapp
      })
    } catch (e) {
      root.whatsappRunning = false
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

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseClients(text)
    }
  }

  Process { id: toggleProc }
  Process { id: actionProc }

  function runAction(script) {
    actionProc.command = [script]
    actionProc.running = true
    root.popupOpen = false
  }

  function close() { root.popupOpen = false }

  Text {
    anchors.centerIn: parent
    width: 16
    height: 16
    text: "\uf232"
    color: root.whatsappRunning ? "#25D366" : Color.foreground
    font.family: "Font Awesome 7 Brands"
    font.pixelSize: 13
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  Rectangle {
    visible: root.showBadge
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.popupOpen = true
        return
      }
      toggleProc.command = [root.toggleScript]
      toggleProc.running = true
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      width: parent.width
      spacing: Style.space(8)

      Text {
        width: parent.width
        text: "WhatsApp Web"
        color: Color.popups.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: Util.alpha(Color.popups.border, 0.5)
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.popupRowHeight
        radius: Style.cornerRadius
        color: closeMouse.containsMouse ? Color.menu.selectedBackground : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.controlPaddingX
          anchors.verticalCenter: parent.verticalCenter
          text: "󰆴"
          color: closeMouse.containsMouse ? Color.menu.selectedText : Color.popups.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.controlPaddingX + Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          text: "Close WhatsApp"
          color: closeMouse.containsMouse ? Color.menu.selectedText : Color.popups.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.runAction(root.closeScript)
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.popupRowHeight
        radius: Style.cornerRadius
        color: restartMouse.containsMouse ? Color.menu.selectedBackground : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.controlPaddingX
          anchors.verticalCenter: parent.verticalCenter
          text: "󰑐"
          color: restartMouse.containsMouse ? Color.menu.selectedText : Color.popups.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.controlPaddingX + Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          text: "Restart WhatsApp"
          color: restartMouse.containsMouse ? Color.menu.selectedText : Color.popups.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: restartMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.runAction(root.restartScript)
        }
      }
    }
  }
}

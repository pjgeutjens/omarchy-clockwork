import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  required property string fontFamily
  property var targetScreen: null
  property bool open: false
  property string displayText: "00:00"
  property string message: "Take a break"
  property real progress: 0
  property bool running: false
  property bool completed: false

  signal closeRequested()
  signal toggleRequested()
  signal resetRequested()

  readonly property color onScrim: "white"
  readonly property color onScrimDim: Qt.rgba(1, 1, 1, 0.58)

  screen: targetScreen
  visible: open
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-clockwork-fullscreen"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  onOpenChanged: if (open) Qt.callLater(function() {
    if (root.open) keyCatcher.forceActiveFocus()
  })

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.9)
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: root.closeRequested()
    Keys.onSpacePressed: root.toggleRequested()
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_R) {
        root.resetRequested()
        event.accepted = true
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(48), Style.space(900))
      spacing: Style.space(22)

      Text {
        text: root.completed ? "TIME IS UP" : "BREAK TIMER"
        color: root.completed ? Color.accent : root.onScrimDim
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        font.letterSpacing: 3
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Text {
        text: root.message
        textFormat: Text.PlainText
        color: root.onScrim
        font.family: root.fontFamily
        font.pixelSize: Math.min(Style.font.displayLarge * 1.8, keyCatcher.width / 16)
        font.bold: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Style.space(900)
      }

      Text {
        text: root.displayText
        textFormat: Text.PlainText
        color: root.onScrim
        font.family: root.fontFamily
        font.pixelSize: Math.min(Style.font.displayLarge * 5, keyCatcher.width / 7)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(8)

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(1, 1, 1, 0.16)
        }

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: root.progress <= 0 ? 0 : Math.max(height, parent.width * root.progress)
          height: parent.height
          radius: height / 2
          color: Color.accent
          Behavior on width { NumberAnimation { duration: 90 } }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.space(10)

        Button {
          text: root.running ? "Pause" : root.completed ? "Start again" : "Resume"
          iconText: root.running ? "Ⅱ" : "▶"
          foreground: root.onScrim
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.completed
          opacity: enabled ? 1 : 0.5
          onClicked: root.toggleRequested()
        }

        Button {
          text: "End"
          iconText: "↻"
          foreground: root.onScrim
          fontFamily: root.fontFamily
          bordered: true
          onClicked: root.resetRequested()
        }

        Button {
          text: "Return"
          foreground: root.onScrim
          fontFamily: root.fontFamily
          bordered: true
          onClicked: root.closeRequested()
        }
      }

      Text {
        text: "Space pause/resume   ·   Esc return   ·   R end"
        color: root.onScrimDim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
    }
  }
}

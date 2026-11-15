import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Column {
  id: root

  property string label: ""
  property int value: 0
  property int from: 0
  property int to: 59
  property int stepSize: 1
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.displayLarge * 2
  property real fieldWidth: Style.space(150)
  property bool hasCursor: false
  property bool hovered: false
  property bool canceling: false
  property alias field: spin

  signal modified(int value)
  signal editingDone()
  signal navigationRequested(int direction)
  signal hoveredChangedByPointer(bool hovered)

  function beginEditing() {
    spin.forceActiveFocus()
    editor.selectAll()
  }

  function commitText(text) {
    var parsed = parseInt(String(text), 10)
    if (isNaN(parsed)) parsed = root.value
    parsed = Math.max(root.from, Math.min(root.to, parsed))
    if (parsed === root.value) return
    root.modified(parsed)
  }

  spacing: Style.space(5)

  QQC.SpinBox {
    id: spin
    width: root.fieldWidth
    implicitHeight: root.fontSize + Style.spacing.controlPaddingY * 2
    from: root.from
    to: root.to
    stepSize: root.stepSize
    value: root.value
    editable: true
    activeFocusOnTab: true
    font.family: root.fontFamily
    font.pixelSize: root.fontSize

    textFromValue: function(value, locale) {
      return value < 10 ? "0" + value : String(value)
    }
    valueFromText: function(text, locale) {
      var parsed = parseInt(String(text), 10)
      return isNaN(parsed) ? root.value : parsed
    }

    readonly property var _borderSpec: Border.controlSpec(
      activeFocus ? "focus" : (root.hovered || root.hasCursor ? "hover-cursor" : "normal"),
      root.foreground,
      root.accent
    )

    leftPadding: Border.left(_borderSpec) + Style.spacing.controlPaddingX
    rightPadding: Border.right(_borderSpec) + Style.spacing.controlPaddingX
    topPadding: Border.top(_borderSpec)
    bottomPadding: Border.bottom(_borderSpec)

    onValueModified: root.modified(value)

    background: BorderSurface {
      color: Style.controlFill(spin.activeFocus, root.hovered || root.hasCursor, root.foreground, root.accent)
      borderSpec: spin._borderSpec
      radius: Style.cornerRadius

      HoverHandler {
        onHoveredChanged: {
          root.hovered = hovered
          root.hoveredChangedByPointer(hovered)
        }
      }
    }

    contentItem: TextInput {
      id: editor
      text: spin.displayText
      font: spin.font
      color: root.foreground
      selectionColor: Style.selectionFillFor(root.foreground, root.accent)
      selectedTextColor: root.foreground
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      readOnly: !spin.editable
      validator: spin.validator
      inputMethodHints: Qt.ImhFormattedNumbersOnly
      selectByMouse: true

      onEditingFinished: {
        if (!root.canceling) root.commitText(text)
        root.canceling = false
      }

      Keys.onReturnPressed: {
        focus = false
        root.editingDone()
      }
      Keys.onEnterPressed: {
        focus = false
        root.editingDone()
      }
      Keys.onEscapePressed: {
        root.canceling = true
        focus = false
        root.editingDone()
      }
      Keys.onTabPressed: {
        focus = false
        root.navigationRequested(1)
      }
      Keys.onBacktabPressed: {
        focus = false
        root.navigationRequested(-1)
      }
    }
  }

  Text {
    width: root.fieldWidth
    text: root.label.toUpperCase()
    textFormat: Text.PlainText
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.2
    horizontalAlignment: Text.AlignHCenter
  }
}

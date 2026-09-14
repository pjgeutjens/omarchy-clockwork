import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "." as TimerCore

Panel {
  id: root
  moduleName: "io.github.pjgeutjens.clockwork"
  ipcTarget: "io.github.pjgeutjens.clockwork"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool canEditMajorTime: !TimerCore.TimerState.running
    && TimerCore.TimerState.storedElapsedMs === 0
    && !TimerCore.TimerState.completed
    && (TimerCore.TimerState.mode === TimerCore.TimerState.countdownMode
      || TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode)
  property bool fullscreenOpen: false
  property bool suppressActivate: false
  property int cursorIndex: 0
  readonly property var cursorTargets: {
    if (TimerCore.TimerState.running) return []
    if (TimerCore.TimerState.mode === TimerCore.TimerState.countdownMode) {
      var countdownTargets = []
      if (root.canEditMajorTime) {
        countdownTargets.push({ key: "major-left", item: majorTimeLeft, kind: "time" })
        countdownTargets.push({ key: "major-right", item: majorTimeRight, kind: "time" })
      }
      countdownTargets.push({ key: "countdown-fullscreen", item: fullscreenToggle, kind: "toggle" })
      if (TimerCore.TimerState.countdownFullscreenEnabled)
        countdownTargets.push({ key: "countdown-message", item: countdownMessage, kind: "text" })
      return countdownTargets
    }
    if (TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode) {
      var alarmTargets = []
      if (root.canEditMajorTime) {
        alarmTargets.push({ key: "major-left", item: majorTimeLeft, kind: "time" })
        alarmTargets.push({ key: "major-right", item: majorTimeRight, kind: "time" })
        if (TimerCore.TimerState.alarmUses12Hour) {
          alarmTargets.push({ key: "alarm-am", item: alarmAmButton, kind: "button" })
          alarmTargets.push({ key: "alarm-pm", item: alarmPmButton, kind: "button" })
        }
      }
      alarmTargets.push({ key: "alarm-format", item: alarmFormatToggle, kind: "toggle" })
      alarmTargets.push({ key: "alarm-sound", item: alarmSoundButton, kind: "button" })
      alarmTargets.push({ key: "alarm-message", item: alarmMessage, kind: "text" })
      return alarmTargets
    }
    if (TimerCore.TimerState.mode === TimerCore.TimerState.intervalsMode) {
      return [
        { key: "interval-rounds", item: intervalRounds, kind: "number" },
        { key: "interval-minutes", item: intervalMinutes, kind: "number" },
        { key: "interval-seconds", item: intervalSeconds, kind: "number" }
      ]
    }
    if (TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode) {
      if (TimerCore.TimerState.pomodoroSessionStarted || TimerCore.TimerState.completed) return []
      return [
        { key: "pomodoro-work", item: pomodoroWorkMinutes, kind: "number" },
        { key: "pomodoro-short", item: pomodoroShortBreakMinutes, kind: "number" },
        { key: "pomodoro-cycles", item: pomodoroCycles, kind: "number" },
        { key: "pomodoro-long", item: pomodoroLongBreakMinutes, kind: "number" },
        { key: "pomodoro-sound", item: pomodoroSoundToggle, kind: "toggle" }
      ]
    }
    return []
  }
  readonly property string cursorKey: cursorTargets.length > 0
    ? cursorTargets[Math.max(0, Math.min(cursorIndex, cursorTargets.length - 1))].key
    : ""

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function startPause() {
    // Field edits only commit on focus loss, so steal focus first or Start
    // reads the pre-edit value
    keyCatcher.forceActiveFocus()
    var shouldOpenFullscreen = !TimerCore.TimerState.running
      && TimerCore.TimerState.mode === TimerCore.TimerState.countdownMode
      && TimerCore.TimerState.countdownFullscreenEnabled
    TimerCore.TimerState.startPause()
    if (shouldOpenFullscreen && TimerCore.TimerState.running) {
      root.fullscreenOpen = true
      root.close()
    }
  }

  function resetTimer() {
    TimerCore.TimerState.reset()
    root.fullscreenOpen = false
  }

  function closeFullscreen() {
    root.fullscreenOpen = false
    Qt.callLater(root.open)
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setPomodoroSetting(key, value) {
    var setting = ({})
    if (key === "pomodoro-work") {
      TimerCore.TimerState.setPomodoroWorkMinutes(value)
      setting.pomodoroWorkMinutes = TimerCore.TimerState.pomodoroWorkMinutes
    } else if (key === "pomodoro-short") {
      TimerCore.TimerState.setPomodoroShortBreakMinutes(value)
      setting.pomodoroShortBreakMinutes = TimerCore.TimerState.pomodoroShortBreakMinutes
    } else if (key === "pomodoro-cycles") {
      TimerCore.TimerState.setPomodoroCycles(value)
      setting.pomodoroCycles = TimerCore.TimerState.pomodoroCycles
    } else if (key === "pomodoro-long") {
      TimerCore.TimerState.setPomodoroLongBreakMinutes(value)
      setting.pomodoroLongBreakMinutes = TimerCore.TimerState.pomodoroLongBreakMinutes
    } else if (key === "pomodoro-sound") {
      TimerCore.TimerState.setPomodoroSoundEnabled(Boolean(value))
      setting.pomodoroSound = TimerCore.TimerState.pomodoroSoundEnabled
    }
    root.persistSettings(setting)
  }

  function setAlarmUses12Hour(enabled) {
    TimerCore.TimerState.setAlarmUses12Hour(enabled)
    root.persistSettings({ alarmUses12Hour: TimerCore.TimerState.alarmUses12Hour })
    root.clampCursor()
  }

  function cycleAlarmSound(direction) {
    TimerCore.TimerState.cycleAlarmSound(direction)
    root.persistSettings({ alarmSound: TimerCore.TimerState.alarmSound })
  }

  function clampCursor() {
    if (root.cursorTargets.length === 0) {
      root.cursorIndex = 0
      return
    }
    root.cursorIndex = Math.max(0, Math.min(root.cursorIndex, root.cursorTargets.length - 1))
  }

  function selectCursor(key) {
    for (var i = 0; i < root.cursorTargets.length; i++) {
      if (root.cursorTargets[i].key === key) {
        root.cursorIndex = i
        root.ensureCursorVisible(root.cursorTargets[i].item)
        return
      }
    }
  }

  function moveCursor(direction) {
    var count = root.cursorTargets.length
    if (count === 0) return false
    root.cursorIndex = (root.cursorIndex + direction + count) % count
    root.ensureCursorVisible(root.cursorTargets[root.cursorIndex].item)
    return true
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea || !scrollArea.contentItem) return
    var flick = scrollArea.contentItem
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var margin = Style.space(12)
    if (top < flick.contentY + margin) flick.contentY = Math.max(0, top - margin)
    else if (bottom > flick.contentY + flick.height - margin)
      flick.contentY = bottom + margin - flick.height
  }

  function finishEditing() {
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function finishEditingAndMove(direction) {
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      root.moveCursor(direction)
    })
  }

  function activateCursor() {
    if (root.cursorTargets.length === 0) return false
    var target = root.cursorTargets[root.cursorIndex]
    if (target.kind === "time" || target.kind === "number") {
      target.item.beginEditing()
    } else if (target.kind === "text") {
      target.item.selectAll()
      target.item.forceActiveFocus()
    } else if (target.key === "countdown-fullscreen") {
      TimerCore.TimerState.setCountdownFullscreenEnabled(!TimerCore.TimerState.countdownFullscreenEnabled)
      root.clampCursor()
    } else if (target.key === "pomodoro-sound") {
      root.setPomodoroSetting("pomodoro-sound", !TimerCore.TimerState.pomodoroSoundEnabled)
    } else if (target.key === "alarm-format") {
      root.setAlarmUses12Hour(!TimerCore.TimerState.alarmUses12Hour)
    } else if (target.key === "alarm-am") {
      TimerCore.TimerState.setAlarmMeridiem("AM")
    } else if (target.key === "alarm-pm") {
      TimerCore.TimerState.setAlarmMeridiem("PM")
    } else if (target.key === "alarm-sound") {
      root.cycleAlarmSound(1)
    }
    return true
  }

  function adjustCursor(direction) {
    if (root.cursorTargets.length === 0) return
    var key = root.cursorTargets[root.cursorIndex].key
    if (key === "interval-rounds") TimerCore.TimerState.setIntervalRounds(TimerCore.TimerState.intervalRounds + direction)
    else if (key === "interval-minutes") TimerCore.TimerState.setIntervalMinutes(TimerCore.TimerState.intervalMinutes + direction)
    else if (key === "interval-seconds") TimerCore.TimerState.setIntervalSeconds(TimerCore.TimerState.intervalSeconds + direction)
    else if (key === "pomodoro-work") root.setPomodoroSetting(key, TimerCore.TimerState.pomodoroWorkMinutes + direction)
    else if (key === "pomodoro-short") root.setPomodoroSetting(key, TimerCore.TimerState.pomodoroShortBreakMinutes + direction)
    else if (key === "pomodoro-cycles") root.setPomodoroSetting(key, TimerCore.TimerState.pomodoroCycles + direction)
    else if (key === "pomodoro-long") root.setPomodoroSetting(key, TimerCore.TimerState.pomodoroLongBreakMinutes + direction)
    else if (key === "pomodoro-sound") root.setPomodoroSetting(key, direction > 0)
    else if (key === "countdown-fullscreen") TimerCore.TimerState.setCountdownFullscreenEnabled(direction > 0)
    else if (key === "alarm-format") root.setAlarmUses12Hour(direction > 0)
    else if (key === "alarm-am" || key === "alarm-pm")
      TimerCore.TimerState.setAlarmMeridiem(direction > 0 ? "PM" : "AM")
    else if (key === "alarm-sound") root.cycleAlarmSound(direction)
  }

  function moveCursorHorizontal(direction) {
    var key = root.cursorKey
    if (key === "major-left" && direction > 0) root.selectCursor("major-right")
    else if (key === "major-right" && direction < 0) root.selectCursor("major-left")
    else root.adjustCursor(direction)
  }

  Connections {
    target: TimerCore.TimerState
    function onModeChanged() { root.cursorIndex = 0 }
    function onRunningChanged() { root.clampCursor() }
    function onCountdownFullscreenEnabledChanged() { root.clampCursor() }
    function onPomodoroSessionStartedChanged() { root.clampCursor() }
  }

  Component {
    id: timerIcon
    Text {
      text: "◷"
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.display
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(610))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: majorTimeLeft.field.activeFocus
        || majorTimeRight.field.activeFocus
        || countdownMessage.activeFocus
        || intervalRounds.field.activeFocus
        || intervalMinutes.field.activeFocus
        || intervalSeconds.field.activeFocus
        || alarmMessage.activeFocus
        || pomodoroWorkMinutes.field.activeFocus
        || pomodoroShortBreakMinutes.field.activeFocus
        || pomodoroCycles.field.activeFocus
        || pomodoroLongBreakMinutes.field.activeFocus
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.moveCursorHorizontal(dx)
      }
      onReturnRequested: {
        if (root.cursorTargets.length > 0) {
          root.suppressActivate = true
          root.activateCursor()
        }
      }
      onActivateRequested: {
        if (root.suppressActivate) root.suppressActivate = false
        else root.startPause()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (!root.moveCursor(direction)) root.switchPanel(direction)
      }
      onTextKey: function(text) {
        if (text === "1") TimerCore.TimerState.selectMode(TimerCore.TimerState.stopwatchMode)
        else if (text === "2") TimerCore.TimerState.selectMode(TimerCore.TimerState.countdownMode)
        else if (text === "3") TimerCore.TimerState.selectMode(TimerCore.TimerState.alarmMode)
        else if (text === "4") TimerCore.TimerState.selectMode(TimerCore.TimerState.intervalsMode)
        else if (text === "5") TimerCore.TimerState.selectMode(TimerCore.TimerState.pomodoroMode)
        else if (text === "r" || text === "R") root.resetTimer()
        else if ((text === "s" || text === "S")
          && TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode)
          TimerCore.TimerState.skipPomodoroPhase()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            iconComponent: timerIcon
            title: "Clockwork"
            meta: TimerCore.TimerState.modeName + " · " + TimerCore.TimerState.statusText
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          PanelSeparator {
            foreground: root.contentForeground
          }

          Row {
            id: modeRow
            width: parent.width
            spacing: Style.space(6)

            readonly property var modes: [
              { label: "Stopwatch", value: TimerCore.TimerState.stopwatchMode },
              { label: "Countdown", value: TimerCore.TimerState.countdownMode },
              { label: "Alarm", value: TimerCore.TimerState.alarmMode },
              { label: "Intervals", value: TimerCore.TimerState.intervalsMode },
              { label: "Pomodoro", value: TimerCore.TimerState.pomodoroMode }
            ]
            readonly property real cellWidth: (width - spacing * (modes.length - 1)) / modes.length

            Repeater {
              model: modeRow.modes

              Button {
                required property var modelData
                width: modeRow.cellWidth
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                bordered: true
                active: TimerCore.TimerState.mode === modelData.value
                enabled: !TimerCore.TimerState.running
                opacity: enabled ? 1 : 0.5
                onClicked: TimerCore.TimerState.selectMode(modelData.value)
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Text {
              visible: !root.canEditMajorTime
              width: parent.width
              text: TimerCore.TimerState.displayText
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.displayLarge * 2
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Row {
              id: majorTimeEditor
              visible: root.canEditMajorTime
              width: parent.width
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)
              readonly property bool hasMeridiem: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                && TimerCore.TimerState.alarmUses12Hour
              readonly property real colonWidth: Style.space(18)
              readonly property real meridiemWidth: hasMeridiem ? Style.space(58) : 0
              readonly property real timeFieldWidth: Math.max(Style.space(96),
                (width - colonWidth - meridiemWidth - spacing * (hasMeridiem ? 3 : 2)) / 2)

              TimeField {
                id: majorTimeLeft
                width: majorTimeEditor.timeFieldWidth
                fieldWidth: width
                label: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode ? "Hour" : "Minutes"
                from: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                  && TimerCore.TimerState.alarmUses12Hour ? 1 : 0
                to: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                  ? TimerCore.TimerState.alarmUses12Hour ? 12 : 23 : 999
                value: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                  ? TimerCore.TimerState.alarmDisplayHour
                  : TimerCore.TimerState.countdownMinutes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "major-left"
                onModified: function(value) {
                  if (TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode)
                    TimerCore.TimerState.alarmUses12Hour
                      ? TimerCore.TimerState.setAlarmDisplayHour(value)
                      : TimerCore.TimerState.setAlarmHour(value)
                  else
                    TimerCore.TimerState.setCountdownMinutes(value)
                }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("major-left")
                }
              }

              Text {
                width: majorTimeEditor.colonWidth
                text: ":"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.displayLarge * 2
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.top: majorTimeLeft.top
                anchors.topMargin: (majorTimeLeft.field.height - implicitHeight) / 2
              }

              TimeField {
                id: majorTimeRight
                width: majorTimeEditor.timeFieldWidth
                fieldWidth: width
                label: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode ? "Minute" : "Seconds"
                from: 0
                to: 59
                value: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                  ? TimerCore.TimerState.alarmMinute
                  : TimerCore.TimerState.countdownSeconds
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "major-right"
                onModified: function(value) {
                  if (TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode)
                    TimerCore.TimerState.setAlarmMinute(value)
                  else
                    TimerCore.TimerState.setCountdownSeconds(value)
                }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("major-right")
                }
              }

              Column {
                id: alarmMeridiemSelector
                visible: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                  && TimerCore.TimerState.alarmUses12Hour
                width: majorTimeEditor.meridiemWidth
                spacing: Style.space(5)
                readonly property real buttonHeight: (majorTimeRight.field.height - spacing) / 2

                Button {
                  id: alarmAmButton
                  width: Style.space(58)
                  height: alarmMeridiemSelector.buttonHeight
                  text: "AM"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  bordered: true
                  selected: TimerCore.TimerState.alarmMeridiem === "AM"
                  hasCursor: root.cursorKey === "alarm-am"
                  onClicked: TimerCore.TimerState.setAlarmMeridiem("AM")
                  onHovered: function(hovered) {
                    if (hovered) root.selectCursor("alarm-am")
                  }
                }

                Button {
                  id: alarmPmButton
                  width: Style.space(58)
                  height: alarmMeridiemSelector.buttonHeight
                  text: "PM"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  bordered: true
                  selected: TimerCore.TimerState.alarmMeridiem === "PM"
                  hasCursor: root.cursorKey === "alarm-pm"
                  onClicked: TimerCore.TimerState.setAlarmMeridiem("PM")
                  onHovered: function(hovered) {
                    if (hovered) root.selectCursor("alarm-pm")
                  }
                }
              }
            }

            Text {
              width: parent.width
              text: TimerCore.TimerState.statusText.toUpperCase()
              textFormat: Text.PlainText
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              horizontalAlignment: Text.AlignHCenter
            }
          }

          Item {
            visible: TimerCore.TimerState.mode !== TimerCore.TimerState.stopwatchMode
            width: parent.width
            implicitHeight: visible ? Style.space(7) : 0

            Rectangle {
              anchors.fill: parent
              radius: height / 2
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
            }

            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: TimerCore.TimerState.progress <= 0
                ? 0
                : Math.max(height, parent.width * TimerCore.TimerState.progress)
              height: parent.height
              radius: height / 2
              color: Color.accent
              Behavior on width { NumberAnimation { duration: 90 } }
            }
          }

          PanelSeparator {
            visible: TimerCore.TimerState.mode !== TimerCore.TimerState.stopwatchMode
            foreground: root.contentForeground
          }

          Column {
            visible: TimerCore.TimerState.mode === TimerCore.TimerState.countdownMode
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              id: fullscreenToggle
              width: parent.width
              label: "Fullscreen break view"
              description: "Show the countdown and message across this display"
              checked: TimerCore.TimerState.countdownFullscreenEnabled
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              hasCursor: root.cursorKey === "countdown-fullscreen"
              enabled: !TimerCore.TimerState.running
              opacity: enabled ? 1 : 0.5
              onClicked: if (enabled)
                TimerCore.TimerState.setCountdownFullscreenEnabled(!TimerCore.TimerState.countdownFullscreenEnabled)
              onHovered: function(hovered) {
                if (hovered) root.selectCursor("countdown-fullscreen")
              }
            }

            Column {
              visible: TimerCore.TimerState.countdownFullscreenEnabled
              width: parent.width
              spacing: Style.space(5)

              PanelSectionHeader {
                text: "BREAK MESSAGE"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              TextField {
                id: countdownMessage
                width: parent.width
                text: TimerCore.TimerState.countdownMessage
                placeholderText: "Take a break"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                hasCursor: root.cursorKey === "countdown-message"
                enabled: !TimerCore.TimerState.running
                opacity: enabled ? 1 : 0.5
                onEditingFinished: TimerCore.TimerState.setCountdownMessage(text)
                onHoveredChanged: if (hovered) root.selectCursor("countdown-message")
                Keys.onReturnPressed: {
                  TimerCore.TimerState.setCountdownMessage(text)
                  root.finishEditing()
                }
                Keys.onEnterPressed: {
                  TimerCore.TimerState.setCountdownMessage(text)
                  root.finishEditing()
                }
                Keys.onEscapePressed: root.finishEditing()
                Keys.onTabPressed: {
                  TimerCore.TimerState.setCountdownMessage(text)
                  root.finishEditingAndMove(1)
                }
                Keys.onBacktabPressed: {
                  TimerCore.TimerState.setCountdownMessage(text)
                  root.finishEditingAndMove(-1)
                }
              }
            }
          }

          Column {
            visible: TimerCore.TimerState.mode === TimerCore.TimerState.intervalsMode
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: parent.width
              implicitHeight: Math.max(intervalHeader.implicitHeight, intervalSummary.implicitHeight)

              PanelSectionHeader {
                id: intervalHeader
                text: "EXERCISE INTERVALS"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: intervalSummary
                text: TimerCore.TimerState.intervalRounds + " × "
                  + TimerCore.TimerState.intervalDurationText
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              CompactField {
                id: intervalRounds
                width: (parent.width - parent.spacing) / 3
                fieldWidth: width
                label: "Rounds"
                from: 1
                to: 999
                value: TimerCore.TimerState.intervalRounds
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "interval-rounds"
                enabled: !TimerCore.TimerState.running
                opacity: enabled ? 1 : 0.5
                onModified: function(value) { TimerCore.TimerState.setIntervalRounds(value) }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("interval-rounds")
                }
              }

              Row {
                width: (parent.width - parent.spacing) * 2 / 3
                spacing: Style.space(6)

                CompactField {
                  id: intervalMinutes
                  width: (parent.width - parent.spacing) / 2
                  fieldWidth: width
                  label: "Minutes"
                  from: 0
                  to: 999
                  value: TimerCore.TimerState.intervalMinutes
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  hasCursor: root.cursorKey === "interval-minutes"
                  enabled: !TimerCore.TimerState.running
                  opacity: enabled ? 1 : 0.5
                  onModified: function(value) { TimerCore.TimerState.setIntervalMinutes(value) }
                  onEditingDone: root.finishEditing()
                  onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                  onHoveredChangedByPointer: function(hovered) {
                    if (hovered) root.selectCursor("interval-minutes")
                  }
                }

                CompactField {
                  id: intervalSeconds
                  width: (parent.width - parent.spacing) / 2
                  fieldWidth: width
                  label: "Seconds"
                  from: 0
                  to: 59
                  value: TimerCore.TimerState.intervalSeconds
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  hasCursor: root.cursorKey === "interval-seconds"
                  enabled: !TimerCore.TimerState.running
                  opacity: enabled ? 1 : 0.5
                  onModified: function(value) { TimerCore.TimerState.setIntervalSeconds(value) }
                  onEditingDone: root.finishEditing()
                  onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                  onHoveredChangedByPointer: function(hovered) {
                    if (hovered) root.selectCursor("interval-seconds")
                  }
                }
              }
            }
          }

          Column {
            visible: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              id: alarmFormatToggle
              width: parent.width
              label: "12-hour time"
              description: "Show the alarm time with AM or PM"
              checked: TimerCore.TimerState.alarmUses12Hour
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              hasCursor: root.cursorKey === "alarm-format"
              enabled: !TimerCore.TimerState.running
              opacity: enabled ? 1 : 0.5
              onClicked: if (enabled)
                root.setAlarmUses12Hour(!TimerCore.TimerState.alarmUses12Hour)
              onHovered: function(hovered) {
                if (hovered) root.selectCursor("alarm-format")
              }
            }

            Button {
              id: alarmSoundButton
              width: parent.width
              text: "Alarm sound · " + TimerCore.TimerState.alarmSoundName
              iconText: "󰎈"
              tooltipText: "Click to choose the next installed alarm sound"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              bordered: true
              leftAlign: true
              hasCursor: root.cursorKey === "alarm-sound"
              enabled: !TimerCore.TimerState.running
              opacity: enabled ? 1 : 0.5
              onClicked: if (enabled) root.cycleAlarmSound(1)
              onHovered: function(hovered) {
                if (hovered) root.selectCursor("alarm-sound")
              }
            }

            PanelSectionHeader {
              text: "ALARM MESSAGE"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            TextField {
              id: alarmMessage
              width: parent.width
              text: TimerCore.TimerState.alarmMessage
              placeholderText: "Alarm"
              foreground: root.contentForeground
              font.family: root.contentFontFamily
              hasCursor: root.cursorKey === "alarm-message"
              enabled: !TimerCore.TimerState.running
              opacity: enabled ? 1 : 0.5
              onEditingFinished: TimerCore.TimerState.setAlarmMessage(text)
              onHoveredChanged: if (hovered) root.selectCursor("alarm-message")
              Keys.onReturnPressed: {
                TimerCore.TimerState.setAlarmMessage(text)
                root.finishEditing()
              }
              Keys.onEnterPressed: {
                TimerCore.TimerState.setAlarmMessage(text)
                root.finishEditing()
              }
              Keys.onEscapePressed: root.finishEditing()
              Keys.onTabPressed: {
                TimerCore.TimerState.setAlarmMessage(text)
                root.finishEditingAndMove(1)
              }
              Keys.onBacktabPressed: {
                TimerCore.TimerState.setAlarmMessage(text)
                root.finishEditingAndMove(-1)
              }
            }
          }

          Column {
            visible: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: parent.width
              implicitHeight: Math.max(pomodoroHeader.implicitHeight, pomodoroSummary.implicitHeight)

              PanelSectionHeader {
                id: pomodoroHeader
                text: "POMODORO CYCLE"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: pomodoroSummary
                text: TimerCore.TimerState.pomodoroWorkMinutes + " / "
                  + TimerCore.TimerState.pomodoroShortBreakMinutes + " × "
                  + TimerCore.TimerState.pomodoroCycles + " · "
                  + TimerCore.TimerState.pomodoroLongBreakMinutes + " long"
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(7)

              Repeater {
                model: TimerCore.TimerState.pomodoroCycles

                Rectangle {
                  required property int index
                  width: Style.space(8)
                  height: width
                  radius: width / 2
                  color: index < TimerCore.TimerState.pomodoroCompletedCycles
                    ? Color.accent
                    : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.24)
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              CompactField {
                id: pomodoroWorkMinutes
                width: (parent.width - parent.spacing) / 2
                fieldWidth: width
                label: "Focus minutes"
                from: 1
                to: 999
                value: TimerCore.TimerState.pomodoroWorkMinutes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "pomodoro-work"
                enabled: !TimerCore.TimerState.pomodoroSessionStarted && !TimerCore.TimerState.completed
                opacity: enabled ? 1 : 0.5
                onModified: function(value) { root.setPomodoroSetting("pomodoro-work", value) }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("pomodoro-work")
                }
              }

              CompactField {
                id: pomodoroShortBreakMinutes
                width: (parent.width - parent.spacing) / 2
                fieldWidth: width
                label: "Short break"
                from: 1
                to: 999
                value: TimerCore.TimerState.pomodoroShortBreakMinutes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "pomodoro-short"
                enabled: !TimerCore.TimerState.pomodoroSessionStarted && !TimerCore.TimerState.completed
                opacity: enabled ? 1 : 0.5
                onModified: function(value) { root.setPomodoroSetting("pomodoro-short", value) }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("pomodoro-short")
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              CompactField {
                id: pomodoroCycles
                width: (parent.width - parent.spacing) / 2
                fieldWidth: width
                label: "Focus cycles"
                from: 1
                to: 99
                value: TimerCore.TimerState.pomodoroCycles
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "pomodoro-cycles"
                enabled: !TimerCore.TimerState.pomodoroSessionStarted && !TimerCore.TimerState.completed
                opacity: enabled ? 1 : 0.5
                onModified: function(value) { root.setPomodoroSetting("pomodoro-cycles", value) }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("pomodoro-cycles")
                }
              }

              CompactField {
                id: pomodoroLongBreakMinutes
                width: (parent.width - parent.spacing) / 2
                fieldWidth: width
                label: "Long break"
                from: 1
                to: 999
                value: TimerCore.TimerState.pomodoroLongBreakMinutes
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                hasCursor: root.cursorKey === "pomodoro-long"
                enabled: !TimerCore.TimerState.pomodoroSessionStarted && !TimerCore.TimerState.completed
                opacity: enabled ? 1 : 0.5
                onModified: function(value) { root.setPomodoroSetting("pomodoro-long", value) }
                onEditingDone: root.finishEditing()
                onNavigationRequested: function(direction) { root.finishEditingAndMove(direction) }
                onHoveredChangedByPointer: function(hovered) {
                  if (hovered) root.selectCursor("pomodoro-long")
                }
              }
            }

            Toggle {
              id: pomodoroSoundToggle
              width: parent.width
              label: "Pomodoro sounds"
              description: "Bell between phases and three bells when the cycle ends"
              checked: TimerCore.TimerState.pomodoroSoundEnabled
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              hasCursor: root.cursorKey === "pomodoro-sound"
              enabled: !TimerCore.TimerState.pomodoroSessionStarted && !TimerCore.TimerState.completed
              opacity: enabled ? 1 : 0.5
              onClicked: if (enabled)
                root.setPomodoroSetting("pomodoro-sound", !TimerCore.TimerState.pomodoroSoundEnabled)
              onHovered: function(hovered) {
                if (hovered) root.selectCursor("pomodoro-sound")
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: Math.max(0, parent.width - resetButton.width
                - (skipButton.visible ? skipButton.width + parent.spacing : 0)
                - parent.spacing)
              text: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                ? TimerCore.TimerState.running ? "Unset" : "Set"
                : TimerCore.TimerState.running ? "Pause" : TimerCore.TimerState.completed ? "Start again" : "Start"
              iconText: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                ? TimerCore.TimerState.running ? "×" : "●"
                : TimerCore.TimerState.running ? "Ⅱ" : "▶"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              bordered: true
              active: TimerCore.TimerState.running
              enabled: TimerCore.TimerState.mode === TimerCore.TimerState.stopwatchMode
                || TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                || TimerCore.TimerState.targetMs > 0
              opacity: enabled ? 1 : 0.5
              onClicked: root.startPause()
            }

            Button {
              id: skipButton
              visible: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
                && TimerCore.TimerState.pomodoroSessionStarted
                && !TimerCore.TimerState.completed
              text: "Skip"
              iconText: "»"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              bordered: true
              onClicked: TimerCore.TimerState.skipPomodoroPhase()
            }

            Button {
              id: resetButton
              text: "Reset"
              iconText: "↻"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              bordered: true
              enabled: TimerCore.TimerState.running
                || TimerCore.TimerState.storedElapsedMs > 0
                || TimerCore.TimerState.completed
                || (TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
                  && TimerCore.TimerState.pomodoroSessionStarted)
              opacity: enabled ? 1 : 0.5
              onClicked: root.resetTimer()
            }
          }

          Text {
            width: parent.width
            text: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
              && TimerCore.TimerState.pomodoroSessionStarted
              && !TimerCore.TimerState.completed
              ? "Space start/pause   ·   S skip   ·   R reset"
              : root.cursorTargets.length > 0
              ? "J/K fields   ·   H/L adjust   ·   Enter edit   ·   Space action"
              : TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
                ? "Space set/unset   ·   R reset   ·   1–5 change mode"
                : "Space start/pause   ·   R reset   ·   1–5 change mode"
            textFormat: Text.PlainText
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  FullscreenCountdown {
    targetScreen: panel.anchorWindow ? panel.anchorWindow.screen : null
    fontFamily: root.contentFontFamily
    open: root.fullscreenOpen
    displayText: TimerCore.TimerState.displayText
    message: TimerCore.TimerState.countdownMessage
    progress: TimerCore.TimerState.progress
    running: TimerCore.TimerState.running
    completed: TimerCore.TimerState.completed
    onCloseRequested: root.closeFullscreen()
    onToggleRequested: TimerCore.TimerState.startPause()
    onResetRequested: root.resetTimer()
  }
}

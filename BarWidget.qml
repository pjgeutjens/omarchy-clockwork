import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "." as TimerCore

BarWidget {
  id: root
  moduleName: "io.github.pjgeutjens.clockwork"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property bool pomodoroSessionVisible: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
    && TimerCore.TimerState.pomodoroSessionStarted
  readonly property bool pomodoroBreak: root.pomodoroSessionVisible
    && TimerCore.TimerState.pomodoroPhase.kind !== "focus"
  readonly property bool alarmRinging: TimerCore.TimerState.mode === TimerCore.TimerState.alarmMode
    && TimerCore.TimerState.completed
  readonly property color pomodoroPhaseColor: root.pomodoroBreak
    ? TimerCore.TimerState.pomodoroBreakColor
    : Color.accent
  readonly property color alarmCueColor: root.bar ? root.bar.urgent : Color.urgent

  function configuredInt(primary, alias, fallback, minimum, maximum) {
    var parsed = Number(root.setting(primary, root.setting(alias, fallback)))
    if (!isFinite(parsed)) parsed = fallback
    return Math.max(minimum, Math.min(maximum, Math.round(parsed)))
  }

  function applyPomodoroSettings() {
    TimerCore.TimerState.configurePomodoro(
      root.configuredInt("pomodoroWorkMinutes", "workMinutes", 25, 1, 999),
      root.configuredInt("pomodoroShortBreakMinutes", "shortBreakMinutes", 5, 1, 999),
      root.configuredInt("pomodoroCycles", "pomodorosPerCycle", 4, 1, 99),
      root.configuredInt("pomodoroLongBreakMinutes", "longBreakMinutes", 15, 1, 999),
      root.setting("pomodoroSound", root.setting("sound", true)) !== false,
      root.setting("pomodoroBreakColor", root.setting("breakColor", "#a6e3a1"))
    )
  }

  function applyAlarmSettings() {
    TimerCore.TimerState.setAlarmUses12Hour(root.setting("alarmUses12Hour", false) === true)
    TimerCore.TimerState.setAlarmSound(root.setting("alarmSound", "alarm-clock-elapsed.oga"))
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: {
    root.applyPomodoroSettings()
    root.applyAlarmSettings()
    root.injectPanel()
  }
  Component.onCompleted: {
    root.applyPomodoroSettings()
    root.applyAlarmSettings()
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

  IpcHandler {
    // Keep this literal: IpcHandler registers once during construction, before
    // the bar host has necessarily finished injecting the widget properties.
    target: "io.github.pjgeutjens.clockwork"

    function start(): string {
      if (!TimerCore.TimerState.running) TimerCore.TimerState.startPause()
      return TimerCore.TimerState.statusText
    }

    function pause(): string {
      TimerCore.TimerState.pause()
      return TimerCore.TimerState.statusText
    }

    function toggleTimer(): string {
      TimerCore.TimerState.startPause()
      return TimerCore.TimerState.statusText
    }

    function reset(): string {
      TimerCore.TimerState.reset()
      return TimerCore.TimerState.statusText
    }

    function skip(): string {
      TimerCore.TimerState.skipPomodoroPhase()
      return TimerCore.TimerState.statusText
    }

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }

    function stopwatch(): string {
      TimerCore.TimerState.selectMode(TimerCore.TimerState.stopwatchMode)
      return TimerCore.TimerState.statusText
    }

    function countdown(minutes: string, seconds: string): string {
      TimerCore.TimerState.selectMode(TimerCore.TimerState.countdownMode)
      TimerCore.TimerState.setCountdownMinutes(parseInt(minutes, 10) || 0)
      TimerCore.TimerState.setCountdownSeconds(parseInt(seconds, 10) || 0)
      return TimerCore.TimerState.statusText
    }

    function intervals(rounds: string, minutes: string, seconds: string): string {
      TimerCore.TimerState.selectMode(TimerCore.TimerState.intervalsMode)
      TimerCore.TimerState.setIntervalRounds(parseInt(rounds, 10) || 1)
      var legacyUnit = String(seconds).toLowerCase()
      var duration = parseInt(minutes, 10) || 0
      if (legacyUnit.indexOf("sec") === 0) {
        TimerCore.TimerState.setIntervalMinutes(Math.floor(duration / 60))
        TimerCore.TimerState.setIntervalSeconds(duration % 60)
      } else if (legacyUnit.indexOf("min") === 0) {
        TimerCore.TimerState.setIntervalMinutes(duration)
        TimerCore.TimerState.setIntervalSeconds(0)
      } else {
        TimerCore.TimerState.setIntervalMinutes(duration)
        TimerCore.TimerState.setIntervalSeconds(parseInt(seconds, 10) || 0)
      }
      return TimerCore.TimerState.statusText
    }

    function alarm(hour: string, minute: string, message: string): string {
      TimerCore.TimerState.selectMode(TimerCore.TimerState.alarmMode)
      TimerCore.TimerState.setAlarmHour(parseInt(hour, 10) || 0)
      TimerCore.TimerState.setAlarmMinute(parseInt(minute, 10) || 0)
      TimerCore.TimerState.setAlarmMessage(message)
      return TimerCore.TimerState.statusText
    }

    function pomodoro(workMinutes: string, shortBreakMinutes: string, cycles: string, longBreakMinutes: string): string {
      TimerCore.TimerState.selectMode(TimerCore.TimerState.pomodoroMode)
      TimerCore.TimerState.setPomodoroWorkMinutes(parseInt(workMinutes, 10) || 25)
      TimerCore.TimerState.setPomodoroShortBreakMinutes(parseInt(shortBreakMinutes, 10) || 5)
      TimerCore.TimerState.setPomodoroCycles(parseInt(cycles, 10) || 4)
      TimerCore.TimerState.setPomodoroLongBreakMinutes(parseInt(longBreakMinutes, 10) || 15)
      return TimerCore.TimerState.statusText
    }

    function status(): string {
      return JSON.stringify({
        mode: TimerCore.TimerState.modeName,
        running: TimerCore.TimerState.running,
        completed: TimerCore.TimerState.completed,
        display: TimerCore.TimerState.displayText,
        status: TimerCore.TimerState.statusText,
        phase: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
          ? TimerCore.TimerState.pomodoroPhase.label
          : "",
        completedPomodoros: TimerCore.TimerState.mode === TimerCore.TimerState.pomodoroMode
          ? TimerCore.TimerState.pomodoroCompletedCycles
          : 0,
        sound: TimerCore.TimerState.pomodoroSoundEnabled
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical
      ? -1
      : timerRow.implicitWidth + button.scaledHorizontalMargin * 2
    active: TimerCore.TimerState.running
    tooltipText: TimerCore.TimerState.modeName + " · " + TimerCore.TimerState.statusText
    onPressed: function(b) {
      if (b === Qt.MiddleButton) TimerCore.TimerState.startPause()
      else if (b === Qt.RightButton) TimerCore.TimerState.reset()
      else root.toggle()
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: height / 2
      visible: root.alarmRinging
      color: root.alarmCueColor

      SequentialAnimation on opacity {
        running: root.alarmRinging
        loops: Animation.Infinite
        NumberAnimation { from: 0.12; to: 0.44; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.44; to: 0.12; duration: 700; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: height / 2
      visible: root.pomodoroSessionVisible
      color: Qt.rgba(
        root.pomodoroPhaseColor.r,
        root.pomodoroPhaseColor.g,
        root.pomodoroPhaseColor.b,
        TimerCore.TimerState.running ? 0.18 : 0.10
      )
    }

    Row {
      id: timerRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Text {
        text: root.pomodoroBreak ? "󰅶" : "◷"
        color: root.alarmRinging
          ? root.alarmCueColor
          : root.pomodoroSessionVisible
          ? root.pomodoroPhaseColor
          : button.active ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Math.round(Style.font.iconLarge * 1.15)
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: !root.vertical && TimerCore.TimerState.barTimeText !== ""
        text: TimerCore.TimerState.barTimeText
        textFormat: Text.PlainText
        color: root.alarmRinging
          ? root.alarmCueColor
          : root.pomodoroSessionVisible
          ? root.pomodoroPhaseColor
          : button.active ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}

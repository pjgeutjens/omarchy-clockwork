pragma Singleton

import QtQuick
import Quickshell

Item {
  id: root

  readonly property int stopwatchMode: 0
  readonly property int countdownMode: 1
  readonly property int intervalsMode: 2
  readonly property int alarmMode: 3
  readonly property int pomodoroMode: 4

  property int mode: stopwatchMode
  property bool running: false
  property bool completed: false
  property double startedAt: 0
  property double storedElapsedMs: 0
  property double nowMs: Date.now()
  property int notifiedIntervals: 0
  property int completionBellsRemaining: 0
  property string completionSoundFile: "complete.oga"
  property double alarmRingEndsAt: 0

  property int countdownMinutes: 5
  property int countdownSeconds: 0
  property bool countdownFullscreenEnabled: false
  property string countdownMessage: "Take a break"
  property int intervalRounds: 8
  property int intervalMinutes: 0
  property int intervalSeconds: 30
  property int alarmHour: 7
  property int alarmMinute: 0
  property bool alarmUses12Hour: false
  property string alarmSound: "alarm-clock-elapsed.oga"
  property string alarmMessage: "Alarm"
  property double alarmTargetAt: 0
  property int alarmTargetDurationMs: 0
  property int pomodoroWorkMinutes: 25
  property int pomodoroShortBreakMinutes: 5
  property int pomodoroCycles: 4
  property int pomodoroLongBreakMinutes: 15
  property bool pomodoroSoundEnabled: true
  property color pomodoroBreakColor: "#a6e3a1"
  property string pomodoroPhaseKind: "focus"
  property int pomodoroCurrentCycle: 1
  property int pomodoroCompletedCycles: 0
  property bool pomodoroSessionStarted: false

  readonly property int intervalDurationMs: Math.max(1000, intervalMinutes * 60000 + intervalSeconds * 1000)
  readonly property string intervalDurationText: pad2(intervalMinutes) + ":" + pad2(intervalSeconds)
  readonly property double pomodoroWorkMs: Math.max(1, pomodoroWorkMinutes) * 60000
  readonly property double pomodoroShortBreakMs: Math.max(1, pomodoroShortBreakMinutes) * 60000
  readonly property double pomodoroLongBreakMs: Math.max(1, pomodoroLongBreakMinutes) * 60000
  readonly property double pomodoroPhaseDurationMs: pomodoroPhaseKind === "long-break"
    ? pomodoroLongBreakMs
    : pomodoroPhaseKind === "short-break"
      ? pomodoroShortBreakMs
      : pomodoroWorkMs
  readonly property double targetMs: mode === countdownMode
    ? Math.max(0, countdownMinutes * 60000 + countdownSeconds * 1000)
    : mode === intervalsMode
      ? Math.max(1, intervalRounds) * intervalDurationMs
      : mode === alarmMode
        ? alarmTargetDurationMs
        : mode === pomodoroMode
          ? pomodoroPhaseDurationMs
          : 0
  readonly property double elapsedMs: Math.max(0, Math.round(running ? storedElapsedMs + nowMs - startedAt : storedElapsedMs))
  readonly property var pomodoroPhase: ({
    index: pomodoroCompletedCycles * 2 + (pomodoroPhaseKind === "focus" ? 0 : 1),
    kind: pomodoroPhaseKind,
    cycle: pomodoroCurrentCycle,
    label: pomodoroPhaseKind === "focus"
      ? "Focus " + pomodoroCurrentCycle + " of " + pomodoroCycles
      : pomodoroPhaseKind === "long-break"
        ? "Long break"
        : "Short break · Cycle " + pomodoroCurrentCycle + " of " + pomodoroCycles,
    durationMs: pomodoroPhaseDurationMs,
    elapsedMs: Math.min(elapsedMs, pomodoroPhaseDurationMs),
    remainingMs: Math.max(0, pomodoroPhaseDurationMs - elapsedMs)
  })
  readonly property double displayMs: mode === stopwatchMode
    ? elapsedMs
    : mode === pomodoroMode
      ? pomodoroPhase.remainingMs
      : Math.max(0, targetMs - elapsedMs)
  readonly property real progress: mode === stopwatchMode
    ? 0
    : mode === pomodoroMode
      ? pomodoroPhase.durationMs > 0
        ? Math.min(1, pomodoroPhase.elapsedMs / pomodoroPhase.durationMs)
        : 0
      : targetMs > 0 ? Math.min(1, elapsedMs / targetMs) : 0
  readonly property int currentRound: mode === intervalsMode
    ? Math.min(Math.max(1, intervalRounds), Math.floor(elapsedMs / intervalDurationMs) + 1)
    : 0
  readonly property int alarmDisplayHour: alarmUses12Hour
    ? (alarmHour % 12 === 0 ? 12 : alarmHour % 12)
    : alarmHour
  readonly property string alarmMeridiem: alarmHour >= 12 ? "PM" : "AM"
  readonly property string alarmSoundName: alarmSound === "bell.oga"
    ? "Bell"
    : alarmSound === "phone-incoming-call.oga"
      ? "Phone"
      : "Alarm clock"
  readonly property string alarmTimeText: alarmUses12Hour
    ? alarmDisplayHour + ":" + pad2(alarmMinute) + " " + alarmMeridiem
    : pad2(alarmHour) + ":" + pad2(alarmMinute)
  readonly property string modeName: mode === stopwatchMode
    ? "Stopwatch"
    : mode === countdownMode
      ? "Countdown"
      : mode === intervalsMode
        ? "Intervals"
        : mode === alarmMode
          ? "Alarm"
          : "Pomodoro"
  readonly property string statusText: {
    if (completed) {
      if (mode === intervalsMode) return "Workout complete"
      if (mode === alarmMode) return "Alarm ringing"
      if (mode === pomodoroMode) return "Pomodoro complete"
      return "Time is up"
    }
    if (mode === alarmMode) return running ? "Armed for " + alarmTimeText : "Ready"
    if (mode === pomodoroMode) {
      if (running) return pomodoroPhase.label
      if (pomodoroSessionStarted) return "Paused · " + pomodoroPhase.label
      return pomodoroCycles + " cycles · " + pomodoroWorkMinutes + " / " + pomodoroShortBreakMinutes + " min"
    }
    if (mode === intervalsMode)
      return "Round " + currentRound + " of " + intervalRounds + " · " + intervalDurationText
    if (running) return mode === stopwatchMode ? "Counting up" : "Counting down"
    if (storedElapsedMs > 0) return "Paused"
    return "Ready"
  }
  readonly property string displayText: mode === alarmMode && !running && storedElapsedMs === 0 && !completed
    ? alarmTimeText
    : formatTime(displayMs, mode === stopwatchMode)
  readonly property string barTimeText: running || storedElapsedMs > 0 || completed
    || (mode === pomodoroMode && pomodoroSessionStarted)
    ? formatTime(displayMs, false)
    : ""

  function formatTime(milliseconds, showCentiseconds) {
    var safeMilliseconds = Math.max(0, Math.floor(milliseconds))
    var totalSeconds = showCentiseconds || mode === stopwatchMode
      ? Math.floor(safeMilliseconds / 1000)
      : Math.ceil(milliseconds / 1000)
    var hours = Math.floor(totalSeconds / 3600)
    var minutes = Math.floor((totalSeconds % 3600) / 60)
    var seconds = totalSeconds % 60
    var mm = minutes < 10 ? "0" + minutes : String(minutes)
    var ss = seconds < 10 ? "0" + seconds : String(seconds)
    var result = hours > 0 ? hours + ":" + mm + ":" + ss : mm + ":" + ss
    if (!showCentiseconds) return result
    var centiseconds = Math.floor((safeMilliseconds % 1000) / 10)
    return result + "." + (centiseconds < 10 ? "0" : "") + centiseconds
  }

  function pad2(value) {
    return value < 10 ? "0" + value : String(value)
  }

  function selectMode(nextMode) {
    nextMode = Math.max(stopwatchMode, Math.min(pomodoroMode, Number(nextMode)))
    if (nextMode === mode) return
    mode = nextMode
    reset()
  }

  function startPause() {
    if (running) {
      if (mode === alarmMode) {
        reset()
        return
      }
      pause()
      return
    }
    if (completed) reset()
    if (mode === alarmMode) prepareAlarm()
    if (mode !== stopwatchMode && targetMs <= 0) return
    if (mode === pomodoroMode) pomodoroSessionStarted = true
    nowMs = Date.now()
    startedAt = nowMs
    running = true
  }

  function pause() {
    if (!running) return
    nowMs = Date.now()
    storedElapsedMs = elapsedMs
    running = false
  }

  function reset() {
    running = false
    completed = false
    alarmRingTimer.stop()
    alarmRingEndsAt = 0
    storedElapsedMs = 0
    notifiedIntervals = 0
    nowMs = Date.now()
    startedAt = nowMs
    if (mode === alarmMode) {
      alarmTargetAt = 0
      alarmTargetDurationMs = 0
    }
    if (mode === pomodoroMode) {
      pomodoroPhaseKind = "focus"
      pomodoroCurrentCycle = 1
      pomodoroCompletedCycles = 0
      pomodoroSessionStarted = false
    }
  }

  function setCountdownMinutes(value) {
    countdownMinutes = Math.max(0, Math.min(999, Number(value)))
    reset()
  }

  function setCountdownSeconds(value) {
    countdownSeconds = Math.max(0, Math.min(59, Number(value)))
    reset()
  }

  function setCountdownFullscreenEnabled(enabled) {
    countdownFullscreenEnabled = Boolean(enabled)
  }

  function setCountdownMessage(message) {
    var cleaned = String(message || "").trim()
    countdownMessage = cleaned === "" ? "Take a break" : cleaned
  }

  function setAlarmHour(value) {
    alarmHour = Math.max(0, Math.min(23, Number(value)))
    reset()
  }

  function setAlarmDisplayHour(value) {
    var hour = Math.max(1, Math.min(12, Number(value)))
    alarmHour = (hour % 12) + (alarmHour >= 12 ? 12 : 0)
    reset()
  }

  function setAlarmMeridiem(value) {
    var hour = alarmHour % 12
    alarmHour = hour + (String(value).toUpperCase() === "PM" ? 12 : 0)
    reset()
  }

  function setAlarmUses12Hour(enabled) {
    alarmUses12Hour = Boolean(enabled)
  }

  function setAlarmSound(value) {
    var next = String(value || "")
    if (next !== "bell.oga" && next !== "phone-incoming-call.oga")
      next = "alarm-clock-elapsed.oga"
    alarmSound = next
  }

  function cycleAlarmSound(direction) {
    var sounds = ["alarm-clock-elapsed.oga", "bell.oga", "phone-incoming-call.oga"]
    var index = sounds.indexOf(alarmSound)
    if (index < 0) index = 0
    setAlarmSound(sounds[(index + direction + sounds.length) % sounds.length])
  }

  function setAlarmMinute(value) {
    alarmMinute = Math.max(0, Math.min(59, Number(value)))
    reset()
  }

  function setAlarmMessage(message) {
    var cleaned = String(message || "").trim()
    alarmMessage = cleaned === "" ? "Alarm" : cleaned
  }

  function prepareAlarm() {
    var current = Date.now()
    var target = new Date(current)
    target.setHours(alarmHour, alarmMinute, 0, 0)
    if (target.getTime() <= current) target.setDate(target.getDate() + 1)
    alarmTargetAt = target.getTime()
    alarmTargetDurationMs = Math.max(1, Math.round(alarmTargetAt - current))
    storedElapsedMs = 0
    completed = false
  }

  function setPomodoroWorkMinutes(value) {
    pomodoroWorkMinutes = Math.max(1, Math.min(999, Number(value)))
    reset()
  }

  function setPomodoroShortBreakMinutes(value) {
    pomodoroShortBreakMinutes = Math.max(1, Math.min(999, Number(value)))
    reset()
  }

  function setPomodoroCycles(value) {
    pomodoroCycles = Math.max(1, Math.min(99, Number(value)))
    reset()
  }

  function setPomodoroLongBreakMinutes(value) {
    pomodoroLongBreakMinutes = Math.max(1, Math.min(999, Number(value)))
    reset()
  }

  function setPomodoroSoundEnabled(enabled) {
    pomodoroSoundEnabled = Boolean(enabled)
  }

  function setPomodoroBreakColor(value) {
    pomodoroBreakColor = String(value || "#a6e3a1")
  }

  function configurePomodoro(workMinutes, shortBreakMinutes, cycles, longBreakMinutes, soundEnabled, breakColor) {
    var nextWork = Math.max(1, Math.min(999, Number(workMinutes)))
    var nextShort = Math.max(1, Math.min(999, Number(shortBreakMinutes)))
    var nextCycles = Math.max(1, Math.min(99, Number(cycles)))
    var nextLong = Math.max(1, Math.min(999, Number(longBreakMinutes)))
    var changed = nextWork !== pomodoroWorkMinutes
      || nextShort !== pomodoroShortBreakMinutes
      || nextCycles !== pomodoroCycles
      || nextLong !== pomodoroLongBreakMinutes
    pomodoroWorkMinutes = nextWork
    pomodoroShortBreakMinutes = nextShort
    pomodoroCycles = nextCycles
    pomodoroLongBreakMinutes = nextLong
    pomodoroSoundEnabled = Boolean(soundEnabled)
    pomodoroBreakColor = String(breakColor || "#a6e3a1")
    if (changed && mode === pomodoroMode) reset()
  }

  function beginPomodoroPhase(kind, cycle, autoRun) {
    pomodoroPhaseKind = kind
    pomodoroCurrentCycle = Math.max(1, Math.min(pomodoroCycles, Number(cycle)))
    storedElapsedMs = 0
    nowMs = Date.now()
    startedAt = nowMs
    running = Boolean(autoRun)
    completed = false
    pomodoroSessionStarted = true
  }

  function skipPomodoroPhase() {
    if (mode !== pomodoroMode || !pomodoroSessionStarted || completed) return
    if (pomodoroPhaseKind === "focus") {
      beginPomodoroPhase("short-break", pomodoroCurrentCycle, true)
      notify("Focus skipped · Short break starts now")
      return
    }
    if (pomodoroPhaseKind === "short-break") {
      beginPomodoroPhase("focus", pomodoroCompletedCycles + 1, false)
      notify("Break skipped · Ready for focus " + pomodoroCurrentCycle)
      return
    }
    finishPomodoroCycle(false)
  }

  function completePomodoroPhase() {
    if (pomodoroPhaseKind === "focus") {
      pomodoroCompletedCycles = Math.min(pomodoroCycles, pomodoroCompletedCycles + 1)
      var longBreak = pomodoroCompletedCycles >= pomodoroCycles
      beginPomodoroPhase(longBreak ? "long-break" : "short-break", pomodoroCompletedCycles, true)
      playPomodoroSound()
      notify(longBreak
        ? "Focus " + pomodoroCompletedCycles + " complete · Long break starts now"
        : "Focus " + pomodoroCompletedCycles + " complete · Short break starts now")
      return
    }
    if (pomodoroPhaseKind === "long-break") {
      finishPomodoroCycle(true)
      return
    }
    beginPomodoroPhase("focus", pomodoroCompletedCycles + 1, false)
    playPomodoroSound()
    notify("Break complete · Ready for focus " + pomodoroCurrentCycle)
  }

  function finishPomodoroCycle(withSound) {
    storedElapsedMs = pomodoroPhaseDurationMs
    running = false
    completed = true
    pomodoroSessionStarted = true
    if (withSound) playCompletionSequence()
    notify("All " + pomodoroCycles + " focus cycles complete")
  }

  function setIntervalRounds(value) {
    intervalRounds = Math.max(1, Math.min(999, Number(value)))
    reset()
  }

  function setIntervalMinutes(value) {
    intervalMinutes = Math.max(0, Math.min(999, Number(value)))
    if (intervalMinutes === 0 && intervalSeconds === 0) intervalSeconds = 1
    reset()
  }

  function setIntervalSeconds(value) {
    intervalSeconds = Math.max(0, Math.min(59, Number(value)))
    if (intervalMinutes === 0 && intervalSeconds === 0) intervalSeconds = 1
    reset()
  }

  function tick() {
    nowMs = Date.now()
    if (!running || mode === stopwatchMode) return

    if (mode === intervalsMode) {
      var passed = Math.min(intervalRounds, Math.floor(elapsedMs / intervalDurationMs))
      if (passed > notifiedIntervals && passed < intervalRounds) {
        notifiedIntervals = passed
        playSound("complete.oga")
        notify("Round " + passed + " complete · Round " + (passed + 1) + " starts now")
      }
    }

    if (mode === pomodoroMode && elapsedMs >= targetMs) {
      completePomodoroPhase()
      return
    }

    if (elapsedMs >= targetMs) finish()
  }

  function finish() {
    if (!running) return
    storedElapsedMs = targetMs
    running = false
    completed = true
    notifiedIntervals = mode === intervalsMode ? intervalRounds : notifiedIntervals
    if (mode === alarmMode) startAlarmRinging()
    else playCompletionSequence("complete.oga")
    notify(mode === intervalsMode
      ? "All " + intervalRounds + " rounds complete"
      : mode === alarmMode
        ? alarmMessage
        : "Countdown complete")
  }

  function playSound(soundFile) {
    Quickshell.execDetached([
      "pw-play",
      "--volume", "1.0",
      "/usr/share/sounds/freedesktop/stereo/" + soundFile
    ])
  }

  function startAlarmRinging() {
    alarmRingTimer.stop()
    alarmRingEndsAt = Date.now() + 3 * 60 * 1000
    playSound(alarmSound)
    alarmRingTimer.start()
  }

  function playCompletionSequence(soundFile) {
    if (mode === pomodoroMode && !pomodoroSoundEnabled) return
    completionBellTimer.stop()
    completionSoundFile = soundFile || "complete.oga"
    completionBellsRemaining = 3
    playNextCompletionBell()
  }

  function playPomodoroSound() {
    if (pomodoroSoundEnabled) playSound("complete.oga")
  }

  function playNextCompletionBell() {
    if (completionBellsRemaining <= 0) return
    playSound(completionSoundFile)
    completionBellsRemaining -= 1
    if (completionBellsRemaining > 0) completionBellTimer.restart()
  }

  function notify(message) {
    Quickshell.execDetached([
      "omarchy-notification-send",
      "-g", "◷",
      "Clockwork",
      message
    ])
  }

  Timer {
    interval: root.mode === root.stopwatchMode ? 10 : 100
    repeat: true
    running: root.running
    onTriggered: root.tick()
  }

  Timer {
    id: completionBellTimer
    interval: 625
    repeat: false
    onTriggered: root.playNextCompletionBell()
  }

  Timer {
    id: alarmRingTimer
    interval: 3000
    repeat: true
    onTriggered: {
      if (Date.now() >= root.alarmRingEndsAt) {
        stop()
        return
      }
      root.playSound(root.alarmSound)
    }
  }
}

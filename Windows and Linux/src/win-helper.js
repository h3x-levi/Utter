// One long-lived PowerShell process answers what Electron can't see on Windows: which app has
// focus and whether it takes text (for the island), and pausing or resuming media players.
// Every call fails open: on a timeout or error the caller behaves as if the helper weren't there.
const { spawn } = require('node:child_process')

const SCRIPT = String.raw`
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Runtime.WindowsRuntime
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class UtterForeground {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
'@
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation' + [char]96 + '1'
} | Select-Object -First 1
function Wait-Operation($operation, [Type]$type) {
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
  if ($task.Wait(3000)) { $task.Result } else { throw 'timed out' }
}
$script:manager = $null
$script:pausedIds = @()
function Get-MediaManager {
  if (-not $script:manager) {
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $script:manager = Wait-Operation ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
  }
  $script:manager
}
function Get-Focus {
  $processId = [uint32]0
  [void][UtterForeground]::GetWindowThreadProcessId([UtterForeground]::GetForegroundWindow(), [ref]$processId)
  $editable = $true
  try {
    $element = [System.Windows.Automation.AutomationElement]::FocusedElement
    $type = $element.Current.ControlType
    $value = $null
    $hasValue = $element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)
    $textType = $type -eq [System.Windows.Automation.ControlType]::Edit -or $type -eq [System.Windows.Automation.ControlType]::Document -or $type -eq [System.Windows.Automation.ControlType]::ComboBox
    $editable = (-not $element.Current.IsPassword) -and ($textType -or ($hasValue -and -not $value.Current.IsReadOnly))
  } catch { $editable = $true }
  '{"pid":' + $processId + ',"editable":' + $editable.ToString().ToLower() + '}'
}
function Suspend-Media {
  $script:pausedIds = @()
  foreach ($session in (Get-MediaManager).GetSessions()) {
    if ($session.GetPlaybackInfo().PlaybackStatus -eq 'Playing') {
      [void](Wait-Operation ($session.TryPauseAsync()) ([bool]))
      $script:pausedIds += $session.SourceAppUserModelId
    }
  }
  '{"paused":' + $script:pausedIds.Count + '}'
}
function Resume-Media {
  foreach ($session in (Get-MediaManager).GetSessions()) {
    if ($script:pausedIds -contains $session.SourceAppUserModelId) { [void](Wait-Operation ($session.TryPlayAsync()) ([bool])) }
  }
  $script:pausedIds = @()
  '{"ok":true}'
}
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  $id, $command = $line.Split(' ', 2)
  try {
    $reply = switch ($command) {
      'focus' { Get-Focus }
      'media-pause' { Suspend-Media }
      'media-resume' { Resume-Media }
      default { '{}' }
    }
  } catch { $reply = '{"error":true}' }
  [Console]::Out.WriteLine($id + ' ' + $reply)
  [Console]::Out.Flush()
}
`

let child = null
let buffer = ''
let nextId = 1
const waiting = new Map()

function start() {
  child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand',
    Buffer.from(SCRIPT, 'utf16le').toString('base64')], { windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'] })
  child.stdout.setEncoding('utf8')
  child.stdout.on('data', (data) => {
    buffer += data
    let newline
    while ((newline = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, newline).trim()
      buffer = buffer.slice(newline + 1)
      const space = line.indexOf(' ')
      waiting.get(line.slice(0, space))?.(line.slice(space + 1))
    }
  })
  const reset = () => { child = null; [...waiting.values()].forEach((resolve) => resolve(null)) }
  child.on('exit', reset)
  child.on('error', reset)
}

function ask(command, timeout = 1500) {
  if (process.platform !== 'win32') return Promise.resolve(null)
  if (!child) start()
  const id = String(nextId++)
  return new Promise((resolve) => {
    const finish = (line) => {
      if (!waiting.delete(id)) return
      try { resolve(line && JSON.parse(line)) } catch { resolve(null) }
    }
    waiting.set(id, finish)
    child.stdin.write(`${id} ${command}\n`)
    setTimeout(() => finish(null), timeout)
  })
}

module.exports = { ask, stop: () => child?.kill(), SCRIPT }

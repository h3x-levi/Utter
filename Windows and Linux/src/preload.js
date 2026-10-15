const { contextBridge, ipcRenderer } = require('electron')

const invoke = (channel) => (...args) => ipcRenderer.invoke(channel, ...args)

contextBridge.exposeInMainWorld('utter', {
  platform: process.platform,

  // Library window: main owns every file; it sends the full state after each change.
  getState: invoke('state:get'),
  onState: (fn) => ipcRenderer.on('state', (_e, state) => fn(state)),
  onShow: (fn) => ipcRenderer.on('show', (_e, view) => fn(view)),
  setSetting: invoke('settings:set'),
  setWords: invoke('words:set'),
  setSnippets: invoke('snippets:set'),
  deleteTrack: invoke('history:delete'),
  restoreTrack: invoke('history:restore'),
  trackToNote: invoke('history:toNote'),
  createNote: invoke('note:create'),
  updateNote: invoke('note:update'),
  deleteNote: invoke('note:delete'),
  restoreNote: invoke('note:restore'),
  setOpenNote: invoke('note:open'),
  renameSpeaker: invoke('note:renameSpeaker'),
  pasteAgain: invoke('paste:again'),
  copy: invoke('clipboard:copy'),
  handsFree: invoke('dictation:handsFree'),
  dictateIntoNote: invoke('dictation:note'),
  meeting: invoke('meeting'),
  exportItems: invoke('export'),
  reset: invoke('reset'),
  openExternal: invoke('open:external'),
  about: invoke('about'),
  showView: invoke('view:show'),
  closeWindow: invoke('window:close'),
  fitWindow: (height) => ipcRenderer.send('window:fit', height),
  quit: invoke('app:quit'),
  finishOnboarding: invoke('onboarding:done'),
  signIn: invoke('account:signIn'),
  signOut: invoke('account:signOut'),
  signInEmail: invoke('account:signInEmail'),
  skipSignIn: invoke('account:skip'),
  downloadModel: invoke('model:download'),
  removeModel: invoke('model:remove'),
  selectModel: invoke('model:select'),
  crashReports: invoke('crash:list'),
  showCrashFolder: invoke('crash:show'),
  dismissOffer: invoke('offer:dismiss'),

  // Companion robot window and its Settings tab.
  companion: (command, ...args) => ipcRenderer.invoke('companion', command, ...args),
  onCompanion: (fn) => ipcRenderer.on('companion:state', (_e, state) => fn(state)),

  // Pill window: it owns the microphone and system-audio capture.
  onPill: (fn) => ipcRenderer.on('pill', (_e, pill) => fn(pill)),
  onCapture: (fn) => ipcRenderer.on('capture', (_e, command) => fn(command)),
  sendPCM: (stream, buffer) => ipcRenderer.send('pcm', stream, buffer),
  captureEvent: (event) => ipcRenderer.send('capture:event', event),
  pillMouse: (event) => ipcRenderer.send('pill:mouse', event),
})

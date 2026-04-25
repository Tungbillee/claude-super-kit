---
name: sk:electron-apps
description: "Electron main/renderer architecture, IPC, preload/contextBridge, native modules, auto-updater, code signing, security checklist"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: desktop
last_updated: 2026-04-25
license: MIT
---

# sk:electron-apps — Electron Desktop Development

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  Main Process (Node.js full access)             │
│  main.ts → BrowserWindow, Menu, Tray, IPC       │
│            native modules, file system, updater │
└──────────────────┬──────────────────────────────┘
                   │ contextBridge (allowlist only)
┌──────────────────▼──────────────────────────────┐
│  Preload Script (bridge)                        │
│  preload.ts → exposes safe API via              │
│               contextBridge.exposeInMainWorld   │
└──────────────────┬──────────────────────────────┘
                   │ window.electronAPI (typed)
┌──────────────────▼──────────────────────────────┐
│  Renderer Process (browser sandbox)             │
│  React / Vue / Svelte SPA                       │
│  NO nodeIntegration, NO direct Node access      │
└─────────────────────────────────────────────────┘
```

## Main Process Setup

```typescript
// src/main/main.ts
import { app, BrowserWindow, ipcMain, Menu, shell } from 'electron'
import path from 'node:path'
import { setupAutoUpdater } from './auto-updater'

let main_window: BrowserWindow | null = null

function createWindow() {
  main_window = new BrowserWindow({
    width: 1280,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,   // MANDATORY — isolate renderer
      nodeIntegration: false,   // MANDATORY — no Node in renderer
      sandbox: true,            // extra hardening
      webSecurity: true
    }
  })

  if (process.env.NODE_ENV === 'development') {
    main_window.loadURL('http://localhost:5173')
    main_window.webContents.openDevTools()
  } else {
    main_window.loadFile(path.join(__dirname, '../renderer/index.html'))
  }

  main_window.on('closed', () => { main_window = null })
}

app.whenReady().then(() => {
  createWindow()
  setupIpcHandlers()
  setupAutoUpdater(main_window!)
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
```

## Preload + contextBridge

```typescript
// src/preload/preload.ts
import { contextBridge, ipcRenderer } from 'electron'

// Type-safe API surface — only expose what renderer needs
contextBridge.exposeInMainWorld('electronAPI', {
  // invoke = request/response (promise)
  readFile: (path: string) => ipcRenderer.invoke('file:read', path),
  writeFile: (path: string, content: string) =>
    ipcRenderer.invoke('file:write', path, content),
  openFileDialog: () => ipcRenderer.invoke('dialog:openFile'),

  // on = subscribe to main→renderer push events
  onUpdateAvailable: (cb: (info: UpdateInfo) => void) => {
    ipcRenderer.on('update:available', (_event, info) => cb(info))
    return () => ipcRenderer.removeAllListeners('update:available') // cleanup
  },

  // send = fire-and-forget
  logEvent: (event: string) => ipcRenderer.send('analytics:log', event)
})

// Global type augmentation for renderer TypeScript
declare global {
  interface Window {
    electronAPI: typeof import('./preload').electronAPI
  }
}
```

## IPC Handlers (Main Process)

```typescript
// src/main/ipc-handlers.ts
import { ipcMain, dialog, BrowserWindow } from 'electron'
import fs from 'node:fs/promises'

export function setupIpcHandlers() {
  // invoke/handle — request/response pattern
  ipcMain.handle('file:read', async (_event, file_path: string) => {
    try {
      return { ok: true, content: await fs.readFile(file_path, 'utf-8') }
    } catch (e) {
      return { ok: false, error: (e as Error).message }
    }
  })

  ipcMain.handle('file:write', async (_event, file_path: string, content: string) => {
    try {
      await fs.writeFile(file_path, content, 'utf-8')
      return { ok: true }
    } catch (e) {
      return { ok: false, error: (e as Error).message }
    }
  })

  ipcMain.handle('dialog:openFile', async (event) => {
    const window = BrowserWindow.fromWebContents(event.sender)!
    const result = await dialog.showOpenDialog(window, {
      properties: ['openFile'],
      filters: [{ name: 'All Files', extensions: ['*'] }]
    })
    return result.canceled ? null : result.filePaths[0]
  })

  // send/on — fire-and-forget
  ipcMain.on('analytics:log', (_event, event_name: string) => {
    console.log('[analytics]', event_name)
  })
}
```

## IPC from Renderer

```typescript
// src/renderer/services/electron-bridge.ts
// Typed wrappers around window.electronAPI

export async function readFile(path: string) {
  if (!window.electronAPI) throw new Error('Not running in Electron')
  const result = await window.electronAPI.readFile(path)
  if (!result.ok) throw new Error(result.error)
  return result.content
}

export function subscribeToUpdates(cb: (info: UpdateInfo) => void) {
  return window.electronAPI.onUpdateAvailable(cb) // returns cleanup fn
}
```

## Native Module: better-sqlite3

```typescript
// src/main/db/database.ts
import Database from 'better-sqlite3'
import path from 'node:path'
import { app } from 'electron'

// Store DB in userData (persists across app updates)
const DB_PATH = path.join(app.getPath('userData'), 'app.db')

let db_instance: Database.Database | null = null

export function getDb(): Database.Database {
  if (!db_instance) {
    db_instance = new Database(DB_PATH)
    db_instance.pragma('journal_mode = WAL')  // better concurrent perf
    db_instance.pragma('foreign_keys = ON')
    runMigrations(db_instance)
  }
  return db_instance
}

function runMigrations(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER DEFAULT (unixepoch())
    )
  `)
}

// Typed queries
export const queries = {
  getSetting: (db: Database.Database) =>
    db.prepare<[string], { value: string }>('SELECT value FROM settings WHERE key = ?'),
  setSetting: (db: Database.Database) =>
    db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)')
}
```

## Auto-Updater (electron-updater)

```typescript
// src/main/auto-updater.ts
import { autoUpdater } from 'electron-updater'
import type { BrowserWindow } from 'electron'
import log from 'electron-log'

export function setupAutoUpdater(window: BrowserWindow) {
  autoUpdater.logger = log
  autoUpdater.autoDownload = true
  autoUpdater.autoInstallOnAppQuit = true

  autoUpdater.on('update-available', (info) => {
    window.webContents.send('update:available', info)
  })

  autoUpdater.on('update-downloaded', (info) => {
    window.webContents.send('update:downloaded', info)
    // Optionally prompt user then:
    // autoUpdater.quitAndInstall()
  })

  autoUpdater.on('error', (err) => {
    log.error('Update error:', err)
    window.webContents.send('update:error', err.message)
  })

  // Check on startup + every 4h
  autoUpdater.checkForUpdates()
  setInterval(() => autoUpdater.checkForUpdates(), 4 * 60 * 60 * 1000)
}
```

## electron-builder Config

```json
// electron-builder.json
{
  "appId": "com.company.appname",
  "productName": "App Name",
  "directories": { "output": "dist" },
  "files": ["dist-electron/**", "dist-renderer/**"],
  "publish": [{ "provider": "github", "owner": "org", "repo": "repo" }],
  "mac": {
    "category": "public.app-category.productivity",
    "hardenedRuntime": true,
    "gatekeeperAssess": false,
    "entitlements": "build/entitlements.mac.plist",
    "entitlementsInherit": "build/entitlements.mac.plist",
    "notarize": true
  },
  "win": {
    "target": [{ "target": "nsis", "arch": ["x64"] }],
    "signingHashAlgorithms": ["sha256"],
    "certificateSubjectName": "Your Company Name"
  },
  "nsis": {
    "oneClick": false,
    "allowToChangeInstallationDirectory": true
  }
}
```

## Security Checklist

| Item | Setting | Why |
|------|---------|-----|
| `nodeIntegration` | `false` | Prevent renderer Node access |
| `contextIsolation` | `true` | Isolate preload context |
| `sandbox` | `true` | OS-level process sandbox |
| `webSecurity` | `true` | Enforce same-origin |
| CSP header | Set via `session.defaultSession` | Block XSS |
| `allowRunningInsecureContent` | `false` | No mixed content |
| External links | `shell.openExternal()` only | No `target=_blank` in app |
| `enableRemoteModule` | Not used (removed Electron 14+) | Legacy attack vector |

```typescript
// CSP via session
app.whenReady().then(() => {
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
        ]
      }
    })
  })
})
```

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What Electron task?",
      header: "Task",
      options: [
        { label: "IPC setup", description: "Main ↔ Renderer communication" },
        { label: "Native module", description: "better-sqlite3, fs, etc." },
        { label: "Auto-updater", description: "electron-updater setup" },
        { label: "Build & sign", description: "electron-builder, code signing" }
      ]
    },
    {
      question: "Renderer framework?",
      header: "Renderer",
      options: [
        { label: "Vue 3 + Vite", description: "Composition API" },
        { label: "React + Vite", description: "Hooks-based" },
        { label: "Vanilla / Other", description: "No framework" }
      ]
    }
  ]
})
```

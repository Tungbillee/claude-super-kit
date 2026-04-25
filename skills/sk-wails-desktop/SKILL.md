---
name: sk:wails-desktop
description: "Wails v2 — Go + frontend desktop apps, Go bindings, IPC via EventsEmit/On, packaging, comparison vs Electron/Tauri"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: desktop
last_updated: 2026-04-25
license: MIT
---

# sk:wails-desktop — Wails v2 Desktop Development

## Architecture Overview

```
┌──────────────────────────────────────────────┐
│  Go Main Process                             │
│  main.go → wails.Run() → App struct          │
│  Business logic, file I/O, DB, system APIs  │
└──────────────┬───────────────────────────────┘
               │ Auto-generated JS bindings
               │ go:embed frontend/dist
┌──────────────▼───────────────────────────────┐
│  Frontend (Vue / React / Svelte)             │
│  Calls Go methods like async JS functions   │
│  window.go.App.MethodName(args)             │
└──────────────────────────────────────────────┘
```

## Project Initialization

```bash
# Install Wails CLI
go install github.com/wailsapp/wails/v2/cmd/wails@latest

# Create new project
wails init -n myapp -t vue-ts   # or react-ts, svelte, vanilla

# Dev mode (hot reload both sides)
wails dev

# Production build
wails build -platform darwin/universal   # macOS ARM + x86
wails build -platform windows/amd64
wails build -platform linux/amd64
```

## Go App Struct — Binding Methods

```go
// app.go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "github.com/wailsapp/wails/v2/pkg/runtime"
)

type App struct {
    ctx context.Context
}

func NewApp() *App { return &App{} }

// OnStartup is called when app starts — store context for runtime calls
func (a *App) OnStartup(ctx context.Context) {
    a.ctx = ctx
}

// ---- Exported methods become JS callable ----
// Rules: exported, receiver *App, return (T, error) or just T

func (a *App) Greet(name string) string {
    return fmt.Sprintf("Hello %s!", name)
}

// Struct marshaling — Go struct → TS interface (auto-generated)
type FileInfo struct {
    Path    string `json:"path"`
    Size    int64  `json:"size"`
    IsDir   bool   `json:"is_dir"`
}

func (a *App) ReadDir(dir_path string) ([]FileInfo, error) {
    entries, err := os.ReadDir(dir_path)
    if err != nil {
        return nil, fmt.Errorf("readdir %s: %w", dir_path, err)
    }
    result := make([]FileInfo, 0, len(entries))
    for _, e := range entries {
        info, err := e.Info()
        if err != nil {
            continue
        }
        result = append(result, FileInfo{
            Path:  dir_path + "/" + e.Name(),
            Size:  info.Size(),
            IsDir: e.IsDir(),
        })
    }
    return result, nil
}

// Open native file dialog — uses runtime context
func (a *App) OpenFileDialog(title string, filters []runtime.FileFilter) (string, error) {
    path, err := runtime.OpenFileDialog(a.ctx, runtime.OpenDialogOptions{
        Title:   title,
        Filters: filters,
    })
    if err != nil {
        return "", err
    }
    return path, nil
}
```

## main.go — App Config

```go
// main.go
package main

import (
    "embed"
    "github.com/wailsapp/wails/v2"
    "github.com/wailsapp/wails/v2/pkg/options"
    "github.com/wailsapp/wails/v2/pkg/options/assetserver"
    "github.com/wailsapp/wails/v2/pkg/options/mac"
    "github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
    app := NewApp()

    err := wails.Run(&options.App{
        Title:  "My App",
        Width:  1280,
        Height: 800,
        AssetServer: &assetserver.Options{Assets: assets},
        OnStartup:   app.OnStartup,
        Bind:        []interface{}{app},  // expose to frontend
        Mac: &mac.Options{
            About: &mac.AboutInfo{Title: "My App", Message: "v1.0.0"},
        },
        Windows: &windows.Options{
            WebviewIsTransparent: false,
            WindowIsTranslucent:  false,
        },
    })
    if err != nil {
        println("Error:", err.Error())
    }
}
```

## Frontend: Calling Go Bindings

```typescript
// frontend/src/lib/go-bridge.ts
// Wails auto-generates bindings in frontend/wailsjs/go/
import { Greet, ReadDir, OpenFileDialog } from '../wailsjs/go/main/App'
import type { main } from '../wailsjs/go/models'

export async function greet(name: string): Promise<string> {
  return Greet(name)
}

export async function listDirectory(path: string): Promise<main.FileInfo[]> {
  try {
    return await ReadDir(path)
  } catch (e) {
    throw new Error(`Failed to read dir: ${e}`)
  }
}

export async function pickFile(): Promise<string | null> {
  const path = await OpenFileDialog('Select File', [
    { DisplayName: 'All Files', Pattern: '*.*' }
  ])
  return path || null
}
```

## Events — Go ↔ Frontend Push

```go
// Go → Frontend push event
import "github.com/wailsapp/wails/v2/pkg/runtime"

func (a *App) StartLongTask() {
    go func() {
        for i := 0; i <= 100; i += 10 {
            runtime.EventsEmit(a.ctx, "task:progress", map[string]int{"percent": i})
            time.Sleep(500 * time.Millisecond)
        }
        runtime.EventsEmit(a.ctx, "task:complete", nil)
    }()
}
```

```typescript
// Frontend subscribe to events
import { EventsOn, EventsOff } from '../wailsjs/runtime/runtime'

export function subscribeToProgress(cb: (pct: number) => void) {
  EventsOn('task:progress', (data: { percent: number }) => cb(data.percent))
  return () => EventsOff('task:progress') // cleanup
}
```

```typescript
// Frontend → Go event (less common, prefer direct binding calls)
import { EventsEmit } from '../wailsjs/runtime/runtime'
EventsEmit('frontend:ready')
```

## Menus & Tray

```go
// System tray
import "github.com/wailsapp/wails/v2/pkg/menu"

func (a *App) OnStartup(ctx context.Context) {
    a.ctx = ctx
    tray_menu := menu.NewMenu()
    tray_menu.Append(menu.Text("Show", nil, func(_ *menu.CallbackData) {
        runtime.WindowShow(ctx)
    }))
    tray_menu.Append(menu.Separator())
    tray_menu.Append(menu.Text("Quit", nil, func(_ *menu.CallbackData) {
        runtime.Quit(ctx)
    }))
    runtime.MenuSetApplicationMenu(ctx, tray_menu)
}
```

## wails.json Config

```json
{
  "name": "myapp",
  "outputfilename": "myapp",
  "assetdir": "frontend/dist",
  "frontend:install": "npm install",
  "frontend:build": "npm run build",
  "frontend:dev:watcher": "npm run dev",
  "frontend:dev:serverUrl": "http://localhost:5173",
  "author": { "name": "Dev", "email": "dev@example.com" }
}
```

## Comparison vs Electron/Tauri

| Aspect | Wails v2 | Electron | Tauri |
|--------|----------|----------|-------|
| Language | Go + JS/TS | Node.js + JS/TS | Rust + JS/TS |
| Bundle size | ~8–15 MB | ~80–150 MB | ~3–10 MB |
| Memory | Low (Go) | High (Chromium) | Very low (Rust) |
| Native APIs | Go stdlib | Node.js | Rust crates |
| Learning curve | Go + web | JS only | Rust + web |
| Ecosystem | Growing | Mature | Growing |
| Best for | Go teams | Web devs | Size-critical |
| SQLite | database/sql | better-sqlite3 | rusqlite |

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What Wails task?",
      header: "Task",
      options: [
        { label: "Go binding", description: "Expose Go method to frontend" },
        { label: "Events", description: "Push events between Go and JS" },
        { label: "File / dialog", description: "Native file picker, dialogs" },
        { label: "Build & package", description: "wails build for distribution" }
      ]
    },
    {
      question: "Frontend framework?",
      header: "Frontend",
      options: [
        { label: "Vue 3", description: "Composition API" },
        { label: "React", description: "Hooks-based" },
        { label: "Svelte", description: "Compiler-based" }
      ]
    }
  ]
})
```

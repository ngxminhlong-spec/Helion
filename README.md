# Helion

> A high-performance Remote Spy and Network Analysis tool for the Roblox platform.

Helion monitors, intercepts, and analyzes all network traffic between the Roblox client and server — covering both **RemoteEvents** and **RemoteFunctions** — across the main Luau thread and parallel Actor threads.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Execution](#execution)
  - [Option A — Pre-built bundle (recommended)](#option-a--pre-built-bundle-recommended)
  - [Option B — Virtual Loader (live from source)](#option-b--virtual-loader-live-from-source)
  - [Option C — Custom URL override](#option-c--custom-url-override)
- [Setup & Building from Source](#setup--building-from-source)
  - [Prerequisites](#prerequisites)
  - [Install toolchain](#install-toolchain)
  - [Build commands](#build-commands)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
  - [Boot sequence](#boot-sequence)
  - [Network interception](#network-interception)
  - [Virtual require system (VirtualLoader)](#virtual-require-system-virtualloader)
- [Module Documentation](#module-documentation)
  - [Core — init.client.luau](#core--initclientluau)
  - [ExecutorSupport](#executorsupport)
  - [Window](#window)
  - [Network/Init](#networkinit)
  - [Network/Hooks/Default/Outgoing](#networkhooksdefaultoutgoing)
  - [Network/Hooks/Default/Incoming](#networkhooksdefaultincoming)
  - [Components/Interface](#componentsinterface)
  - [Components/Highlighter](#componentshighlighter)
  - [Components/Sonner](#componentssonner)
  - [Components/AssetManager & Icons](#componentsassetmanager--icons)
  - [Components/Drag & Resize](#componentsdrag--resize)
  - [Components/Animations](#componentsanimations)
  - [Lib/CodeGen/Generator](#libcodegengenerator)
  - [Lib/CodeGen/SessionExporter](#libcodegenSessionExporter)
  - [Lib/Serializer/LuaEncode](#libserializerluaencode)
  - [Lib/SaveManager](#libsavemanager)
  - [Lib/FileLog](#libfilelog)
  - [Lib/FileHelper](#libfilehelper)
  - [Lib/Hooking](#libhooking)
  - [Lib/Connect](#libconnect)
  - [Lib/Signal](#libsignal)
  - [Lib/Decompile](#libdecompile)
  - [Lib/Pagination](#libpagination)
  - [Lib/Log](#liblog)
  - [Lib/Anticheats/Main](#libanticheatsMain)
  - [Lib/Anticheats/impl/Adonis](#libanticheatsimpladonis)
  - [Extensions/Manager](#extensionsmanager)
- [Executor Compatibility](#executor-compatibility)
- [Known Executor Quirks](#known-executor-quirks)
- [File Layout Reference](#file-layout-reference)

---

## Features

| Feature | Description |
|---|---|
| **Outgoing spy** | Intercepts `FireServer`, `InvokeServer`, `FireAllClients`, and all remote variants |
| **Incoming spy** | Intercepts `OnClientEvent`, `OnServerEvent`, `OnInvoke` callbacks |
| **Actor support** | Hooks parallel Luau threads via `run_on_actor` so remotes in Actors are never missed |
| **Code generation** | Produces copy-paste Luau code to replay or hook any intercepted call |
| **Session export** | Exports the full session as a self-contained HTML file for offline analysis |
| **Syntax highlighting** | Luau syntax highlighted display for all remote arguments |
| **Extension API** | Plugin system for adding custom tabs, interceptors, and context menu items |
| **Anticheat bypass** | Built-in bypass for Adonis and generic actor-parallel detection |
| **Settings persistence** | Saves all user settings to `Helion/Settings.json` across sessions |
| **Executor detection** | Auto-detects executor capabilities and adapts behaviour accordingly |

---

## Requirements

- A Roblox executor that supports the following functions:
  - **Essential:** `hookmetamethod`, `getrawmetatable`, `newcclosure`, `checkcaller`, `getcallingscript`, `cloneref`, `getnamecallmethod`
  - **For Actor support:** `run_on_actor`, `create_comm_channel`, `getactors`
  - **Recommended:** `hookfunction`, `restorefunction`, `isfunctionhooked`, `oth` library, `setstackhidden`
- HTTP requests enabled in your executor (`game:HttpGet` must work)

---

## Execution

### Option A — Pre-built bundle (recommended)

Paste this one-liner into your executor. It downloads and runs the fully bundled, self-contained script directly from GitHub:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/Loader.luau"))()
```

The loader fetches `Distribution/Script.luau` — a single file containing every module bundled together. Nothing is written to disk.

---

### Option B — Virtual Loader (live from source)

This loader downloads every individual source file from GitHub into RAM at runtime, then boots Helion using a virtual `require` system. Useful if you want to run the latest source code without rebuilding.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/VirtualLoader.luau"))()
```

**How it works:**
1. All `.luau` files under `Src/` are fetched from GitHub raw URLs into a RAM table
2. A virtual `script` proxy mimics the Roblox Instance hierarchy (`script.Parent`, `script.Lib.Signal`, etc.)
3. A custom `require()` resolves module paths against the RAM table, compiles with `loadstring`, and caches results
4. `init.client.luau` is executed as the entry point with the virtual environment injected

---

### Option C — Custom URL override

If you host the bundle yourself (CDN, private server, etc.), set `HELION_URL` before running the loader:

```lua
getgenv().HELION_URL = "https://your-cdn.example.com/Helion.luau"
loadstring(game:HttpGet("https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/Loader.luau"))()
```

---

## Setup & Building from Source

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| [Rokit](https://github.com/rojo-rbx/rokit) | 1.2.0+ | Toolchain manager |
| Lune | 0.8.9 | Runs the Wax build system |
| Rojo | 7.4.4 | Converts the source tree to an `.rbxm` model |
| Darklua | 0.16.0 | Optional minification |

### Install toolchain

All tools are managed by **Rokit**. Run these commands once from the repo root:

```bash
# 1. Install Rokit itself
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash

# 2. Trust and install all project tools
cd Helion
rokit install
```

If the Rokit installer fails (some Linux environments), install it manually:

```bash
curl -L https://github.com/rojo-rbx/rokit/releases/download/v1.2.0/rokit-1.2.0-linux-x86_64.zip -o /tmp/rokit.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/rokit.zip').extract('rokit', '/tmp/')"
chmod +x /tmp/rokit && mv /tmp/rokit ~/.local/bin/rokit
rokit trust lune-org/lune && rokit trust rojo-rbx/rojo && rokit trust seaofvoices/darklua
cd Helion && rokit install
```

### Build commands

All commands must be run from inside the `Helion/` directory.

```bash
# Interactive build — prompts whether to minify
lune run Build bundle

# CI build — no prompts, no minification (fastest)
lune run Build bundle ci-mode=true

# Minified build — runs Darklua on the output
lune run Build bundle ci-mode=true minify=true

# Build with a custom header prepended to the output
lune run Build bundle ci-mode=true header=Build/Header.luau
```

Output is written to `Helion/Distribution/Script.luau`.

---

## Project Structure

```
Helion/
├── Src/                        # All source code
│   ├── init.client.luau        # Main entry point
│   ├── ExecutorSupport.luau    # Executor capability checks
│   ├── Window.luau             # Main UI controller
│   ├── Components/             # UI building blocks
│   │   ├── Animations.luau
│   │   ├── AssetManager.luau
│   │   ├── Drag.luau
│   │   ├── Helper.luau
│   │   ├── Highlighter.luau
│   │   ├── Icons.luau
│   │   ├── Interface.luau
│   │   ├── Resize.luau
│   │   └── Sonner.luau
│   ├── Extensions/
│   │   └── Manager.luau        # Plugin/extension API
│   ├── Lib/                    # Core libraries
│   │   ├── Anticheats/
│   │   │   ├── Main.luau
│   │   │   └── impl/
│   │   │       └── Adonis.luau
│   │   ├── CodeGen/
│   │   │   ├── Generator.luau
│   │   │   └── SessionExporter.luau
│   │   ├── Serializer/
│   │   │   └── LuaEncode.luau
│   │   ├── Connect.luau
│   │   ├── Decompile.luau
│   │   ├── FileHelper.luau
│   │   ├── FileLog.luau
│   │   ├── Hooking.luau
│   │   ├── Log.luau
│   │   ├── Pagination.luau
│   │   ├── SaveManager.luau
│   │   └── Signal.luau
│   └── Network/
│       ├── Init.luau           # Hook coordinator
│       └── Hooks/Default/
│           ├── Outgoing.luau   # FireServer / InvokeServer hooks
│           └── Incoming.luau   # OnClientEvent / OnInvoke hooks
├── Build/                      # Wax bundler (Lune-based)
│   ├── init.luau
│   ├── DarkLua.json
│   └── Lib/
├── Distribution/
│   └── Script.luau             # Built output
├── Loader.luau                 # Standard loader (fetches bundle)
├── VirtualLoader.luau          # RAM loader (fetches each source file)
├── LoadHelion.luau             # One-liner reference file
├── default.project.json        # Rojo project config
├── rokit.toml                  # Toolchain versions
└── stylua.toml                 # Code style config
```

---

## Architecture Overview

### Boot sequence

```
Executor runs Loader.luau
        │
        ▼
Fetches Distribution/Script.luau via HttpGet
        │
        ▼
loadstring() compiles the bundle
        │
        ▼
init.client.luau runs:
  1. Clone Roblox services into wax.shared
  2. Run ExecutorSupport checks
  3. Load SaveManager, Hooking, Connect utilities
  4. Boot Sonner (toast notifications)
  5. Initialise LuaEncode + CodeGen
  6. Resolve LocalPlayer
  7. Run Anticheat bypasses
  8. Boot Window (main UI)
  9. Boot Network/Init (remote hooks)
 10. Load Extensions/Manager (plugins)
```

### Network interception

Helion hooks at the metamethod level so it catches every remote regardless of how it is called:

```
game.__namecall  (hooked via hookmetamethod)
        │
        ├── FireServer / FireAllClients / FireClient
        ├── InvokeServer / InvokeClient
        └── → logged to wax.shared, displayed in Window

RemoteFunction / BindableFunction callbacks
        │
        ├── OnClientEvent:Connect(cb)  →  cb is detourred
        └── OnInvoke  →  getcallbackvalue + hookfunction
```

For games using parallel Luau (Actors), `Network/Init.luau` uses `run_on_actor` to inject the same hooks into every Actor and routes logs back to the main thread via `create_comm_channel`.

### Virtual require system (VirtualLoader)

```
VirtualLoader.luau
        │
        ├── Fetch all Src/*.luau from GitHub raw URLs → RAM table
        │
        ├── makeProxy(dotPath)
        │       Simulates Roblox Instance tree
        │       .Parent  →  go up one path segment
        │       .Child   →  go down via __index
        │
        └── virtualRequire(proxy)
                Resolves proxy → dotPath → RAM[dotPath]
                loadstring(src) with injected env:
                  { script = proxy, require = virtualRequire, wax = wax }
                Caches result — each module runs only once
```

---

## Module Documentation

### Core — `init.client.luau`

The main entry point. Runs as a `LocalScript` inside the executor context.

**Responsibilities:**
- Clones all needed Roblox services into `wax.shared` via `cloneref` to bypass anticheat instance tracking
- Generates a unique `HelionVerificationToken` (GUID) used internally to validate hook sources
- Exposes shared utilities (`restorefunction`, `getrawmetatable`, `hookmetamethod` wrappers) with safe fallbacks for executors that don't support them
- Coordinates the full module load order

**Key globals written to `wax.shared`:**

| Key | Type | Description |
|---|---|---|
| `HelionStartTime` | number | `tick()` at start, used for elapsed time logging |
| `ExecutorName` | string | Result of `identifyexecutor()` |
| `ExecutorSupport` | table | Feature check results from `ExecutorSupport.luau` |
| `LocalPlayer` | Player | Cached local player instance |
| `PlayerScripts` | Instance | Cloned `PlayerScripts` container |
| `SaveManager` | table | Settings persistence module |
| `Sonner` | table | Toast notification API |
| `Hooking` | table | Hook/unhook wrapper API |
| `LuaEncode` | function | Serializer for Luau values |
| `Hooks` | table | Registry of all active hooks (function → original) |

---

### `ExecutorSupport`

**Path:** `Src/ExecutorSupport.luau`

Runs a suite of live tests to check which executor functions are available and working correctly. Results are stored in a table returned by the module.

**Checks performed:**

| Check | Essential | What it tests |
|---|---|---|
| `hookfunction` | No | Hooks a local function, verifies return value changed |
| `isfunctionhooked` | No | Verifies hooked vs. unhooked detection |
| `restorefunction` | No | Verifies a hooked function can be fully restored |
| `hookmetamethod` | Yes | Hooks `__index` on a locked metatable |
| `getrawmetatable` | Yes | Reads a locked metatable |
| `getnamecallmethod` | Yes | Reads the current `:Method()` name during namecall |
| `newcclosure` | Yes | Creates a C-level closure, validates `debug.info` reports `[C]` |
| `checkcaller` | Yes | Checks if function is available |
| `getcallingscript` | Yes | Checks if function is available |
| `cloneref` | Yes | Clones `game`, verifies it's a different reference |
| `compareinstances` | Yes | Confirms `cloneref(game) == game` via compareinstances |
| `setstackhidden` | No | Verifies stack hiding works for `debug.info`, `traceback`, `getfenv`, `error` |
| `oth` | No | Full async hook correctness test including `__namecall` return value integrity |
| `run_on_actor` | Yes | Checked as present |
| `getactors` | Yes | Checked as present |
| `create_comm_channel` | Yes | Checked as present |
| `getfflag` / `setfflag` | Yes | Checked as present |
| `getcallbackvalue` | Yes | Fetches `OnInvoke` and verifies it is callable |
| `getnilinstances` | Yes | Returns a table |
| `getconnections` | Yes | Returns correct count and functions for `:Connect`, `:Once`, `:Wait` |
| `firesignal` | Yes | Fires a BindableEvent and confirms the handler ran |

**Result structure:**
```lua
ExecutorSupport["hookfunction"] = {
    IsWorking = true,
    Details   = <return value or error message>,
    Essential = false,
}
ExecutorSupport.FailedChecks = {
    Essential    = { "run_on_actor", ... },
    NonEssential = { "setstackhidden", ... },
}
```

---

### `Window`

**Path:** `Src/Window.luau`

The main UI controller. Manages the list of intercepted remotes, the detail view, code generation output, and all user interaction.

**Responsibilities:**
- Renders the scrollable remote list with call counts and type badges
- Opens a detail modal for any selected remote showing: arguments, call stack, generated code, and session history
- Provides a toolbar with filter, clear, pause, and export controls
- Handles keyboard shortcuts
- Integrates with the Extension API to allow plugins to inject custom tabs

---

### `Network/Init`

**Path:** `Src/Network/Init.luau`

Coordinates where and how hooks are installed.

**Responsibilities:**
- Installs `Outgoing` and `Incoming` hooks on the main Luau thread
- If `run_on_actor` is supported, iterates all Actors (from `getactors()` and `getnilinstances()`) and injects hooks into each one
- Creates a `comm_channel` per Actor so logs from parallel threads are forwarded to the main thread and appended to the shared log

---

### `Network/Hooks/Default/Outgoing`

**Path:** `Src/Network/Hooks/Default/Outgoing.luau`

Intercepts all **outgoing** remote calls.

**Hooked methods:**

| Method | Remote type |
|---|---|
| `FireServer` | RemoteEvent |
| `InvokeServer` | RemoteFunction |
| `FireAllClients` | RemoteEvent (server-side) |
| `FireClient` | RemoteEvent (server-side) |
| `InvokeClient` | RemoteFunction (server-side) |
| `Fire` | BindableEvent |
| `Invoke` | BindableFunction |

**For each call, captures:**
- The remote Instance and its full path
- All arguments (serialized via LuaEncode)
- The calling script (`getcallingscript`)
- The calling function's debug info (`debug.info`)
- A timestamp and unique call ID

---

### `Network/Hooks/Default/Incoming`

**Path:** `Src/Network/Hooks/Default/Incoming.luau`

Intercepts all **incoming** remote calls.

**Technique:**
- Hooks `__namecall` to detect `:Connect(...)` calls on `RemoteEvent.OnClientEvent` and `BindableEvent.Event`
- Wraps the user-supplied callback in a detour that logs arguments before passing them through
- Uses `getcallbackvalue` + `hookfunction` to intercept `RemoteFunction.OnClientInvoke` and `BindableFunction.OnInvoke`

---

### `Components/Interface`

**Path:** `Src/Components/Interface.luau`

A lightweight UI construction library. Provides factory functions for creating styled Roblox GUI instances (`Frame`, `TextLabel`, `TextButton`, `ScrollingFrame`, etc.) with consistent defaults.

---

### `Components/Highlighter`

**Path:** `Src/Components/Highlighter.luau`

Syntax-highlights Luau source code inside a `TextLabel` or `RichText` frame. Tokenises the source and applies colour codes for keywords, strings, numbers, comments, and operators.

---

### `Components/Sonner`

**Path:** `Src/Components/Sonner.luau`

A toast notification system inspired by [Sonner](https://sonner.emilkowal.ski/).

**API:**
```lua
wax.shared.Sonner.success("Remote blocked!")
wax.shared.Sonner.warning("Actor hooks unavailable")
wax.shared.Sonner.error("Fatal hook failure")
wax.shared.Sonner.info("Session exported")
```

Toasts slide in from the bottom of the screen, queue correctly, and auto-dismiss after a timeout.

---

### `Components/AssetManager` & `Icons`

- **`AssetManager.luau`** — Downloads and caches external font and image assets (e.g., Geist Mono). Falls back to defaults if HTTP fails.
- **`Icons.luau`** — Maps icon names to Lucide SVG data. Used throughout the UI for consistent icon rendering.

---

### `Components/Drag` & `Resize`

- **`Drag.luau`** — Attaches drag behaviour to a Frame. Respects DPI scale if `GetDPIScale` is available.
- **`Resize.luau`** — Attaches resize handles (corners and edges) to a Frame. Enforces min/max size constraints and also respects DPI scale.

---

### `Components/Animations`

**Path:** `Src/Components/Animations.luau`

Provides tween-based animation helpers:

```lua
Animations.FadeIn(frame, duration)
Animations.FadeOut(frame, duration)
Animations.SlideIn(frame, direction, duration)
```

Uses `TweenService` from `wax.shared`.

---

### `Lib/CodeGen/Generator`

**Path:** `Src/Lib/CodeGen/Generator.luau`

Generates Luau code from intercepted remote data.

**Output types:**

| Type | Description |
|---|---|
| **Call code** | Directly reproduces the remote call with all original arguments |
| **Hook code** | Creates a hook script the user can run to log or block the remote |

**Instance path resolution** — handles all cases:
- Standard service path: `game:GetService("ReplicatedStorage").Remotes.Fire`
- Player-relative path: `game.Players.LocalPlayer.PlayerScripts.Handler`
- Nil-parented instance: wrapped in a `getnilinstances()` search
- Unknown path: fallback to Instance name only

**Exported function:**
```lua
-- Returns the full dotted path string for a Roblox Instance
Generator.GetFullPath(instance) --> string
```

---

### `Lib/CodeGen/SessionExporter`

**Path:** `Src/Lib/CodeGen/SessionExporter.luau`

Exports the entire Helion session as a self-contained HTML file.

- Serializes every logged call (arguments, call stack, upvalues, constants, proto hashes)
- Injects the serialized data into `SessionHTMLView.txt` (an HTML template)
- Writes the result to `Helion/Session_<timestamp>.html`

The exported file can be opened in any browser and contains a searchable, filterable view of the full session.

---

### `Lib/Serializer/LuaEncode`

**Path:** `Src/Lib/Serializer/LuaEncode.luau`

Converts any Luau value to a valid Luau source string — used throughout for argument display and code generation.

**Handles:**
- Primitives: `nil`, `boolean`, `number` (including `math.huge`, `nan`)
- Strings (with proper escape sequences)
- Tables (recursive, with cycle detection)
- Roblox instances (resolved to full path via `Generator.GetFullPath`)
- Roblox types: `Vector2`, `Vector3`, `CFrame`, `Color3`, `UDim2`, `Enum`, etc.

---

### `Lib/SaveManager`

**Path:** `Src/Lib/SaveManager.luau`

Persists user settings across sessions.

**Storage:** `Helion/Settings.json` (written via `FileHelper`)

**API:**
```lua
SaveManager.Load()               -- reads Settings.json into wax.shared.Settings
SaveManager.Save()               -- writes wax.shared.Settings to disk
SaveManager.Set(key, value)      -- sets a key and immediately saves
SaveManager.Get(key, default)    -- returns a setting or the default
```

---

### `Lib/FileLog`

**Path:** `Src/Lib/FileLog.luau`

A structured file logger. Writes timestamped log entries to `Helion/Helion.log`.

**Log levels:** `INFO`, `WARN`, `ERROR`

**Entry format:**
```
[12:34:56.789 | +0.123s | T:main] INFO  Network hooks installed
```

**API:**
```lua
FileLogger.Info("message")
FileLogger.Warn("message")
FileLogger.Error("message")
```

All writes are wrapped in `pcall` so a file I/O failure never crashes Helion.

---

### `Lib/FileHelper`

**Path:** `Src/Lib/FileHelper.luau`

Wraps executor filesystem functions with safety and path normalization.

**API:**
```lua
FileHelper.Read(path)              -- returns file contents or nil
FileHelper.Write(path, contents)   -- creates parent folders automatically
FileHelper.Exists(path)            -- returns boolean
FileHelper.MakeFolder(path)        -- creates folder recursively
```

Falls back gracefully if `readfile`/`writefile` are unavailable.

---

### `Lib/Hooking`

**Path:** `Src/Lib/Hooking.luau`

A unified wrapper for the various hooking APIs that executors may provide.

**Priority order:** `oth.hook` → `hookfunction` → metamethod fallback

**API:**
```lua
Hooking.HookFunction(fn, replacement)  -- returns original
Hooking.UnhookFunction(fn)
Hooking.HookMetamethod(obj, name, fn)  -- returns original
```

---

### `Lib/Connect`

**Path:** `Src/Lib/Connect.luau`

Provides `wax.shared.Connect` — a safe wrapper around `RBXScriptSignal:Connect` that automatically disconnects on unload and prevents connecting to already-cleaned-up signals.

---

### `Lib/Signal`

**Path:** `Src/Lib/Signal.luau`

A pure-Luau bindable signal implementation (no Roblox Instances). Used internally by the Extension Manager and Window for decoupled event communication.

---

### `Lib/Decompile`

**Path:** `Src/Lib/Decompile.luau`

Interface module for script decompilation. Wraps whatever decompiler the executor provides (e.g., `decompile()`). Returns `nil` if no decompiler is available.

---

### `Lib/Pagination`

**Path:** `Src/Lib/Pagination.luau`

A generic paginator utility used by the remote list in `Window.luau` to split large datasets across pages without freezing the UI.

---

### `Lib/Log`

**Path:** `Src/Lib/Log.luau`

A lightweight in-memory log buffer that the Window UI reads to display the live call list. Separate from `FileLog` — this is the runtime store, not disk output.

---

### `Lib/Anticheats/Main`

**Path:** `Src/Lib/Anticheats/Main.luau`

Manages anticheat bypass modules. On load it:
1. Runs general-purpose bypasses applicable to all games
2. Checks the current `game.PlaceId` and runs any place-specific bypass

Individual bypass implementations live in `Lib/Anticheats/impl/`.

---

### `Lib/Anticheats/impl/Adonis`

**Path:** `Src/Lib/Anticheats/impl/Adonis.luau`

Bypasses the **Adonis** admin anticheat system.

**Detection technique:** Scans `getreg()` for coroutine threads whose source name matches known Adonis detection scripts.

**Bypass:**
1. Closes all detected Adonis monitoring threads
2. Hooks the `Detected` function to yield indefinitely, preventing any future ban calls

---

### `Extensions/Manager`

**Path:** `Src/Extensions/Manager.luau`

Provides a plugin API so third-party scripts can extend Helion without modifying the core.

**Plugin capabilities:**

| API | Description |
|---|---|
| `Helion.AddTab(name, builder)` | Adds a custom tab to the Remote Info modal |
| `Helion.AddContextMenuItem(label, fn)` | Adds an item to the right-click menu |
| `Helion.AddInterceptor(fn)` | Runs `fn(remote, args)` before every outgoing call; return `false` to block |
| `Helion.OnLog(fn)` | Called every time a new remote call is logged |
| `Helion.Settings` | Read/write access to `wax.shared.Settings` |
| `Helion.ExecutorSupport` | Read-only access to the executor feature table |

**Plugin loading:** Extensions are Luau scripts loaded from the `Helion/Extensions/` folder via `listfiles` + `readfile`. Each file is executed in a sandboxed environment with the `Helion` API table injected.

---

## Executor Compatibility

| Executor | Outgoing | Incoming | Actors | Notes |
|---|---|---|---|---|
| **AWP** | ✅ | ✅ | ✅ | Fully supported |
| **Synapse X** | ✅ | ✅ | ❌ | No `run_on_actor` |
| **Fluxus** | ✅ | ✅ | ❌ | No `run_on_actor` |
| **Potassium** | ✅ | ✅ | ❌ | `oth` disabled (crashes) |
| **Volcano** | ✅ | ✅ | ❌ | `oth` + `run_on_actor` disabled |

Executors not listed may still work. Check `wax.shared.ExecutorSupport.FailedChecks.Essential` at runtime to see what is missing.

---

## Known Executor Quirks

- **Volcano** — `oth` and `run_on_actor` are force-disabled because they cause game crashes on this executor.
- **Potassium** — `oth` is force-disabled.
- **Actor parallel remotes** — If `run_on_actor` is unavailable but the game uses Actors, Helion will show a notification offering to enable `DebugRunParallelLuaOnMainThread` via `setfflag` as a workaround (requires rejoin).

---

## File Layout Reference

| File | Purpose |
|---|---|
| `Helion/Loader.luau` | Standard one-file loader — fetches and runs the bundle |
| `Helion/VirtualLoader.luau` | RAM loader — fetches every source file individually |
| `Helion/LoadHelion.luau` | Convenience file containing just the one-liner |
| `Helion/Distribution/Script.luau` | Final bundled output (generated by build) |
| `Helion/Build/init.luau` | Wax bundler entry point |
| `Helion/Build/DarkLua.json` | Darklua minification config |
| `Helion/rokit.toml` | Toolchain version pins |
| `Helion/default.project.json` | Rojo project definition |
| `Helion/stylua.toml` | StyLua formatting config |

---

*Helion — built for research and educational purposes.*

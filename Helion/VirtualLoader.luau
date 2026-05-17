--[[
    Helion Virtual Loader
    Downloads every source module from GitHub into RAM, then boots Helion
    using a virtual require/script-proxy system — no disk writes needed.

    One-liner for your executor:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/VirtualLoader.luau"))()
]]

-- ── Guard ─────────────────────────────────────────────────────────────────────
if getgenv().HelionInitialized == true then
    local ok, sonner = pcall(function()
        return getgenv().Helion and getgenv().Helion.shared.Sonner
    end)
    if ok and sonner then
        sonner.warning("Helion is already running. Unload it first.")
    else
        warn("[Helion] Already initialized. Unload first.")
    end
    return
end

-- ── Config ────────────────────────────────────────────────────────────────────
local RAW_BASE = "https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/Src/"

--[[
    FILE_MAP: dot-path → file path relative to Src/
    Dot-path is how a module is addressed in the virtual tree,
    e.g.  require(script.Lib.Signal)  →  dotPath = "Lib.Signal"
    The root entry ("") is init.client.luau (the main entry point).
]]
local FILE_MAP = {
    [""]                                = "init.client.luau",
    ["ExecutorSupport"]                 = "ExecutorSupport.luau",
    ["Window"]                          = "Window.luau",
    ["Extensions.Manager"]              = "Extensions/Manager.luau",
    ["Network.Init"]                    = "Network/Init.luau",
    ["Network.Hooks.Default.Outgoing"]  = "Network/Hooks/Default/Outgoing.luau",
    ["Network.Hooks.Default.Incoming"]  = "Network/Hooks/Default/Incoming.luau",
    ["Components.Animations"]           = "Components/Animations.luau",
    ["Components.AssetManager"]         = "Components/AssetManager.luau",
    ["Components.Drag"]                 = "Components/Drag.luau",
    ["Components.Helper"]               = "Components/Helper.luau",
    ["Components.Highlighter"]          = "Components/Highlighter.luau",
    ["Components.Icons"]                = "Components/Icons.luau",
    ["Components.Interface"]            = "Components/Interface.luau",
    ["Components.Resize"]               = "Components/Resize.luau",
    ["Components.Sonner"]               = "Components/Sonner.luau",
    ["Lib.FileLog"]                     = "Lib/FileLog.luau",
    ["Lib.SaveManager"]                 = "Lib/SaveManager.luau",
    ["Lib.Connect"]                     = "Lib/Connect.luau",
    ["Lib.Hooking"]                     = "Lib/Hooking.luau",
    ["Lib.FileHelper"]                  = "Lib/FileHelper.luau",
    ["Lib.Decompile"]                   = "Lib/Decompile.luau",
    ["Lib.Log"]                         = "Lib/Log.luau",
    ["Lib.Signal"]                      = "Lib/Signal.luau",
    ["Lib.Pagination"]                  = "Lib/Pagination.luau",
    ["Lib.Anticheats.Main"]             = "Lib/Anticheats/Main.luau",
    ["Lib.Anticheats.impl.Adonis"]      = "Lib/Anticheats/impl/Adonis.luau",
    ["Lib.Serializer.LuaEncode"]        = "Lib/Serializer/LuaEncode.luau",
    ["Lib.CodeGen.Generator"]           = "Lib/CodeGen/Generator.luau",
    ["Lib.CodeGen.SessionExporter"]     = "Lib/CodeGen/SessionExporter.luau",
}

-- ── Step 1: Fetch all sources into RAM ────────────────────────────────────────
print("[Helion] Fetching modules into RAM...")

local RAM = {}          -- dotPath → source string
local fetchFailed = 0

for dotPath, filePath in pairs(FILE_MAP) do
    local url = RAW_BASE .. filePath
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src > 0 then
        RAM[dotPath] = src
    else
        warn("[Helion] Failed to fetch: " .. filePath)
        fetchFailed += 1
    end
end

if fetchFailed > 0 then
    warn(string.format("[Helion] Warning: %d module(s) failed to download.", fetchFailed))
else
    print("[Helion] All modules loaded into RAM successfully.")
end

-- ── Step 2: Shared wax object (mirrors what the Wax bundler injects) ──────────
--  All modules reference `wax.shared` as a global — we create it once here
--  and pass it into every module environment so they all share the same table.
local wax = {
    shared  = {},
    version = "VirtualLoader-1.0",
}

-- ── Step 3: Virtual script proxy ─────────────────────────────────────────────
--  Simulates the Roblox Instance tree (script, script.Parent, script.Lib, …)
--  Each proxy carries its dot-path as a private key so require() can read it.

local PROXY_KEY = {} -- unique table used as a private field key

local function makeProxy(dotPath)
    local t = { [PROXY_KEY] = dotPath }
    return setmetatable(t, {
        __index = function(_, key)
            if key == "Parent" then
                -- Go up one segment:  "Lib.CodeGen" → "Lib",  "Lib" → "",  "" → ""
                local parent = dotPath:match("^(.-)%.[^%.]+$") or ""
                return makeProxy(parent)
            end
            -- Navigate into a child
            local child = dotPath ~= "" and (dotPath .. "." .. key) or key
            return makeProxy(child)
        end,
        __tostring = function()
            return "Script(" .. (dotPath ~= "" and dotPath or "root") .. ")"
        end,
        __newindex = function() end, -- silently ignore writes (safety)
        __eq       = function(a, b) return rawequal(a, b) end,
    })
end

-- ── Step 4: Virtual require with caching ─────────────────────────────────────
local ModuleCache   = {} -- dotPath → return value (cached after first run)
local ModuleRunning = {} -- dotPath → true (circular-require guard)

local virtualRequire  -- forward declaration so modules can close over it

virtualRequire = function(scriptProxy)
    -- Accept both our proxy objects and real Roblox instances (fallback)
    local dotPath = type(scriptProxy) == "table" and scriptProxy[PROXY_KEY]
    if dotPath == nil then
        -- Not one of ours — fall back to real require if available
        if typeof ~= nil and typeof(scriptProxy) == "Instance" then
            return require(scriptProxy)
        end
        error("[Helion] require() called on an unknown object: " .. tostring(scriptProxy), 2)
    end

    -- Return cached result
    if ModuleCache[dotPath] ~= nil then
        return ModuleCache[dotPath]
    end

    -- Circular require guard
    if ModuleRunning[dotPath] then
        error("[Helion] Circular require detected: " .. dotPath, 2)
    end

    local src = RAM[dotPath]
    if not src then
        error("[Helion] Module not in RAM: " .. dotPath
            .. "\n  (Is it listed in FILE_MAP inside VirtualLoader.luau?)", 2)
    end

    ModuleRunning[dotPath] = true

    local chunkName = "Helion." .. (dotPath ~= "" and dotPath:gsub("%.", "/") or "init")
    local fn, compileErr = loadstring(src, chunkName)
    if not fn then
        ModuleRunning[dotPath] = nil
        error("[Helion] Compile error in " .. chunkName .. ":\n  " .. tostring(compileErr), 2)
    end

    -- Build this module's environment:
    --   • script  → its own proxy
    --   • require → our virtual require
    --   • wax     → the shared wax object (same table for every module)
    --   • everything else falls through to the real global env
    local modEnv = setmetatable({
        script  = makeProxy(dotPath),
        require = virtualRequire,
        wax     = wax,
    }, { __index = getfenv(0) })

    setfenv(fn, modEnv)

    local ok, result = pcall(fn)
    ModuleRunning[dotPath] = nil

    if not ok then
        error("[Helion] Runtime error in " .. chunkName .. ":\n  " .. tostring(result), 2)
    end

    -- Roblox ModuleScript semantics: cache the return value.
    -- If the module returned nothing (nil), store a sentinel so we don't re-run it.
    ModuleCache[dotPath] = result ~= nil and result or true
    return ModuleCache[dotPath]
end

-- ── Step 5: Boot the main entry point ────────────────────────────────────────
print("[Helion] Booting...")

local mainSrc = RAM[""]
if not mainSrc then
    error("[Helion] Main entry point (init.client.luau) was not downloaded.")
end

local mainFn, mainErr = loadstring(mainSrc, "Helion.init")
if not mainFn then
    error("[Helion] Compile error in main:\n  " .. tostring(mainErr))
end

local mainEnv = setmetatable({
    script  = makeProxy(""),
    require = virtualRequire,
    wax     = wax,
}, { __index = getfenv(0) })

setfenv(mainFn, mainEnv)

xpcall(mainFn, function(e)
    warn("[Helion] Fatal boot error:\n" .. tostring(e))
end)

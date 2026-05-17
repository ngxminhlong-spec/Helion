--[[
    Helion Loader - Executor Bootstrap Script
    Paste this into your executor to run Helion.

    You can override the URL with:
        getgenv().HELION_URL = "https://your-cdn/Helion.luau"
    before executing this loader.
]]

local HELION_DEFAULT_URL = "https://raw.githubusercontent.com/ngxminhlong-spec/Helion/main/Helion/Distribution/Script.luau"

-- Guard: prevent double-execution
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

local function fetch(url)
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok or not result or result == "" then
        error("[Helion] Failed to fetch: " .. tostring(url) .. "\n" .. tostring(result))
    end
    return result
end

local url = (getgenv and getgenv().HELION_URL) or HELION_DEFAULT_URL

local ok, err = xpcall(function()
    local src = fetch(url)
    local fn, compileErr = loadstring(src, "Helion")
    if not fn then
        error("[Helion] Compile error: " .. tostring(compileErr))
    end
    fn()
end, function(e)
    warn(tostring(e))
end)

if not ok then
    warn("[Helion] Failed to load. Check your internet connection or executor compatibility.")
end

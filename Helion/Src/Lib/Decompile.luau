--[[
    Helion Decompiler Utility
    Wraps executor decompile() / unluau support with graceful fallbacks.
]]

local Decompile = {}

-- Detects which decompile method is available
local function GetDecompiler()
    if typeof(decompile) == "function" then
        return "native", decompile
    end
    -- Some executors expose it via debug namespace
    if typeof(debug) == "table" and typeof(debug.getproto) == "function" then
        return "debug.getproto", nil
    end
    return nil, nil
end

local DecompilerType, DecompilerFn = GetDecompiler()

Decompile.IsSupported = DecompilerType ~= nil

--[[
    Attempts to decompile a Luau function or obtain its source.
    Returns (success: bool, result: string)
]]
function Decompile.Function(fn: (...any) -> ...any): (boolean, string)
    if typeof(fn) ~= "function" then
        return false, "-- Not a function"
    end

    -- Try native decompile()
    if DecompilerFn then
        local ok, result = pcall(DecompilerFn, fn)
        if ok and result and result ~= "" then
            return true, result
        end
    end

    -- Try debug.getinfo style (some executors)
    if typeof(debug) == "table" and typeof(debug.info) == "function" then
        local ok, source, line = pcall(debug.info, fn, "sl")
        if ok and source then
            return true, ("-- Source: " .. tostring(source) .. "\n-- Line: " .. tostring(line) .. "\n-- Decompile not available, source reference only.")
        end
    end

    return false, "-- Decompile not supported by this executor.\n-- Try an executor with decompile() support (e.g. Synapse X, KRNL, Fluxus)."
end

--[[
    Attempts to decompile a Roblox Instance's source script.
    Returns (success: bool, result: string)
]]
function Decompile.Instance(instance: Instance): (boolean, string)
    if not instance then
        return false, "-- No instance provided"
    end
    if not instance:IsA("LuaSourceContainer") then
        return false, ("-- " .. instance.ClassName .. " does not have Luau source")
    end
    if DecompilerFn then
        local ok, result = pcall(DecompilerFn, instance)
        if ok and result and result ~= "" then
            return true, result
        end
    end
    return false, "-- Decompile not supported or access denied for " .. tostring(instance.Name)
end

--[[
    Decompiles the calling function of a remote call (the game script that fired the remote).
    Returns (success: bool, result: string)
]]
function Decompile.CallerFunction(callInfo: any): (boolean, string)
    if not callInfo then
        return false, "-- No call info provided"
    end
    local fn = callInfo.Function
    if typeof(fn) == "table" then
        -- C function / native — can't decompile
        return false, ("-- Native/C function: " .. tostring(fn.Name or "?") .. "\n-- Address: " .. tostring(fn.Address or "?"))
    end
    return Decompile.Function(fn)
end

return Decompile

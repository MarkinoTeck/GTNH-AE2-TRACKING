-- src/loop.lua
local component  = require("component")
local computer   = require("computer")
local event      = require("event")
local term       = require("term")
local os         = require("os")
local HttpClient = require("lib/httpclient")
local JsonEncode = require("lib/jsonEncode")
local Logger     = require("lib/logger")

local Loop = {}
local conf
local me
local capacitor
local tpsCard

-- Sensor constants for Lapotronic Supercapacitor
local SENSOR_EU_STORE = 2
local SENSOR_WIRELESS_EU = 23

-- Sensor constants for DTPF
local SENSOR_DTPF_EFF = 7

function Loop.init(config)
    conf = config

    -- ME interface/controller
    local meAddr = conf:get("meAddress")
    if meAddr and meAddr ~= "" then
        me = component.proxy(meAddr)
    end
    if not me then
        -- Fallback: try the first available ME interface
        local ok, proxy = pcall(function() return component.me_interface end)
        if ok and proxy then me = proxy end
    end
    if not me then
        error("Cannot access ME component. Check meAddress in config.")
    end

    -- Capacitor (optional)
    if conf:get("isCapacitorActive") then
        local capAddr = conf:get("capacitorAddress")
        if capAddr and capAddr ~= "" then
            capacitor = component.proxy(capAddr)
        end
        if not capacitor then
            print("Warning: capacitor not found; continuing without energy data.")
            conf:set("isCapacitorActive", false)
            os.sleep(5)
        end
    end

    -- DTPF (optional)
    if conf:get("isDTPFactive") then
        local dtpfAddr = conf:get("DTPFAddress")
        if dtpfAddr and dtpfAddr ~= "" then
            dtpf = component.proxy(dtpfAddr)
        end
        if not dtpf then
            print("Warning: dtpf not found; continuing without dtpf data.")
            conf:set("isDTPFactive", false)
            os.sleep(5)
        end
    end

    -- TPS card (optional) — auto-detect
    local tpsOk, tpsProxy = pcall(function() return component.tps_card end)
    if tpsOk and tpsProxy then
        tpsCard = tpsProxy
        print("TPS card detected.")
    else
        print("No TPS card found; continuing without TPS data.")
    end
end

local function getMeData()
    local result = {}

    local ok, itemsRaw = pcall(function() return me.getItemsInNetwork() end)
    if ok and itemsRaw then
        for _, item in ipairs(itemsRaw) do
            table.insert(result, {
                type  = "item",
                label = item.label or "N/A",
                name  = item.name  or "unknown",
                count = item.size  or 0,
            })
        end
    end

    local ok2, fluidsRaw = pcall(function() return me.getFluidsInNetwork() end)
    if ok2 and fluidsRaw then
        for _, fluid in ipairs(fluidsRaw) do
            table.insert(result, {
                type   = "fluid",
                label  = fluid.label  or "N/A",
                name   = fluid.name   or "unknown",
                amount = fluid.amount or 0,
            })
        end
    end

    return result
end

local function getEnergyData()
    if not capacitor then return nil end

    local sensorIndex = conf:get("isCapacitorWireless") and SENSOR_WIRELESS_EU or SENSOR_EU_STORE

    local ok, sensorInfo = pcall(function() return capacitor.getSensorInformation() end)
    if not ok or not sensorInfo or not sensorInfo[sensorIndex] then
        return nil
    end

    local clean  = sensorInfo[sensorIndex]:gsub(",", "")
    local energy = tonumber(clean:match("(%d+)")) or 0

    return {
        type  = "energy",
        label = "Lapotronic Supercapacitor",
        count = energy,
    }
end

local function getDtpfData()
    if not dtpf then return nil end

    local ok, sensorInfo = pcall(function() return dtpf.getSensorInformation() end)
    if not ok or not sensorInfo or not sensorInfo[SENSOR_DTPF_EFF] then return nil end

    local raw = sensorInfo[SENSOR_DTPF_EFF]
    -- Strip Minecraft color codes (§ followed by any char)
    raw = raw:gsub("%§.", "")
    -- Remove thousands separators
    raw = raw:gsub(",(%d)", "%1")

    local ticks    = tonumber(raw:match("Ticks run:%s*([%d%.]+)"))    or 0
    local discount = tonumber(raw:match("Fuel Discount:%s*([%d%.]+)")) or 0
    local catalyst = tonumber(raw:match("Extra catalyst use:%s*([%d%.]+)")) or 0

    return {
        {
            type  = "dtpf_ticks",
            label = "DTPF Ticks Run",
            count = ticks,
        },
        {
            type  = "dtpf_%",
            label = "DTPF Fuel Discount %",
            count = discount,
        },
        {
            type  = "dtpf_catalyst",
            label = "DTPF Extra Catalyst (L)",
            count = catalyst,
        },
    }
end

local function getTpsData()
    if not tpsCard then return nil end

    local ok, overallTickTime = pcall(function() return tpsCard.getOverallTickTime() end)
    if not ok then return nil end

    local tps = tpsCard.convertTickTimeIntoTps(overallTickTime)

    return {
        type             = "tps",
        label            = "Server TPS",
        overallTps       = tps,
        overallTickMs    = overallTickTime,
        overallChunks    = (function()
            local c, v = pcall(function() return tpsCard.getOverallChunksLoaded() end)
            return c and v or nil
        end)(),
        overallEntities  = (function()
            local c, v = pcall(function() return tpsCard.getOverallEntitiesLoaded() end)
            return c and v or nil
        end)(),
        overallTEs       = (function()
            local c, v = pcall(function() return tpsCard.getOverallTileEntitiesLoaded() end)
            return c and v or nil
        end)(),
    }
end

-- Display helpers
local function printData(data)
    for _, entry in ipairs(data) do
        if entry.type == "item" then
            print(string.format("Item:   %-40s x%d", entry.label, entry.count))
        elseif entry.type == "fluid" then
            print(string.format("Fluid:  %-40s %d mB", entry.label, entry.amount))
        elseif entry.type == "energy" then
            print(string.format("Energy: %-40s %d EU", entry.label, entry.count))
        end
    end
end

local function printTps(tpsData)
    if not tpsData then return end
    print(string.format(
        "TPS:    %-40s %.2f TPS  (%.2f ms)",
        tpsData.label, tpsData.overallTps, tpsData.overallTickMs
    ))
    if tpsData.overallChunks   then print(string.format("        Chunks loaded:   %d", tpsData.overallChunks))   end
    if tpsData.overallEntities then print(string.format("        Entities loaded: %d", tpsData.overallEntities)) end
    if tpsData.overallTEs      then print(string.format("        TEs loaded:      %d", tpsData.overallTEs))      end
end

local function printDtpf(dtpfData)
    if not dtpfData then return end
    for _, entry in ipairs(dtpfData) do
        print(string.format("DTPF:   %-40s %g", entry.label, entry.count))
    end
end

-- Main loop
function Loop.run()
    local url      = conf:get("serverUrl")
    local mondoId  = conf:get("mondoId")
    local interval = 10  -- seconds between polls

    while true do
        term.clear()
        term.setCursor(1, 1)

        local ok, err = pcall(function()
            local data   = getMeData()
            local energy = getEnergyData()
            if energy then table.insert(data, energy) end

            local dtpfData = getDtpfData()
            if dtpfData then
                for _, entry in ipairs(dtpfData) do
                    table.insert(data, entry)
                end
            end

            printData(data)

            local tpsData = getTpsData()
            printTps(tpsData)
            printDtpf(dtpfData)

            local payload = {
                mondo = mondoId,
                items = data,
                tps   = tpsData,
                ts    = os.time() * 1000,
                uts    = computer.uptime() * 1000,
            }

            local response, reqErr = HttpClient.post(url, JsonEncode.encode(payload))
            if response then
                print("\nServer: " .. tostring(response))
            else
                print("\nSend error: " .. tostring(reqErr))
                Logger.error("POST failed: " .. tostring(reqErr))
            end
        end)

        if not ok then
            print("Loop error: " .. tostring(err))
            Logger.error("Loop error: " .. tostring(err))
        end

        print("\n[Press Q to quit]")

        local deadline = computer.uptime() + interval
        repeat
            local remaining = deadline - computer.uptime()
            if remaining <= 0 then break end
            local ev, _, char = event.pull(remaining, "key_down")
            if ev == "key_down" and char == string.byte("q") then
                term.clear()
                term.setCursor(1, 1)
                print("Exiting ME monitor. Goodbye!")
                return
            end
        until computer.uptime() >= deadline
    end
end

return Loop

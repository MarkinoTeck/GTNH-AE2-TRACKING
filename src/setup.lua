-- src/setup.lua
local io = require("io")

local Setup = {}

-- Prompt for a non-empty string
local function prompt(label, minLen)
    minLen = minLen or 1
    while true do
        io.write(label)
        local input = io.read("*l")
        if input and #input >= minLen then
            return input
        end
        print("Invalid input, please try again.")
    end
end

-- Prompt for a yes/no boolean
local function promptBool(label, default)
    while true do
        local hint = default and "[Y/n]" or "[y/N]"
        io.write(label .. " " .. hint .. ": ")
        local input = io.read("*l")
        if not input or input == "" then
            return default
        end
        input = input:lower()
        if input == "y" or input == "yes" then return true end
        if input == "n" or input == "no"  then return false end
        print("Please enter y or n.")
    end
end

function Setup.run(conf)
    local changed = false

    -- mondoId
    if not conf:get("mondoId") or conf:get("mondoId") == "" then
        print("=== ME MONITOR SETUP ===")
        local mondoId = prompt("Enter mondo/world ID: ")
        conf:set("mondoId", mondoId)
        changed = true
    end

    -- ME component address
    if not conf:get("meAddress") or conf:get("meAddress") == "" then
        local addr = prompt("Enter ME Interface or ME controller component address: ")
        conf:set("meAddress", addr)
        changed = true
    end

    -- Capacitor
    local capActive = conf:get("isCapacitorActive")
    if capActive == nil then
        capActive = promptBool("Enable capacitor energy monitoring?", true)
        conf:set("isCapacitorActive", capActive)
        changed = true
    end

    if capActive then
        if not conf:get("capacitorAddress") or conf:get("capacitorAddress") == "" then
            local addr = prompt("Enter capacitor component address: ")
            conf:set("capacitorAddress", addr)
            changed = true
        end

        local wireless = conf:get("isCapacitorWireless")
        if wireless == nil then
            wireless = promptBool("Is the capacitor a Wireless capacitor?", false)
            conf:set("isCapacitorWireless", wireless)
            changed = true
        end
    end

    -- Dtpf
    local capActive = conf:get("isDTPFactive")
    if capActive == nil then
        capActive = promptBool("Enable dtpf monitoring?", true)
        conf:set("isDTPFactive", capActive)
        changed = true
    end

    if capActive then
        if not conf:get("DTPFAddress") or conf:get("DTPFAddress") == "" then
            local addr = prompt("Enter dtpf component address: ")
            conf:set("DTPFAddress", addr)
            changed = true
        end
    end

    -- Server URL
    if not conf:get("serverUrl") or conf:get("serverUrl") == "" then
        local url = prompt("Enter server URL [leave blank for default]: ", 0)
        if url == "" then
            url = "http://convexapi-ae2-opencomputers.lookitsmark.com/post"
        end
        conf:set("serverUrl", url)
        changed = true
    end

    if changed then
        conf:save()
        print("Configuration saved.")
        print("========================")
    end

    -- Print config summary
    print("--- Current Configuration ---")
    print("Mondo ID:        " .. tostring(conf:get("mondoId")))
    print("ME Address:      " .. tostring(conf:get("meAddress")))
    print("Capacitor:       " .. tostring(conf:get("isCapacitorActive")))
    if conf:get("isCapacitorActive") then
        print("  Address:       " .. tostring(conf:get("capacitorAddress")))
        print("  Wireless:      " .. tostring(conf:get("isCapacitorWireless")))
    end
    print("DTPF:            " .. tostring(conf:get("isDTPFactive")))
    if conf:get("isDTPFactive") then
        print("  Address:       " .. tostring(conf:get("DTPFAddress")))
    end
    print("Server URL:      " .. tostring(conf:get("serverUrl")))
    print("-----------------------------")
    os.sleep(5)
end

return Setup

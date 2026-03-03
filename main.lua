-- main.lua
local autoUpdate = require("lib/autoupdate")
local version    = require("version")

autoUpdate(
    version,
    "MarkinoTeck/GTNH-AE2-TRACKING",
    "ComputerCode"
)

local Config = require("lib/config")
local Setup  = require("src/setup")
local Loop   = require("src/loop")

local DEFAULTS = {
    mondoId            = "",
    meAddress          = "",
    capacitorAddress   = "",
    isCapacitorActive  = nil,   -- nil = not yet configured
    isCapacitorWireless = nil,  -- nil = not yet configured
    serverUrl          = "",
}

local conf = Config.new("/etc/me_monitor.cfg", DEFAULTS)

-- init configs
Setup.run(conf)

-- loop
Loop.init(conf)
Loop.run()

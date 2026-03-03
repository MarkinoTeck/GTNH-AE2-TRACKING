---@diagnostic disable: undefined-field, need-check-nil

-- lib/config.lua

local fs            = require("filesystem")
local serialization = require("serialization")

local Config = {}
Config.__index = Config

-- Create a new config object.
-- @param path     string   Path to the config file (e.g. "/etc/config.cfg")
-- @param defaults table    Key/value pairs used when the file does not exist yet
function Config.new(path, defaults)
    local self = setmetatable({}, Config)
    self.path     = path
    self.defaults = defaults

    -- Create file with defaults if it doesn't exist yet
    if not fs.exists(path) then
        local file = io.open(path, "w")
        file:write(serialization.serialize(defaults))
        file:close()
    end

    -- Load from disk
    local file = io.open(path, "r")
    self.data = serialization.unserialize(file:read("*a"))
    file:close()

    for k, v in pairs(defaults) do
        if self.data[k] == nil then
            self.data[k] = v
        end
    end

    return self
end

-- Persist current config to disk
function Config:save()
    local file = io.open(self.path, "w")
    file:write(serialization.serialize(self.data))
    file:close()
end

function Config:get(key)
    return self.data[key]
end

function Config:set(key, value)
    self.data[key] = value
end

return Config

--[[ EXAMPLE
local Config = require("lib/config")

local defaults = {
    mondoId             = "",
    meAddress           = "",
    capacitorAddress    = "",
    isCapacitorActive   = nil,
    isCapacitorWireless = nil,
    serverUrl           = "",
}

local conf = Config.new("/etc/config.cfg", defaults)
print(conf:get("serverUrl"))

conf:set("mondoId", "my-world-123")
conf:save()
]]

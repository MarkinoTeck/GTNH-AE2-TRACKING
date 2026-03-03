-- lib/logger.lua

local Logger = {}

local LOG_PATH = "/logs.log"

function Logger.error(msg)
    local file = io.open(LOG_PATH, "a")
    if file then
        local time = os.date("%Y-%m-%d %H:%M:%S")
        file:write("[" .. time .. "] " .. tostring(msg) .. "\n")
        file:close()
    end
end

return Logger

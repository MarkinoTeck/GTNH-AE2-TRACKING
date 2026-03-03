local component = require("component")
local internet = component.internet
local os = require("os")

local HttpClient = {}
HttpClient.__index = HttpClient

-- Perform a GET request
function HttpClient.get(url)
    local req, err = internet.request(url)
    if not req then
        return nil, err
    end

    req.finishConnect()
    req.response()

    local result = ""
    while true do
        local chunk = req.read(1024)
        if not chunk then break end
        result = result .. chunk
    end

    req.close()
    return result
end

-- Perform a POST request with optional headers
function HttpClient.post(url, body, headers)
    headers = headers or {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#body)
    }

    local req, err = internet.request(url, body, headers)
    if not req then
        return nil, err
    end

    req.finishConnect()
    req.response()

    local result = ""
    while true do
        local chunk = req.read(1024)
        if not chunk then break end
        result = result .. chunk
    end

    req.close()
    return result
end

-- optional helper for periodic requests
function HttpClient.loop(callback, delay)
    delay = delay or 10
    while true do
        callback()
        os.sleep(delay)
    end
end

return HttpClient


--[[ EXAMPLE
local HttpClient = require("httpclient")

-- Single GET
local response, err = HttpClient.get("http://test.url.com/a")
if response then
    print(response)
end

-- Single POST
local response, err = HttpClient.post("http://test.url.com/p", "Hellooo!")
if response then
    print(response)
end

-- Loop GET every 10 seconds
HttpClient.loop(function()
    print(HttpClient.get("http://test.url.com/a"))
end, 10)

]]

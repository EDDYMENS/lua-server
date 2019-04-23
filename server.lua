local entryScript = arg[1]
local ok, script = pcall(require, entryScript)
if not ok then
    script = {config = {}}
end
local port = script.config.port or 4040
local host = script.config.host or "0.0.0.0"
local socket = require "socket"
local server = assert(socket.bind(host, port))
local ip, port = server:getsockname()
print("Listening on http://" .. host .. ":" .. port)
print("Press Ctrl-CC to quit.")

function dateTimeLog()
    local date = os.date("*t")
    return date.year .. "-" .. date.month .. "-" .. date.day .. " " .. date.hour .. ":" .. date.min .. ":" .. date.sec
end

Request = {}
function Request:processRequest(pathProtocol, client)
    local requestPattern = "^(.-)%s(%S+)%s*(HTTP%/%d%.%d)"
    local method, rawPath, protocol = string.match(pathProtocol, requestPattern)
    local headers = self:headers(client)
    local queryParams = self:queryParams(rawPath)
    local postParams = self:postParams(client, headers["Content-Length"])
    return {
        path = rawPath,
        headers = headers,
        protocol = protocol,
        method = method,
        postParams = postParams or nil,
        queryParams = queryParams
    }
end

function Request:postParams(client, contentSize)
    if (contentSize == nil) then
        return false
    end
    local data, err, partial = client:receive(contentSize)
    if err == "timeout" then
        data = partial
    end
    return data
end

function Request:queryParams(rawPath)
    params = {}
    if rawPath and next(params) == nil then
        for k, v in string.gmatch(rawPath, "([^=?]*)=([^&]*)&?") do
            params[k] = v
        end
    end
    return params
end

function Request:headers(client)
    local headerPattern = "([%w-]+): ([%w %p]+=?)"
    local data = client:receive()
    local headers = {}
    while (data ~= nil) and (data:len() > 0) do
        local key, value = string.match(data, headerPattern)

        if key and value then
            headers[key] = value
        end

        data = client:receive()
    end
    return headers
end

function Request:prepUserHeaders(userHeadersTbl)
    local userHeaderString = "\r\n"
    for key, value in pairs(userHeadersTbl) do
        userHeaderString = userHeaderString .. "\r\n" .. value
    end
    return userHeaderString
end
while 1 do
    local client = server:accept()
    client:settimeout(30)
    local requestInit, requestErr = client:receive()
    local requestPayload = Request:processRequest(requestInit, client)
    print(dateTimeLog(), requestInit)
    package.loaded.script = nil
    local ok, script = pcall(require, entryScript)
    errHeader = nil
    if not ok then
        -- print(debug.stacktrace())
        requestErr = '<b style="color:white;background-color:red">' .. script .. "</b>"
        errHeader = "Content-type: text/html"
    end
    local userHeaders = errHeader or Request:prepUserHeaders(script.config.headers)
    local response = requestErr or script:handler(requestPayload)
    client:send(
        "HTTP/1.1 200 OK\r\n" ..
            "Server: SimpleServer/0.1 " .. _VERSION .. " \r\n" .. userHeaders .. "\n" .. "\r\n" .. response .. "\r\n"
    )
    client:close()
end

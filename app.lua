local Script = {}
Script.config = {
    host = "0.0.0.0",
    port = 4040,
    debug = true,
    headers = {
        "content-type: application/json",
        "Connection: keep-alive"
    }
}
function Script:handler(request)
    return '{"name":"edmond"}'
end

return Script

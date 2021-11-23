local cjson = require("cjson")

local upstream = require "ngx.upstream"
local servers = upstream.get_servers("@api")

local function empty(s) return s == nil or s == '' end

local success, body = pcall(cjson.decode, ngx.var.request_body);
if not success then
    ngx.log(ngx.ERR, "invalid JSON request" .. body)
    -- return
end

local method = body['method']
local version = body["jsonrpc"]

if not empty(method) then ngx.var.rpcmethod = method end

local requests = {}
for _, srv in ipairs(servers) do
    local addr = srv.addr
    table.insert(requests, {
        "/proxy", {
            method = ngx["HTTP_" .. ngx.var.request_method],
            always_forward_body = true,
            copy_all_vars = true,
            vars = {proxy_host = addr}
        }
    })
end

local responses = {ngx.location.capture_multi(requests)}
for i, res in ipairs(responses) do
    local addr = servers[i].addr
--    ngx.say(addr, " HTTP/1.1 ", res.status)
--    for header, value in pairs(res.header) do ngx.say(header, ": ", value) end
--    ngx.say()
    ngx.print(res.body)
    local success, body = pcall(cjson.decode, res.body);
    if not success then
        ngx.log(ngx.ERR, "invalid JSON response body1" .. body)
    return
    end
--    ngx.print(body.result)
--    ngx.say()
    break
end

for i, res in ipairs(responses) do
    for n, r in ipairs(responses) do
        local ressuccess, resbody = pcall(cjson.decode, res.body);
	if not ressuccess then
		ngx.log(ngx.ERR, "invalid JSON resbody" .. body)
	return
	end
	local rsuccess, rbody = pcall(cjson.decode, r.body);
        if not ressuccess then
                ngx.log(ngx.ERR, "invalid JSON rbody" .. body)
        return
        end

        if resbody.result ~= rbody.result then
            ngx.var.different = "1"
            ngx.var.req_body = ngx.var.request_body
            break
        end
    end
--    ngx.say()
end
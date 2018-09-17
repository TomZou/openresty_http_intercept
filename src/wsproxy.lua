local server = require "resty.websocket.server"
local client = require "lualib.websocket.client"
local dns = require "lualib.dns.resolver"
-- local dump = require "lualib.dump"

local config = {
	-- ["prod-live-front.playbattlegrounds.com"] = "13.35.121.71",
	-- ["j9t5h48n24.execute-api.us-west-2.amazonaws.com"] = "13.33.231.73",
	-- ["prod-live-entry.playbattlegrounds.com"] = "52.45.250.114",
	-- ["d1wfiv6sf8d64f.cloudfront.net"] = "13.33.227.159",
}

local dnsc, err = dns:new({
	nameservers = {"8.8.8.8", {"8.8.4.4", 53} },
	retrans = 5,  -- 5 retransmissions on receive timeout
	timeout = 2000,  -- 2 sec
})

local function dns_resolver(host)
	local ip = config[host]
	if not ip then
		if not dnsc then
			return nil, "fail to resolve host " .. host
		end

		local answers, err, tries = dnsc:query(host, nil, {})
		if not answers then
			return nil, "failed to query the DNS server: " .. err .. "\nretry historie:\n " .. table.concat(tries, "\n  ")
		end

		if answers.errcode then
			return nil, "server returned error code: " .. answers.errcode .. ": " .. answers.errstr
		end

		for i, ans in ipairs(answers) do
			if ans.type == 1 and ans.class == 1 then
				return ans.address
			end
        end
    else
        return ip
	end	
end

local wb, err = server:new({
    timeout = 5000,  -- in milliseconds
    max_payload_len = 65535 * 100,
})

if not wb then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

local headers = ngx.req.get_headers()
local uri = "ws" .. headers.origin:sub(5) .. ngx.var.request_uri
-- ngx.log(ngx.ERR, 'uri ', uri)

local ip, err = dns_resolver(ngx.var.host)
if not ip then
    ngx.log(ngx.ERR, "dns_resolver ", ngx.var.host, " fail: ", err)
	return ngx.exit(444)
end

local wbc, err = client:new({
    timeout = 5000,  -- in milliseconds
    max_payload_len = 65535 * 100,
})
local ok, err = wbc:connect_by_ip(ip, uri, {
    origin = headers.origin
})
if not ok then
    ngx.log(ngx.ERR, "connect_by_ip fail ", ip, " err ", err)
    return ngx.exit(444)
else
    -- ngx.log(ngx.ERR, "connect_by_ip ok ", ip, ", uri ", uri)
end

while true do
    -- 接受客户端发来的请求
    local data, typ, err = wb:recv_frame()
    local bytes
    if not data then
        if string.find(err, "closed", 1, true) then
            ngx.log(ngx.ERR, "client closed")
            break
        elseif string.find(err, "timeout", 1, true) then
            -- ngx.log(ngx.ERR, "failed to receive a frame from client: ", err)
        else
            ngx.log(ngx.ERR, "failed to receive a frame from client: ", err)
            ngx.exit(444)
            break
        end
    else
        -- ngx.log(ngx.ERR, 'wb:recv_frame typ ', typ, ' err ', err)

        if typ == "close" then
            -- for typ "close", err contains the status code
            local code = err
            -- ngx.log(ngx.ERR, "client closing with status code ", code, " and message ", data)
            local bytes, err = wbc:send_close(code, data)
            -- ngx.log(ngx.ERR, "send_close to server return ", bytes, " err ", err)
            break
        elseif typ == "text" then
            bytes, err = wbc:send_text(data)
            ngx.log(ngx.ERR, "send_text to server: ", data, " return ", bytes, " err ", err)
        elseif typ == "binary" then
            bytes, err = wbc:send_binary(data)
            -- ngx.log(ngx.ERR, "send_binary to server: ", data, " return ", bytes, " err ", err)
        elseif typ == "ping" then
            bytes, err = wbc:send_ping(data)
            -- ngx.log(ngx.ERR, "send_ping to server: ", data, " return ", bytes, " err ", err)
        elseif typ == "pong" then
            bytes, err = wbc:send_pong(data)
            -- ngx.log(ngx.ERR, "send_pong to server: ", data, " return ", bytes, " err ", err)
        else
            ngx.log(ngx.ERR, "received a frame from client of type ", typ, " and payload ", data)
        end

        wb:set_timeout(1000)
    end

    -- 接收服务端发来的请求
    data, typ, err = wbc:recv_frame()
    if not data then
        if string.find(err, "closed", 1, true) then
            ngx.log(ngx.ERR, "server closed")
            break
        elseif string.find(err, "timeout", 1, true) then
            -- ngx.log(ngx.ERR, "failed to receive a frame from server: ", err)
        else
            ngx.log(ngx.ERR, "failed to receive a frame from server: ", err)
            ngx.exit(444)
            break
        end
    else
        -- ngx.log(ngx.ERR, 'wbc:recv_frame typ ', typ, ' err ', err)

        if typ == "close" then
            -- for typ "close", err contains the status code
            local code = err
            -- ngx.log(ngx.ERR, "server closing with status code ", code, " and message ", data)
            local bytes, err = wb:send_close(code, data)
            -- ngx.log(ngx.ERR, "send_close to client return ", bytes, " err ", err)
            break
        elseif typ == "text" then
            bytes, err = wb:send_text(data)
            ngx.log(ngx.ERR, "send_text to client: ", data, " return ", bytes, " err ", err)
        elseif typ == "binary" then
            bytes, err = wb:send_binary(data)
            -- ngx.log(ngx.ERR, "send_binary to client: ", data, " return ", bytes, " err ", err)
        elseif typ == "ping" then
            bytes, err = wb:send_ping(data)
            -- ngx.log(ngx.ERR, "send_ping to client: ", data, " return ", bytes, " err ", err)
        elseif typ == "pong" then
            bytes, err = wb:send_pong(data)
            -- ngx.log(ngx.ERR, "send_pong to client: ", data, " return ", bytes, " err ", err)            
        else
            ngx.log(ngx.ERR, "received a frame from server of type ", typ, " and payload ", data)
        end

        wbc:set_timeout(1000)
    end
end

wb:send_close()
wbc:send_close()

local dns = require "resty.dns.resolver"
local stringUtils = require "lualib.stringUtils"
local dumpUtils = require "lualib.dumpUtils"

local _M = {}

function _M.resolve(host)
    local dnsc = dns:new{
        nameservers = {"8.8.8.8", {"8.8.4.4", 53} },
        retrans = 5,  -- 5 retransmissions on receive timeout
        timeout = 3000,  -- 3 sec
    }
	local answers, err, tries = dnsc:query(host, nil, {})
	if not answers then		
		return nil, "query failed"
	end
	if answers.errcode then
		ngx.log(ngx.ERR, "server returned error code: ", answers.errcode,
				": ", answers.errstr)
		return nil, answers.errcode
	end
	for i, ans in ipairs(answers) do
		if ans.type == 1 and ans.class == 1 then
			return ans.address
		end
	end
end

function _M.needResolve(host)
	local strTab = stringUtils.split(host, ".")
	if #strTab == 3 then
		for _, v in ipairs(strTab) do
			if not tonumber(v) then
				return true
			end
		end
		return false
	end
end

return _M

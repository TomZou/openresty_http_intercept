local http = require "lualib.http"
local dns = require "lualib.dns.myresolver"
local gzip = require "lualib.gzip"
local cache = require "lualib.cache"
local tableSerialize = require "lualib.tableSerialize"
local stringUtils = require "lualib.stringUtils"
--1.完全匹配响应里面http头部给出的cache条件
--2.只缓存静态文件,403,404请求不缓存
--3.一个request分成几个key去存 例如：request-header， request-body，request-status
local needCacheType = {
	'image/', "audio/", "video/", "text/", 
}

local months = {
	['Jan'] = 1,
	['Feb'] = 2,
	['Mar'] = 3,
	['Apr'] = 4,
	['May'] = 5,
	['Jun'] = 6,
	['Jul'] = 7,
	['Aug'] = 8,
	['Sep'] = 9,
	['Oct'] = 10,
	['Nov'] = 11,
	['Dec'] = 12,
}

local function transferDate(cur)
	for _1, _2, _3, _4, _5, _6 in string.gmatch(cur, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)") do
		return { year =  _1, month = _2, day = _3, hour = _4, min = _5, sec = _6 }
	end	
end

local function transferGMTDate(t)
	for _1, _2, _3, _4, _5, _6, _7 in string.gmatch(t, "(%w+), (%d+) (%w+) (%d+) (%d+):(%d+):(%d+)") do
		return _2, months[_3], _4, _5, _6, _7
	end	
end

local function writeFile(reqTime, reqRawHeader, resTime, res, src, dst, isBodyGziped, isImage)
	local dateTime = transferDate(ngx.localtime())
	local fileName = "../logs/" .. dateTime.year .. dateTime.month .. dateTime.day .. "-" .. dateTime.hour .. ".log"
	local file = io.open(fileName, "ab")
	if not file then return end

	local delimiter = "========================== " .. reqTime .. "," .. src .. " ---> " .. resTime .. "," .. dst .. " ===========================\r\n"
	local gunzipBody
	if not isImage and isBodyGziped then
		gunzipBody = gzip.decompress(res.body)
	end
	local resStr
	if isImage then
		resStr = res.status .. "\r\n" .. res.raw_header .. "\r\n"
	else
		resStr = res.status .. "\r\n" .. res.raw_header .. "\r\n" .. (gunzipBody or res.body)
	end
	local str = delimiter .. reqRawHeader .. "\r\n========" .. resStr .. "\r\n"

	file:write(str)
	file:close()
end

local function saveCacheCondition(res)
	if res.status == 403 or res.status == 404 then return false end
	local headers = res.headers

	if headers["Content-Type"] then
		local needSave = false
		for _, v in ipairs(needCacheType) do 
			if string.find(headers["Content-Type"], v) then
				needSave = true
				break
			end
		end	
		if not needSave then return false end
	end	

	if headers['Cache-Control'] then
		if headers['Cache-Control'] == 'no-cache'  then 
			return false 
		elseif string.find(headers['Cache-Control'], "max-age") then
			local expireTime = 0
			local tab = stringUtils.split(headers['Cache-Control'], ",")
			for _, v in ipairs(tab) do
				if string.find(v, "max-age") then
					local tab2 = stringUtils.split(v, "=")
					expireTime = tonumber(tab2[2])
					return true, expireTime
				end
			end		
		end
	end

	if headers['Expires'] then
		if headers['Expires'] == -1 then 
			return false
		else  
			local day, month, year, hour, minute, second = transferGMTDate(headers["Expires"])
			local expireTime = os.time({day = day, month = month, year = year, hour = hour, minute = minute, second = second}) - os.time()
			return true, expireTime
		end
	end

	return true
end

local function saveResCache(url, res, expires)
	local status = res.status
	local headers = tableSerialize.serialize(res.headers)
	local body = res.body
	local exp = expires or 600
--	local gzipStr = gzip.compress(resStr)
	ngx.log(ngx.ERR, "save cache key:", url, " expires:", exp)
	cache.set_to_cache("responseCache", url .. "-status", status, exp)
	cache.set_to_cache("responseCache", url .. "-headers", headers, exp)
	cache.set_to_cache("responseCache", url .. "-body", body, exp)	
end

local function getResCache(url)
	local str = cache.get_from_cache("responseCache", url)
	if str then
		local res = tableSerialize.unserialize(str)
		return res
	else
		return nil
	end
end

local function getIp(host)
	if dns.needResolve(host) then
		ip = cache.get_from_cache("myDnsCache", host)
		if not ip then
			ip = dns.resolve(host)
			if not ip then
				ngx.log(ngx.ERR, "refresh DNS cache failed host:", host) 
				ngx.exit(444)
			else
				cache.set_to_cache("myDnsCache", host, ip, 300)
				return ip
			end
		else
			return ip
		end
	else
		ngx.exit(444)
	end
end

local reqTime = ngx.localtime()
local reqRawHeader = ngx.req.raw_header()
local headers = ngx.req.get_headers()
local method = ngx.req.get_method()
local host = headers['host']

local reqParams = {
	headers = headers
}

local port = '' -- 默认不用拼装端口
if ngx.var.scheme == 'https' then
	reqParams.ssl_verify = false  -- 固定不校验ssl证书
	if ngx.var.server_port ~= '443' then
		port = ':' .. ngx.var.server_port  -- 非默认端口才要拼装端口
	end
elseif ngx.var.scheme == 'http' then
	if ngx.var.server_port ~= '80' then
		port = ':' .. ngx.var.server_port  -- 非默认端口才要拼装端口
	end
else
	ngx.log(ngx.ERR, 'unsupported scheme ' .. ngx.var.scheme)
	ngx.log(ngx.ERR, reqRawHeader)
	ngx.exit(500)
end

local url = ngx.var.scheme .. '://' .. host .. port .. ngx.var.request_uri
-- ngx.log(ngx.ERR, url)

if method == 'POST' then
	ngx.req.read_body() -- 需要先read_body()才能解析post参数
	-- local args = ngx.req.get_post_args()
	reqParams.method = "POST"
	reqParams.body = ngx.var.request_body
end

local resStatusCache = getResCache(url .. "-status")

if resStatusCache then
	ngx.log(ngx.ERR, "get_from_cache:url:", url, " status:", resStatusCache)
	ngx.status = resStatusCache
	local headers = getResCache(url .. "-headers")
	for k, v in pairs(headers) do
		ngx.header[k] = v
	end	
	local body = getResCache(url .. "-body")
	if body then
		ngx.print(body)
	end
	ngx.eof()
else
	local ip = getIp(host)
	ngx.log(ngx.ERR, "get_from_request:url:", url, " ip:", ip, " host:", host)
	local httpc = http.new()
	httpc:set_timeout(20000) -- 20s
	local res, err = httpc:request_uri_by_ip(ip, url, reqParams)
	if res then
		ngx.status = res.status

		local isBodyGziped = false
		local isImage = false
		for k, v in pairs(res.headers) do
			if k == "Content-Encoding" and v == "gzip" then
				isBodyGziped = true
			end
			if k == "Content-Type" and string.find(v, 'image/', 0, true) then
				isImage = true
			end
			ngx.header[k] = v
		end
		if true then
			writeFile(reqTime, reqRawHeader, ngx.localtime(), res, ngx.var.remote_addr, ip or host, isBodyGziped, isImage)
		end
		if res.body then
			ngx.print(res.body)
		end
		--ngx.thread.spawn(saveResCache, url, res)
		local needSave, expires = saveCacheCondition(res)
		if needSave then
			saveResCache(url, res, expires)
		end
		ngx.eof()
	else
		ngx.log(ngx.ERR, 'request_uri fail: ' .. url .. ', ' .. err)
		ngx.exit(500)
	end
end
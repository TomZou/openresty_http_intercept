local type = type
local sformat = string.format
local slen = string.len
local sbyte = string.byte
local schar = string.char
local sfind = string.find
local sgmatch = string.gmatch
local sgsub = string.gsub
local ssub = string.sub
local tinsert = table.insert
local random = math.random

local _M = {}

function _M.split(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
    local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
          break
        end

        table.insert (t, string.sub (s, start, pos - 1))
        start = pos + string.len (delim)
    end
    table.insert (t, string.sub (s, start))

    return t
end

function _M.replace(str, pat, repl)
    if sfind(repl, "%", 1, true) then
        local newRepl = ""
        -- '%'使用‘%%’替换
        local len = slen(repl)
        for i = 1, len do
            local byte = ssub(repl, i, i)
            if byte == '%' then
                newRepl = newRepl .. "%%"
            else
                newRepl = newRepl .. byte
            end
        end
        repl = newRepl
    end
    return sgsub(str, pat, repl)
end

-- 系统消息进行转义处理
function _M.sysMsg_str(str)
    return (sgsub(sgsub(sgsub(str,"<","&lt;"),">","&gt;"),"%^","&xor;"))
end
function _M.makeSysMsg(str_l0, str_l1)
    -- if str_l0 then
    --     str_l0 = (sgsub(sgsub(sgsub(str_l0,"<","&lt;"),">","&gt;"),"%^","&xor;"))
    -- end
    -- if str_l1 then
    --     str_l1 = (sgsub(sgsub(sgsub(str_l1,"<","&lt;"),">","&gt;"),"%^","&xor;"))
    -- end

    local str
    if str_l0 and str_l1 then
        str = sformat("en:%s^id:%s", str_l0, str_l1)
    else
        str = str_l0 or str_l1
    end

    return str
end


-- Taken from http://lua-users.org/wiki/StringRecipes then modified for RFC3986
function _M.urlEncode(str)
	if str then
		str = sgsub(str, "([^%w-._~])", function(c)
			if c == " " then return "+" end
			return sformat ("%%%02X", sbyte(c))
		end)
	end
	return str
end

function _M.urlDecode(s)  
    s = string.gsub(string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end), "+", " ")
    return s
end  

function _M.urlEncodeToLower(str)
	if str then
		str = sgsub(str, "([^%w-._~])", function(c)
			if c == " " then return "+" end
			return sformat ("%%%02x", sbyte(c))
		end)
	end
	return str
end


function _M.createNewToken(uid)
	return tostring(uid)..tostring(random())
end

function _M.utf8len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

return _M

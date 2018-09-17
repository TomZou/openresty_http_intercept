-- 主要包括常用的dump函数
local _M = {}

local type = type
local pairs = pairs
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local next = next
local tostring = tostring

local function mytostring(s)
	if type(s) == "string" then
		return '"' .. s .. '"'
	else
		return tostring(s)
	end
end

-- 把obj dump成字符串，能处理环状结构
function _M.dump2str(obj, desc)
	if desc then desc = desc .. "\n" else desc = "" end

	if type(obj) ~= "table" then
		return desc .. " [" .. mytostring(obj) .. "]"
	end

	local cache = { [obj] = "." }
	local function _dump(t, space, name)
		local temp = {}
		for k, v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp, "+" .. key .. " {" .. cache[v] .. "}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				--key = key .. "(" .. tostring(v) .. ")"  --需要显示表地址信息(table: 0x7f8b6b500760)时打开这行
				tinsert(temp, "+" .. key .. _dump(v, space .. (next(t, k) and "|" or " ") .. srep(" ", #key), new_key))
			else
				tinsert(temp, "+" .. key .. " [" .. mytostring(v) .. "]")
			end
		end
		return tconcat(temp, "\n" .. space)
	end

	return desc .. ".(" .. tostring(obj) .. ")\n" .. _dump(obj, "", "")
end

function _M.dump(obj, desc)
	print(_M.dump2str(obj, desc))
end

return _M

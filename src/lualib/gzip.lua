local table_insert = table.insert
local table_concat = table.concat
local zlib = require 'lualib.ffi-zlib'
local chunk = 16384

local _M = {}
local count = 0
local sourceStr
local input = function(bufsize)
	local start = count > 0 and bufsize*count or 1 --1
    local data = sourceStr:sub(start, (bufsize*(count+1)-1))
	if data == "" then
		data = nil
	end
	count = count + 1
    return data	
end

local outputTable = {}
local output = function(data)
    table_insert(outputTable, data)
end

function _M.compress(str)
	if not str then
		return nil
	end
	sourceStr = str
	count = 0
	outputTable = {}
	local ok, err = zlib.deflateGzip(input, output, chunk)
	if not ok then
		return nil
	end
	local decompressed = table_concat(outputTable,'')
	return decompressed	
end


function _M.decompress(str)
	if not str then
		return nil
	end
	sourceStr = str
	count = 0
	outputTable = {}
	local ok, err = zlib.inflateGzip(input, output, chunk)
	if not ok then
		return nil
	end
	local decompressed = table_concat(outputTable,'')
	return decompressed
end


return _M
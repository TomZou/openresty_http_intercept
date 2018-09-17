
local _M = {
    myDnsCache = ngx.shared.myDnsCache,
    responseCache = ngx.shared.responseCache
}

function _M.set_to_cache(cacheName, key, value, expiretime)
    
    local succ, err, forcible = _M[cacheName]:set(key, value, expiretime)
    ngx.log(ngx.ERR, "set ", cacheName, " key:", key, " succ:", succ, " err:", err)
    return succ
end

function _M.get_from_cache(cacheName, key)
    local value = _M[cacheName]:get(key)
    --ngx.log(ngx.ERR, value)
    return value    
end

return _M

# openresty_http_intercept
this is a http/https interceptor based on openresty
此工程是基于openresty框架实现的一个http/https中间人的服务，主要的任务是监控服务端与客户端之间通信的内容并对内容进行缓存，从而提高通信的速度。
缓存机制：
    1.只缓存静态文件
    2.目前实现了直接内存缓存
    3.完全匹配服务端在头部设定的缓存条件

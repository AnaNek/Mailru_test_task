local cartridge = require('cartridge')
local log = require('log')
local errors = require('errors')

local err_vshard_router = errors.new_class("Vshard routing error")
local err_httpd = errors.new_class("httpd error")

local function json_response(req, json, status) 
    local resp = req:render({json = json})
    resp.status = status
    return resp
end

local function success_response(req, json, status, key)
    local resp = json_response(req, json, status)
    log.info("%s status:%d key: %d", req.method, resp.status, key)
    return resp
end

local function error_response(req, msg, status)
    local resp = json_response(req, {info = msg}, status)
    log.info("%s status:%d %s", req.method, resp.status, msg)
    return resp
end

local function storage_error_response(req, error)
    if error.err == "Already exist" then
        return error_response(req, "Already exist", 409)
    elseif error.err == "Not found" then
        return error_response(req, "Not found", 404)
    else
        return error_response(req, "Internal error", 500)
    end
end

local function http_song_add(req)
    local body = req:json()
    
    if body == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    if body.key == nil or body.value == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    if body.value.name == nil or body.value.artist == nil 
    or body.value.duration == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(body.key)
    
    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'write',
        'song_add',
        {body.key, bucket_id, body.value.name, body.value.artist, body.value.duration}
    )
    
    if error then
        return error_response(req, "Internal error", 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return success_response(req, {info = "Song was added"}, 201, tonumber(body.key))
end

local function http_song_get(req)
    local song_id = tonumber(req:stash('song_id'))
    
    if song_id == nil then
        return error_response(req, "Invalid key", 400)
    end
    
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(song_id)
    
    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'read',
        'song_get',
        {song_id}
    )
    
    if error then
        return error_response(req, "Internal error", 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return success_response(req, resp.song, 200, song_id)
end

local function http_song_delete(req)
    local song_id = tonumber(req:stash('song_id'))
    
    if song_id == nil then
        return error_response(req, "Invalid key", 400)
    end
    
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(song_id)
    
    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'write',
        'song_delete',
        {song_id}
    )
    
    if error then
        return error_response(req, "Internal error", 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return success_response(req, {info = "Song was deleted"}, 200, song_id)
end
 
local function http_song_update(req)
    local song_id = tonumber(req:stash('song_id'))
    local body = req:json()
    
    if song_id == nil then
        return error_response(req, "Invalid key", 400)
    end
    
    if body == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    if body.value == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    if body.value.name == nil or body.value.artist == nil 
    or body.value.duration == nil then
        return error_response(req, "Invalid body", 400)
    end
    
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(song_id)
    
    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'read',
        'song_update',
        {song_id, bucket_id, body.value.name, body.value.artist, body.value.duration}
    )
    
    if error then
        return error_response(req, "Internal error", 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return success_response(req, resp.song, 200, song_id)
end
   
local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    local httpd = cartridge.service_get('httpd')

    if not httpd then
        return nil, errors:new("Not found")
    end
    
    httpd:route({method = 'POST', path = '/kv', public = true},
        http_song_add
    )

    httpd:route({method = 'GET', path = '/kv/:song_id', public = true},
        http_song_get
    )
    
    httpd:route({method = 'DELETE', path = '/kv/:song_id', public = true},
        http_song_delete
    )

    httpd:route({method = 'PUT', path = '/kv/:song_id', public = true},
        http_song_update
    )

    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = {
        'cartridge.roles.vshard-router'
    }
}

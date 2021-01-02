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

local function storage_error_response(req, error)
    if error.err == "Already exist" then
        return json_response(req, {
        info = "Already exist"
        }, 409)
    elseif error.err == "Not found" then
        return json_response(req, {
        info = "Not found"
        }, 404)
    else
        return json_response(req, {
        info = "Internal error",
        error = error
        }, 500)
    end
end

local function http_song_add(req)
    local body = req:json()
    log.info("POST", body)
    
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
        return json_response(req, {
        info = "Internal error",
        error = error
        }, 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return json_response(req, {info = "Successfully created"}, 201)
end

local function http_song_get(req)
    local song_id = tonumber(req:stash('song_id'))
    log.info("GET")
    
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
        return json_response(req, {
        info = "Internal error",
        error = error
        }, 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return json_response(req, resp.song, 200)
end

local function http_song_delete(req)
    local song_id = tonumber(req:stash('song_id'))
    log.info("DELETE")
    
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
        return json_response(req, {
        info = "Internal error",
        error = error
        }, 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return json_response(req, {info = "Deleted"} , 200)
end
 
local function http_song_update(req)
    local song_id = tonumber(req:stash('song_id'))
    local body = req:json()
    log.info("PUT")
    
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
        return json_response(req, {
        info = "Internal error",
        error = error
        }, 500)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return json_response(req, resp.song, 200)
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

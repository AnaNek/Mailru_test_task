local checks = require('checks')
local errors = require('errors')
local err_storage = errors.new_class("Storage error")

local function init_space()
    local space = box.schema.space.create(
         'song', -- имя спейса
         {
             format = {
                 {'song_id', 'unsigned'}, -- id песни
                 {'bucket_id', 'unsigned'}, -- id сегмента
                 {'name', 'string'}, -- название
                 {'artist', 'string'}, -- исполнитель
                 {'duration', 'unsigned'} -- длительность
             },
             
             if_not_exists = true,
         }
     )
     
     -- индекс по id песни
     space:create_index('song_id', {
         parts = {'song_id'},
         if_not_exists = true,
     })
     
     -- индекс по id сегмента
     space:create_index('bucket_id', {
         parts = {'bucket_id'},
         unique = false,
         if_not_exists = true, 
     })
end

local function song_add(song_id, bucket_id, name, artist, duration)
    checks('number', 'number', 'string', 'string', 'number')
    
    local song = box.space.song:get(song_id)
    
    if song ~= nil then
        return {ok = false, error = err_storage:new("Already exist")}
    end
    
    box.space.song:insert({song_id, bucket_id, name, artist, duration})
    
    return {ok = true, error = nil}
end

local function song_delete(song_id)
    checks('number')
    
    local song = box.space.song:get(song_id)
    if song == nil then
        return {ok = false, error = err_storage:new("Not found")}
    end
    
    box.space.song:delete(song_id)
    
    return {ok = true, error = nil}
end

local function song_get(song_id)
    checks('number')
    
    local song = box.space.song:get(song_id)
    
    if song == nil then
        return {song = nil, error = err_storage:new("Not found")}
    end
    
    song = song:tomap({names_only = true})
    
    song.bucket_id = nil
    
    return {song = song, error = nil}
end

local function song_update(song_id, bucket_id, name, artist, duration)
    checks('number', 'number', 'string', 'string', 'number')
    
    local song = box.space.song:get(song_id)
    
    if song == nil then
        return {song = nil, error = err_storage:new("Not found")}
    end
    
    song = box.space.song:update(song_id, {{'=', 3, name}, {'=', 4, artist}, {'=', 5, duration}})
    song = song:tomap({names_only = true})
    
    song.bucket_id = nil
    
    return {song = song, error = nil}
end

local exported_functions = {
    song_add = song_add,
    song_delete = song_delete,
    song_get = song_get,
    song_update = song_update,
}

local function init(opts)
    if opts.is_master then
        init_space()
        
        for name in pairs(exported_functions) do
            box.schema.func.create(name, {if_not_exists = true})
        end
        
    end
    
    for name, func in pairs(exported_functions) do
        rawset(_G, name, func)
    end
    
    return true
    
end

return {
    role_name = 'storage',
    init = init,
    utils = {
        song_add = song_add,
        song_update = song_update,
        song_get = song_get,
        song_delete = song_delete,
    },
    dependencies = {
        'cartridge.roles.vshard-storage'
    }
}

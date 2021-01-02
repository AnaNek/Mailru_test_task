# Тестовое задание Mail.ru

Для разработки использовался фреймворк Tarantool Cartridge.

Для реализации kv-хранилища и API для него приложение разбито на 2 роли:

- api - реализация RESTful http-сервер;
- storage - реализация хранения и изменения информации.

В хранилище содержится информация о песнях.

Формат спейса описывается идентификатором песни, идентификатором сегмента, названием песни, исполнителем, длительностью композиции.

Инициализация необходимого пространства в хранилище:

```lua
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
```

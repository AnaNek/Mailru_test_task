# Тестовое задание Mail.ru

Для разработки использовался фреймворк Tarantool Cartridge.

Для реализации kv-хранилища и API для него приложение разбито на 2 роли:

- api - реализация RESTful http-сервера;
- storage - реализация хранения и изменения информации.

В хранилище содержится информация о песнях.

Формат спейса описывается идентификатором песни, идентификатором сегмента, названием песни, исполнителем, длительностью композиции в секундах.

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

## Настройка кластера

Настройка кластера проводилась через веб-интерфейс:

1. на одном инстансе была назначена роль api, был создан первый набор реплик;

2. на другом инстансе была назначена роль storage, был создан второй набор реплик;

3. для запуска vshard была нажата кнопка Bootstrap vshard на закладке Cluster в веб-интерфейсе.

После этого кластер настроен. 

## Демонстрация работы

1. Добавление песни в хранилище

```
curl -X POST -v -H "Content-Type: application/json" -d '{"key": 3, "value": {"name": "In the end", "artist": "Linkin park", "duration": 185}}' http://185.86.146.113:8081/kv
Note: Unnecessary use of -X or --request, POST is already inferred.
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> POST /kv HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 85
> 
* upload completely sent off: 85 out of 85 bytes
* Mark bundle as not supporting multiuse
< HTTP/1.1 201 Created
< Content-length: 25
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"info":"Song was added"}
```

Проверить добавление информации в хранилище можно с помощью метода GET.

2. Получение песни из хранилища по id

```
curl -X GET -v http://185.86.146.113:8081/kv/3
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> GET /kv/3 HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 Ok
< Content-length: 71
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"song_id":3,"name":"In the end","duration":185,"artist":"Linkin park"}
```
3. Изменение информации о песне в хранилище по id

```
curl -X PUT -v -H "Content-Type: application/json" -d '{"value": {"name": "In the End", "artist": "Linkin Park", "duration": 187}}' http://185.86.146.113:8081/kv/3
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> PUT /kv/3 HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 75
> 
* upload completely sent off: 75 out of 75 bytes
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 Ok
< Content-length: 71
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"song_id":3,"name":"In the End","duration":187,"artist":"Linkin Park"}
```
Проверка изменения информации о песне с помощью метода GET:

```
curl -X GET -v http://185.86.146.113:8081/kv/3
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> GET /kv/3 HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 Ok
< Content-length: 71
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"song_id":3,"name":"In the End","duration":187,"artist":"Linkin Park"}
```

Информация была изменена

4. Удаление песни из хранилища по id

```
curl -X DELETE -v http://185.86.146.113:8081/kv/3
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> DELETE /kv/3 HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 Ok
< Content-length: 27
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"info":"Song was deleted"}
```

Проверка удаления песни с помощью метода GET:

```
curl -X GET -v http://185.86.146.113:8081/kv/3
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 185.86.146.113:8081...
* TCP_NODELAY set
* Connected to 185.86.146.113 (185.86.146.113) port 8081 (#0)
> GET /kv/3 HTTP/1.1
> Host: 185.86.146.113:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 404 Not found
< Content-length: 20
< Server: Tarantool http (tarantool v2.5.3-0-gf93e48013)
< Content-type: application/json; charset=utf-8
< Connection: keep-alive
< 
* Connection #0 to host 185.86.146.113 left intact
{"info":"Not found"}
```

Песня была удалена.


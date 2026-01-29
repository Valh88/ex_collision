# ExCollision

Библиотека для серверных коллизий, симуляции физического мира (AABB), поиска путей по тайлмапу (A*) и парсинга карт Tiled TMX.

## Возможности

- **Парсинг TMX** — загрузка карт Tiled: тайловые слои (CSV/base64), objectgroup, tilesets
- **Мир коллизий** — статические и динамические тела (AABB), проверка пересечений, симуляция шага движения
- **Поиск путей** — алгоритм A* по тайлмапу с протоколом `TileSource`
- **Интеграция TMX → World** — автоматическое построение мира коллизий из слоёв карты (например "Walls") и objectgroup

В проекте используются возможности Elixir: протоколы (`Collidable`, `TileSource`), делегаты (`defdelegate`), реализации протоколов для структур (`defimpl`), `Enumerable` для мира тел.

## Установка

```elixir
def deps do
  [
    {:ex_collision, "~> 0.1.0"}
  ]
end
```

## Пример (карта data/Dun.tmx)

```elixir
# Парсинг TMX
map = ExCollision.parse_tmx!("data/Dun.tmx")

# Мир коллизий из слоя "Walls" и objectgroup
world = ExCollision.world_from_tmx(map, collision_layer: "Walls")

# Поиск пути по слою Floor (0 = проходимо)
layer = ExCollision.tmx_layer_by_name(map, "Floor")
source = ExCollision.TMX.TileLayerTileSource.new(layer)
{:ok, path} = ExCollision.find_path(source, {10, 10}, {20, 15})

# Динамическое тело и движение
{world, id} = ExCollision.World.add_body(world, ExCollision.World.Body.from_xywh(:player, 50, 50, 16, 16))
{:ok, world, body} = ExCollision.World.move_body(world, id, 2, 0)
```

## Обработка коллизий (on_collision)

При движении тела (`move_body` или `step`) при коллизии вызывается колбек `on_collision`, если он задан. Сигнатура: `(world, body_id, collided_body_ids, hit_static) -> world`.

Пример: пуля, которая исчезает при попадании в стену или в игрока; при попадании в игрока можно обновить его данные (урон).

```elixir
# Пуля удаляется при любой коллизии
bullet_callback = fn world, body_id, _collided_ids, _hit_static ->
  # body_id — id пули; удаляем её из мира
  ExCollision.World.remove_body(world, body_id)
end

bullet = ExCollision.World.Body.from_xywh(bullet_id, x, y, 4, 4, velocity: {vx, vy}, on_collision: bullet_callback)
{world, _} = ExCollision.World.add_body(world, bullet)

# При step/move_body при коллизии колбек вызовется и мир вернётся уже без пули (или с обновлёнными данными игрока)
```

## Модули

| Модуль | Назначение |
|--------|------------|
| `ExCollision.TMX.Parser` | Парсинг TMX (файл или XML-строка) |
| `ExCollision.TMX.Map` | Структура карты, `layer_by_name/2` |
| `ExCollision.TMX.WorldBuilder` | Построение мира из TMX (`from_tmx/2`) |
| `ExCollision.World` | Мир коллизий (тела, статика, `move_body`, `collides?`) |
| `ExCollision.World.Body` | Динамическое/статическое тело (AABB) |
| `ExCollision.Pathfinding.AStar` | Поиск пути A* по тайлмапу |
| `ExCollision.Protocols.Collidable` | Протокол: `aabb/1` |
| `ExCollision.Protocols.TileSource` | Протокол: `width/1`, `height/1`, `tile_at/2`, `walkable?/2` |

## Лицензия

MIT

# ExCollision

A library for server-side collisions, physics world simulation (AABB), tilemap pathfinding (A*), and Tiled TMX map parsing.

## Features

- **TMX parsing** — load Tiled maps: tile layers (CSV/base64), objectgroup, tilesets
- **Collision world** — static and dynamic bodies (AABB), intersection checks, step-by-step movement simulation
- **Pathfinding** — A* algorithm over the tilemap with the `TileSource` protocol
- **TMX → World integration** — automatic construction of the collision world from map layers (e.g. "Walls") and objectgroup

The project uses Elixir features: protocols (`Collidable`, `TileSource`), delegates (`defdelegate`), protocol implementations for structs (`defimpl`), and `Enumerable` for the body world.

## Installation

```elixir
def deps do
  [
    {:ex_collision, "~> 0.1.0"}
  ]
end
```

## Example (map data/Dun.tmx)

```elixir
# Parse TMX
map = ExCollision.parse_tmx!("data/Dun.tmx")

# Collision world from "Walls" layer and objectgroup
world = ExCollision.world_from_tmx(map, collision_layer: "Walls")

# Pathfinding over Floor layer (0 = walkable)
layer = ExCollision.tmx_layer_by_name(map, "Floor")
source = ExCollision.TMX.TileLayerTileSource.new(layer)
{:ok, path} = ExCollision.find_path(source, {10, 10}, {20, 15})

# Dynamic body and movement
{world, id} = ExCollision.World.add_body(world, ExCollision.World.Body.from_xywh(:player, 50, 50, 16, 16))
{:ok, world, body} = ExCollision.World.move_body(world, id, 2, 0)
```

## Collision handling (on_collision)

When a body moves (`move_body` or `step`), the `on_collision` callback is invoked on collision if set. Signature: `(world, body_id, collided_body_ids, hit_static) -> world`.

Example: a bullet that disappears when hitting a wall or a player; when hitting a player you can update their data (damage).

```elixir
# Bullet is removed on any collision
bullet_callback = fn world, body_id, _collided_ids, _hit_static ->
  # body_id is the bullet id; remove it from the world
  ExCollision.World.remove_body(world, body_id)
end

bullet = ExCollision.World.Body.from_xywh(bullet_id, x, y, 4, 4, velocity: {vx, vy}, on_collision: bullet_callback)
{world, _} = ExCollision.World.add_body(world, bullet)

# On step/move_body the callback runs on collision and the world is returned without the bullet (or with updated player data)
```

## Modules

| Module | Purpose |
|--------|---------|
| `ExCollision.TMX.Parser` | TMX parsing (file or XML string) |
| `ExCollision.TMX.Map` | Map structure, `layer_by_name/2` |
| `ExCollision.TMX.WorldBuilder` | Build world from TMX (`from_tmx/2`) |
| `ExCollision.World` | Collision world (bodies, static, `move_body`, `collides?`) |
| `ExCollision.World.Body` | Dynamic/static body (AABB) |
| `ExCollision.Pathfinding.AStar` | A* pathfinding over tilemap |
| `ExCollision.Protocols.Collidable` | Protocol: `aabb/1` |
| `ExCollision.Protocols.TileSource` | Protocol: `width/1`, `height/1`, `tile_at/2`, `walkable?/2` |

## License

MIT

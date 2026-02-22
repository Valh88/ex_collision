defmodule ExCollision do
  @moduledoc """
  Library for server-side collisions, physics world simulation, tilemap pathfinding, and Tiled TMX parsing.

  ## Main features

  - **TMX parsing** — load Tiled maps (tile layers, objectgroup, tilesets)
  - **Collision world** — static and dynamic bodies (AABB), intersection checks and step simulation
  - **Pathfinding** — A* over tilemap with `TileSource` protocol support
  - **TMX → World integration** — build collision world from map layers (Walls, objectgroup)

  ## Server loop

  `World.step(world, dt)` is called every server tick (e.g. 60 times per second).
  Use a fixed `dt = 1/60` for determinism or the actual interval between ticks.

  ## Example

      # Parse TMX
      map = ExCollision.TMX.Parser.parse!("data/Dun.tmx")

      # Collision world from map ("Walls" layer and objectgroup)
      world = ExCollision.TMX.WorldBuilder.from_tmx(map, collision_layer: "Walls")

      # Pathfinding over layer (walkability: GID=0). In Dun.tmx lines 18–28 are all zeros
      layer = ExCollision.TMX.Map.layer_by_name(map, "Floor")
      source = ExCollision.TMX.TileLayerTileSource.new(layer)
      {:ok, path} = ExCollision.Pathfinding.AStar.find_path(source, {5, 20}, {30, 25})

      # Player — Body. Every server tick: step(world, 1/60)
      {world, player_id} = ExCollision.World.add_body(world, ExCollision.World.Body.from_xywh(:player, 50, 50, 16, 16, velocity: {0, 0}))
      {:ok, world} = ExCollision.World.set_velocity(world, player_id, 32, 0)
      world = ExCollision.World.step(world, 1/60)  # every server tick

      # Interpolation for smooth rendering (alpha = time since last step / step interval)
      {:ok, {x, y}} = ExCollision.World.get_interpolated_position(world, player_id, 0.5)
  """

  # Delegates to submodules for convenient API
  defdelegate parse_tmx!(path_or_xml), to: ExCollision.TMX.Parser, as: :parse!
  defdelegate tmx_layer_by_name(map, name), to: ExCollision.TMX.Map, as: :layer_by_name
  @doc "A* pathfinding. Options: :allow_diagonal — allow diagonal movement (8 directions)"
  def find_path(tile_source, start, goal, opts \\ []) do
    ExCollision.Pathfinding.AStar.find_path(tile_source, start, goal, opts)
  end

  def world_from_tmx(tmx_map, opts \\ []) do
    ExCollision.TMX.WorldBuilder.from_tmx(tmx_map, opts)
  end

  @doc "World simulation step. Call every server tick, e.g.: world_step(world, 1/60)"
  defdelegate world_step(world, dt), to: ExCollision.World, as: :step

  @doc "Set body velocity (vx, vy) in pixels/sec"
  defdelegate world_set_velocity(world, body_id, vx, vy), to: ExCollision.World, as: :set_velocity

  @doc "Interpolated body position for rendering (alpha in 0..1)"
  defdelegate world_interpolated_position(world, body_id, alpha),
    to: ExCollision.World,
    as: :get_interpolated_position

  # API for adding/removing objects in the world
  @doc "Add object (Body) to world. Returns {world, id}."
  defdelegate world_add_object(world, body), to: ExCollision.World, as: :add_object

  @doc "Remove object from world by id."
  defdelegate world_remove_object(world, id), to: ExCollision.World, as: :remove_object

  @doc "Get object by id"
  defdelegate world_get_object(world, id), to: ExCollision.World, as: :get_object

  @doc "Check if object with id exists in world"
  defdelegate world_has_object?(world, id), to: ExCollision.World, as: :has_body?

  @doc "List of all object ids in world"
  defdelegate world_object_ids(world), to: ExCollision.World, as: :body_ids

  @doc "Remove static AABB by index. Returns {:ok, world} or {:error, :out_of_range}."
  defdelegate world_remove_static_at(world, index), to: ExCollision.World, as: :remove_static_at

  @doc "List of body ids intersecting the AABB (exclude_id — body to ignore). For bullets: where it would move — who it hit."
  defdelegate world_bodies_intersecting_aabb(world, aabb, exclude_id \\ nil),
    to: ExCollision.World,
    as: :bodies_intersecting_aabb
end

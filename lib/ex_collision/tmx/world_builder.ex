defmodule ExCollision.TMX.WorldBuilder do
  @moduledoc """
  Builds collision world from TMX map: adds static AABBs from tile layer
  and objectgroup. Provides unified interface via `Collidable` protocol for objects.
  """
  alias ExCollision.TMX.{Map, TileLayer, ObjectGroup, MapObject}
  alias ExCollision.Geometry.AABB
  alias ExCollision.World
  alias ExCollision.World.Body

  @doc """
  Creates world and fills it with static collisions from TMX map.

  Options:
  - `:collision_layer` — name of tile layer for collisions (e.g. "Walls"). Default: first layer named "Walls" or first tile layer.
  - `:collision_object_groups` — list of objectgroup names for collisions (e.g. ["Collision"]). Default: all objectgroups.
  - `:tile_width`, `:tile_height` — tile size in pixels (from map if not set).
  """
  @spec from_tmx(Map.t(), keyword()) :: World.t()
  def from_tmx(%Map{} = tmx_map, opts \\ []) do
    world = World.new()
    tw = Keyword.get(opts, :tile_width, tmx_map.tile_width)
    th = Keyword.get(opts, :tile_height, tmx_map.tile_height)

    world =
      tmx_map.layers
      |> Enum.reduce(world, fn layer, acc ->
        add_layer_collisions(acc, layer, tmx_map, tw, th, opts)
      end)

    world
  end

  defp add_layer_collisions(world, %TileLayer{} = layer, _tmx_map, tw, th, opts) do
    collision_name = Keyword.get(opts, :collision_layer, "Walls")
    layer_name = to_string(layer.name)

    if layer_name == collision_name do
      add_tile_layer_collisions(world, layer, tw, th)
    else
      world
    end
  end

  defp add_layer_collisions(world, %ObjectGroup{} = group, _tmx_map, _tw, _th, opts) do
    allowed = Keyword.get(opts, :collision_object_groups, :all)
    name = to_string(group.name)

    if allowed == :all or name in List.wrap(allowed) do
      add_object_group_collisions(world, group)
    else
      world
    end
  end

  defp add_layer_collisions(world, _other, _tmx_map, _tw, _th, _opts), do: world

  defp add_tile_layer_collisions(world, layer, tw, th) do
    layer.data
    |> Enum.with_index()
    |> Enum.reduce(world, fn {gid, idx}, acc ->
      if gid != 0 do
        {x, y} = index_to_xy(idx, layer.width)
        aabb = AABB.from_xywh(x * tw, y * th, tw, th)
        World.add_static(acc, aabb)
      else
        acc
      end
    end)
  end

  defp add_object_group_collisions(world, group) do
    Enum.reduce(group.objects, world, fn obj, acc ->
      aabb = object_to_aabb(obj)
      if aabb, do: World.add_static(acc, aabb), else: acc
    end)
  end

  defp object_to_aabb(%MapObject{width: w, height: h, x: x, y: y})
       when is_number(w) and is_number(h) and w > 0 and h > 0 do
    # Tiled: y is bottom edge for orthogonal
    AABB.from_xywh(x, y, w, h)
  end

  defp object_to_aabb(%MapObject{polygon_points: [_ | _] = points}) do
    # Bounding box of polygon
    {xs, ys} = Enum.unzip(points)
    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)
    AABB.new(min_x, min_y, max_x, max_y)
  end

  defp object_to_aabb(%MapObject{polyline_points: [_ | _] = points}) do
    {xs, ys} = Enum.unzip(points)
    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)
    AABB.new(min_x, min_y, max_x, max_y)
  end

  defp object_to_aabb(_), do: nil

  defp index_to_xy(idx, width) do
    {rem(idx, width), div(idx, width)}
  end

  @doc """
  Creates dynamic body (Body) at MapObject position — for spawning player/entity from TMX point.
  MapObject must have width and height (rectangle). Options: :velocity, :data.
  """
  @spec body_from_map_object(MapObject.t(), term(), keyword()) :: Body.t() | nil
  def body_from_map_object(%MapObject{width: w, height: h, x: x, y: y}, id, opts \\ [])
      when is_number(w) and is_number(h) and w > 0 and h > 0 do
    Body.from_xywh(id, x, y, w, h, opts)
  end

  # def body_from_map_object(_map_object, _id, _opts), do: nil
end

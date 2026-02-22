defprotocol ExCollision.Protocols.TileSource do
  @moduledoc """
  Protocol for tile grid sources (TMX layer, world tilemap).
  Provides tile GID by coordinates and walkability checks.
  """
  @doc "Width in tiles"
  def width(source)

  @doc "Height in tiles"
  def height(source)

  @doc "Tile GID by index (column + row * width), 0 = empty"
  def tile_at(source, index)

  @doc "Whether tile is walkable (not a wall) for pathfinding. Default: gid == 0 is walkable"
  def walkable?(source, index)
end

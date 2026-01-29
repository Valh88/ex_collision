defprotocol ExCollision.Protocols.TileSource do
  @moduledoc """
  Протокол для источников тайловой сетки (слой TMX, тайлмап мира).
  Позволяет получать GID по координатам тайла и проверять проходимость.
  """
  @doc "Ширина в тайлах"
  def width(source)

  @doc "Высота в тайлах"
  def height(source)

  @doc "GID тайла по индексу (column + row * width), 0 = пусто"
  def tile_at(source, index)

  @doc "Проходим ли тайл (не стена) для pathfinding. По умолчанию: gid == 0 — проходимо"
  def walkable?(source, index)
end

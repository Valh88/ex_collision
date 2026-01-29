defimpl ExCollision.Protocols.TileSource, for: ExCollision.TMX.TileLayer do
  def width(%{width: w}), do: w
  def height(%{height: h}), do: h

  def tile_at(%{data: data}, index) when index >= 0 do
    if index < length(data), do: Enum.at(data, index, 0), else: 0
  end

  def tile_at(_, _), do: 0

  def walkable?(source, index) do
    ExCollision.Protocols.TileSource.tile_at(source, index) == 0
  end
end

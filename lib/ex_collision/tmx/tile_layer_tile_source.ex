defmodule ExCollision.TMX.TileLayerTileSource do
  @moduledoc """
  TileLayer delegate/wrapper for TileSource protocol.
  Allows using TMX layer for pathfinding and walkability checks.
  Options: `:solid_gids` — list of GIDs treated as walls (default: any non-zero is wall).
  """
  defstruct [:layer, :solid_gids]

  @type t :: %__MODULE__{
          layer: ExCollision.TMX.TileLayer.t(),
          solid_gids: :all_nonzero | MapSet.t(non_neg_integer())
        }

  def new(layer, opts \\ []) do
    solid = Keyword.get(opts, :solid_gids, :all_nonzero)
    %__MODULE__{layer: layer, solid_gids: solid}
  end
end

defimpl ExCollision.Protocols.TileSource, for: ExCollision.TMX.TileLayerTileSource do
  def width(%{layer: layer}), do: layer.width
  def height(%{layer: layer}), do: layer.height

  def tile_at(%{layer: layer}, index) when index >= 0 do
    data = layer.data
    if index < length(data), do: Enum.at(data, index, 0), else: 0
  end

  def tile_at(_, _), do: 0

  def walkable?(source, index) do
    gid = ExCollision.Protocols.TileSource.tile_at(source, index)
    solid?(source, gid)
  end

  defp solid?(%{solid_gids: :all_nonzero}, 0), do: true
  defp solid?(%{solid_gids: :all_nonzero}, _), do: false
  defp solid?(%{solid_gids: set}, gid) when is_map(set), do: not MapSet.member?(set, gid)
end

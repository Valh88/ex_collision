defmodule ExCollision.TMX.Map do
  @moduledoc """
  Структура карты Tiled TMX.
  """
  @enforce_keys [:width, :height, :tile_width, :tile_height]
  defstruct [
    :version,
    :orientation,
    :render_order,
    :next_layer_id,
    :next_object_id,
    :tilesets,
    :layers,
    width: 0,
    height: 0,
    tile_width: 16,
    tile_height: 16
  ]

  @doc "Возвращает слой по имени (tile layer или object group)"
  def layer_by_name(%__MODULE__{layers: layers}, name) when is_binary(name) do
    name_str = name

    Enum.find(layers, fn
      %{name: n} when is_list(n) -> to_string(n) == name_str
      %{name: n} when is_binary(n) -> n == name_str
      _ -> false
    end)
  end

  @type t :: %__MODULE__{
          version: String.t() | nil,
          orientation: String.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          tile_width: non_neg_integer(),
          tile_height: non_neg_integer(),
          render_order: String.t(),
          next_layer_id: non_neg_integer(),
          next_object_id: non_neg_integer(),
          tilesets: [ExCollision.TMX.Tileset.t()],
          layers: [ExCollision.TMX.Layer.t()]
        }
end

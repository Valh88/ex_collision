defmodule ExCollision.TMX.Tileset do
  @moduledoc """
  Набор тайлов из TMX.
  """
  defstruct [:first_gid, :name, :tile_width, :tile_height, :columns, :tile_count]

  @type t :: %__MODULE__{
          first_gid: non_neg_integer(),
          name: String.t() | charlist(),
          tile_width: non_neg_integer(),
          tile_height: non_neg_integer(),
          columns: non_neg_integer() | nil,
          tile_count: non_neg_integer() | nil
        }
end

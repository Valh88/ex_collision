defmodule ExCollision.TMX.TileLayer do
  @moduledoc """
  TMX tile layer (tile grid with data).
  """
  defstruct [:id, :name, :width, :height, :opacity, :visible, :data]

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          name: String.t() | charlist(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          opacity: float(),
          visible: boolean(),
          data: [non_neg_integer()]
        }
end

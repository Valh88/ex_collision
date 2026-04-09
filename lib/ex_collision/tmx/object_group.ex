defmodule ExCollision.TMX.ObjectGroup do
  @moduledoc """
  TMX object layer (rectangles, polygons, etc.).
  """
  defstruct [:id, :name, :visible, :objects, properties: %{}]

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          name: String.t() | charlist(),
          visible: boolean(),
          objects: [ExCollision.TMX.MapObject.t()],
          properties: %{String.t() => term()}
        }
end

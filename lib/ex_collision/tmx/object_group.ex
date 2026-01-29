defmodule ExCollision.TMX.ObjectGroup do
  @moduledoc """
  Слой объектов TMX (прямоугольники, полигоны и т.д.).
  """
  defstruct [:id, :name, :visible, :objects]

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          name: String.t() | charlist(),
          visible: boolean(),
          objects: [ExCollision.TMX.MapObject.t()]
        }
end

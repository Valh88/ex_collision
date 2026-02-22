defmodule ExCollision.TMX.MapObject do
  @moduledoc """
  Static object on TMX map (rectangle, polygon, polyline).
  Used for collisions and markup from objectgroup.

  Player and moving entities are not MapObject but `ExCollision.World.Body`
  in the collision world. MapObject describes static; Body — dynamic (velocity, interpolation).
  """
  defstruct [
    :id,
    :gid,
    :name,
    :type,
    :x,
    :y,
    :width,
    :height,
    :rotation,
    :visible,
    :polygon_points,
    :polyline_points
  ]

  @type t :: %__MODULE__{
          id: non_neg_integer() | nil,
          gid: non_neg_integer() | nil,
          name: String.t() | charlist(),
          type: String.t() | charlist(),
          x: float(),
          y: float(),
          width: float() | nil,
          height: float() | nil,
          rotation: float(),
          visible: boolean(),
          polygon_points: [{float(), float()}],
          polyline_points: [{float(), float()}]
        }
end

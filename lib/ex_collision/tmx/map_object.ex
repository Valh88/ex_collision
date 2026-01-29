defmodule ExCollision.TMX.MapObject do
  @moduledoc """
  Статический объект на карте TMX (прямоугольник, полигон, полилиния).
  Используется для коллизий и разметки из objectgroup.

  Игрок и движущиеся сущности — это не MapObject, а `ExCollision.World.Body`
  в мире коллизий. MapObject описывает статику; Body — динамику (velocity, интерполяция).
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

defmodule ExCollision.Geometry.AABB do
  @moduledoc """
  Axis-Aligned Bounding Box. Used for collisions and bodies in the world.
  Implements `ExCollision.Protocols.Collidable` protocol.
  """
  defstruct [:min_x, :min_y, :max_x, :max_y]

  alias ExCollision.Geometry.Vec2

  @type t :: %__MODULE__{
          min_x: number(),
          min_y: number(),
          max_x: number(),
          max_y: number()
        }

  def new(min_x, min_y, max_x, max_y) do
    %__MODULE__{
      min_x: min(min_x, max_x),
      min_y: min(min_y, max_y),
      max_x: max(min_x, max_x),
      max_y: max(min_y, max_y)
    }
  end

  def from_xywh(x, y, width, height) when width >= 0 and height >= 0 do
    new(x, y, x + width, y + height)
  end

  def from_xywh(x, y, width, height) do
    new(x + width, y + height, x, y)
  end

  def width(%__MODULE__{min_x: min_x, max_x: max_x}), do: max_x - min_x
  def height(%__MODULE__{min_y: min_y, max_y: max_y}), do: max_y - min_y

  def center(%__MODULE__{min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y}) do
    Vec2.new((min_x + max_x) / 2, (min_y + max_y) / 2)
  end

  def from_center(center_x, center_y, width, height) do
    half_width = width / 2
    half_height = height / 2

    new(
      center_x - half_width,
      center_y - half_height,
      center_x + half_width,
      center_y + half_height
    )
  end

  def contains_point?(%__MODULE__{min_x: mx, min_y: my, max_x: xx, max_y: xy}, px, py) do
    px >= mx and px <= xx and py >= my and py <= xy
  end

  def intersects?(
        %__MODULE__{min_x: a_min_x, min_y: a_min_y, max_x: a_max_x, max_y: a_max_y},
        %__MODULE__{min_x: b_min_x, min_y: b_min_y, max_x: b_max_x, max_y: b_max_y}
      ) do
    a_min_x <= b_max_x and a_max_x >= b_min_x and a_min_y <= b_max_y and a_max_y >= b_min_y
  end

  def expand(%__MODULE__{min_x: mx, min_y: my, max_x: xx, max_y: xy}, delta) do
    %__MODULE__{
      min_x: mx - delta,
      min_y: my - delta,
      max_x: xx + delta,
      max_y: xy + delta
    }
  end
end

defimpl ExCollision.Protocols.Collidable, for: ExCollision.Geometry.AABB do
  def aabb(aabb), do: aabb
end

defimpl Inspect, for: ExCollision.Geometry.AABB do
  def inspect(%{min_x: mx, min_y: my, max_x: xx, max_y: xy}, _opts) do
    "AABB(#{mx}, #{my}, #{xx}, #{xy})"
  end
end

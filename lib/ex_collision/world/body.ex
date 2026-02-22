defmodule ExCollision.World.Body do
  @moduledoc """
  Dynamic body in the collision world (AABB + metadata).
  Implements the `Collidable` protocol.

  Player and other moving objects are Body in the world, not MapObject.
  MapObject — static objects from TMX (objectgroup); Body — dynamic bodies with velocity and interpolation.

  Option `:on_collision` — function (world, body_id, collided_ids, hit_static) -> world,
  called on collision; can remove body (bullet), apply damage, etc.
   (world, body_id, collided_body_ids, hit_static) -> world
    world — current world
    body_id — id of the body that collided
    collided_body_ids — list of body ids that were hit (e.g. players)
    hit_static — true if collision with static (wall, etc.)
  """
  defstruct [:id, :aabb, :previous_aabb, :velocity, :static, :data, :on_collision]

  alias ExCollision.Geometry.AABB

  @type collision_callback :: (world :: term(),
                               body_id :: term(),
                               collided_body_ids :: [term()],
                               hit_static :: boolean() ->
                                 world :: term())
  @type t :: %__MODULE__{
          id: term(),
          aabb: AABB.t(),
          previous_aabb: AABB.t() | nil,
          velocity: {float(), float()} | nil,
          static: boolean(),
          data: term(),
          on_collision: collision_callback | nil
        }

  def new(id, aabb, opts \\ []) do
    static = Keyword.get(opts, :static, false)
    data = Keyword.get(opts, :data, nil)
    velocity = Keyword.get(opts, :velocity, nil)
    on_collision = Keyword.get(opts, :on_collision, nil)

    %__MODULE__{
      id: id,
      aabb: aabb,
      previous_aabb: nil,
      velocity: velocity,
      static: static,
      data: data,
      on_collision: on_collision
    }
  end

  def from_xywh(id, x, y, w, h, opts \\ []) do
    new(id, AABB.from_xywh(x, y, w, h), opts)
  end

  def from_center(id, center_x, center_y, width, height, opts \\ []) do
    new(id, AABB.from_center(center_x, center_y, width, height), opts)
  end

  @doc "Set collision callback: (world, body_id, [body ids], hit_static) -> world"
  def set_on_collision(%__MODULE__{} = body, callback)
      when is_function(callback, 4) or is_nil(callback) do
    %{body | on_collision: callback}
  end

  def move(%__MODULE__{aabb: aabb} = body, dx, dy) do
    %__MODULE__{
      body
      | aabb: %AABB{
          min_x: aabb.min_x + dx,
          min_y: aabb.min_y + dy,
          max_x: aabb.max_x + dx,
          max_y: aabb.max_y + dy
        }
    }
  end

  def position(%__MODULE__{aabb: aabb}) do
    {aabb.min_x, aabb.min_y}
  end

  @doc "AABB center (for rendering)"
  def center(%__MODULE__{aabb: aabb}) do
    AABB.center(aabb)
  end

  @doc "Set body velocity (vx, vy) in pixels/sec"
  def set_velocity(%__MODULE__{} = body, vx, vy) when is_number(vx) and is_number(vy) do
    %{body | velocity: {vx, vy}}
  end

  @doc "Clear velocity"
  def set_velocity(%__MODULE__{} = body, nil), do: %{body | velocity: nil}

  @doc """
  Interpolated center position for smooth rendering.
  alpha in [0, 1]: 0 = previous frame, 1 = current frame.
  If previous_aabb is nil, returns current center.
  """
  def interpolated_center(%__MODULE__{aabb: aabb, previous_aabb: nil}, _alpha) do
    AABB.center(aabb)
  end

  def interpolated_center(%__MODULE__{aabb: aabb, previous_aabb: prev}, alpha)
      when is_number(alpha) do
    %ExCollision.Geometry.Vec2{x: cx, y: cy} = AABB.center(aabb)
    %ExCollision.Geometry.Vec2{x: px, y: py} = AABB.center(prev)
    # prev + (current - prev) * alpha
    {
      px + (cx - px) * alpha,
      py + (cy - py) * alpha
    }
  end

  @doc "Interpolated top-left corner (min_x, min_y)"
  def interpolated_position(%__MODULE__{aabb: aabb, previous_aabb: nil}, _alpha) do
    {aabb.min_x, aabb.min_y}
  end

  def interpolated_position(%__MODULE__{aabb: aabb, previous_aabb: prev}, alpha)
      when is_number(alpha) do
    {
      prev.min_x + (aabb.min_x - prev.min_x) * alpha,
      prev.min_y + (aabb.min_y - prev.min_y) * alpha
    }
  end
end

defimpl ExCollision.Protocols.Collidable, for: ExCollision.World.Body do
  def aabb(%{aabb: aabb}), do: aabb
end

defimpl Inspect, for: ExCollision.World.Body do
  def inspect(
        %{id: id, aabb: aabb, static: static, velocity: vel, on_collision: on_collision},
        _opts
      ) do
    "Body(#{inspect(id)}, #{inspect(aabb)}, static: #{static}, velocity: #{inspect(vel)}), on_collision: #{inspect(on_collision)}"
  end
end

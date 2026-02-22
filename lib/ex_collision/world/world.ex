defmodule ExCollision.World do
  @moduledoc """
  Collision world: static and dynamic bodies (AABB).
  Supports collision checks and simulation (step with collision resolution).
  Implements `Enumerable` over bodies.
  """
  defstruct [:bodies, :static_bodies, :next_id]

  alias ExCollision.World.Body
  alias ExCollision.Geometry.AABB

  @type t :: %__MODULE__{
          bodies: %{term() => Body.t()},
          static_bodies: [AABB.t()],
          next_id: non_neg_integer()
        }

  def new(opts \\ []) do
    %__MODULE__{
      bodies: %{},
      static_bodies: [],
      next_id: Keyword.get(opts, :next_id, 0)
    }
  end

  @doc "Add static AABB (e.g. from tiles or objectgroup)"
  def add_static(world, aabb) when is_struct(aabb, AABB) do
    update_in(world.static_bodies, &[aabb | &1])
  end

  @doc "Remove static AABB by index (0 = first added). Returns {:ok, world} or {:error, :out_of_range}."
  def remove_static_at(world, index) when is_integer(index) and index >= 0 do
    if index < length(world.static_bodies) do
      new_static = List.delete_at(world.static_bodies, index)
      {:ok, %{world | static_bodies: new_static}}
    else
      {:error, :out_of_range}
    end
  end

  @doc "Number of static AABBs in the world"
  def static_count(world), do: length(world.static_bodies)

  @doc "Add body and return {world, body_id}"
  def add_body(world, body) when is_struct(body, Body) do
    id = body.id || world.next_id

    world =
      world
      |> put_in([Access.key(:bodies), id], %{body | id: id})
      |> update_in([Access.key(:next_id)], &(&1 + 1))

    {world, id}
  end

  @doc "Add object (dynamic body) to world. Returns {world, id}."
  def add_object(world, body) when is_struct(body, Body), do: add_body(world, body)

  @doc "Remove body by id"
  def remove_body(world, id) do
    update_in(world.bodies, &Map.delete(&1, id))
  end

  @doc "Remove object (body) from world by id. Returns updated world."
  def remove_object(world, id), do: remove_body(world, id)

  @doc "Get body by id"
  def get_body(world, id), do: Map.get(world.bodies, id)

  @doc "Get object (body) by id"
  def get_object(world, id), do: get_body(world, id)

  @doc "Check if body/object with given id exists in world"
  def has_body?(world, id), do: Map.has_key?(world.bodies, id)

  @doc "List of all object (body) ids in world"
  def body_ids(world), do: Map.keys(world.bodies)

  @doc "Check if two bodies intersect (e.g. bullet and player)"
  def bodies_intersect?(world, body_id_a, body_id_b) do
    a = get_body(world, body_id_a)
    b = get_body(world, body_id_b)
    a != nil and b != nil and AABB.intersects?(a.aabb, b.aabb)
  end

  @doc """
  List of body ids intersecting the given AABB (e.g. where a bullet would move).
  exclude_body_id — body to ignore (the bullet itself).
  Useful for bullet collision: where it would move — who it hit.
  """
  def bodies_intersecting_aabb(world, aabb, exclude_body_id \\ nil) do
    world.bodies
    |> Map.drop([exclude_body_id])
    |> Enum.filter(fn {_id, body} -> AABB.intersects?(body.aabb, aabb) end)
    |> Enum.map(fn {id, _body} -> id end)
  end

  @doc "Check if AABB collides with world (static or body)"
  def collides?(world, aabb, exclude_body_id \\ nil) do
    collides_static?(world.static_bodies, aabb) or
      collides_any_body?(world.bodies, aabb, exclude_body_id)
  end

  defp collides_static?([], _), do: false

  defp collides_static?([s | rest], aabb) do
    AABB.intersects?(s, aabb) or collides_static?(rest, aabb)
  end

  defp collides_any_body?(bodies, aabb, exclude) do
    bodies
    |> Map.drop([exclude])
    |> Map.values()
    |> Enum.any?(fn body -> AABB.intersects?(body.aabb, aabb) end)
  end

  @doc """
  Try to move body by (dx, dy); on collision the body does not move.
  If body has `on_collision` set, it is called with (world, body_id, [collided body ids], hit_static);
  callback returns updated world (e.g. remove bullet, apply damage).
  Returns {:ok, world, body} | {:collision, world, body} | {:error, :not_found}.
  """
  def move_body(world, body_id, dx, dy) do
    case get_body(world, body_id) do
      nil ->
        {:error, :not_found}

      body ->
        if body.static do
          {:ok, world, body}
        else
          new_aabb =
            AABB.new(
              body.aabb.min_x + dx,
              body.aabb.min_y + dy,
              body.aabb.max_x + dx,
              body.aabb.max_y + dy
            )

          if collides?(world, new_aabb, body_id) do
            collided_ids = bodies_intersecting_aabb(world, new_aabb, body_id)
            hit_static = collides_static?(world.static_bodies, new_aabb)
            world = run_collision_callback(world, body, body_id, collided_ids, hit_static)
            {:collision, world, body}
          else
            new_body = %{body | aabb: new_aabb, previous_aabb: body.aabb}
            world = put_in(world.bodies[body_id], new_body)
            {:ok, world, new_body}
          end
        end
    end
  end

  def update_coordinates(world, body_id, x, y, opts \\ []) do
    case get_body(world, body_id) do
      nil ->
        {:error, :not_found}

      body ->
        if body.static do
          {:ok, world, body}
        else
          width = Keyword.get(opts, :width, 60)
          height = Keyword.get(opts, :height, 60)
          new_aabb =
            AABB.from_center(
              x,
              y,
              width,
              height
            )

          if collides?(world, new_aabb, body_id) do
            collided_ids = bodies_intersecting_aabb(world, new_aabb, body_id)
            hit_static = collides_static?(world.static_bodies, new_aabb)
            world = run_collision_callback(world, body, body_id, collided_ids, hit_static)
            {:collision, world, body}
          else
            new_body = %{body | aabb: new_aabb, previous_aabb: body.aabb}
            world = put_in(world.bodies[body_id], new_body)
            {:ok, world, new_body}
          end
        end
    end
  end

  defp run_collision_callback(world, body, body_id, collided_ids, hit_static) do
    case body.on_collision do
      nil ->
        world

      callback when is_function(callback, 4) ->
        callback.(world, body_id, collided_ids, hit_static)

      _ ->
        world
    end
  end

  @doc "Update body in world"
  def put_body(world, body) do
    put_in(world.bodies[body.id], body)
  end

  @doc "Update object (body) in world by its id"
  def put_object(world, body) when is_struct(body, Body), do: put_body(world, body)

  @doc "Set body velocity (vx, vy) in pixels/sec"
  def set_velocity(world, body_id, vx, vy) do
    case get_body(world, body_id) do
      nil ->
        {:error, :not_found}

      body ->
        body = Body.set_velocity(body, vx, vy)
        {:ok, put_body(world, body)}
    end
  end

  @doc """
  World simulation step: for each dynamic body with velocity applies movement,
  stores previous_aabb for interpolation, resolves collisions (on collision movement is reverted).
  Returns updated world.

  Call every server tick (e.g. in GenServer or game loop):
  `world = World.step(world, dt)`.
  - **dt** — step time in seconds. For fixed 60 ticks/sec use `1/60`.
  - For deterministic simulation use fixed dt; for real-time use actual interval between ticks.
  """
  def step(world, dt) when is_number(dt) and dt >= 0 do
    world.bodies
    |> Map.values()
    |> Enum.reduce(world, fn body, acc ->
      if body.static or body.velocity == nil do
        # Keep previous_aabb even for static/no velocity (for interpolation)
        body = %{body | previous_aabb: body.aabb}
        put_body(acc, body)
      else
        {vx, vy} = body.velocity
        dx = vx * dt
        dy = vy * dt
        body_with_prev = %{body | previous_aabb: body.aabb}
        acc = put_body(acc, body_with_prev)

        case move_body(acc, body.id, dx, dy) do
          {:ok, new_world, _new_body} -> new_world
          # Use world after callback (callback may have removed body, applied damage, etc.)
          {:collision, updated_world, _body} -> updated_world
          {:error, _} -> acc
        end
      end
    end)
  end

  @doc """
  Interpolated body position for smooth rendering.
  alpha in [0, 1]: 0 = previous frame, 1 = current (e.g.: time_since_step / step_interval).
  Returns {:ok, {x, y}} — top-left corner, or {:error, :not_found}.
  """
  def get_interpolated_position(world, body_id, alpha) do
    case get_body(world, body_id) do
      nil -> {:error, :not_found}
      body -> {:ok, Body.interpolated_position(body, alpha)}
    end
  end

  @doc "Interpolated body center (for sprite rendering by center)"
  def get_interpolated_center(world, body_id, alpha) do
    case get_body(world, body_id) do
      nil -> {:error, :not_found}
      body -> {:ok, Body.interpolated_center(body, alpha)}
    end
  end

  @doc "Number of bodies"
  def body_count(world) do
    map_size(world.bodies)
  end
end

defimpl Enumerable, for: ExCollision.World do
  def count(world), do: {:ok, ExCollision.World.body_count(world)}
  def member?(world, body), do: {:ok, body in Map.values(world.bodies)}
  def slice(_), do: {:error, __MODULE__}

  def reduce(world, acc, fun) do
    Enumerable.List.reduce(Map.values(world.bodies), acc, fun)
  end
end

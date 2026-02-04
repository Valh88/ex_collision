defmodule ExCollision.World do
  @moduledoc """
  Мир коллизий: статические и динамические тела (AABB).
  Поддерживает проверку коллизий и симуляцию (шаг с разрешением коллизий).
  Реализует `Enumerable` по телам.
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

  @doc "Добавить статическое AABB (например, из тайлов или objectgroup)"
  def add_static(world, aabb) when is_struct(aabb, AABB) do
    update_in(world.static_bodies, &[aabb | &1])
  end

  @doc "Удалить статический AABB по индексу (0 = первый добавленный). Возвращает {:ok, world} или {:error, :out_of_range}."
  def remove_static_at(world, index) when is_integer(index) and index >= 0 do
    if index < length(world.static_bodies) do
      new_static = List.delete_at(world.static_bodies, index)
      {:ok, %{world | static_bodies: new_static}}
    else
      {:error, :out_of_range}
    end
  end

  @doc "Количество статических AABB в мире"
  def static_count(world), do: length(world.static_bodies)

  @doc "Добавить тело и вернуть {world, body_id}"
  def add_body(world, body) when is_struct(body, Body) do
    id = body.id || world.next_id

    world =
      world
      |> put_in([Access.key(:bodies), id], %{body | id: id})
      |> update_in([Access.key(:next_id)], &(&1 + 1))

    {world, id}
  end

  @doc "Добавить объект (динамическое тело) в мир. Возвращает {world, id}."
  def add_object(world, body) when is_struct(body, Body), do: add_body(world, body)

  @doc "Удалить тело по id"
  def remove_body(world, id) do
    update_in(world.bodies, &Map.delete(&1, id))
  end

  @doc "Удалить объект (тело) из мира по id. Возвращает обновлённый мир."
  def remove_object(world, id), do: remove_body(world, id)

  @doc "Получить тело по id"
  def get_body(world, id), do: Map.get(world.bodies, id)

  @doc "Получить объект (тело) по id"
  def get_object(world, id), do: get_body(world, id)

  @doc "Проверить, есть ли тело/объект с данным id в мире"
  def has_body?(world, id), do: Map.has_key?(world.bodies, id)

  @doc "Список id всех объектов (тел) в мире"
  def body_ids(world), do: Map.keys(world.bodies)

  @doc "Проверить, пересекаются ли два тела (например пуля и игрок)"
  def bodies_intersect?(world, body_id_a, body_id_b) do
    a = get_body(world, body_id_a)
    b = get_body(world, body_id_b)
    a != nil and b != nil and AABB.intersects?(a.aabb, b.aabb)
  end

  @doc """
  Список id тел, пересекающих заданный AABB (например куда хотела перейти пуля).
  exclude_body_id — не учитывать это тело (саму пулю).
  Удобно при коллизии пули: куда бы она перешла — в кого попала.
  """
  def bodies_intersecting_aabb(world, aabb, exclude_body_id \\ nil) do
    world.bodies
    |> Map.drop([exclude_body_id])
    |> Enum.filter(fn {_id, body} -> AABB.intersects?(body.aabb, aabb) end)
    |> Enum.map(fn {id, _body} -> id end)
  end

  @doc "Проверить, пересекается ли AABB с миром (статикой или телом)"
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
  Попытаться сдвинуть тело на (dx, dy); при коллизии тело не двигается.
  Если у тела задан `on_collision`, вызывается с (world, body_id, [id столкнувшихся тел], hit_static);
  колбек возвращает обновлённый мир (например, удалить пулю, нанести урон).
  Возвращает {:ok, world, body} | {:collision, world, body} | {:error, :not_found}.
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
            new_body = %{body | aabb: new_aabb}
            world = put_in(world.bodies[body_id], new_body)
            {:ok, world, new_body}
          end
        end
    end
  end

  def update_coordinates(world, body_id, x, y) do
    case get_body(world, body_id) do
      nil ->
        {:error, :not_found}

      body ->
        if body.static do
          {:ok, world, body}
        else
          new_aabb =
            AABB.new(
              x,
              y,
              x + body.aabb.width,
              y + body.aabb.height
            )

          if collides?(world, new_aabb, body_id) do
            collided_ids = bodies_intersecting_aabb(world, new_aabb, body_id)
            hit_static = collides_static?(world.static_bodies, new_aabb)
            world = run_collision_callback(world, body, body_id, collided_ids, hit_static)
            {:collision, world, body}
          else
            new_body = %{body | aabb: new_aabb}
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

  @doc "Обновить тело в мире"
  def put_body(world, body) do
    put_in(world.bodies[body.id], body)
  end

  @doc "Обновить объект (тело) в мире по его id"
  def put_object(world, body) when is_struct(body, Body), do: put_body(world, body)

  @doc "Задать скорость тела (vx, vy) в пикселях/сек"
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
  Шаг симуляции мира: для каждого динамического тела с velocity применяет движение,
  сохраняет previous_aabb для интерполяции, разрешает коллизии (при столкновении движение отменяется).
  Возвращает обновлённый мир.

  Вызывайте каждый серверный тик (например, в GenServer или игровом цикле):
  `world = World.step(world, dt)`.
  - **dt** — время шага в секундах. При фиксированном тике 60 раз/сек используйте `1/60`.
  - Для детерминированной симуляции лучше фиксированный dt; для привязки к реальному времени — фактический интервал между тиками.
  """
  def step(world, dt) when is_number(dt) and dt >= 0 do
    world.bodies
    |> Map.values()
    |> Enum.reduce(world, fn body, acc ->
      if body.static or body.velocity == nil do
        # Сохраняем previous_aabb даже для статики/без скорости (для интерполяции)
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
          # Используем мир после колбека (колбек мог удалить тело, нанести урон и т.д.)
          {:collision, updated_world, _body} -> updated_world
          {:error, _} -> acc
        end
      end
    end)
  end

  @doc """
  Интерполированная позиция тела для плавной отрисовки.
  alpha in [0, 1]: 0 = предыдущий кадр, 1 = текущий (например: time_since_step / step_interval).
  Возвращает {:ok, {x, y}} — левый верхний угол, или {:error, :not_found}.
  """
  def get_interpolated_position(world, body_id, alpha) do
    case get_body(world, body_id) do
      nil -> {:error, :not_found}
      body -> {:ok, Body.interpolated_position(body, alpha)}
    end
  end

  @doc "Интерполированный центр тела (для отрисовки спрайта по центру)"
  def get_interpolated_center(world, body_id, alpha) do
    case get_body(world, body_id) do
      nil -> {:error, :not_found}
      body -> {:ok, Body.interpolated_center(body, alpha)}
    end
  end

  @doc "Количество тел"
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

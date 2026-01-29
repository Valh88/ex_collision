defmodule ExCollision do
  @moduledoc """
  Библиотека для серверных коллизий, симуляции физического мира, поиска путей по тайлмапу и парсинга Tiled TMX.

  ## Основные возможности

  - **Парсинг TMX** — загрузка карт Tiled (тайловые слои, objectgroup, tilesets)
  - **Мир коллизий** — статические и динамические тела (AABB), проверка пересечений и симуляция шага
  - **Поиск путей** — A* по тайлмапу с поддержкой протокола `TileSource`
  - **Интеграция TMX → World** — построение мира коллизий из слоёв карты (Walls, objectgroup)

  ## Серверный цикл

  `World.step(world, dt)` вызывается каждый тик на сервере (например, 60 раз в секунду).
  Передавайте фиксированный `dt = 1/60` для детерминизма или фактический интервал между тиками.

  ## Пример

      # Парсинг TMX
      map = ExCollision.TMX.Parser.parse!("data/Dun.tmx")

      # Мир коллизий из карты (слой "Walls" и objectgroup)
      world = ExCollision.TMX.WorldBuilder.from_tmx(map, collision_layer: "Walls")

      # Поиск пути по слою (проходимость: GID=0). В Dun.tmx строки 18–28 — сплошные нули
      layer = ExCollision.TMX.Map.layer_by_name(map, "Floor")
      source = ExCollision.TMX.TileLayerTileSource.new(layer)
      {:ok, path} = ExCollision.Pathfinding.AStar.find_path(source, {5, 20}, {30, 25})

      # Игрок — Body. Каждый серверный тик: step(world, 1/60)
      {world, player_id} = ExCollision.World.add_body(world, ExCollision.World.Body.from_xywh(:player, 50, 50, 16, 16, velocity: {0, 0}))
      {:ok, world} = ExCollision.World.set_velocity(world, player_id, 32, 0)
      world = ExCollision.World.step(world, 1/60)  # каждый тик на сервере

      # Интерполяция для плавной отрисовки (alpha = время с прошлого step / интервал step)
      {:ok, {x, y}} = ExCollision.World.get_interpolated_position(world, player_id, 0.5)
  """

  # Делегаты к подмодулям для удобного API
  defdelegate parse_tmx!(path_or_xml), to: ExCollision.TMX.Parser, as: :parse!
  defdelegate tmx_layer_by_name(map, name), to: ExCollision.TMX.Map, as: :layer_by_name
  @doc "Поиск пути A*. Опции: :allow_diagonal — разрешить ход по диагонали (8 направлений)"
  def find_path(tile_source, start, goal, opts \\ []) do
    ExCollision.Pathfinding.AStar.find_path(tile_source, start, goal, opts)
  end

  def world_from_tmx(tmx_map, opts \\ []) do
    ExCollision.TMX.WorldBuilder.from_tmx(tmx_map, opts)
  end

  @doc "Шаг симуляции мира. Вызывать каждый серверный тик, например: world_step(world, 1/60)"
  defdelegate world_step(world, dt), to: ExCollision.World, as: :step

  @doc "Задать скорость тела (vx, vy) в пикселях/сек"
  defdelegate world_set_velocity(world, body_id, vx, vy), to: ExCollision.World, as: :set_velocity

  @doc "Интерполированная позиция тела для отрисовки (alpha in 0..1)"
  defdelegate world_interpolated_position(world, body_id, alpha),
    to: ExCollision.World,
    as: :get_interpolated_position

  # API добавления/удаления объектов в мире
  @doc "Добавить объект (Body) в мир. Возвращает {world, id}."
  defdelegate world_add_object(world, body), to: ExCollision.World, as: :add_object

  @doc "Удалить объект из мира по id."
  defdelegate world_remove_object(world, id), to: ExCollision.World, as: :remove_object

  @doc "Получить объект по id"
  defdelegate world_get_object(world, id), to: ExCollision.World, as: :get_object

  @doc "Проверить, есть ли объект с id в мире"
  defdelegate world_has_object?(world, id), to: ExCollision.World, as: :has_body?

  @doc "Список id всех объектов в мире"
  defdelegate world_object_ids(world), to: ExCollision.World, as: :body_ids

  @doc "Удалить статический AABB по индексу. Возвращает {:ok, world} или {:error, :out_of_range}."
  defdelegate world_remove_static_at(world, index), to: ExCollision.World, as: :remove_static_at

  @doc "Список id тел, пересекающих AABB (exclude_id — кого не учитывать). Для пули: куда бы она перешла — в кого попала."
  defdelegate world_bodies_intersecting_aabb(world, aabb, exclude_id \\ nil),
    to: ExCollision.World,
    as: :bodies_intersecting_aabb
end

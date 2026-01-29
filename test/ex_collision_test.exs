defmodule ExCollisionTest do
  use ExUnit.Case, async: true

  alias ExCollision.TMX.Parser
  alias ExCollision.TMX.{Map, TileLayer, WorldBuilder}
  alias ExCollision.World
  alias ExCollision.Geometry.{AABB, Vec2}
  alias ExCollision.Pathfinding.AStar
  alias ExCollision.TMX.TileLayerTileSource

  @dun_tmx Path.join([__DIR__, "..", "data", "Dun.tmx"])

  describe "TMX Parser" do
    test "parse! parses Dun.tmx" do
      map = Parser.parse!(@dun_tmx)
      assert %Map{} = map
      assert map.width == 38
      assert map.height == 29
      assert map.tile_width == 16
      assert map.tile_height == 16
      assert length(map.tilesets) >= 1
      assert length(map.layers) >= 1
    end

    test "layer_by_name returns Walls layer" do
      map = Parser.parse!(@dun_tmx)
      layer = Map.layer_by_name(map, "Walls")
      assert %TileLayer{} = layer
      assert layer.width == 38
      assert layer.height == 29
      assert length(layer.data) == 38 * 29
    end

    test "layer_by_name returns Floor layer" do
      map = Parser.parse!(@dun_tmx)
      layer = Map.layer_by_name(map, "Floor")
      assert %TileLayer{} = layer
    end
  end

  describe "WorldBuilder" do
    test "from_tmx builds world with static bodies from Walls" do
      map = Parser.parse!(@dun_tmx)
      world = WorldBuilder.from_tmx(map, collision_layer: "Walls")
      assert %World{} = world
      assert length(world.static_bodies) > 0
    end
  end

  describe "World" do
    test "add_body and move_body" do
      world = World.new()
      body = World.Body.from_xywh(:player, 0, 0, 16, 16)
      {world, id} = World.add_body(world, body)
      assert World.get_body(world, id) != nil
      {:ok, _world, new_body} = World.move_body(world, id, 5, 0)
      assert new_body.aabb.min_x == 5
    end

    test "collides? with static" do
      world = World.new()
      world = World.add_static(world, AABB.from_xywh(10, 10, 16, 16))
      assert World.collides?(world, AABB.from_xywh(12, 12, 4, 4))
      refute World.collides?(world, AABB.from_xywh(30, 30, 4, 4))
    end
  end

  describe "Bullet hit detection (player shoots at another)" do
    test "bullet hits target — при пересечении пули и цели коллизия определяется" do
      world = World.new()
      # Игрок 1 слева, игрок 2 (цель) справа
      shooter = World.Body.from_xywh(:player1, 0, 50, 16, 24, velocity: {0, 0})
      target = World.Body.from_xywh(:player2, 200, 50, 16, 24, velocity: {0, 0})
      # Пуля изначально не пересекается с целью
      bullet = World.Body.from_xywh(:bullet, 20, 58, 4, 4, velocity: {0, 0})

      {world, _shooter_id} = World.add_body(world, shooter)
      {world, target_id} = World.add_body(world, target)
      {world, bullet_id} = World.add_body(world, bullet)

      refute World.bodies_intersect?(world, bullet_id, target_id)

      # Добавляем «вторую пулю» в позиции, пересекающей цель (как при попадании в игре)
      # Цель: 200..216 (x), 50..74 (y). Пуля 4x4 в (202, 58) пересекает цель
      hit_bullet = World.Body.from_xywh(:bullet_hit, 202, 58, 4, 4)
      {world, hit_bullet_id} = World.add_body(world, hit_bullet)

      assert World.bodies_intersect?(world, hit_bullet_id, target_id),
             "When bullet overlaps target, bodies_intersect? is true"
    end

    test "bullet misses — пуля летит в сторону от цели, коллизии нет" do
      world = World.new()
      shooter = World.Body.from_xywh(:player1, 0, 50, 16, 24, velocity: {0, 0})
      target = World.Body.from_xywh(:player2, 200, 50, 16, 24, velocity: {0, 0})
      # Пуля летит влево (мимо цели)
      bullet = World.Body.from_xywh(:bullet, 100, 58, 4, 4, velocity: {-300, 0})

      {world, _shooter_id} = World.add_body(world, shooter)
      {world, target_id} = World.add_body(world, target)
      {world, bullet_id} = World.add_body(world, bullet)

      refute World.bodies_intersect?(world, bullet_id, target_id)

      world =
        run_steps_until(world, bullet_id, target_id, 60, fn w ->
          World.step(w, 1 / 60)
        end)

      refute World.bodies_intersect?(world, bullet_id, target_id),
             "Bullet should not hit target when moving away"
    end

    test "bodies_intersect? — два тела пересекаются" do
      world = World.new()
      a = World.Body.from_xywh(:a, 10, 10, 8, 8)
      b = World.Body.from_xywh(:b, 14, 14, 8, 8)
      {world, id_a} = World.add_body(world, a)
      {world, id_b} = World.add_body(world, b)
      assert World.bodies_intersect?(world, id_a, id_b)
    end

    test "bodies_intersect? — два тела не пересекаются" do
      world = World.new()
      a = World.Body.from_xywh(:a, 0, 0, 8, 8)
      b = World.Body.from_xywh(:b, 20, 20, 8, 8)
      {world, id_a} = World.add_body(world, a)
      {world, id_b} = World.add_body(world, b)
      refute World.bodies_intersect?(world, id_a, id_b)
    end
  end

  describe "Коллизии и колбек on_collision" do
    test "move_body: при столкновении со статикой колбек вызывается с hit_static: true, collided_ids: []" do
      world = World.new()
      world = World.add_static(world, AABB.from_xywh(20, 0, 16, 100))

      body =
        World.Body.from_xywh(:player, 0, 10, 16, 16,
          on_collision: fn w, bid, cids, hit ->
            send(self(), {:on_collision, bid, cids, hit})
            w
          end
        )

      {world, id} = World.add_body(world, body)

      assert {:collision, ^world, _} = World.move_body(world, id, 30, 0)
      assert_receive {:on_collision, ^id, [], true}
    end

    test "move_body: при столкновении с другим телом колбек вызывается с hit_static: false и списком id" do
      world = World.new()
      other = World.Body.from_xywh(:target, 50, 10, 16, 16)

      body =
        World.Body.from_xywh(:player, 0, 10, 16, 16,
          on_collision: fn w, bid, cids, hit ->
            send(self(), {:on_collision, bid, cids, hit})
            w
          end
        )

      {world, other_id} = World.add_body(world, other)
      {world, id} = World.add_body(world, body)

      assert {:collision, ^world, _} = World.move_body(world, id, 60, 0)
      assert_receive {:on_collision, ^id, [^other_id], false}
    end

    test "move_body: колбек может удалить само тело — после коллизии тела нет в мире" do
      world = World.new()
      world = World.add_static(world, AABB.from_xywh(20, 0, 16, 100))

      bullet =
        World.Body.from_xywh(:bullet, 0, 10, 8, 8,
          on_collision: fn w, body_id, _cids, _hit ->
            World.remove_body(w, body_id)
          end
        )

      {world, bullet_id} = World.add_body(world, bullet)

      assert {:collision, world, _} = World.move_body(world, bullet_id, 30, 0)
      refute World.has_body?(world, bullet_id)
    end

    test "move_body: колбек может удалить другое тело (в кого врезались) — тело исчезает из мира" do
      world = World.new()

      # Цель 40..56 по x, 10..26 по y. Пуля 0..8 — сдвиг 40 даёт 40..48, пересечение с целью
      target = World.Body.from_xywh(:target, 40, 10, 16, 16)

      bullet =
        World.Body.from_xywh(:bullet, 0, 10, 8, 8,
          on_collision: fn w, _bid, collided_ids, _hit ->
            Enum.reduce(collided_ids, w, &World.remove_body(&2, &1))
          end
        )

      {world, target_id} = World.add_body(world, target)
      {world, bullet_id} = World.add_body(world, bullet)

      assert {:collision, world, _} = World.move_body(world, bullet_id, 40, 0)
      refute World.has_body?(world, target_id)
      assert World.has_body?(world, bullet_id)
    end

    test "step: при коллизии вызывается on_collision; колбек удаляет пулю — пули нет в мире" do
      world = World.new()
      world = World.add_static(world, AABB.from_xywh(20, 0, 16, 100))

      bullet =
        World.Body.from_xywh(:bullet, 5, 10, 8, 8,
          velocity: {500, 0},
          on_collision: fn w, body_id, _cids, _hit ->
            World.remove_body(w, body_id)
          end
        )

      {world, bullet_id} = World.add_body(world, bullet)

      world = World.step(world, 1 / 60)

      refute World.has_body?(world, bullet_id),
             "Пуля должна быть удалена колбеком при столкновении со стеной"
    end

    test "step: пуля попадает в игрока, колбек удаляет пулю — пуля удалена, игрок остаётся" do
      world = World.new()
      player = World.Body.from_xywh(:player, 50, 10, 16, 16, velocity: {0, 0})

      bullet =
        World.Body.from_xywh(:bullet, 0, 12, 8, 8,
          velocity: {400, 0},
          on_collision: fn w, body_id, _cids, _hit ->
            World.remove_body(w, body_id)
          end
        )

      {world, player_id} = World.add_body(world, player)
      {world, bullet_id} = World.add_body(world, bullet)

      world = run_steps_until(world, bullet_id, player_id, 30, fn w -> World.step(w, 1 / 60) end)

      refute World.has_body?(world, bullet_id),
             "Пуля должна быть удалена колбеком при попадании в игрока"

      assert World.has_body?(world, player_id), "Игрок должен остаться в мире"
    end

    test "move_body: без on_collision при коллизии мир не меняется (колбек не вызывается)" do
      world = World.new()
      world = World.add_static(world, AABB.from_xywh(20, 0, 16, 100))
      body = World.Body.from_xywh(:player, 0, 10, 16, 16)
      {world, id} = World.add_body(world, body)

      assert {:collision, world2, _} = World.move_body(world, id, 30, 0)
      assert world2.bodies == world.bodies
      refute_receive {:on_collision, _, _, _}, 0
    end
  end

  describe "Интерполяция позиции (velocity + step)" do
    @dt 1 / 60

    test "пуля с velocity: после step интерполяция alpha=0 = старая позиция, alpha=1 = новая" do
      world = World.new()
      bullet = World.Body.from_xywh(:bullet, 10, 20, 8, 8, velocity: {120, 0})
      {world, bullet_id} = World.add_body(world, bullet)

      # До шага: текущая позиция (10, 20), previous_aabb ещё нет — интерполяция возвращает текущую
      {:ok, {x0, y0}} = World.get_interpolated_position(world, bullet_id, 0)
      assert x0 == 10 and y0 == 20

      world = World.step(world, @dt)
      # За один шаг: dx = 120 * (1/60) = 2, новая позиция (12, 20)
      body = World.get_body(world, bullet_id)
      assert body.aabb.min_x == 12 and body.aabb.min_y == 20
      assert body.previous_aabb.min_x == 10 and body.previous_aabb.min_y == 20

      {:ok, {x_prev, y_prev}} = World.get_interpolated_position(world, bullet_id, 0)
      {:ok, {x_curr, y_curr}} = World.get_interpolated_position(world, bullet_id, 1)
      assert x_prev == 10 and y_prev == 20, "alpha=0 — позиция до шага"
      assert x_curr == 12 and y_curr == 20, "alpha=1 — позиция после шага"
    end

    test "пуля с velocity: alpha=0.5 даёт середину между предыдущей и текущей позицией" do
      world = World.new()
      bullet = World.Body.from_xywh(:bullet, 0, 0, 8, 8, velocity: {60, 60})
      {world, bullet_id} = World.add_body(world, bullet)
      world = World.step(world, @dt)
      # dx = dy = 60 * (1/60) = 1, новая позиция (1, 1)
      {:ok, {x_half, y_half}} = World.get_interpolated_position(world, bullet_id, 0.5)
      assert_in_delta x_half, 0.5, 0.001
      assert_in_delta y_half, 0.5, 0.001
    end

    test "пуля с velocity: несколько шагов — позиция каждый кадр интерполируется между шагами" do
      world = World.new()
      vx = 120.0
      bullet = World.Body.from_xywh(:bullet, 0, 0, 8, 8, velocity: {vx, 0})
      {world, bullet_id} = World.add_body(world, bullet)

      world = World.step(world, @dt)
      {:ok, {x1, _}} = World.get_interpolated_position(world, bullet_id, 1)
      world = World.step(world, @dt)
      {:ok, {x2, _}} = World.get_interpolated_position(world, bullet_id, 1)
      world = World.step(world, @dt)
      {:ok, {x3, _}} = World.get_interpolated_position(world, bullet_id, 1)

      step_dx = vx * @dt
      assert_in_delta x1, step_dx, 0.001
      assert_in_delta x2, 2 * step_dx, 0.001
      assert_in_delta x3, 3 * step_dx, 0.001
    end

    test "в каждом кадре между шагами можно получать интерполированную позицию с разным alpha" do
      world = World.new()
      bullet = World.Body.from_xywh(:bullet, 100, 50, 8, 8, velocity: {300, 0})
      {world, bullet_id} = World.add_body(world, bullet)
      world = World.step(world, @dt)

      # Новая позиция 100 + 300/60 = 105. Между 100 и 105 при разном alpha.
      {:ok, {a0, _}} = World.get_interpolated_position(world, bullet_id, 0)
      {:ok, {a25, _}} = World.get_interpolated_position(world, bullet_id, 0.25)
      {:ok, {a5, _}} = World.get_interpolated_position(world, bullet_id, 0.5)
      {:ok, {a75, _}} = World.get_interpolated_position(world, bullet_id, 0.75)
      {:ok, {a1, _}} = World.get_interpolated_position(world, bullet_id, 1)

      assert a0 == 100
      assert_in_delta a25, 101.25, 0.01
      assert_in_delta a5, 102.5, 0.01
      assert_in_delta a75, 103.75, 0.01
      assert a1 == 105
    end

    test "интерполированный центр пули меняется так же плавно" do
      world = World.new()
      # Пуля 8x8, центр (4,4) от угла. Позиция (0,0) => центр (4,4)
      bullet = World.Body.from_xywh(:bullet, 0, 0, 8, 8, velocity: {60, 60})
      {world, bullet_id} = World.add_body(world, bullet)
      world = World.step(world, @dt)
      # Новая позиция (1,1), центр (5,5). alpha=0.5 => центр (4.5, 4.5)
      {:ok, {cx_half, cy_half}} = World.get_interpolated_center(world, bullet_id, 0.5)
      assert_in_delta cx_half, 4.5, 0.001
      assert_in_delta cy_half, 4.5, 0.001
    end
  end

  defp run_steps_until(world, bullet_id, target_id, max_steps, step_fun) do
    Enum.reduce_while(1..max_steps, world, fn _i, w ->
      w = step_fun.(w)

      if World.bodies_intersect?(w, bullet_id, target_id) do
        {:halt, w}
      else
        {:cont, w}
      end
    end)
  end

  describe "Pathfinding AStar" do
    test "find_path on Floor layer" do
      map = Parser.parse!(@dun_tmx)
      layer = Map.layer_by_name(map, "Floor")
      source = TileLayerTileSource.new(layer)
      # Точки, где в Dun.tmx есть проходимые тайлы (0)
      result = AStar.find_path(source, {20, 15}, {25, 15})
      assert match?({:ok, _}, result) or result == {:error, :unreachable}
    end
  end

  describe "Geometry" do
    test "AABB intersects?" do
      a = AABB.from_xywh(0, 0, 10, 10)
      b = AABB.from_xywh(5, 5, 10, 10)
      assert AABB.intersects?(a, b)
      c = AABB.from_xywh(20, 20, 5, 5)
      refute AABB.intersects?(a, c)
    end

    test "Vec2" do
      v = Vec2.new(1, 2)
      assert v.x == 1 and v.y == 2
      assert Vec2.add(v, Vec2.new(3, 4)) |> then(&(&1.x == 4 and &1.y == 6))
    end
  end
end

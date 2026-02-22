defmodule ExCollision.Pathfinding.AStar do
  @moduledoc """
  A* pathfinding over tilemap.
  Uses `ExCollision.Protocols.TileSource` for walkability.
  Coordinates are tile indices (column, row) or {x, y} in tiles.
  """
  alias ExCollision.Protocols.TileSource

  @doc """
  Finds path from start to goal over the tilemap.

  start, goal — {tile_x, tile_y} (tile indices).
  Returns {:ok, [ {x, y}, ... ]} or {:error, :unreachable}.

  Options:
  - `:allow_diagonal` — allow diagonal movement (8 directions). Default `false` (4 directions only).
  """
  @spec find_path(TileSource.t(), {integer(), integer()}, {integer(), integer()}, keyword()) ::
          {:ok, [{integer(), integer()}]} | {:error, :unreachable}
  def find_path(source, start, goal, opts \\ []) do
    width = TileSource.width(source)
    height = TileSource.height(source)
    start_idx = to_index(start, width)
    goal_idx = to_index(goal, width)
    allow_diagonal = Keyword.get(opts, :allow_diagonal, false)

    cond do
      out_of_bounds?(start, width, height) ->
        {:error, :unreachable}

      out_of_bounds?(goal, width, height) ->
        {:error, :unreachable}

      start == goal ->
        {:ok, [start]}

      not TileSource.walkable?(source, start_idx) ->
        {:error, :unreachable}

      not TileSource.walkable?(source, goal_idx) ->
        {:error, :unreachable}

      true ->
        do_astar(source, width, height, start_idx, goal_idx, allow_diagonal)
    end
  end

  defp to_index({x, y}, width), do: y * width + x

  defp from_index(idx, width) do
    {rem(idx, width), div(idx, width)}
  end

  defp out_of_bounds?({x, y}, width, height) do
    x < 0 or x >= width or y < 0 or y >= height
  end

  defp do_astar(source, width, height, start_idx, goal_idx, allow_diagonal) do
    # Open set: {f_score, idx}; closed set: map idx -> true
    # g_score: map idx -> cost
    g = %{start_idx => 0}
    h = heuristic(start_idx, goal_idx, width, allow_diagonal)
    open = :gb_sets.singleton({h, start_idx})
    came_from = %{}
    closed = %{}

    result =
      astar_loop(source, width, height, goal_idx, open, g, came_from, closed, allow_diagonal)

    case result do
      {:found, path_indices} ->
        path = Enum.map(path_indices, &from_index(&1, width))
        {:ok, path}

      :not_found ->
        {:error, :unreachable}
    end
  end

  defp heuristic(idx, goal_idx, width, allow_diagonal) do
    {x, y} = from_index(idx, width)
    {gx, gy} = from_index(goal_idx, width)

    if allow_diagonal do
      # Euclidean distance (admissible heuristic for 8 directions)
      :math.sqrt((x - gx) * (x - gx) + (y - gy) * (y - gy))
    else
      # Manhattan (for 4 directions)
      abs(x - gx) + abs(y - gy)
    end
  end

  @spec astar_loop(
          TileSource.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          :gb_sets.set(),
          %{optional(non_neg_integer()) => number()},
          %{optional(non_neg_integer()) => non_neg_integer()},
          %{optional(non_neg_integer()) => true},
          boolean()
        ) :: {:found, [non_neg_integer()]} | :not_found
  defp astar_loop(source, width, height, goal_idx, open, g, came_from, closed, allow_diagonal) do
    case :gb_sets.is_empty(open) do
      true ->
        :not_found

      false ->
        {{_f, current}, open} = :gb_sets.take_smallest(open)

        if current == goal_idx do
          path = reconstruct_path(came_from, current)
          {:found, path}
        else
          # Add current to closed set
          closed = Map.put(closed, current, true)
          g_current = Map.get(g, current, :infinity)
          neighbors = neighbors_with_cost(current, width, height, allow_diagonal)

          {open, g, came_from} =
            Enum.reduce(neighbors, {open, g, came_from}, fn {n_idx, cost},
                                                            {open_acc, g_acc, cf_acc} ->
              # Skip already visited nodes
              if Map.has_key?(closed, n_idx) do
                {open_acc, g_acc, cf_acc}
              else
                if not TileSource.walkable?(source, n_idx) do
                  {open_acc, g_acc, cf_acc}
                else
                  tentative_g = g_current + cost
                  prev_g = Map.get(g_acc, n_idx, :infinity)

                  if tentative_g < prev_g do
                    g_acc = Map.put(g_acc, n_idx, tentative_g)
                    f = tentative_g + heuristic(n_idx, goal_idx, width, allow_diagonal)
                    open_acc = :gb_sets.add({f, n_idx}, open_acc)
                    cf_acc = Map.put(cf_acc, n_idx, current)
                    {open_acc, g_acc, cf_acc}
                  else
                    {open_acc, g_acc, cf_acc}
                  end
                end
              end
            end)

          astar_loop(source, width, height, goal_idx, open, g, came_from, closed, allow_diagonal)
        end
    end
  end

  # Neighbors: 4 directions only (up, down, left, right), cost 1
  defp neighbors_with_cost(idx, width, height, false) do
    {x, y} = from_index(idx, width)

    [{x - 1, y}, {x + 1, y}, {x, y - 1}, {x, y + 1}]
    |> Enum.reject(fn {nx, ny} -> nx < 0 or nx >= width or ny < 0 or ny >= height end)
    |> Enum.map(fn {nx, ny} -> {ny * width + nx, 1} end)
  end

  # Neighbors: 8 directions (including diagonals), diagonal cost sqrt(2)
  defp neighbors_with_cost(idx, width, height, true) do
    {x, y} = from_index(idx, width)
    diagonal_cost = :math.sqrt(2)

    [
      {x - 1, y, 1},
      {x + 1, y, 1},
      {x, y - 1, 1},
      {x, y + 1, 1},
      {x - 1, y - 1, diagonal_cost},
      {x + 1, y - 1, diagonal_cost},
      {x - 1, y + 1, diagonal_cost},
      {x + 1, y + 1, diagonal_cost}
    ]
    |> Enum.reject(fn {nx, ny, _c} -> nx < 0 or nx >= width or ny < 0 or ny >= height end)
    |> Enum.map(fn {nx, ny, c} -> {ny * width + nx, c} end)
  end

  defp reconstruct_path(came_from, current) do
    do_reconstruct(came_from, current, [current])
  end

  defp do_reconstruct(came_from, current, acc) do
    case Map.get(came_from, current) do
      nil -> Enum.reverse(acc)
      prev -> do_reconstruct(came_from, prev, [prev | acc])
    end
  end

  @doc """
  Checks whether a point on the tilemap is walkable.
  """
  def walkable_at?(source, {x, y}) do
    width = TileSource.width(source)
    height = TileSource.height(source)

    if out_of_bounds?({x, y}, width, height) do
      false
    else
      idx = to_index({x, y}, width)
      TileSource.walkable?(source, idx)
    end
  end
end

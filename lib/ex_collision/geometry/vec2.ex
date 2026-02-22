defmodule ExCollision.Geometry.Vec2 do
  @moduledoc """
  Two-dimensional vector. Implements `Inspect` and `String.Chars` protocols.
  """
  defstruct [:x, :y]

  @type t :: %__MODULE__{x: number(), y: number()}

  def new(x, y) when is_number(x) and is_number(y) do
    %__MODULE__{x: x, y: y}
  end

  def add(%__MODULE__{x: ax, y: ay}, %__MODULE__{x: bx, y: by}) do
    %__MODULE__{x: ax + bx, y: ay + by}
  end

  def sub(%__MODULE__{x: ax, y: ay}, %__MODULE__{x: bx, y: by}) do
    %__MODULE__{x: ax - bx, y: ay - by}
  end

  def scale(%__MODULE__{x: x, y: y}, k) do
    %__MODULE__{x: x * k, y: y * k}
  end

  def floor_vec(%__MODULE__{x: x, y: y}) do
    %__MODULE__{x: Kernel.floor(x), y: Kernel.floor(y)}
  end

  def round_vec(%__MODULE__{x: x, y: y}) do
    %__MODULE__{x: round(x), y: round(y)}
  end
end

defimpl Inspect, for: ExCollision.Geometry.Vec2 do
  def inspect(%{x: x, y: y}, _opts) do
    "Vec2(#{x}, #{y})"
  end
end

defimpl String.Chars, for: ExCollision.Geometry.Vec2 do
  def to_string(%{x: x, y: y}) do
    "Vec2(#{x}, #{y})"
  end
end

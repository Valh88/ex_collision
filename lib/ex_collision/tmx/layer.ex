defmodule ExCollision.TMX.Layer do
  @moduledoc """
  Base TMX layer type (tile layer or object group).
  Implements `ExCollision.Protocols.TMXLayer` for uniform access.
  """
  @type t :: ExCollision.TMX.TileLayer.t() | ExCollision.TMX.ObjectGroup.t()
end

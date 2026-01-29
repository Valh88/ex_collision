defmodule ExCollision.TMX.Layer do
  @moduledoc """
  Базовый тип слоя TMX (tile layer или object group).
  Реализует протокол `ExCollision.Protocols.TMXLayer` для единообразного доступа.
  """
  @type t :: ExCollision.TMX.TileLayer.t() | ExCollision.TMX.ObjectGroup.t()
end

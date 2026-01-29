defprotocol ExCollision.Protocols.Collidable do
  @moduledoc """
  Протокол для объектов, участвующих в проверке коллизий.
  Требует возвращать AABB для пересечения.
  """
  @doc "Возвращает AABB данного объекта"
  def aabb(collidable)
end

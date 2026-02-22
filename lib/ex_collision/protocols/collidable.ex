defprotocol ExCollision.Protocols.Collidable do
  @moduledoc """
  Protocol for objects participating in collision checks.
  Requires returning AABB for intersection.
  """
  @doc "Returns the AABB of this object"
  def aabb(collidable)
end

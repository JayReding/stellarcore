class_name GalaxyScale
extends RefCounted
## Conversion between simulated light years and stellar-view world units.
##
## The play area is a disc 100 light years across. It is rendered with a
## 55-unit radius, giving a fixed world-units-per-light-year scale.

const DIAMETER_LY := 100.0
const RADIUS_LY := DIAMETER_LY * 0.5
const WORLD_RADIUS := 55.0
const WORLD_UNITS_PER_LY := WORLD_RADIUS / RADIUS_LY
const LY_PER_WORLD_UNIT := RADIUS_LY / WORLD_RADIUS


static func to_world(ly_position: Vector3) -> Vector3:
	return ly_position * WORLD_UNITS_PER_LY


static func to_ly(world_position: Vector3) -> Vector3:
	return world_position * LY_PER_WORLD_UNIT

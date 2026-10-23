class_name FleetData
extends Resource
## Persistent data for a fleet.
##
## Fleets store display names for their ships until a formal ship model exists.
## They also own their position and any active travel route so the turn system can
## advance them independently of the selected system panel.

const FTL_PROBE_SPEED_LY_PER_TURN := 10.0
const SHIP_SPEEDS_LY_PER_TURN := {
	"FTL Probe": FTL_PROBE_SPEED_LY_PER_TURN,
}

const GREEK_LETTERS: Array[String] = [
	"Alpha",
	"Beta",
	"Gamma",
	"Delta",
	"Epsilon",
	"Zeta",
	"Eta",
	"Theta",
	"Iota",
	"Kappa",
	"Lambda",
	"Mu",
	"Nu",
	"Xi",
	"Omicron",
	"Pi",
	"Rho",
	"Sigma",
	"Tau",
	"Upsilon",
	"Phi",
	"Chi",
	"Psi",
	"Omega",
]

@export var name: String = ""
## The system where the fleet was formed / is currently stationed.
@export var system_name: String = ""
@export var system_id: String = ""
@export var ships: Array[String] = []

## Galaxy-space position in light years.
@export var position_ly: Vector3 = Vector3.ZERO

@export var in_transit: bool = false
@export var destination_id: String = ""
@export var destination_name: String = ""
@export var route_origin_ly: Vector3 = Vector3.ZERO
@export var route_destination_ly: Vector3 = Vector3.ZERO
@export var route_distance_ly: float = 0.0
@export var route_travelled_ly: float = 0.0
@export var route_speed_ly_per_turn: float = 0.0
@export var route_turns_total: int = 0
@export var route_turns_elapsed: int = 0


func ship_count() -> int:
	return ships.size()


func add_ship(ship_name: String) -> void:
	ships.append(ship_name)


## Removes one matching ship. Returns false when the fleet has none of that type.
func remove_one_ship(ship_name: String) -> bool:
	var index := ships.find(ship_name)
	if index < 0:
		return false
	ships.remove_at(index)
	return true


## The fleet moves at the speed of its slowest ship.
func speed_ly_per_turn() -> float:
	if ships.is_empty():
		return 0.0

	var slowest := INF
	for ship_name in ships:
		var speed := float(
			SHIP_SPEEDS_LY_PER_TURN.get(ship_name, FTL_PROBE_SPEED_LY_PER_TURN)
		)
		slowest = minf(slowest, speed)
	return slowest


func turns_to_position(target_ly: Vector3) -> int:
	var speed := speed_ly_per_turn()
	if speed <= 0.0:
		return -1
	var distance := position_ly.distance_to(target_ly)
	return ceili(distance / speed)


func dock_at(star: StarData) -> void:
	if star == null:
		return
	system_id = star.id
	system_name = star.display_name
	position_ly = star.position_ly
	in_transit = false
	clear_route()


func begin_travel(destination: StarData) -> void:
	if destination == null:
		return

	route_origin_ly = position_ly
	route_destination_ly = destination.position_ly
	destination_id = destination.id
	destination_name = destination.display_name
	route_distance_ly = route_origin_ly.distance_to(route_destination_ly)
	route_travelled_ly = 0.0
	route_speed_ly_per_turn = speed_ly_per_turn()
	route_turns_elapsed = 0
	route_turns_total = 0
	if route_speed_ly_per_turn > 0.0 and route_distance_ly > 0.0:
		route_turns_total = ceili(route_distance_ly / route_speed_ly_per_turn)
	in_transit = route_turns_total > 0
	position_ly = route_origin_ly


## Advances one turn along the current course. Returns true on the arrival turn.
func advance_travel_turn() -> bool:
	if not in_transit:
		return false

	route_turns_elapsed += 1
	route_travelled_ly = minf(
		route_distance_ly,
		route_travelled_ly + route_speed_ly_per_turn
	)
	if (
		route_turns_elapsed >= route_turns_total
		or route_travelled_ly >= route_distance_ly - 0.0001
	):
		route_turns_elapsed = route_turns_total
		route_travelled_ly = route_distance_ly
		position_ly = route_destination_ly
		in_transit = false
		return true

	var progress := route_travelled_ly / route_distance_ly
	position_ly = route_origin_ly.lerp(route_destination_ly, progress)
	return false


func turns_remaining() -> int:
	if not in_transit:
		return 0
	return maxi(route_turns_total - route_turns_elapsed, 0)


func location_label() -> String:
	if in_transit:
		return "In transit to %s" % destination_name
	return system_name


func clear_route() -> void:
	destination_id = ""
	destination_name = ""
	route_origin_ly = Vector3.ZERO
	route_destination_ly = Vector3.ZERO
	route_distance_ly = 0.0
	route_travelled_ly = 0.0
	route_speed_ly_per_turn = 0.0
	route_turns_total = 0
	route_turns_elapsed = 0


func ship_summary() -> String:
	if ships.is_empty():
		return "No ships"

	var counts: Dictionary = {}
	var order: Array[String] = []
	for ship_name in ships:
		if not counts.has(ship_name):
			order.append(ship_name)
		counts[ship_name] = int(counts.get(ship_name, 0)) + 1

	var parts: Array[String] = []
	for ship_name in order:
		var count := int(counts[ship_name])
		var suffix := "" if count == 1 else "s"
		parts.append("%d %s%s" % [count, ship_name, suffix])
	return ", ".join(parts)


static func default_name(system_name: String, ordinal: int) -> String:
	var index := maxi(ordinal, 0)
	var letter_index := index % GREEK_LETTERS.size()
	var cycle := floori(float(index) / float(GREEK_LETTERS.size()))
	var name := "%s %s" % [system_name, GREEK_LETTERS[letter_index]]
	if cycle > 0:
		name += " %d" % (cycle + 1)
	return name

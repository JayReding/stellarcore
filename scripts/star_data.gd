class_name StarData
extends Resource
## Persistent data for a single star system.
##
## This resource deliberately knows nothing about the view. The stellar view
## renders it, but turn-based systems (structures, fleets, ownership) can extend
## and serialize the same object.

enum SpectralClass { O, B, A, F, G, K }

const CLASS_LETTERS: Array[String] = ["O", "B", "A", "F", "G", "K"]
const CLASS_NAMES: Array[String] = [
	"Blue", "Blue-white", "White", "Yellow-white", "Yellow", "Orange",
]
const CLASS_SIZE_FACTORS: Array[float] = [1.50, 1.32, 1.16, 1.03, 0.92, 0.80]

@export var id: String = ""
@export var display_name: String = ""
@export var is_home: bool = false
@export var spectral_class: SpectralClass = SpectralClass.G
@export_range(0, 9) var spectral_subclass: int = 2
## Position within the galaxy, measured in light years from the play-area center.
@export var position_ly: Vector3 = Vector3.ZERO
@export var temperature_k: float = 5778.0
## Presentation-only radius, in stellar-view world units.
@export var visual_radius: float = 1.5
@export var pick_radius: float = 3.2
## Whether the player has surveyed this system and can see its planets.
@export var surveyed: bool = false
## Planets ordered from the star outward.
@export var planets: Array[PlanetData] = []
## Fleets stationed in this system.
@export var fleets: Array[FleetData] = []
## Player-owned resources stockpiled in this system.
@export var resources: ResourceStockpile = ResourceStockpile.new()
## Planet that hosts this system's shipyard, if any.
@export var shipyard_planet: PlanetData = null
## Ships waiting to be built, in order. Each entry maps a hull id to its
## accumulated turns of work. One turn of work is applied per turn.
@export var ship_queue: Array[Dictionary] = []
## The single structure currently under construction in this system. Only one
## construction project runs per star system at a time.
@export var construction_type_id: String = ""
@export var construction_planet: PlanetData = null
@export var construction_turns_remaining: int = 0
@export var construction_turns_total: int = 0


func has_shipyard() -> bool:
	if (
		shipyard_planet == null
		or not shipyard_planet.has_structure(StructureData.SHIPYARD)
	):
		refresh_shipyard_planet()
	return shipyard_planet != null


func refresh_shipyard_planet() -> void:
	shipyard_planet = null
	for planet in planets:
		if planet != null and planet.has_structure(StructureData.SHIPYARD):
			shipyard_planet = planet
			return


## Fleets currently stationed in the system. In-transit fleets belong to no
## system's shipyard while they travel.
func stationed_fleets() -> Array[FleetData]:
	var result: Array[FleetData] = []
	for fleet in fleets:
		if fleet != null and not fleet.in_transit:
			result.append(fleet)
	return result


## Stationed fleets with no destination set or staged. Shipyard output only
## joins these, so ordered and travelling fleets keep the ships they have.
func available_fleets() -> Array[FleetData]:
	var result: Array[FleetData] = []
	for fleet in stationed_fleets():
		if fleet.destination_id.is_empty() and not fleet.has_orders():
			result.append(fleet)
	return result


## The fleet completed ships join: the newest available fleet, or null when
## the yard must create one.
func newest_available_fleet() -> FleetData:
	var available := available_fleets()
	if available.is_empty():
		return null
	return available[available.size() - 1]


func all_structures() -> Array[StructureData]:
	var result: Array[StructureData] = []
	for planet in planets:
		if planet != null:
			result.append_array(planet.structures)
	return result


func has_structure(type_id: String) -> bool:
	for planet in planets:
		if planet != null and planet.has_structure(type_id):
			return true
	return false


func has_colony() -> bool:
	return has_structure(StructureData.COLONY)


## Colonies unlock construction in their star system.
func can_build_structures() -> bool:
	return has_colony()


## Whether a structure is currently under construction in this system.
func is_constructing() -> bool:
	return not construction_type_id.is_empty()


## Queues a structure for construction on a planet. The caller spends the
## construction cost up front.
func start_construction(type_id: String, planet: PlanetData, turns: int) -> void:
	construction_type_id = type_id
	construction_planet = planet
	construction_turns_total = maxi(turns, 1)
	construction_turns_remaining = construction_turns_total


## Advances construction by one turn. Returns the completed structure and its
## planet when the project finishes, or an empty Dictionary while it runs.
func advance_construction() -> Dictionary:
	if not is_constructing():
		return {}

	construction_turns_remaining = maxi(0, construction_turns_remaining - 1)
	if construction_turns_remaining > 0:
		return {}

	var completed := {
		"type_id": construction_type_id,
		"planet": construction_planet,
	}
	var planet := construction_planet
	if planet != null and not planet.has_structure(construction_type_id):
		planet.add_structure(construction_type_id)
	construction_type_id = ""
	construction_planet = null
	construction_turns_remaining = 0
	construction_turns_total = 0
	refresh_shipyard_planet()
	return completed


## Human-readable name of the structure under construction, if any.
func construction_display_name() -> String:
	if not is_constructing():
		return ""
	return str(
		StructureData.definition_for(construction_type_id).get("name", "Structure")
	)


## Planets that currently own at least one structure.
func structures_by_planet() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for planet in planets:
		if planet != null and not planet.structures.is_empty():
			result.append({
				"planet": planet,
				"structures": planet.structures,
			})
	return result


## Net local-resource production minus upkeep for the whole system.
func resource_flow() -> Dictionary:
	var flow: Dictionary = {}
	for planet in planets:
		if planet == null:
			continue
		var planet_flow := planet.local_resource_flow()
		for resource_id in planet_flow:
			flow[resource_id] = (
				int(flow.get(resource_id, 0)) + int(planet_flow[resource_id])
			)
	return flow


func research_flow() -> int:
	var total := 0
	for planet in planets:
		if planet != null:
			total += planet.research_per_turn()
	return total


static func class_letter_for(cls: int) -> String:
	return CLASS_LETTERS[clampi(cls, 0, CLASS_LETTERS.size() - 1)]


static func class_name_for(cls: int) -> String:
	return CLASS_NAMES[clampi(cls, 0, CLASS_NAMES.size() - 1)]


static func size_factor_for(cls: int) -> float:
	return CLASS_SIZE_FACTORS[clampi(cls, 0, CLASS_SIZE_FACTORS.size() - 1)]


static func color_for(cls: int) -> Color:
	match cls:
		SpectralClass.O:
			return Color(0.45, 0.62, 1.00)
		SpectralClass.B:
			return Color(0.62, 0.78, 1.00)
		SpectralClass.A:
			return Color(0.82, 0.90, 1.00)
		SpectralClass.F:
			return Color(1.00, 0.98, 0.92)
		SpectralClass.G:
			return Color(1.00, 0.88, 0.62)
		SpectralClass.K:
			return Color(1.00, 0.68, 0.38)
		_:
			return Color.WHITE


static func temperature_range_for(cls: int) -> Vector2:
	match cls:
		SpectralClass.O:
			return Vector2(30000.0, 45000.0)
		SpectralClass.B:
			return Vector2(12000.0, 28000.0)
		SpectralClass.A:
			return Vector2(8000.0, 11000.0)
		SpectralClass.F:
			return Vector2(6200.0, 7800.0)
		SpectralClass.G:
			return Vector2(5300.0, 6000.0)
		SpectralClass.K:
			return Vector2(3900.0, 5200.0)
		_:
			return Vector2(3900.0, 45000.0)


static func class_description_for(cls: int) -> String:
	match cls:
		SpectralClass.O:
			return "Extremely hot blue star. Rare, brilliant, and short-lived."
		SpectralClass.B:
			return "Hot blue-white star with a fierce ultraviolet output."
		SpectralClass.A:
			return "White star, brighter and hotter than the Sun."
		SpectralClass.F:
			return "Yellow-white star, warmer than the Sun and quietly luminous."
		SpectralClass.G:
			return "Yellow main-sequence star. Stable, familiar, Sun-like."
		SpectralClass.K:
			return "Orange dwarf, cooler than the Sun and extremely long-lived."
		_:
			return "Unclassified stellar object."


func class_letter() -> String:
	return class_letter_for(spectral_class)


func classification() -> String:
	return "%s%dV" % [class_letter(), spectral_subclass]


func class_name_label() -> String:
	return "%s-class star" % class_name_for(spectral_class)


func class_color() -> Color:
	return color_for(spectral_class)


func class_description() -> String:
	return class_description_for(spectral_class)


func size_factor() -> float:
	return size_factor_for(spectral_class)


func temperature_display() -> String:
	return "%s K" % _group_digits(int(round(temperature_k)))


func distance_ly_to(other: StarData) -> float:
	if other == null:
		return -1.0
	return position_ly.distance_to(other.position_ly)


static func _group_digits(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped

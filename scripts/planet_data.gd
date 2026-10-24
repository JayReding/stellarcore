class_name PlanetData
extends Resource
## A planet orbiting a star, including the structures built on or around it.

enum PlanetClass { ROCKY, HIGH_MINERAL, EARTH_LIKE, DEAD_WORLD, GAS_GIANT, ICE_WORLD }

const CLASS_NAMES: Array[String] = [
	"Rocky", "High-Mineral", "Earth-like", "Dead World", "Gas Giant", "Ice World",
]

@export var designation: String = ""
@export_range(1, 99) var orbit_index: int = 1
@export var planet_class: PlanetClass = PlanetClass.ROCKY
## Average orbital distance in astronomical units. Used to order the system.
@export var orbit_au: float = 0.0
## Structures built on the surface or in orbit of this planet.
@export var structures: Array[StructureData] = []


static func class_name_for(cls: int) -> String:
	return CLASS_NAMES[clampi(cls, 0, CLASS_NAMES.size() - 1)]


static func class_color_for(cls: int) -> Color:
	match cls:
		PlanetClass.ROCKY:
			return Color(0.66, 0.58, 0.50)
		PlanetClass.HIGH_MINERAL:
			return Color(0.91, 0.62, 0.32)
		PlanetClass.EARTH_LIKE:
			return Color(0.35, 0.80, 0.62)
		PlanetClass.DEAD_WORLD:
			return Color(0.60, 0.65, 0.72)
		PlanetClass.GAS_GIANT:
			return Color(0.82, 0.70, 0.48)
		PlanetClass.ICE_WORLD:
			return Color(0.55, 0.80, 0.95)
		_:
			return Color.WHITE


static func roman_numeral(value: int) -> String:
	const VALUES: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	const SYMBOLS: Array[String] = [
		"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I",
	]

	var remaining := clampi(value, 1, 3999)
	var result := ""
	for i in VALUES.size():
		while remaining >= VALUES[i]:
			result += SYMBOLS[i]
			remaining -= VALUES[i]
	return result


func class_name_label() -> String:
	return class_name_for(planet_class)


func class_color() -> Color:
	return class_color_for(planet_class)


func add_structure(type_id: String) -> StructureData:
	var structure := StructureData.new()
	structure.type_id = type_id
	structures.append(structure)
	return structure


func has_structure(type_id: String) -> bool:
	for structure in structures:
		if structure != null and structure.type_id == type_id:
			return true
	return false


func structure_count() -> int:
	return structures.size()


## Net local-resource production minus upkeep. Research Data is separate because
## it is galaxy-wide.
func local_resource_flow() -> Dictionary:
	var flow: Dictionary = {}
	for structure in structures:
		if structure == null:
			continue
		var structure_flow := structure.net_resource_flow()
		for resource_id in structure_flow:
			flow[resource_id] = (
				int(flow.get(resource_id, 0)) + int(structure_flow[resource_id])
			)
	return flow


func research_per_turn() -> int:
	var total := 0
	for structure in structures:
		if structure != null:
			total += structure.research_per_turn()
	return total


## Individual contribution and upkeep lines, tagged with the structure that
## causes them. Used by the System View planet detail.
func flow_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for structure in structures:
		if structure == null:
			continue
		for entry in structure.flow_entries():
			entries.append({
				"resource_id": entry["resource_id"],
				"amount": entry["amount"],
				"kind": entry["kind"],
				"structure_name": structure.display_name(),
			})
	return entries

class_name StructureData
extends Resource
## A structure built on or in orbit of a planet.
##
## Structures are the source of system production and upkeep. Base figures live
## in DEFINITIONS; planetary richness can scale them once that mechanic exists.

enum Location { SURFACE, ORBIT }

const COLONY := "colony"
const SHIPYARD := "shipyard"
const ORE_PROCESSING := "ore_processing"
const HELIUM_3_STATION := "helium_3_station"
const ANTIMATTER_REFINERY := "antimatter_refinery"

const DEFINITIONS := {
	COLONY: {
		"name": "Colony",
		"location": Location.SURFACE,
		"role": "Permits construction",
		"color": Color(0.42, 0.88, 0.64),
		"description": (
			"A permanent settlement. Colonies permit construction in their "
			+ "star system and produce a small amount of resources."
		),
		"production": {
			ResourceStockpile.TITANIUM: 10,
			ResourceStockpile.HELIUM_3: 2,
		},
		"upkeep": {},
		"research_per_turn": 5,
	},
	SHIPYARD: {
		"name": "Shipyard",
		"location": Location.ORBIT,
		"role": "Builds ships",
		"color": Color(0.42, 0.72, 1.0),
		"description": (
			"An orbital construction yard. Shipyards allow the player to build "
			+ "ships in this system."
		),
		"production": {},
		"upkeep": {ResourceStockpile.HELIUM_3: 2},
		"research_per_turn": 0,
	},
	ORE_PROCESSING: {
		"name": "Ore Processing Station",
		"location": Location.ORBIT,
		"role": "Refines ore",
		"color": Color(0.91, 0.66, 0.38),
		"description": (
			"An orbital refinery that turns raw ore into usable Titanium."
		),
		"production": {ResourceStockpile.TITANIUM: 25},
		"upkeep": {ResourceStockpile.HELIUM_3: 2},
		"research_per_turn": 0,
		"cost": {ResourceStockpile.TITANIUM: 200},
		"build_time": 3,
	},
	HELIUM_3_STATION: {
		"name": "Helium3 Station",
		"location": Location.ORBIT,
		"role": "Harvests helium-3",
		"color": Color(0.45, 0.86, 0.96),
		"description": (
			"An orbital harvesting station that skims Helium3 from a gas giant."
			+ " Also produces a small amount of antimatter as a byproduct."
		),
		"production": {
			ResourceStockpile.HELIUM_3: 20,
			ResourceStockpile.ANTIMATTER: 1
		},
		"upkeep": {},
		"research_per_turn": 0,
		"cost": {ResourceStockpile.TITANIUM: 200},
		"build_time": 3,
	},
	ANTIMATTER_REFINERY: {
		"name": "Antimatter Refinery",
		"location": Location.ORBIT,
		"role": "Refines antimatter",
		"color": Color(0.8, 0.58, 1.0),
		"description": (
			"An orbital refinery that processes Helium3 into Antimatter for "
			+ "ship operations."
		),
		"production": {ResourceStockpile.ANTIMATTER: 5},
		"upkeep": {ResourceStockpile.HELIUM_3: 5},
		"research_per_turn": 0,
		"unlocked_by": "antimatter_refining",
		"cost": {ResourceStockpile.TITANIUM: 200},
		"build_time": 3,
	},
}

@export var type_id: String = COLONY


static func definition_for(type_id_value: String) -> Dictionary:
	return DEFINITIONS.get(type_id_value, {})


## Structure types the player can build without completing research.
static func base_structure_ids() -> Array[String]:
	var ids: Array[String] = []
	for type_id in DEFINITIONS:
		if str(DEFINITIONS[type_id].get("unlocked_by", "")).is_empty():
			ids.append(str(type_id))
	return ids


static func location_label_for(location: int) -> String:
	return "Orbit" if location == Location.ORBIT else "Surface"


func definition() -> Dictionary:
	return definition_for(type_id)


func display_name() -> String:
	return str(definition().get("name", "Unknown Structure"))


func location() -> int:
	return int(definition().get("location", Location.SURFACE))


func location_label() -> String:
	return location_label_for(location())


func role() -> String:
	return str(definition().get("role", ""))


func color() -> Color:
	return definition().get("color", Color.WHITE)


func description() -> String:
	return str(definition().get("description", ""))


func production_per_turn() -> Dictionary:
	return definition().get("production", {})


func upkeep_per_turn() -> Dictionary:
	return definition().get("upkeep", {})


func research_per_turn() -> int:
	return int(definition().get("research_per_turn", 0))


## Titanium (or other local resources) spent from the system stockpile when
## construction starts. Empty means the structure is free to build.
func construction_cost() -> Dictionary:
	return definition().get("cost", {})


## Turns construction takes. Zero means the structure completes immediately.
func build_time() -> int:
	return maxi(int(definition().get("build_time", 0)), 0)


func net_resource_flow() -> Dictionary:
	var flow: Dictionary = {}

	for resource_id in production_per_turn():
		flow[resource_id] = (
			int(flow.get(resource_id, 0)) + int(production_per_turn()[resource_id])
		)
	for resource_id in upkeep_per_turn():
		flow[resource_id] = (
			int(flow.get(resource_id, 0)) - int(upkeep_per_turn()[resource_id])
		)
	return flow


## Returns positive production and negative upkeep entries for display.
func flow_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for resource_id in production_per_turn():
		entries.append({
			"resource_id": str(resource_id),
			"amount": int(production_per_turn()[resource_id]),
			"kind": "output",
		})
	for resource_id in upkeep_per_turn():
		entries.append({
			"resource_id": str(resource_id),
			"amount": -int(upkeep_per_turn()[resource_id]),
			"kind": "input",
		})

	var research := research_per_turn()
	if research != 0:
		entries.append({
			"resource_id": ResourceStockpile.RESEARCH_DATA,
			"amount": research,
			"kind": "output",
		})
	return entries

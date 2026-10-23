class_name ResourceStockpile
extends Resource
## Resources stockpiled in a single star system.
##
## Titanium, Helium 3, Composites, Antimatter, and Meta-Matter are local to a
## system so cargo transport can move them between systems later. Research Data
## is galaxy-wide and lives on StellarView instead.
##
## Amounts are integer units. Hidden resources are tracked even when they are not
## shown in a system's resource list until they are revealed through progression.

const TITANIUM := "titanium"
const HELIUM_3 := "helium_3"
const COMPOSITES := "composites"
const ANTIMATTER := "antimatter"
const META_MATTER := "meta_matter"
const RESEARCH_DATA := "research_data"

const RESEARCH_DATA_NAME := "Research Data"
const RESEARCH_DATA_COLOR := Color(0.52, 0.92, 0.78)

const STARTING_TITANIUM := 200
const STARTING_HELIUM_3 := 200
const STARTING_ANTIMATTER := 50

const RESOURCE_DEFINITIONS := [
	{
		"id": TITANIUM,
		"name": "Titanium",
		"color": Color(0.72, 0.82, 0.94),
		"hidden_by_default": false,
		"description": (
			"Structural metal used to build ships and orbital structures."
		),
	},
	{
		"id": HELIUM_3,
		"name": "Helium 3",
		"color": Color(0.45, 0.86, 0.96),
		"hidden_by_default": false,
		"description": "Fuel used to power orbital structures.",
	},
	{
		"id": COMPOSITES,
		"name": "Composites",
		"color": Color(0.68, 0.86, 0.58),
		"hidden_by_default": true,
		"description": (
			"Advanced materials used by higher-tier ships and structures."
		),
	},
	{
		"id": ANTIMATTER,
		"name": "Antimatter",
		"color": Color(0.8, 0.58, 1.0),
		"hidden_by_default": false,
		"description": "Powers FTL drives for travel between stars.",
	},
	{
		"id": META_MATTER,
		"name": "Meta-Matter",
		"color": Color(1.0, 0.82, 0.45),
		"hidden_by_default": true,
		"description": "Exotic matter reserved for the highest technologies.",
	},
]

## Research Data is not stored in a system stockpile, but keeping its definition
## here gives the HUD and technology tree one catalog for names and colors.
const RESEARCH_DATA_DEFINITION := {
	"id": RESEARCH_DATA,
	"name": RESEARCH_DATA_NAME,
	"color": RESEARCH_DATA_COLOR,
	"hidden_by_default": false,
	"description": "Data used to advance the technology tree.",
}

@export var titanium: int = 0
@export var helium_3: int = 0
@export var composites: int = 0
@export var antimatter: int = 0
@export var meta_matter: int = 0


## Creates the stockpile Newhome begins the game with. Every other system starts
## empty.
static func starting_home() -> ResourceStockpile:
	var stockpile := ResourceStockpile.new()
	stockpile.titanium = STARTING_TITANIUM
	stockpile.helium_3 = STARTING_HELIUM_3
	stockpile.antimatter = STARTING_ANTIMATTER
	return stockpile


static func definition(resource_id: String) -> Dictionary:
	if resource_id == RESEARCH_DATA:
		return RESEARCH_DATA_DEFINITION
	for resource in RESOURCE_DEFINITIONS:
		if str(resource.get("id", "")) == resource_id:
			return resource
	return {}


static func display_name(resource_id: String) -> String:
	return str(definition(resource_id).get("name", resource_id))


static func is_hidden_by_default(resource_id: String) -> bool:
	return bool(definition(resource_id).get("hidden_by_default", false))


static func is_visible(
	resource_id: String, revealed_resources: Array[String] = []
) -> bool:
	var resource := definition(resource_id)
	if resource.is_empty():
		return false
	if not bool(resource.get("hidden_by_default", false)):
		return true
	return revealed_resources.has(resource_id)


func get_amount(resource_id: String) -> int:
	match resource_id:
		TITANIUM:
			return titanium
		HELIUM_3:
			return helium_3
		COMPOSITES:
			return composites
		ANTIMATTER:
			return antimatter
		META_MATTER:
			return meta_matter
		_:
			return 0


func set_amount(resource_id: String, amount: int) -> void:
	var value := maxi(amount, 0)
	match resource_id:
		TITANIUM:
			titanium = value
		HELIUM_3:
			helium_3 = value
		COMPOSITES:
			composites = value
		ANTIMATTER:
			antimatter = value
		META_MATTER:
			meta_matter = value


func add_amount(resource_id: String, amount: int) -> void:
	set_amount(resource_id, get_amount(resource_id) + amount)


func can_afford(cost: Dictionary) -> bool:
	for resource_id in cost:
		if get_amount(str(resource_id)) < int(cost[resource_id]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false

	for resource_id in cost:
		var id := str(resource_id)
		set_amount(id, get_amount(id) - int(cost[resource_id]))
	return true


## Moves resources to another system's stockpile. Cargo transport will use this
## once fleets can carry freight.
func transfer_to(target: ResourceStockpile, amounts: Dictionary) -> bool:
	if target == null or target == self:
		return false
	if not can_afford(amounts):
		return false

	for resource_id in amounts:
		if int(amounts[resource_id]) < 0:
			return false

	for resource_id in amounts:
		var id := str(resource_id)
		var amount := int(amounts[resource_id])
		set_amount(id, get_amount(id) - amount)
		target.add_amount(id, amount)
	return true


func visible_definitions(
	revealed_resources: Array[String] = []
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for resource in RESOURCE_DEFINITIONS:
		var resource_id := str(resource.get("id", ""))
		if is_visible(resource_id, revealed_resources):
			result.append(resource)
	return result

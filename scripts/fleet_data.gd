class_name FleetData
extends Resource
## Persistent data for a fleet. Fleets currently belong to one star system and
## store the display names of their ships until a formal ship model is added.

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
@export var system_name: String = ""
@export var ships: Array[String] = []


func ship_count() -> int:
	return ships.size()


func add_ship(ship_name: String) -> void:
	ships.append(ship_name)


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

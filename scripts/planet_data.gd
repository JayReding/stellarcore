class_name PlanetData
extends Resource
## A planet orbiting a star. Attributes and resources will be added later.

enum PlanetClass { ROCKY, HIGH_MINERAL, EARTH_LIKE, DEAD_WORLD, GAS_GIANT, ICE_WORLD }

const CLASS_NAMES: Array[String] = [
	"Rocky", "High-Mineral", "Earth-like", "Dead World", "Gas Giant", "Ice World",
]

@export var designation: String = ""
@export_range(1, 99) var orbit_index: int = 1
@export var planet_class: PlanetClass = PlanetClass.ROCKY
## Average orbital distance in astronomical units. Used to order the system.
@export var orbit_au: float = 0.0


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

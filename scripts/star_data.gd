class_name StarData
extends Resource
## Persistent data for a single star system.
##
## This resource deliberately knows nothing about the view. The stellar view
## renders it, but future turn-based systems (colonies, fleets, ownership)
## can extend and serialize the same object.

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
## Planet that hosts this system's shipyard, if any.
@export var shipyard_planet: PlanetData = null


func has_shipyard() -> bool:
	return shipyard_planet != null


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

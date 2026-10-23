class_name Galaxy
extends Resource
## The star systems in play and their precomputed travel distances.
##
## Distances are stored in light years. The matrix is derived data: it is
## rebuilt automatically if the resource is loaded without it.

@export var seed_value: int = 0
@export var stars: Array[StarData] = []

var _distance_matrix: Array[PackedFloat64Array] = []
var _index_by_id: Dictionary = {}


func rebuild_distances() -> void:
	_distance_matrix.clear()
	_index_by_id.clear()

	var count := stars.size()
	for i in count:
		_index_by_id[stars[i].id] = i

	_distance_matrix.resize(count)
	for i in count:
		var row := PackedFloat64Array()
		row.resize(count)
		for j in count:
			row[j] = 0.0 if i == j else stars[i].position_ly.distance_to(stars[j].position_ly)
		_distance_matrix[i] = row


func index_of(star: StarData) -> int:
	if star == null:
		return -1
	_ensure_distances()
	return int(_index_by_id.get(star.id, -1))


func distance_between(a: StarData, b: StarData) -> float:
	_ensure_distances()
	var index_a := index_of(a)
	var index_b := index_of(b)
	if index_a < 0 or index_b < 0:
		return -1.0
	return _distance_matrix[index_a][index_b]


func home_star() -> StarData:
	for star in stars:
		if star.is_home:
			return star
	return null


func all_fleets() -> Array[FleetData]:
	var result: Array[FleetData] = []
	for star in stars:
		for fleet in star.fleets:
			result.append(fleet)
	return result


## Returns the first unused Greek-letter name for a production system.
## Fleet names are galaxy-wide, so deleted fleets release their names even if
## they were stationed in another system when they were removed.
func next_fleet_name(system_name: String) -> String:
	var used: Dictionary = {}
	for fleet in all_fleets():
		used[fleet.name] = true

	var ordinal := 0
	while used.has(FleetData.default_name(system_name, ordinal)):
		ordinal += 1
	return FleetData.default_name(system_name, ordinal)


func stars_within_range(origin: StarData, range_ly: float) -> Array[StarData]:
	var result: Array[StarData] = []
	_ensure_distances()

	var origin_index := index_of(origin)
	if origin_index < 0:
		return result

	for i in stars.size():
		if i != origin_index and _distance_matrix[origin_index][i] <= range_ly:
			result.append(stars[i])
	return result


func _ensure_distances() -> void:
	if _distance_matrix.size() != stars.size() or _index_by_id.size() != stars.size():
		rebuild_distances()

extends RefCounted

# Coordinates are traced on the supplied 1671 × 941 illustration.
const ART_SIZE := Vector2(1671, 941)
const WORLD_SIZE := Vector2(1280, 720)
const SCALE := WORLD_SIZE / ART_SIZE
const PAVEMENT := [
	Vector2(64,722), Vector2(198,564), Vector2(279,447), Vector2(330,361),
	Vector2(351,302), Vector2(375,252), Vector2(582,275), Vector2(1174,285),
	Vector2(1250,317), Vector2(1540,366), Vector2(1670,375), Vector2(1670,394),
	Vector2(1551,393), Vector2(1468,402), Vector2(1345,399), Vector2(1301,420),
	Vector2(1375,658), Vector2(1412,678), Vector2(1451,802), Vector2(1265,804),
	Vector2(1232,843), Vector2(181,839), Vector2(91,821), Vector2(60,790),
]
const CROSSINGS := [
	Rect2(0, 729, 75, 29), Rect2(182, 443, 105, 25),
	Rect2(265, 299, 80, 22), Rect2(79, 819, 81, 54),
	Rect2(1264, 803, 204, 49), Rect2(1183, 847, 105, 74),
	Rect2(1586, 451, 85, 27),
]
const GARDENS := [
	[Vector2(276,442),Vector2(291,408),Vector2(321,379),Vector2(447,374),Vector2(460,392),Vector2(441,422),Vector2(392,444),Vector2(322,453)],
	[Vector2(100,741),Vector2(121,693),Vector2(155,670),Vector2(306,664),Vector2(352,691),Vector2(380,731),Vector2(374,768),Vector2(344,793),Vector2(165,795),Vector2(115,781)],
]
const TREE_FEET := [
	Vector2(360,428),Vector2(407,400),Vector2(451,377),Vector2(589,389),Vector2(715,394),
	Vector2(989,398),Vector2(1104,399),Vector2(1171,435),Vector2(1186,504),Vector2(1197,576),Vector2(1206,663),
	Vector2(201,747),Vector2(316,768),Vector2(487,787),Vector2(675,803),Vector2(848,805),Vector2(1014,812),Vector2(1141,804),
]
# Each crop follows the visible foliage and trunk, with the same UVs as the background.
const TREES := [
	[358,428,313,326,418,398], [406,400,352,303,463,371], [451,377,404,278,500,353],
	[589,389,529,299,635,365], [715,394,663,302,760,371], [989,398,933,313,1030,372],
	[1104,399,1050,307,1155,370], [1171,435,1137,346,1201,421], [1186,504,1143,413,1216,482],
	[1197,576,1157,487,1230,558], [1206,663,1161,552,1240,637], [201,747,114,595,294,700],
	[316,768,251,618,393,703], [487,787,411,646,550,736], [675,803,571,621,769,739],
	[848,805,782,637,906,753], [1014,812,910,625,1081,750], [1141,804,1047,614,1230,745],
]
const KIOSKS := [
	Rect2(182,512,61,49), Rect2(525,363,53,44), Rect2(1037,368,58,44),
	Rect2(202,749,69,53), Rect2(416,755,68,58), Rect2(713,761,64,56),
	Rect2(920,762,67,56), Rect2(1157,756,64,56),
]
const LAMPS := [
	Vector2(230,496),Vector2(497,400),Vector2(646,399),Vector2(912,402),
	Vector2(91,803),Vector2(383,791),Vector2(561,791),Vector2(883,833),Vector2(1232,801),
	Vector2(536,301),Vector2(786,311),Vector2(971,290),Vector2(1154,320),Vector2(1307,415),
]

static var pavement_polygon := PackedVector2Array(PAVEMENT)
static var garden_polygons := make_garden_polygons()
static var scenery := make_scenery()

static func make_garden_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for points in GARDENS:
		polygons.append(PackedVector2Array(points))
	return polygons

static func walkable(world_point: Vector2) -> bool:
	var point := world_point / SCALE
	var on_paving := Geometry2D.is_point_in_polygon(point, pavement_polygon)
	if not on_paving:
		for crossing in CROSSINGS:
			if crossing.has_point(point):
				on_paving = true
				break
	if not on_paving:
		return false
	for garden in garden_polygons:
		if Geometry2D.is_point_in_polygon(point, garden):
			return false
	for foot in TREE_FEET:
		if ((point - foot) / Vector2(14, 9)).length_squared() < 1.0:
			return false
	for kiosk in KIOSKS:
		if Rect2(kiosk.position.x, kiosk.end.y - 22, kiosk.size.x, 24).grow(2).has_point(point):
			return false
	for foot in LAMPS:
		if point.distance_squared_to(foot) < 37.0:
			return false
	return true

static func make_scenery() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for tree in TREES:
		var x: float = tree[0]
		var y: float = tree[1]
		var l: float = tree[2]
		var t: float = tree[3]
		var r: float = tree[4]
		var b: float = tree[5]
		var w := r - l
		var h := b - t
		items.append({
			"pos": Vector2(x, y) * SCALE,
			"cutout": [Vector2(l,t+h*.44), Vector2(l+w*.18,t+h*.12),Vector2(l+w*.53,t),Vector2(r-w*.13,t+h*.18),Vector2(r,t+h*.56),Vector2(r-w*.12,b-h*.1),Vector2(x+6,b),Vector2(x+5,y),Vector2(x-5,y),Vector2(x-7,b),Vector2(l+w*.16,b-h*.08)],
		})
	for kiosk in KIOSKS:
		items.append({"pos":Vector2(kiosk.get_center().x,kiosk.end.y)*SCALE,
			"cutout":[kiosk.position, Vector2(kiosk.end.x,kiosk.position.y), kiosk.end, Vector2(kiosk.position.x,kiosk.end.y)]})
	for foot in LAMPS:
		items.append({"pos":foot*SCALE, "cutout":[
			foot+Vector2(-10,-70),foot+Vector2(9,-70),foot+Vector2(10,-51),
			foot+Vector2(3,-44),foot+Vector2(4,0),foot+Vector2(-4,0),
			foot+Vector2(-3,-44),foot+Vector2(-10,-51)]})
	return items

static func draw_cutout(canvas: Control, texture: Texture2D, cutout: Array) -> void:
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in cutout:
		polygon.append(point * SCALE)
		uv.append(point / ART_SIZE)
	canvas.draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, texture)

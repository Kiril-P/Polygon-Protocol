class_name BossArena
extends Node2D
## The fenced arena of a boss fight: a glowing border and a solid barrier. The spawner
## creates it before the first boss of a fight; every boss in that fight shares it, and it
## removes itself (border and barrier together) once no boss is left.
##
## kind "ring":  a circle (Fortress, Pulsar, Singularity).
## kind "prism": a hexagon whose six walls can overload: a wall flashes amber (warning), then
##               turns live and hurts anything close to it. Used by the Prism boss.

const RING_RADIUS := 1450.0
const PRISM_RADIUS := 1560.0 # Corner distance; the flat walls sit at radius * cos(30deg)
const WALL_DANGER := 70.0 # Distance from a live wall that hurts the player
const GRACE := 1.5 # Seconds before the "no boss left" check starts

var kind: String = "ring"
var radius: float = RING_RADIUS
var color: Color = Color(1.0, 0.2, 0.4)

var _walls: Array = [] # prism only: {a, b, line, state: "off"|"warn"|"live"}
var _body: StaticBody2D
var _border: Line2D
var _grace := GRACE
var _closing := false

## Returns the arena of the running fight, creating it at `center` when there is none.
static func ensure(parent: Node, center: Vector2, arena_kind: String, arena_color: Color) -> BossArena:
	var existing := parent.get_tree().get_first_node_in_group("boss_arena_node")
	if existing is BossArena and not existing._closing:
		return existing
	var a := BossArena.new()
	a.kind = arena_kind
	a.color = arena_color
	a.radius = PRISM_RADIUS if arena_kind == "prism" else RING_RADIUS
	parent.add_child(a)
	a.global_position = center
	return a

func _ready():
	add_to_group("boss_arena_node")
	_build()
	var t := create_tween().set_loops().bind_node(_border)
	t.tween_property(_border, "default_color:a", 1.0, 0.5)
	t.tween_property(_border, "default_color:a", 0.4, 0.5)

# ------------------------------------------------------------------ geometry
## Inscribed radius: the distance from the centre to the nearest wall.
func inner_radius() -> float:
	return radius * cos(PI / 6.0) if kind == "prism" else radius

func corners() -> PackedVector2Array:
	var n := 6 if kind == "prism" else 64
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2(radius, 0).rotated(TAU * i / n))
	return pts

func wall_count() -> int:
	return _walls.size()

## Outward unit normal and midpoint (local) of wall `i`.
func wall_mid(i: int) -> Vector2:
	return (_walls[i]["a"] + _walls[i]["b"]) * 0.5

func wall_normal(i: int) -> Vector2:
	return wall_mid(i).normalized()

func wall_state(i: int) -> String:
	return _walls[i]["state"]

## Random point inside the arena at least `min_player_dist` from `away_from` (when given),
## `edge_margin` inside the wall and no closer than `inner_frac` of the radius to the centre.
func random_point(away_from: Vector2 = Vector2.INF, min_player_dist: float = 0.0, edge_margin: float = 150.0, inner_frac: float = 0.0) -> Vector2:
	var pos := global_position
	for attempt in 12:
		var d := randf_range(inner_frac * inner_radius(), inner_radius() - edge_margin)
		pos = global_position + Vector2(d, 0).rotated(randf() * TAU)
		if away_from == Vector2.INF or pos.distance_to(away_from) > min_player_dist:
			break
	return pos

func contains(world_pos: Vector2) -> bool:
	return (world_pos - global_position).length() <= inner_radius()

# ------------------------------------------------------------------ build
func _build():
	var pts := corners()
	var loop := pts.duplicate()
	loop.append(pts[0])
	_border = Line2D.new()
	_border.name = "ArenaBorder"
	_border.points = loop
	_border.width = 14.0
	_border.default_color = Color(color.r, color.g, color.b, 0.75)
	_border.material = Neon.additive_material()
	var rim := Line2D.new()
	rim.points = loop
	rim.width = 3.0
	rim.default_color = color.lerp(Color.WHITE, 0.7)
	rim.material = Neon.additive_material()
	_border.add_child(rim)
	add_child(_border)

	_body = StaticBody2D.new()
	_body.name = "Barrier"
	_body.collision_layer = 1
	add_child(_body)
	var segs := 6 if kind == "prism" else 16
	for i in segs:
		var p1 := Vector2(radius, 0).rotated(TAU * i / segs)
		var p2 := Vector2(radius, 0).rotated(TAU * (i + 1) / segs)
		var coll := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = p1
		seg.b = p2
		coll.shape = seg
		_body.add_child(coll)
		if kind == "prism":
			var line := Line2D.new()
			line.points = PackedVector2Array([p1, p2])
			line.width = 6.0
			line.default_color = Color(1, 0.8, 0.2, 0.0)
			line.material = Neon.additive_material()
			line.z_index = 2
			add_child(line)
			_walls.append({"a": p1, "b": p2, "line": line, "state": "off"})

# ------------------------------------------------------------------ prism walls
## Overloads walls: flash for `warn` seconds, then hurt for `live` seconds.
func overload_walls(indices: Array, warn: float = 1.4, live: float = 2.5):
	for idx in indices:
		var i: int = posmod(int(idx), maxi(_walls.size(), 1))
		if _walls.is_empty() or _walls[i]["state"] != "off":
			continue
		_walls[i]["state"] = "warn"
		var line: Line2D = _walls[i]["line"]
		line.width = 10.0
		var flash := create_tween().set_loops(maxi(int(warn / 0.2), 1)).bind_node(line)
		flash.tween_property(line, "default_color", Color(1.0, 0.75, 0.15, 0.85), 0.1)
		flash.tween_property(line, "default_color", Color(1.0, 0.75, 0.15, 0.2), 0.1)
		var seq := create_tween().bind_node(self)
		seq.tween_interval(warn)
		seq.tween_callback(func():
			flash.kill()
			_walls[i]["state"] = "live"
			line.width = 26.0
			line.default_color = Color(1.0, 0.25, 0.2, 1.0)
			line.modulate = Color(2.2, 1.6, 1.4)
			AudioManager.play_sfx("glitch", -4.0, 0.9, 1.1))
		seq.tween_interval(live)
		seq.tween_callback(func():
			_walls[i]["state"] = "off"
			line.modulate = Color.WHITE
			line.default_color = Color(1, 0.8, 0.2, 0.0))

func _physics_process(_delta: float):
	if _closing:
		return
	_grace -= _delta
	if _grace <= 0.0 and get_tree().get_nodes_in_group("bosses").is_empty():
		close()
		return
	if _walls.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for w in _walls:
		if w["state"] != "live":
			continue
		var a: Vector2 = global_position + w["a"]
		var b: Vector2 = global_position + w["b"]
		var closest := Geometry2D.get_closest_point_to_segment(player.global_position, a, b)
		if closest.distance_to(player.global_position) < WALL_DANGER and player.has_method("take_damage"):
			player.take_damage(1, "ARENA WALL", "contact")

## Fades the border out and removes the barrier immediately.
func close():
	if _closing:
		return
	_closing = true
	remove_from_group("boss_arena_node")
	if is_instance_valid(_body):
		_body.collision_layer = 0
		_body.queue_free()
	for w in _walls:
		w["state"] = "off"
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)

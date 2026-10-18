class_name EnemyBase
extends CharacterBody2D
## Shared behaviour for every regular enemy: player lookup, damage/flash,
## death rewards, death particles and enemy bullet spawning.
## Subclasses set their stats in _init() (so scene overrides still win),
## call super() from _ready(), and override setup_visuals()/_physics_process().

@export var speed: float = 200.0
@export var health: float = 20.0
@export var damage: float = 10.0
@export var xp_value: int = 10
@export var bullet_scene: PackedScene

var player: Node2D = null
var is_dying: bool = false

# Death particle tuning (override in _init)
var death_particle_amount: int = 20
var death_particle_velocity: Vector2 = Vector2(100.0, 250.0) # min, max
var death_particle_size: Vector2 = Vector2(3.0, 5.0) # min, max
var death_particle_lifetime: float = 1.0
var death_particle_color: Color = Color(0, 0, 0, 0) # alpha 0 = use Polygon2D color
var death_shake: float = 0.0
var play_hit_sfx: bool = true

var neon_color: Color = Color.WHITE
var neon_outline: Line2D = null

func _ready():
	add_to_group("enemies")
	_apply_neon.call_deferred() # After the subclass _ready() has set colours and polygon
	player = get_tree().get_first_node_in_group("player")
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)

func setup_visuals():
	pass

## Re-styles the Polygon2D as a glowing neon outline with a dark fill.
func _apply_neon():
	if is_dying or not has_node("Polygon2D"):
		return
	var poly: Polygon2D = $Polygon2D
	neon_color = poly.color
	poly.modulate = Color.WHITE
	neon_outline = Neon.apply(poly, neon_color, 0.28, 3.5)
	Neon.add_glow(poly, neon_color, 140.0, 0.14)

## Scales speed/health by the chosen difficulty. Arrays are indexed by level (1-5).
func apply_difficulty(speed_mults: Array, health_mults: Array):
	var level := GlobalData.difficulty_level
	speed *= speed_mults[level]
	health *= health_mults[level]

func set_xp_value(v: int):
	xp_value = v

func take_damage(_amount: float):
	if is_dying:
		return
	health -= _amount
	if play_hit_sfx:
		AudioManager.play_sfx("enemy_hit")
	flash_white()
	if health <= 0:
		die()

func flash_white():
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)

func die():
	if is_dying:
		return
	is_dying = true
	AudioManager.play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3) # Cut off after 0.3s
	spawn_death_particles()
	if death_shake >= 8.0:
		VFX.hit_stop(0.05) # Heavy enemies land a freeze-frame
	if player and death_shake > 0.0 and player.has_method("add_shake"):
		player.add_shake(death_shake)
	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
	GlobalData.total_kills += 1
	GlobalData.run_kills += 1
	GlobalData.add_score(xp_value * 10, player.combo_count if player else 0)
	queue_free()

func spawn_death_particles():
	var color := death_particle_color
	if color.a <= 0.0:
		color = neon_color if neon_color != Color.WHITE else (
			$Polygon2D.color if has_node("Polygon2D") else Color.RED)
	var size := clampf(death_particle_amount / 30.0, 0.5, 2.5)
	VFX.death_burst(global_position, color, size)
	VFX.shockwave(global_position, 0.25 + 0.3 * size, color, 60.0 + 70.0 * size)

## Spawns a hostile bullet travelling along `dir`.
func fire_bullet(dir: Vector2, bullet_speed: float, bullet_damage: float, color: Color, bullet_scale: float = 1.0, spawn_offset: float = 0.0):
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * spawn_offset
	get_parent().add_child(bullet)
	bullet.fired_by_enemy = true
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	bullet.add_to_group("enemy_bullets")
	# Only collide with world (layer 1) and player (layer 2)
	bullet.collision_mask = 0
	bullet.set_collision_mask_value(1, true)
	bullet.set_collision_mask_value(2, true)
	if bullet_scale != 1.0:
		bullet.scale = Vector2(bullet_scale, bullet_scale)
	if bullet.has_node("BulletSprite"):
		bullet.get_node("BulletSprite").color = color

class_name Neon
extends RefCounted
## Helpers for the neon-vector look: dark translucent fill, hot glowing outline,
## and soft additive glow sprites.

static var _glow_texture: GradientTexture2D
static var _additive: CanvasItemMaterial

static func additive_material() -> CanvasItemMaterial:
	if not _additive:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive

static func glow_texture() -> GradientTexture2D:
	if not _glow_texture:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = g
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 128
		_glow_texture.height = 128
	return _glow_texture

## Styles `poly` as a neon shape in `base_color`. Idempotent: call again after the
## polygon points or colour change. Returns the outline Line2D.
static func apply(poly: Polygon2D, base_color: Color, fill_mult: float = 0.3, width: float = 3.0) -> Line2D:
	var outline := poly.get_node_or_null("NeonOutline") as Line2D
	if not outline:
		outline = Line2D.new()
		outline.name = "NeonOutline"
		outline.closed = true
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		outline.material = additive_material()
		poly.add_child(outline)
	outline.width = width
	if outline.points != poly.polygon:
		outline.points = poly.polygon
	outline.default_color = base_color.lerp(Color.WHITE, 0.15) * Color(1.1, 1.1, 1.1, 1.0)
	poly.color = Color(base_color.r * fill_mult, base_color.g * fill_mult, base_color.b * fill_mult, 0.92)
	return outline

## Adds a soft additive glow sprite as a child of `parent`.
static func add_glow(parent: Node2D, color: Color, size: float, alpha: float = 0.5) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.name = "NeonGlow"
	glow.texture = glow_texture()
	glow.material = additive_material()
	glow.modulate = Color(color.r, color.g, color.b, alpha)
	glow.scale = Vector2.ONE * size / 128.0
	glow.z_index = -1
	parent.add_child(glow)
	return glow

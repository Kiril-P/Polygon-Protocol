shader_type canvas_item;

uniform vec2 grid_size = vec2(100.0, 100.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.5, 1.0, 0.1);
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 uv = FRAGCOORD.xy;
    vec2 grid = mod(uv, grid_size);
    
    float line_x = step(grid.x, line_thickness);
    float line_y = step(grid.y, line_thickness);
    
    float mask = max(line_x, line_y);
    COLOR = line_color * mask;
}

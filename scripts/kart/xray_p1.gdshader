shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// Draw only where player 1's kart is NOT seen (stencil 64, written by its own materials),
// and mark the pixel so overlapping parts of the silhouette draw once.
stencil_mode read, write, compare_not_equal, 64;

#include "res://scripts/kart/xray.gdshaderinc"

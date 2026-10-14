shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){float r=length(UV-vec2(0.5))*2.0;ALBEDO=COLOR.rgb;ALPHA=exp(-r*r*5.0)*(1.0-smoothstep(0.5,1.0,r))*0.9;}

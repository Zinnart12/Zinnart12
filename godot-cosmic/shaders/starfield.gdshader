shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);}
void fragment(){float r=length(UV-vec2(0.5))*2.0;ALBEDO=COLOR.rgb;ALPHA=exp(-r*r*5.0)*(1.0-smoothstep(0.5,1.0,r))*0.9;ALPHA_SCISSOR_THRESHOLD=0.04;}

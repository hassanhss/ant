$input a_position, a_normal, a_color0
$output v_normal, v_viewdir, v_color0

#include <bgfx_shader.sh>

uniform vec4 u_eyepos;

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 wpos = mul(u_model[0], vec4(pos, 1.0));
	
	v_viewdir = u_eyepos - wpos;	
	v_normal = a_normal;
	v_color0 = a_color0;
}
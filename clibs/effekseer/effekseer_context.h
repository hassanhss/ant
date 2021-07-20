#pragma once

#include <Effekseer.h>
#include <EffekseerRenderer/EffekseerRendererBGFX.Renderer.h>
#include <string>
#include <vector>

#include "lua.hpp"

#include "effect.h"

struct program {
	struct uniform {
		uint32_t    handle;
		std::string name;
	};
	uint32_t prog;
	std::vector<uniform> uniforms;

	uint16_t find_uniform(const char* name) const {
		for (auto it : uniforms) {
			if (it.name == name)
				return (uint16_t)it.handle;
		}
		return UINT16_MAX;
	}
};

struct effekseer_ctx
{
	effekseer_ctx(lua_State* L, int idx);
	bool init();
	uint16_t				viewid;
	int32_t					square_max_count{4000};
	std::vector<program>	sprite_programs;
	std::vector<program>	model_programs;
	//std::vector<bgfx_vertex_layout_t*> layouts;
	bgfx_vertex_layout_t*	unlit_layout{ nullptr };
	bgfx_vertex_layout_t*	lit_layout{ nullptr };
	bgfx_vertex_layout_t*	distortion_layout{ nullptr };
	bgfx_vertex_layout_t*	ad_unlit_layout{ nullptr };
	bgfx_vertex_layout_t*	ad_lit_layout{ nullptr };
	bgfx_vertex_layout_t*	ad_distortion_layout{ nullptr };
	bgfx_vertex_layout_t*	mtl_layout{ nullptr };
	bgfx_vertex_layout_t*	mtl1_layout{ nullptr };
	bgfx_vertex_layout_t*	mtl2_layout{ nullptr };
	bgfx_vertex_layout_t*	model_layout{ nullptr };
	lua_State*				lua_State_{ nullptr };
	//
	Effekseer::Matrix44		view_mat;
	Effekseer::Matrix44		proj_mat;
	Effekseer::EffectRef	test_effect;
	Effekseer::Handle		test_handle;
	Effekseer::ManagerRef	manager;
	EffekseerRendererBGFX::RendererRef renderer;
	
	std::vector<effect_adapter> effects;
	effect_adapter* get_effect(int32_t eidx);
	int32_t create_effect(const void* data, int32_t size);
	void destroy_effect(int32_t eidx);
	void draw(float deltaTime);
	void update();
	int fxloader_ = LUA_REFNIL;
};
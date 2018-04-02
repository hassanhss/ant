local ecs = ...
local world = ecs.world

local mu = require "math.util"
local ru = require "render.util"

local asset     = require "asset"
local bgfx          = require "bgfx"

local general_editor_entites = ecs.system "general_editor_entites"

general_editor_entites.singleton "math_stack"

function general_editor_entites:init()
    local ms = self.math_stack

    local vdecl = bgfx.vertex_decl {
        { "POSITION", 3, "FLOAT" },
        { "COLOR0", 4, "UINT8", true }
    }

    do
        local axisid = world:new_entity("rotation", "position", "scale", "render", "name")
        local axis = world[axisid]

        ms(axis.rotation.v, {0, 0, 0, 0}, "=")
        ms(axis.position.v, {0, 0, 0, 1}, "=")
        ms(axis.scale.v, {1, 1, 1}, "=")

        axis.name.n = "axis-tips"
        local material_name = "line.material"

        local render = axis.render
        render.info = {
            {
                mesh = {
                    handle = {
                        group = {
                            {
                                vdecl = vdecl,
                                vb = bgfx.create_vertex_buffer({"fffd",
                                0.0, 0.0, 0.0, 0xff0000ff,  -- x-axis
                                1.0, 0.0, 0.0, 0xff0000ff,
                                0.0, 0.0, 0.0, 0xff00ff00,  -- y-axis
                                0.0, 1.0, 0.0, 0xff00ff00,
                                0.0, 0.0, 0.0, 0xffff0000,  -- z-axis
                                0.0, 0.0, 1.0, 0xffff0000}, vdecl)
                            },
                        }
                    }
                },
                binding = {{
                    material = asset.load(material_name),
                    meshids = {1}
                }},
                srt = {s={0.2, 0.2, 0.2}, r={0, 0, 0}, t={0, 0, 0}}
            },
        }
    end

    do
        local gridid = world:new_entity("rotation", "position", "scale", "render", "name")
        local grid = world[gridid]
        grid.name.n = "grid"
        ms(grid.rotation.v, {0, 0, 0}, "=")        
        ms(grid.scale.v, {1, 1, 1}, "=")
        ms(grid.position.v, {0, 0, 0, 1}, "=")

        local function create_grid_line_points(w, h, unit)
            local t = {"fffd"}
            local function add_point(x, z, clr)
                table.insert(t, x)
                table.insert(t, 0)
                table.insert(t, z)
                table.insert(t, clr)
            end

            local w_len = w * unit
            local hw_len = w_len * 0.5

            local h_len = h * unit
            local hh_len = h_len * 0.5

            local color = 0x88c0c0c0

            -- center lines
            add_point(-hh_len, 0, 0x88ff0000)
            add_point(hh_len, 0, 0x88ff0000)

            add_point(0, -hw_len, 0x880000ff)
            add_point(0, hw_len, 0x8800000ff)

            -- column lines
            for i=0, w do
                local x = -hw_len + i * unit
                add_point(x, -hh_len, color)
                add_point(x, hh_len, color)                
            end

            -- row lines
            for i=0, h do
                local y = -hh_len + i * unit
                add_point(-hw_len, y, color)
                add_point(hw_len, y, color)
            end
            return t
        end

        local render = grid.render
        render.info = {            
            {
                mesh = {
                    handle = {
                        group = {
                            {
                                vdecl = vdecl,
                                vb = bgfx.create_vertex_buffer(
                                    create_grid_line_points(128, 128, 1),
                                    vdecl)
                            }
                        }
                    }
                },
                binding = {
                    {
                        material = asset.load "line.material",
                        meshids = {1}
                    }
                },
                srt = {s={1, 1, 1}, r={0, 0, 0}, t={0, 0, 0}}
            },
        }

    end
end
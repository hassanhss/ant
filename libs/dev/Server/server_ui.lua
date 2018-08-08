dofile("libs/init.lua")

local project_dir = "/Users/ejoy/Desktop/Engine/ant"

package.cpath = "clibs/?.dll; clibs/lib?.so; clibs/?.so;" .. package.cpath
package.path = "libs/dev/Common/?.lua;libs/dev/Server/?.lua;libs/dev/?.lua;".. package.path
package.path = project_dir.."/libs/?.lua;".. package.path
package.path = project_dir.."/libs/?/?.lua;".. package.path

local iup = require "iuplua"
local mobiledevice = require "libimobiledevicelua"
local server_framework = require "server_framework"
server_framework:init("127.0.0.1", 8888)

--todo store in a file
local winfile = require "winfile"
local default_proj_dir =  winfile.currentdir() ..  "/libs"
--ui layout

local script_text = iup.text{ multiline = "YES", expand = "YES" }
local bgfx_text = iup.text{multiline = "YES", expand = "Yes"}
local device_text = iup.text{multiline = "YES", expand = "YES"}

script_text.tabtitle = "Script"
bgfx_text.tabtitle = "Bgfx"
device_text.tabtitle = "Device"
local text_tabs = iup.tabs{script_text, bgfx_text, device_text}

--project directory and run file
local run_file_btn = iup.button{title = "run file"}
local proj_dir_btn = iup.button{title = "select"}
local proj_dir_text = iup.text{expand = "HORIZONTAL", value = default_proj_dir}
server_framework:SetProjectDirectoryPath(default_proj_dir)

--todo for now auto connect all device at start
--beacuse self update needs to connect to server, but will close the vm after that
--for other operation, we need another connection
local start_up_connect = true
local devices = mobiledevice.GetDevices()
for k, v in pairs(devices) do
    server_framework:HandleCommand(v, "CONNECT")
end

local proj_dir_hbox = iup.hbox{run_file_btn, proj_dir_btn, proj_dir_text}
local main_vbox = iup.vbox{text_tabs, proj_dir_hbox}

--device select and connect/disconnect
local device_list = iup.list{expand = "YES", spacing = 1}
local device_frame = iup.frame{device_list, title = "device(s)"}
local connect_list = iup.list{expand = "YES"}
local connect_frame = iup.frame{connect_list, title = "connected"}

local connect_btn = iup.button{title = "connect"}
local disconnect_btn = iup.button{title = "disconnect"}
local open_close_simpad_btn = iup.button{title = "open/close sim pad"}

local connect_btn_hbox = iup.hbox{connect_btn, disconnect_btn, open_close_simpad_btn}
local device_vbox = iup.vbox{device_frame, connect_frame, connect_btn_hbox}

local main_split = iup.split{main_vbox, device_vbox}

--simpad related stuff
local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local shader_mgr = require "render.resources.shader_mgr"
local nk = require "bgfx.nuklear"

local UI_VIEW = 0
local width = 375
local height = 667
local simpad_canvas = iup.canvas{rastersize = "375x667", bgcolor = "255 0 123"}
local simpad_dlg = iup.dialog{simpad_canvas, title = "sim pad", size = "375x667"}
local simpad_show = false

local nkimage = nil
local fps_label = ""
local function init_bgfx()
    rhwi.init(iup.GetAttributeData(simpad_canvas, "HWND"), width, height)

    nk.init{
        view = UI_VIEW,
        width = width,
        height = height,
        decl = bgfx.vertex_decl {
            { "POSITION", 2, "FLOAT" },
            { "TEXCOORD0", 2, "FLOAT" },
            { "COLOR0", 4, "UINT8", true },
        },
        texture = "s_texColor",
        state = bgfx.make_state {
            WRITE_MASK = "RGBA",
            BLEND = "ALPHA",
        },
        prog = shader_mgr.programLoad("ui/vs_nuklear_texture.sc",
                "ui/fs_nuklear_texture.sc"),
    }

    bgfx.set_view_clear(UI_VIEW, "C", 0x303030ff, 1, 0)

end

--call back
function proj_dir_btn:action()
    local filedlg = iup.filedlg{dialogtype = "DIR", title = "select project directory", directory = proj_dir_text.text}
    filedlg:popup(iup.ANYWHERE, iup.ANYWHERE)

    local status = filedlg.status

    if status ~= "-1" then
        --todo
        local slash_string = string.gsub(filedlg.value, "\\", "/");

        proj_dir_text.value = slash_string
        server_framework:SetProjectDirectoryPath(slash_string)
    end

    filedlg:destroy()
end

function run_file_btn:action()
    local filedlg = iup.filedlg{dialogtype = "OPEN", title = "run file", filter = "*.lua", filterinfo = "Lua files", directory = proj_dir_text.value}
    filedlg:popup(iup.ANYWHERE, iup.ANYWHERE)

    local status = filedlg.status

    --send connect command
    --todo fix it later
    local devices = mobiledevice.GetDevices()
    for k, v in pairs(devices) do

        if status ~= "-1" then
            local file_value = string.gsub(filedlg.value, "\\", "/")

            server_framework:HandleCommand(v, "RUN", file_value)
        end

    end

    filedlg:destroy()
end

function connect_btn:action()
    local select_idx = device_list.value

    --none selected
    if select_idx == 0 then
        return
    end

    local udid = device_list[select_idx]
    --disconnect old connection
    --todo fix it later
    server_framework:HandleCommand(udid, "DISCONNECT")
    server_framework:HandleCommand(udid, "CONNECT")
end


function disconnect_btn:action()
    local select_idx = connect_list.value

    --none selected
    if select_idx == 0 then
        return
    end

    local udid = connect_list[select_idx]
    server_framework:HandleCommand(udid, "DISCONNECT")
end

function simpad_dlg:close_cb()
    simpad_show = false
end

function open_close_simpad_btn:action()
    if simpad_show then
        simpad_dlg:hide()

        simpad_show = false
    else
        server_framework:HandleCommand("all", "SCREENSHOT")

        simpad_dlg:showxy(iup.ANYWHERE, iup.ANYWHERE)
        simpad_dlg.usersize = nil

        if init_bgfx then
            init_bgfx()
            init_bgfx = nil
        end

        simpad_show = true
    end
end

local lodepng = require "lodepnglua"
local function HandleResponse(resp_table)

    for _,v in ipairs(resp_table) do
        --this is just log
        --for now, just show on the multitext
        --need to unpack twice, because the text is packed too

        if v[1] == "log" then
            --unpack the log data
            local log_table = v[2]

            local cat = log_table[1]

            if cat == "Script" then
                local new_log_value = log_table[2]
                if new_log_value then
                    new_log_value = new_log_value .. "\n"
                    --todo temperary disable
                    ---[[
                    script_text.value = script_text.value .. new_log_value
                    local pos = iup.TextConvertLinColToPos(script_text,  script_text.linecount, 0)
                    script_text.caretpos = pos
                    script_text.scrolltopos = pos

                end
--]]
            elseif cat == "Bgfx" then
                local new_log_value = log_table[2]
                new_log_value = new_log_value .. "\n"

                bgfx_text.value = bgfx_text.value .. new_log_value
                local pos = iup.TextConvertLinColToPos(bgfx_text,  bgfx_text.linecount, 0)
                bgfx_text.caretpos = pos
                bgfx_text.scrolltopos = pos

            elseif cat == "Device" then
                local new_log_value = log_table[2]
                new_log_value = new_log_value .. "\n"

                device_text.value = device_text.value .. new_log_value
                local pos = iup.TextConvertLinColToPos(device_text,  device_text.linecount, 0)
                device_text.caretpos = pos
                device_text.scrolltopos = pos
            elseif cat == "Fps" then
                local gpu_timer = log_table[2]
                local cpu_timer = log_table[3]

                fps_label = "cpu time: "..cpu_timer
                print("Get fps", gpu_timer, cpu_timer)
            elseif cat == "Time" then
                --print("time", log_table[2])
            else
                --for now ignore other category
            end


        elseif v[1] == "connect" then
            --device connection and disconnection
            if v[2] == 1 then
                --connected
                --start up connect for self update
                if start_up_connect then
                    start_up_connect = false
                else
                    local idx = connect_list.count
                    connect_list[idx+1] = v[3]
                end

            else
                --disconnected
                local list_count = connect_list.count
                for i = 1, list_count do
                    if connect_list[i] == v[3] then
                        --remove the item
                        for j = i, list_count-1 do
                            connect_list[j] = connect_list[j+1]
                        end
                        connect_list[list_count] = nil
                        break
                    end
                end
            end
        elseif v[1] == "screenshot" then
            local screenshot = v[2]
            local name = screenshot[1]
            local encode_data = screenshot[2]
            print("screenshot data size", #encode_data)
            --decompress it and show the image
            local data, width, height = lodepng.decode_png(encode_data)

            print("decode screenshot data", width, height, #data)
            if width > 0 and height > 0 and #data > 0 then
                --assert(width > 0 and height > 0 and #data > 0)
                print("get screenshot", width, height, #data)

                local nkatlas = nk.loadImageFromMemory(data,width,height,#data/width/height)
                nkimage = nk.makeImage( nkatlas.handle,nkatlas.w,nkatlas.h)  -- make from outside id ,w,h
            else
                --todo handle decode error
            end
        else
            print("resp " .. v[1] .. " not support yet")
        end

    end
end

--return a table
local devices = mobiledevice.GetDevices()
--init connect devices
for i = 1, #devices do
    device_list[i] = devices[i]
end

local dlg = iup.dialog{main_split, title = "ANT ENGINE", size = "HALFxHALF"}


dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

local time_stamp = 0.0
local function UpdateSimpad()
    local time_now = os.clock()
    local time_step = time_now - time_stamp;
    if time_step > 1.0 then
        time_stamp = time_now

        server_framework:HandleCommand("all", "SCREENSHOT")
    end

    if nk.windowBegin( "Test",fps_label, 0, 0, 375, 667,
            "movable", "title", "scrollbar") then
        --image(nkimage)

        nk.layoutRow('dynamic',310,{0.15,0.7,0.15} )
        nk.spacing(1)
        if nkimage then
            nk.image( nkimage )
        end
    end
    nk.windowEnd()
    nk.update()

    bgfx.frame()
end

-- to be able to run this script inside another context
while true do
    local msg = iup.LoopStep()
    if msg == iup.CLOSE then
        break
    end

    server_framework:update()
    local resp_table = server_framework:RecvResponse()
    HandleResponse(resp_table)
    --handle response here

    if simpad_dlg and simpad_show then
        UpdateSimpad()
    end

end

iup.Close()
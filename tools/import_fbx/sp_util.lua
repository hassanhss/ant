local util = {}
local subprocess = require "subprocess"
local fs = require "filesystem.local"
local platform = require "platform"

local function quote_arg(s)
    if type(s) ~= 'string' then
        s = tostring(s)
    end
    if #s == 0 then
        return '""'
    end
    if not s:find('[ \t\"]', 1) then
        return s
    end
    if not s:find('[\"\\]', 1) then
        return '"'..s..'"'
    end
    local quote_hit = true
    local t = {}
    t[#t+1] = '"'
    for i = #s, 1, -1 do
        local c = s:sub(i,i)
        t[#t+1] = c
        if quote_hit and c == '\\' then
            t[#t+1] = '\\'
        elseif c == '"' then
            quote_hit = true
            t[#t+1] = '\\'
        else
            quote_hit = false
        end
    end
    t[#t+1] = '"'
    for i = 1, #t // 2 do
        local tmp = t[i]
        t[i] = t[#t-i+1]
        t[#t-i+1] = tmp
    end
    return table.concat(t)
end

local function to_cmdline(commands)
    local s = {}
    for _, v in ipairs(commands) do
        if type(v) == "table" then
            for _, vv in ipairs(v) do
                s[#s+1] = quote_arg(vv)
            end
        else
            s[#s+1] = quote_arg(v)
        end
    end
    return table.concat(s, " ")
end

function util.spawn_process(commands)
    commands.stdout     = true
    commands.stderr     = true
    commands.hideWindow = true
	local prog = subprocess.spawn(commands)
	local msg = {}
	msg[#msg+1] = to_cmdline(commands)
	if not prog then
		msg[#msg+1] = "----------------------------"
		msg[#msg+1] = "Failed"
		msg[#msg+1] = "----------------------------"
		return false, table.concat(msg, "\n")
	end
	if prog.stdout then
		local s = prog.stdout:read "a"
		if #s > 0 then
			msg[#msg+1] = "========== stdout =========="
			msg[#msg+1] = s
		end
	end
	if prog.stderr then
		local s = prog.stderr:read "a"
		if #s > 0 then
			msg[#msg+1] = "========== stderr =========="
			msg[#msg+1] = s
		end
	end
	msg[#msg+1] = "----------------------------"
	local errcode = prog:wait()
	if errcode ~= 0 then
		msg[#msg+1] = string.format("Failed, error code:%x", errcode)
		msg[#msg+1] = "----------------------------"
		return false, table.concat(msg, "\n")
	end
	msg[#msg+1] = "Success"
	msg[#msg+1] = "----------------------------"
	return true, table.concat(msg, "\n")
end

local function find_bindir()
    local binpath = (fs.current_path() / "bin/"):string():gsub("\\", "/")
    for w in package.cpath:gmatch "[^;]+" do
        local l = w:gsub("\\", "/")
        if l:match(binpath) then
            return l:sub(1, -6)
        end
    end
end

local BINDIR = fs.path(assert(find_bindir()))
local TOOLSUFFIX = platform.OS == "OSX" and "" or ".exe"

function util.tool_exe_path(toolname)
    local exepath = BINDIR / (toolname .. TOOLSUFFIX)
    if fs.exists(exepath) then
        return exepath
    end
    error(table.concat({
        "Can't found tools in : ",
        "\t" .. tostring(exepath)
    }, "\n"))
end

return util

local fs = require "filesystem"

local support_types = {
	sc		= true,
	mesh 	= true,
	state 	= true,
	material= true,
	texture = true,
	hierarchy= true,--scene hierarchy info, using ozz-animation runtime struct
	lk 		= true,
	ozz 	= true,
	sm 		= true,	--animation state machine
	terrain = true,
	fx		= true,
}

local resources = {}
local accessors = {}

local assetmgr = {}
assetmgr.__index = assetmgr

local function get_accessor(name)
	local accessor = accessors[name]
	if accessor == nil then
		if support_types[name] then
			accessor 		= require ("ext_" .. name)
			accessors[name] = accessor
		else
			error("Unsupport asset type: " .. name)
		end
	end
	return accessor
end

function assetmgr.get_loader(name)
	return get_accessor(name).loader
end

function assetmgr.get_unloader(name)
	return get_accessor(name).unloader
end

local function rawtable(filepath)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end

assetmgr.load_depiction = rawtable

local function res_key(filename)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file	
	return filename:string()
end

local function module_name(filepath)
	return filepath:extension():string():match "%.(.+)$"
end

local function get_resource(ref_path)
	local reskey = res_key(ref_path)
	return resources[reskey]
end

assetmgr.get_resource = get_resource
assetmgr.res_key = res_key

function assetmgr.load(filename, param)
	local reskey = res_key(filename)
	local res = resources[reskey]
	if res == nil then
		local loader = assetmgr.get_loader(module_name(filename))
		res = loader(filename, param)
		resources[reskey] = res
	end
	
	return res
end

function assetmgr.unload(filename)
	local reskey = res_key(filename)
	local res = resources[reskey]
	if res then
		local unloader = assetmgr.get_unloader(module_name(filename))
		if unloader then
			unloader(res)
		end
		resources[reskey] = nil
	else
		log.error("not found resource:", filename:string())
	end
end

local function generate_resname_operation()
	local stem_namemapper = {}
	return function (resname)
		local ss = resname:string()
		assert(ss:sub(1, 2) == "//")
		
		local stem = resname:stem()
		
		local stemname = stem:string()
		local idx = stem_namemapper[stemname] or 0
		idx = idx + 1
		stem_namemapper[stemname] = idx
		
		return resname:parent_path() / stemname .. "_" .. idx .. resname:extension():string()
	end
end

local generate_resname = generate_resname_operation()

function assetmgr.register_resource(reffile, content)
	local res = get_resource(reffile)
	if res then
		local newreffile = generate_resname(reffile)
		res = get_resource(newreffile)
		if res then
			log.error("ref key have been used:", reffile:string(), ", regenerate resname still used:", newreffile:string())
		else
			log.info("duplicate resname : ", reffile:string(), ", using new resname:", newreffile:string())
		end
		reffile = newreffile
	end

	resources[res_key(reffile)] = content
	return reffile
end

function assetmgr.get_all_resources()
	return resources
end

function assetmgr.save(tree, filename)	
	local seri = import_package "ant.serialize"
	seri.save(filename, tree)
end

function assetmgr.has_res(filename)
	local key = res_key(filename)
	return resources[key] ~= nil
end

return assetmgr

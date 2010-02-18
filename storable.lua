
--[[
 
  License
 
  lua storable is distributed under the zlib/libpng license, which is OSS
  (Open Source Software) compliant.
 
  Copyright (C) 2009 Tim Aerts
 
  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.
 
  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:
 
  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
 
  Tim Aerts <aardbeiplantje@gmail.com>

--]] 

local S = {}

if _REQUIREDNAME == nil then
    _REQUIREDNAME = "storable"
end
_G[_REQUIREDNAME] = S

local b  = require("bpack")
local bunpack  = function(format, s)
    return b(s, format)
end

local push  = table.insert
local ord   = string.byte

local function _read_size(fh, cache)
    return bunpack(cache.size_unpack_fmt, fh:read(4))
end

local engine, exclude_for_cache

local function process_item(fh, cache)
    local magic_type = fh:read(1)
    print('magic:', ord(magic_type),",where:",fh:seek(),',will do:',engine[magic_type])
    if exclude_for_cache[magic_type] == nil then
        local i = cache.objectnr
        cache.objectnr = cache.objectnr+1
        print("set i:", i)
        cache.objects[i] = engine[magic_type](fh, cache)
        print("set i:", i, ",to:", cache.objects[i])
        return cache.objects[i]
    else
        return engine[magic_type](fh, cache)
    end
end

S.SX_OBJECT = function(fh, cache)
    -- idx's are always big-endian dumped by storable's freeze/nfreeze I think
    local i = bunpack('>I', fh:read(4))
    cache.has_sx_object = true
    return function () return i end
end

S.SX_LSCALAR = function(fh, cache)
    return fh:read(_read_size(fh, cache))
end

S.SX_LUTF8STR = function(fh, cache)
    return SX_LSCALAR(fh, cache)
end

S.SX_ARRAY = function(fh, cache)
    local data = {} 
    for i=1,_read_size(fh, cache) do
        push(data, process_item(fh, cache))
    end

    return data
end

S.SX_HASH = function(fh, cache)
    local data = {}
    for i=1,_read_size(fh, cache) do
        value = process_item(fh, cache)
        key   = fh:read(_read_size(fh, cache))
        data[key] = value
    end

    return data
end

S.SX_REF = function(fh, cache)
    return process_item(fh, cache)
end

S.SX_UNDEF = function(fh, cache)
    return nil
end

S.SX_DOUBLE = function(fh, cache)
    print("SX_DOUBLE")
    return tonumber(bunpack(cache.double_unpack_fmt, fh:read(8)))
end

S.SX_BYTE = function(fh, cache)
    return ord(fh:read(1)) - 128
end

S.SX_NETINT = function(fh, cache)
    return bunpack('>I', fh:read(4))
end

S.SX_SCALAR = function(fh, cache)
    return fh:read(ord(fh:read(1)))
end

S.SX_UTF8STR = function(fh, cache)
    return SX_SCALAR(fh, cache)
end

S.SX_TIED_ARRAY = function(fh, cache)
    return process_item(fh, cache)
end

S.SX_TIED_HASH = function(fh, cache)
    return SX_TIED_ARRAY(fh, cache)
end

S.SX_TIED_SCALAR = function(fh, cache)
    return SX_TIED_ARRAY(fh, cache)
end

S.SX_SV_UNDEF = function(fh, cache)
    return nil
end

S.SX_BLESS = function(fh, cache)
    local package_name = fh:read(ord(fh:read(1)))
    cache.classes.append(package_name)
    return process_item(fh, cache)
end

S.SX_IX_BLESS = function(fh, cache)
    -- FIXME: not used yet
    local package_name = cache.classes[ord(fh:read(1))]
    return process_item(fh, cache)
end

S.SX_OVERLOAD = function(fh, cache)
    return process_item(fh, cache)
end

S.SX_TIED_KEY = function(fh, cache)
    local data = process_item(fh, cache)
    local key  = process_item(fh, cache)
    return data
end
    
S.SX_TIED_IDX = function(fh, cache)
    local data = process_item(fh, cache)
    -- idx's are always big-endian dumped by storable's freeze/nfreeze I think
    local indx_in_array = bunpack('>I', fh:read(4))
    return data
end

S.SX_HOOK = function(fh, cache)
    --[[
    local flags = bunpack('b', fh:read(1))

    while flags & int(0x40) do   -- SHF_NEED_RECURSE
        print("SHF_NEED_RECURSE")
        local dummy = process_item(fh, cache)
        print(dummy)
        flags = bunpack('b', fh:read(1))
        print("flags:",flags)
    end

    print("recursive done")

    if flags & int(0x20) then   -- SHF_IDX_CLASSNAME
        print("SHF_IDX_CLASSNAME")
        print("where:", fh:seek())
        local indx
        if flags & int(0x04) then   -- SHF_LARGE_CLASSLEN
            print("SHF_LARGE_CLASSLEN")
            -- TODO: test
            indx = bunpack('>I', fh:read(4))
        else
            indx = bunpack('b', fh:read(1))
        end
        print("classindx:", indx)
        local package_name = cache.classes[indx]
    else
        print("where:", fh:seek())
        local class_size
        if flags & int(0x04) then   -- SHF_LARGE_CLASSLEN
            print("SHF_LARGE_CLASSLEN")
            -- TODO: test
            -- FIXME: is this actually possible?
            class_size = _read_size(fh, cache)
        else
            class_size = bunpack('b', fh:read(1))
            print("size:", class_size)

        local package_name = fh:read(class_size)
        cache.classes.append(package_name)
        print("size:", class_size, ",package:", package_name)
    end

    local arguments = {}

    local str_size = 0
    if flags & int(0x08) then   -- SHF_LARGE_STRLEN
        print("SHF_LARGE_STRLEN")
        str_size = _read_size(fh, cache)
    else
        print("where:", fh:seek())
        str_size = bunpack('b', fh:read(1))

    if str_size then
        local frozen_str = fh:read(str_size)
        print("size:", str_size, ",frozen_str:", frozen_str)
        arguments[0] = frozen_str
    end

    local list_size = 0
    if flags & int(0x80) then   -- SHF_HAS_LIST
        print("SHF_HAS_LIST")
        if flags & int(0x10) then   -- SHF_LARGE_LISTLEN
            print("SHF_LARGE_LISTLEN")
            print("where:",fh:seek())
            list_size = _read_size(fh, cache)
        else
            list_size = bunpack('b', fh:read(1))
        end
    end

    print("list_size:", list_size)
    for i=0,list_size do
        local indx_in_array = bunpack('>I', fh:read(4))
        print("indx:", indx_in_array)
        if cache.objects[indx_in_array] ~= nil then
            arguments[i+1] = cache.objects[indx_in_array]
        else
            arguments[i+1] = 'None' -- FIXME
        end
    end

    -- FIXME: implement the real callback STORABLE_thaw() still, for now, just
    -- return the dictionary 'arguments' as data
    local sht_type = flags & int(0x03) -- SHF_TYPE_MASK 0x03
    print("flags:",sht_type)
    data = arguments
    if      sht_type == 3 then  -- SHT_EXTRA
        -- TODO
        print("SHT_EXTRA")
    elseif sht_type == 0 then  -- SHT_SCALAR
        -- TODO
        print("SHT_SCALAR")
    elseif sht_type == 1 then  -- SHT_ARRAY
        -- TODO
        print("SHT_ARRAY")
    elseif sht_type == 2 then  -- SHT_HASH
        -- TODO
        print("SHT_HASH")
    end

    --]]
    return data
end

S.SX_FLAG_HASH = function(fh, cache)
    -- TODO: NOT YET IMPLEMENTED!!!!!!
    print("SX_FLAG_HASH:where:", fh:seek())
    local flags = ord(fh:read(1))
    local size  = _read_size(fh, cache)
    print("size:",size)
    print("flags:", flags)
    local data = {}
    for i=0,size do
        local value = process_item(fh, cache)
        local flags = ord(fh:read(1))
        local keysize = _read_size(fh, cache)
        local key
        if keysize then
            key = fh:read(keysize)
        end
        data[key] = value
    end

    return data
end

-- *AFTER* all the subroutines
engine = {
    ["\000"] = S.SX_OBJECT,      -- ( 0): Already stored object
    ["\001"] = S.SX_LSCALAR,     -- ( 1): Scalar (large binary) follows (length, data)
    ["\002"] = S.SX_ARRAY,       -- ( 2): Array forthcoming (size, item list)
    ["\003"] = S.SX_HASH,        -- ( 3): Hash forthcoming (size, key/value pair list)
    ["\004"] = S.SX_REF,         -- ( 4): Reference to object forthcoming
    ["\005"] = S.SX_UNDEF,       -- ( 5): Undefined scalar
    ["\007"] = S.SX_DOUBLE,      -- ( 7): Double forthcoming
    ["\008"] = S.SX_BYTE,        -- ( 8): (signed) byte forthcoming
    ["\009"] = S.SX_NETINT,      -- ( 9): Integer in network order forthcoming
    ["\010"] = S.SX_SCALAR,      -- (10): Scalar (binary, small) follows (length, data)
    ["\011"] = S.SX_TIED_ARRAY,  -- (11): Tied array forthcoming
    ["\012"] = S.SX_TIED_HASH,   -- (12): Tied hash forthcoming
    ["\013"] = S.SX_TIED_SCALAR, -- (13): Tied scalar forthcoming
    ["\014"] = S.SX_SV_UNDEF,    -- (14): Perl's immortal PL_sv_undef
    ["\017"] = S.SX_BLESS,       -- (17): Object is blessed
    ["\018"] = S.SX_IX_BLESS,    -- (18): Object is blessed, classname given by index
    ["\019"] = S.SX_HOOK,        -- (19): Stored via hook, user-defined
    ["\020"] = S.SX_OVERLOAD,    -- (20): Overloaded reference
    ["\021"] = S.SX_TIED_KEY,    -- (21): Tied magic key forthcoming
    ["\022"] = S.SX_TIED_IDX,    -- (22): Tied magic index forthcoming
    ["\023"] = S.SX_UTF8STR,     -- (23): UTF-8 string forthcoming (small)
    ["\024"] = S.SX_LUTF8STR,    -- (24): UTF-8 string forthcoming (large)
    ["\025"] = S.SX_FLAG_HASH,   -- (25): Hash with flags forthcoming (size, flags, key/flags/value triplet list)
}

exclude_for_cache = {
    ["\000"] = true,
    ["\009"] = true,
    ["\010"] = true,
    ["\011"] = true,
    ["\017"] = true,
    ["\018"] = true
}

local function handle_sx_object_refs(cache, data)
    for k,item in ipairs(data) do
        if type(item) == 'table' then
            handle_sx_object_refs(cache, item)
        elseif type(item) == 'function' then
            data[k] = cache.objects[item()]
        end
    end
    for k,item in pairs(data) do
        if type(item) == 'table' then
            handle_sx_object_refs(cache, item)
        elseif type(item) == 'function' then
            data[k] = cache.objects[item()]
        end
    end
    return data
end

local function deserialize(fh)
    local magic = fh:read(1)
    local byteorder = '>'
    local version
    if magic == '\005' then
        version = fh:read(1)
        print("OK:nfreeze") 
    end
    if magic == '\004' then
        version = fh:read(1)
        byteorder = fh:read(ord(fh:read(1)))
        print("OK:freeze:",byteorder)

        -- 32-bit ppc:     4321
        -- 32-bit x86:     1234
        -- 64-bit x86_64:  12345678
        
        if byteorder == '1234' or byteorder == '12345678' then
            byteorder = '<'
        else
            byteorder = '>'
        end

        local somethingtobeinvestigated = fh:read(4)
    end

    print('version:', ord(version));
    local cache = { 
        objects           = {},
        objectnr          = 0,
        classes           = {},
        has_sx_object     = false,
        size_unpack_fmt   = byteorder .. 'I',
        double_unpack_fmt = byteorder .. 'd'
    }
    local data = process_item(fh, cache)

    if cache.has_sx_object then
        handle_sx_object_refs(cache, data)
    end

    return data
end
            
function S.thaw(frozen_data)
    --local fh = cStringIO.StringIO(frozen_data)
    --local data = deserialize(fh)
    --fh:close()
    return frozen_data
end

function S.retrieve(file)
    local fh = assert(io.open(file, 'r'))
    local ignore = fh:read(4)
    local data
    if ignore == 'pst0' then
        data = deserialize(fh)
    end
    fh:close()
    return data
end

return S

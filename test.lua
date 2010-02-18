#!/usr/bin/lua

require("dumper")
require("storable")

local nr_of_tests = 36

local expected = {
    ["i386-darwin"]   = {
        ["2.19"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = nr_of_tests,
            ["nstore"]  = nr_of_tests
        }
    },
    ["i686-linux"]   = {
        ["2.15"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = 0,
            ["nstore"]  = 0
        }
    },
    ["MSWin32"]      = {
        ["2.15"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = 0,
            ["nstore"]  = 0
        }
    },
    ["ppc-linux"]    = {
        ["2.18"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = nr_of_tests,
            ["nstore"]  = nr_of_tests
        },
        ["2.21"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = nr_of_tests,
            ["nstore"]  = nr_of_tests
        }
    },
    ["sun4-solaris"] = {
        ["2.08"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = 0,
            ["nstore"]  = 0
        }
    },
    ["x86_64-linux"] = {
        ["2.18"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = nr_of_tests,
            ["nstore"]  = nr_of_tests
        },
        ["2.21"] = { 
            ["nfreeze"] = nr_of_tests,
            ["freeze"]  = nr_of_tests,
            ["store"]   = nr_of_tests,
            ["nstore"]  = nr_of_tests
        }
    },
}

local src = 't/resources'
local res = 't/results'

--[[
  search for the special tests where the freeze result is not the same as the
  nfreeze result (same for store/nstore). Those tests really do have a seperate
  result file. In such a case, we take the other .store.py file instead of the
  plain .py file as a result to compare with
--]]

local special_tests = {}
for result in io.popen('ls '..res .. '/*.freeze.py'):lines() do
    result = string.gmatch(result, '^.*/(.*).freeze.py$')
    special_tests[result] = 1
end

local function determine_outfile(infile)
    print("infile:", infile)
    local testcase
    local freeze
    for a in string.gmatch(infile, ".*/(.*)_.*_.*_freeze.storable$") do
        testcase = a
        freeze   = 'freeze'
    end
    for a in string.gmatch(infile, ".*/(.*)_.*_.*_nfreeze.storable$") do
        testcase = a
        freeze   = 'nfreeze'
    end
    for a in string.gmatch(infile, ".*/(.*)_.*_.*_store.storable$") do
        testcase = a
        freeze   = 'store'
    end
    for a in string.gmatch(infile, ".*/(.*)_.*_.*_nstore.storable$") do
        testcase = a
        freeze   = 'nstore'
    end
    if freeze == 'freeze' and special_tests[testcase] ~= nil then
        return res .. '/' .. testcase .. '.freeze.lua'
    else
        return res .. '/' .. testcase .. '.lua'
    end
end

local function mythaw(infile)
    --print('reading from infile:',infile)
    local infh = io.open(infile, 'r')
    local data = infh:read()
    infh:close()

    return storable.thaw(data)
end

local function do_test(infile, deserializer)
    local data = deserializer(infile)

    -- read the to-be-result in
    local outfile = determine_outfile(infile)
    os.execute("touch "..outfile)
    local outfh = assert(io.open(outfile,'r'))
    local result_we_need = outfh:read()
    --print(str(result_we_need))
    outfh:close()

    -- dump it
    if 1 == 1 then
        --print('writing output to ',outfile)
        local outfh = io.open(outfile,'w')
        outfh:write(string.dumper(data))
        outfh:close()
    end

    -- check
    if string.dumper(data) == string.dumper(result_we_need) then
        print('infile: ',infile,' ,outfile: ',outfile)
    end
end

local function run_tests(architecture, storableversion, method)
    local d = mythaw
    if method == 'store' or method == 'nstore' then
        d = storable.retrieve
    end
    print("architecture:",architecture,",storableversion:",storableversion,",method:",method)
    local nr_tests = expected[architecture][storableversion][method]
    local files = src..'/'..architecture..'/'..storableversion..'/*_'..method..'.storable'
    local count = 0
    for infile in io.popen("ls "..files):lines() do
        do_test(infile, d)
        count = count + 1
    end
    if count == nr_tests then
        print("count == nr_tests")
    else
        raise()
    end
end

        
for arch, w in pairs(expected) do
    for version, w in pairs(w) do
        for method, w in pairs(w) do
            run_tests(arch, version, method)
        end
    end
end

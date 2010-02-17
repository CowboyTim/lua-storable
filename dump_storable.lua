#!/usr/bin/lua

require("storable")

local a = storable.retrieve(arg[1])

for i,v in ipairs(a) do
    print("i:",i,",v:",v)
end

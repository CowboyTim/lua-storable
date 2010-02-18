#!/usr/bin/lua

require("storable")
require("dumper")

print(string.dumper(storable.retrieve(arg[1])))

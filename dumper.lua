
local push = table.insert
local join = table.concat

local function dumper(...)
    local t = {}
    for i,a in ipairs(arg) do
        if type(a) == 'table' then
            local s = {}
            for j,b in ipairs(a) do
                push(s,dumper(b))
            end
            for j,b in pairs(a) do
                push(s,j.."="..dumper(b))
            end
            push(t, "{"..join(s, ",").."}")
        else
            if type(a) == 'string' then
                a = "\""..a.."\""
            end
            push(t,a)
        end
    end
    return join(t,"\n")
end

string.dumper = dumper

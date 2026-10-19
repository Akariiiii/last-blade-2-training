-- Last Blade 2 Live Training. Lua 5.1 / Fightcade FBNeo.
-- Load this file through Game > Lua Scripting > New Lua Script Window.
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local root = source:match("^(.*[/])") or "./"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local app = require("lb2.app").new()
_G.LB2Training = app -- Introspection for optional tests; normal operation writes no files.
app:start()

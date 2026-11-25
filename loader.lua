-- Finifugal 2.0 — loud loader.
-- A bare `loadstring(httpget(url))()` fails silent: Matcha's httpget returns ""
-- on any network error, and loadstring("") is a valid empty chunk. You get no
-- error and no cheat. This version names the stage it died at.

local URL = "https://raw.githubusercontent.com/elclubdelahorro/Finifugal/main/criminality.lua"

print("[Finifugal] fetching " .. URL)

local src = nil
if type(httpget) == "function" then
	src = httpget(URL)
else
	local ok, got = pcall(function() return game:HttpGet(URL) end)
	if ok then src = got end
end

if type(src) ~= "string" or #src < 1000 then
	local n = (type(src) == "string") and ("#" .. #src .. " bytes") or ("type " .. type(src))
	print("[Finifugal] DOWNLOAD FAILED: " .. n .. " — the executor blocked or failed the fetch")
	return
end

print("[Finifugal] downloaded " .. #src .. " bytes")

local chunk, err = loadstring(src)
if type(chunk) ~= "function" then
	print("[Finifugal] COMPILE FAILED: " .. tostring(err))
	return
end

local ok, runErr = pcall(chunk)
if not ok then
	print("[Finifugal] RUNTIME FAILED: " .. tostring(runErr))
else
	print("[Finifugal] loaded. key tab should be in the menu now.")
end

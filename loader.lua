-- Finifugal 2.0 — loud loader. Any executor: Xeno, desktop, Matcha, mobile.
-- The one-liner fails silent in four different ways, and all four look the
-- same from the outside: nothing happens. This version names the stage.
--   1. every HTTP door the executor has, in order, each pcall'd
--   2. a byte count and a marker check, so an error page is not a script
--   3. compile errors printed with the line
--   4. runtime errors printed with a traceback
--   5. a capability probe, so the next report is a fact not a guess

-- Three hosts, same bytes. raw.githubusercontent is blocked outright by some
-- executors and rate-limited by others; jsDelivr and githack answer where it
-- does not. First one that returns a body with the marker wins.
local URLS = {
	"https://raw.githubusercontent.com/elclubdelahorro/Finifugal/main/criminality.lua",
	"https://cdn.jsdelivr.net/gh/elclubdelahorro/Finifugal@main/criminality.lua",
	"https://raw.githack.com/elclubdelahorro/Finifugal/main/criminality.lua",
}

local function say(s) pcall(function() print("[Finifugal] " .. s) end) end

-- ── capability probe ──────────────────────────────────────────────────────
-- Read this block first when something does not draw. It is the whole story.
do
	local name = "?"
	pcall(function()
		if type(identifyexecutor) == "function" then name = tostring(identifyexecutor())
		elseif type(getexecutorname) == "function" then name = tostring(getexecutorname()) end
	end)
	local function has(f) return type(f) == "function" and "yes" or "NO" end
	say(string.format("exec=%s drawing=%s inst=%s genv=%s hui=%s clip=%s move=%s fire=%s fs=%s",
		name,
		Drawing ~= nil and "yes" or "NO",
		(type(Instance) == "table" and type(Instance.new) == "function") and "yes" or "NO",
		has(getgenv), has(gethui), has(setclipboard),
		has(mousemoverel), has(mouse1press),
		(type(readfile) == "function" and type(writefile) == "function") and "yes" or "NO"))
	pcall(function()
		local sem = Enum.KeyCode and Enum.KeyCode.Semicolon
		say("menu key: Semicolon=" .. tostring(sem ~= nil)
			.. " RightShift=" .. tostring(Enum.KeyCode.RightShift ~= nil)
			.. " K=" .. tostring(Enum.KeyCode.K ~= nil))
	end)
end

-- ── fetch ─────────────────────────────────────────────────────────────────
-- Every door, in order. Xeno answers game:HttpGet; some builds only answer the
-- request table, and a couple choke on the nocache second argument.
local DOORS = {
	{ "HttpGet+nc", function(u) return game:HttpGet(u, true) end },
	{ "HttpGet",    function(u) return game:HttpGet(u) end },
	{ "httpget",    function(u) return httpget(u) end },
	{ "request",    function(u) return request({ Url = u, Method = "GET" }).Body end },
	{ "syn.request",function(u) return syn.request({ Url = u, Method = "GET" }).Body end },
	{ "http.request",function(u) return http.request({ Url = u, Method = "GET" }).Body end },
}

local src, door, host
for _, u in ipairs(URLS) do
	for _, d in ipairs(DOORS) do
		local ok, got = pcall(d[2], u)
		if ok and type(got) == "string" and #got > 1000 and string.find(got, "Finifugal", 1, true) then
			src, door, host = got, d[1], u
			break
		end
		if ok then
			say(string.format("%s -> %s returned %s", u, d[1],
				type(got) == "string" and ("#" .. #got .. " bytes") or type(got)))
		else
			say(string.format("%s -> %s raised: %s", u, d[1], tostring(got)))
		end
	end
	if src then break end
end

if not src then
	say("DOWNLOAD FAILED on every door — the executor has no working network path")
	say("paste the file by hand: open criminality.lua, select all, paste into the executor")
	return
end

say(string.format("downloaded %d bytes via %s (%s)", #src, door, host))

-- ── compile ───────────────────────────────────────────────────────────────
local chunk, err = loadstring(src)
if type(chunk) ~= "function" then
	say("COMPILE FAILED: " .. tostring(err))
	return
end

-- ── run ───────────────────────────────────────────────────────────────────
local ok, runErr = pcall(chunk)
if not ok then
	local tb = runErr
	pcall(function() tb = debug.traceback(tostring(runErr), 2) end)
	say("RUNTIME FAILED:\n" .. tostring(tb))
	return
end

say("loaded. Semicolon (N on a Spanish layout) opens the panel.")

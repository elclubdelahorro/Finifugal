-- Finifugal 2.0 (Roblox) — wallhack, soft aim, map spots.
-- executor-side Lua. Drawing is optional: without it the ESP runs on frames.
-- Matcha profile: capabilities probed once, projection rects cached per player.
-- Key gate first:  avestfriend  (rebake with Finifugal.bake("new-key")).
-- N (semicolon) opens the panel. RightShift toggles ESP. K toggles aim + fire.
-- H flips head/chest. One player snapshot at 10 Hz; per-frame work is projection.
-- The panel is OverlayUI, Blood Flow edition: engine-tweened background,
-- pooled lists, dirty writes only, no per-frame layout.

-- ── BOOT BEACON ───────────────────────────────────────────────────────────
-- A load that dies silently is the one failure nobody can diagnose: nothing
-- on screen, nothing in the console, no way to tell "the executor blocked the
-- download" from "crashed at line 3000". Every stage says its name once, and
-- the trail is readable later on GENV.Finifugal.boot.
local BOOT = {}
local function beacon(stage, loud)
	local s = tostring(stage)
	BOOT[#BOOT + 1] = s
	pcall(function() print("[Finifugal] " .. s) end)
	if loud then
		pcall(function()
			-- Matcha's notify is (message, title, duration) and a bare message
			-- leaves the title nil there. Three args are harmless elsewhere.
			if type(notify) == "function" then
				notify("[Finifugal] " .. s, "Finifugal", 4)
			end
		end)
	end
end

beacon("boot", true)

local Config = {
	esp = {
		enabled = true,
		toggleKey = Enum.KeyCode.RightShift,
		range = 600, -- studs: ESP box and wallhack both stop here
		-- off: Criminality puts most of the server on one team, and a team
		-- filter then hides every player the cheat was bought to see.
		teamCheck = false,
		box = true,
		name = true,
		health = true,
		distance = true,
		tracer = true,
		headDot = true,
		boxThickness = 1,
		textSize = 14,
		visibleColor = Color3.fromRGB(0, 255, 120),
		hiddenColor = Color3.fromRGB(255, 70, 70),
		chams = true,
		chamsFill = Color3.fromRGB(255, 50, 50),
		chamsOutline = Color3.fromRGB(255, 255, 255),
		chamsTransparency = 0.55,
		items = true,
		itemMax = 4,
		hotkeys = {
			[Enum.KeyCode.T] = "distance",
			[Enum.KeyCode.Y] = "chams",
			[Enum.KeyCode.U] = "box",
			[Enum.KeyCode.I] = "items",
			[Enum.KeyCode.O] = "tracer",
			[Enum.KeyCode.P] = "name",
		},
	},
	aim = {
		enabled = true,
		toggleKey = Enum.KeyCode.K,
		fov = 160, -- pixels, measured from the crosshair
		-- "soft" is aim assist: the crosshair slews onto the target at a capped
		-- speed, decelerates near it, and wanders a few pixels. "snap" is the
		-- old near-instant lock.
		style = "soft",
		maxSpeed = 2400, -- soft cursor: pixels per second at the top of the ramp
		softDrift = 6, -- soft: pixels the aim point wanders off the hitbox
		softZone = 120, -- soft: inside this gap the slew tapers down
		softMin = 0.15, -- soft: taper floor, so the last pixels still close
		smoothness = 0.3, -- camera fallback only
		gain = 0.9, -- snap cursor: fraction of the gap closed per frame
		maxStep = 240, -- snap cursor: pixel cap per frame
		deadzone = 0.5, -- cursor: stop inside this many pixels
		range = 260, -- studs. nothing past this gets locked, no matter the FOV
		teamCheck = false,
		-- "head" | "chest". H flips it live; the menu row shows which is on.
		hitbox = "head",
		hitboxKey = Enum.KeyCode.H,
		-- Part randomizer: instead of one fixed hitbox, every hold window
		-- re-rolls which body part the lock sits on, weighted by these
		-- percentages. Jitter scatters the point inside the part so no two
		-- bursts land on the same stud.
		randomizer = false,
		rnd = { head = 45, chest = 30, arm = 15, leg = 10 },
		rndHold = 0.35, -- seconds a rolled part stays before re-rolling
		rndJitter = 0.25, -- studs of scatter inside the part
		-- usernames the aim never locks. lower-case, exact match.
		ignoreNames = {
			["fleetingapril"] = true,
			["valentinolaus"] = true,
			["koyomibot"] = true,
		},
		-- runtime exclusion list. the menu writes here and saves it to
		-- excludePath when the executor has file access. lower-case keys.
		exclude = {},
		excludePath = "CriminalityOD/exclusions.json",
		visibleOnly = false,
		partOffset = Vector3.new(0, 0, 0), -- studs added to the hitbox point
		mode = "auto", -- "auto" | "cursor" | "camera"
		prediction = 0.08, -- seconds of velocity lead; 160 ms ping wants ~0.08
		-- Read the lead off GetPingValue instead of the slider. Matcha exposes
		-- it; where the function is missing the slider stays the source.
		autoLead = true,
		showFov = true,
		fireSnap = true, -- snap style only: trigger down, the gap closes now
		debug = false,
	},
	combat = {
		enabled = true,
		autoShoot = true,
		holdFire = true, -- true: hold LMB (auto guns); false: click every fireRate
		fireRate = 0.08,
		requireLOS = true,
		triggerDelay = 0.06,
		alignPx = 8, -- start firing inside this many pixels; 0 disables
		releasePx = 20, -- keep firing while the head is inside this; kills stutter
		recoilControl = true,
		recoilAlpha = 0.8,
	},
	poi = {
		enabled = true,
		debug = false,
		maxDistance = 4000,
		maxMarkers = 30,
		refresh = 12, -- seconds between full walks
		slice = 250, -- instances walked per frame
		maxNodes = 80000, -- hard ceiling on a walk
		maxFound = 400, -- loot pieces kept; spots are never capped by this
		maxNames = 400, -- how many distinct names the picker keeps
		loot = true, -- show clustered dropped tools
		clusterRadius = 18, -- studs: loot inside this radius is one spot
		clusterMin = 3, -- loot pieces needed to call it a pile
		textSize = 12,
		color = Color3.fromRGB(255, 220, 80), -- armory
		dealerColor = Color3.fromRGB(255, 140, 60), -- dealer / vendor
		lootColor = Color3.fromRGB(200, 200, 200), -- dropped tools
		-- name -> true. The menu writes here; first sight seeds it from the
		-- keyword list below so the map is not blank on the first load.
		show = {},
		keywords = {
			"armory", "armoury", "armor", "arsenal",
			"gunshop", "gun shop", "gunsmith", "gunstore", "gun store",
			"weaponshop", "weapon shop", "weapon", "ammo", "ammunition",
			"dealer", "vendor", "merchant", "blackmarket", "black market",
			"bandit", "shop", "store",
		},
		armoryKeys = {
			"armory", "armoury", "armor", "arsenal",
			"gunshop", "gun shop", "gunsmith", "gunstore", "gun store",
			"weaponshop", "weapon shop", "weapon", "ammo", "ammunition",
		},
		dealerKeys = {
			"dealer", "vendor", "merchant", "blackmarket", "black market",
			"bandit", "shop", "store",
		},
		-- anything whose name contains one of these never reaches the picker
		ignore = { "spawn", "respawn", "checkpoint", "barrier" },
		custom = {}, -- { { name = "Spot", position = Vector3.new(0, 0, 0) }, ... }
	},
	ui = {
		enabled = true,
		-- Ñ sits on the Semicolon key in Roblox's US-layout key table.
		key = Enum.KeyCode.Semicolon,
	},
	key = {
		enabled = true,
		-- "local": the baked hash below is the whole check, nothing to host.
		-- "remote": the status document decides, and can kill the copy live.
		provider = "remote",
		-- FILL: paste the status URL here to arm the kill switch.
		--   "https://your.host/status"  or a gist raw URL
		-- Empty = the hash below decides and nothing can be revoked.
		list = "https://raw.githubusercontent.com/elclubdelahorro/Finifugal/main/status.json",
		-- POST checker, only used when `list` is empty and this is set.
		endpoint = "",
		-- Document shape, nothing else is required:
		--   {"kill": false, "reason": "", "keys": ["avestfriend"]}
		poll = 30, -- seconds between live checks while running
		strict = true, -- true: no status document = no start. the plug.
		-- Append ?t=<clock> to the status URL. Measured on GitHub: the raw CDN
		-- ignores the query and serves an edge copy for up to five minutes
		-- (Cache-Control: max-age=300), so this does not make a commit land
		-- faster there. It is kept because a proxy that does key on the query
		-- is the difference between a stale read and a fresh one, and it costs
		-- one string concat. Instant kills are the Worker's job, not raw's.
		bust = true,
		-- hash of "avestfriend" against salt "finifugal-2.0".
		-- rebake with Finifugal.bake("your-key") and paste the result here.
		hash = "95ea8b09a3b5f8c2",
		salt = "finifugal-2.0",
		path = "CriminalityOD/key.txt",
		ttl = 43200, -- seconds a remote key stays cached, 12 h
	},
	render = {
		-- nil = auto-detect. 0 = standard (0 is solid), 1 = Xeno-style (1 is solid).
		opaque = nil,
	},
	perf = {
		-- Frame meter: EMA and peak of the render callback, printed every
		-- few seconds and shown in the panel. Off costs nothing.
		meter = false,
		poiHz = 30, -- marker projection rate; the walk itself stays time-budgeted
		report = 3, -- seconds between console reports while the meter is on
	},
}

-- Some executors read Drawing.Transparency as opacity: 0 means invisible.
-- Detect it once and map every value through the same helper.
local function solidValue()
	if Config.render.opaque ~= nil then return Config.render.opaque end
	local name = ""
	pcall(function()
		if type(identifyexecutor) == "function" then
			name = tostring(identifyexecutor())
		elseif type(getexecutorname) == "function" then
			name = tostring(getexecutorname())
		end
	end)
	if string.find(string.lower(name), "xeno", 1, true) then return 1 end
	return 0
end

local SOLID = solidValue()

-- t is true transparency: 0 = solid, 1 = clear. The override is read on
-- every call so a wrong auto-detect can be fixed from the menu or console
-- without re-executing the script.
local function alpha(t)
	local solid = Config.render.opaque
	if solid == nil then solid = SOLID end
	if solid == 1 then return 1 - t end
	return t
end

-- Matcha does not ship getgenv; _G is the shared table there. One handle, so
-- every publish and every read goes through the same place on both.
local GENV = (type(getgenv) == "function" and getgenv()) or _G

-- Re-executing in the same session would otherwise leave the old ESP floating.
local prev = GENV and GENV.CriminalityOD
if prev and type(prev.unload) == "function" then
	pcall(prev.unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Harness and some executors do not expose HttpService. Every use is guarded.
local HttpService
pcall(function() HttpService = game:GetService("HttpService") end)

local LocalPlayer = Players.LocalPlayer

-- ══ CAPS ══════════════════════════════════════════════════════════════════
-- Probed once, at load. Matcha and the mobile executors ship a subset of the
-- desktop API. Testing a function inside a render callback is a nil-index
-- every frame; testing it once here is free.
local CAPS = (function()
	local c = { name = "unknown" }
	pcall(function()
		if type(identifyexecutor) == "function" then
			c.name = tostring(identifyexecutor())
		elseif type(getexecutorname) == "function" then
			c.name = tostring(getexecutorname())
		end
	end)
	c.moverel = type(mousemoverel) == "function"
	c.moveabs = type(mousemoveabs) == "function"
	c.clipboard = type(setclipboard) == "function"
	c.fs = type(readfile) == "function" and type(writefile) == "function"
	c.hui = type(gethui) == "function"
	c.genv = type(getgenv) == "function"
	c.task = type(task) == "table" and type(task.spawn) == "function"
	c.touch = false
	pcall(function() c.touch = UserInputService.TouchEnabled == true end)
	c.drawing = Drawing ~= nil
	c.matcha = string.find(string.lower(c.name), "matcha", 1, true) ~= nil
	return c
end)()

-- Matcha is an external VM: it does not hook the engine, so Instance.new does
-- not exist. Every frame the panel is made of is impossible there. The native
-- library is the only menu: UI.AddTab builds widgets Matcha draws itself.
local MATCHA_UI = type(UI) == "table" and type(UI.AddTab) == "function"
if MATCHA_UI then
	CAPS.matcha = true
	-- Highlight is an engine object and Matcha has no Instance.new, so the
	-- wallhack has nothing to attach. Off here beats a menu row that lies.
	Config.esp.chams = false
end

beacon(string.format("caps: %s matcha=%s drawing=%s inst=%s",
	CAPS.name, tostring(MATCHA_UI), tostring(CAPS.drawing),
	tostring(type(Instance) == "table" and type(Instance.new) == "function")))

-- ── CLOCK ──────────────────────────────────────────────────────────────────
-- Matcha documents tick() as its monotonic clock and does not document `os`
-- at all; os.clock in that VM is process CPU time, so every "0.1 s has passed"
-- test built on it stalls the moment the frame loop goes quiet — ESP stops
-- refreshing, the POI walk never advances, the fire gap never opens. Pick the
-- clock once, at load, and every delta in this file reads from it.
local clock = (function()
	if CAPS.matcha and type(tick) == "function" then
		local ok, v = pcall(tick)
		-- Matcha's tick is monotonic, Roblox's is Unix seconds. Every use in
		-- this file is a difference, so either origin works.
		if ok and type(v) == "number" then return tick end
	end
	if type(os) == "table" and type(os.clock) == "function" then return os.clock end
	return function() return 0 end
end)()

-- Wall clock for the key cache only. Matcha does not document `os` at all, so
-- a missing clock must read as "no expiry", never as an index on nil in the
-- middle of a key check.
local function wallclock()
	if type(os) == "table" and type(os.time) == "function" then
		local ok, v = pcall(os.time)
		if ok and type(v) == "number" then return v end
	end
	return 0
end

-- DRAWING FALLBACK ----------------------------------------------------------
-- No Drawing library means the ESP has nowhere to go. The cheat draws eight
-- primitives per player, and a ScreenGui can serve all eight: frames for the
-- box and health bar, a rotated frame for the tracer, a rounded frame for the
-- dot, labels for the text. Objects are pooled by class, so a player leaving
-- and rejoining recycles instances instead of building new ones.
local function drawingShim()
	local holder
	local ok, pg = pcall(function()
		return Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	if not (ok and pg) then
		pcall(function() pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5) end)
	end
	if pg then
		holder = Instance.new("Frame")
		holder.Name = "ODDraw"
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1, 0, 1, 0)
		holder.ZIndex = 1
		holder.Parent = pg
	end

	local free = { Square = {}, Text = {}, Line = {}, Circle = {} }
	-- 60 players x 8 primitives + 30 markers x 2 + the FOV ring and marker.
	local live, MAX = 0, 640
	-- A custom field on a Frame raises on a real client ("not a valid
	-- member"), so the stroke reference lives in a weak side table.
	local strokes = setmetatable({}, { __mode = "k" })

	-- math.atan2 is gone in Luau and the two-argument math.atan is not
	-- portable either. Quadrant maths costs nothing and always exists.
	local function atan2(y, x)
		if x > 0 then return math.atan(y / x) end
		if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
		if y > 0 then return math.pi * 0.5 end
		if y < 0 then return -math.pi * 0.5 end
		return 0
	end

	local function acquire(class)
		local pool = free[class]
		local n = #pool
		if n > 0 then
			local inst = pool[n]
			pool[n] = nil
			inst.Visible = false
			return inst
		end
		assert(live < MAX, "OD drawing shim: object cap")
		live = live + 1

		local inst
		if class == "Text" then
			inst = Instance.new("TextLabel")
			inst.BackgroundTransparency = 1
			inst.BorderSizePixel = 0
			inst.Font = Enum.Font.GothamBold
			inst.TextXAlignment = Enum.TextXAlignment.Center
			inst.TextYAlignment = Enum.TextYAlignment.Center
			inst.ZIndex = 4
		else
			inst = Instance.new("Frame")
			inst.BorderSizePixel = 0
			inst.ZIndex = (class == "Line") and 2 or 3
			if class == "Circle" then
				inst.ClipsDescendants = true
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = inst
			end
			local s = Instance.new("UIStroke")
			s.Thickness = 1
			s.Transparency = 1
			s.Parent = inst
			strokes[inst] = s
		end
		inst.Visible = false
		inst.Parent = holder
		return inst
	end

	local apply = {}

	function apply.Square(v)
		local inst = v.inst
		inst.Position = UDim2.fromOffset(v.x or 0, v.y or 0)
		inst.Size = UDim2.fromOffset(v.w or 0, v.h or 0)
		inst.BackgroundColor3 = v.color or Color3.new(1, 1, 1)
		if v.filled then
			inst.BackgroundTransparency = v.t or 0
			local s = strokes[inst]
			if s then s.Transparency = 1 end
		else
			inst.BackgroundTransparency = 1
			local s = strokes[inst]
			if s then
				s.Transparency = v.t or 0
				s.Thickness = math.max(v.thickness or 1, 1)
				s.Color = v.color or Color3.new(1, 1, 1)
			end
		end
		inst.Visible = v.visible and true or false
	end

	function apply.Text(v)
		local inst = v.inst
		local size = math.clamp(v.size or 14, 6, 48)
		inst.Position = UDim2.fromOffset(v.x or 0, v.y or 0)
		inst.TextSize = size
		inst.TextColor3 = v.color or Color3.new(1, 1, 1)
		inst.TextTransparency = v.t or 0
		inst.Text = v.text or ""
		inst.TextXAlignment = v.center and Enum.TextXAlignment.Center
			or Enum.TextXAlignment.Left
		-- Drawing anchors text at its top-left; Center only moves the x.
		inst.AnchorPoint = v.center and Vector2.new(.5, 0) or Vector2.new(0, 0)
		inst.Size = UDim2.fromOffset(220, size + 4)
		local s = strokes[inst]
		if s then
			s.Transparency = v.outline and (v.t or 0) or 1
			s.Thickness = 1
			s.Color = v.outlineColor or Color3.new(0, 0, 0)
		end
		inst.Visible = v.visible and true or false
	end

	function apply.Line(v)
		local inst = v.inst
		local ax, ay = v.fx or 0, v.fy or 0
		local bx, by = v.tx or 0, v.ty or 0
		local dx, dy = bx - ax, by - ay
		local len = math.sqrt(dx * dx + dy * dy)
		inst.AnchorPoint = Vector2.new(.5, .5)
		inst.Position = UDim2.fromOffset((ax + bx) * .5, (ay + by) * .5)
		inst.Size = UDim2.fromOffset(len, math.max(v.thickness or 1, 1))
		inst.Rotation = math.deg(atan2(dy, dx))
		inst.BackgroundColor3 = v.color or Color3.new(1, 1, 1)
		inst.BackgroundTransparency = v.t or 0
		inst.Visible = v.visible and true or false
	end

	function apply.Circle(v)
		local inst = v.inst
		local r = math.max(v.radius or 1, 1)
		inst.AnchorPoint = Vector2.new(.5, .5)
		inst.Position = UDim2.fromOffset(v.x or 0, v.y or 0)
		inst.Size = UDim2.fromOffset(r * 2, r * 2)
		inst.BackgroundColor3 = v.color or Color3.new(1, 1, 1)
		inst.BackgroundTransparency = v.filled and (v.t or 0) or 1
		local s = strokes[inst]
		if s then
			s.Color = v.color or Color3.new(1, 1, 1)
			s.Thickness = math.max(v.thickness or 1, 1)
			s.Transparency = v.filled and 1 or (v.t or 0)
		end
		inst.Visible = v.visible and true or false
	end

	local methods = {}

	function methods:Remove()
		local v = self.v
		if v.dead then return end
		v.dead = true
		v.visible = false
		v.inst.Visible = false
		local pool = free[self.cls]
		pool[#pool + 1] = v.inst
	end

	local function setter(self, key, value)
		local v = self.v
		if v.dead then return end
		if key == "Position" then
			v.x, v.y = value.X, value.Y
		elseif key == "Size" then
			if self.cls == "Text" then
				v.size = tonumber(value) or v.size
			elseif type(value) == "table" or type(value) == "userdata" then
				v.w, v.h = value.X, value.Y
			end
		elseif key == "Color" then
			v.color = value
		elseif key == "Transparency" then
			v.t = value
		elseif key == "Visible" then
			v.visible = value
		elseif key == "Filled" then
			v.filled = value
		elseif key == "Thickness" then
			v.thickness = value
		elseif key == "Center" then
			v.center = value
		elseif key == "Outline" then
			v.outline = value
		elseif key == "OutlineColor" then
			v.outlineColor = value
		elseif key == "Radius" then
			v.radius = value
		elseif key == "From" then
			v.fx, v.fy = value.X, value.Y
		elseif key == "To" then
			v.tx, v.ty = value.X, value.Y
		elseif key == "Text" then
			v.text = tostring(value)
		else
			v[key] = value
		end
		apply[self.cls](v)
	end

	local Object = {}
	Object.__index = function(self, key)
		local m = methods[key]
		if m then return m end
		return self.v[key]
	end
	Object.__newindex = setter

	local shim = {}

	function shim.new(class)
		class = class or "Square"
		if not apply[class] then class = "Square" end
		local inst = acquire(class)
		local v = { inst = inst }
		local self = setmetatable({ cls = class, v = v }, Object)
		local defaults = {
			Square = { w = 0, h = 0, thickness = 1 },
			Text = { size = 14, center = false },
			Line = { thickness = 1 },
			Circle = { radius = 1, thickness = 1 },
		}
		local d = defaults[class]
		for k, val in pairs(d) do v[k] = val end
		v.t = 0
		v.visible = false
		apply[class](v)
		return self
	end

	return shim
end

local Drawing = Drawing or drawingShim()

-- Counters for the frame meter: how many projections ran, how many were
-- skipped because nothing moved. The second number is the optimisation.
local stats = { projections = 0, reused = 0 }

-- Some executors inject mousemoverel after the script starts, so a load-time
-- probe cannot be trusted. Probing until it appears costs one global lookup
-- per frame, which is what the old inline test did anyway; once it is there,
-- the answer is cached and the hot loop pays nothing.
local moverelOn = false
local function hasMoverel()
	if moverelOn then return true end
	moverelOn = type(mousemoverel) == "function"
	return moverelOn
end

if CAPS.genv or GENV then
	GENV.Finifugal = { caps = CAPS, drawingShim = drawingShim, boot = BOOT }
end

local function camera()
	return Workspace.CurrentCamera
end

-- Matcha emulates the engine externally and its Camera has no
-- WorldToViewportPoint. Project by hand from CFrame + FOV instead: that is the
-- same pinhole the engine uses, and unlike the global WorldToScreen it still
-- returns coordinates for points just outside the viewport, so boxes clip at
-- the edge instead of vanishing. The camera snapshot is cached for 4 ms; a
-- projection must not be one bridge read per drawing.
local camAt, camCF, camVP, camFov = -1e9, nil, nil, 70
local function camSnap(cam)
	local now = clock()
	if now - camAt < 0.004 and camCF then return camCF, camVP, camFov end
	camAt = now
	pcall(function()
		camCF = cam.CFrame
		camVP = cam.ViewportSize
		camFov = cam.FieldOfView
	end)
	return camCF, camVP, camFov
end

local viewPoint
if CAPS.matcha then
	viewPoint = function(cam, p)
		if not cam then return nil end
		local cf, vp, fov = camSnap(cam)
		if cf and vp then
			local rel
			local ok = pcall(function() rel = cf:PointToObjectSpace(p) end)
			if ok and rel and rel.Z < -1e-3 then
				local z = -rel.Z
				local focal = (vp.Y * 0.5) / math.tan(math.rad(fov or 70) * 0.5)
				return { X = vp.X * 0.5 + rel.X / z * focal,
					Y = vp.Y * 0.5 - rel.Y / z * focal, Z = z }
			end
			if ok and rel then return nil end
		end
		if type(WorldToScreen) == "function" then
			local sp, on = WorldToScreen(p)
			if not sp then return nil end
			return { X = sp.X, Y = sp.Y, Z = on and 1 or -1 }
		end
		return nil
	end
else
	viewPoint = function(cam, p)
		if not cam then return nil end
		return cam:WorldToViewportPoint(p)
	end
end

-- Criminality aims with the cursor, not the camera centre. LockCenter pins
-- the cursor to the middle, so there the centre is the crosshair; anywhere
-- else the crosshair is wherever the player's cursor sits.
-- One stamp per rendered frame: the cursor origin and the local team are
-- bridge reads, and every subsystem in a frame wants the same answer.
local frameStamp = 0
local originCache, originStamp = nil, -1
local teamCache, teamStamp = nil, -1

local function aimOrigin()
	if originStamp == frameStamp and originCache then
		return originCache
	end
	local cam = camera()
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local result = center
	local lockCenter = Enum.MouseBehavior and Enum.MouseBehavior.LockCenter
	-- Matcha has neither Enum.MouseBehavior nor GetMouseLocation; its Mouse
	-- class does carry X/Y, so the cursor still resolves over there.
	if lockCenter == nil or UserInputService.MouseBehavior ~= lockCenter then
		local got, p = pcall(function() return UserInputService:GetMouseLocation() end)
		if not (got and p) then
			local okm, m = pcall(function() return LocalPlayer:GetMouse() end)
			if okm and m then got, p = true, { X = m.X, Y = m.Y } end
		end
		if got and p then
			result = Vector2.new(p.X, p.Y)
		end
	end
	originStamp = frameStamp
	originCache = result
	return result
end

local function localTeam()
	if teamStamp == frameStamp then return teamCache end
	teamStamp = frameStamp
	teamCache = LocalPlayer.Team
	return teamCache
end

local function onSameTeam(plr)
	local lt = localTeam()
	return lt ~= nil and plr.Team ~= nil and plr.Team == lt
end

-- ══ EXCLUSIONS ═════════════════════════════════════════════════════════════
-- A name on this list is never a target. The menu owns the list; this block
-- normalises, loads, saves, and answers the lookup. lower-case keys only.
local excludeVersion = 0

local function normName(name)
	local s = tostring(name or "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return string.lower(s)
end

local function exclusionCount()
	local n = 0
	for _ in pairs(Config.aim.exclude) do n = n + 1 end
	return n
end

local function saveExclusions()
	if type(writefile) ~= "function" then return false end
	local list = {}
	for name in pairs(Config.aim.exclude) do list[#list + 1] = name end
	table.sort(list)

	local payload
	if HttpService and type(HttpService.JSONEncode) == "function" then
		local ok, encoded = pcall(function() return HttpService:JSONEncode(list) end)
		if ok and type(encoded) == "string" then payload = encoded end
	end
	if payload == nil then
		local quoted = {}
		for i, name in ipairs(list) do quoted[i] = string.format("%q", name) end
		payload = "[" .. table.concat(quoted, ",") .. "]"
	end

	return pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function"
			and not isfolder("CriminalityOD") then
			makefolder("CriminalityOD")
		end
		writefile(Config.aim.excludePath, payload)
	end)
end

local function loadExclusions()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then return 0 end
	local ok, raw = pcall(function()
		if not isfile(Config.aim.excludePath) then return nil end
		return readfile(Config.aim.excludePath)
	end)
	if not ok or type(raw) ~= "string" or raw == "" then return 0 end

	local decoded
	if HttpService and type(HttpService.JSONDecode) == "function" then
		local okd, d = pcall(function() return HttpService:JSONDecode(raw) end)
		if okd then decoded = d end
	end
	if type(decoded) ~= "table" then return 0 end

	local added = 0
	for key, value in pairs(decoded) do
		local name = nil
		if type(key) == "number" and type(value) == "string" then
			name = value
		elseif type(key) == "string" and value == true then
			name = key
		end
		if name then
			name = normName(name)
			if name ~= "" then
				Config.aim.exclude[name] = true
				added = added + 1
			end
		end
	end
	if added > 0 then excludeVersion = excludeVersion + 1 end
	return added
end

local function addExclusion(name)
	name = normName(name)
	if name == "" then return false end
	Config.aim.exclude[name] = true
	excludeVersion = excludeVersion + 1
	saveExclusions()
	return true
end

local function removeExclusion(name)
	name = normName(name)
	if Config.aim.exclude[name] == nil then return false end
	Config.aim.exclude[name] = nil
	excludeVersion = excludeVersion + 1
	saveExclusions()
	return true
end

local function exclusionList()
	local names = {}
	for name in pairs(Config.aim.exclude) do names[#names + 1] = name end
	table.sort(names)
	return names
end

loadExclusions()

-- ══ CFG ═══════════════════════════════════════════════════════════════════
-- The build's settings in the Crim cfg vocabulary: one flat JSON object, 170
-- keys, the shape the other menu reads. Every key this cheat has an opinion on
-- is written from Config. Every key it has no opinion on — desync, freecam,
-- silent aim, the resolver — is carried from the base below untouched, so
-- loading the file never silently resets a setting this cheat does not own.
local CFG_PATH = "CriminalityOD/crim.cfg"

local CFG_BASE = {
	accent_color = "[1.0,0.4117647111415863,0.25882354378700256,1.0]",
	aimbot = true,
	aimbot_hitpart = "0",
	aimbot_range = "342",
	aimbot_wallcheck = false,
	aimkey = "18",
	aimkeymethod = "0",
	aimtype = "1",
	aimview = false,
	allow_unsafe_execution = false,
	ambience = false,
	ambience_color = "[1.0,1.0,1.0,1.0]",
	armorbar = false,
	blur_background = false,
	box = true,
	box_color = "[1.0,1.0,1.0,1.0]",
	boxtype = "0",
	brightness = false,
	brightness_glowy = false,
	brightness_value = "2.0",
	chams = false,
	chams_color = "[1.0,1.0,1.0,0.4000000059604645]",
	chams_filled = true,
	chams_outline = false,
	chams_outline_color = "[1.0,1.0,1.0,1.0]",
	chams_type = "2",
	change_fps = false,
	circle_color = "[1.0,1.0,1.0,1.0]",
	clicktp = false,
	clicktpbindkey = "17",
	clicktpbindmethod = "1",
	damage_reticles = true,
	darken_background = false,
	deadzone_color = "[1.0,1.0,1.0,1.0]",
	deadzone_fill_color = "[1.0,1.0,1.0,1.0]",
	desync = false,
	desync_interval = "10",
	desynckey = "5",
	desyncmethod = "0",
	display_circle = false,
	distance_esp = true,
	enable_raycast = false,
	esp = true,
	esp_notvisible_color = "[1.0,0.0,0.0,1.0]",
	esp_visible_color = "[0.6313725709915161,0.7843137383460999,1.0,1.0]",
	esp_wallcheck = false,
	exposure = false,
	exposure_value = "2.0",
	fill_color = "[1.0,1.0,1.0,0.07500000298023224]",
	filledbox = false,
	fly = false,
	fly_amount = "1",
	flybind = "70",
	flybindmethod = "0",
	flymethod = "0",
	fog = false,
	fog_color = "[1.0,1.0,1.0,1.0]",
	fog_glow = false,
	fog_value = "0.5",
	follow_target = false,
	fontstyle = "0",
	fov = "100",
	fov_color = "[1.0,1.0,1.0,1.0]",
	fov_fill_color = "[1.0,1.0,1.0,0.07500000298023224]",
	fov_filled = false,
	fps_to_set = "240",
	freecam = false,
	freecam_speed = "1.5",
	freecamkey = "76",
	freecamtype = "0",
	gradient_text = true,
	head_dot = false,
	head_dot_color = "[1.0,1.0,1.0,1.0]",
	head_dot_glow = false,
	health_based_color = true,
	healthbar = true,
	healthbar_color = "[0.0,1.0,0.0,1.0]",
	healthcheck = false,
	hitbox_extend = false,
	hitbox_healthcheck = false,
	hitbox_size = "20",
	hitbox_teamcheck = false,
	infjump = false,
	keybind_list = true,
	lag_notifier = true,
	lock_character_position = false,
	main_prediction = "0.15000000596046448",
	menufontstyle = "1",
	menukey = "45",
	menukeymethod = "0",
	name_color = "[1.0,1.0,1.0,1.0]",
	name_esp = true,
	noclip = false,
	noclipkeynoclipbind = "90",
	noclipmethod = "0",
	outline = true,
	performance = "2",
	prediction = true,
	prediction_x = "17.49519920349121",
	prediction_y = "17.49519920349121",
	profile_esp = false,
	radar = true,
	rapidfire = false,
	raycast_update = "2500",
	raycastragebot = false,
	render_distance = "426",
	reset_on_desync_off = false,
	resolver = true,
	self_esp = false,
	sensitivity = "1.100000023841858",
	show_only_visible = false,
	show_server_position = false,
	silent_aim = false,
	silent_fov = "100",
	silent_fov_color = "[1.0,1.0,1.0,1.0]",
	silent_fov_fill_color = "[1.0,1.0,1.0,0.07500000298023224]",
	silent_fov_on = false,
	silent_healthcheck = false,
	silent_hitpart = "0",
	silent_prediction = false,
	silent_prediction_x = "1.0",
	silent_prediction_y = "17.31599998474121",
	silent_smoothing = "0.0",
	silent_teamcheck = false,
	silent_wallcheck = false,
	silentkey = "69",
	silentkeymethod = "2",
	sizing_type = "1",
	skeleton = false,
	skeleton_color = "[1.0,1.0,1.0,1.0]",
	smoothness = true,
	smoothness_x = "2.5",
	smoothness_y = "2.5",
	snow = false,
	speed = false,
	speed_amount = "1",
	speedbind = "86",
	speedbindmethod = "0",
	speedmethod = "0",
	streamproof = false,
	target_strafe = false,
	targethud = true,
	targetmethod = "0",
	targetstrafedistance = "10.0",
	targetstrafekey = "88",
	targetstrafekeymethod = "0",
	targetstrafespeed = "5.0",
	team_based_color = false,
	team_check = false,
	team_check_esp = false,
	team_flag = false,
	teleporttofreecam = false,
	teleporttofreecamkey = "78",
	teleporttofreecammethod = "3",
	tool = true,
	tracers = false,
	tracers_color = "[1.0,1.0,1.0,1.0]",
	tracertype = "0",
	trigger_bot_hitboxmul = "1.0",
	triggerbot = false,
	triggerbot_delay_ms = "1",
	triggerbot_release_delay_ms = "10",
	triggerbot_teamcheck = false,
	triggerbot_visualizehitbox = false,
	triggerbot_wallcheck = false,
	triggerbotkeybind = "81",
	triggerbotkeymethod = "0",
	use_tick = false,
	usefov = true,
	vsync = true,
}

-- The cfg speaks Windows virtual-key codes; the build speaks Enum.KeyCode.
-- The crossing lives here and nowhere else. Enum.KeyCode is a subset on some
-- VMs, so every bind is probed instead of indexed.
local CFG_VK = {}
local function bindVK(name, vk)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	if ok and k ~= nil then CFG_VK[k] = vk end
end
bindVK("K", 0x4B)
bindVK("H", 0x48)
bindVK("T", 0x54)
bindVK("Y", 0x59)
bindVK("U", 0x55)
bindVK("I", 0x49)
bindVK("O", 0x4F)
bindVK("P", 0x50)
bindVK("Semicolon", 0xBA)
bindVK("RightShift", 0xA1)

local function cfgVK(k, fallback)
	if k ~= nil and CFG_VK[k] ~= nil then return CFG_VK[k] end
	return fallback
end

local function cfgColor(c, a)
	if type(c) ~= "userdata" and type(c) ~= "table" then return nil end
	return { c.R, c.G, c.B, a or 1 }
end

-- Config, expressed in the cfg's vocabulary. Anything missing from this list
-- is a key the build does not have an opinion on and stays at its base value.
local function cfgValues()
	local t = {}
	for k, v in pairs(CFG_BASE) do t[k] = v end

	local e, a, c = Config.esp, Config.aim, Config.combat

	t.esp = e.enabled
	t.box = e.box
	t.name_esp = e.name
	t.healthbar = e.health
	t.distance_esp = e.distance
	t.tracers = e.tracer
	t.head_dot = e.headDot
	t.chams = e.chams
	t.filledbox = false
	t.render_distance = e.range
	t.team_check_esp = e.teamCheck

	local vis = cfgColor(e.visibleColor, 1)
	local hid = cfgColor(e.hiddenColor, 1)
	if vis then
		t.esp_visible_color = vis
		t.box_color = vis
		t.tracers_color = vis
		t.head_dot_color = vis
		t.fov_color = vis
	end
	if hid then t.esp_notvisible_color = hid end
	local fill = cfgColor(e.chamsFill, 1 - (e.chamsTransparency or 0))
	if fill then t.chams_color = fill end
	local outl = cfgColor(e.chamsOutline, 1)
	if outl then t.chams_outline_color = outl end

	t.aimbot = a.enabled
	t.aimbot_hitpart = (a.hitbox == "head") and 0.0 or 1.0
	t.aimbot_range = a.range
	t.aimbot_wallcheck = a.visibleOnly
	t.aimkey = cfgVK(a.toggleKey, t.aimkey)
	t.fov = a.fov
	t.usefov = a.showFov
	t.main_prediction = a.prediction
	t.prediction = a.autoLead
	t.show_only_visible = a.visibleOnly
	t.team_check = a.teamCheck
	t.menukey = cfgVK(Config.ui.key, t.menukey)

	-- Triggerbot is the closest thing this cfg has to auto-fire: it pulls the
	-- trigger when the target is under the crosshair, which is what alignPx
	-- gates here. The release delay has no counterpart and keeps its base.
	t.triggerbot = c.autoShoot
	t.triggerbot_delay_ms = math.floor(c.triggerDelay * 1000 + 0.5)
	t.triggerbot_wallcheck = c.requireLOS
	t.triggerbot_teamcheck = a.teamCheck

	return t
end

-- Deterministic JSON. Keys sorted, so the same Config always writes the same
-- bytes. Floats at 15 significant digits: 17 exposes the float64 artefact
-- (1 - 0.55 prints as 0.44999999999999996) and a colour does not need it.
local function cfgNum(n)
	n = tonumber(n) or 0
	if n ~= n or n == math.huge or n == -math.huge then return "0.0" end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%.1f", n)
	end
	return string.format("%.15g", n)
end

local function cfgEncode(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for i = 1, #keys do
		local k = keys[i]
		local v = t[k]
		local enc
		if type(v) == "boolean" then
			enc = v and "true" or "false"
		elseif type(v) == "number" then
			enc = cfgNum(v)
		elseif type(v) == "table" then
			local xs = {}
			for j = 1, #v do xs[j] = cfgNum(v[j]) end
			enc = "[" .. table.concat(xs, ",") .. "]"
		else
			-- A string in this table is a raw JSON fragment carried from the
			-- base file: a key this cheat does not own, passed through
			-- byte-for-byte instead of re-formatted and nudged.
			enc = tostring(v)
		end
		parts[#parts + 1] = '"' .. k .. '":' .. enc
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function cfgText()
	return cfgEncode(cfgValues())
end

local function cfgSave()
	if type(writefile) ~= "function" then return false, "no file access" end
	local ok, err = pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function"
			and not isfolder("CriminalityOD") then
			makefolder("CriminalityOD")
		end
		writefile(CFG_PATH, cfgText())
	end)
	return ok, err
end

local function cfgCount()
	local n = 0
	for _ in pairs(cfgValues()) do n = n + 1 end
	return n
end
-- Hard skip: a named player is never a target, team or not.
local function aimIgnored(plr)
	local name = type(plr.Name) == "string" and string.lower(plr.Name) or nil
	if name ~= nil then
		if Config.aim.ignoreNames[name] then return true end
		if Config.aim.exclude[name] then return true end
	end
	-- DisplayName is not on every VM's Player; a missing read must not kill
	-- the sweep that fills the whole ESP.
	local display
	pcall(function() display = plr.DisplayName end)
	if type(display) == "string" and display ~= "" then
		display = string.lower(display)
		if Config.aim.exclude[display] then return true end
		if Config.aim.ignoreNames[display] then return true end
	end
	return false
end

-- RaycastParams is not in Matcha's documented surface. Build it only if it is
-- actually there: without a filter the ray hits the local character first and
-- every visibility test reports "blocked", so LOS gets switched off instead.
local rayParams
do
	local ok, rp = pcall(function() return RaycastParams.new() end)
	if ok and rp then
		rayParams = rp
		pcall(function() rayParams.IgnoreWater = true end)
		pcall(function()
			local ft = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist
			if ft ~= nil then rayParams.FilterType = ft end
		end)
	end
end
if not rayParams and CAPS.matcha then
	Config.combat.requireLOS = false
end

-- One reusable filter table: a fresh one per raycast per player per tick was
-- pure garbage. Raycast is synchronous, so the buffer is safe to share.
local filterBuf = {}

local function lineOfSight(plr, fromPos, toPos)
	local char = plr.Character
	filterBuf[1] = LocalPlayer.Character or char
	filterBuf[2] = char
	filterBuf[3] = nil
	local okr, hit
	if rayParams then
		pcall(function() rayParams.FilterDescendantsInstances = filterBuf end)
		okr, hit = pcall(function()
			return Workspace:Raycast(fromPos, toPos - fromPos, rayParams)
		end)
	else
		okr, hit = pcall(function()
			return Workspace:Raycast(fromPos, toPos - fromPos)
		end)
	end
	-- No ray support in this VM: clear beats a hard aim lockout.
	if not okr then return true end
	if not hit then return true end
	if char and hit.Instance:IsDescendantOf(char) then return true end
	return false
end

-- ══ PLAYER SNAPSHOT ════════════════════════════════════════════════════════
-- Every expensive lookup — Humanoid, root part, hitboxes, bounding box,
-- backpack — lives here on a slow tick. The render path only reads positions.
local partCache = setmetatable({}, { __mode = "k" })

local function safePart(part)
	if part ~= nil and part:IsA("BasePart") then return part end
	return nil
end

-- Custom rigs rename parts, so the direct child is tried first and the
-- descendant walk is the fallback. Both hitboxes resolve once per character.
local function resolveParts(char)
	local c = partCache[char]
	if c then return c end
	c = { head = nil, chest = nil, leftArm = nil, rightArm = nil,
		leftLeg = nil, rightLeg = nil }

	c.head = safePart(char:FindFirstChild("Head"))
	c.chest = safePart(char:FindFirstChild("UpperTorso")) or safePart(char:FindFirstChild("Torso"))

	-- One descendant walk fills everything still missing. R6 uses "Left Arm",
	-- R15 uses "LeftUpperArm"; both are matched by substring.
	if not (c.head and c.chest and c.leftArm and c.rightArm and c.leftLeg and c.rightLeg) then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				local n = d.Name:lower()

				if not c.head and string.find(n, "head", 1, true) then
					c.head = d
				elseif not c.chest and (string.find(n, "torso", 1, true)
					or string.find(n, "chest", 1, true)) then
					c.chest = d
				elseif not c.leftArm and string.find(n, "left", 1, true)
					and string.find(n, "arm", 1, true) then
					c.leftArm = d
				elseif not c.rightArm and string.find(n, "right", 1, true)
					and string.find(n, "arm", 1, true) then
					c.rightArm = d
				elseif not c.leftLeg and string.find(n, "left", 1, true)
					and string.find(n, "leg", 1, true) then
					c.leftLeg = d
				elseif not c.rightLeg and string.find(n, "right", 1, true)
					and string.find(n, "leg", 1, true) then
					c.rightLeg = d
				end
			end
		end
	end

	if not c.chest then
		c.chest = safePart(char:FindFirstChild("HumanoidRootPart")) or c.head
	end
	if not c.head then c.head = c.chest end

	partCache[char] = c
	return c
end

-- ESP drawing objects, one set per player, built lazily.
local esp = {}
-- A player turning on screen needs its text now, not at the next 10 Hz tick.
local espDirty = true

-- Declared before destroy() so one teardown path owns everything a player
-- left behind: the drawings, the Highlight, and the raycast verdict.
local vis = {}
local chamsOff

local function destroy(plr)
	-- Every leave path goes through here, including players that were never
	-- on screen (no esp entry) but still have a cached raycast and Highlight.
	vis[plr] = nil
	if chamsOff then chamsOff(plr) end

	local o = esp[plr]
	if not o then return end
	for _, d in pairs(o) do
		-- Real Drawing objects are userdata; the shim's are tables. Both have
		-- Remove, and a stale one must not abort the teardown of the rest.
		local kind = type(d)
		if (kind == "table" or kind == "userdata") and type(d.Remove) == "function" then
			pcall(d.Remove, d)
		end
	end
	esp[plr] = nil
end

-- One row per player. Written by sweep(), read by everything else.
local track = {}

local function trackPlayer(plr, t)
	t.char = plr.Character
	t.hum = t.char and t.char:FindFirstChildOfClass("Humanoid") or nil
	t.hrp = t.char and safePart(t.char:FindFirstChild("HumanoidRootPart")) or nil
	local parts = t.char and resolveParts(t.char) or nil
	-- The randomizer rolls any of these slots, so they all live on the entry.
	if parts then
		t.head, t.chest = parts.head, parts.chest
		t.leftArm, t.rightArm = parts.leftArm, parts.rightArm
		t.leftLeg, t.rightLeg = parts.leftLeg, parts.rightLeg
	else
		t.head, t.chest = nil, nil
		t.leftArm, t.rightArm = nil, nil
		t.leftLeg, t.rightLeg = nil, nil
	end
	t.rnd = nil -- a respawn is a new body: no stale roll carries over
	t.rect = nil -- and no rect from the old body's screen position
	t.backpack = plr:FindFirstChildOfClass("Backpack")
	t.items = nil
	t.bw, t.bh, t.boxOff = nil, nil, nil
	if t.char and t.hrp then
		local ok, cf, size = pcall(t.char.GetBoundingBox, t.char)
		if ok and cf and size then
			t.bw = size.X * 0.5
			t.bh = size.Y * 0.5
			t.boxOff = cf.Position - t.hrp.Position
		end
	end
	t.boxAt = clock()
end

local function sweep()
	local now = clock()
	local seen = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		seen[plr] = true
		local t = track[plr]
		if not t then
			t = { plr = plr, alive = false }
			track[plr] = t
			trackPlayer(plr, t)
		elseif plr.Character ~= t.char then
			trackPlayer(plr, t)
		elseif now - (t.boxAt or -1e9) > 1 then
			-- extents move with accessories and ragdolls; once a second is plenty
			t.boxAt = now
			local ok, cf, size = pcall(t.char.GetBoundingBox, t.char)
			if ok and cf and size and t.hrp then
				local nw, nh = size.X * 0.5, size.Y * 0.5
				-- A ragdoll or an accessory changes the extents while the
				-- player stands still; the cached screen rect would lie.
				if nw ~= t.bw or nh ~= t.bh then t.rect = nil end
				t.bw, t.bh = nw, nh
				t.boxOff = cf.Position - t.hrp.Position
			end
		end
	end
	for plr in pairs(track) do
		if not seen[plr] then
			track[plr] = nil
			destroy(plr)
		end
	end
end

-- Cheap every frame: a character swap and a health read. This is what makes a
-- death or a respawn land on the next frame instead of the next sweep.
local function refreshAlive()
	for plr, t in pairs(track) do
		if plr.Character ~= t.char then
			trackPlayer(plr, t)
		end
		local hum = t.hum
		t.alive = t.char ~= nil and hum ~= nil and hum.Health > 0 and t.hrp ~= nil
	end
end

-- Slot order matters: the percentages are read in this order until the roll
-- is spent, so the last slot absorbs the remainder.
local RND_ORDER = { "head", "chest", "arm", "leg" }

local function rollSlot()
	local total = 0
	for _, key in ipairs(RND_ORDER) do
		total = total + (Config.aim.rnd[key] or 0)
	end
	if total <= 0 then return "head" end

	-- Weights are relative, not strict percentages: the roll is normalised
	-- against whatever the sliders add up to, so no combination is dead.
	local r = math.random() * total
	local acc = 0

	for _, key in ipairs(RND_ORDER) do
		acc = acc + (Config.aim.rnd[key] or 0)
		if r <= acc then
			if key == "arm" then
				return math.random(2) == 1 and "leftArm" or "rightArm"
			elseif key == "leg" then
				return math.random(2) == 1 and "leftLeg" or "rightLeg"
			end
			return key
		end
	end

	return "head"
end

-- Returns the part to aim at, and the scatter offset for this hold window.
-- Randomizer off: the fixed hitbox, no offset. On: a weighted re-roll every
-- rndHold seconds, held still for the whole window so the burst stays tight.
local function aimPartFor(t, now)
	if not t or not t.alive then return nil end

	if not Config.aim.randomizer then
		return (Config.aim.hitbox == "chest") and t.chest or t.head, nil
	end

	now = now or clock()
	local r = t.rnd

	if not r or (now - r.at) >= Config.aim.rndHold then
		r = { at = now, slot = rollSlot(), off = nil }
		t.rnd = r
	end

	local part = t[r.slot] or t.chest or t.head
	if not part then return nil end

	if not r.off then
		local j = Config.aim.rndJitter
		if j and j > 0 then
			r.off = Vector3.new(
				(math.random() * 2 - 1) * j,
				(math.random() * 2 - 1) * j,
				(math.random() * 2 - 1) * j)
		else
			r.off = Vector3.new(0, 0, 0)
		end
	end

	return part, r.off
end

local function setHitbox(mode)
	Config.aim.hitbox = (mode == "chest") and "chest" or "head"
	print(string.format("[OD] hitbox = %s", Config.aim.hitbox))
end

-- Drawing text differs per VM: desktop executors take a numeric Font and a
-- Size; Matcha documents FontSize plus a Drawing.Fonts table. Set what exists
-- and drop what does not — a rejected property write must not kill a frame.
local TEXT_FONT = 2
pcall(function()
	if Drawing.Fonts ~= nil and Drawing.Fonts.UI ~= nil then
		TEXT_FONT = Drawing.Fonts.UI
	end
end)

local function textStyle(t, size)
	pcall(function() t.Font = TEXT_FONT end)
	pcall(function() t.Size = size end)
	if CAPS.matcha then pcall(function() t.FontSize = size end) end
	pcall(function() t.OutlineColor = Color3.new(0, 0, 0) end)
end

local function makeText()
	local t = Drawing.new("Text")
	t.Center = true
	t.Outline = true
	textStyle(t, Config.esp.textSize)
	t.Transparency = alpha(0)
	t.Visible = false
	return t
end

local function ensure(plr)
	local o = esp[plr]
	if o then return o end
	o = {
		box = Drawing.new("Square"),
		name = makeText(),
		dist = makeText(),
		items = makeText(),
		hpBg = Drawing.new("Square"),
		hp = Drawing.new("Square"),
		tracer = Drawing.new("Line"),
		head = Drawing.new("Circle"),
		q = {},
		on = false,
	}
	o.box.Thickness = Config.esp.boxThickness
	o.box.Filled = false
	o.box.Transparency = alpha(0)
	o.box.Visible = false
	o.hpBg.Filled = true
	o.hpBg.Color = Color3.fromRGB(15, 15, 15)
	o.hpBg.Transparency = alpha(0.35)
	o.hp.Filled = true
	o.hp.Transparency = alpha(0)
	o.tracer.Thickness = 1
	o.tracer.Transparency = alpha(0.4)
	o.head.Filled = true
	o.head.Thickness = 1
	o.head.Radius = 3
	o.head.Transparency = alpha(0)
	textStyle(o.items, 12)
	esp[plr] = o
	return o
end

local function hide(o)
	if not o.on then return end
	o.on = false
	espDirty = true
	o.box.Visible = false
	o.name.Visible = false
	o.dist.Visible = false
	o.items.Visible = false
	o.hpBg.Visible = false
	o.hp.Visible = false
	o.tracer.Visible = false
	o.head.Visible = false
end

-- Project one world point. nil when it is behind the camera, NaN, or far
-- outside the viewport — a projection that blows up must not size a box.
local function project(cam, vp, p)
	stats.projections = stats.projections + 1
	local sp = viewPoint(cam, p)
	if not sp or sp.Z <= 0 then return nil end
	local x, y = sp.X, sp.Y
	if x ~= x or y ~= y then return nil end
	if x < -vp.X * 2 or x > vp.X * 3 or y < -vp.Y * 2 or y > vp.Y * 3 then
		return nil
	end
	return x, y
end

-- Fast pass: geometry only, and only the properties that actually moved.
-- Every write is a bridge call in most executors; a standing player should
-- cost zero of them after the first frame.
local function updateEspFast()
	local cam = camera()
	if not cam then return end
	local vp = cam.ViewportSize
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local look = camCF.LookVector
	local right = Vector3.new(-look.Z, 0, look.X)
	if right.Magnitude < 1e-6 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local up = right:Cross(look)
	local cx = vp.X * 0.5
	local espOn = Config.esp.enabled

	for plr, t in pairs(track) do
		-- One health read per player per frame keeps death and revive on the
		-- next frame; the character walk stays on the slow lane.
		local hum = t.hum
		if hum ~= nil then
			local aliveNow = hum.Health > 0
			if aliveNow ~= t.alive then
				t.alive = aliveNow
				espDirty = true
			end
		end

		local o = esp[plr]
		local show = espOn and plr ~= LocalPlayer and t.alive and t.hrp ~= nil
		local x, y, w, h, dist

		if show then
			local center = t.hrp.Position
			if t.boxOff then center = center + t.boxOff end
			dist = (center - camPos).Magnitude
			if dist > Config.esp.range or (Config.esp.teamCheck and onSameTeam(plr)) then
				show = false
			else
				-- Behind the camera the projection is wasted work: one dot
				-- culls the half of the lobby that is not on screen.
				local toCenter = center - camPos
				if toCenter:Dot(look) <= 0 then
					show = false
				else
					-- Screen rect reuse. Four projections return identical
					-- numbers when neither the camera nor the player moved
					-- since last frame; a standing lobby then costs zero
					-- bridge calls. The key is camera position + look vector,
					-- which is the whole orientation (Roblox has no roll).
					local rr = t.rect
					if rr and rr.vw == vp.X and rr.vh == vp.Y
						and rr.cx == center.X and rr.cy == center.Y and rr.cz == center.Z
						and rr.lx == look.X and rr.ly == look.Y and rr.lz == look.Z
						and rr.px == camPos.X and rr.py == camPos.Y and rr.pz == camPos.Z then
						x, y, w, h = rr.x, rr.y, rr.w, rr.h
						stats.reused = stats.reused + 1
						if w < 1 or h < 1 or w > vp.X * 4 or h > vp.Y * 4 then
							show = false
						end
					else
						local hw = t.bw or 1.5
						local hh = t.bh or 3
						local sx = project(cam, vp, center + right * hw)
						local tx, ty = project(cam, vp, center + up * hh)
						local bx, by = project(cam, vp, center - up * hh)
						local mx, my = project(cam, vp, center)
						if sx and tx and bx and mx and my then
							w = math.abs(sx - mx) * 2
							x = mx - w * 0.5
							y = ty
							h = by - ty
							if w < 1 or h < 1 or w > vp.X * 4 or h > vp.Y * 4 then
								show = false
							end
						else
							show = false
						end
						-- Reuse the table: a fresh one per player per frame is
						-- garbage for the collector on a slow VM.
						local rc = t.rect or {}
						t.rect = rc
						rc.vw, rc.vh = vp.X, vp.Y
						rc.cx, rc.cy, rc.cz = center.X, center.Y, center.Z
						rc.lx, rc.ly, rc.lz = look.X, look.Y, look.Z
						rc.px, rc.py, rc.pz = camPos.X, camPos.Y, camPos.Z
						rc.x, rc.y, rc.w, rc.h = x or 0, y or 0, w or 0, h or 0
					end
				end
			end
		end

		if not show then
			t.onScreen = false
			if o then hide(o) end
		else
			if not o then o = ensure(plr) end
			if not o.on then
				o.on = true
				o.q = {} -- full write on the first visible frame
				espDirty = true
			end
			t.onScreen = true
			t.dist = dist

			local q = o.q
			local midX = x + w * 0.5

			if q.x ~= x or q.y ~= y then
				q.x, q.y = x, y
				o.box.Position = Vector2.new(x, y)
			end
			if q.w ~= w or q.h ~= h then
				q.w, q.h = w, h
				o.box.Size = Vector2.new(w, h)
			end
			if q.boxOn ~= Config.esp.box then
				q.boxOn = Config.esp.box
				o.box.Visible = Config.esp.box
			end

			local nx, ny = midX, y - 14
			if q.nx ~= nx or q.ny ~= ny then
				q.nx, q.ny = nx, ny
				o.name.Position = Vector2.new(nx, ny)
			end
			local ddx, ddy = midX, y + h + 4
			if q.dx ~= ddx or q.dy ~= ddy then
				q.dx, q.dy = ddx, ddy
				o.dist.Position = Vector2.new(ddx, ddy)
			end
			local ix, iy = midX, y + h + 18
			if q.ix ~= ix or q.iy ~= iy then
				q.ix, q.iy = ix, iy
				o.items.Position = Vector2.new(ix, iy)
			end

			local hum = t.hum
			local frac = 0
			if hum and hum.MaxHealth > 0 then
				frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			end
			if q.hfrac ~= frac or q.hh ~= h then
				q.hfrac, q.hh = frac, h
				o.hpBg.Size = Vector2.new(3, h)
				o.hp.Size = Vector2.new(3, h * frac)
			end
			local barX, barY = x - 7, y
			if q.barX ~= barX or q.barY ~= barY then
				q.barX, q.barY = barX, barY
				o.hpBg.Position = Vector2.new(barX, barY)
			end
			local fillY = y + h * (1 - frac)
			if q.fillY ~= fillY then
				q.fillY = fillY
				o.hp.Position = Vector2.new(barX, fillY)
			end
			if q.hpOn ~= Config.esp.health then
				q.hpOn = Config.esp.health
				o.hpBg.Visible = Config.esp.health
				o.hp.Visible = Config.esp.health
			end

			local tx2, ty2 = midX, y + h
			if q.tx ~= tx2 or q.ty ~= ty2 or q.tcx ~= cx or q.tcy ~= vp.Y then
				q.tx, q.ty, q.tcx, q.tcy = tx2, ty2, cx, vp.Y
				o.tracer.From = Vector2.new(cx, vp.Y)
				o.tracer.To = Vector2.new(tx2, ty2)
			end
			if q.tracerOn ~= Config.esp.tracer then
				q.tracerOn = Config.esp.tracer
				o.tracer.Visible = Config.esp.tracer
			end

			local headX, headY = nil, nil
			if t.head then
				headX, headY = project(cam, vp, t.head.Position)
			end
			local headOn = Config.esp.headDot and headX ~= nil
			if q.headOn ~= headOn then
				q.headOn = headOn
				o.head.Visible = headOn
			end
			if headOn and (q.headX ~= headX or q.headY ~= headY) then
				q.headX, q.headY = headX, headY
				o.head.Position = Vector2.new(headX, headY)
			end
		end
	end
end

-- Raycasts are throttled per player; 10 Hz is invisible to the eye.

local function visible(plr, pos)
	local now = clock()
	local c = vis[plr]
	if c and now - c.t < 0.1 then
		return c.v
	end
	local cam = camera()
	local v = cam and lineOfSight(plr, cam.CFrame.Position, pos) or false
	vis[plr] = { t = now, v = v }
	return v
end

-- Slow pass: text, colours, item lists. 10 Hz content, written only when the
-- value changes — the old loop formatted a string for every player per frame.
local function updateEspSlow()
	if not Config.esp.enabled then return end
	local cam = camera()
	if not cam then return end
	local camPos = cam.CFrame.Position

	for plr, t in pairs(track) do
		local o = esp[plr]
		if o and o.on and t.hrp then
			local q = o.q
			local visNow = t.onScreen and visible(plr, t.hrp.Position) or false
			local color = visNow and Config.esp.visibleColor or Config.esp.hiddenColor

			if q.color ~= color then
				q.color = color
				o.box.Color = color
				o.name.Color = color
				o.dist.Color = color
				o.items.Color = color
				o.tracer.Color = color
				o.head.Color = color
			end

			if q.nameText ~= plr.Name then
				q.nameText = plr.Name
				o.name.Text = plr.Name
			end
			if q.nameOn ~= Config.esp.name then
				q.nameOn = Config.esp.name
				o.name.Visible = Config.esp.name
			end

			local d = math.floor((t.hrp.Position - camPos).Magnitude + 0.5)
			if q.distText ~= d then
				q.distText = d
				o.dist.Text = tostring(d)
			end
			if q.distOn ~= Config.esp.distance then
				q.distOn = Config.esp.distance
				o.dist.Visible = Config.esp.distance
			end

			local itemsText = ""
			if Config.esp.items then
				local list = {}
				local char = t.char
				if char then
					for _, child in ipairs(char:GetChildren()) do
						if child:IsA("Tool") then list[#list + 1] = child.Name end
					end
				end
				local backpack = t.backpack
				if backpack then
					for _, child in ipairs(backpack:GetChildren()) do
						if child:IsA("Tool") then list[#list + 1] = child.Name end
					end
				end
				if #list > Config.esp.itemMax then
					local cut = {}
					for i = 1, Config.esp.itemMax do cut[i] = list[i] end
					cut[#cut + 1] = "+" .. tostring(#list - Config.esp.itemMax)
					list = cut
				end
				itemsText = table.concat(list, " | ")
			end
			if q.itemsText ~= itemsText then
				q.itemsText = itemsText
				o.items.Text = itemsText
				o.items.Visible = itemsText ~= ""
			end

			local hum = t.hum
			local frac = 0
			if hum and hum.MaxHealth > 0 then
				frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			end
			local bucket = math.floor(frac * 20 + 0.5) / 20
			if q.hcol ~= bucket then
				q.hcol = bucket
				o.hp.Color = Color3.fromRGB(0, 220, 90):Lerp(Color3.fromRGB(220, 40, 40), 1 - bucket)
			end
		end
	end
end

-- 3D avatar through walls: a client-side Highlight on the character. The on/off
-- decision is per frame; the property writes are throttled because a Highlight
-- rewrite re-renders its geometry.
local chams = {}
local chamsAt = -1e9

chamsOff = function(plr)
	local entry = chams[plr]
	if entry then
		entry.inst:Destroy()
		chams[plr] = nil
	end
end

local function chamsFor(plr, t, write)
	-- Matcha cannot create an Instance; the Highlight path is impossible there.
	if CAPS.matcha then return end
	local char = t and t.char
	if not char then
		chamsOff(plr)
		return
	end
	local entry = chams[plr]
	if entry and entry.inst.Parent ~= char then
		entry.inst:Destroy()
		entry = nil
		chams[plr] = nil
	end
	if not entry then
		local h = Instance.new("Highlight")
		h.Name = "OD_Chams"
		h.Adornee = char
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = char
		-- Paint bookkeeping sits beside the Instance: a real Highlight has no
		-- `q` property and assigning one raises.
		entry = { inst = h, q = {} }
		write = true
		chams[plr] = entry
	end
	if not write then return end
	local h, q = entry.inst, entry.q
	if q.fill ~= Config.esp.chamsFill then
		q.fill = Config.esp.chamsFill
		h.FillColor = q.fill
	end
	if q.fillT ~= Config.esp.chamsTransparency then
		q.fillT = Config.esp.chamsTransparency
		h.FillTransparency = q.fillT
	end
	if q.outline ~= Config.esp.chamsOutline then
		q.outline = Config.esp.chamsOutline
		h.OutlineColor = q.outline
	end
	if q.outlineT ~= 0 then
		q.outlineT = 0
		h.OutlineTransparency = 0
	end
end

local function updateChams()
	local cam = camera()
	local camPos = cam and cam.CFrame.Position
	local now = clock()
	local write = now - chamsAt >= 0.1
	if write then chamsAt = now end
	for plr, t in pairs(track) do
		local on = Config.esp.enabled and Config.esp.chams and plr ~= LocalPlayer
			and t.alive and not (Config.esp.teamCheck and onSameTeam(plr))
		if on and camPos and t.hrp then
			on = (t.hrp.Position - camPos).Magnitude <= Config.esp.range
		end
		if on then
			chamsFor(plr, t, write)
		else
			chamsOff(plr)
		end
	end
end

-- Points of interest: armories, gun vendors, and loot piles worth walking to.
-- The walk is incremental — a slice of the tree per frame — so a full scan
-- never lands as one frame spike.
local poi = {
	draws = {},
	spots = {},
	queue = {},
	found = {},
	keys = {},
	names = {},
	count = 0,
	version = 0,
	seen = 0,
	lootCount = 0,
	scanning = false,
	lastDone = -1e9,
}

local function poiIgnored(name)
	local lname = name:lower()
	for _, ig in ipairs(Config.poi.ignore) do
		if string.find(lname, ig, 1, true) then return true end
	end
	return false
end

local function poiIsKeyword(name)
	local lname = name:lower()
	for _, kw in ipairs(Config.poi.keywords) do
		if string.find(lname, kw, 1, true) then return true end
	end
	return false
end

-- Three colours on the map: yellow armory, orange dealer, grey loot. A name
-- that hits both lists (a "weapon dealer") reads as an armory first, because
-- that is the marker that sells guns.
local function poiColorFor(kind, name)
	if kind == "loot" then return Config.poi.lootColor end
	if kind == "custom" then return Config.poi.color end
	local lname = name:lower()
	for _, kw in ipairs(Config.poi.armoryKeys) do
		if string.find(lname, kw, 1, true) then return Config.poi.color end
	end
	for _, kw in ipairs(Config.poi.dealerKeys) do
		if string.find(lname, kw, 1, true) then return Config.poi.dealerColor end
	end
	return Config.poi.color
end

local function poiKey(name, pos)
	return string.format("%s@%d,%d,%d", name, math.floor(pos.X / 8), math.floor(pos.Y / 8), math.floor(pos.Z / 8))
end

local function poiAdd(kind, name, pos)
	local key = poiKey(name, pos)
	if poi.keys[key] then return end
	-- Loot is capped so a floor full of dropped tools cannot starve the
	-- armory/dealer markers out of the walk.
	if kind == "loot" then
		if poi.lootCount >= Config.poi.maxFound then return end
		poi.lootCount = poi.lootCount + 1
	end
	poi.keys[key] = true
	poi.found[#poi.found + 1] = { kind = kind, name = name, pos = pos }
end

-- Every name the map exposes lands in poi.names. First sight decides the
-- default tick from the keyword list; after that the menu owns the decision.
local function poiNote(name, pos)
	local rec = poi.names[name]
	if rec then
		rec.count = rec.count + 1
		return
	end
	local auto = poiIsKeyword(name)
	-- Keyword names always get in, even after the picker is full: the
	-- armory is the one name the cheat cannot afford to drop. The absolute
	-- ceiling stops a map of uniquely named "shop" parts from growing it
	-- without bound.
	if not auto and poi.count >= Config.poi.maxNames then return end
	if poi.count >= Config.poi.maxNames + 100 then return end
	poi.names[name] = { count = 1, pos = pos, auto = auto }
	if Config.poi.show[name] == nil then
		Config.poi.show[name] = auto
	end
	poi.count = poi.count + 1
	poi.version = poi.version + 1
end

local function poiPivot(inst)
	if inst:IsA("BasePart") then return inst.Position end
	-- Models only: the pcall stays, but it no longer runs for every part.
	local ok, cf = pcall(inst.GetPivot, inst)
	if ok and cf then return cf.Position end
	return nil
end

local function poiClassify(inst)
	if inst:IsA("Tool") then
		local handle = inst:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			poiNote(inst.Name, handle.Position)
			if Config.poi.loot then
				poiAdd("loot", inst.Name, handle.Position)
			end
		end
		return
	end

	local isPart = inst:IsA("BasePart")
	local isModel = inst:IsA("Model")

	if isPart or isModel then
		local name = inst.Name
		if not poiIgnored(name) then
			local pos = poiPivot(inst)
			if pos then
				poiNote(name, pos)
				-- only ticked names are stored; ticking one forces a rescan
				if Config.poi.show[name] then
					poiAdd("spot", name, pos)
				end
			end
		end
	end

	if isModel then
		if Players:GetPlayerFromCharacter(inst) then return end
		for _, c in ipairs(inst:GetChildren()) do
			poi.queue[#poi.queue + 1] = c
		end
	elseif inst:IsA("Folder") then
		for _, c in ipairs(inst:GetChildren()) do
			poi.queue[#poi.queue + 1] = c
		end
	end
end

local function poiStart()
	poi.queue = {}
	for _, c in ipairs(Workspace:GetChildren()) do
		poi.queue[#poi.queue + 1] = c
	end
	poi.found = {}
	poi.keys = {}
	poi.lootCount = 0
	poi.seen = 0
	poi.scanning = true
end

local function poiPublish()
	local named, loot = {}, {}
	local cam = camera()
	local camPos = cam and cam.CFrame.Position or nil

	for _, e in ipairs(poi.found) do
		if e.kind == "spot" then
			if Config.poi.show[e.name] then
				named[#named + 1] = { kind = "spot", name = e.name, pos = e.pos, count = 1 }
			end
		else
			local hit = nil
			for _, s in ipairs(loot) do
				if (s.pos - e.pos).Magnitude <= Config.poi.clusterRadius then
					hit = s
					break
				end
			end
			if hit then
				hit.count = hit.count + 1
			else
				loot[#loot + 1] = { kind = "loot", name = "Loot", pos = e.pos, count = 1 }
			end
		end
	end

	-- The marker pool is capped. Nearest first means the armory across the
	-- street keeps its slot over a pile three blocks out.
	if camPos then
		table.sort(named, function(a, b)
			return (a.pos - camPos).Magnitude < (b.pos - camPos).Magnitude
		end)
	end
	table.sort(loot, function(a, b) return a.count > b.count end)

	local spots = {}
	for _, s in ipairs(named) do
		if #spots >= Config.poi.maxMarkers then break end
		s.color = poiColorFor(s.kind, s.name)
		spots[#spots + 1] = s
	end
	for _, s in ipairs(loot) do
		if #spots >= Config.poi.maxMarkers then break end
		if s.count >= Config.poi.clusterMin then
			s.name = string.format("Loot x%d", s.count)
			s.color = poiColorFor("loot", s.name)
			spots[#spots + 1] = s
		end
	end

	for _, c in ipairs(Config.poi.custom) do
		if #spots >= Config.poi.maxMarkers then break end
		spots[#spots + 1] = {
			kind = "custom",
			name = c.name,
			pos = c.position,
			count = 1,
			color = poiColorFor("custom", c.name),
		}
	end

	poi.spots = spots
	poi.lastDone = clock()

	if Config.poi.debug then
		print(string.format("[OD] POI: %d spots from %d hits", #spots, #poi.found))
	end
end

-- Time-budgeted walk: the slice is a ceiling, the clock is the real limit.
-- On a big map this keeps a scan from landing as a frame spike.
local function poiStep(budget)
	local left = budget
	local deadline = clock() + 0.0015
	while left > 0 and #poi.queue > 0 and clock() < deadline do
		local inst = poi.queue[#poi.queue]
		poi.queue[#poi.queue] = nil
		left = left - 1
		poi.seen = poi.seen + 1
		poiClassify(inst)
		if poi.seen >= Config.poi.maxNodes then
			poi.queue = {}
			break
		end
	end
	if #poi.queue == 0 then
		poi.scanning = false
		poiPublish()
	end
end

-- Dump the names the map actually uses, so keywords can be matched to them.
local function poiNames(limit)
	limit = limit or 120
	local seen, out = {}, {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Model") then
			if not seen[d.Name] then
				seen[d.Name] = true
				local pos = nil
				if d:IsA("BasePart") then
					pos = d.Position
				else
					local ok, cf = pcall(function() return d:GetPivot() end)
					if ok then pos = cf.Position end
				end
				out[#out + 1] = { name = d.Name, class = d.ClassName, pos = pos }
				if #out >= limit then break end
			end
		end
	end
	return out
end

-- The draw objects are a fixed pool: created once, reused every scan.
-- Creating and removing them each refresh was the other source of hitches.
local function poiPool(i)
	local d = poi.draws[i]
	if d then return d end

	local circle = Drawing.new("Circle")
	circle.Filled = true
	circle.Thickness = 1
	circle.Radius = 4
	circle.Transparency = alpha(0.1)
	circle.Color = Config.poi.color
	circle.Visible = false

	local text = Drawing.new("Text")
	text.Center = true
	text.Outline = true
	textStyle(text, Config.poi.textSize)
	text.Transparency = alpha(0)
	text.Color = Config.poi.color
	text.Visible = false

	d = { circle = circle, text = text }
	poi.draws[i] = d
	return d
end

local function poiClear()
	for _, d in ipairs(poi.draws) do
		d.circle:Remove()
		d.text:Remove()
	end
	poi.draws = {}
	poi.spots = {}
	poi.queue = {}
	poi.scanning = false
end

local poiTextAt = -1e9
local poiProjAt = -1e9
local poiProjVer = -1

local function updatePoi(now)
	if not Config.poi.enabled then
		for _, d in ipairs(poi.draws) do
			if d.qVis ~= false then
				d.qVis = false
				d.circle.Visible = false
				d.text.Visible = false
			end
		end
		return
	end

	if poi.scanning then
		poiStep(Config.poi.slice)
	elseif clock() - poi.lastDone >= Config.poi.refresh then
		poiStart()
		poiStep(Config.poi.slice)
	end

	now = now or clock()

	-- Markers are static world points: 30 Hz projection is indistinguishable
	-- from every frame and halves the work. A new spot list bypasses the gate.
	local hz = Config.perf.poiHz
	local fresh = poiProjVer ~= poi.version
	if not fresh and hz and hz > 0 and now - poiProjAt < 1 / hz then return end
	poiProjAt = now
	poiProjVer = poi.version

	local cam = camera()
	if not cam then return end
	local camPos = cam.CFrame.Position
	local writeText = now - poiTextAt >= 0.1
	if writeText then poiTextAt = now end

	for i, s in ipairs(poi.spots) do
		local d = poiPool(i)
		local dist = (s.pos - camPos).Magnitude
		-- An unticked name disappears on the next frame, without waiting for
		-- the walk to finish and republish.
		local shown = s.kind ~= "spot" or Config.poi.show[s.name] ~= false
		if shown and dist <= Config.poi.maxDistance then
			local sp = viewPoint(cam, s.pos)
			if sp and sp.Z > 0 then
				local col = s.color or Config.poi.color
				if d.qCol ~= col then
					d.qCol = col
					d.circle.Color = col
					d.text.Color = col
				end
				d.circle.Position = Vector2.new(sp.X, sp.Y)
				-- A pooled marker reused for a new name rewrites at once, or the
				-- old label lingers until the next text tick.
				if writeText or d.qName ~= s.name then
					d.qName = s.name
					d.text.Position = Vector2.new(sp.X, sp.Y + 9)
					d.text.Text = string.format("%s [%.0f]", s.name, dist)
				end
				if d.qVis ~= true then
					d.qVis = true
					d.circle.Visible = true
					d.text.Visible = true
				end
			elseif d.qVis ~= false then
				d.qVis = false
				d.circle.Visible = false
				d.text.Visible = false
			end
		elseif d.qVis ~= false then
			d.qVis = false
			d.circle.Visible = false
			d.text.Visible = false
		end
	end

	for i = #poi.spots + 1, #poi.draws do
		local d = poi.draws[i]
		if d.qVis ~= false then
			d.qVis = false
			d.circle.Visible = false
			d.text.Visible = false
		end
	end
end

-- Hitboxes are resolved once per character in resolveParts (top of file);
-- aimPartFor just picks the one the current mode wants.

-- Where the next shot has to land: the hitbox plus the ground the target
-- covers during the ping window. A 160 ms round trip wants ~80 ms of lead.
-- `off` is the randomizer's scatter for this hold window; nil when off.

-- Ping-derived lead. GetPingValue is the round trip in milliseconds, and the
-- shot has to land one one-way trip from now: lead = ping / 2000. Cached for a
-- second — it is a bridge read and it barely moves between frames.
local pingAt, pingVal = -1e9, nil
local function pingLead()
	if type(GetPingValue) ~= "function" then return nil end
	local t = clock()
	if t - pingAt < 1 then return pingVal end
	pingAt = t
	local ok, v = pcall(GetPingValue)
	if ok and type(v) == "number" and v > 0 and v < 1000 then
		pingVal = v / 2000
	else
		pingVal = nil
	end
	return pingVal
end

local function aimLead()
	if Config.aim.autoLead then
		local p = pingLead()
		if p and p > 0 then
			if p > 0.3 then return 0.3 end
			return p
		end
	end
	return Config.aim.prediction
end

local function aimPoint(part, off)
	local pos = part.Position
	if off then
		pos = pos + off
	end
	local bias = Config.aim.partOffset
	if bias and bias.Magnitude > 0 then
		pos = pos + bias
	end
	local lead = aimLead()
	if lead and lead > 0 then
		local v = part.AssemblyLinearVelocity
		if v then pos = pos + v * lead end
	end
	return pos
end

-- Sticky target: switching every frame makes the lock feel twitchy.
local lockedTarget = nil
local shooting = false

local function findTarget()
	local cam = camera()
	if not cam then return nil end
	local origin = aimOrigin()
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local look = camCF.LookVector
	local best, bestScore = nil, math.huge
	local stick, stickScore = nil, math.huge

	-- Mid-burst the lock does not move: every bullet already in the air is
	-- aimed at this hitbox, and switching targets wastes the burst.
	if shooting and lockedTarget and lockedTarget ~= LocalPlayer
		and not aimIgnored(lockedTarget) then
		local lt = track[lockedTarget]
		local lpart, loff = aimPartFor(lt)
		if lpart then
			local lpos = aimPoint(lpart, loff)
			local ldist = (lpart.Position - camPos).Magnitude
			local lsp = viewPoint(cam, lpos)
			if ldist <= Config.aim.range and lsp and lsp.Z > 0 then
				local lscore = (Vector2.new(lsp.X, lsp.Y) - origin).Magnitude
				if lscore <= Config.aim.fov * 1.25 then
					return lockedTarget
				end
			end
		end
	end

	for plr, t in pairs(track) do
		if plr ~= LocalPlayer and t.alive then
			local part, off = aimPartFor(t)
			local skip = (Config.aim.teamCheck and onSameTeam(plr)) or aimIgnored(plr)
			if part and not skip then
				local raw = part.Position
				local pos = aimPoint(part, off)
				local toPart = raw - camPos
				local dist = toPart.Magnitude
				-- A target behind the camera cannot be inside the crosshair;
				-- skip the projection instead of paying for it.
				if dist <= Config.aim.range and toPart:Dot(look) > 0 then
					local sp = viewPoint(cam, pos)
					if sp and sp.Z > 0 then
						local score = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
						if score <= Config.aim.fov then
							if not Config.aim.visibleOnly or lineOfSight(plr, camPos, raw) then
								if score < bestScore then
									best, bestScore = plr, score
								end
								if plr == lockedTarget then
									stick, stickScore = plr, score
								end
							end
						end
					end
				end
			end
		end
	end

	-- hold the current target until it drifts to the edge of the FOV
	if stick and stickScore <= Config.aim.fov * 0.9 then
		return stick
	end
	lockedTarget = best
	return best
end

local aimDebugAt = -1e9

-- Cursor convergence probe. mousemoverel exists on most executors but is a
-- no-op on a few; if the gap stops closing, the camera takes over briefly.
local aimFallbackUntil = 0
local aimProbe = { t = 0, gap = 0 }

-- CFrame.lookAt is not on Matcha's constructor list. Build the same rotation
-- matrix by hand when it is missing: X column right, Y column up, -Z forward.
local function lookCFrame(pos, target)
	if type(CFrame.lookAt) == "function" then
		local ok, cf = pcall(CFrame.lookAt, pos, target)
		if ok and cf then return cf end
	end
	local f = target - pos
	if f.Magnitude < 1e-6 then return nil end
	f = f.Unit
	local right = f:Cross(Vector3.new(0, 1, 0))
	if right.Magnitude < 1e-6 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local up = right:Cross(f).Unit
	return CFrame.new(pos.X, pos.Y, pos.Z,
		right.X, up.X, -f.X,
		right.Y, up.Y, -f.Y,
		right.Z, up.Z, -f.Z)
end

local function applyAim(plr, dt, boost, firing)
	local cam = camera()
	if not cam then return end
	local t = track[plr]
	local part, off = aimPartFor(t)
	if not part then return end

	local aimPos = aimPoint(part, off)
	local sp = viewPoint(cam, aimPos)
	if not sp or sp.Z <= 0 then return end

	local now = clock()
	local soft = Config.aim.style ~= "snap"
	local target = Vector2.new(sp.X, sp.Y)

	-- Soft keeps a few pixels of life in the aim point. math.noise is not on
	-- every executor, so two sines at unrelated rates do the same job.
	if soft and Config.aim.softDrift > 0 then
		local amp = Config.aim.softDrift
		target = Vector2.new(
			target.X + math.sin(now * 2.1) * amp,
			target.Y + math.sin(now * 1.7 + 1.3) * amp * 0.7)
	end

	local origin = aimOrigin()
	local dx = target.X - origin.X
	local dy = target.Y - origin.Y
	local gap = math.sqrt(dx * dx + dy * dy)

	-- If the gap is not shrinking, the cursor never moved. Flip to the
	-- camera for 1.5 s so the lock still lands instead of doing nothing.
	if now - aimProbe.t >= 0.5 then
		if aimProbe.gap > 30 and gap > aimProbe.gap * 0.9 then
			aimFallbackUntil = now + 1.5
		end
		aimProbe.t = now
		aimProbe.gap = gap
	end

	-- Recoil is a camera kick: the hitbox moves on screen between shots.
	-- Snap style closes the whole gap on trigger-down; soft never does.
	local snap = (not soft) and firing and Config.aim.fireSnap
		and Config.combat.recoilControl
	local deadzone = snap and 0 or Config.aim.deadzone
	if soft then deadzone = math.max(deadzone, 2) end

	if Config.aim.debug and clock() - aimDebugAt > 1 then
		aimDebugAt = clock()
		print(string.format("[OD] aim %s part=%s dx=%.1f dy=%.1f", soft and "soft" or "snap",
			part.Name, dx, dy))
	end

	-- Cursor path: the game's crosshair is the mouse, so move the mouse.
	-- The camera is left alone — fighting it is what made the lock feel coarse.
	if Config.aim.mode ~= "camera" and hasMoverel()
		and now >= aimFallbackUntil then
		if gap <= deadzone then return end

		local gx, gy
		if snap then
			gx, gy = dx, dy
		elseif soft then
			-- Capped slew: maxSpeed px/s, tapered inside softZone so the
			-- crosshair eases onto the hitbox instead of arriving hot.
			local zone = math.max(Config.aim.softZone, 1)
			local floor = math.clamp(Config.aim.softMin, 0.02, 1)
			local taper = math.clamp(gap / zone, floor, 1)
			local step = math.min(gap, Config.aim.maxSpeed * dt * taper)
			gx, gy = dx / gap * step, dy / gap * step
		else
			local k = 1 - (1 - math.clamp(Config.aim.gain, 0.05, 1)) ^ (dt * 60)
			local lim = Config.aim.maxStep
			gx = math.clamp(dx * k, -lim, lim)
			gy = math.clamp(dy * k, -lim, lim)
		end
		if pcall(mousemoverel, gx, gy) then return end
	end

	-- Camera fallback: executors without mousemoverel, or mode = "camera".
	-- The slew cap does not apply here — a capped camera stalls convergence.
	local alpha
	if snap then
		alpha = 1
	else
		local base = math.clamp(Config.aim.smoothness, 0.01, 1)
		if boost then base = math.max(base, math.clamp(boost, 0.01, 1)) end
		alpha = 1 - (1 - base) ^ (dt * 60)
	end

	local camPos = cam.CFrame.Position
	local desired = aimPos - camPos
	if desired.Magnitude < 1e-3 then return end
	desired = desired.Unit
	local blended = cam.CFrame.LookVector:Lerp(desired, alpha)
	if blended.Magnitude < 1e-3 then
		blended = desired
	else
		blended = blended.Unit
	end
	local cf = lookCFrame(camPos, camPos + blended)
	if cf then cam.CFrame = cf end
end

-- Auto-fire + recoil control.
local aimActive = false

local vim
pcall(function() vim = game:GetService("VirtualInputManager") end)

local ownsPress = false
local lastClick = 0
local fireOKSince = nil

local function mouseButton(down)
	if type(mouse1press) == "function" and type(mouse1release) == "function" then
		local ok = pcall(down and mouse1press or mouse1release)
		if ok then return true end
	end
	if vim then
		local ok = pcall(function()
			vim:SendMouseButtonEvent(0, 0, 0, down, game, 0)
		end)
		if ok then return true end
	end
	return false
end

local function mouseClick()
	if type(mouse1click) == "function" then
		local ok = pcall(mouse1click)
		if ok then return true end
	end
	return mouseButton(true) and mouseButton(false)
end

-- The player's own trigger. The script must not fight it or release it.
local function userFiring()
	local ok, down = pcall(function()
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end)
	if ok then return down == true end
	-- Matcha ships no Enum.UserInputType; ismouse1pressed reads the button.
	if type(ismouse1pressed) == "function" then
		local okm, pressed = pcall(ismouse1pressed)
		if okm then return pressed == true end
	end
	return false
end

local function stopFire()
	if shooting and ownsPress then
		ownsPress = false
		mouseButton(false)
	end
	shooting = false
	fireOKSince = nil
end

-- Never press on top of the player's own trigger, and never release it.
local function startFire()
	if shooting then
		-- The player's press was holding the trigger. When they let go, take
		-- the press over instead of believing a bullet is still going out.
		if not ownsPress and not userFiring() then
			ownsPress = mouseButton(true)
			shooting = ownsPress
		end
		return
	end
	if userFiring() then
		shooting = true
		ownsPress = false
		return
	end
	ownsPress = mouseButton(true)
	shooting = ownsPress
end

local function canFire(target)
	if not (Config.combat.enabled and Config.combat.autoShoot and aimActive and target) then
		return false
	end
	local char = target.Character
	local part, off = aimPartFor(track[target])
	local cam = camera()
	if not part or not cam then return false end
	local pos = part.Position
	if (pos - cam.CFrame.Position).Magnitude > Config.aim.range then return false end
	if Config.combat.requireLOS and not lineOfSight(target, cam.CFrame.Position, pos) then return false end
	-- Two thresholds: start on the head, keep the burst while it is close.
	-- Releasing on every recoil kick was the stutter that lost half the mag.
	if Config.combat.alignPx > 0 or Config.combat.releasePx > 0 then
		local sp = viewPoint(cam, aimPoint(part, off))
		if not sp or sp.Z <= 0 then return false end
		local gap = (Vector2.new(sp.X, sp.Y) - aimOrigin()).Magnitude
		local limit = shooting and Config.combat.releasePx or Config.combat.alignPx
		if limit > 0 and gap > limit then return false end
	end
	return true
end

local function updateFire(target)
	if not canFire(target) then
		stopFire()
		return
	end

	local now = clock()
	if not fireOKSince then
		fireOKSince = now
	end
	if now - fireOKSince < Config.combat.triggerDelay then
		return
	end

	if Config.combat.holdFire then
		startFire()
	else
		if shooting then
			shooting = false
			if ownsPress then
				ownsPress = false
				mouseButton(false)
			end
		end
		if now - lastClick >= Config.combat.fireRate then
			lastClick = now
			mouseClick()
		end
	end
end

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.NumSides = 64
fovCircle.Transparency = alpha(0.6)
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Visible = false

local aimMarker = Drawing.new("Circle")
aimMarker.Thickness = 1.5
aimMarker.Filled = false
aimMarker.NumSides = 24
aimMarker.Transparency = alpha(0)
aimMarker.Color = Color3.fromRGB(255, 80, 80)
aimMarker.Visible = false

-- FOV ring write cache: the Drawing layer is a C++ boundary, so a frame with
-- no change in position, radius, visibility or colour must write nothing.
local FOV_ACTIVE = Color3.fromRGB(0, 255, 120)
local FOV_IDLE = Color3.fromRGB(255, 255, 255)
local fovQ = { pos = nil, radius = nil, visible = nil, color = nil }

-- Rewrite every live drawing after a transparency-mode flip. The objects are
-- created once, so without this a wrong auto-detect stays invisible until the
-- script is re-executed.
local function setOpaque(v)
	Config.render.opaque = (v == 1 or v == true) and 1 or 0
	for _, o in pairs(esp) do
		o.box.Transparency = alpha(0)
		o.name.Transparency = alpha(0)
		o.dist.Transparency = alpha(0)
		o.items.Transparency = alpha(0)
		o.hpBg.Transparency = alpha(0.35)
		o.hp.Transparency = alpha(0)
		o.tracer.Transparency = alpha(0.4)
		o.head.Transparency = alpha(0)
	end
	for _, d in ipairs(poi.draws) do
		d.circle.Transparency = alpha(0.1)
		d.text.Transparency = alpha(0)
	end
	fovCircle.Transparency = alpha(0.6)
	aimMarker.Transparency = alpha(0)
	return Config.render.opaque
end

-- ══ MENU ═══════════════════════════════════════════════════════════════════
-- Instance menu. Ñ opens it; every switch writes straight into Config, so the
-- panel and the hotkeys can never disagree about state.
-- Matcha's Enum is a subset: KeyCode holds A-Z and the mouse buttons, so
-- Semicolon does not exist and a table literal keyed on it dies with "table
-- index is nil" before the gate can draw. Build the set, never the literal.
local UI_KEYS = {}
if Config.ui.key ~= nil then UI_KEYS[Config.ui.key] = true end -- Ñ on a Spanish layout
pcall(function() UI_KEYS[Enum.KeyCode["Ñ"]] = true end)

local uiOpen = true
local uiRefresh = function() end
local uiSetOpen = function() end
local uiDestroy = function() end

-- =========================================================
-- OverlayUI — inline panel library (Finifugal 2.0)
-- =========================================================
local OverlayUI = (function()
-- OverlayUI.lua | client-side Roblox UI module
-- Blood Flow edition. Pure instances; no textures, gradients or frame callbacks.
-- Public API is unchanged. Only the caller schedules refresh().
-- Studio/client runtime and FPS have not been measured in this environment.

local OverlayUI = {}
OverlayUI.__index = OverlayUI
local List = {}
List.__index = List

local Players = game:GetService("Players")
-- TweenService is not on Matcha's documented service list. The panel never
-- runs there, but this read is at file scope, so a nil return or a raise would
-- take the load down before the gate draws.
local TweenService
pcall(function() TweenService = game:GetService("TweenService") end)
local UIS = game:GetService("UserInputService")

local MAX_ROWS, MAX_LISTS, MAX_ITEMS = 128, 16, 64
local MAX_CONNECTIONS = 4096
local HEADER, ROW, GAP, HEIGHT = 36, 30, 4, 440
-- This library only ever runs on the desktop path, but its constants sit at
-- file scope, so they execute on every VM. Probe them: Matcha's Enum carries
-- KeyCode and nothing else, and it ships no TweenInfo at all.
local FONT, BOLD, MONO, SWITCH
pcall(function()
	FONT, BOLD, MONO = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.Code
	SWITCH = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end)
local LINE = Color3.fromRGB(31, 36, 44)
local DEFAULT = {
    bg = Color3.fromRGB(13, 15, 18), row = Color3.fromRGB(21, 24, 29),
    accent = Color3.fromRGB(57, 217, 138), text = Color3.fromRGB(230, 235, 242),
    muted = Color3.fromRGB(123, 132, 148), off = Color3.fromRGB(43, 49, 59),
}
local OFF_POS, ON_POS = UDim2.new(0, 3, .5, 0), UDim2.new(1, -17, .5, 0)
local function offset(x, y) return UDim2.fromOffset(x, y) end
local function scale(x, y) return UDim2.fromScale(x, y) end
local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function write(obj, prop, value)
    if obj[prop] ~= value then obj[prop] = value end
end
local function make(class, props, parent)
    local obj = Instance.new(class)
    local n = 0
    for k, v in pairs(props) do
        n = n + 1
        if n > 40 then obj:Destroy(); error("OverlayUI: property limit", 2) end
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end
local function frame(parent, props) return make("Frame", props, parent) end
local function corner(parent, px)
    return make("UICorner", {CornerRadius = UDim.new(0, px)}, parent)
end
local function round(parent)
    return make("UICorner", {CornerRadius = UDim.new(.5, 0)}, parent)
end
local function stroke(parent, color, transparency)
    return make("UIStroke", {Color = color, Thickness = 1,
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
end
local function label(parent, text, color, size, font)
    return make("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = tostring(text or ""), TextColor3 = color, TextSize = size or 11,
        Font = font or FONT, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
        Active = false}, parent)
end
local function button(parent, text, color, bg, size)
    return make("TextButton", {BackgroundColor3 = bg, BorderSizePixel = 0,
        Text = tostring(text), TextColor3 = color, TextSize = size or 12,
        Font = BOLD, AutoButtonColor = false, Active = true,
        TextTruncate = Enum.TextTruncate.AtEnd}, parent)
end
local function centeredRight(obj, right, w, h)
    obj.AnchorPoint = Vector2.new(1, .5)
    obj.Position = UDim2.new(1, -right, .5, 0)
    obj.Size = offset(w, h)
end
local function separator(parent, pos, size)
    return frame(parent, {BackgroundColor3 = LINE, BorderSizePixel = 0,
        Position = pos, Size = size, Active = false})
end
local function theme(t)
    t = t or {}
    return {bg = t.bg or DEFAULT.bg, row = t.row or DEFAULT.row,
        accent = t.accent or DEFAULT.accent, text = t.text or DEFAULT.text,
        muted = t.muted or DEFAULT.muted, off = t.off or DEFAULT.off}
end
local function numberText(n) return n == 0 and "0" or tostring(n) end

-- An externally owned ScreenGui is never destroyed. Our ScreenGui is mounted
-- beside it, or in PlayerGui if the original container is inaccessible.
local function mount(gui, requested)
    local function attempt(p)
        if typeof(p) ~= "Instance" then return false end
        local ok, result = pcall(function()
            if p:IsA("ScreenGui") then p = p.Parent end
            if not p or not (p:IsA("CoreGui") or p:IsA("PlayerGui")) then return false end
            gui.Parent = p
            return gui.Parent == p
        end)
        return ok and result == true
    end
    if requested and attempt(requested) then return true end
    if not requested then
        local ok, core = pcall(function() return game:GetService("CoreGui") end)
        if ok and attempt(core) then return true end
    end
    local player = Players.LocalPlayer
    if not player then return false end
    return attempt(player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5))
end

function OverlayUI:_connect(signal, cb)
    assert(not self._destroyed, "OverlayUI: destroyed")
    assert(#self._connections < MAX_CONNECTIONS, "OverlayUI: connection cap")
    local c = signal:Connect(cb)
    self._connections[#self._connections + 1] = c
    return c
end
function OverlayUI:_click(obj, cb)
    self:_connect(obj.Activated, function() if not self._destroyed then cb() end end)
end
function OverlayUI:_order()
    assert(not self._destroyed, "OverlayUI: destroyed")
    assert(self._count < MAX_ROWS, "OverlayUI: row cap")
    self._count = self._count + 1
    return self._count
end
function OverlayUI:_record(record)
    assert(#self._records < MAX_ROWS, "OverlayUI: getter cap")
    self._records[#self._records + 1] = record
    return record
end

-- BLOOD FLOW ---------------------------------------------------------------
-- Three asynchronous, engine-managed moving clouds, each with a small secondary
-- lobe. Concentric low-opacity discs approximate a feathered, irregular edge
-- without UIGradient, textures, rotated strips, or high-contrast outlines.
-- All 45 discs are constructed once; only three parent Positions are tweened.
-- No Lua animation loop and no animation work inside refresh().
local CLOUDS = {
    {color = Color3.fromRGB(119, 9, 24), size = 292, lobe = 202, dx = 55, dy = 56,
        from = scale(.02, .19), to = scale(.94, .66), duration = 13, opacity = .072},
    {color = Color3.fromRGB(78, 3, 20), size = 326, lobe = 218, dx = -59, dy = 46,
        from = scale(.97, .14), to = scale(.08, .83), duration = 19, opacity = .079},
    {color = Color3.fromRGB(143, 14, 32), size = 222, lobe = 154, dx = 38, dy = -50,
        from = scale(.72, .89), to = scale(.23, .28), duration = 23, opacity = .052},
}
local function discLobe(parent, color, diameter, x, y, layers, opacity, drift)
    for i = 1, math.min(layers, 10) do
        local t = (i - 1) / (layers - 1)
        local d = math.floor(diameter * (1 - .75 * t) + .5)
        -- Faint outer rings, slowly increasing density toward the core.
        local a = opacity * (.34 + .66 * t)
        local disc = frame(parent, {Name = "Veil", BackgroundColor3 = color,
            BackgroundTransparency = 1 - a, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(.5, .5),
            Position = offset(x + drift * t, y - drift * .35 * t),
            Size = offset(d, d), Active = false})
        round(disc)
    end
end
function OverlayUI:_createBloodFlow()
    -- Inset protects the rounded panel corners from rectangular clipping.
    -- Opaque header/footer margins and row surfaces keep the border quiet.
    local layer = frame(self._panel, {Name = "BloodFlow", BackgroundTransparency = 1,
        BorderSizePixel = 0, Position = offset(5, 5), Size = UDim2.new(1, -10, 1, -10),
        ClipsDescendants = true, Active = false, ZIndex = 1})
    self._bloodLayer = layer
    self._bloodTweens = {}
    for i = 1, 3 do
        local c = CLOUDS[i]
        local cloud = frame(layer, {Name = "Current" .. i, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = offset(1, 1), Position = c.from,
            ClipsDescendants = false, Active = false, ZIndex = i})
        discLobe(cloud, c.color, c.size, 0, 0, 10, c.opacity, 22)
        discLobe(cloud, c.color, c.lobe, c.dx, c.dy, 5, c.opacity * .58, -16)
        local tween = TweenService:Create(cloud,
            TweenInfo.new(c.duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Position = c.to})
        self._bloodTweens[i] = tween
    end
    self:_bloodRunning(self._open and not self._collapsed)
end
function OverlayUI:_bloodRunning(run)
    if not self._bloodTweens or self._bloodActive == run then return end
    self._bloodActive = run
    for i = 1, 3 do
        local t = self._bloodTweens[i]
        if t then if run then t:Play() else t:Pause() end end
    end
    write(self._bloodLayer, "Visible", run)
end
function OverlayUI:_destroyBloodFlow()
    if self._bloodTweens then
        for i = 1, 3 do
            local t = self._bloodTweens[i]
            if t then t:Cancel(); t:Destroy(); self._bloodTweens[i] = nil end
        end
    end
    self._bloodTweens = nil
    self._bloodActive = false
    if self._bloodLayer then self._bloodLayer:Destroy(); self._bloodLayer = nil end
end

-- SCROLL / GEOMETRY --------------------------------------------------------
function OverlayUI:_scroll(parent, pad)
    local scroll = make("ScrollingFrame", {Name = "Scroll", BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = scale(1, 1), CanvasSize = offset(0, 0),
        CanvasPosition = Vector2.new(0, 0), ScrollBarThickness = 3,
        ScrollBarImageColor3 = self._theme.muted, ScrollBarImageTransparency = .45,
        ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true, Active = true}, parent)
    pcall(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    local content = frame(scroll, {Name = "Content", BackgroundTransparency = 1,
        BorderSizePixel = 0, Position = offset(pad, pad), Size = UDim2.new(1, -(pad * 2 + 4), 0, 0)})
    local layout = make("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP)}, content)
    local function sync()
        if self._destroyed then return end
        local h = math.ceil(layout.AbsoluteContentSize.Y)
        write(content, "Size", UDim2.new(1, -(pad * 2 + 4), 0, h))
        write(scroll, "CanvasSize", offset(0, h + pad * 2))
        local maxY = math.max(0, h + pad * 2 - scroll.AbsoluteSize.Y)
        if scroll.CanvasPosition.Y > maxY then write(scroll, "CanvasPosition", Vector2.new(0, maxY)) end
    end
    self:_connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), sync)
    self:_connect(scroll:GetPropertyChangedSignal("AbsoluteSize"), sync)
    sync()
    return scroll, content
end
function OverlayUI:_layout()
    if self._destroyed then return end
    local v = self._root.AbsoluteSize
    if v.X <= 0 or v.Y <= 0 then return end
    local w, h = math.min(self._width, v.X), math.min(self._collapsed and HEADER or HEIGHT, v.Y)
    self._right = clamp(self._right, 0, math.max(0, v.X - w))
    self._top = clamp(self._top, 0, math.max(0, v.Y - h - 4))
    write(self._wrapper, "Size", offset(w, h))
    write(self._wrapper, "Position", UDim2.new(1, -self._right, 0, self._top))
    write(self._body, "Size", UDim2.new(1, 0, 0, math.max(0, h - HEADER)))
    write(self._body, "Visible", not self._collapsed)
    write(self._headerLine, "Visible", not self._collapsed)
    write(self._collapse, "Text", self._collapsed and "+" or "-")
end
function OverlayUI:_bindDrag()
    local header = self._header
    self:_connect(header.InputBegan, function(input)
        local kind = input.UserInputType
        if not self._open or self._drag or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then return end
        local p = Vector2.new(input.Position.X, input.Position.Y)
        if p.X >= header.AbsolutePosition.X + header.AbsoluteSize.X - 60 then return end
        self._drag = {input = input, kind = kind, start = p, right = self._right, top = self._top}
    end)
    self:_connect(UIS.InputChanged, function(input)
        -- Slider drags and header drags share one hook.
        if self._sliderDrag then
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                self._sliderDrag(input)
            end
            return
        end
        local d = self._drag
        if not d then return end
        if d.kind == Enum.UserInputType.Touch then
            if d.input ~= input then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - d.start
        self._right, self._top = d.right - delta.X, d.top + delta.Y
        self:_layout()
    end)
    self:_connect(UIS.InputEnded, function(input)
        if self._sliderDrag then self._sliderDrag = nil; return end
        local d = self._drag
        if d and (input == d.input or (d.kind == Enum.UserInputType.MouseButton1 and input.UserInputType == d.kind)) then
            self._drag = nil
        end
    end)
    self:_connect(UIS.WindowFocusReleased, function() self._drag = nil; self._sliderDrag = nil end)
end

function OverlayUI.new(options)
    options = options or {}
    local w = tonumber(options.width)
    local self = setmetatable({_theme = theme(options.theme), _width = finite(w) and clamp(w, 180, 960) or 260,
        _connections = {}, _records = {}, _lists = {}, _count = 0,
        _destroyed = false, _open = true, _collapsed = false, _right = 12, _top = 24}, OverlayUI)
    local t = self._theme
    local gui = make("ScreenGui", {Name = "OverlayUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = true})
    if not mount(gui, options.parent) then gui:Destroy(); error("OverlayUI: requires accessible client PlayerGui", 2) end
    self._gui = gui
    self._root = frame(gui, {Name = "Viewport", BackgroundTransparency = 1, BorderSizePixel = 0, Size = scale(1, 1), Active = false})
    self._wrapper = frame(self._root, {Name = "Wrapper", BackgroundTransparency = 1, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 24), Size = offset(self._width, HEIGHT), Active = false})
    local shadow = frame(self._wrapper, {Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = .6, BorderSizePixel = 0, Position = offset(0, 4), Size = scale(1, 1), ZIndex = 1, Active = false})
    corner(shadow, 10)
    self._panel = frame(self._wrapper, {Name = "Panel", BackgroundColor3 = t.bg, BorderSizePixel = 0,
        Size = scale(1, 1), ZIndex = 2, ClipsDescendants = true, Active = true})
    corner(self._panel, 10)
    stroke(self._panel, LINE, .25)
    self._header = frame(self._panel, {Name = "Header", BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, HEADER), ZIndex = 3, Active = true})
    local dot = frame(self._header, {BackgroundColor3 = t.accent, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 12, .5, 0), Size = offset(7, 7), Active = false})
    round(dot)
    local title = label(self._header, options.title or "PANEL", t.text, 12, BOLD)
    title.Position, title.Size = offset(26, 0), UDim2.new(1, -90, 1, 0)
    self._collapse = button(self._header, "-", t.muted, t.row, 14)
    self._collapse.Name = "Collapse"
    centeredRight(self._collapse, 34, 22, 22); corner(self._collapse, 6)
    local close = button(self._header, "X", t.muted, t.row, 10)
    close.Name = "Close"
    centeredRight(close, 8, 22, 22); corner(close, 6)
    self._headerLine = separator(self._header, UDim2.new(0, 8, 1, -1), UDim2.new(1, -16, 0, 1))
    self._headerLine.BackgroundTransparency = .35
    self._body = frame(self._panel, {Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = offset(0, HEADER), Size = UDim2.new(1, 0, 1, -HEADER), ZIndex = 3, ClipsDescendants = true})
    self._mainScroll, self._content = self:_scroll(self._body, 8)
    self:_click(close, function() self:setOpen(false) end)
    self:_click(self._collapse, function()
        self._collapsed = not self._collapsed
        self:_layout()
        self:_bloodRunning(self._open and not self._collapsed)
    end)
    self:_connect(self._root:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layout() end)
    self:_bindDrag()
    self:_layout()
    self:_createBloodFlow()
    return self
end

-- CONTROL BUILDERS ---------------------------------------------------------
function OverlayUI:_row(name, h, text)
    local r = frame(self._content, {Name = text and (text .. "Row") or name, LayoutOrder = self:_order(),
        BackgroundColor3 = self._theme.row, BackgroundTransparency = .22,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, h or ROW)})
    corner(r, 8)
    return r
end
function OverlayUI:_rowLabel(r, text)
    local l = label(r, text, self._theme.text, 11, FONT)
    l.Position, l.Size = offset(9, 0), UDim2.new(.48, -10, 1, 0)
    return l
end
function OverlayUI:_box(r, placeholder, numeric)
    local t = self._theme
    local b = make("TextBox", {Name = "Input", BackgroundColor3 = t.bg, BorderSizePixel = 0,
        Text = "", PlaceholderText = placeholder or "", PlaceholderColor3 = t.muted,
        TextColor3 = t.text, TextSize = 11, Font = numeric and MONO or FONT,
        TextXAlignment = numeric and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, MultiLine = false,
        ClearTextOnFocus = false, ClipsDescendants = true}, r)
    corner(b, 6); stroke(b, LINE, .25)
    make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, b)
    return b
end
function OverlayUI:section(text)
    local s = frame(self._content, {Name = "Section", LayoutOrder = self:_order(),
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 16)})
    local l = label(s, string.upper(tostring(text)), self._theme.accent, 10, BOLD)
    l.Position, l.Size = offset(2, 0), UDim2.new(1, -4, 0, 14)
    local line = separator(s, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
    line.BackgroundTransparency = .5
    return l
end

-- TOGGLE TWEENS ------------------------------------------------------------
local function stop(rec, key)
    local a = rec[key]
    if not a then return end
    rec[key] = nil
    a.connection:Disconnect()
    a.tween:Cancel()
    a.tween:Destroy()
end
local function tweenTo(ui, rec, key, object, goal, finish)
    stop(rec, key)
    local t = TweenService:Create(object, SWITCH, goal)
    local a = {tween = t}
    rec[key] = a
    a.connection = t.Completed:Connect(function()
        if rec[key] ~= a then return end
        rec[key] = nil
        a.connection:Disconnect()
        if not ui._destroyed then finish() end
        t:Destroy()
    end)
    t:Play()
end
function OverlayUI:_paintToggle(r, value)
    local previous = r.cached
    if previous == value then return end
    r.cached = value
    local t = self._theme
    local trackColor, knobColor, pos = value and t.accent or t.off, value and t.bg or t.muted, value and ON_POS or OFF_POS
    local function finishTrack() write(r.track, "BackgroundColor3", trackColor) end
    local function finishKnob() write(r.knob, "BackgroundColor3", knobColor); write(r.knob, "Position", pos) end
    if previous == nil or not self._open or self._collapsed then
        stop(r, "trackTween"); stop(r, "knobTween"); finishTrack(); finishKnob()
    else
        tweenTo(self, r, "trackTween", r.track, {BackgroundColor3 = trackColor}, finishTrack)
        tweenTo(self, r, "knobTween", r.knob, {BackgroundColor3 = knobColor, Position = pos}, finishKnob)
    end
end
function OverlayUI:toggle(text, get, set)
    local r, t = self:_row("Toggle", nil, text), self._theme
    self:_rowLabel(r, text).Size = UDim2.new(1, -65, 1, 0)
    local track = frame(r, {BackgroundColor3 = t.off, BorderSizePixel = 0, Active = false})
    centeredRight(track, 9, 36, 20); corner(track, 10)
    local knob = frame(track, {BackgroundColor3 = t.muted, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, .5), Position = OFF_POS, Size = offset(14, 14), Active = false})
    round(knob)
    local hit = make("TextButton", {Name = "tgl_" .. text, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, Size = scale(1, 1), ZIndex = 5, Active = true}, r)
    self:_record({kind = "toggle", get = get, track = track, knob = knob})
    self:_click(hit, function() set(not get()) end)
    return r
end
function OverlayUI:button(text, cb)
    local r, t = self:_row("Button", nil, text), self._theme
    local b = button(r, text, t.text, t.row, 11)
    b.Name = "btn_" .. text
    b.BackgroundTransparency, b.Size, b.TextXAlignment = 1, scale(1, 1), Enum.TextXAlignment.Left
    make("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 24)}, b)
    local arrow = label(r, ">", t.accent, 13, BOLD)
    centeredRight(arrow, 9, 12, ROW); arrow.TextXAlignment = Enum.TextXAlignment.Center
    self:_click(b, cb)
    return b
end
function OverlayUI:stepper(text, get, set, step, lo, hi)
    assert(finite(step) and step > 0 and finite(lo) and finite(hi) and lo <= hi, "OverlayUI: invalid stepper")
    local r, t = self:_row("Stepper", nil, text), self._theme
    self:_rowLabel(r, text)
    local controls = frame(r, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(.48, 0, 0, 0), Size = UDim2.new(.52, -7, 1, 0)})
    local minus = button(controls, "-", t.text, t.off, 13)
    minus.AnchorPoint, minus.Position, minus.Size = Vector2.new(0, .5), UDim2.new(0, 0, .5, 0), offset(22, 22)
    corner(minus, 6)
    local plus = button(controls, "+", t.text, t.off, 13)
    centeredRight(plus, 0, 22, 22); corner(plus, 6)
    local v = label(controls, "", t.text, 11, MONO)
    v.Position, v.Size, v.TextXAlignment = offset(26, 0), UDim2.new(1, -52, 1, 0), Enum.TextXAlignment.Right
    self:_record({kind = "step", get = get, value = v})
    local function change(delta)
        local current = get()
        if not finite(current) then return end
        local nextValue = clamp(current + delta, lo, hi)
        if nextValue ~= current then set(nextValue) end
    end
    self:_click(minus, function() change(-step) end)
    self:_click(plus, function() change(step) end)
    return r
end
function OverlayUI:textRow(text, get, set, lo, hi)
    assert(finite(lo) and finite(hi) and lo <= hi, "OverlayUI: invalid text bounds")
    local r = self:_row("TextRow", nil, text)
    self:_rowLabel(r, text)
    local b = self:_box(r, "", true)
    b.Name = "num_" .. text
    b.AnchorPoint, b.Position, b.Size = Vector2.new(1, .5), UDim2.new(1, -7, .5, 0), UDim2.new(.52, -7, 0, 22)
    local rec = self:_record({kind = "text", get = get, box = b, editing = false, dirty = false})
    self:_connect(b.Focused, function() rec.editing = true; rec.dirty = false end)
    self:_connect(b:GetPropertyChangedSignal("Text"), function() if rec.editing then rec.dirty = true end end)
    self:_connect(b.FocusLost, function()
        if self._destroyed then return end
        local dirty = rec.dirty
        rec.editing, rec.dirty = false, false
        local current, parsed = get(), tonumber(b.Text)
        if dirty and finite(parsed) then
            local n = clamp(parsed, lo, hi)
            if n ~= current then set(n) end
            current = get()
        end
        rec.cached = current
        write(b, "Text", numberText(current))
    end)
    return b
end
function OverlayUI:nameRow(text, placeholder, onSubmit)
    local r, t = self:_row("NameRow", nil, text), self._theme
    self:_rowLabel(r, text).Size = UDim2.new(.37, -10, 1, 0)
    local b = self:_box(r, placeholder, false)
    b.Name = "txt_" .. text
    b.Position, b.Size = UDim2.new(.37, 0, 0, 4), UDim2.new(.63, -34, 0, 22)
    local submit = button(r, "+", t.bg, t.accent, 14)
    centeredRight(submit, 7, 22, 22); corner(submit, 6)
    local function send()
        local value = b.Text:match("^%s*(.-)%s*$")
        if value and value ~= "" then write(b, "Text", ""); onSubmit(value) end
    end
    self:_connect(b.FocusLost, function(enter) if enter and not self._destroyed then send() end end)
    self:_click(submit, send)
    return b
end

-- SLIDER / STAT ------------------------------------------------------------
-- A drag slider in the same row grammar: click anywhere on the track, drag,
-- release. The value snaps to `step` so a weight can never land on 43.7.
function OverlayUI:slider(text, get, set, lo, hi, step)
    assert(finite(lo) and finite(hi) and lo < hi, "OverlayUI: invalid slider")
    local r, t = self:_row("Slider", nil, text), self._theme
    self:_rowLabel(r, text).Size = UDim2.new(.4, -10, 1, 0)
    local track = frame(r, {Name = text .. "Track", BackgroundColor3 = t.off, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(.4, 0, .5, 0),
        Size = UDim2.new(.6, -46, 0, 6), Active = true})
    corner(track, 3)
    local fill = frame(track, {Name = "Fill", BackgroundColor3 = t.accent, BorderSizePixel = 0,
        Size = scale(0, 1), Active = false})
    corner(fill, 3)
    local knob = frame(track, {Name = "Knob", BackgroundColor3 = t.text, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, 0, .5, 0),
        Size = offset(10, 14), Active = false})
    corner(knob, 5)
    local value = label(r, "", t.text, 10, MONO)
    value.Name = "Value"
    centeredRight(value, 7, 38, 20)
    value.TextXAlignment = Enum.TextXAlignment.Right
    self:_record({kind = "slider", get = get, fill = fill, knob = knob,
        value = value, lo = lo, hi = hi, step = step})
    local function applyFromX(x)
        local abs = track.AbsolutePosition or Vector2.new(0, 0)
        local size = track.AbsoluteSize or Vector2.new(0, 0)
        if size.X <= 0 then return end
        local f = clamp((x - abs.X) / size.X, 0, 1)
        local n = lo + f * (hi - lo)
        if finite(step) and step > 0 then n = math.floor(n / step + .5) * step end
        n = clamp(n, lo, hi)
        if n ~= get() then set(n) end
    end
    self:_connect(track.InputBegan, function(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        -- One drag owner for the panel: the shared InputChanged handler
        -- forwards moves while this is set, so ten sliders cost one hook.
        self._sliderDrag = function(move) applyFromX(move.Position.X) end
        applyFromX(input.Position.X)
    end)
    return r
end
-- Read-only number row: a gauge, not a control.
function OverlayUI:stat(text, get, format)
    local r, t = self:_row("Stat", nil, text), self._theme
    self:_rowLabel(r, text).Size = UDim2.new(.6, -10, 1, 0)
    local value = label(r, "", t.muted, 10, MONO)
    value.Name = "Value"
    value.AnchorPoint, value.Position = Vector2.new(1, .5), UDim2.new(1, -9, .5, 0)
    value.Size, value.TextXAlignment = UDim2.new(.4, -10, 1, 0), Enum.TextXAlignment.Right
    self:_record({kind = "stat", get = get, value = value, format = format})
    return r
end

-- POOLED LISTS -------------------------------------------------------------
function OverlayUI:list(name, height)
    assert(#self._lists < MAX_LISTS, "OverlayUI: list cap")
    local h = tonumber(height)
    local r, t = self:_row("List", finite(h) and clamp(h, 52, 360) or 110), self._theme
    local title = label(r, name, t.text, 11, BOLD)
    title.Position, title.Size = offset(9, 0), UDim2.new(1, -57, 0, 26)
    local badge = label(r, "0", t.accent, 10, MONO)
    badge.BackgroundTransparency, badge.BackgroundColor3 = 0, t.bg
    badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(1, 0), UDim2.new(1, -8, 0, 5), offset(35, 17)
    badge.TextXAlignment = Enum.TextXAlignment.Center; corner(badge, 6)
    local line = separator(r, offset(7, 26), UDim2.new(1, -14, 0, 1)); line.BackgroundTransparency = .3
    local body = frame(r, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = offset(3, 29), Size = UDim2.new(1, -6, 1, -33), ClipsDescendants = true})
    local scroll, content = self:_scroll(body, 3)
    local handle = setmetatable({_ui = self, _frame = r, _badge = badge, _scroll = scroll,
        _content = content, _pool = {}, _used = 0, _count = 0, _destroyed = false}, List)
    self._lists[#self._lists + 1] = handle
    return handle
end
function List:setCount(n)
    if self._destroyed or self._ui._destroyed then return end
    n = tonumber(n)
    n = finite(n) and math.max(0, math.floor(n)) or 0
    if n == self._count then return end
    self._count = n; write(self._badge, "Text", tostring(n))
end
function List:setVisible(v)
    if not self._destroyed and not self._ui._destroyed then write(self._frame, "Visible", v == true) end
end
function List:clear()
    if self._destroyed or self._ui._destroyed then return end
    for i = 1, math.min(self._used, MAX_ITEMS) do
        local slot = self._pool[i]
        slot.cb = nil; write(slot.row, "Visible", false)
    end
    self._used = 0; self:setCount(0)
end
function List:_allocate(index)
    local ui, t = self._ui, self._ui._theme
    local row = button(self._content, "", t.text, t.bg, 11)
    row.Name, row.LayoutOrder, row.Size, row.Visible = "Entry", index, UDim2.new(1, 0, 0, ROW), false
    row.BackgroundTransparency = .14; corner(row, 8)
    local l = label(row, "", t.text, 10, FONT)
    l.Position, l.Size = offset(7, 0), UDim2.new(1, -32, 1, 0)
    local x = label(row, "X", t.muted, 10, BOLD)
    x.BackgroundTransparency, x.BackgroundColor3 = 0, t.row
    centeredRight(x, 4, 22, 22); x.TextXAlignment = Enum.TextXAlignment.Center; corner(x, 6)
    local slot = {row = row, label = l, remove = x}
    ui:_click(row, function() if not self._destroyed and row.Visible and slot.cb then slot.cb() end end)
    self._pool[index] = slot
    return slot
end
function List:addRow(text, onRemove, onActivate)
    if self._destroyed or self._ui._destroyed then return nil end
    assert(self._used < MAX_ITEMS, "OverlayUI: list item cap")
    local index = self._used + 1
    local s = self._pool[index] or self:_allocate(index)
    local removable = type(onRemove) == "function"
    local activate = type(onActivate) == "function"
    -- A removable row removes on click; an activatable row toggles on click.
    s.cb = removable and onRemove or (activate and onActivate or nil)
    write(s.label, "Text", tostring(text)); write(s.remove, "Visible", removable)
    write(s.label, "Size", UDim2.new(1, removable and -32 or -14, 1, 0))
    write(s.row, "Active", removable or activate); write(s.row, "Visible", true)
    self._used = index; self:setCount(index)
    return s.row
end

-- PUBLIC REFRESH / LIFECYCLE -----------------------------------------------
function OverlayUI:refresh()
    if self._destroyed then return end
    local focused = UIS:GetFocusedTextBox() -- exactly one query
    for i = 1, math.min(#self._records, MAX_ROWS) do
        local r = self._records[i]
        local v = r.get() -- exactly one getter call per dynamic row
        if r.kind == "toggle" then
            self:_paintToggle(r, v == true)
        elseif r.kind == "step" then
            if r.cached ~= v then r.cached = v; write(r.value, "Text", numberText(v)) end
        elseif r.kind == "slider" then
            if r.cached ~= v then
                r.cached = v
                local span = r.hi - r.lo
                local f = span > 0 and clamp((v - r.lo) / span, 0, 1) or 0
                write(r.fill, "Size", scale(f, 1))
                write(r.knob, "Position", UDim2.new(f, 0, .5, 0))
                write(r.value, "Text", numberText(v))
            end
        elseif r.kind == "stat" then
            local s = r.format and r.format(v) or tostring(v)
            if r.cached ~= s then r.cached = s; write(r.value, "Text", s) end
        elseif r.kind == "text" and focused ~= r.box and not r.editing then
            if r.cached ~= v then r.cached = v; write(r.box, "Text", numberText(v)) end
        end
    end
end
function OverlayUI:isCollapsed()
    return self._collapsed == true
end
function OverlayUI:setOpen(open)
    if self._destroyed then return end
    open = open == true
    if self._open == open then return end
    self._open = open
    if not open then self._drag = nil end
    write(self._wrapper, "Visible", open)
    self:_bloodRunning(open and not self._collapsed)
end
function OverlayUI:isOpen() return not self._destroyed and self._open end
function OverlayUI:destroy()
    if self._destroyed then return end
    self._destroyed, self._open, self._drag = true, false, nil
    for i = 1, math.min(#self._connections, MAX_CONNECTIONS) do self._connections[i]:Disconnect() end
    for i = 1, math.min(#self._records, MAX_ROWS) do
        local r = self._records[i]
        if r.kind == "toggle" then stop(r, "trackTween"); stop(r, "knobTween") end
    end
    for i = 1, math.min(#self._lists, MAX_LISTS) do
        local l = self._lists[i]
        l._destroyed = true
        for j = 1, math.min(#l._pool, MAX_ITEMS) do l._pool[j].cb = nil end
        table.clear(l._pool)
        l._frame, l._badge, l._scroll, l._content = nil, nil, nil, nil
        l._used, l._count = 0, 0
    end
    self:_destroyBloodFlow()
    self._gui:Destroy()
    table.clear(self._connections); table.clear(self._records); table.clear(self._lists)
    self._gui, self._root, self._wrapper, self._panel, self._header = nil, nil, nil, nil, nil
    self._body, self._content, self._mainScroll, self._headerLine, self._collapse = nil, nil, nil, nil, nil
end

return OverlayUI

end)()

-- ══ KEY ═══════════════════════════════════════════════════════════════════
-- A gate, not a vault. All of this runs on the client, so anyone who can read
-- the script can patch it. What it buys is that a leaked copy is not a working
-- copy: the plaintext key never lives in the file, and remote mode can pin the
-- key to a hardware id.
local Key = (function()
	local M = {}

	local function trim(s)
		return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1"))
	end

	-- Arithmetic mix. No bitwise operators, so it runs on Luau, Lua 5.1 and
	-- Lua 5.3 without a branch. Doubles are exact to 2^53; the largest
	-- intermediate here is 2^32 * 131, far inside that.
	local function mix(s, seed)
		local h = seed % 4294967296
		for i = 1, #s do
			h = (h * 131 + string.byte(s, i) + 7) % 4294967296
		end
		return h
	end

	function M.hash(plain)
		local salted = Config.key.salt .. "|" .. tostring(plain)
		local a = mix(salted, 2166136261)
		local b = mix(salted .. "#" .. tostring(#salted), 16777619)
		return string.format("%08x%08x", a, b)
	end

	-- Console helper: Key.bake("my-new-key") prints the hash to paste into
	-- Config.key.hash. Exposed on getgenv().Finifugal.bake as well.
	function M.bake(plain)
		local h = M.hash(trim(plain))
		print(string.format("[OD] key %q -> hash %q", trim(plain), h))
		return h
	end

	function M.hwid()
		if M._hwid then return M._hwid end
		local id
		pcall(function()
			if type(gethwid) == "function" then id = tostring(gethwid()) end
		end)
		if not id then
			pcall(function()
				local svc = game:GetService("RbxAnalyticsService")
				id = tostring(svc:GetClientId())
			end)
		end
		if (not id or id == "") and type(readfile) == "function"
			and type(writefile) == "function" then
			local path = "CriminalityOD/hwid.txt"
			pcall(function()
				if type(isfile) == "function" and isfile(path) then id = readfile(path) end
			end)
			if not id or id == "" then
				id = string.format("fb%u%u", math.random(1, 2147483646),
					math.random(1, 2147483646))
				pcall(function() writefile(path, id) end)
			end
		end
		if not id or id == "" then id = "unsupported" end
		id = trim(id)
		M._hwid = id
		return id
	end

	function M.save(plain)
		if type(writefile) ~= "function" then return false end
		return pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function"
				and not isfolder("CriminalityOD") then
				makefolder("CriminalityOD")
			end
			writefile(Config.key.path, plain .. "\n" .. tostring(wallclock()))
		end)
	end

	local function readCache()
		if type(readfile) ~= "function" then return nil end
		local ok, raw = pcall(function()
			if type(isfile) == "function" and not isfile(Config.key.path) then return nil end
			return readfile(Config.key.path)
		end)
		if not ok or type(raw) ~= "string" or raw == "" then return nil end
		local plain, at = string.match(raw, "^(.-)\n(%d+)$")
		if plain then return plain, tonumber(at) end
		return trim(raw), nil
	end

	local function escape(s)
		s = string.gsub(tostring(s), "\\", "\\\\")
		s = string.gsub(s, '"', '\\"')
		return (string.gsub(s, "\n", "\\n"))
	end

	local function http(method, url, payload)
		local req
		if type(request) == "function" then req = request
		elseif type(http_request) == "function" then req = http_request
		elseif type(syn) == "table" and type(syn.request) == "function" then req = syn.request
		elseif type(http) == "table" and type(http.request) == "function" then req = http.request
		end
		if not req then
			-- Executors without request() still ship a GET path. The bare
			-- global is native on Matcha; the DataModel method is the fallback.
			if method == "GET" then
				if type(httpget) == "function" then
					local okh, plain = pcall(httpget, url)
					if okh and type(plain) == "string" and plain ~= "" then return plain end
				end
				local okg, body = pcall(function() return game:HttpGet(url) end)
				if okg and type(body) == "string" then return body end
			end
			return nil, "no request()"
		end
		local opts = { Url = url, Method = method, Timeout = 5 }
		if payload then
			opts.Headers = { ["Content-Type"] = "application/json" }
			opts.Body = payload
		end
		local ok, res = pcall(req, opts)
		if not ok or type(res) ~= "table" then return nil, "request failed" end
		local code = tonumber(res.StatusCode or res.Status) or 0
		if code ~= 200 then return nil, "http " .. tostring(code) end
		return tostring(res.Body or res.body or "")
	end

	local function post(url, payload) return http("POST", url, payload) end

	-- The status document. JSONDecode when the executor has it, a pattern
	-- reader for the three fields when it does not. No dependency either way.
	local function decode(raw)
		if HttpService and type(HttpService.JSONDecode) == "function" then
			local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and type(data) == "table" then
				-- A field of the wrong type is treated as absent: a document
				-- that reports a count under "keys" must not index a number.
				if type(data.keys) == "table" then
					local set = {}
					for _, k in ipairs(data.keys) do set[string.lower(tostring(k))] = true end
					data.keys = set
				else
					data.keys = nil
				end
				-- A public document carries hashes, never the keys themselves.
				if type(data.hashes) == "table" then
					local set = {}
					for _, h in ipairs(data.hashes) do set[string.lower(tostring(h))] = true end
					data.hashes = set
				else
					data.hashes = nil
				end
				return data
			end
		end

		local doc = { kill = string.find(raw, '"kill"%s*:%s*true') ~= nil }
		doc.reason = string.match(raw, '"reason"%s*:%s*"([^"]*)"')
		local block = string.match(raw, '"keys"%s*:%s*%[(.-)%]')
		if block then
			doc.keys = {}
			for k in string.gmatch(block, '"([^"]+)"') do doc.keys[string.lower(k)] = true end
		end
		local hblock = string.match(raw, '"hashes"%s*:%s*%[(.-)%]')
		if hblock then
			doc.hashes = {}
			for h in string.gmatch(hblock, '"([^"]+)"') do doc.hashes[string.lower(h)] = true end
		end
		return doc
	end

	function M.status()
		if Config.key.list == "" then return nil, "no list url" end
		local url = Config.key.list
		if Config.key.bust then
			url = url .. (string.find(url, "?", 1, true) and "&" or "?")
				.. "t=" .. tostring(wallclock())
		end
		local raw, err = http("GET", url)
		if not raw then return nil, err end
		return decode(raw)
	end

	function M.check(plain)
		plain = trim(plain)
		if plain == "" then return false, "enter a key" end

		if Config.key.hash == "" then
			warn("[OD] key gate has no hash baked — accepting any key")
			M.current = plain
			M.save(plain)
			return true, "unconfigured"
		end

		-- The status document comes first: a kill there outranks any key on
		-- this disk, and a key taken off the list stops working now.
		if Config.key.list ~= "" then
			local doc, err = M.status()
			if doc then
				if doc.kill then
					return false, (doc.reason and doc.reason ~= "") and doc.reason or "revoked"
				end
				if doc.hashes then
					if not doc.hashes[string.lower(M.hash(plain))] then
						return false, "not licensed"
					end
				elseif doc.keys then
					if not doc.keys[string.lower(plain)] then
						return false, "not on the list"
					end
				elseif M.hash(plain) ~= Config.key.hash then
					-- Kill-only document: it decides whether the gate opens,
					-- the baked hash still decides which key opens it.
					return false, "wrong key"
				end
				M.current = plain
				M.save(plain)
				return true, "licensed"
			end
			if Config.key.strict then
				-- A pulled plug is a 404; a dead executor is a timeout. Both
				-- mean the same thing to whoever is holding the panel.
				return false, "license server unreachable (" .. tostring(err) .. ")"
			end
		end

		if Config.key.provider == "remote" and Config.key.endpoint ~= "" then
			local body
			if HttpService and type(HttpService.JSONEncode) == "function" then
				local ok, encoded = pcall(function()
					return HttpService:JSONEncode({ key = plain, hwid = M.hwid() })
				end)
				if ok then body = encoded end
			end
			if not body then
				body = string.format('{"key":"%s","hwid":"%s"}',
					escape(plain), escape(M.hwid()))
			end

			local raw, err = post(Config.key.endpoint, body)
			if not raw then return false, err or "offline" end

			local good = string.find(raw, '"ok"%s*:%s*true') ~= nil
			if not good and HttpService and type(HttpService.JSONDecode) == "function" then
				local okd, data = pcall(function() return HttpService:JSONDecode(raw) end)
				good = okd and type(data) == "table" and data.ok == true
			end
			if not good then return false, "rejected" end

			M.current = plain
			M.save(plain)
			return true, "licensed"
		end

		if M.hash(plain) ~= Config.key.hash then return false, "wrong key" end
		M.current = plain
		M.save(plain)
		return true, "ok"
	end

	-- True when the cheat may start. A cached key is re-hashed every load, so
	-- rebaking the file invalidates every copy that was handed out. With a
	-- list configured the document gets the last word, cached key or not.
	function M.unlocked()
		if not Config.key.enabled then return true end
		local plain, at = readCache()
		if not plain then return false end
		if Config.key.hash == "" then return true end

		if Config.key.list ~= "" then
			local doc = M.status()
			if doc then
				if doc.kill then return false end
				if doc.hashes then
					if not doc.hashes[string.lower(M.hash(plain))] then return false end
				elseif doc.keys then
					if not doc.keys[string.lower(plain)] then return false end
				elseif M.hash(plain) ~= Config.key.hash then
					return false
				end
				M.current = plain
				return true
			end
			if Config.key.strict then return false end
		end

		if Config.key.provider == "remote" and Config.key.endpoint ~= "" then
			if at and wallclock() - at < Config.key.ttl then
				M.current = plain
				return true
			end
			return (M.check(plain))
		end

		M.current = plain
		return M.hash(plain) == Config.key.hash
	end

	-- One look at the document against the key in hand. true = stop now.
	function M.pollOnce()
		if Config.key.list == "" then return false end
		local doc = M.status()
		if not doc then
			return Config.key.strict, "offline"
		end
		if doc.kill then
			return true, (doc.reason and doc.reason ~= "") and doc.reason or "revoked"
		end
		if doc.hashes then
			if M.current and not doc.hashes[string.lower(M.hash(M.current))] then
				return true, "key removed"
			end
		elseif doc.keys and M.current and not doc.keys[string.lower(M.current)] then
			return true, "key removed"
		end
		return false
	end

	-- Poll loop. Its own thread, so a slow request cannot stall the render
	-- callback; the callback it calls is the script's own unload.
	function M.watch(onKill)
		if Config.key.list == "" or (Config.key.poll or 0) <= 0 then return end
		local taskLib = type(task) == "table" and task or nil
		local nap = taskLib and taskLib.wait or wait
		if type(nap) ~= "function" then return end
		local spawner = taskLib and taskLib.spawn
		if type(spawner) ~= "function" then
			spawner = function(fn) coroutine.wrap(fn)() end
		end

		local stop = false
		M.stopWatch = function() stop = true end

		spawner(function()
			while not stop do
				nap(Config.key.poll)
				if stop then return end
				local kill, why = M.pollOnce()
				if kill then
					stop = true
					if onKill then onKill(why) end
					return
				end
			end
		end)
	end

	return M
end)()

if CAPS.genv or GENV then
	GENV.Finifugal.bake = Key.bake
	GENV.Finifugal.key = Key
end

-- The gate is a second OverlayUI panel with nothing on it but the key row.
-- On a good key it destroys itself and calls the builder it was handed; the
-- cheat body does not exist until then, so a locked load binds no render step
-- and draws nothing.
local function keyGate(onUnlock)
	local status = "locked"
	local uiKey

	-- Matcha has no Instance.new, so the gate cannot be a panel there. One
	-- native tab, one field, one button. On a good key the tab is dropped and
	-- the body is built exactly as it is on the overlay path.
	if MATCHA_UI then
		local typed = ""
		local opened = false
		local spawner = (type(task) == "table" and type(task.spawn) == "function")
			and task.spawn or (type(spawn) == "function" and spawn or function(fn) fn() end)
		local okTab, tabErr = pcall(function()
			UI.AddTab("Finifugal key", function(tab)
				if opened then return end
				local s = tab:Section("LICENSE", "Left")
				s:InputText("f2_key", "Key", "", function(text) typed = text end)
				s:Button("Unlock", function()
					-- The fetch is synchronous in this VM; run it off the frame
					-- that drew the button so the menu does not freeze.
					spawner(function()
						local plain = typed
						local okv, got = pcall(UI.GetValue, "f2_key")
						if okv and type(got) == "string" and got ~= "" then plain = got end
						local good, msg = Key.check(plain)
						status = tostring(msg or (good and "ok" or "rejected"))
						if good then
							opened = true
							pcall(UI.RemoveTab, "Finifugal key")
							onUnlock()
						else
							print("[OD] key: " .. status)
						end
					end)
				end)
				s:Tip("issued with this copy")
				s:Text("State: " .. status)
			end)
		end)
		if not okTab then
			warn("[OD] key gate failed to draw: " .. tostring(tabErr))
			onUnlock()
		end
		return
	end

	local ok, err = pcall(function()
		uiKey = OverlayUI.new({
			title = "FINIFUGAL 2.0",
			width = 268,
			theme = { accent = Color3.fromRGB(229, 83, 100) },
		})

		uiKey:section("LICENSE")

		local typed = ""
		local box = uiKey:nameRow("Key", "XXXX-XXXX-XXXX", function(value)
			typed = value
		end)

		uiKey:button("Unlock", function()
			-- Read the box live (the click can land with focus still in it),
			-- but fall back to the submitted value: nameRow clears the box
			-- after a submit, so an Enter-then-Unlock would read "".
			local value = box and box.Text or ""
			if value == "" then value = typed end
			local good, msg = Key.check(value)
			status = msg
			if good then
				uiKey:destroy()
				onUnlock()
			else
				-- The library never repaints itself; the cheat's render loop
				-- does that. The gate has no loop, so it refreshes on action.
				uiKey:refresh()
			end
		end)

		uiKey:button("Copy HWID", function()
			if CAPS.clipboard then
				pcall(setclipboard, Key.hwid())
				status = "hwid copied"
			else
				status = Key.hwid()
			end
			uiKey:refresh()
		end)

		uiKey:section("STATUS")
		uiKey:stat("State", function() return status end)
		uiKey:stat("HWID", function() return string.sub(Key.hwid(), 1, 18) end)
		uiKey:stat("Render", function() return CAPS.drawing and "drawing" or "frames" end)

		uiKey:refresh()
	end)

	if not ok then
		warn("[OD] key gate failed to draw: " .. tostring(err))
		warn("[OD] starting unlocked — fix the panel, or set Config.key.enabled = false")
		onUnlock()
	end
end

-- Everything below is the cheat. It lives in a function so the gate can hold
-- it back: no render bind, no Drawing object, no menu until the key passes.
local function main()
-- The menu: one panel, built once. The library owns layout and paint; this
-- block owns the config wiring and the two pooled lists.
-- Blood Flow edition: 45 discs are built once and three parent positions are
-- tweened by the engine. Nothing here animates.

local ui

-- ══ KEYBINDS ═══════════════════════════════════════════════════════════════
-- Every control key is a Config field; the menu only changes what the input
-- handler already reads. A pending bind captures the next key press, rejects a
-- duplicate, persists the layout, and repaints the rows from Config.
local BIND_PATH = "CriminalityOD/keybinds.txt"
local BIND_FIELDS = { "distance", "chams", "box", "items", "tracer", "name" }

local binding = nil -- the row waiting for a key
local bindRows = {}
local bindDefaults

local function keyName(k)
	if k == nil then return "unbound" end
	local n = k.Name
	if type(n) == "string" then return n end
	return tostring(k)
end

local function keyFromName(name)
	if type(name) ~= "string" or name == "" then return nil end
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	if ok and k ~= nil and k ~= Enum.KeyCode.Unknown then return k end
	return nil
end

local function hotkeyOf(field)
	for key, name in pairs(Config.esp.hotkeys) do
		if name == field then return key end
	end
	return nil
end

local function setHotkey(field, key)
	for k, name in pairs(Config.esp.hotkeys) do
		if name == field then Config.esp.hotkeys[k] = nil end
	end
	if key ~= nil then Config.esp.hotkeys[key] = field end
end

local function setMenuKey(key)
	Config.ui.key = key
	table.clear(UI_KEYS)
	UI_KEYS[key] = true
	-- Ñ stays a second alias on the layouts that have it.
	pcall(function() UI_KEYS[Enum.KeyCode["Ñ"]] = true end)
end

local function saveBinds()
	if type(writefile) ~= "function" then return end
	local lines = {
		"menu=" .. keyName(Config.ui.key),
		"esp=" .. keyName(Config.esp.toggleKey),
		"aim=" .. keyName(Config.aim.toggleKey),
		"hitbox=" .. keyName(Config.aim.hitboxKey),
	}
	for _, field in ipairs(BIND_FIELDS) do
		local key = hotkeyOf(field)
		if key ~= nil then lines[#lines + 1] = "hk_" .. field .. "=" .. keyName(key) end
	end
	pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function"
			and not isfolder("CriminalityOD") then
			makefolder("CriminalityOD")
		end
		writefile(BIND_PATH, table.concat(lines, "\n"))
	end)
end

local function loadBinds()
	if type(readfile) ~= "function" then return end
	local ok, raw = pcall(function()
		if type(isfile) == "function" and not isfile(BIND_PATH) then return nil end
		return readfile(BIND_PATH)
	end)
	if not ok or type(raw) ~= "string" or raw == "" then return end

	local seen = {}
	for line in string.gmatch(raw, "[^\r\n]+") do
		local id, name = string.match(line, "^([%w_]+)%s*=%s*(.+)$")
		local key = id and keyFromName(name)
		if key ~= nil and not seen[key] then
			seen[key] = true
			if id == "menu" then setMenuKey(key)
			elseif id == "esp" then Config.esp.toggleKey = key
			elseif id == "aim" then Config.aim.toggleKey = key
			elseif id == "hitbox" then Config.aim.hitboxKey = key
			elseif string.sub(id, 1, 3) == "hk_" then
				setHotkey(string.sub(id, 4), key)
			end
		end
	end
end

local function snapshotBinds()
	local snap = {
		menu = Config.ui.key,
		esp = Config.esp.toggleKey,
		aim = Config.aim.toggleKey,
		hitbox = Config.aim.hitboxKey,
		hotkeys = {},
	}
	for _, field in ipairs(BIND_FIELDS) do snap.hotkeys[field] = hotkeyOf(field) end
	return snap
end

bindDefaults = snapshotBinds()
loadBinds()

local function bindText(label, key)
	return string.format("%s   [%s]", label, keyName(key))
end

local function paintBinds()
	for _, row in ipairs(bindRows) do
		row.button.Text = bindText(row.label, row.get())
	end
	binding = nil
end

local function addBind(label, get, set)
	local row = { label = label, get = get, set = set }
	row.button = ui:button(label, function()
		binding = row
		row.button.Text = label .. "   [press a key]"
	end)
	bindRows[#bindRows + 1] = row
	return row
end

local function applyBind(row, key)
	for _, other in ipairs(bindRows) do
		if other ~= row and other.get() == key then
			binding = nil
			row.button.Text = row.label .. "   [in use]"
			warn(string.format("[OD] %s is already bound to %s", keyName(key), other.label))
			return false
		end
	end
	row.set(key)
	saveBinds()
	paintBinds()
	print(string.format("[OD] bound %s -> %s", row.label, keyName(key)))
	return true
end

local function resetBinds()
	setMenuKey(bindDefaults.menu)
	Config.esp.toggleKey = bindDefaults.esp
	Config.aim.toggleKey = bindDefaults.aim
	Config.aim.hitboxKey = bindDefaults.hitbox
	for _, field in ipairs(BIND_FIELDS) do
		setHotkey(field, bindDefaults.hotkeys[field])
	end
	saveBinds()
	paintBinds()
	print("[OD] keybinds reset")
end

-- PERF — the meter costs one clock read at each end of the frame, nothing
-- when it is off. Everything is EMA so one hitch does not stick in the readout.
local perf = { ema = 0, peak = 0, fps = 0, reportAt = -1e9 }

local function activeDraws()
	local n = 0
	for _, o in pairs(esp) do
		if o.on then n = n + 1 end
	end
	return n
end

local function perfSample(now, dt, cost)
	perf.ema = perf.ema * 0.88 + cost * 0.12
	if cost > perf.peak then perf.peak = cost end
	perf.peak = perf.peak * 0.995
	if dt and dt > 0 then
		perf.fps = perf.fps * 0.88 + (1 / dt) * 0.12
	end

	if now - perf.reportAt >= Config.perf.report then
		perf.reportAt = now
		print(string.format("[OD] frame %.2f ms  peak %.2f ms  %.0f fps  draws %d  proj %d  reuse %d",
			perf.ema * 1000, perf.peak * 1000, perf.fps, activeDraws(),
			stats.projections, stats.reused))
	end
end

local exList, poiList
local exSeen, poiSeen = -1, -1
local poiShownAt = -1e9

local function rebuildExclusions()
	if not exList then return end
	exSeen = excludeVersion
	exList:clear()

	local names = exclusionList()
	local shown = 0

	for _, name in ipairs(names) do
		if shown >= 40 then break end
		shown = shown + 1

		local button = exList:addRow(name, function()
			removeExclusion(name)
			rebuildExclusions()
		end)

		if button then button.Name = "exc_" .. name end
	end

	exList:setCount(shown)
end

local function rebuildPoi()
	if not poiList then return end
	poiSeen = poi.version
	poiShownAt = clock()
	poiList:clear()

	local names = {}
	for name, rec in pairs(poi.names) do
		names[#names + 1] = { name = name, rec = rec }
	end

	table.sort(names, function(a, b)
		local aa = a.rec and a.rec.auto and 1 or 0
		local ba = b.rec and b.rec.auto and 1 or 0
		if aa ~= ba then return aa > ba end
		return a.name < b.name
	end)

	local shown = 0

	for _, entry in ipairs(names) do
		if shown >= 40 then break end
		shown = shown + 1

		local on = Config.poi.show[entry.name] and true or false

		local button = poiList:addRow((on and "[x] " or "[ ] ") .. entry.name, nil, function()
			Config.poi.show[entry.name] = not (Config.poi.show[entry.name] and true or false)
			poi.lastDone = -1e9
			rebuildPoi()
		end)

		if button then button.Name = "poi_" .. entry.name end
	end

	poiList:setCount(shown)
end

local function refreshMenu()
	if not ui then return end
	-- A closed or collapsed panel has nothing to paint. The getter sweep is
	-- ~40 bridge reads at 10 Hz; on a slow VM that is the whole frame.
	if not (ui:isOpen() and not ui:isCollapsed()) then return end
	ui:refresh()

	if exSeen ~= excludeVersion then rebuildExclusions() end

	if poiList and poiSeen ~= poi.version
		and (poiList._used == 0 or clock() - poiShownAt > 0.5 or poiShownAt < 0) then
		rebuildPoi()
	end
end

-- ══ MATCHA UI ══════════════════════════════════════════════════════════════
-- The native binding. Matcha's tab callback runs once per frame, so every
-- widget is declared with a stable id and writes Config directly. Keybinds are
-- native widgets; the frame loop reads them back by id.
local function matchaMenu()
	if not MATCHA_UI then return false end

	-- A re-exec would otherwise stack a second Finifugal tab on the old one.
	if type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Finifugal")
	end

	local function paint(tab)
		local L = tab:Section("Visuals", "Left")

		L:Toggle("f2_esp", "ESP", Config.esp.enabled, function(v)
			Config.esp.enabled = v; espDirty = true
		end)
		-- Keybind sits directly after a Toggle; RShift = 0xA1.
		L:Keybind("f2_esp_kb", 0xA1, "toggle")
		L:Toggle("f2_box", "Box", Config.esp.box, function(v)
			Config.esp.box = v; espDirty = true
		end)
		L:ColorPicker("f2_cvis", Config.esp.visibleColor.R, Config.esp.visibleColor.G,
			Config.esp.visibleColor.B, 1, function(c)
				Config.esp.visibleColor = c; espDirty = true
			end)
		L:Toggle("f2_name", "Name", Config.esp.name, function(v)
			Config.esp.name = v; espDirty = true
		end)
		L:Toggle("f2_hp", "Health bar", Config.esp.health, function(v)
			Config.esp.health = v; espDirty = true
		end)
		L:Toggle("f2_dist", "Distance", Config.esp.distance, function(v)
			Config.esp.distance = v; espDirty = true
		end)

		local E = tab:Section("ESP detail", "Left")

		E:Toggle("f2_tracer", "Tracer", Config.esp.tracer, function(v)
			Config.esp.tracer = v; espDirty = true
		end)
		E:ColorPicker("f2_chid", Config.esp.hiddenColor.R, Config.esp.hiddenColor.G,
			Config.esp.hiddenColor.B, 1, function(c)
				Config.esp.hiddenColor = c; espDirty = true
			end)
		E:Toggle("f2_dot", "Head dot", Config.esp.headDot, function(v)
			Config.esp.headDot = v; espDirty = true
		end)
		E:Toggle("f2_items", "Items", Config.esp.items, function(v)
			Config.esp.items = v; espDirty = true
		end)
		E:Toggle("f2_team", "Team check", Config.esp.teamCheck, function(v)
			Config.esp.teamCheck = v
		end)
		E:SliderInt("f2_range", "ESP range", 50, 5000, Config.esp.range, function(v)
			Config.esp.range = v; espDirty = true
		end)
		E:SliderInt("f2_text", "Text size", 8, 28, Config.esp.textSize, function(v)
			Config.esp.textSize = v; espDirty = true
		end)
		E:SliderInt("f2_thick", "Box width", 1, 5, Config.esp.boxThickness, function(v)
			Config.esp.boxThickness = v; espDirty = true
		end)
		E:Text("Wallhack needs Instance.new; use the desktop executor.")

		local A = tab:Section("Aim", "Left")

		A:Toggle("f2_aim", "Aim + fire", Config.aim.enabled, function(v)
			Config.aim.enabled = v
		end)
		A:Keybind("f2_aim_kb", 0x4B, "toggle")
		A:Combo("f2_style", "Style", { "soft", "snap" },
			Config.aim.style == "snap" and 1 or 0, function(idx)
				Config.aim.style = (idx == 1) and "snap" or "soft"
			end)
		A:Combo("f2_mode", "Aim source", { "auto", "cursor", "camera" },
			Config.aim.mode == "cursor" and 1 or (Config.aim.mode == "camera" and 2 or 0),
			function(idx)
				Config.aim.mode = ({ "auto", "cursor", "camera" })[idx + 1] or "auto"
			end)
		A:SliderInt("f2_fov", "FOV", 10, 800, Config.aim.fov, function(v)
			Config.aim.fov = v; Config.aim.showFov = true
		end)
		A:SliderInt("f2_arange", "Aim range", 20, 1000, Config.aim.range, function(v)
			Config.aim.range = v
		end)
		A:SliderInt("f2_speed", "Slew px/s", 100, 6000, Config.aim.maxSpeed, function(v)
			Config.aim.maxSpeed = v
		end)
		A:SliderInt("f2_drift", "Soft drift", 0, 40, Config.aim.softDrift, function(v)
			Config.aim.softDrift = v
		end)
		A:SliderInt("f2_zone", "Soft zone", 10, 400, Config.aim.softZone, function(v)
			Config.aim.softZone = v
		end)
		A:SliderFloat("f2_smooth", "Smoothing", 0.01, 1.0, Config.aim.smoothness, "%.2f",
			function(v) Config.aim.smoothness = v end)
		A:SliderFloat("f2_gain", "Snap gain", 0.05, 1.0, Config.aim.gain, "%.2f",
			function(v) Config.aim.gain = v end)
		A:SliderFloat("f2_dead", "Deadzone", 0.0, 5.0, Config.aim.deadzone, "%.1f",
			function(v) Config.aim.deadzone = v end)
		A:SliderFloat("f2_lead", "Velocity lead", 0.0, 0.3, Config.aim.prediction, "%.3f",
			function(v) Config.aim.prediction = v end)
		A:Toggle("f2_autolead", "Lead from ping", Config.aim.autoLead,
			function(v) Config.aim.autoLead = v end)
		A:Toggle("f2_hit", "Head / chest", Config.aim.hitbox == "head", function(v)
			Config.aim.hitbox = v and "head" or "chest"
		end)
		A:Toggle("f2_visible", "Visible only", Config.aim.visibleOnly, function(v)
			Config.aim.visibleOnly = v
		end)
		A:Toggle("f2_rnd", "Part randomizer", Config.aim.randomizer, function(v)
			Config.aim.randomizer = v
		end)
		A:SliderInt("f2_rhead", "Roll: head %", 0, 100, Config.aim.rnd.head,
			function(v) Config.aim.rnd.head = v end)
		A:SliderInt("f2_rchest", "Roll: chest %", 0, 100, Config.aim.rnd.chest,
			function(v) Config.aim.rnd.chest = v end)
		A:SliderInt("f2_rarm", "Roll: arm %", 0, 100, Config.aim.rnd.arm,
			function(v) Config.aim.rnd.arm = v end)
		A:SliderInt("f2_rleg", "Roll: leg %", 0, 100, Config.aim.rnd.leg,
			function(v) Config.aim.rnd.leg = v end)

		local C = tab:Section("Combat", "Right")

		C:Toggle("f2_auto", "Auto fire", Config.combat.autoShoot,
			function(v) Config.combat.autoShoot = v end)
		C:Toggle("f2_hold", "Hold LMB", Config.combat.holdFire,
			function(v) Config.combat.holdFire = v end)
		C:SliderFloat("f2_rate", "Fire rate", 0.02, 0.50, Config.combat.fireRate, "%.2f",
			function(v) Config.combat.fireRate = v end)
		C:Toggle("f2_los", "Require line of sight", Config.combat.requireLOS,
			function(v) Config.combat.requireLOS = v end)
		C:SliderFloat("f2_delay", "Trigger delay", 0.0, 0.30, Config.combat.triggerDelay, "%.2f",
			function(v) Config.combat.triggerDelay = v end)
		C:SliderInt("f2_align", "Start px", 0, 40, Config.combat.alignPx,
			function(v) Config.combat.alignPx = v end)
		C:SliderInt("f2_release", "Keep px", 0, 60, Config.combat.releasePx,
			function(v) Config.combat.releasePx = v end)
		C:Toggle("f2_recoil", "Recoil control", Config.combat.recoilControl,
			function(v) Config.combat.recoilControl = v end)
		C:SliderFloat("f2_ralpha", "Recoil strength", 0.0, 1.0, Config.combat.recoilAlpha, "%.2f",
			function(v) Config.combat.recoilAlpha = v end)

		local M = tab:Section("Map", "Right")

		M:Toggle("f2_poi", "Markers", Config.poi.enabled,
			function(v) Config.poi.enabled = v end)
		M:Toggle("f2_loot", "Dropped tools", Config.poi.loot,
			function(v) Config.poi.loot = v end)
		M:SliderInt("f2_pdist", "Marker range", 100, 20000, Config.poi.maxDistance,
			function(v) Config.poi.maxDistance = v end)
		M:SliderInt("f2_pmax", "Max markers", 1, 200, Config.poi.maxMarkers,
			function(v) Config.poi.maxMarkers = v end)
		M:SliderInt("f2_prefresh", "Rescan every s", 2, 60, Config.poi.refresh,
			function(v) Config.poi.refresh = v end)
		M:SliderInt("f2_psize", "Marker text", 8, 24, Config.poi.textSize,
			function(v) Config.poi.textSize = v end)
		M:Button("Rescan map", function()
			poi.lastDone = -1e9
			poiStart()
			rebuildPoi()
		end)
		M:Button("Save cfg", function()
			local ok, err = cfgSave()
			print("[OD] cfg " .. (ok and ("written: " .. CFG_PATH) or ("failed: " .. tostring(err))))
		end)
		M:Button("Show dealers + armory", function()
			for name in pairs(poi.names) do
				if poiIsKeyword(name) then Config.poi.show[name] = true end
			end
			for _, kw in ipairs(Config.poi.armoryKeys) do Config.poi.show[kw] = true end
			for _, kw in ipairs(Config.poi.dealerKeys) do Config.poi.show[kw] = true end
			Config.poi.enabled = true
			poi.lastDone = -1e9
			poiStart()
			rebuildPoi()
		end)

		local P = tab:Section("Performance", "Right")

		P:Toggle("f2_meter", "Frame meter", Config.perf.meter,
			function(v) Config.perf.meter = v end)
		P:SliderInt("f2_poihz", "Marker rate Hz", 5, 60, Config.perf.poiHz,
			function(v) Config.perf.poiHz = v end)
		P:Toggle("f2_debug", "Aim debug", Config.aim.debug,
			function(v) Config.aim.debug = v end)
		P:Text("RShift ESP · K aim · H head/chest")
	end

	local ok, err = pcall(function()
		UI.AddTab("Finifugal", paint)
	end)
	if not ok then
		warn("[OD] matcha tab failed: " .. tostring(err))
		return false
	end
	return true
end

local function buildUi()
	if not Config.ui.enabled then return end

	if MATCHA_UI then return matchaMenu() end

	local ok, err = pcall(function()
		ui = OverlayUI.new({
			title = "FINIFUGAL 2.0",
			width = 268,
			-- The library ships a green accent; the blood flow reads better
			-- against its own crimson, same as the library's demo.
			theme = { accent = Color3.fromRGB(229, 83, 100) },
		})

		-- visuals ------------------------------------------------------
		ui:section("VISUALS")

		ui:toggle("ESP", function() return Config.esp.enabled end,
			function(v) Config.esp.enabled = v; espDirty = true end)

		ui:toggle("Wallhack", function() return Config.esp.chams end,
			function(v) Config.esp.chams = v; espDirty = true end)

		ui:textRow("ESP range", function() return Config.esp.range end,
			function(v) Config.esp.range = v; espDirty = true end, 50, 5000)

		ui:toggle("Team check", function() return Config.esp.teamCheck end,
			function(v) Config.esp.teamCheck = v; espDirty = true end)

		ui:button("Draw fix", function()
			-- Toggle the mode, and never assign the helper's return into the
			-- config: 0 and 1 are the only two states alpha() understands.
			setOpaque(Config.render.opaque == 1 and 0 or 1)
		end)

		ui:toggle("Box", function() return Config.esp.box end,
			function(v) Config.esp.box = v; espDirty = true end)

		ui:toggle("Name", function() return Config.esp.name end,
			function(v) Config.esp.name = v; espDirty = true end)

		ui:toggle("Distance", function() return Config.esp.distance end,
			function(v) Config.esp.distance = v; espDirty = true end)

		ui:toggle("Tracer", function() return Config.esp.tracer end,
			function(v) Config.esp.tracer = v; espDirty = true end)

		ui:toggle("Head dot", function() return Config.esp.headDot end,
			function(v) Config.esp.headDot = v; espDirty = true end)

		ui:toggle("Items", function() return Config.esp.items end,
			function(v) Config.esp.items = v; espDirty = true end)

		-- aim ----------------------------------------------------------
		ui:section("AIM")

		ui:toggle("Aimbot", function() return aimActive end,
			function(v) aimActive = v end)

		ui:toggle("Auto-fire", function() return Config.combat.autoShoot end,
			function(v) Config.combat.autoShoot = v end)

		ui:toggle("Recoil control", function() return Config.combat.recoilControl end,
			function(v) Config.combat.recoilControl = v end)

		ui:stepper("FOV", function() return Config.aim.fov end,
			function(v) Config.aim.fov = v end, 5, 40, 600)

		ui:stepper("Range", function() return Config.aim.range end,
			function(v) Config.aim.range = v end, 25, 40, 900)

		ui:stepper("Lead ms", function()
			return math.floor(Config.aim.prediction * 1000 + 0.5)
		end, function(v)
			Config.aim.prediction = v / 1000
		end, 20, 0, 300)

		ui:toggle("Lead from ping", function() return Config.aim.autoLead end,
			function(v) Config.aim.autoLead = v end)

		ui:button("Save cfg", function()
			local ok, err = cfgSave()
			print("[OD] cfg " .. (ok and ("written: " .. CFG_PATH) or ("failed: " .. tostring(err))))
		end)

		local styleButton
		local function paintStyle()
			local soft = Config.aim.style ~= "snap"
			styleButton.Text = string.format("Aim style: %s", soft and "soft" or "snap")
			styleButton.TextColor3 = soft and ui._theme.accent or ui._theme.text
		end
		styleButton = ui:button("Aim style", function()
			Config.aim.style = (Config.aim.style == "snap") and "soft" or "snap"
			paintStyle()
		end)
		paintStyle()

		local hitButton
		local function paintHitbox()
			local head = Config.aim.hitbox ~= "chest"
			hitButton.Text = string.format("Hitbox: %s   [H]", head and "head" or "chest")
			hitButton.TextColor3 = head and ui._theme.accent or ui._theme.text
		end
		hitButton = ui:button("Hitbox", function()
			setHitbox(Config.aim.hitbox == "chest" and "head" or "chest")
			paintHitbox()
		end)
		paintHitbox()

		-- part randomizer: weighted body-part roll per hold window ----------
		ui:toggle("Part randomizer", function() return Config.aim.randomizer end,
			function(v)
				Config.aim.randomizer = v
				-- a fresh roll on the next aim tick, not a stale window from
				-- whenever it was last on
				for _, t in pairs(track) do t.rnd = nil end
			end)

		ui:slider("Head %", function() return Config.aim.rnd.head end,
			function(v) Config.aim.rnd.head = v end, 0, 100, 1)

		ui:slider("Chest %", function() return Config.aim.rnd.chest end,
			function(v) Config.aim.rnd.chest = v end, 0, 100, 1)

		ui:slider("Arms %", function() return Config.aim.rnd.arm end,
			function(v) Config.aim.rnd.arm = v end, 0, 100, 1)

		ui:slider("Legs %", function() return Config.aim.rnd.leg end,
			function(v) Config.aim.rnd.leg = v end, 0, 100, 1)

		ui:slider("Re-roll ms", function()
			return math.floor(Config.aim.rndHold * 1000 + 0.5)
		end, function(v) Config.aim.rndHold = v / 1000 end, 0, 2000, 25)

		ui:slider("Jitter studs", function() return Config.aim.rndJitter end,
			function(v) Config.aim.rndJitter = v end, 0, 1.5, 0.05)

		-- H flips the same value; keep the label honest without polling.
		local hitSeen = Config.aim.hitbox
		ui:stepper("Soft px/s", function() return Config.aim.maxSpeed end,
			function(v) Config.aim.maxSpeed = v end, 200, 400, 8000)

		ui:stepper("Drift px", function() return Config.aim.softDrift end,
			function(v) Config.aim.softDrift = v end, 2, 0, 30)

		-- exclusions ---------------------------------------------------
		ui:section("EXCLUSIONS")

		ui:nameRow("Exclude", "username", function(name)
			if addExclusion(name) then rebuildExclusions() end
		end)

		ui:button("View excluded", function()
			exList:setVisible(not exList._frame.Visible)
		end)

		exList = ui:list("Excluded", 110)
		exList:setVisible(false)

		-- map ----------------------------------------------------------
		ui:section("MAP")

		ui:toggle("POI", function() return Config.poi.enabled end,
			function(v) Config.poi.enabled = v end)

		ui:button("Show dealers + armory", function()
			for name in pairs(poi.names) do
				if poiIsKeyword(name) then Config.poi.show[name] = true end
			end
			for _, kw in ipairs(Config.poi.armoryKeys) do Config.poi.show[kw] = true end
			for _, kw in ipairs(Config.poi.dealerKeys) do Config.poi.show[kw] = true end
			Config.poi.enabled = true
			poi.lastDone = -1e9
			poiStart()
			rebuildPoi()
		end)

		ui:button("Rescan map", function()
			poi.lastDone = -1e9
		end)

		poiList = ui:list("Map spots", 152)

		-- keybinds -----------------------------------------------------
		ui:section("KEYBINDS")

		addBind("Menu", function() return Config.ui.key end, setMenuKey)
		addBind("ESP", function() return Config.esp.toggleKey end,
			function(k) Config.esp.toggleKey = k end)
		addBind("Aim + fire", function() return Config.aim.toggleKey end,
			function(k) Config.aim.toggleKey = k end)
		addBind("Head / chest", function() return Config.aim.hitboxKey end,
			function(k) Config.aim.hitboxKey = k end)
		addBind("Hotkey: distance", function() return hotkeyOf("distance") end,
			function(k) setHotkey("distance", k) end)
		addBind("Hotkey: wallhack", function() return hotkeyOf("chams") end,
			function(k) setHotkey("chams", k) end)
		addBind("Hotkey: box", function() return hotkeyOf("box") end,
			function(k) setHotkey("box", k) end)
		addBind("Hotkey: items", function() return hotkeyOf("items") end,
			function(k) setHotkey("items", k) end)
		addBind("Hotkey: tracer", function() return hotkeyOf("tracer") end,
			function(k) setHotkey("tracer", k) end)
		addBind("Hotkey: name", function() return hotkeyOf("name") end,
			function(k) setHotkey("name", k) end)
		ui:button("Reset keybinds", resetBinds)
		paintBinds()

		-- performance --------------------------------------------------
		ui:section("PERFORMANCE")

		ui:toggle("Frame meter", function() return Config.perf.meter end,
			function(v)
				Config.perf.meter = v
				perf.ema, perf.peak, perf.fps, perf.reportAt = 0, 0, 0, -1e9
			end)

		ui:stat("Frame ms", function() return perf.ema * 1000 end,
			function(v) return string.format("%.2f", v) end)

		ui:stat("Peak ms", function() return perf.peak * 1000 end,
			function(v) return string.format("%.2f", v) end)

		ui:stat("FPS", function() return perf.fps end,
			function(v) return string.format("%.0f", v) end)

		ui:stat("Proj", function() return stats.projections end,
			function(v) return string.format("%d", v) end)

		ui:stat("Reuse", function() return stats.reused end,
			function(v) return string.format("%d", v) end)

		ui:stat("Render", function() return CAPS.drawing and "drawing" or "frames" end)

		rebuildExclusions()
		rebuildPoi()

		uiRefresh = function()
			-- The H key writes Config directly; the button label follows here.
			if Config.aim.hitbox ~= hitSeen then
				hitSeen = Config.aim.hitbox
				paintHitbox()
			end
			refreshMenu()
		end

		uiSetOpen = function(open)
			if ui then
				ui:setOpen(open)
				-- The X button closes the panel without telling us; read the
				-- live state so the next key press reopens it.
				uiOpen = ui:isOpen()
				-- A pending bind must not swallow a key after the panel is
				-- gone; paintBinds clears it and restores the row text.
				if not uiOpen then paintBinds() end
			else
				uiOpen = open and true or false
			end
		end

		uiDestroy = function()
			if ui then ui:destroy() end
		end
	end)

	if not ok then
		warn("[OD] menu build failed: " .. tostring(err))
	end
	return ok
end

-- One warn per subsystem per session: a failing call must not become a
-- console flood, and it must not take the rest of the frame down with it.
local warned = {}

local function soft(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not warned[name] then
		warned[name] = true
		warn(string.format("[OD] %s failed: %s", name, tostring(err)))
	end
	return ok
end

-- Slow lane, 10 Hz: player snapshot, ESP text/LOS, chams property writes,
-- the POI walk and the menu rows. Per-frame work is projection only.
local sweepAt, slowAt = -1e9, -1e9

-- ══ MATCHA KEYS ═══════════════════════════════════════════════════════════
-- Matcha's InputObject carries KeyCode only for A-Z and the mouse buttons, and
-- its VM has no Enum for RightShift. The native tab's keybind is the source
-- when it has painted; the raw keyboard is the fallback.
local mkeyPrev = {}
local function mkeyEdge(id, vk)
	local v = nil
	if type(UI) == "table" and type(UI.GetValue) == "function" then
		local ok, got = pcall(UI.GetValue, id)
		if ok and type(got) == "boolean" then v = got end
	end
	if v ~= nil then
		local was = mkeyPrev[id .. "v"]
		mkeyPrev[id .. "v"] = v
		if was ~= nil and v ~= was then return true end
		return false
	end
	local down = iskeypressed(vk) and true or false
	local was = mkeyPrev[vk]
	mkeyPrev[vk] = down
	return down and not was
end

local function matchaKeys()
	if not CAPS.matcha or type(iskeypressed) ~= "function" then return end
	if type(isrbxactive) == "function" then
		local ok, active = pcall(isrbxactive)
		if ok and active == false then return end
	end
	if mkeyEdge("f2_esp_kb", 0xA1) then
		Config.esp.enabled = not Config.esp.enabled
		espDirty = true
		print(string.format("[OD] esp = %s", tostring(Config.esp.enabled)))
	end
	if mkeyEdge("f2_aim_kb", 0x4B) then
		aimActive = not aimActive
		print(string.format("[OD] aim = %s", tostring(aimActive)))
	end
	if mkeyEdge("f2_hit_kb", 0x48) then
		setHitbox(Config.aim.hitbox == "chest" and "head" or "chest")
	end
end

local function onRender(dt)
	frameStamp = frameStamp + 1
	matchaKeys()
	local now = clock()
	local costAt = Config.perf.meter and now or nil

	-- Snapshot first: the fast pass can only project players it can see.
	if now - sweepAt >= 0.1 then
		sweepAt = now
		soft("sweep", sweep)
		soft("alive", refreshAlive)
	end

	-- Menu first: a typed value or a toggle must land before the ESP pass
	-- reads the config in the same frame.
	soft("menu", uiRefresh)

	soft("esp", updateEspFast)

	if now - slowAt >= 0.1 or espDirty then
		slowAt = now
		espDirty = false
		soft("esptext", updateEspSlow)
		soft("chams", updateChams)
	end

	soft("poi", updatePoi, now)

	local cam = camera()
	if cam then
		local origin = aimOrigin()
		local radius = Config.aim.fov
		local visible = Config.aim.enabled and Config.aim.showFov
		local color = aimActive and FOV_ACTIVE or FOV_IDLE

		-- Drawing writes cross into the renderer; only pay for a change.
		if fovQ.pos ~= origin then
			fovQ.pos = origin
			fovCircle.Position = origin
		end
		if fovQ.radius ~= radius then
			fovQ.radius = radius
			fovCircle.Radius = radius
		end
		if fovQ.visible ~= visible then
			fovQ.visible = visible
			fovCircle.Visible = visible
		end
		if fovQ.color ~= color then
			fovQ.color = color
			fovCircle.Color = color
		end
	end

	if costAt then
		perfSample(now, dt, clock() - costAt)
	end
end

-- The aim must write after the game's camera module, not on the raw
-- RenderStepped signal. The module binds at RenderPriority.Camera (200);
-- Last (2000) runs after everything, so the write survives the frame.
local markerShown = false

local function aimTick(dt)
	-- A Drawing property write is a C++ call. 60 a second to say "still off"
	-- is waste; only the transition costs anything.
	if markerShown then
		aimMarker.Visible = false
		markerShown = false
	end
	if not (Config.aim.enabled and aimActive) then
		stopFire()
		return
	end

	local target = findTarget()
	if not target then
		stopFire()
		return
	end

	local firing = shooting or userFiring()
	local boost = nil
	if Config.combat.enabled and Config.combat.recoilControl and firing then
		boost = Config.combat.recoilAlpha
	end
	applyAim(target, dt, boost, firing)
	updateFire(target)

	local cam = camera()
	local part, off = aimPartFor(track[target])
	if cam and part then
		local sp = viewPoint(cam, aimPoint(part, off))
		if sp and sp.Z > 0 then
			aimMarker.Position = Vector2.new(sp.X, sp.Y)
			aimMarker.Radius = 8
			aimMarker.Visible = true
			markerShown = true
		end
	end
end

local function onAimStep(dt)
	soft("aim", aimTick, dt)
end

local RENDER_NAME = "OD_Criminality"
local AIM_NAME = "OD_Criminality_Aim"
local aimBound = pcall(function()
	RunService:BindToRenderStep(AIM_NAME, Enum.RenderPriority.Last.Value, onAimStep)
end)

local aimConnection
if not aimBound then
	aimConnection = RunService.RenderStepped:Connect(onAimStep)
end

-- The default camera runs at RenderPriority.Camera (200); Camera + 1 wins.
local bound = pcall(function()
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, onRender)
end)

local connection
if not bound then
	connection = RunService.RenderStepped:Connect(onRender)
end

-- Input links are tracked so a re-exec leaves no handler behind.
local inputLink, focusLink, leaveLink

local function unload()
	stopFire()
	-- Stop the key watchdog first, so it cannot fire on a dead instance.
	if Key.stopWatch then Key.stopWatch() end
	if inputLink then inputLink:Disconnect(); inputLink = nil end
	if focusLink then focusLink:Disconnect(); focusLink = nil end
	if leaveLink then leaveLink:Disconnect(); leaveLink = nil end
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if aimConnection then
		aimConnection:Disconnect()
		aimConnection = nil
	end
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
		RunService:UnbindFromRenderStep(AIM_NAME)
	end)
	fovCircle.Visible = false
	fovCircle:Remove()
	aimMarker.Visible = false
	aimMarker:Remove()
	local keys = {}
	for plr in pairs(esp) do
		keys[#keys + 1] = plr
	end
	for _, plr in ipairs(keys) do
		destroy(plr)
	end
	local chamsKeys = {}
	for plr in pairs(chams) do
		chamsKeys[#chamsKeys + 1] = plr
	end
	for _, plr in ipairs(chamsKeys) do
		chamsOff(plr)
	end
	poiClear()
	-- Drop the last references: the closures are about to be unreachable, and
	-- a stale character table would keep a whole map alive until GC.
	table.clear(track)
	table.clear(vis)
	table.clear(esp)
	table.clear(chams)
	uiDestroy()
end

local function onInputBegan(input, gpe)
	-- A pending rebind owns the next key press, processed focus or not.
	if binding ~= nil then
		local key = input.KeyCode
		if key ~= nil and key ~= Enum.KeyCode.Unknown then
			if key == Enum.KeyCode.Escape then
				paintBinds()
			else
				applyBind(binding, key)
			end
		end
		return
	end
	if gpe then return end
	if UI_KEYS[input.KeyCode] then
		if ui then
			uiSetOpen(not ui:isOpen())
		else
			uiSetOpen(not uiOpen)
		end
		return
	end
	if input.KeyCode == Config.esp.toggleKey then
		Config.esp.enabled = not Config.esp.enabled
		espDirty = true
		print(string.format("[OD] esp = %s", tostring(Config.esp.enabled)))
	elseif input.KeyCode == Config.aim.toggleKey then
		aimActive = not aimActive
		print(string.format("[OD] aim = %s", tostring(aimActive)))
	elseif input.KeyCode == Config.aim.hitboxKey then
		setHitbox(Config.aim.hitbox == "chest" and "head" or "chest")
	else
		local field = Config.esp.hotkeys[input.KeyCode]
		if field then
			Config.esp[field] = not Config.esp[field]
			espDirty = true
			print(string.format("[OD] esp.%s = %s", field, tostring(Config.esp[field])))
		end
	end
end

pcall(function()
	inputLink = UserInputService.InputBegan:Connect(onInputBegan)
end)

pcall(function()
	focusLink = UserInputService.WindowFocusReleased:Connect(function()
		aimActive = false
		stopFire()
	end)
end)

pcall(function()
	leaveLink = Players.PlayerRemoving:Connect(function(plr)
		destroy(plr)
		chamsOff(plr)
		vis[plr] = nil
	end)
end)

if GENV then
	GENV.CriminalityOD = {
		config = Config,
		unload = unload,
		poiRescan = function()
			poi.lastDone = -1e9
		end,
		poiNames = poiNames,
		setOpaque = setOpaque,
		setMenu = function(open)
			uiSetOpen(open and true or false)
		end,
		panel = function()
			return ui
		end,
		stats = stats,
		caps = CAPS,
		-- Test seams. The harness drives the frame loop through these instead
		-- of reaching into the chunk's locals.
		clock = clock,
		aimLead = aimLead,
		cfgText = cfgText,
		cfgSave = cfgSave,
		cfgKeys = cfgCount,
	}
end

-- The menu builds last, after the render and aim callbacks are already bound.
-- A menu that fails can no longer take the cheat down with it.
local menuOK = false
if Config.ui.enabled then
	menuOK = buildUi() == true
end

-- The kill switch: a document that says so stops this copy where it stands.
-- unload disconnects the render step, drops every Drawing, destroys the panel.
Key.watch(function(reason)
	warn("[OD] this copy was revoked: " .. tostring(reason))
	pcall(unload)
end)

print(string.format("[OD] Finifugal 2.0 loaded — Ñ: menu, RightShift: ESP, K: aim + fire — menu=%s drawing solid=%d", tostring(menuOK), SOLID))

end

local function launch()
	beacon("key accepted", true)
	main()
end

if Key.unlocked() then
	launch()
else
	beacon("asking for key")
	keyGate(launch)
end

local ion2d = {}
ion2d.currentScene = 1
ion2d.scenes = {}
ion2d._nextEntityId = 1
local drawnText = {}
local drawnTextCount = 0
local luapng
local textengine
local registerBuiltInSystems

local math_sin = math.sin
local math_cos = math.cos
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_random = math.random
local math_pi = math.pi
local table_insert = table.insert
local table_remove = table.remove
local os_epoch = os.epoch

local function safeError(msg, level)
	level = level or 1

	if textengine then
		pcall(function()
			textengine.rawSetBackgroundColor(0)
			textengine.rawSetTextColor(9)
			textengine.rawClear()
			textengine.rawSetCursorPos(0, 0)
			textengine.rawWrite("ERROR:\n")
			textengine.rawWrite(tostring(msg))
			textengine.rawWrite("\n\nPress any key to exit...")
		end)

		pcall(function()
			os.pullEvent("key")
		end)
	end

	term.setGraphicsMode(0)
	term.redirect(term.native())
	error(msg, level + 1)
end

function ion2d.panic(msg)
	safeError(msg, 2)
end

ion2d.Component = {}
ion2d.Component.__index = ion2d.Component

function ion2d.Component:new(data)
	local instance = setmetatable(data or {}, self)
	return instance
end

ion2d.components = {}

ion2d.components.Lifetime = setmetatable({}, { __index = ion2d.Component })
ion2d.components.Lifetime.__index = ion2d.components.Lifetime

function ion2d.components.Lifetime:new(duration)
	local instance = {
		duration = duration,
		startTime = os.epoch("utc") / 1000,
	}
	return setmetatable(instance, self)
end

function ion2d.components.Lifetime:isExpired()
	return (os.epoch("utc") / 1000) >= (self.startTime + self.duration)
end

ion2d.components.Team = setmetatable({}, { __index = ion2d.Component })
ion2d.components.Team.__index = ion2d.components.Team

function ion2d.components.Team:new(teamName)
	local instance = { name = teamName }
	return setmetatable(instance, self)
end

ion2d.components.FireControl = setmetatable({}, { __index = ion2d.Component })
ion2d.components.FireControl.__index = ion2d.components.FireControl

function ion2d.components.FireControl:new(data)
	local instance = {
		delay = data.delay or 1.0,
		aimError = data.aimError or 0,
		lastFireTime = 0,
	}
	return setmetatable(instance, self)
end

function ion2d.components.FireControl:canFire(currentTime)
	return (currentTime - self.lastFireTime) >= self.delay
end

function ion2d.components.FireControl:recordFire(currentTime)
	self.lastFireTime = currentTime
end

ion2d.components.Camera = setmetatable({}, { __index = ion2d.Component })
ion2d.components.Camera.__index = ion2d.components.Camera

function ion2d.components.Camera:new(config)
	config = config or {}
	local instance = {
		x = config.x or 0,
		y = config.y or 0,
		targetX = config.targetX or 0,
		targetY = config.targetY or 0,
		smoothing = config.smoothing or 0.1,
		bounds = config.bounds,

		shakeX = 0,
		shakeY = 0,
		shakeIntensity = 0,
		shakeDecay = 8,

		followTarget = nil,
		followOffset = { x = 0, y = 0 },
	}
	return setmetatable(instance, self)
end

function ion2d.components.Camera:follow(entity, offsetX, offsetY)
	self.followTarget = entity
	self.followOffset.x = offsetX or 0
	self.followOffset.y = offsetY or 0
end

function ion2d.components.Camera:stopFollowing()
	self.followTarget = nil
end

function ion2d.components.Camera:shake(intensity)
	self.shakeIntensity = math.max(self.shakeIntensity, intensity)
end

function ion2d.components.Camera:setPosition(x, y)
	self.x = x
	self.y = y
	self.targetX = x
	self.targetY = y
end

function ion2d.components.Camera:setBounds(minX, minY, maxX, maxY)
	self.bounds = { minX, minY, maxX, maxY }
end

function ion2d.components.Camera:update(dt, screenW, screenH)
	if self.followTarget and not self.followTarget:isDestroyed() then
		local tx, ty = self.followTarget:getCenter()
		self.targetX = tx - screenW / 2 + self.followOffset.x
		self.targetY = ty - screenH / 2 + self.followOffset.y
	end

	if self.bounds then
		local b = self.bounds
		self.targetX = math_max(b[1], math_min(b[3] - screenW, self.targetX))
		self.targetY = math_max(b[2], math_min(b[4] - screenH, self.targetY))
	end

	self.x = self.x + (self.targetX - self.x) * self.smoothing
	self.y = self.y + (self.targetY - self.y) * self.smoothing

	if self.shakeIntensity > 0 then
		self.shakeX = (math_random() - 0.5) * self.shakeIntensity
		self.shakeY = (math_random() - 0.5) * self.shakeIntensity
		self.shakeIntensity = self.shakeIntensity * (1 - dt * self.shakeDecay)
		if self.shakeIntensity < 0.1 then
			self.shakeIntensity = 0
			self.shakeX = 0
			self.shakeY = 0
		end
	end
end

function ion2d.components.Camera:getPosition()
	return self.x + self.shakeX, self.y + self.shakeY
end

function ion2d.components.Camera:getViewBounds()
	local camX, camY = self:getPosition()
	local screenW, screenH = term.getSize()
	screenW, screenH = screenW * 8, screenH * 8
	return camX, camY, camX + screenW, camY + screenH
end

function ion2d.components.Camera:worldToScreen(x, y)
	local camX, camY = self:getPosition()
	return x - camX, y - camY
end

function ion2d.components.Camera:screenToWorld(x, y)
	local camX, camY = self:getPosition()
	return x + camX, y + camY
end

ion2d.components.ParticleEmitter = setmetatable({}, { __index = ion2d.Component })
ion2d.components.ParticleEmitter.__index = ion2d.components.ParticleEmitter

function ion2d.components.ParticleEmitter:new(config)
	config = config or {}
	local instance = {

		rate = config.rate or 10,

		burst = config.burst or 0,

		spriteX = config.spriteX or 1,
		spriteY = config.spriteY or 1,
		lifetime = config.lifetime or 1.0,
		lifetimeVariance = config.lifetimeVariance or 0,

		speed = config.speed or 50,
		speedVariance = config.speedVariance or 0,
		angle = config.angle or 0,

		angleVariance = config.angleVariance or math.pi * 2,

		drag = config.drag or 0,
		gravity = config.gravity or 0,

		fadeOut = config.fadeOut ~= false,

		_accumulator = 0,
		_particles = {},
	}
	return setmetatable(instance, self)
end

function ion2d.components.ParticleEmitter:emit(x, y, count)
	count = count or 1

	for i = 1, count do
		local angle = self.angle + (math.random() - 0.5) * self.angleVariance
		local speed = self.speed + (math.random() - 0.5) * self.speedVariance
		local vx = math.cos(angle) * speed
		local vy = math.sin(angle) * speed

		local lifetime = self.lifetime + (math.random() - 0.5) * self.lifetimeVariance

		local particle = {
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			lifetime = lifetime,
			age = 0,
			spriteX = self.spriteX,
			spriteY = self.spriteY,
		}

		table.insert(self._particles, particle)
	end
end

function ion2d.components.ParticleEmitter:update(dt, x, y)
	if self.rate > 0 then
		self._accumulator = self._accumulator + dt
		local toEmit = math.floor(self._accumulator * self.rate)
		if toEmit > 0 then
			self:emit(x, y, toEmit)
			self._accumulator = self._accumulator - (toEmit / self.rate)
		end
	end

	for i = #self._particles, 1, -1 do
		local p = self._particles[i]

		p.age = p.age + dt

		if p.age >= p.lifetime then
			table.remove(self._particles, i)
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt

			if self.drag > 0 then
				p.vx = p.vx * math.exp(-self.drag * dt)
				p.vy = p.vy * math.exp(-self.drag * dt)
			end

			if self.gravity ~= 0 then
				p.vy = p.vy + self.gravity * dt
			end
		end
	end
end

function ion2d.components.ParticleEmitter:render(camera)
	local camX, camY = 0, 0
	if camera then
		camX, camY = camera:getPosition()
	end

	for _, p in ipairs(self._particles) do
		local sprite = ion2d.spritemap[p.spriteX][p.spriteY]
		if sprite then
			local screenX = p.x - camX
			local screenY = p.y - camY

			local opacity = 1.0
			if self.fadeOut then
				local life = 1 - (p.age / p.lifetime)
				opacity = life * life
			end

			if opacity > 0.1 then
				term.drawPixels(screenX, screenY, sprite.pixels, sprite.width, sprite.height)
			end
		end
	end
end

function ion2d.components.ParticleEmitter:clear()
	self._particles = {}
end

ion2d.particles = {}
ion2d.particles._pool = {}
ion2d.particles._poolSize = 0
ion2d.particles._maxPoolSize = 100

function ion2d.particles.spawn(x, y, vx, vy, lifetime, spriteX, spriteY)
	spriteX = spriteX or 4
	spriteY = spriteY or 1

	local particle = nil
	if ion2d.particles._poolSize > 0 then
		particle = ion2d.particles._pool[ion2d.particles._poolSize]
		ion2d.particles._pool[ion2d.particles._poolSize] = nil
		ion2d.particles._poolSize = ion2d.particles._poolSize - 1

		particle:setSprite(spriteX, spriteY)
		particle:centerAt(x, y)
		particle:setVelocity(vx, vy)
		particle.internal.destroyed = false
		particle.meta.destroyTime = nil

		local lifetimeComp = particle:getComponent(ion2d.components.Lifetime)
		if lifetimeComp then
			lifetimeComp.duration = lifetime or 0.5
			lifetimeComp.startTime = os.epoch("utc") / 1000
		end
	else
		particle = ion2d.world.spawn("particle", {
			spriteX = spriteX,
			spriteY = spriteY,
			centerAt = { x, y },
			velocity = { vx, vy },
			lifetime = lifetime or 0.5,
		})
	end

	return particle
end

function ion2d.particles.explosion(x, y, count, speed, spriteX, spriteY)
	count = count or 10
	speed = speed or 80
	spriteX = spriteX or 4
	spriteY = spriteY or 1

	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local vel = speed * (0.5 + math.random() * 0.5)
		ion2d.particles.spawn(
			x,
			y,
			math.cos(angle) * vel,
			math.sin(angle) * vel,
			0.3 + math.random() * 0.4,
			spriteX,
			spriteY
		)
	end
end

function ion2d.particles.trail(x, y, vx, vy, spriteX, spriteY)
	spriteX = spriteX or 4
	spriteY = spriteY or 1

	ion2d.particles.spawn(
		x + (math.random() - 0.5) * 4,
		y + (math.random() - 0.5) * 4,
		vx * -0.1 + (math.random() - 0.5) * 10,
		vy * -0.1 + (math.random() - 0.5) * 10,
		0.2 + math.random() * 0.2,
		spriteX,
		spriteY
	)
end

ion2d.Tilemap = {}
ion2d.Tilemap.__index = ion2d.Tilemap

function ion2d.Tilemap:new(tileWidth, tileHeight)
	local instance = {
		tileWidth = tileWidth,
		tileHeight = tileHeight,
		tiles = {},

		width = 0,
		height = 0,
	}
	return setmetatable(instance, self)
end

function ion2d.Tilemap:setTile(x, y, spriteX, spriteY)
	if not self.tiles[y] then
		self.tiles[y] = {}
	end
	self.tiles[y][x] = { spriteX = spriteX, spriteY = spriteY }

	self.width = math.max(self.width, x)
	self.height = math.max(self.height, y)
end

function ion2d.Tilemap:getTile(x, y)
	if self.tiles[y] and self.tiles[y][x] then
		return self.tiles[y][x].spriteX, self.tiles[y][x].spriteY
	end
	return nil, nil
end

function ion2d.Tilemap:removeTile(x, y)
	if self.tiles[y] then
		self.tiles[y][x] = nil
	end
end

function ion2d.setTilemap(tilemap)
	ion2d.currentTilemap = tilemap
end

function ion2d.Tilemap:render(camera, layer)
	layer = layer or 1

	local camX, camY = 0, 0
	local screenW, screenH = term.getSize()
	screenW, screenH = screenW * 8, screenH * 8

	if camera then
		camX, camY = camera:getPosition()
	end

	local margin = 4

	local startX = math.max(1, math.floor(camX / self.tileWidth) - margin)
	local startY = math.max(1, math.floor(camY / self.tileHeight) - margin)
	local endX = math.min(self.width, math.ceil((camX + screenW) / self.tileWidth) + margin)
	local endY = math.min(self.height, math.ceil((camY + screenH) / self.tileHeight) + margin)

	for y = startY, endY do
		if self.tiles[y] then
			for x = startX, endX do
				local tile = self.tiles[y][x]
				if tile and tile.spriteX and tile.spriteY then
					local sprite = ion2d.spritemap[tile.spriteX][tile.spriteY]
					if sprite then
						local worldX = (x - 1) * self.tileWidth
						local worldY = (y - 1) * self.tileHeight
						local screenX = worldX - camX
						local screenY = worldY - camY
						term.drawPixels(screenX, screenY, sprite.pixels, sprite.width, sprite.height)
					end
				end
			end
		end
	end
end

function ion2d.Tilemap:worldToTile(x, y)
	return math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1
end

function ion2d.Tilemap:tileToWorld(tileX, tileY)
	return (tileX - 1) * self.tileWidth, (tileY - 1) * self.tileHeight
end

function ion2d.newTilemap(tileWidth, tileHeight)
	return ion2d.Tilemap:new(tileWidth, tileHeight)
end

ion2d.StateMachine = {}
ion2d.StateMachine.__index = ion2d.StateMachine

function ion2d.StateMachine:new(states)
	local instance = {
		states = states,
		current = nil,
	}
	return setmetatable(instance, self)
end

function ion2d.StateMachine:setState(stateName)
	if self.current and self.states[self.current] and self.states[self.current].exit then
		self.states[self.current].exit()
	end

	self.current = stateName

	if self.states[stateName] and self.states[stateName].enter then
		self.states[stateName].enter()
	end
end

function ion2d.StateMachine:update(dt)
	if self.current and self.states[self.current] and self.states[self.current].update then
		self.states[self.current].update(dt)
	end
end

function ion2d.StateMachine:getCurrentState()
	return self.current
end

ion2d.input = {
	bindings = {},
	currentKeys = {},
	previousKeys = {},
}

function ion2d.input.bind(action, key)
	ion2d.input.bindings[action] = key
end

function ion2d.input.updateKeyState(key, state)
	ion2d.input.currentKeys[key] = state
end

function ion2d.input.down(action)
	local key = ion2d.input.bindings[action]
	return key and ion2d.input.currentKeys[key] == true
end

function ion2d.input.pressed(action)
	local key = ion2d.input.bindings[action]
	return key and ion2d.input.currentKeys[key] == true and not ion2d.input.previousKeys[key]
end

function ion2d.input.released(action)
	local key = ion2d.input.bindings[action]
	return key and ion2d.input.currentKeys[key] == false and ion2d.input.previousKeys[key] == true
end

function ion2d.input.update()
	for k, v in pairs(ion2d.input.currentKeys) do
		ion2d.input.previousKeys[k] = v
	end
end

function ion2d.initLayer(scene, number)
	ion2d.scenes[scene].layers[number] = {
		entities = {},
	}
end

ion2d.currentSceneRef = nil

function ion2d.initScene(number)
	ion2d.scenes[number] = {
		layers = {},
		background = 15,
		_componentGroups = {},
		renderables = {},
		updatables = {},

		typeGroups = {},
		typeCounts = {},
	}
	ion2d.initLayer(number, 1)

	if number == ion2d.currentScene then
		ion2d.currentSceneRef = ion2d.scenes[number]
	end
end

function ion2d.reloadScene()
	local scene = ion2d.currentScene
	ion2d.removeScene(scene)
	ion2d.initScene(scene)
	ion2d.currentSceneRef = ion2d.scenes[scene]

	if ion2d.onSceneReload then
		ion2d.onSceneReload(scene)
	end
end

function ion2d.removeScene(number)
	ion2d.scenes[number] = nil
end

function ion2d.setState(stateName)
	if ion2d.stateMachine then
		ion2d.stateMachine:setState(stateName)
	end
end

function ion2d.getState()
	if ion2d.stateMachine then
		return ion2d.stateMachine:getCurrentState()
	end
	return nil
end

local function pushText(func, args)
	drawnTextCount = drawnTextCount + 1
	local entry = drawnText[drawnTextCount]
	if not entry then
		entry = { func = nil, args = {} }
		drawnText[drawnTextCount] = entry
	end
	entry.func = func

	local eargs = entry.args
	for i = 1, #args do
		eargs[i] = args[i]
	end

	for i = #args + 1, #eargs do
		eargs[i] = nil
	end
end

function ion2d.init()
	local success, err = pcall(function()
		term.setGraphicsMode(2)
		textengine = require("/ion2d/lib/textengine")
		textengine.rawWrite = textengine.write
		textengine.rawSetBackgroundColor = textengine.setBackgroundColor
		textengine.rawSetTextColor = textengine.setTextColor
		textengine.rawClear = textengine.clear
		textengine.rawSetCursorPos = textengine.setCursorPos

		textengine.write = function(...)
			pushText(textengine.rawWrite, { ... })
		end

		textengine.setBackgroundColor = function(bg)
			pushText(textengine.rawSetBackgroundColor, { bg })
			textengine.rawSetBackgroundColor(bg)
		end

		textengine.setTextColor = function(fg)
			pushText(textengine.rawSetTextColor, { fg })
			textengine.rawSetTextColor(fg)
		end

		textengine.clear = function(_)
			drawnTextCount = 0
		end

		textengine.setCursorPos = function(x, y)
			pushText(textengine.rawSetCursorPos, { x, y })
			textengine.rawSetCursorPos(x, y)
		end

		term.redirect(textengine)
		luapng = require("/ion2d/lib/luapng")
		ion2d.initScene(1)

		registerBuiltInSystems()

		term.clear()
	end)

	if not success then
		safeError("Failed to initialize ion2d: " .. tostring(err))
	end
end

function ion2d.newSpritemap(file, cellW, cellH)
	local success, result = pcall(function()
		local img = luapng(file, nil, false, false)

		local cellsW = math.floor(img.width / cellW)
		local cellsH = math.floor(img.height / cellH)

		local spritemap = {}
		local pngPixels = img.pixels
		local colorCache = {}
		local spriteIdCounter = 1

		for sx = 1, cellsW do
			spritemap[sx] = {}
			for sy = 1, cellsH do
				local pixels = {}

				for y = 1, cellH do
					pixels[y] = {}
					local py = (sy - 1) * cellH + y
					local srcRow = pngPixels[py]

					for x = 1, cellW do
						local px = (sx - 1) * cellW + x
						local pixel = srcRow[px]

						if pixel.A == 0 then
							pixels[y][x] = -1
						else
							local r, g, b = pixel.R, pixel.G, pixel.B
							local key = r * 65536 + g * 256 + b

							local xtermColor = colorCache[key]
							if not xtermColor then
								xtermColor = textengine.toXterm256(r, g, b) - 1
								colorCache[key] = xtermColor
							end

							pixels[y][x] = xtermColor
						end
					end
				end

				spritemap[sx][sy] = {
					id = spriteIdCounter,
					pixels = pixels,
					width = cellW,
					height = cellH,
				}
				spriteIdCounter = spriteIdCounter + 1
			end

			if sx % 5 == 0 then
				os.queueEvent("yield")
				os.pullEvent("yield")
			end
		end

		return spritemap
	end)

	if not success then
		safeError("Failed to load spritemap from '" .. file .. "': " .. tostring(result))
	end

	return result
end

function ion2d.setSpritemap(spritemap)
	ion2d.spritemap = spritemap
end

function ion2d.getSpritemap()
	return ion2d.spritemap
end

function ion2d.newCharacter(spriteX, spriteY, scene, layer)
	scene = scene or 1
	layer = layer or 1

	if not ion2d.spritemap then
		safeError("No spritemap loaded. Call ion2d.setSpritemap() first.")
	end

	local spritemap = ion2d.spritemap

	if not spritemap[spriteX] then
		safeError("Sprite X index " .. spriteX .. " out of bounds (max: " .. #spritemap .. ")")
	end

	if not spritemap[spriteX][spriteY] then
		safeError("Sprite Y index " .. spriteY .. " out of bounds (max: " .. #spritemap[spriteX] .. ")")
	end

	local sprite = spritemap[spriteX][spriteY]
	local sceneData = ion2d.scenes[scene]
	local layerTable = sceneData.layers[layer].entities

	local nextId = ion2d._nextEntityId + 1
	ion2d._nextEntityId = nextId

	local entity = {
		id = nextId,
		sprite = sprite,
		x = 1,
		y = 1,
		vx = 0,
		vy = 0,
		scene = scene,
		layer = layer,

		internal = {
			destroyed = false,
			_collidingWith = {},
			_events = {
				onDestroy = {},
				onUpdate = {},
				onCollisionEnter = {},
				onCollisionStay = {},
				onCollisionExit = {},
			},
		},

		state = {},
		meta = {},
		components = {},
		properties = {},
		forwardAngleOffset = 0,
	}

	function entity:addComponent(component)
		local componentType = getmetatable(component)
		table.insert(self.components, component)

		if not ion2d.scenes[self.scene]._componentGroups[componentType] then
			ion2d.scenes[self.scene]._componentGroups[componentType] = {}
		end
		table.insert(ion2d.scenes[self.scene]._componentGroups[componentType], self)

		return component
	end

	function entity:getComponent(componentType)
		for _, component in ipairs(self.components) do
			if getmetatable(component) == componentType then
				return component
			end
		end
		return nil
	end

	function entity:hasComponent(componentType)
		return self:getComponent(componentType) ~= nil
	end

	function entity:removeComponent(componentType)
		for i = #self.components, 1, -1 do
			if getmetatable(self.components[i]) == componentType then
				table.remove(self.components, i)

				local group = ion2d.scenes[self.scene]._componentGroups[componentType]
				if group then
					for j = #group, 1, -1 do
						if group[j] == self then
							table.remove(group, j)
							break
						end
					end
				end

				return true
			end
		end
		return false
	end

	function entity:set(key, value)
		self.properties[key] = value
	end

	function entity:get(key)
		return self.properties[key]
	end

	function entity:is(type)
		if self.properties.type == type then
			return true
		end

		local team = self:getComponent(ion2d.components.Team)
		if team then
			return team.name == type
		end
		return false
	end

	function entity:OnDestroy(callback)
		table.insert(self.internal._events.onDestroy, callback)
		return {
			Disconnect = function()
				for i = #self.internal._events.onDestroy, 1, -1 do
					if self.internal._events.onDestroy[i] == callback then
						table.remove(self.internal._events.onDestroy, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnUpdate(callback)
		table.insert(self.internal._events.onUpdate, callback)
		return {
			Disconnect = function()
				for i = #self.internal._events.onUpdate, 1, -1 do
					if self.internal._events.onUpdate[i] == callback then
						table.remove(self.internal._events.onUpdate, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnCollisionEnter(callback)
		table.insert(self.internal._events.onCollisionEnter, callback)
		return {
			Disconnect = function()
				for i = #self.internal._events.onCollisionEnter, 1, -1 do
					if self.internal._events.onCollisionEnter[i] == callback then
						table.remove(self.internal._events.onCollisionEnter, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnCollisionStay(callback)
		table.insert(self.internal._events.onCollisionStay, callback)
		return {
			Disconnect = function()
				for i = #self.internal._events.onCollisionStay, 1, -1 do
					if self.internal._events.onCollisionStay[i] == callback then
						table.remove(self.internal._events.onCollisionStay, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnCollisionExit(callback)
		table.insert(self.internal._events.onCollisionExit, callback)
		return {
			Disconnect = function()
				for i = #self.internal._events.onCollisionExit, 1, -1 do
					if self.internal._events.onCollisionExit[i] == callback then
						table.remove(self.internal._events.onCollisionExit, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnCollision(callback)
		return self:OnCollisionEnter(callback)
	end

	function entity:_fireEvent(eventName, ...)
		if self.internal._events[eventName] then
			for _, callback in ipairs(self.internal._events[eventName]) do
				pcall(callback, self, ...)
			end
		end
	end

	function entity:setPosition(x, y)
		self.x = x
		self.y = y
	end

	function entity:move(dx, dy)
		self.x = self.x + dx
		self.y = self.y + dy
	end

	function entity:getPosition()
		return self.x, self.y
	end

	function entity:setVelocity(vx, vy)
		self.vx = vx
		self.vy = vy
	end

	function entity:thrust(vx, vy)
		self.vx = self.vx + vx
		self.vy = self.vy + vy
	end

	function entity:getVelocity()
		return self.vx, self.vy
	end

	function entity:setDrag(drag)
		self.drag = drag
	end
	function entity:getAngle()
		return self.meta.angle or 0
	end

	function entity:setAngle(angle)
		self.meta.angle = angle
	end

	function entity:forward()
		local angle = self:getAngle() + self.forwardAngleOffset
		return math.cos(angle), math.sin(angle)
	end

	function entity:right()
		local angle = self:getAngle() + self.forwardAngleOffset
		return math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)
	end

	function entity:backward()
		local fx, fy = self:forward()
		return -fx, -fy
	end

	function entity:left()
		local rx, ry = self:right()
		return -rx, -ry
	end

	function entity:setSprite(spriteX, spriteY)
		if not ion2d.spritemap then
			safeError("No spritemap loaded")
		end

		if not ion2d.spritemap[spriteX] then
			safeError("Sprite X index " .. spriteX .. " out of bounds (max: " .. #ion2d.spritemap .. ")")
		end

		if not ion2d.spritemap[spriteX][spriteY] then
			safeError("Sprite Y index " .. spriteY .. " out of bounds (max: " .. #ion2d.spritemap[spriteX] .. ")")
		end

		self.sprite = ion2d.spritemap[spriteX][spriteY]
	end

	function entity:getSize()
		return self.sprite.width, self.sprite.height
	end

	function entity:getBounds()
		return self.x, self.y, self.x + self.sprite.width, self.y + self.sprite.height
	end

	function entity:containsPoint(px, py)
		local x1, y1, x2, y2 = self:getBounds()
		return px >= x1 and px < x2 and py >= y1 and py < y2
	end

	function entity:checkCollision(other)
		local x1 = self.x
		local y1 = self.y
		local x2 = x1 + self.sprite.width
		local y2 = y1 + self.sprite.height

		local ox1 = other.x
		local oy1 = other.y
		local ox2 = ox1 + other.sprite.width
		local oy2 = oy1 + other.sprite.height

		return x1 < ox2 and x2 > ox1 and y1 < oy2 and y2 > oy1
	end

	function entity:CollidesWith(other)
		local collides = self:checkCollision(other)
		if collides then
			self:_fireEvent("onCollisionEnter", other)
			other:_fireEvent("onCollisionEnter", self)
		end
		return collides
	end

	function entity:distanceTo(other)
		local cx = self.x + self.sprite.width / 2
		local cy = self.y + self.sprite.height / 2
		local ocx = other.x + other.sprite.width / 2
		local ocy = other.y + other.sprite.height / 2
		local dx = cx - ocx
		local dy = cy - ocy
		return math.sqrt(dx * dx + dy * dy)
	end

	function entity:centerAt(x, y)
		self.x = x - self.sprite.width / 2
		self.y = y - self.sprite.height / 2
	end

	function entity:getCenter()
		return self.x + self.sprite.width / 2, self.y + self.sprite.height / 2
	end

	function entity:setMeta(key, value)
		self.meta[key] = value
	end

	function entity:getMeta(key)
		return self.meta[key]
	end

	function entity:isDestroyed()
		if self.internal.destroyed then
			return true
		end

		local lifetime = self:getComponent(ion2d.components.Lifetime)
		if lifetime then
			return lifetime:isExpired()
		end

		return self.meta.destroyTime ~= nil
	end

	function entity:stop()
		self.vx = 0
		self.vy = 0
	end

	function entity:rotateSprite(spriteXOffset, spriteYOffset)
		local currentX = 1
		local currentY = 1

		for x = 1, #ion2d.spritemap do
			for y = 1, #ion2d.spritemap[x] do
				if ion2d.spritemap[x][y] == self.sprite then
					currentX = x
					currentY = y
					break
				end
			end
		end

		local newX = currentX + (spriteXOffset or 0)
		local newY = currentY + (spriteYOffset or 0)

		if ion2d.spritemap[newX] and ion2d.spritemap[newX][newY] then
			self:setSprite(newX, newY)
		end
	end

	function entity:setFlipX(flipped)
		self.meta.flipX = flipped
	end

	function entity:setFlipY(flipped)
		self.meta.flipY = flipped
	end

	function entity:setOpacity(opacity)
		self.meta.opacity = math.max(0, math.min(1, opacity))
	end

	function entity:getOpacity()
		return self.meta.opacity or 1
	end

	function entity:setLayer(newLayer)
		local currentLayerEntities = ion2d.scenes[self.scene].layers[self.layer].entities
		for i = #currentLayerEntities, 1, -1 do
			if currentLayerEntities[i] == self then
				table.remove(currentLayerEntities, i)
				break
			end
		end

		if not ion2d.scenes[self.scene].layers[newLayer] then
			ion2d.initLayer(self.scene, newLayer)
		end

		self.layer = newLayer
		table.insert(ion2d.scenes[self.scene].layers[newLayer].entities, self)
	end

	function entity:getLayer()
		return self.layer
	end

	function entity:setScene(newScene)
		for componentType, group in pairs(ion2d.scenes[self.scene]._componentGroups) do
			for i = #group, 1, -1 do
				if group[i] == self then
					table.remove(group, i)
					break
				end
			end
		end

		local currentLayerEntities = ion2d.scenes[self.scene].layers[self.layer].entities
		for i = #currentLayerEntities, 1, -1 do
			if currentLayerEntities[i] == self then
				table.remove(currentLayerEntities, i)
				break
			end
		end

		if not ion2d.scenes[newScene] then
			ion2d.initScene(newScene)
		end

		if not ion2d.scenes[newScene].layers[self.layer] then
			ion2d.initLayer(newScene, self.layer)
		end

		self.scene = newScene
		table.insert(ion2d.scenes[newScene].layers[self.layer].entities, self)

		for _, component in ipairs(self.components) do
			local componentType = getmetatable(component)
			if not ion2d.scenes[newScene]._componentGroups[componentType] then
				ion2d.scenes[newScene]._componentGroups[componentType] = {}
			end
			table.insert(ion2d.scenes[newScene]._componentGroups[componentType], self)
		end
	end

	function entity:getScene()
		return self.scene
	end

	function entity:moveRelative(forward, strafe)
		local angle = (self.meta.angle or 0) + self.forwardAngleOffset
		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward
		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe
		self:move(forwardX + strafeX, forwardY + strafeY)
	end

	function entity:setVelocityRelative(forward, strafe)
		local angle = (self.meta.angle or 0) + self.forwardAngleOffset
		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward
		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe
		self.vx = forwardX + strafeX
		self.vy = forwardY + strafeY
	end

	function entity:thrustRelative(forward, strafe)
		local angle = (self.meta.angle or 0) + self.forwardAngleOffset
		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward
		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe
		self.vx = self.vx + forwardX + strafeX
		self.vy = self.vy + forwardY + strafeY
	end

	function entity:moveTowards(targetX, targetY, speed, dt)
		local cx, cy = self:getCenter()
		local dx = targetX - cx
		local dy = targetY - cy
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist > 0 then
			local moveAmount = math.min(speed * dt, dist)
			local nx = dx / dist
			local ny = dy / dist
			self:move(nx * moveAmount, ny * moveAmount)
			return dist <= speed * dt
		end
		return true
	end

	function entity:lookAt(x, y)
		local cx, cy = self:getCenter()
		local targetX, targetY

		if type(x) == "table" and x.getCenter then
			targetX, targetY = x:getCenter()
		else
			targetX, targetY = x, y
		end

		local angle = math.atan2(targetY - cy, targetX - cx)
		self.meta.angle = angle
		return angle
	end

	function entity:angleTo(x, y)
		local cx, cy = self:getCenter()
		local targetX, targetY

		if type(x) == "table" and x.getCenter then
			targetX, targetY = x:getCenter()
		else
			targetX, targetY = x, y
		end

		return math.atan2(targetY - cy, targetX - cx)
	end

	function entity:rotateTowards(targetAngle, maxRotation)
		local currentAngle = self.meta.angle or 0
		local diff = ion2d.angleDifference(currentAngle, targetAngle)

		if math.abs(diff) < maxRotation then
			self.meta.angle = targetAngle
		else
			self.meta.angle = currentAngle + (diff > 0 and maxRotation or -maxRotation)
		end
	end

	function entity:bounceOffEdges(width, height, damping)
		damping = damping or 1.0
		local bounced = false

		if self.x < 0 then
			self.x = 0
			self.vx = -self.vx * damping
			bounced = true
		elseif self.x + self.sprite.width > width then
			self.x = width - self.sprite.width
			self.vx = -self.vx * damping
			bounced = true
		end

		if self.y < 0 then
			self.y = 0
			self.vy = -self.vy * damping
			bounced = true
		elseif self.y + self.sprite.height > height then
			self.y = height - self.sprite.height
			self.vy = -self.vy * damping
			bounced = true
		end

		return bounced
	end

	function entity:wrapAroundScreen(width, height)
		local cx, cy = self:getCenter()
		local halfW = self.sprite.width / 2
		local halfH = self.sprite.height / 2

		if cx < -halfW then
			self:centerAt(width + halfW, cy)
		elseif cx > width + halfW then
			self:centerAt(-halfW, cy)
		end

		if cy < -halfH then
			self:centerAt(cx, height + halfH)
		elseif cy > height + halfH then
			self:centerAt(cx, -halfH)
		end
	end

	function entity:accelerate(ax, ay, dt)
		self.vx = self.vx + ax * dt
		self.vy = self.vy + ay * dt
	end

	function entity:limitSpeed(maxSpeed)
		local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
		if speed > maxSpeed then
			local scale = maxSpeed / speed
			self.vx = self.vx * scale
			self.vy = self.vy * scale
		end
	end

	function entity:clone()
		local clone = ion2d.newCharacter(1, 1, self.scene, self.layer)
		clone.sprite = self.sprite
		clone.x = self.x
		clone.y = self.y
		clone.vx = self.vx
		clone.vy = self.vy
		clone.drag = self.drag
		clone.forwardAngleOffset = self.forwardAngleOffset

		for k, v in pairs(self.meta) do
			if k ~= "destroyTime" then
				clone.meta[k] = v
			end
		end

		for k, v in pairs(self.properties) do
			clone.properties[k] = v
		end

		for k, v in pairs(self.state) do
			clone.state[k] = v
		end

		for _, component in ipairs(self.components) do
			local componentType = getmetatable(component)

			local componentData = {}
			for k, v in pairs(component) do
				componentData[k] = v
			end
			local newComponent = componentType:new(componentData)
			clone:addComponent(newComponent)
		end

		return clone
	end

	function entity:getSpeed()
		return math.sqrt(self.vx * self.vx + self.vy * self.vy)
	end

	function entity:setSpeed(speed)
		local currentSpeed = self:getSpeed()
		if currentSpeed > 0 then
			local scale = speed / currentSpeed
			self.vx = self.vx * scale
			self.vy = self.vy * scale
		end
	end

	function entity:teleport(x, y, callback)
		local oldX, oldY = self.x, self.y
		self.x = x
		self.y = y
		if callback then
			callback(self, oldX, oldY)
		end
	end

	function entity:isOnScreen(width, height, margin)
		margin = margin or 0
		return self.x + self.sprite.width >= -margin
			and self.x <= width + margin
			and self.y + self.sprite.height >= -margin
			and self.y <= height + margin
	end

	function entity:clampToScreen(width, height)
		local TEWidth, TEHeight = textengine.getPixelSize()
		width = width or TEWidth
		height = height or TEHeight
		if self.x < 0 then
			self.x = 0
		end
		if self.y < 0 then
			self.y = 0
		end
		if self.x + self.sprite.width > width then
			self.x = width - self.sprite.width
		end
		if self.y + self.sprite.height > height then
			self.y = height - self.sprite.height
		end
	end

	function entity:destroy(time)
		if time and time > 0 then
			self:addComponent(ion2d.components.Lifetime:new(time))
		else
			self.internal.destroyed = true
			self.meta.destroyTime = os.epoch("utc") / 1000
			self:_fireEvent("onDestroy")
		end
	end

	entity.SetPosition = entity.setPosition
	entity.Move = entity.move
	entity.GetPosition = entity.getPosition
	entity.SetVelocity = entity.setVelocity
	entity.Thrust = entity.thrust
	entity.GetVelocity = entity.getVelocity
	entity.SetDrag = entity.setDrag
	entity.GetAngle = entity.getAngle
	entity.SetAngle = entity.setAngle
	entity.SetSprite = entity.setSprite
	entity.GetSize = entity.getSize
	entity.GetBounds = entity.getBounds
	entity.ContainsPoint = entity.containsPoint
	entity.DistanceTo = entity.distanceTo
	entity.CenterAt = entity.centerAt
	entity.GetCenter = entity.getCenter
	entity.SetMeta = entity.setMeta
	entity.GetMeta = entity.getMeta
	entity.IsDestroyed = entity.isDestroyed
	entity.Stop = entity.stop
	entity.RotateSprite = entity.rotateSprite
	entity.SetFlipX = entity.setFlipX
	entity.SetFlipY = entity.setFlipY
	entity.SetOpacity = entity.setOpacity
	entity.GetOpacity = entity.getOpacity
	entity.SetLayer = entity.setLayer
	entity.GetLayer = entity.getLayer
	entity.SetScene = entity.setScene
	entity.GetScene = entity.getScene
	entity.MoveRelative = entity.moveRelative
	entity.SetVelocityRelative = entity.setVelocityRelative
	entity.ThrustRelative = entity.thrustRelative
	entity.MoveTowards = entity.moveTowards
	entity.LookAt = entity.lookAt
	entity.AngleTo = entity.angleTo
	entity.RotateTowards = entity.rotateTowards
	entity.BounceOffEdges = entity.bounceOffEdges
	entity.Accelerate = entity.accelerate
	entity.LimitSpeed = entity.limitSpeed
	entity.Clone = entity.clone
	entity.GetSpeed = entity.getSpeed
	entity.SetSpeed = entity.setSpeed
	entity.Teleport = entity.teleport
	entity.IsOnScreen = entity.isOnScreen
	entity.ClampToScreen = entity.clampToScreen
	entity.Destroy = entity.destroy

	table_insert(layerTable, entity)
	table_insert(sceneData.renderables, entity)
	table_insert(sceneData.updatables, entity)

	return entity
end

ion2d.world = {}

function ion2d.world.spawn(entityType, config)
	config = config or {}
	local scene = config.scene or ion2d.currentScene
	local layer = config.layer or 1

	local entity = ion2d.newCharacter(config.spriteX or 1, config.spriteY or 1, scene, layer)

	if config.position then
		entity:setPosition(config.position[1], config.position[2])
	end

	if config.centerAt then
		entity:centerAt(config.centerAt[1], config.centerAt[2])
	end

	if config.velocity then
		entity:setVelocity(config.velocity[1], config.velocity[2])
	end

	if config.angle then
		entity:setAngle(config.angle)
	end

	if config.forwardAngleOffset then
		entity.forwardAngleOffset = config.forwardAngleOffset
	end

	if config.team then
		entity:addComponent(ion2d.components.Team:new(config.team))
	end

	if config.lifetime then
		entity:addComponent(ion2d.components.Lifetime:new(config.lifetime))
	end

	if config.fireControl then
		entity:addComponent(ion2d.components.FireControl:new(config.fireControl))
	end

	if config.properties then
		for k, v in pairs(config.properties) do
			entity:set(k, v)
		end
	end

	entity:set("type", entityType)

	local sceneData = ion2d.scenes[scene]
	if not sceneData.typeGroups[entityType] then
		sceneData.typeGroups[entityType] = {}
		sceneData.typeCounts[entityType] = 0
	end

	local typeGroup = sceneData.typeGroups[entityType]
	local count = sceneData.typeCounts[entityType] + 1
	typeGroup[count] = entity
	sceneData.typeCounts[entityType] = count

	return entity
end

function ion2d.world.getById(id, scene)
	scene = scene or ion2d.currentScene
	for _, layer in pairs(ion2d.scenes[scene].layers) do
		for _, entity in ipairs(layer.entities) do
			if entity.id == id then
				return entity
			end
		end
	end
	return nil
end

function ion2d.world.getAllEntities(scene)
	scene = scene or ion2d.currentScene
	local entities = {}
	for _, layer in pairs(ion2d.scenes[scene].layers) do
		for _, entity in ipairs(layer.entities) do
			table.insert(entities, entity)
		end
	end
	return entities
end

function ion2d.world.getEntitiesWithComponent(componentType, scene)
	scene = scene or ion2d.currentScene

	local group = ion2d.scenes[scene]._componentGroups[componentType]
	if group then
		local copy = {}
		for i = 1, #group do
			copy[i] = group[i]
		end
		return copy
	end
	return {}
end

function ion2d.world.getEntitiesOfType(entityType, scene)
	scene = scene or ion2d.currentScene
	local sceneData = ion2d.scenes[scene]

	local typeGroup = sceneData.typeGroups[entityType]
	if not typeGroup then
		return {}
	end

	local count = sceneData.typeCounts[entityType]
	local result = {}
	for i = 1, count do
		result[i] = typeGroup[i]
	end
	return result
end

function ion2d.world.getEntityCount(entityType, scene)
	scene = scene or ion2d.currentScene
	local sceneData = ion2d.scenes[scene]
	return sceneData.typeCounts[entityType] or 0
end

ion2d.collision = {}
ion2d.collision.useSpatialHash = false

ion2d.collision.gridCellSize = 32

local function buildSpatialHash(entities, cellSize)
	local grid = {}

	for _, entity in ipairs(entities) do
		if not entity:isDestroyed() then
			local x1, y1, x2, y2 = entity:getBounds()
			local minCellX = math.floor(x1 / cellSize)
			local minCellY = math.floor(y1 / cellSize)
			local maxCellX = math.floor(x2 / cellSize)
			local maxCellY = math.floor(y2 / cellSize)

			for cx = minCellX, maxCellX do
				for cy = minCellY, maxCellY do
					local key = cx .. "," .. cy
					if not grid[key] then
						grid[key] = {}
					end
					table.insert(grid[key], entity)
				end
			end
		end
	end

	return grid
end

local function getNearbyCells(entity, cellSize)
	local cells = {}
	local x1, y1, x2, y2 = entity:getBounds()
	local minCellX = math.floor(x1 / cellSize)
	local minCellY = math.floor(y1 / cellSize)
	local maxCellX = math.floor(x2 / cellSize)
	local maxCellY = math.floor(y2 / cellSize)

	for cx = minCellX, maxCellX do
		for cy = minCellY, maxCellY do
			table.insert(cells, cx .. "," .. cy)
		end
	end

	return cells
end

ion2d.collision.spatialGrid = nil

ion2d.collision.spatialGridDirty = true

local function buildSpatialHashPersistent(entities, cellSize, grid)
	if grid then
		for k, _ in pairs(grid) do
			local cell = grid[k]

			for i = 1, #cell do
				cell[i] = nil
			end
		end
	else
		grid = {}
	end

	local entityCount = #entities
	for e = 1, entityCount do
		local entity = entities[e]
		if not entity.internal.destroyed then
			local x1, y1, x2, y2 = entity:getBounds()
			local minCellX = math_floor(x1 / cellSize)
			local minCellY = math_floor(y1 / cellSize)
			local maxCellX = math_floor(x2 / cellSize)
			local maxCellY = math_floor(y2 / cellSize)

			for cx = minCellX, maxCellX do
				local column = grid[cx]
				if not column then
					column = {}
					grid[cx] = column
				end

				for cy = minCellY, maxCellY do
					local cell = column[cy]
					if not cell then
						cell = {}
						column[cy] = cell
					end

					local cellSize = #cell + 1
					cell[cellSize] = entity
				end
			end
		end
	end

	return grid
end

local function getNearbyCellsPersistent(entity, cellSize, grid)
	local x1, y1, x2, y2 = entity:getBounds()
	local minCellX = math_floor(x1 / cellSize)
	local minCellY = math_floor(y1 / cellSize)
	local maxCellX = math_floor(x2 / cellSize)
	local maxCellY = math_floor(y2 / cellSize)

	local nearby = {}
	local count = 0

	for cx = minCellX, maxCellX do
		local column = grid[cx]
		if column then
			for cy = minCellY, maxCellY do
				local cell = column[cy]
				if cell then
					local cellSize = #cell
					for i = 1, cellSize do
						count = count + 1
						nearby[count] = cell[i]
					end
				end
			end
		end
	end

	return nearby, count
end

function ion2d.collision.checkAll(scene)
	scene = scene or ion2d.currentScene
	local entities = ion2d.world.getAllEntities(scene)

	if #entities < 2 then
		return
	end

	local currentCollisions = {}

	if ion2d.collision.useSpatialHash then
		local grid = buildSpatialHash(entities, ion2d.collision.gridCellSize)
		local checked = {}

		for _, e1 in ipairs(entities) do
			if not e1:isDestroyed() then
				currentCollisions[e1.id] = {}
				local cells = getNearbyCells(e1, ion2d.collision.gridCellSize)

				for _, cellKey in ipairs(cells) do
					local cellEntities = grid[cellKey] or {}
					for _, e2 in ipairs(cellEntities) do
						if e1.id ~= e2.id and not e2:isDestroyed() then
							local pairKey = math.min(e1.id, e2.id) .. "," .. math.max(e1.id, e2.id)
							if not checked[pairKey] then
								checked[pairKey] = true

								if e1:checkCollision(e2) then
									currentCollisions[e1.id][e2.id] = true

									if e1.internal._collidingWith[e2.id] then
										e1:_fireEvent("onCollisionStay", e2)
										e2:_fireEvent("onCollisionStay", e1)
									else
										e1:_fireEvent("onCollisionEnter", e2)
										e2:_fireEvent("onCollisionEnter", e1)
									end
								end
							end
						end
					end
				end
			end
		end
	else
		for i = 1, #entities do
			local e1 = entities[i]
			if not e1:isDestroyed() then
				currentCollisions[e1.id] = {}

				for j = i + 1, #entities do
					local e2 = entities[j]
					if not e2:isDestroyed() then
						if e1:checkCollision(e2) then
							currentCollisions[e1.id][e2.id] = true

							if e1.internal._collidingWith[e2.id] then
								e1:_fireEvent("onCollisionStay", e2)
								e2:_fireEvent("onCollisionStay", e1)
							else
								e1:_fireEvent("onCollisionEnter", e2)
								e2:_fireEvent("onCollisionEnter", e1)
							end
						end
					end
				end
			end
		end
	end

	for _, entity in ipairs(entities) do
		if not entity:isDestroyed() then
			for otherId, _ in pairs(entity.internal._collidingWith) do
				if not currentCollisions[entity.id] or not currentCollisions[entity.id][otherId] then
					local other = ion2d.world.getById(otherId, scene)
					if other and not other:isDestroyed() then
						entity:_fireEvent("onCollisionExit", other)
					end
				end
			end

			entity.internal._collidingWith = currentCollisions[entity.id] or {}
		end
	end
end

function ion2d.collision.checkBetween(type1, type2, scene)
	scene = scene or ion2d.currentScene
	local sceneData = ion2d.scenes[scene]

	local count1 = sceneData.typeCounts[type1] or 0
	local count2 = sceneData.typeCounts[type2] or 0

	if count1 == 0 or count2 == 0 then
		return
	end

	local group1 = sceneData.typeGroups[type1]
	local group2 = sceneData.typeGroups[type2]

	if count1 * count2 > 100 then
		local cellSize = 32

		ion2d.collision.spatialGrid = buildSpatialHashPersistent(group2, cellSize, ion2d.collision.spatialGrid)
		local grid = ion2d.collision.spatialGrid

		for i = 1, count1 do
			local e1 = group1[i]
			if not e1.internal.destroyed then
				local nearby, nearbyCount = getNearbyCellsPersistent(e1, cellSize, grid)

				local checked = {}

				for j = 1, nearbyCount do
					local e2 = nearby[j]
					local id2 = e2.id
					if not checked[id2] and not e2.internal.destroyed then
						checked[id2] = true

						if e1:checkCollision(e2) then
							if e1.internal._collidingWith[id2] then
								e1:_fireEvent("onCollisionStay", e2)
								e2:_fireEvent("onCollisionStay", e1)
							else
								e1:_fireEvent("onCollisionEnter", e2)
								e2:_fireEvent("onCollisionEnter", e1)
								e1.internal._collidingWith[id2] = true
								e2.internal._collidingWith[e1.id] = true
							end
						else
							if e1.internal._collidingWith[id2] then
								e1:_fireEvent("onCollisionExit", e2)
								e2:_fireEvent("onCollisionExit", e1)
								e1.internal._collidingWith[id2] = nil
								e2.internal._collidingWith[e1.id] = nil
							end
						end
					end
				end
			end
		end
	else
		for i = 1, count1 do
			local e1 = group1[i]
			if not e1.internal.destroyed then
				for j = 1, count2 do
					local e2 = group2[j]
					if not e2.internal.destroyed then
						if e1:checkCollision(e2) then
							if e1.internal._collidingWith[e2.id] then
								e1:_fireEvent("onCollisionStay", e2)
								e2:_fireEvent("onCollisionStay", e1)
							else
								e1:_fireEvent("onCollisionEnter", e2)
								e2:_fireEvent("onCollisionEnter", e1)
								e1.internal._collidingWith[e2.id] = true
								e2.internal._collidingWith[e1.id] = true
							end
						else
							if e1.internal._collidingWith[e2.id] then
								e1:_fireEvent("onCollisionExit", e2)
								e2:_fireEvent("onCollisionExit", e1)
								e1.internal._collidingWith[e2.id] = nil
								e2.internal._collidingWith[e1.id] = nil
							end
						end
					end
				end
			end
		end
	end
end

function ion2d.normalizeAngle(angle)
	while angle > math.pi do
		angle = angle - 2 * math.pi
	end
	while angle < -math.pi do
		angle = angle + 2 * math.pi
	end
	return angle
end

function ion2d.angleDifference(fromAngle, toAngle)
	local diff = toAngle - fromAngle
	return ion2d.normalizeAngle(diff)
end

function ion2d.toRadians(degrees)
	return degrees * math.pi / 180
end

function ion2d.toDegrees(radians)
	return radians * 180 / math.pi
end

local ROTATION_STEPS = 64
local MAX_ROTATION_CACHE_SIZE = 500

local function rotateSprite(sprite, angle, opacity)
	angle = angle % (2 * math.pi)
	opacity = opacity or 1

	local step = math.floor((angle / (2 * math.pi)) * ROTATION_STEPS)

	local cacheKey = sprite.id .. ":rot:" .. step .. ":op:" .. tostring(opacity)

	if not ion2d._rotationCache then
		ion2d._rotationCache = {}
		ion2d._rotationCacheSize = 0
	end

	if ion2d._rotationCache[cacheKey] then
		return ion2d._rotationCache[cacheKey]
	end

	if ion2d._rotationCacheSize >= MAX_ROTATION_CACHE_SIZE then
		ion2d._rotationCache = {}
		ion2d._rotationCacheSize = 0
	end

	local width = sprite.width
	local height = sprite.height
	local pixels = sprite.pixels

	local cos_a = math.cos(angle)
	local sin_a = math.sin(angle)

	local corners = {
		{ 0, 0 },
		{ width, 0 },
		{ width, height },
		{ 0, height },
	}

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge

	for _, corner in ipairs(corners) do
		local x, y = corner[1], corner[2]
		local rx = x * cos_a - y * sin_a
		local ry = x * sin_a + y * cos_a
		minX = math.min(minX, rx)
		minY = math.min(minY, ry)
		maxX = math.max(maxX, rx)
		maxY = math.max(maxY, ry)
	end

	local newWidth = math.ceil(maxX - minX)
	local newHeight = math.ceil(maxY - minY)

	local centerX = width / 2
	local centerY = height / 2

	local newCenterX = newWidth / 2
	local newCenterY = newHeight / 2

	local rotatedPixels = {}

	for ny = 1, newHeight do
		rotatedPixels[ny] = {}
		for nx = 1, newWidth do
			local dx = nx - newCenterX
			local dy = ny - newCenterY

			local ox = dx * cos_a + dy * sin_a + centerX
			local oy = -dx * sin_a + dy * cos_a + centerY

			ox = math.floor(ox + 0.5)
			oy = math.floor(oy + 0.5)

			if ox >= 1 and ox <= width and oy >= 1 and oy <= height then
				rotatedPixels[ny][nx] = pixels[oy][ox]
			else
				rotatedPixels[ny][nx] = -1
			end
		end
	end

	local rotatedSprite = {
		pixels = rotatedPixels,
		width = newWidth,
		height = newHeight,
	}

	ion2d._rotationCache[cacheKey] = rotatedSprite
	ion2d._rotationCacheSize = ion2d._rotationCacheSize + 1

	return rotatedSprite
end

local function transformSprite(sprite, flipX, flipY, opacity)
	local cacheKey = sprite.id
		.. "_"
		.. tostring(flipX or false)
		.. "_"
		.. tostring(flipY or false)
		.. "_"
		.. tostring(opacity or 1)

	if not ion2d._transformCache then
		ion2d._transformCache = {}
	end

	if ion2d._transformCache[cacheKey] then
		return ion2d._transformCache[cacheKey]
	end

	local pixels = {}
	for y = 1, sprite.height do
		pixels[y] = {}
		for x = 1, sprite.width do
			local srcX = flipX and (sprite.width - x + 1) or x
			local srcY = flipY and (sprite.height - y + 1) or y
			pixels[y][x] = sprite.pixels[srcY][srcX]
		end
	end

	local transformed = {
		pixels = pixels,
		width = sprite.width,
		height = sprite.height,
	}

	ion2d._transformCache[cacheKey] = transformed
	return transformed
end

function ion2d.newController(character, leftSprite, rightSprite, upSprite, downSprite)
	local controller = {
		character = character,
		sprites = {
			left = leftSprite or { 1, 1 },
			right = rightSprite or { 1, 1 },
			up = upSprite or { 1, 1 },
			down = downSprite or { 1, 1 },
		},
		lastDirection = "right",
	}

	function controller:setDirection(direction)
		if direction == "left" or direction == "right" or direction == "up" or direction == "down" then
			self.lastDirection = direction
			local sprite = self.sprites[direction]
			self.character:setSprite(sprite[1], sprite[2])
		end
	end

	function controller:getDirection()
		return self.lastDirection
	end

	function controller:move(dx, dy)
		if dx < 0 then
			self:setDirection("left")
		elseif dx > 0 then
			self:setDirection("right")
		elseif dy < 0 then
			self:setDirection("up")
		elseif dy > 0 then
			self:setDirection("down")
		end

		self.character:move(dx, dy)
	end

	function controller:setSprites(left, right, up, down)
		if left then
			self.sprites.left = left
		end
		if right then
			self.sprites.right = right
		end
		if up then
			self.sprites.up = up
		end
		if down then
			self.sprites.down = down
		end
	end

	return controller
end

function ion2d.gcScene(scene)
	local sceneData = ion2d.scenes[scene]
	local layers = sceneData.layers
	local renderables = sceneData.renderables
	local updatables = sceneData.updatables
	local typeGroups = sceneData.typeGroups
	local typeCounts = sceneData.typeCounts
	local time = os_epoch("utc") / 1000

	local needsCompaction = {}

	for _, layer in pairs(layers) do
		local ents = layer.entities
		for i = #ents, 1, -1 do
			local entity = ents[i]
			local lifetime = entity:getComponent(ion2d.components.Lifetime)
			local shouldDestroy = false

			if lifetime and lifetime:isExpired() then
				shouldDestroy = true
			elseif entity.meta.destroyTime and entity.meta.destroyTime <= time then
				shouldDestroy = true
			end

			if shouldDestroy then
				if not entity.internal.destroyed then
					entity.internal.destroyed = true
					entity:_fireEvent("onDestroy")

					if entity:is("particle") and ion2d.particles._poolSize < ion2d.particles._maxPoolSize then
						ion2d.particles._poolSize = ion2d.particles._poolSize + 1
						ion2d.particles._pool[ion2d.particles._poolSize] = entity
						goto continue
					end
				end

				for componentType, group in pairs(sceneData._componentGroups) do
					for j = #group, 1, -1 do
						if group[j] == entity then
							table_remove(group, j)
							break
						end
					end
				end

				for j = #renderables, 1, -1 do
					if renderables[j] == entity then
						table_remove(renderables, j)
						break
					end
				end
				for j = #updatables, 1, -1 do
					if updatables[j] == entity then
						table_remove(updatables, j)
						break
					end
				end

				local entityType = entity:get("type")
				if entityType then
					needsCompaction[entityType] = true
				end

				table_remove(ents, i)
			end

			::continue::
		end
	end

	for entityType, _ in pairs(needsCompaction) do
		local typeGroup = typeGroups[entityType]
		if typeGroup then
			local writeIdx = 1
			local count = typeCounts[entityType]

			for readIdx = 1, count do
				local entity = typeGroup[readIdx]
				if entity and not entity.internal.destroyed then
					if writeIdx ~= readIdx then
						typeGroup[writeIdx] = entity
					end
					writeIdx = writeIdx + 1
				end
			end

			for i = writeIdx, count do
				typeGroup[i] = nil
			end

			typeCounts[entityType] = writeIdx - 1
		end
	end
end

local function internalRenderText()
	for i = 1, drawnTextCount do
		local op = drawnText[i]
		op.func(table.unpack(op.args))
	end
end

function ion2d.components.Camera:isVisible(entity)
	local camX, camY = self:getPosition()
	local screenW, screenH = term.getSize()
	screenW, screenH = screenW * 8, screenH * 8

	local margin = 32

	local x1, y1, x2, y2 = entity:getBounds()

	return x2 >= camX - margin
		and x1 <= camX + screenW + margin
		and y2 >= camY - margin
		and y1 <= camY + screenH + margin
end

function ion2d.renderScene(scene, camera)
	local success, err = pcall(function()
		term.native().setFrozen(true)
		textengine.rawClear()

		local camX, camY = 0, 0
		if camera then
			camX, camY = camera:getPosition()
		end

		if ion2d.currentTilemap then
			ion2d.currentTilemap:render(camera)
		end

		local sceneData = ion2d.scenes[scene]
		local renderables = sceneData.renderables
		local renderableCount = #renderables

		for i = 1, renderableCount do
			local entity = renderables[i]

			if not entity.internal.destroyed then
				if camera then
					local x1, y1, x2, y2 = entity:getBounds()
					local screenW, screenH = term.getSize()
					screenW, screenH = screenW * 8, screenH * 8
					local margin = 32

					if
						x2 < camX - margin
						or x1 > camX + screenW + margin
						or y2 < camY - margin
						or y1 > camY + screenH + margin
					then
						goto continue
					end
				end

				local sprite = entity.sprite
				local opacity = entity.meta.opacity or 1

				if entity.meta.flipX or entity.meta.flipY then
					sprite = transformSprite(sprite, entity.meta.flipX, entity.meta.flipY, opacity)
				end

				local screenX = entity.x - camX
				local screenY = entity.y - camY

				if entity.meta.angle and entity.meta.angle ~= 0 then
					sprite = rotateSprite(sprite, entity.meta.angle, opacity)
					local offsetX = (sprite.width - entity.sprite.width) / 2
					local offsetY = (sprite.height - entity.sprite.height) / 2
					term.drawPixels(screenX - offsetX, screenY - offsetY, sprite.pixels, sprite.width, sprite.height)
				else
					term.drawPixels(screenX, screenY, sprite.pixels, sprite.width, sprite.height)
				end
			end

			::continue::
		end

		internalRenderText()
		term.native().setFrozen(false)
	end)

	if not success then
		safeError("Render error: " .. tostring(err))
	end
end

ion2d.systems = {}
ion2d._registeredSystems = {}

function ion2d.addSystem(systemDef)
	if not systemDef.update then
		safeError("System must have an update function")
	end

	local system = {
		components = systemDef.components or {},
		update = systemDef.update,
		name = systemDef.name or "unnamed_system",
		priority = systemDef.priority or 0,
		enabled = true,
	}

	table.insert(ion2d._registeredSystems, system)

	table.sort(ion2d._registeredSystems, function(a, b)
		return a.priority > b.priority
	end)

	return system
end

function ion2d.removeSystem(system)
	for i = #ion2d._registeredSystems, 1, -1 do
		if ion2d._registeredSystems[i] == system then
			table.remove(ion2d._registeredSystems, i)
			return true
		end
	end
	return false
end

function ion2d.setSystemEnabled(systemName, enabled)
	for _, system in ipairs(ion2d._registeredSystems) do
		if system.name == systemName then
			system.enabled = enabled
			return true
		end
	end
	return false
end

function ion2d.getSystem(systemName)
	for _, system in ipairs(ion2d._registeredSystems) do
		if system.name == systemName then
			return system
		end
	end
	return nil
end

local function runRegisteredSystems(dt, scene)
	local sceneData = ion2d.scenes[scene]
	local systemsCount = #ion2d._registeredSystems

	for s = 1, systemsCount do
		local system = ion2d._registeredSystems[s]
		if system.enabled then
			if #system.components > 0 then
				local smallestGroup = nil
				local smallestSize = math.huge

				local componentsCount = #system.components
				for c = 1, componentsCount do
					local componentType = system.components[c]
					local group = sceneData._componentGroups[componentType]
					if group then
						local size = #group
						if size < smallestSize then
							smallestSize = size
							smallestGroup = group
						end
					else
						smallestGroup = nil
						break
					end
				end

				if smallestGroup then
					local groupCount = #smallestGroup
					for e = 1, groupCount do
						local entity = smallestGroup[e]
						local hasAll = true
						for c = 1, componentsCount do
							if not entity:hasComponent(system.components[c]) then
								hasAll = false
								break
							end
						end
						if hasAll then
							system.update(entity, dt)
						end
					end
				end
			else
				local updatables = sceneData.updatables
				local updatablesCount = #updatables
				for e = 1, updatablesCount do
					system.update(updatables[e], dt)
				end
			end
		end
	end
end

function registerBuiltInSystems()
	ion2d.addSystem({
		name = "movement",
		priority = 100,
		components = {},
		update = function(entity, dt)
			if entity.vx and (entity.vx ~= 0 or entity.vy ~= 0) then
				entity.x = entity.x + entity.vx * dt
				entity.y = entity.y + entity.vy * dt
			end
		end,
	})

	ion2d.addSystem({
		name = "drag",
		priority = 90,
		components = {},
		update = function(entity, dt)
			if entity.drag and entity.drag > 0 then
				entity.vx = entity.vx * math.exp(-entity.drag * dt)
				entity.vy = entity.vy * math.exp(-entity.drag * dt)

				if math.abs(entity.vx) < 0.001 then
					entity.vx = 0
				end
				if math.abs(entity.vy) < 0.001 then
					entity.vy = 0
				end
			end
		end,
	})

	ion2d.addSystem({
		name = "particle_lifetime",
		priority = 85,
		components = { ion2d.components.Lifetime },
		update = function(entity, dt)
			local lifetime = entity:getComponent(ion2d.components.Lifetime)
			if lifetime then
				local elapsed = os.epoch("utc") / 1000 - lifetime.startTime
				local life = 1 - (elapsed / lifetime.duration)
				entity:setOpacity(life * life)
			end
		end,
	})
end

ion2d.fixedDeltaTime = 1 / 60
ion2d._accumulator = 0

function ion2d.step(dt)
	local success, err = pcall(function()
		ion2d.input.update()

		if ion2d.stateMachine then
			ion2d.stateMachine:update(dt)
		end

		local currentScene = ion2d.currentScene
		ion2d.gcScene(currentScene)

		local sceneData = ion2d.scenes[currentScene]
		local updatables = sceneData.updatables
		local updatablesCount = #updatables

		for i = 1, updatablesCount do
			local e = updatables[i]
			if not e.internal.destroyed then
				e:_fireEvent("onUpdate", dt)
			end
		end

		runRegisteredSystems(dt, currentScene)
	end)

	if not success then
		safeError("Update error: " .. tostring(err))
	end
end

function ion2d.render(camera)
	ion2d.renderScene(ion2d.currentScene, camera)
end

function ion2d.update(dt)
	ion2d.step(dt)
	ion2d.render()
end

function ion2d.updateFixed(frameDt)
	ion2d._accumulator = ion2d._accumulator + frameDt

	local steps = 0
	local maxSteps = 5

	while ion2d._accumulator >= ion2d.fixedDeltaTime and steps < maxSteps do
		ion2d.step(ion2d.fixedDeltaTime)
		ion2d._accumulator = ion2d._accumulator - ion2d.fixedDeltaTime
		steps = steps + 1
	end

	ion2d.render()
end

function ion2d.safeCall(func, ...)
	local results = { pcall(func, ...) }
	local success = table.remove(results, 1)

	if not success then
		safeError("Runtime error: " .. tostring(results[1]))
	end

	return table.unpack(results)
end

return ion2d

local ion2d = {}
ion2d.currentScene = 1
ion2d.scenes = {}
local drawnText = {}
local luapng
local textengine

-- Store original error function
local originalError = error
local errorDisplayed = false

-- Custom error handler that displays in graphics mode
local function safeError(msg, level)
	level = level or 1
	errorDisplayed = true

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
	originalError(msg, level + 1)
end

_G.error = safeError

function ion2d.initLayer(scene, number)
	ion2d.scenes[scene].layers[number] = {
		entities = {},
	}
end

function ion2d.initScene(number)
	ion2d.scenes[number] = {
		layers = {},
		background = 15,
	}
	ion2d.initLayer(number, 1)
end

function ion2d.removeScene(number)
	ion2d.scenes[number] = nil
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
			table.insert(drawnText, { ["func"] = textengine.rawWrite, ["args"] = { ... } })
		end
		textengine.setBackgroundColor = function(bg)
			table.insert(drawnText, { ["func"] = textengine.rawSetBackgroundColor, ["args"] = { bg } })
			textengine.rawSetBackgroundColor(bg) -- spoof for reading bg
		end
		textengine.setTextColor = function(fg)
			table.insert(drawnText, { ["func"] = textengine.rawSetTextColor, ["args"] = { fg } })
			textengine.rawSetTextColor(fg) -- spoof for reading fg
		end
		textengine.clear = function(_)
			drawnText = {}
		end
		textengine.setCursorPos = function(x, y)
			table.insert(drawnText, { ["func"] = textengine.rawSetCursorPos, ["args"] = { x, y } })
			textengine.rawSetCursorPos(x, y) -- spoof for reading cursor pos
		end

		term.redirect(textengine)
		luapng = require("/ion2d/lib/luapng")
		ion2d.initScene(1)
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
					pixels = pixels,
					width = cellW,
					height = cellH,
				}
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

	if not ion2d.spritemap[spriteX] then
		safeError("Sprite X index " .. spriteX .. " out of bounds (max: " .. #ion2d.spritemap .. ")")
	end

	if not ion2d.spritemap[spriteX][spriteY] then
		safeError("Sprite Y index " .. spriteY .. " out of bounds (max: " .. #ion2d.spritemap[spriteX] .. ")")
	end

	local sprite = ion2d.spritemap[spriteX][spriteY]
	local layerTable = ion2d.scenes[scene].layers[layer].entities

	local entity = {
		sprite = sprite,
		x = 1,
		y = 1,
		vx = 0,
		vy = 0,
		scene = scene,
		layer = layer,
		meta = {},
		_events = {
			onDestroy = {},
			onUpdate = {},
			onCollision = {},
		},
	}

	function entity:OnDestroy(callback)
		table.insert(self._events.onDestroy, callback)
		return {
			Disconnect = function()
				for i = #self._events.onDestroy, 1, -1 do
					if self._events.onDestroy[i] == callback then
						table.remove(self._events.onDestroy, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnUpdate(callback)
		table.insert(self._events.onUpdate, callback)
		return {
			Disconnect = function()
				for i = #self._events.onUpdate, 1, -1 do
					if self._events.onUpdate[i] == callback then
						table.remove(self._events.onUpdate, i)
						break
					end
				end
			end,
		}
	end

	function entity:OnCollision(callback)
		table.insert(self._events.onCollision, callback)
		return {
			Disconnect = function()
				for i = #self._events.onCollision, 1, -1 do
					if self._events.onCollision[i] == callback then
						table.remove(self._events.onCollision, i)
						break
					end
				end
			end,
		}
	end

	function entity:_fireEvent(eventName, ...)
		if self._events[eventName] then
			for _, callback in ipairs(self._events[eventName]) do
				pcall(callback, self, ...)
			end
		end
	end

	function entity:SetPosition(x, y)
		self.x = x
		self.y = y
	end

	function entity:Move(dx, dy)
		self.x = self.x + dx
		self.y = self.y + dy
	end

	function entity:GetPosition()
		return self.x, self.y
	end

	function entity:SetVelocity(vx, vy)
		self.vx = vx
		self.vy = vy
	end

	function entity:Thrust(vx, vy)
		self.vx = self.vx + vx
		self.vy = self.vy + vy
	end

	function entity:GetVelocity()
		return self.vx, self.vy
	end

	function entity:SetDrag(drag)
		self.drag = drag
	end

	function entity:GetAngle()
		return self.meta.angle
	end

	function entity:SetSprite(spriteX, spriteY)
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

	function entity:GetSize()
		return self.sprite.width, self.sprite.height
	end

	function entity:GetBounds()
		return self.x, self.y, self.x + self.sprite.width, self.y + self.sprite.height
	end

	function entity:ContainsPoint(px, py)
		local x1, y1, x2, y2 = self:GetBounds()
		return px >= x1 and px < x2 and py >= y1 and py < y2
	end

	function entity:CollidesWith(other)
		local x1, y1, x2, y2 = self:GetBounds()
		local ox1, oy1, ox2, oy2 = other:GetBounds()
		return x1 < ox2 and x2 > ox1 and y1 < oy2 and y2 > oy1
	end

	function entity:DistanceTo(other)
		local cx = self.x + self.sprite.width / 2
		local cy = self.y + self.sprite.height / 2
		local ocx = other.x + other.sprite.width / 2
		local ocy = other.y + other.sprite.height / 2
		local dx = cx - ocx
		local dy = cy - ocy
		return math.sqrt(dx * dx + dy * dy)
	end

	function entity:CenterAt(x, y)
		self.x = x - self.sprite.width / 2
		self.y = y - self.sprite.height / 2
	end

	function entity:GetCenter()
		return self.x + self.sprite.width / 2, self.y + self.sprite.height / 2
	end

	function entity:SetMeta(key, value)
		self.meta[key] = value
	end

	function entity:GetMeta(key)
		return self.meta[key]
	end

	function entity:IsDestroyed()
		return self.meta.destroyTime ~= nil
	end

	function entity:Stop()
		self.vx = 0
		self.vy = 0
	end

	function entity:RotateSprite(spriteXOffset, spriteYOffset)
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
			self:SetSprite(newX, newY)
		end
	end

	function entity:SetFlipX(flipped)
		self.meta.flipX = flipped
	end

	function entity:SetFlipY(flipped)
		self.meta.flipY = flipped
	end

	function entity:SetOpacity(opacity)
		self.meta.opacity = math.max(0, math.min(1, opacity))
	end

	function entity:GetOpacity()
		return self.meta.opacity or 1
	end

	function entity:SetLayer(newLayer)
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

	function entity:GetLayer()
		return self.layer
	end

	function entity:SetScene(newScene)
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
	end

	function entity:MoveRelative(forward, strafe)
		local angle = self.meta.angle or 0

		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward

		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe

		self:Move(forwardX + strafeX, forwardY + strafeY)
	end

	function entity:SetVelocityRelative(forward, strafe)
		local angle = self.meta.angle or 0

		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward

		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe

		self.vx = forwardX + strafeX
		self.vy = forwardY + strafeY
	end

	function entity:ThrustRelative(forward, strafe)
		local angle = self.meta.angle or 0

		local forwardX = math.cos(angle) * forward
		local forwardY = math.sin(angle) * forward

		local strafeX = math.cos(angle + math.pi / 2) * strafe
		local strafeY = math.sin(angle + math.pi / 2) * strafe

		self.vx = self.vx + forwardX + strafeX
		self.vy = self.vy + forwardY + strafeY
	end

	function entity:GetScene()
		return self.scene
	end

	function entity:MoveTowards(targetX, targetY, speed, dt)
		local cx, cy = self:GetCenter()
		local dx = targetX - cx
		local dy = targetY - cy
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist > 0 then
			local moveAmount = math.min(speed * dt, dist)
			local nx = dx / dist
			local ny = dy / dist
			self:Move(nx * moveAmount, ny * moveAmount)
			return dist <= speed * dt
		end
		return true
	end

	function entity:LookAt(x, y)
		local cx, cy = self:GetCenter()
		local targetX, targetY

		if type(x) == "table" and x.GetCenter then
			targetX, targetY = x:GetCenter()
		else
			targetX, targetY = x, y
		end

		local angle = math.atan2(targetY - cy, targetX - cx)
		self.meta.angle = angle
		return angle
	end

	function entity:AngleTo(x, y)
		local cx, cy = self:GetCenter()
		local targetX, targetY

		if type(x) == "table" and x.GetCenter then
			targetX, targetY = x:GetCenter()
		else
			targetX, targetY = x, y
		end

		return math.atan2(targetY - cy, targetX - cx)
	end

	function entity:RotateTowards(targetAngle, maxRotation)
		local diff = ion2d.angleDifference(self.meta.angle, targetAngle)

		if math.abs(diff) < maxRotation then
			self.meta.angle = targetAngle
		else
			self.meta.angle = self.meta.angle + (diff > 0 and maxRotation or -maxRotation)
		end
	end

	function entity:BounceOffEdges(width, height, damping)
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

	function entity:Accelerate(ax, ay, dt)
		self.vx = self.vx + ax * dt
		self.vy = self.vy + ay * dt
	end

	function entity:LimitSpeed(maxSpeed)
		local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
		if speed > maxSpeed then
			local scale = maxSpeed / speed
			self.vx = self.vx * scale
			self.vy = self.vy * scale
		end
	end

	function entity:Clone()
		local clone = ion2d.newCharacter(1, 1, self.scene, self.layer)
		clone.sprite = self.sprite
		clone.x = self.x
		clone.y = self.y
		clone.vx = self.vx
		clone.vy = self.vy
		clone.drag = self.drag
		for k, v in pairs(self.meta) do
			if k ~= "destroyTime" then
				clone.meta[k] = v
			end
		end
		return clone
	end

	function entity:GetSpeed()
		return math.sqrt(self.vx * self.vx + self.vy * self.vy)
	end

	function entity:SetSpeed(speed)
		local currentSpeed = self:GetSpeed()
		if currentSpeed > 0 then
			local scale = speed / currentSpeed
			self.vx = self.vx * scale
			self.vy = self.vy * scale
		end
	end

	function entity:Teleport(x, y, callback)
		local oldX, oldY = self.x, self.y
		self.x = x
		self.y = y
		if callback then
			callback(self, oldX, oldY)
		end
	end

	function entity:IsOnScreen(width, height, margin)
		margin = margin or 0
		return self.x + self.sprite.width >= -margin
			and self.x <= width + margin
			and self.y + self.sprite.height >= -margin
			and self.y <= height + margin
	end

	function entity:ClampToScreen(width, height)
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

	function entity:Destroy(time)
		self.meta.destroyTime = (os.epoch("utc") / 1000) + (time or 0)
		if time == nil or time == 0 then
			self:_fireEvent("onDestroy")
		end
	end

	table.insert(layerTable, entity)
	return entity
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

local function rotateSprite(sprite, angle)
	angle = angle % (2 * math.pi)

	local cacheKey = tostring(sprite) .. "_" .. tostring(math.floor(angle * 1000))

	if not ion2d._rotationCache then
		ion2d._rotationCache = {}
	end

	if ion2d._rotationCache[cacheKey] then
		return ion2d._rotationCache[cacheKey]
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

	return rotatedSprite
end

local function transformSprite(sprite, flipX, flipY, opacity)
	local cacheKey = tostring(sprite)
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

	function controller:SetDirection(direction)
		if direction == "left" or direction == "right" or direction == "up" or direction == "down" then
			self.lastDirection = direction
			local sprite = self.sprites[direction]
			self.character:SetSprite(sprite[1], sprite[2])
		end
	end

	function controller:GetDirection()
		return self.lastDirection
	end

	function controller:Move(dx, dy)
		if dx < 0 then
			self:SetDirection("left")
		elseif dx > 0 then
			self:SetDirection("right")
		elseif dy < 0 then
			self:SetDirection("up")
		elseif dy > 0 then
			self:SetDirection("down")
		end

		self.character:Move(dx, dy)
	end

	function controller:SetSprites(left, right, up, down)
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
	local layers = ion2d.scenes[scene].layers
	local time = os.epoch("utc") / 1000
	for _, layer in pairs(layers) do
		local ents = layer.entities
		for i = #ents, 1, -1 do
			if ents[i].meta.destroyTime then
				if ents[i].meta.destroyTime <= time then
					-- Fire onDestroy event before removal
					ents[i]:_fireEvent("onDestroy")
					table.remove(ents, i)
				end
			end
		end
	end
end

local function internalRenderText()
	for _, op in ipairs(drawnText) do
		op.func(table.unpack(op.args))
	end
end

function ion2d.renderScene(scene)
	local success, err = pcall(function()
		term.native().setFrozen(true)
		textengine.rawClear()
		local layers = ion2d.scenes[scene].layers
		for _, layer in pairs(layers) do
			local ents = layer.entities
			for i = 1, #ents do
				local entity = ents[i]
				local sprite = entity.sprite

				if entity.meta.flipX or entity.meta.flipY then
					sprite = transformSprite(sprite, entity.meta.flipX, entity.meta.flipY)
				end

				if entity.meta.angle and entity.meta.angle ~= 0 then
					sprite = rotateSprite(sprite, entity.meta.angle)

					local offsetX = (sprite.width - entity.sprite.width) / 2
					local offsetY = (sprite.height - entity.sprite.height) / 2
					term.drawPixels(entity.x - offsetX, entity.y - offsetY, sprite.pixels, sprite.width, sprite.height)
				else
					term.drawPixels(entity.x, entity.y, sprite.pixels, sprite.width, sprite.height)
				end
			end
		end
		internalRenderText()
		term.native().setFrozen(false)
	end)

	if not success then
		safeError("Render error: " .. tostring(err))
	end
end

ion2d.systems = {}

function ion2d.systems.movement(entity, dt)
	if entity.vx then
		entity.x = entity.x + entity.vx * dt
		entity.y = entity.y + entity.vy * dt
	end
end

function ion2d.systems.drag(entity, dt)
	if (not entity.drag) or (entity.drag == 0) then
		return
	end

	entity.vx = entity.vx * math.exp(-entity.drag * dt)
	entity.vy = entity.vy * math.exp(-entity.drag * dt)

	if math.abs(entity.vx) < 0.001 then
		entity.vx = 0
	end
	if math.abs(entity.vy) < 0.001 then
		entity.vy = 0
	end
end

function ion2d.update(dt)
	local success, err = pcall(function()
		ion2d.gcScene(ion2d.currentScene)

		for _, layer in pairs(ion2d.scenes[ion2d.currentScene].layers) do
			for _, e in ipairs(layer.entities) do
				e:_fireEvent("onUpdate", dt)

				for _, system in pairs(ion2d.systems) do
					system(e, dt)
				end
			end
		end

		ion2d.renderScene(ion2d.currentScene)
	end)

	if not success then
		safeError("Update error: " .. tostring(err))
	end
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

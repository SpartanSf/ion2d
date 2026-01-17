if not term.drawPixels then
	error("Must be using CraftOS-PC!")
end

local math_random = math.random
local math_sin = math.sin
local math_cos = math.cos
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_pi = math.pi
local os_epoch = os.epoch

local ion2d = require("/ion2d")

local success, err = pcall(function()
	ion2d.init()
	local screenW, screenH = term.getSize()
	screenW, screenH = screenW * 8, screenH * 8

	local spritemap = ion2d.newSpritemap("/demogame/spritemap.png", 16, 16)
	ion2d.setSpritemap(spritemap)

	ion2d.input.bind("turn_left", keys.a)
	ion2d.input.bind("turn_right", keys.d)
	ion2d.input.bind("thrust", keys.w)
	ion2d.input.bind("brake", keys.s)
	ion2d.input.bind("fire", keys.space)
	ion2d.input.bind("special", keys.leftShift)
	ion2d.input.bind("restart", keys.r)
	ion2d.input.bind("quit", keys.q)

	local player, camera, powerups, enemies
	local wave = 1
	local maxWave = 1
	local gameStats = { score = 0, kills = 0 }
	local DEBUG = false

	camera = ion2d.components.Camera:new({
		smoothing = 0.1,
	})

	local background = ion2d.newTilemap(16, 16)

	local tilesWide = 200
	local tilesHigh = 200

	for y = 1, tilesHigh do
		for x = 1, tilesWide do
			background:setTile(x, y, 4, 2)
		end
	end

	powerups = {
		types = {
			shield = { spriteX = 1, spriteY = 2, duration = 10 },
			rapidfire = { spriteX = 2, spriteY = 2, duration = 8 },
			multishot = { spriteX = 3, spriteY = 2, duration = 12 },
		},
	}

	function powerups.spawn(x, y, type)
		local def = powerups.types[type]
		if not def then
			if DEBUG then
				print("ERROR: Unknown powerup type: " .. tostring(type))
			end
			return
		end

		local powerup = ion2d.world.spawn("powerup", {
			spriteX = def.spriteX,
			spriteY = def.spriteY,
			centerAt = { x, y },
			properties = {
				powerupType = type,
				duration = def.duration,
			},
		})
		powerup.state.bobTime = 0
		powerup.state.startY = y

		if DEBUG then
			print("Spawned powerup: " .. type .. " at " .. x .. "," .. y)
		end

		return powerup
	end

	function powerups.updateAll(dt)
		local allPowerups = ion2d.world.getEntitiesOfType("powerup")
		local powerupCount = #allPowerups

		for i = 1, powerupCount do
			local p = allPowerups[i]
			local bobTime = p.state.bobTime + dt * 3
			p.state.bobTime = bobTime

			local offset = math_sin(bobTime) * 3
			local cx, cy = p:getCenter()
			p:centerAt(cx, p.state.startY + offset)
			p:setAngle(p:getAngle() + dt * 2)
		end
	end

	function powerups.activate(player, type)
		local def = powerups.types[type]
		if not def then
			return
		end

		player.state.powerups[type] = os.epoch("utc") / 1000 + def.duration

		local cx, cy = player:getCenter()
		ion2d.particles.explosion(cx, cy, 20, 100)
	end

	function powerups.isActive(player, type)
		if not player.state.powerups[type] then
			return false
		end
		local remaining = player.state.powerups[type] - os.epoch("utc") / 1000
		return remaining > 0
	end

	enemies = {
		behaviors = {},
		_frameCount = 0, 

	}

	function enemies.behaviors.chase(enemy, dt)
		if not player or player:isDestroyed() then
			return
		end

		local playerCx, playerCy = player:getCenter()
		local targetAngle = enemy:angleTo(playerCx, playerCy) + math_pi / 2

		enemy:rotateTowards(targetAngle, enemy:get("turnSpeed") * dt * 0.3)

		local distance = enemy:distanceTo(player)
		if distance > 150 then
			enemy:moveRelative(0, -enemy:get("moveSpeed") * dt * 0.5)
		end
	end

	function enemies.behaviors.strafe(enemy, dt)
		if not player or player:isDestroyed() then
			return
		end

		local time = os_epoch("utc") / 1000
		local wanderAngle = time * 0.5 + enemy.id
		enemy:setAngle(enemy:getAngle() + math_sin(wanderAngle) * dt * 0.5)
		enemy:moveRelative(0, -enemy:get("moveSpeed") * dt * 0.4)
	end

	function enemies.behaviors.kamikaze(enemy, dt)
		if not player or player:isDestroyed() then
			return
		end

		local playerCx, playerCy = player:getCenter()
		local targetAngle = enemy:angleTo(playerCx, playerCy) + math_pi / 2

		enemy:rotateTowards(targetAngle, enemy:get("turnSpeed") * dt * 0.4)
		enemy:moveRelative(0, -enemy:get("moveSpeed") * dt * 0.8)
	end

	function enemies.spawn(x, y, behavior)
		local enemy = ion2d.world.spawn("enemy", {
			spriteX = 2,
			spriteY = 1,
			centerAt = { x, y },
			team = "enemy",
			fireControl = {
				delay = 2.5 + math.random() * 1.5,
				aimError = 0.8,
			},
			properties = {
				moveSpeed = 15 + math.random() * 10,
				turnSpeed = 1.0 + math.random() * 0.3,
				behavior = behavior or "chase",
			},
		})
		enemy.state.health = 20 + wave * 3
		enemy.state.maxHealth = enemy.state.health
		enemy.state.hasHandler = false

		if DEBUG then
			print("Spawned enemy with " .. enemy.state.health .. " HP")
		end

		return enemy
	end

	function enemies.updateAll(dt)

		local allEnemies = ion2d.world.getEntitiesOfType("enemy")
		local enemyCount = #allEnemies

		local time = os_epoch("utc") / 1000
		local frameCount = enemies._frameCount + 1
		enemies._frameCount = frameCount

		local hasPlayer = player and not player:isDestroyed()
		local playerCx, playerCy
		if hasPlayer then
			playerCx, playerCy = player:getCenter()
		end

		for i = 1, enemyCount do
			local enemy = allEnemies[i]

			local behavior = enemy:get("behavior")
			if enemies.behaviors[behavior] then
				enemies.behaviors[behavior](enemy, dt)
			end

			enemy:wrapAroundScreen(screenW, screenH)

			if frameCount % 4 == 0 and math_random() < 0.2 then
				local bx, by = enemy:backward()
				local cx, cy = enemy:getCenter()
				ion2d.particles.trail(cx + bx * 8, cy + by * 8, enemy.vx, enemy.vy)
			end

			if hasPlayer and math_random() < 0.3 then
				local fireControl = enemy:getComponent(ion2d.components.FireControl)
				if fireControl and fireControl:canFire(time) then
					local aimAngle = enemy:angleTo(playerCx, playerCy)
					local aimError = (math_random() - 0.5) * fireControl.aimError
					local shootAngle = aimAngle + aimError

					local cx, cy = enemy:getCenter()
					local cosAngle = math_cos(shootAngle)
					local sinAngle = math_sin(shootAngle)

					ion2d.world.spawn("bullet", {
						spriteX = 5,
						spriteY = 1,
						centerAt = { cx, cy },
						angle = shootAngle,
						velocity = {
							cosAngle * 140,
							sinAngle * 140,
						},
						team = "enemy",
						lifetime = 2.5,
					})

					fireControl:recordFire(time)
				end
			end
		end
	end

	local function spawnWave(waveNum)
		local baseCount = 2 + math.floor(waveNum * 0.5)
		local behaviors = { "chase", "strafe", "kamikaze" }

		if DEBUG then
			print("Spawning wave " .. waveNum .. " with " .. baseCount .. " enemies")
		end

		for i = 1, baseCount do
			local angle = (i / baseCount) * math.pi * 2
			local radius = 150
			local x = screenW / 2 + math.cos(angle) * radius
			local y = screenH / 2 + math.sin(angle) * radius
			local behavior = behaviors[math.random(#behaviors)]
			enemies.spawn(x, y, behavior)
		end

		if waveNum >= 2 then
			local types = { "shield", "rapidfire", "multishot" }
			local type = types[math.random(#types)]
			powerups.spawn(screenW / 2 + (math.random() - 0.5) * 80, screenH / 2 + (math.random() - 0.5) * 80, type)
		end
	end

	local function setupPlayerHandler()
		player:OnCollisionEnter(function(self, other)
			if self:isDestroyed() then
				return
			end

			if other:is("bullet") then
				local bulletTeam = other:getComponent(ion2d.components.Team)
				if bulletTeam and bulletTeam.name == "enemy" then
					if not powerups.isActive(self, "shield") then
						self.state.health = self.state.health - 15
						camera:shake(6)

						if DEBUG then
							print("Player hit! Health: " .. self.state.health)
						end

						if self.state.health <= 0 then
							if DEBUG then
								print("Player died!")
							end
							gameStats.score = self.state.score
							gameStats.kills = self.state.kills
							ion2d.gameMessage = "GAME OVER! Wave " .. wave
							local cx, cy = self:getCenter()
							ion2d.particles.explosion(cx, cy, 20, 120)
							self:destroy(0)
							player = nil
							ion2d.setState("gameover")
							return
						end
					end
					other:destroy(0)
					local cx, cy = other:getCenter()
					ion2d.particles.explosion(cx, cy, 6, 60)
				end
			elseif other:is("powerup") then
				local type = other:get("powerupType")
				if DEBUG then
					print("Picked up powerup: " .. tostring(type))
				end
				powerups.activate(self, type)
				other:destroy(0)
			elseif other:is("enemy") then
				if not powerups.isActive(self, "shield") then
					self.state.health = self.state.health - 25
					camera:shake(10)

					if DEBUG then
						print("Player rammed enemy! Health: " .. self.state.health)
					end

					if self.state.health <= 0 then
						if DEBUG then
							print("Player died from ramming!")
						end
						gameStats.score = self.state.score
						gameStats.kills = self.state.kills
						ion2d.gameMessage = "GAME OVER! Wave " .. wave
						local cx, cy = self:getCenter()
						ion2d.particles.explosion(cx, cy, 20, 120)
						self:destroy(0)
						player = nil
						ion2d.setState("gameover")
						return
					end
				end
				other.state.health = 0
				local cx, cy = other:getCenter()
				ion2d.particles.explosion(cx, cy, 15, 100)
				other:destroy(0)
			end
		end)
	end

	local function setupEnemyHandler(enemy)
		enemy:OnCollisionEnter(function(self, other)
			if self:isDestroyed() then
				return
			end

			if other:is("bullet") then
				local bulletTeam = other:getComponent(ion2d.components.Team)
				if bulletTeam and bulletTeam.name == "player" then
					self.state.health = self.state.health - 25

					if DEBUG then
						print("Enemy hit! Health: " .. self.state.health)
					end

					other:destroy(0)
					local cx, cy = other:getCenter()
					ion2d.particles.explosion(cx, cy, 6, 60)
					camera:shake(3)

					if self.state.health <= 0 then
						if DEBUG then
							print("Enemy destroyed!")
						end

						if player and not player:isDestroyed() then
							player.state.score = player.state.score + 100 * wave
							player.state.kills = player.state.kills + 1
							player.state.specialCharge =
								math.min(player.state.maxSpecialCharge, player.state.specialCharge + 15)
						end
						local cx, cy = self:getCenter()
						ion2d.particles.explosion(cx, cy, 20, 120)
						camera:shake(8)
						self:destroy(0)
					end
				end
			end
		end)
	end

	local function initGame()
		if DEBUG then
			print("Initializing game...")
		end

		for _, entity in ipairs(ion2d.world.getAllEntities()) do
			entity:destroy(0)
		end

		wave = 1
		gameStats = { score = 0, kills = 0 }

		player = ion2d.world.spawn("player", {
			spriteX = 1,
			spriteY = 1,
			centerAt = { screenW / 2, screenH / 2 },
			team = "player",
			fireControl = {
				delay = 0.15,
				aimError = 0,
			},
			properties = {
				maxSpeed = 120,
				acceleration = 150,
				turnSpeed = 4,
			},
		})

		player.state.health = 100
		player.state.maxHealth = 100
		player.state.score = 0
		player.state.kills = 0
		player.state.powerups = {}
		player.state.specialCharge = 0
		player.state.maxSpecialCharge = 100
		player:setDrag(1.5)

		setupPlayerHandler()

		camera:follow(player)
		camera:setBounds(0, 0, 200, 200)

		spawnWave(wave)

		if DEBUG then
			print("Game initialized. Player at " .. screenW / 2 .. "," .. screenH / 2)
		end
	end

	local thrustFrameCount = 0 

	ion2d.stateMachine = ion2d.StateMachine:new({
		playing = {
			enter = function()
				initGame()
				thrustFrameCount = 0 

			end,

			update = function(dt)

				local time = os_epoch("utc") / 1000
				local hasPlayer = player and not player:isDestroyed()

				if hasPlayer then
					if ion2d.input.down("turn_left") then
						player:setAngle(player:getAngle() - player:get("turnSpeed") * dt)
					end
					if ion2d.input.down("turn_right") then
						player:setAngle(player:getAngle() + player:get("turnSpeed") * dt)
					end

					if ion2d.input.down("thrust") then
						local accel = player:get("acceleration")
						player:thrustRelative(0, -accel * dt)

						thrustFrameCount = thrustFrameCount + 1
						if thrustFrameCount >= 5 then
							thrustFrameCount = 0
							local bx, by = player:backward()
							local cx, cy = player:getCenter()
							ion2d.particles.trail(cx + bx * 8, cy + by * 8, player.vx, player.vy)
						end
					end

					if ion2d.input.down("brake") then
						player.vx = player.vx * 0.9
						player.vy = player.vy * 0.9
					end

					player:limitSpeed(player:get("maxSpeed"))

					player:wrapAroundScreen(screenW, screenH)

					local fireDelay = 0.15
					if powerups.isActive(player, "rapidfire") then
						fireDelay = 0.08
					end

					if ion2d.input.down("fire") then
						local fireControl = player:getComponent(ion2d.components.FireControl)
						fireControl.delay = fireDelay

						if fireControl:canFire(time) then
							local angle = player:getAngle() - math_pi / 2
							local cx, cy = player:getCenter()
							local fx, fy = player:forward()

							local cosAngle = math_cos(angle)
							local sinAngle = math_sin(angle)

							ion2d.world.spawn("bullet", {
								spriteX = 3,
								spriteY = 1,
								centerAt = { cx + fx * 8, cy + fy * 8 },
								angle = angle,
								velocity = {
									cosAngle * 220 + player.vx,
									sinAngle * 220 + player.vy,
								},
								team = "player",
								lifetime = 2,
							})

							if powerups.isActive(player, "multishot") then
								for _, offset in ipairs({ -0.3, 0.3 }) do
									local spreadAngle = angle + offset
									local cosSpread = math_cos(spreadAngle)
									local sinSpread = math_sin(spreadAngle)

									ion2d.world.spawn("bullet", {
										spriteX = 3,
										spriteY = 1,
										centerAt = { cx, cy },
										angle = spreadAngle,
										velocity = {
											cosSpread * 200 + player.vx,
											sinSpread * 200 + player.vy,
										},
										team = "player",
										lifetime = 2,
									})
								end
							end

							fireControl:recordFire(time)
							camera:shake(1)
						end
					end

					if ion2d.input.down("special") and player.state.specialCharge >= 100 then
						player.state.specialCharge = 0

						local cx, cy = player:getCenter()

						for i = 1, 12 do
							local angle = (i / 12) * math_pi * 2
							local cosAngle = math_cos(angle)
							local sinAngle = math_sin(angle)

							ion2d.world.spawn("bullet", {
								spriteX = 3,
								spriteY = 1,
								centerAt = { cx, cy },
								angle = angle,
								velocity = {
									cosAngle * 200,
									sinAngle * 200,
								},
								team = "player",
								lifetime = 1.5,
							})
						end

						ion2d.particles.explosion(cx, cy, 20, 150)
						camera:shake(15)
					end

					if player.state.specialCharge < 100 then
						player.state.specialCharge = player.state.specialCharge + dt * 5
					end
				end

				camera:update(dt, screenW, screenH)

				if hasPlayer then
					enemies.updateAll(dt)
					powerups.updateAll(dt)
				end

				if hasPlayer then
					ion2d.collision.checkBetween("bullet", "player")
					ion2d.collision.checkBetween("player", "powerup")
					ion2d.collision.checkBetween("player", "enemy")
				end
				ion2d.collision.checkBetween("bullet", "enemy")

				local allEnemies = ion2d.world.getEntitiesOfType("enemy")
				local enemyCount = #allEnemies
				for i = 1, enemyCount do
					local enemy = allEnemies[i]
					if not enemy.state.hasHandler then
						enemy.state.hasHandler = true
						setupEnemyHandler(enemy)
					end
				end

				if hasPlayer then
					local remainingEnemies = ion2d.world.getEntityCount("enemy")
					if remainingEnemies == 0 then
						wave = wave + 1
						maxWave = math_max(maxWave, wave)
						spawnWave(wave)
					end
				end

				if player and not player:isDestroyed() then
					term.clear()
					term.setCursorPos(1, 1)
					term.write("HP: " .. math_max(0, player.state.health) .. "/" .. player.state.maxHealth)
					term.setCursorPos(1, 2)
					term.write("Score: " .. player.state.score)
					term.setCursorPos(1, 3)
					term.write("Wave: " .. wave)
					term.setCursorPos(1, 4)
					term.write("Special: " .. math_floor(player.state.specialCharge) .. "%")

					local line = 5
					local powerupTypes = powerups.types
					for type, _ in pairs(powerupTypes) do
						if powerups.isActive(player, type) then
							term.setCursorPos(1, line)
							local remaining = player.state.powerups[type] - time
							term.write(type:upper() .. ": " .. string.format("%.1fs", remaining))
							line = line + 1
						end
					end

					if DEBUG then
						term.setCursorPos(1, line + 1)
						term.write("Enemies: " .. ion2d.world.getEntityCount("enemy"))
						term.setCursorPos(1, line + 2)
						term.write("Powerups: " .. ion2d.world.getEntityCount("powerup"))
					end
				end
			end,
		},

		gameover = {
			enter = function()

				local bullets = ion2d.world.getEntitiesOfType("bullet")
				local bulletCount = #bullets
				for i = 1, bulletCount do
					bullets[i]:destroy(0)
				end
				ion2d.gameoverEnterTime = os_epoch("utc") / 1000
			end,

			update = function(dt)

				camera:update(dt, screenW, screenH)

				term.clear()
				term.setCursorPos(1, 1)
				term.write(ion2d.gameMessage or "Game Over")
				term.setCursorPos(1, 2)
				term.write("Final Score: " .. gameStats.score)
				term.setCursorPos(1, 3)
				term.write("Kills: " .. gameStats.kills)
				term.setCursorPos(1, 4)
				term.write("Max Wave: " .. maxWave)
				term.setCursorPos(1, 6)
				term.write("Press R to restart or Q to quit")

				local timeSinceEnter = os_epoch("utc") / 1000 - ion2d.gameoverEnterTime
				if timeSinceEnter > 0.5 then
					if ion2d.input.down("restart") then
						ion2d.setState("playing")
					elseif ion2d.input.down("quit") then
						term.setGraphicsMode(0)
						term.redirect(term.native())
						term.clear()
						term.setCursorPos(1, 1)
						error("Game quit")
					end
				end
			end,
		},
	})

	ion2d.setState("playing")

	ion2d.setTilemap(background)

	parallel.waitForAny(function()
		while true do
			local event, key = os.pullEvent()
			if event == "key" then
				ion2d.input.updateKeyState(key, true)
			elseif event == "key_up" then
				ion2d.input.updateKeyState(key, false)
			end
		end
	end, function()
		local lastTime = os.epoch("utc") / 1000
		while true do
			local time = os.epoch("utc") / 1000
			local dt = time - lastTime

			if dt >= 0.016 then
				ion2d.step(dt)
				ion2d.render(camera)
				lastTime = time
			end

			sleep(0)
		end
	end)
end)

if not success then
	term.setGraphicsMode(0)
	term.redirect(term.native())
	term.clear()
	term.setCursorPos(1, 1)
	print("ERROR:")
	print(tostring(err))
end


if not term.drawPixels then
    error("Must be using CraftOS-PC!")
end

local ion2d = require("/ion2d")
ion2d.init()
local screenW, screenH = term.getSize()
screenW, screenH = screenW * 8, screenH * 8 -- Convert characters to pixels (textengine)

-- Sets up a sprite map to use, with 16*16 sprites
local spritemap = ion2d.newSpritemap("/demogame/spritemap.png", 16, 16)
ion2d.setSpritemap(spritemap)
-- Creates a new character from sprite map x=1, y=1
local character = ion2d.newCharacter(1, 1)
character:SetPosition(32, 32)
character.meta.team = "player"

-- Create enemy tank
local enemy = ion2d.newCharacter(2, 1)
enemy:SetPosition(250, 32)
enemy.meta.team = "enemy"
enemy.meta.lastFireTime = 0
enemy.meta.fireDelay = 1.0
enemy.meta.angle = 0

local bullets = {}
local lastFireTime = 0
local fireDelay = 0.3
local gameOver = false
local gameMessage = ""

local function fireBullet(tank, team)
	local angle = tank:GetAngle() or 0

    local adjustedAngle = angle - math.pi / 2
	local cx, cy = tank:GetCenter()

    local spawnDistance = 0
	local bulletX = cx + math.cos(adjustedAngle) * spawnDistance
	local bulletY = cy + math.sin(adjustedAngle) * spawnDistance

    local bullet = ion2d.newCharacter(3, 1)
	bullet:CenterAt(bulletX, bulletY)
	bullet.meta.angle = adjustedAngle
	bullet.meta.team = team

    local bulletSpeed = 200
	bullet:SetVelocity(math.cos(adjustedAngle) * bulletSpeed, math.sin(adjustedAngle) * bulletSpeed)

    bullet:Destroy(3)
	table.insert(bullets, bullet)
end

local function updateEnemy(dt, time)
	if gameOver then
		return
	end

	local rawAngle = enemy:AngleTo(character:GetCenter())
	local aimError = (math.random() - 0.5) * 0.3
	local targetAngle = rawAngle + math.pi / 2 + aimError

	local enemyTurnSpeed = 2
	enemy:RotateTowards(targetAngle, enemyTurnSpeed * dt)

	local distance = enemy:DistanceTo(character)
	local idealDistance = 120

	local moveForward = 0
	local moveStrafe = 0

	if distance > idealDistance + 40 then
		moveForward = -25 * dt
	elseif distance < idealDistance - 40 then
		moveForward = 25 * dt
	else
		moveForward = math.sin(time * 1.5) * 15 * dt
	end

	moveStrafe = math.cos(time * 2) * 35 * dt

	enemy:MoveRelative(0, moveStrafe)
	enemy:MoveRelative(0, moveForward)

	local timeSinceLastFire = time - enemy.meta.lastFireTime
	if timeSinceLastFire >= enemy.meta.fireDelay then
		fireBullet(enemy, "enemy")
		enemy.meta.lastFireTime = time
	end

    enemy:ClampToScreen()
end

local function removeBullets()
    for i = #bullets, 1, -1 do
        bullets[i]:Destroy(0)
    end
end

local function checkCollisions()
	if gameOver then
		return
	end

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]

		if bullet.meta.team == "enemy" and bullet:CollidesWith(character) then
			gameOver = true
            removeBullets()
			gameMessage = "YOU DIED! Enemy wins!"
			return
		end

		if bullet.meta.team == "player" and bullet:CollidesWith(enemy) then
			gameOver = true
            removeBullets()
			gameMessage = "YOU WIN! Enemy destroyed!"
			return
		end
	end
end

local keysPressed = {}
parallel.waitForAny(function() -- Tracks which keys are being pressed
	while true do
		local event, key = os.pullEvent()
		if event == "key" then
			keysPressed[key] = true
		elseif event == "key_up" then
			keysPressed[key] = false
		end
	end
end, function() -- Main game run loop + key press handling
	local lastTime = os.epoch("utc") / 1000
	while true do
		local time = os.epoch("utc") / 1000
		local dt = time - lastTime -- Delta time, so the game always runs at the same rate physically
		if dt >= 0.05 then
			if not gameOver then
				local moveSpeed = 40 -- 40 pixels/second
				local turnSpeed = 3 -- Radians per second (about 172 degrees/sec)

				if keysPressed[keys.a] then
					character.meta.angle = (character.meta.angle or 0) - turnSpeed * dt
				end
				if keysPressed[keys.d] then
					character.meta.angle = (character.meta.angle or 0) + turnSpeed * dt
				end

				local forward = 0
				if keysPressed[keys.w] then
					forward = moveSpeed * dt
				end
				if keysPressed[keys.s] then
					forward = -moveSpeed * dt
				end
				if forward ~= 0 then
					character:MoveRelative(0, -forward)
				end

				local timeSinceLastFire = time - lastFireTime
				if keysPressed[keys.space] then
					if timeSinceLastFire >= fireDelay then
						fireBullet(character, "player")
						lastFireTime = time
					end
				end

                character:ClampToScreen()

				updateEnemy(dt, time)

				checkCollisions()

				term.clear()
				term.setCursorPos(1, 1)
				local cooldownRemaining = math.max(0, fireDelay - timeSinceLastFire)
				if cooldownRemaining > 0 then
					term.write("Cooldown: " .. string.format("%.2f", cooldownRemaining) .. "s")
				else
					term.write("Ready to fire!")
				end
			else
				term.clear()
				term.setCursorPos(1, 1)
				term.write(gameMessage)
				term.setCursorPos(1, 2)
				term.write("Press R to restart or Q to quit")

				if keysPressed[keys.r] then
					enemy:Destroy(0)

					gameOver = false
					gameMessage = ""
					character:SetPosition(32, 32)
					character.meta.angle = 0

					enemy = ion2d.newCharacter(2, 1)
					enemy:SetPosition(250, 32)
					enemy.meta.team = "enemy"
					enemy.meta.lastFireTime = 0
					enemy.meta.fireDelay = 1.0
					enemy.meta.angle = 0

					for i = #bullets, 1, -1 do
						bullets[i]:Destroy(0)
						table.remove(bullets, i)
					end
					lastFireTime = 0
				elseif keysPressed[keys.q] then
					term.setGraphicsMode(0)
					term.redirect(term.native())
					term.clear()
					term.setCursorPos(1, 1)
					return
				end
			end

			ion2d.update(dt) -- Updates the screen and runs background processes
			lastTime = time
		end
		sleep(0)
	end
end)

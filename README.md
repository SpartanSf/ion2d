# ion2d Documentation

ion2d is a 2D game engine for CraftOS-PC with sprite rendering, entity management, physics, collision detection, and more.

## Table of Contents

1. [Getting Started](##getting-started)
2. [Initialization](#initialization)
3. [Sprites and Spritesheets](#sprites-and-spritesheets)
4. [Entities](#entities)
5. [World Management](#world-management)
6. [Components](#components)
7. [Input System](#input-system)
8. [Camera System](#camera-system)
9. [Collision Detection](#collision-detection)
10. [Particle System](#particle-system)
11. [Tilemaps](#tilemaps)
12. [State Machine](#state-machine)
13. [ECS Systems](#ecs-systems)
14. [Utility Functions](#utility-functions)

---

## Getting Started

### Installation

Run `wget run https://raw.githubusercontent.com/SpartanSf/ion2d/refs/heads/main/installer.lua` in the terminal or download and run the `installer.lua` file in this repo.

### Basic Setup

```lua
local ion2d = require("/ion2d")

ion2d.init()

-- Load a spritesheet with 16*16 pixel sprites
local spritemap = ion2d.newSpritemap("/path/to/spritesheet.png", 16, 16)
ion2d.setSpritemap(spritemap)

-- Create a game loop
local lastTime = os.epoch("utc") / 1000
while true do
    local time = os.epoch("utc") / 1000
    local dt = time - lastTime
    
    if dt >= 0.016 then
        ion2d.step(dt)
        ion2d.render()
        lastTime = time
    end
    
    sleep(0)
end
```

---

## Initialization

### ion2d.init()

Initializes the engine. Must be called before using any other ion2d functions.

```lua
ion2d.init()
```

This function:
- Sets graphics mode
- Initializes the text engine
- Creates the default scene
- Registers built-in systems

---

## Sprites and Spritesheets

### ion2d.newSpritemap(file, cellW, cellH)

Loads a PNG spritesheet and divides it into sprites.

**Parameters:**
- `file` (string): Path to the PNG file
- `cellW` (number): Width of each sprite cell
- `cellH` (number): Height of each sprite cell

**Returns:** Spritemap table

```lua
local spritemap = ion2d.newSpritemap("/demogame/spritemap.png", 16, 16)
```

### ion2d.setSpritemap(spritemap)

Sets the active spritesheet for the engine.

```lua
ion2d.setSpritemap(spritemap)
```

### ion2d.getSpritemap()

Returns the currently active spritesheet.

```lua
local currentMap = ion2d.getSpritemap()
```

---

## Entities

Entities are the core game objects in ion2d. They have position, velocity, sprites, and can have components attached.

### Creating Entities

#### ion2d.newCharacter(spriteX, spriteY, scene, layer)

Creates a basic entity.

**Parameters:**
- `spriteX` (number): X coordinate in spritesheet (1-indexed)
- `spriteY` (number): Y coordinate in spritesheet (1-indexed)
- `scene` (number, optional): Scene number (default: 1)
- `layer` (number, optional): Layer number (default: 1)

```lua
local player = ion2d.newCharacter(1, 1, 1, 1)
player:setPosition(100, 100)
player:setVelocity(50, 0)
```

### Entity Properties

#### Position and Movement

```lua
-- Set absolute position
entity:setPosition(x, y)

-- Move relative to current position
entity:move(dx, dy)

-- Get current position
local x, y = entity:getPosition()

-- Set velocity
entity:setVelocity(vx, vy)

-- Add to velocity (thrust)
entity:thrust(vx, vy)

-- Get velocity
local vx, vy = entity:getVelocity()

-- Stop all movement
entity:stop()
```

#### Centering

```lua
-- Center entity at a point
entity:centerAt(x, y)

-- Get center position
local cx, cy = entity:getCenter()
```

#### Rotation

```lua
-- Set angle in radians
entity:setAngle(angle)

-- Get current angle
local angle = entity:getAngle()

-- Get directional vectors
local fx, fy = entity:forward()
local rx, ry = entity:right()
local bx, by = entity:backward()
local lx, ly = entity:left()
```

#### Sprites and Appearance

```lua
-- Change sprite
entity:setSprite(spriteX, spriteY)

-- Rotate through sprites
entity:rotateSprite(offsetX, offsetY)

-- Flip sprite
entity:setFlipX(true)
entity:setFlipY(true)

-- Set opacity (0.0 to 1.0)
entity:setOpacity(0.5)
local opacity = entity:getOpacity()

-- Get sprite dimensions
local width, height = entity:getSize()
```

#### Physics

```lua
-- Set drag coefficient
entity:setDrag(1.5)

-- Accelerate
entity:accelerate(ax, ay, dt)

-- Limit maximum speed
entity:limitSpeed(maxSpeed)

-- Get/set speed
local speed = entity:getSpeed()
entity:setSpeed(newSpeed)
```

#### Relative Movement

```lua
-- Move relative to entity's rotation
entity:moveRelative(forward, strafe)

-- Set velocity relative to rotation
entity:setVelocityRelative(forward, strafe)

-- Thrust relative to rotation
entity:thrustRelative(forward, strafe)
```

#### Advanced Movement

```lua
-- Move towards a target
local arrived = entity:moveTowards(targetX, targetY, speed, dt)

-- Look at a point or entity
entity:lookAt(x, y)
entity:lookAt(otherEntity)

-- Get angle to a point
local angle = entity:angleTo(x, y)

-- Rotate towards an angle smoothly
entity:rotateTowards(targetAngle, maxRotation)
```

#### Screen Boundaries

```lua
-- Bounce off edges
local bounced = entity:bounceOffEdges(width, height, damping)

-- Wrap around screen
entity:wrapAroundScreen(width, height)

-- Check if on screen
local visible = entity:isOnScreen(width, height, margin)

-- Clamp to screen
entity:clampToScreen(width, height)
```

#### Collision

```lua
-- Check collision with another entity
local colliding = entity:checkCollision(other)

-- Get bounds
local x1, y1, x2, y2 = entity:getBounds()

-- Check if point is inside
local inside = entity:containsPoint(px, py)

-- Get distance to another entity
local dist = entity:distanceTo(other)
```

#### Custom Properties

```lua
-- Set custom property
entity:set("health", 100)
entity:set("type", "player")

-- Get custom property
local health = entity:get("health")

-- Check entity type
if entity:is("enemy") then
    -- Do something
end
```

#### State and Metadata

```lua
-- Use state for game-specific data
entity.state.health = 100
entity.state.powerups = {}

-- Use meta for engine-specific data
entity.meta.customData = "value"
entity:setMeta("key", "value")
local value = entity:getMeta("key")
```

#### Lifecycle

```lua
-- Check if destroyed
if entity:isDestroyed() then
    -- Entity is marked for removal
end

-- Destroy entity
entity:destroy(0) -- Destroy immediately
entity:destroy(2) -- Destroy after 2 seconds

-- Clone entity
local copy = entity:clone()
```

#### Layers and Scenes

```lua
-- Move to different layer
entity:setLayer(2)
local layer = entity:getLayer()

-- Move to different scene
entity:setScene(2)
local scene = entity:getScene()
```

### Entity Events

Entities support event callbacks for various situations.

```lua
-- Called every frame
entity:OnUpdate(function(self, dt)
    print("Updating with dt: " .. dt)
end)

-- Called when entity is destroyed
entity:OnDestroy(function(self)
    print("Entity destroyed!")
end)

-- Called when collision starts
entity:OnCollisionEnter(function(self, other)
    print("Collided with: " .. other.id)
end)

-- Called while collision continues
entity:OnCollisionStay(function(self, other)
    print("Still colliding with: " .. other.id)
end)

-- Called when collision ends
entity:OnCollisionExit(function(self, other)
    print("Stopped colliding with: " .. other.id)
end)

-- Shorthand for OnCollisionEnter
entity:OnCollision(function(self, other)
    print("Hit something!")
end)
```

All event handlers return a connection object that can be disconnected:

```lua
local connection = entity:OnUpdate(function(self, dt)
    -- Do something
end)

-- Later, disconnect the event
connection:Disconnect()
```

---

## World Management

The world module provides high-level entity spawning and querying.

### ion2d.world.spawn(entityType, config)

Spawns a new entity with the given configuration.

**Parameters:**
- `entityType` (string): Type identifier for the entity
- `config` (table): Configuration table

**Config options:**
- `spriteX`, `spriteY`: Sprite coordinates
- `position`: {x, y} table for position
- `centerAt`: {x, y} table to center at
- `velocity`: {vx, vy} table for velocity
- `angle`: Initial rotation angle
- `forwardAngleOffset`: Offset for forward direction
- `team`: Team name (adds Team component)
- `lifetime`: Duration in seconds (adds Lifetime component)
- `fireControl`: Fire control config (adds FireControl component)
- `properties`: Table of custom properties
- `scene`: Target scene (default: current)
- `layer`: Target layer (default: 1)

```lua
-- Spawn a player
local player = ion2d.world.spawn("player", {
    spriteX = 1,
    spriteY = 1,
    centerAt = {100, 100},
    velocity = {50, 0},
    team = "player",
    properties = {
        health = 100,
        maxSpeed = 120
    }
})

-- Spawn a bullet
local bullet = ion2d.world.spawn("bullet", {
    spriteX = 3,
    spriteY = 1,
    centerAt = {x, y},
    angle = shootAngle,
    velocity = {vx, vy},
    team = "player",
    lifetime = 2.0
})

-- Spawn an enemy with fire control
local enemy = ion2d.world.spawn("enemy", {
    spriteX = 2,
    spriteY = 1,
    centerAt = {200, 150},
    team = "enemy",
    fireControl = {
        delay = 2.5,
        aimError = 0.8
    },
    properties = {
        behavior = "chase",
        moveSpeed = 20
    }
})
```

### Querying Entities

```lua
-- Get entity by ID
local entity = ion2d.world.getById(entityId, scene)

-- Get all entities in scene
local allEntities = ion2d.world.getAllEntities(scene)

-- Get entities of a specific type
local enemies = ion2d.world.getEntitiesOfType("enemy", scene)

-- Get count of entity type
local enemyCount = ion2d.world.getEntityCount("enemy", scene)

-- Get entities with specific component
local controllable = ion2d.world.getEntitiesWithComponent(
    ion2d.components.FireControl, 
    scene
)
```

---

## Components

Components add specific behaviors and data to entities.

### Team Component

Groups entities into teams for collision filtering.

```lua
local team = ion2d.components.Team:new("player")
entity:addComponent(team)

-- Check team
local teamComp = entity:getComponent(ion2d.components.Team)
if teamComp and teamComp.name == "player" then
    -- Do something
end
```

### Lifetime Component

Automatically destroys entity after duration.

```lua
local lifetime = ion2d.components.Lifetime:new(2.5) -- 2.5 seconds
entity:addComponent(lifetime)

-- Check if expired
if lifetime:isExpired() then
    print("Expired!")
end
```

### FireControl Component

Manages shooting cooldowns and aim.

```lua
local fireControl = ion2d.components.FireControl:new({
    delay = 0.5,      -- Time between shots
    aimError = 0.1    -- Random aim offset
})
entity:addComponent(fireControl)

-- Use in game loop
local time = os.epoch("utc") / 1000
if fireControl:canFire(time) then
    -- Spawn bullet
    fireControl:recordFire(time)
end
```

### Managing Components

```lua
-- Add component
entity:addComponent(component)

-- Get component
local comp = entity:getComponent(ion2d.components.Team)

-- Check if has component
if entity:hasComponent(ion2d.components.Lifetime) then
    print("Has lifetime")
end

-- Remove component
entity:removeComponent(ion2d.components.Team)
```

---

## Input System

The input system provides key binding and state tracking.

### Binding Keys

```lua
-- Bind actions to keys
ion2d.input.bind("move_left", keys.a)
ion2d.input.bind("move_right", keys.d)
ion2d.input.bind("jump", keys.space)
ion2d.input.bind("shoot", keys.leftCtrl)
```

### Checking Input

```lua
-- Check if key is currently down (reccomended use)
if ion2d.input.down("move_left") then
    player:move(-speed * dt, 0)
end

-- Check if key was just pressed this frame
if ion2d.input.pressed("jump") then
    player:thrust(0, -jumpForce)
end

-- Check if key was just released this frame
if ion2d.input.released("shoot") then
    print("Stopped shooting")
end
```

### Handling Input Events

You may handle key events with `ion2d.input.updateKeyState`:

```lua
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
    -- Game loop
end)
```

### Complete Input Example

```lua
ion2d.input.bind("left", keys.a)
ion2d.input.bind("right", keys.d)
ion2d.input.bind("up", keys.w)
ion2d.input.bind("down", keys.s)
ion2d.input.bind("fire", keys.space)

function updatePlayer(dt)
    if ion2d.input.down("left") then
        player:setAngle(player:getAngle() - turnSpeed * dt)
    end
    if ion2d.input.down("right") then
        player:setAngle(player:getAngle() + turnSpeed * dt)
    end
    if ion2d.input.down("up") then
        player:thrustRelative(0, -acceleration * dt)
    end
    if ion2d.input.pressed("fire") then
        spawnBullet()
    end
end
```

---

## Camera System

The camera controls the viewport and can follow entities.

### Creating a Camera

```lua
local camera = ion2d.components.Camera:new({
    x = 0,
    y = 0,
    smoothing = 0.1,  -- Lower for smoother following
})
```

### Following Entities

```lua
-- Follow an entity
camera:follow(player)

-- Follow with offset
camera:follow(player, offsetX, offsetY)

-- Stop following
camera:stopFollowing()
```

### Camera Bounds

```lua
-- Constrain camera to world bounds
camera:setBounds(minX, minY, maxX, maxY)

-- Example: Keep camera in 200x200 tile world
camera:setBounds(0, 0, 200 * 16, 200 * 16)
```

### Camera Effects

```lua
-- Shake the camera
camera:shake(intensity) -- intensity 1-20

-- Set position directly
camera:setPosition(x, y)

-- Get camera position
local x, y = camera:getPosition()
```

### Coordinate Conversion

```lua
-- Convert world coordinates to screen
local screenX, screenY = camera:worldToScreen(worldX, worldY)

-- Convert screen coordinates to world
local worldX, worldY = camera:screenToWorld(screenX, screenY)

-- Get view bounds
local x1, y1, x2, y2 = camera:getViewBounds()

-- Check if entity is visible
if camera:isVisible(entity) then
    -- Draw custom effects
end
```

### Updating and Rendering

```lua
-- Update camera (call every frame before rendering)
camera:update(dt, screenWidth, screenHeight)

-- Render with camera
ion2d.render(camera)
```

### Camera Example

```lua
local camera = ion2d.components.Camera:new({
    smoothing = 0.1,
})

camera:follow(player)
camera:setBounds(0, 0, 3200, 3200) -- 200x200 tiles at 16px

-- In game loop
function update(dt)
    local screenW, screenH = term.getSize()
    screenW, screenH = screenW * 8, screenH * 8
    
    camera:update(dt, screenW, screenH)
    
    -- Shake on explosion
    if explosionHappened then
        camera:shake(10)
    end
end
```

---

## Collision Detection

ion2d provides flexible collision detection systems.

### Basic Collision

```lua
-- Check collision between two entities
if entity1:checkCollision(entity2) then
    print("Collision detected!")
end
```

### Collision Events

```lua
player:OnCollisionEnter(function(self, other)
    if other:is("enemy") then
        self.state.health = self.state.health - 10
    elseif other:is("powerup") then
        -- Collect powerup
        other:destroy(0)
    end
end)
```

### World Collision Checking

```lua
-- Check all entities against each other
ion2d.collision.checkAll(scene)

-- Check collisions between specific types (more efficient)
ion2d.collision.checkBetween("bullet", "enemy")
ion2d.collision.checkBetween("player", "powerup")
```

### Spatial Hashing

For large numbers of entities, enable spatial hashing:

```lua
-- Enable spatial hash optimization
ion2d.collision.useSpatialHash = true

-- Set grid cell size (tune for your entity sizes)
ion2d.collision.gridCellSize = 32
```

### Collision Example

```lua
-- Setup collision handlers
player:OnCollisionEnter(function(self, other)
    if other:is("bullet") then
        local bulletTeam = other:getComponent(ion2d.components.Team)
        if bulletTeam and bulletTeam.name == "enemy" then
            self.state.health = self.state.health - 15
            other:destroy(0)
            
            if self.state.health <= 0 then
                self:destroy(0)
                gameOver()
            end
        end
    end
end)

-- In game loop
function update(dt)
    -- Update entities...
    
    -- Check collisions
    ion2d.collision.checkBetween("bullet", "player")
    ion2d.collision.checkBetween("bullet", "enemy")
    ion2d.collision.checkBetween("player", "powerup")
end
```

---

## Particle System

ion2d includes an optimized particle system with object pooling.

### Spawning Individual Particles

```lua
-- Spawn a single particle
ion2d.particles.spawn(x, y, vx, vy, lifetime, spriteX, spriteY)

-- Example
ion2d.particles.spawn(100, 100, 50, -30, 0.5, 4, 1)
```

### Particle Effects

```lua
-- Create explosion effect
ion2d.particles.explosion(x, y, count, speed, spriteX, spriteY)

-- Example: 20 particles at speed 100
ion2d.particles.explosion(centerX, centerY, 20, 100)

-- Create trail effect
ion2d.particles.trail(x, y, vx, vy, spriteX, spriteY)

-- Example: Engine trail
if thrusting then
    local bx, by = player:backward()
    local cx, cy = player:getCenter()
    ion2d.particles.trail(cx + bx * 8, cy + by * 8, player.vx, player.vy)
end
```

### Particle Emitter Component

For continuous particle emission:

```lua
local emitter = ion2d.components.ParticleEmitter:new({
    rate = 10,              -- Particles per second
    burst = 0,              -- Initial burst count
    spriteX = 4,
    spriteY = 1,
    lifetime = 1.0,         -- Particle lifetime
    lifetimeVariance = 0.2, -- Randomness
    speed = 50,
    speedVariance = 10,
    angle = 0,              -- Emission angle
    angleVariance = math.pi * 2, -- Full circle
    drag = 0,               -- Air resistance
    gravity = 0,            -- Gravity effect
    fadeOut = true          -- Fade particles out
})

entity:addComponent(emitter)

-- Update emitter each frame
local cx, cy = entity:getCenter()
emitter:update(dt, cx, cy)

-- Render particles
emitter:render(camera)

-- Emit burst
emitter:emit(x, y, 20)

-- Clear all particles
emitter:clear()
```

### Particle Example

```lua
-- Explosion on enemy death
enemy:OnDestroy(function(self)
    local cx, cy = self:getCenter()
    ion2d.particles.explosion(cx, cy, 20, 120)
end)

-- Engine trail
local thrustFrameCount = 0
function updatePlayer(dt)
    if thrusting then
        thrustFrameCount = thrustFrameCount + 1
        if thrustFrameCount >= 5 then
            thrustFrameCount = 0
            local bx, by = player:backward()
            local cx, cy = player:getCenter()
            ion2d.particles.trail(
                cx + bx * 8, 
                cy + by * 8, 
                player.vx, 
                player.vy
            )
        end
    end
end
```

---

## Tilemaps

Tilemaps allow you to create tile-based backgrounds and levels.

### Creating a Tilemap

```lua
local tilemap = ion2d.newTilemap(tileWidth, tileHeight)

-- Example: 16x16 pixel tiles
local background = ion2d.newTilemap(16, 16)
```

### Setting Tiles

```lua
-- Set tile at position
tilemap:setTile(x, y, spriteX, spriteY)

-- Example: Create grass field
for y = 1, 100 do
    for x = 1, 100 do
        background:setTile(x, y, 4, 2) -- Grass sprite
    end
end
```

### Getting and Removing Tiles

```lua
-- Get tile at position
local spriteX, spriteY = tilemap:getTile(x, y)

-- Remove tile
tilemap:removeTile(x, y)
```

### Coordinate Conversion

```lua
-- Convert world coordinates to tile coordinates
local tileX, tileY = tilemap:worldToTile(worldX, worldY)

-- Convert tile coordinates to world coordinates
local worldX, worldY = tilemap:tileToWorld(tileX, tileY)
```

### Rendering Tilemaps

```lua
-- Set active tilemap
ion2d.setTilemap(background)

-- Tilemap renders automatically with ion2d.render()
-- Or render manually
tilemap:render(camera, layer)
```

### Tilemap Example

```lua
-- Create background
local background = ion2d.newTilemap(16, 16)

-- Fill with grass
for y = 1, 200 do
    for x = 1, 200 do
        background:setTile(x, y, 4, 2)
    end
end

-- Add some walls
for x = 1, 200 do
    background:setTile(x, 1, 5, 1)    -- Top wall
    background:setTile(x, 200, 5, 1)  -- Bottom wall
end

for y = 1, 200 do
    background:setTile(1, y, 5, 1)    -- Left wall
    background:setTile(200, y, 5, 1)  -- Right wall
end

-- Set as active tilemap
ion2d.setTilemap(background)

-- Camera bounds match tilemap
camera:setBounds(0, 0, 200 * 16, 200 * 16)
```

---

## State Machine

The state machine manages game states like menu, playing, and game over.

### Creating a State Machine

```lua
ion2d.stateMachine = ion2d.StateMachine:new({
    stateName1 = {
        enter = function() end,
        update = function(dt) end,
        exit = function() end
    },
    stateName2 = {
        -- ...
    }
})
```

### State Functions

- `enter`: Called when entering the state
- `update`: Called every frame while in this state
- `exit`: Called when leaving the state

### Changing States

```lua
-- Set current state
ion2d.setState("playing")

-- Get current state
local currentState = ion2d.getState()
```

### State Machine Example

```lua
ion2d.stateMachine = ion2d.StateMachine:new({
    menu = {
        enter = function()
            -- Clean up entities
            for _, entity in ipairs(ion2d.world.getAllEntities()) do
                entity:destroy(0)
            end
        end,
        
        update = function(dt)
            term.clear()
            term.setCursorPos(1, 3)
            term.write("MY GAME")
            term.setCursorPos(1, 5)
            term.write("Press ENTER to start")
            
            if ion2d.input.down("start") then
                ion2d.setState("playing")
            end
        end
    },
    
    playing = {
        enter = function()
            -- Initialize game
            player = spawnPlayer()
            wave = 1
            spawnWave(wave)
        end,
        
        update = function(dt)
            -- Update game logic
            updatePlayer(dt)
            updateEnemies(dt)
            
            -- Check collisions
            ion2d.collision.checkBetween("bullet", "enemy")
            
            -- Render UI
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Wave: " .. wave)
            term.setCursorPos(1, 2)
            term.write("Score: " .. score)
            
            -- Check win condition
            if ion2d.world.getEntityCount("enemy") == 0 then
                wave = wave + 1
                spawnWave(wave)
            end
            
            -- Check lose condition
            if player:isDestroyed() then
                ion2d.setState("gameover")
            end
        end
    },
    
    gameover = {
        enter = function()
            gameoverTime = os.epoch("utc") / 1000
        end,
        
        update = function(dt)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("GAME OVER")
            term.setCursorPos(1, 2)
            term.write("Final Score: " .. score)
            term.setCursorPos(1, 4)
            term.write("Press R to restart")
            
            local timeSince = os.epoch("utc") / 1000 - gameoverTime
            if timeSince > 0.5 and ion2d.input.down("restart") then
                ion2d.setState("playing")
            end
        end
    }
})

-- Start in menu
ion2d.setState("menu")
```

---

## ECS Systems

ion2d includes an Entity Component System for organizing game logic.

### Creating a System

```lua
local system = ion2d.addSystem({
    name = "my_system",
    priority = 100,  -- Higher runs first
    components = {}, -- Required components (empty = all entities)
    update = function(entity, dt)
        -- System logic
    end
})
```

### System Examples

```lua
-- System that only runs on entities with specific components
ion2d.addSystem({
    name = "fire_control",
    priority = 50,
    components = {ion2d.components.FireControl},
    update = function(entity, dt)
        local fc = entity:getComponent(ion2d.components.FireControl)
        -- Update fire control logic
    end
})

-- System that runs on all entities
ion2d.addSystem({
    name = "cleanup",
    priority = 10,
    components = {},
    update = function(entity, dt)
        if entity:isOnScreen() == false then
            entity:destroy(0)
        end
    end
})
```

### Managing Systems

```lua
-- Disable a system
ion2d.setSystemEnabled("my_system", false)

-- Enable a system
ion2d.setSystemEnabled("my_system", true)

-- Get system reference
local system = ion2d.getSystem("my_system")

-- Remove system
ion2d.removeSystem(system)
```

### Built-in Systems

ion2d includes these built-in systems:

1. **movement** (priority 100): Applies velocity to position
2. **drag** (priority 90): Applies drag to velocity
3. **particle_lifetime** (priority 85): Fades particles based on lifetime

### System Example

```lua
-- AI behavior system
ion2d.addSystem({
    name = "enemy_ai",
    priority = 80,
    components = {},
    update = function(entity, dt)
        if not entity:is("enemy") then return end
        if not player or player:isDestroyed() then return end
        
        local behavior = entity:get("behavior")
        
        if behavior == "chase" then
            local px, py = player:getCenter()
            local targetAngle = entity:angleTo(px, py) + math.pi / 2
            entity:rotateTowards(targetAngle, entity:get("turnSpeed") * dt)
            
            if entity:distanceTo(player) > 150 then
                entity:moveRelative(0, -entity:get("moveSpeed") * dt)
            end
        elseif behavior == "patrol" then
            entity:moveRelative(0, -entity:get("moveSpeed") * dt)
            
            if not entity:isOnScreen(screenW, screenH) then
                entity:setAngle(entity:getAngle() + math.pi)
            end
        end
    end
})

-- Health system
ion2d.addSystem({
    name = "health",
    priority = 70,
    components = {},
    update = function(entity, dt)
        if entity.state.health and entity.state.health <= 0 then
            local cx, cy = entity:getCenter()
            ion2d.particles.explosion(cx, cy, 15, 100)
            entity:destroy(0)
        end
    end
})
```

---

## Utility Functions

### Angle Functions

```lua
-- Normalize angle
local normalized = ion2d.normalizeAngle(angle)

-- Get shortest difference between two angles
local diff = ion2d.angleDifference(fromAngle, toAngle)

-- Convert degrees to radians
local radians = ion2d.toRadians(90) -- math.pi/2

-- Convert radians to degrees
local degrees = ion2d.toDegrees(math.pi) -- 180
```

### Scene Management

```lua
-- Initialize a new scene
ion2d.initScene(sceneNumber)

-- Remove a scene
ion2d.removeScene(sceneNumber)

-- Reload current scene (clears all entities)
ion2d.reloadScene()
```

### Controllers

Create directional sprite controllers for entities:

```lua
local controller = ion2d.newController(
    character,
    leftSprite,   -- {spriteX, spriteY}
    rightSprite,
    upSprite,
    downSprite
)

-- Set direction (automatically changes sprite)
controller:setDirection("left")

-- Get current direction
local dir = controller:getDirection()

-- Move with automatic sprite change
controller:move(dx, dy) -- Sets sprite based on direction

-- Update sprites
controller:setSprites(
    {1, 1}, -- left
    {2, 1}, -- right
    {3, 1}, -- up
    {4, 1}  -- down
)
```

---

## Main Loop Patterns

### Basic Loop

```lua
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
```

### Loop with Input Handling

```lua
parallel.waitForAny(
    -- Input handler
    function()
        while true do
            local event, key = os.pullEvent()
            if event == "key" then
                ion2d.input.updateKeyState(key, true)
            elseif event == "key_up" then
                ion2d.input.updateKeyState(key, false)
            end
        end
    end,
    
    -- Game loop
    function()
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
    end
)
```

### Fixed Timestep Loop

For consistent physics simulation:

```lua
-- Set fixed timestep (default is 1/60)
ion2d.fixedDeltaTime = 1 / 60

-- In game loop
local lastTime = os.epoch("utc") / 1000
while true do
    local time = os.epoch("utc") / 1000
    local dt = time - lastTime
    
    if dt >= 0.016 then
        ion2d.updateFixed(dt) -- Uses fixed timesteps internally
        lastTime = time
    end
    
    sleep(0)
end
```

---

## Complete Game Example

Here's a complete working example of a simple space shooter:

```lua
local ion2d = require("/ion2d")

-- Initialize
ion2d.init()
local screenW, screenH = term.getSize()
screenW, screenH = screenW * 8, screenH * 8

-- Load sprites
local spritemap = ion2d.newSpritemap("/demogame/spritemap.png", 16, 16)
ion2d.setSpritemap(spritemap)

-- Setup input
ion2d.input.bind("turn_left", keys.a)
ion2d.input.bind("turn_right", keys.d)
ion2d.input.bind("thrust", keys.w)
ion2d.input.bind("fire", keys.space)
ion2d.input.bind("start", keys.enter)
ion2d.input.bind("restart", keys.r)

-- Game variables
local player, camera
local score = 0
local wave = 1

-- Create camera
camera = ion2d.components.Camera:new({
	smoothing = 0.1,
})

-- Initialize game
local function initGame()
	-- Clear all entities
	for _, entity in ipairs(ion2d.world.getAllEntities()) do
		entity:destroy(0)
	end

	score = 0
	wave = 1

	-- Spawn player
	player = ion2d.world.spawn("player", {
		spriteX = 1,
		spriteY = 1,
		centerAt = { screenW / 2, screenH / 2 },
		team = "player",
		fireControl = {
			delay = 0.2,
			aimError = 0,
		},
		properties = {
			maxSpeed = 120,
			acceleration = 150,
			turnSpeed = 4,
		},
	})

	player.state.health = 100
	player:setDrag(1.5)

	-- Player collision handler
	player:OnCollisionEnter(function(self, other)
		if other:is("bullet") then
			local team = other:getComponent(ion2d.components.Team)
			if team and team.name == "enemy" then
				self.state.health = self.state.health - 20
				other:destroy(0)
				camera:shake(5)

				if self.state.health <= 0 then
					ion2d.setState("gameover")
				end
			end
		end
	end)

	camera:follow(player)

	-- Spawn first wave
	spawnWave(wave)
end

-- Spawn enemy wave
function spawnWave(waveNum)
	local count = 2 + math.floor(waveNum * 0.5)

	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local radius = 150
		local x = screenW / 2 + math.cos(angle) * radius
		local y = screenH / 2 + math.sin(angle) * radius

		local enemy = ion2d.world.spawn("enemy", {
			spriteX = 2,
			spriteY = 1,
			centerAt = { x, y },
			team = "enemy",
			fireControl = {
				delay = 2.0,
				aimError = 0.5,
			},
			properties = {
				moveSpeed = 20,
				turnSpeed = 1.5,
			},
		})

		enemy.state.health = 30

		-- Enemy collision handler
		enemy:OnCollisionEnter(function(self, other)
			if other:is("bullet") then
				local team = other:getComponent(ion2d.components.Team)
				if team and team.name == "player" then
					self.state.health = self.state.health - 25
					other:destroy(0)

					if self.state.health <= 0 then
						score = score + 100
						local cx, cy = self:getCenter()
						ion2d.particles.explosion(cx, cy, 20, 100)
						self:destroy(0)
					end
				end
			end
		end)
	end
end

-- Enemy AI system
ion2d.addSystem({
	name = "enemy_ai",
	priority = 80,
	components = {},
	update = function(entity, dt)
		if not entity:is("enemy") then
			return
		end
		if not player or player:isDestroyed() then
			return
		end

		-- Chase player
		local px, py = player:getCenter()
		local targetAngle = entity:angleTo(px, py) + math.pi / 2
		entity:rotateTowards(targetAngle, (entity:get("turnSpeed") or 0) * dt)

		if entity:distanceTo(player) > 150 then
			local moveSpeed = entity:get("moveSpeed") or 0
			entity:moveRelative(0, -moveSpeed * dt)
		end

		entity:wrapAroundScreen(screenW, screenH)

		-- Shoot at player
		local fc = entity:getComponent(ion2d.components.FireControl)
		local time = os.epoch("utc") / 1000

		if fc and fc:canFire(time) and math.random() < 0.3 then
			local aimAngle = entity:angleTo(px, py)
			local cx, cy = entity:getCenter()

			ion2d.world.spawn("bullet", {
				spriteX = 5,
				spriteY = 1,
				centerAt = { cx, cy },
				angle = aimAngle,
				velocity = {
					math.cos(aimAngle) * 120,
					math.sin(aimAngle) * 120,
				},
				team = "enemy",
				lifetime = 2.0,
			})

			fc:recordFire(time)
		end
	end,
})

-- State machine
ion2d.stateMachine = ion2d.StateMachine:new({
	menu = {
		enter = function()
			for _, entity in ipairs(ion2d.world.getAllEntities()) do
				entity:destroy(0)
			end
		end,

		update = function(dt)
			camera:update(dt, screenW, screenH)

			term.clear()
			term.setCursorPos(1, 3)
			term.write("SPACE SHOOTER")
			term.setCursorPos(1, 5)
			term.write("CONTROLS:")
			term.setCursorPos(1, 6)
			term.write("A/D - Turn")
			term.setCursorPos(1, 7)
			term.write("W - Thrust")
			term.setCursorPos(1, 8)
			term.write("Space - Fire")
			term.setCursorPos(1, 10)
			term.write("Press ENTER to start")

			if ion2d.input.down("start") then
				ion2d.setState("playing")
			end
		end,
	},

	playing = {
		enter = function()
			initGame()
		end,

		update = function(dt)
			local time = os.epoch("utc") / 1000

			-- Player controls
			if player and not player:isDestroyed() then
				if ion2d.input.down("turn_left") then
					player:setAngle(player:getAngle() - player:get("turnSpeed") * dt)
				end
				if ion2d.input.down("turn_right") then
					player:setAngle(player:getAngle() + player:get("turnSpeed") * dt)
				end
				if ion2d.input.down("thrust") then
					player:thrustRelative(0, -player:get("acceleration") * dt)
				end

				player:limitSpeed(player:get("maxSpeed"))
				player:wrapAroundScreen(screenW, screenH)

				-- Shooting
				if ion2d.input.down("fire") then
					local fc = player:getComponent(ion2d.components.FireControl)
					if fc:canFire(time) then
						local angle = player:getAngle() - math.pi / 2
						local cx, cy = player:getCenter()
						local fx, fy = player:forward()

						ion2d.world.spawn("bullet", {
							spriteX = 3,
							spriteY = 1,
							centerAt = { cx + fx * 8, cy + fy * 8 },
							angle = angle,
							velocity = {
								math.cos(angle) * 200 + player.vx,
								math.sin(angle) * 200 + player.vy,
							},
							team = "player",
							lifetime = 1.5,
						})

						fc:recordFire(time)
						camera:shake(1)
					end
				end
			end

			-- Update camera
			camera:update(dt, screenW, screenH)

			-- Check collisions
			ion2d.collision.checkBetween("bullet", "player")
			ion2d.collision.checkBetween("bullet", "enemy")

			-- Check wave complete
			if ion2d.world.getEntityCount("enemy") == 0 then
				wave = wave + 1
				spawnWave(wave)
			end

			-- Render UI
			if player and not player:isDestroyed() then
				term.clear()
				term.setCursorPos(1, 1)
				term.write("HP: " .. player.state.health)
				term.setCursorPos(1, 2)
				term.write("Score: " .. score)
				term.setCursorPos(1, 3)
				term.write("Wave: " .. wave)
			end
		end,
	},

	gameover = {
		enter = function()
			-- Clear bullets
			for _, bullet in ipairs(ion2d.world.getEntitiesOfType("bullet")) do
				bullet:destroy(0)
			end
		end,

		update = function(dt)
			camera:update(dt, screenW, screenH)

			term.clear()
			term.setCursorPos(1, 1)
			term.write("GAME OVER")
			term.setCursorPos(1, 2)
			term.write("Final Score: " .. score)
			term.setCursorPos(1, 3)
			term.write("Wave: " .. wave)
			term.setCursorPos(1, 5)
			term.write("Press R to restart")

			if ion2d.input.down("restart") then
				ion2d.setState("playing")
			end
		end,
	},
})

ion2d.setState("menu")

-- Main loop
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
```

---

## Common Patterns

### Health System

```lua
entity.state.health = 100
entity.state.maxHealth = 100

entity:OnCollisionEnter(function(self, other)
    if other:is("damage_source") then
        self.state.health = self.state.health - other:get("damage")
        
        if self.state.health <= 0 then
            self:destroy(0)
        end
    end
end)
```

### Powerup System

```lua
local powerupTypes = {
    shield = { duration = 10, spriteX = 1, spriteY = 2 },
    speed = { duration = 5, spriteX = 2, spriteY = 2 }
}

player.state.activePowerups = {}

function activatePowerup(player, type)
    local def = powerupTypes[type]
    player.state.activePowerups[type] = os.epoch("utc") / 1000 + def.duration
end

function isPowerupActive(player, type)
    local endTime = player.state.activePowerups[type]
    if not endTime then return false end
    return os.epoch("utc") / 1000 < endTime
end
```

### Wave Spawner

```lua
local wave = 1

function spawnWave(waveNum)
    local count = 5 + waveNum * 2
    local types = {"basic", "fast", "tank"}
    
    for i = 1, count do
        local type = types[math.random(#types)]
        local angle = (i / count) * math.pi * 2
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        
        spawnEnemy(type, x, y)
    end
end

-- Check for wave completion
if ion2d.world.getEntityCount("enemy") == 0 then
    wave = wave + 1
    spawnWave(wave)
end
```

### Screen Shake on Impact

```lua
entity:OnCollisionEnter(function(self, other)
    local impactStrength = self:getSpeed() * 0.1
    camera:shake(math.min(impactStrength, 20))
end)
```

---

## Function Reference

### Core Engine Functions

| Function | Description |
|----------|-------------|
| `ion2d.init()` | Initialize the engine (required first) |
| `ion2d.step(dt)` | Update all game logic for one frame |
| `ion2d.render(camera)` | Render the current scene |
| `ion2d.update(dt)` | Combined step() and render() |
| `ion2d.updateFixed(frameDt)` | Update with fixed timestep physics |
| `ion2d.safeCall(func, ...)` | Call function with error handling |
| `ion2d.panic(msg)` | Trigger engine error with cleanup |

### Spritesheet Functions

| Function | Description |
|----------|-------------|
| `ion2d.newSpritemap(file, cellW, cellH)` | Load PNG spritesheet |
| `ion2d.setSpritemap(spritemap)` | Set active spritesheet |
| `ion2d.getSpritemap()` | Get current spritesheet |

### Entity Creation

| Function | Description |
|----------|-------------|
| `ion2d.newCharacter(spriteX, spriteY, scene, layer)` | Create basic entity |
| `ion2d.world.spawn(type, config)` | Spawn entity with configuration |

### Entity Position & Movement

| Function | Description |
|----------|-------------|
| `entity:setPosition(x, y)` | Set absolute position |
| `entity:getPosition()` | Get position (returns x, y) |
| `entity:move(dx, dy)` | Move relative to current position |
| `entity:centerAt(x, y)` | Center entity at position |
| `entity:getCenter()` | Get center position (returns x, y) |
| `entity:setVelocity(vx, vy)` | Set velocity |
| `entity:getVelocity()` | Get velocity (returns vx, vy) |
| `entity:thrust(vx, vy)` | Add to velocity |
| `entity:stop()` | Set velocity to zero |
| `entity:setDrag(drag)` | Set drag coefficient |
| `entity:accelerate(ax, ay, dt)` | Apply acceleration |
| `entity:limitSpeed(maxSpeed)` | Clamp speed to maximum |
| `entity:getSpeed()` | Get current speed magnitude |
| `entity:setSpeed(speed)` | Set speed while maintaining direction |

### Entity Rotation

| Function | Description |
|----------|-------------|
| `entity:setAngle(angle)` | Set rotation angle (radians) |
| `entity:getAngle()` | Get current angle |
| `entity:forward()` | Get forward direction vector (returns x, y) |
| `entity:backward()` | Get backward direction vector (returns x, y) |
| `entity:right()` | Get right direction vector (returns x, y) |
| `entity:left()` | Get left direction vector (returns x, y) |
| `entity:lookAt(x, y)` or `entity:lookAt(entity)` | Rotate to face target |
| `entity:angleTo(x, y)` or `entity:angleTo(entity)` | Get angle to target |
| `entity:rotateTowards(targetAngle, maxRotation)` | Smoothly rotate toward angle |

### Entity Relative Movement

| Function | Description |
|----------|-------------|
| `entity:moveRelative(forward, strafe)` | Move relative to rotation |
| `entity:setVelocityRelative(forward, strafe)` | Set velocity relative to rotation |
| `entity:thrustRelative(forward, strafe)` | Thrust relative to rotation |

### Entity Advanced Movement

| Function | Description |
|----------|-------------|
| `entity:moveTowards(x, y, speed, dt)` | Move toward target at speed |
| `entity:bounceOffEdges(width, height, damping)` | Bounce off screen edges |
| `entity:wrapAroundScreen(width, height)` | Wrap to opposite edge |
| `entity:clampToScreen(width, height)` | Keep entity on screen |
| `entity:teleport(x, y, callback)` | Instantly move with callback |

### Entity Sprites & Appearance

| Function | Description |
|----------|-------------|
| `entity:setSprite(spriteX, spriteY)` | Change sprite |
| `entity:rotateSprite(offsetX, offsetY)` | Change sprite by offset |
| `entity:getSize()` | Get sprite dimensions (returns w, h) |
| `entity:setFlipX(flipped)` | Flip sprite horizontally |
| `entity:setFlipY(flipped)` | Flip sprite vertically |
| `entity:setOpacity(opacity)` | Set opacity (0.0 to 1.0) |
| `entity:getOpacity()` | Get current opacity |

### Entity Collision

| Function | Description |
|----------|-------------|
| `entity:checkCollision(other)` | Check if colliding with entity |
| `entity:CollidesWith(other)` | Check collision and fire events |
| `entity:getBounds()` | Get bounding box (returns x1, y1, x2, y2) |
| `entity:containsPoint(px, py)` | Check if point is inside |
| `entity:distanceTo(other)` | Get distance to entity |

### Entity Properties & State

| Function | Description |
|----------|-------------|
| `entity:set(key, value)` | Set custom property |
| `entity:get(key)` | Get custom property |
| `entity:is(type)` | Check if entity matches type |
| `entity:setMeta(key, value)` | Set metadata |
| `entity:getMeta(key)` | Get metadata |

### Entity Components

| Function | Description |
|----------|-------------|
| `entity:addComponent(component)` | Add component to entity |
| `entity:getComponent(componentType)` | Get component instance |
| `entity:hasComponent(componentType)` | Check if has component |
| `entity:removeComponent(componentType)` | Remove component |

### Entity Events

| Function | Description |
|----------|-------------|
| `entity:OnUpdate(callback)` | Called every frame with (self, dt) |
| `entity:OnDestroy(callback)` | Called when destroyed with (self) |
| `entity:OnCollisionEnter(callback)` | Called when collision starts with (self, other) |
| `entity:OnCollisionStay(callback)` | Called while colliding with (self, other) |
| `entity:OnCollisionExit(callback)` | Called when collision ends with (self, other) |
| `entity:OnCollision(callback)` | Alias for OnCollisionEnter |

### Entity Lifecycle

| Function | Description |
|----------|-------------|
| `entity:destroy(time)` | Destroy entity (0 = immediate, >0 = delay) |
| `entity:isDestroyed()` | Check if entity is destroyed |
| `entity:clone()` | Create copy of entity |
| `entity:isOnScreen(width, height, margin)` | Check if visible on screen |

### Entity Layers & Scenes

| Function | Description |
|----------|-------------|
| `entity:setLayer(layer)` | Move to different layer |
| `entity:getLayer()` | Get current layer |
| `entity:setScene(scene)` | Move to different scene |
| `entity:getScene()` | Get current scene |

### World Queries

| Function | Description |
|----------|-------------|
| `ion2d.world.getById(id, scene)` | Get entity by ID |
| `ion2d.world.getAllEntities(scene)` | Get all entities in scene |
| `ion2d.world.getEntitiesOfType(type, scene)` | Get entities of specific type |
| `ion2d.world.getEntityCount(type, scene)` | Get count of entity type |
| `ion2d.world.getEntitiesWithComponent(componentType, scene)` | Get entities with component |

### Collision System

| Function | Description |
|----------|-------------|
| `ion2d.collision.checkAll(scene)` | Check all entities against each other |
| `ion2d.collision.checkBetween(type1, type2, scene)` | Check specific types (optimized) |
| `ion2d.collision.useSpatialHash` | Property: enable spatial hashing |
| `ion2d.collision.gridCellSize` | Property: spatial hash cell size |

### Input System

| Function | Description |
|----------|-------------|
| `ion2d.input.bind(action, key)` | Bind action to key |
| `ion2d.input.down(action)` | Check if key is currently down |
| `ion2d.input.pressed(action)` | Check if key was just pressed |
| `ion2d.input.released(action)` | Check if key was just released |
| `ion2d.input.updateKeyState(key, state)` | Update key state (internal) |
| `ion2d.input.update()` | Update input state (internal) |

### Camera Component

| Function | Description |
|----------|-------------|
| `ion2d.components.Camera:new(config)` | Create new camera |
| `camera:follow(entity, offsetX, offsetY)` | Follow entity |
| `camera:stopFollowing()` | Stop following |
| `camera:shake(intensity)` | Shake camera effect |
| `camera:setPosition(x, y)` | Set camera position |
| `camera:setBounds(minX, minY, maxX, maxY)` | Constrain camera to bounds |
| `camera:update(dt, screenW, screenH)` | Update camera (call each frame) |
| `camera:getPosition()` | Get camera position (returns x, y) |
| `camera:getViewBounds()` | Get visible area (returns x1, y1, x2, y2) |
| `camera:worldToScreen(x, y)` | Convert world to screen coords |
| `camera:screenToWorld(x, y)` | Convert screen to world coords |
| `camera:isVisible(entity)` | Check if entity is in view |

### Particle System

| Function | Description |
|----------|-------------|
| `ion2d.particles.spawn(x, y, vx, vy, lifetime, sx, sy)` | Spawn single particle |
| `ion2d.particles.explosion(x, y, count, speed, sx, sy)` | Create explosion effect |
| `ion2d.particles.trail(x, y, vx, vy, sx, sy)` | Create trail effect |

### Particle Emitter Component

| Function | Description |
|----------|-------------|
| `ion2d.components.ParticleEmitter:new(config)` | Create particle emitter |
| `emitter:emit(x, y, count)` | Emit particles |
| `emitter:update(dt, x, y)` | Update emitter and particles |
| `emitter:render(camera)` | Render particles |
| `emitter:clear()` | Clear all particles |

### Tilemap

| Function | Description |
|----------|-------------|
| `ion2d.newTilemap(tileWidth, tileHeight)` | Create new tilemap |
| `ion2d.setTilemap(tilemap)` | Set active tilemap |
| `tilemap:setTile(x, y, spriteX, spriteY)` | Set tile at position |
| `tilemap:getTile(x, y)` | Get tile sprites (returns sx, sy) |
| `tilemap:removeTile(x, y)` | Remove tile |
| `tilemap:render(camera, layer)` | Render tilemap |
| `tilemap:worldToTile(x, y)` | Convert world to tile coords |
| `tilemap:tileToWorld(tileX, tileY)` | Convert tile to world coords |

### State Machine

| Function | Description |
|----------|-------------|
| `ion2d.StateMachine:new(states)` | Create state machine |
| `stateMachine:setState(stateName)` | Change to state |
| `stateMachine:update(dt)` | Update current state |
| `stateMachine:getCurrentState()` | Get current state name |
| `ion2d.setState(stateName)` | Change state (uses ion2d.stateMachine) |
| `ion2d.getState()` | Get current state (uses ion2d.stateMachine) |

### Component Types

| Function | Description |
|----------|-------------|
| `ion2d.components.Team:new(teamName)` | Create team component |
| `ion2d.components.Lifetime:new(duration)` | Create lifetime component |
| `ion2d.components.FireControl:new(config)` | Create fire control component |
| `ion2d.components.Camera:new(config)` | Create camera component |
| `ion2d.components.ParticleEmitter:new(config)` | Create particle emitter |

### Lifetime Component

| Function | Description |
|----------|-------------|
| `lifetime:isExpired()` | Check if lifetime has expired |

### FireControl Component

| Function | Description |
|----------|-------------|
| `fireControl:canFire(currentTime)` | Check if can fire |
| `fireControl:recordFire(currentTime)` | Record fire time |

### ECS System Functions

| Function | Description |
|----------|-------------|
| `ion2d.addSystem(systemDef)` | Register new system |
| `ion2d.removeSystem(system)` | Remove system |
| `ion2d.setSystemEnabled(name, enabled)` | Enable/disable system |
| `ion2d.getSystem(name)` | Get system by name |

### Scene Management

| Function | Description |
|----------|-------------|
| `ion2d.initScene(number)` | Initialize scene |
| `ion2d.removeScene(number)` | Remove scene |
| `ion2d.reloadScene()` | Reload current scene |
| `ion2d.initLayer(scene, number)` | Initialize layer in scene |
| `ion2d.gcScene(scene)` | Garbage collect destroyed entities |

### Utility Functions

| Function | Description |
|----------|-------------|
| `ion2d.normalizeAngle(angle)` | Normalize to -π to π |
| `ion2d.angleDifference(from, to)` | Get shortest angle difference |
| `ion2d.toRadians(degrees)` | Convert degrees to radians |
| `ion2d.toDegrees(radians)` | Convert radians to degrees |

### Controller Functions

| Function | Description |
|----------|-------------|
| `ion2d.newController(character, left, right, up, down)` | Create directional controller |
| `controller:setDirection(direction)` | Set direction and sprite |
| `controller:getDirection()` | Get current direction |
| `controller:move(dx, dy)` | Move with auto sprite change |
| `controller:setSprites(left, right, up, down)` | Update sprite mappings |

### Rendering Functions

| Function | Description |
|----------|-------------|
| `ion2d.renderScene(scene, camera)` | Render specific scene |

### Engine Properties

| Property | Description |
|----------|-------------|
| `ion2d.currentScene` | Current scene number |
| `ion2d.scenes` | Table of all scenes |
| `ion2d.spritemap` | Current spritemap |
| `ion2d.currentTilemap` | Current active tilemap |
| `ion2d.stateMachine` | Global state machine |
| `ion2d.fixedDeltaTime` | Fixed timestep (default 1/60) |

---

For more examples, refer to the demogame/demo.lua file included with the engine.

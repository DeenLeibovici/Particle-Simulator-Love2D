-- AI!!!!!!!!!!!!!!!!!!!!
-- Global Constants (Recommended)
-- Define dimensions and cell size
local CELL_SIZE = 10
local WIDTH = 800
local HEIGHT = 600

-- Define particle type constants
local PARTICLE = {
    EMPTY = 0,
    SOLID = 1,
    SAND = 2,
    WATER = 3
}

-- Global Variables
local mt = {}          -- The particle matrix (using 1-based indexing)
local N = WIDTH / CELL_SIZE -- Number of columns (x)
local M = HEIGHT / CELL_SIZE -- Number of rows (y)
local mouse = true
local frameTime = 0
local entity_count = 0
local current_particle = PARTICLE.SAND -- Start with sand (2)
local brushSize = 1
local solid_icon, sand_icon, water_icon, eraser_icon -- Image variables
local font
local current_sweep_direction = 1 -- 1 for left-to-right, -1 for right-to-left

function love.load()
    love.window.setMode(WIDTH, HEIGHT)
    love.window.setTitle("Particle Simulator")
    font = love.graphics.newFont("assets/LoveFont.ttf", 16)

    -- Initialize the matrix (using 1-based indexing: 1 to N, 1 to M)
    for i = 1, N do
      mt[i] = {}     -- create a new column
      for j = 1, M do
        mt[i][j] = PARTICLE.EMPTY
      end
    end

    love.graphics.setDefaultFilter("nearest", "nearest")
    solid_icon = love.graphics.newImage("assets/solid.png")
    sand_icon = love.graphics.newImage("assets/sand.png")
    water_icon = love.graphics.newImage("assets/water.png")
    eraser_icon = love.graphics.newImage("assets/eraser.png")
end

---Helper Functions

-- Helper function to check if a cell (i, j) is within bounds
local function is_valid(i, j)
    return i >= 1 and i <= N and j >= 1 and j <= M
end

-- Function to check if the cell below is empty
local function check_below(i, j)
    -- Check bounds first, then particle type
    return is_valid(i, j + 1) and mt[i][j + 1] == PARTICLE.EMPTY
end

-- Function to get the particle ID at a safe location
-- Returns 0 if out of bounds
local function get_particle_id(i, j)
    if not is_valid(i, j) then
        return PARTICLE.EMPTY
    end
    return mt[i][j]
end

---Particle Update Logic

-- **BUG FIX:** Randomizing the diagonal check fixes the right-side bias.
function update_sand(i, j)
    -- 1. Check straight down
    if check_below(i, j) then
        mt[i][j] = PARTICLE.EMPTY
        mt[i][j + 1] = PARTICLE.SAND
        return
    end

    -- 2. Check diagonals
    local dir = {1, -1} -- Possible directions: right, left
    if math.random() < 0.5 then -- Randomly swap to prevent directional bias
        dir = {-1, 1}
    end

    for _, dx in ipairs(dir) do
        local new_i = i + dx
        -- Sand falls over non-solid blocks (empty or water)
        if is_valid(new_i, j + 1) and mt[new_i][j + 1] ~= PARTICLE.SOLID then
            if mt[new_i][j + 1] == PARTICLE.EMPTY then
                mt[i][j] = PARTICLE.EMPTY
                mt[new_i][j + 1] = PARTICLE.SAND
                return
            -- Additional: Swap with water if water is below (for sinking)
            elseif mt[new_i][j + 1] == PARTICLE.WATER then
                mt[i][j] = PARTICLE.WATER
                mt[new_i][j + 1] = PARTICLE.SAND
                return
            end
        end
    end
end

-- **BUG FIX:** Water spreads horizontally *before* checking diagonal fall.
function update_water(i, j)
    -- 1. Check straight down
    if check_below(i, j) then
        mt[i][j] = PARTICLE.EMPTY
        mt[i][j + 1] = PARTICLE.WATER
        return
    end

    -- 2. Check diagonals (same logic as sand for falling into empty space)
    local dir_diag = {1, -1}
    if math.random() < 0.5 then dir_diag = {-1, 1} end

    for _, dx in ipairs(dir_diag) do
        local new_i = i + dx
        if is_valid(new_i, j + 1) and mt[new_i][j + 1] == PARTICLE.EMPTY then
            mt[i][j] = PARTICLE.EMPTY
            mt[new_i][j + 1] = PARTICLE.WATER
            return
        end
    end

    -- 3. Check horizontal spread (Water flows sideways)
    local dir_side = {1, -1}
    if math.random() < 0.5 then dir_side = {-1, 1} end

    for _, dx in ipairs(dir_side) do
        local new_i = i + dx
        if is_valid(new_i, j) and mt[new_i][j] == PARTICLE.EMPTY then
            mt[i][j] = PARTICLE.EMPTY
            mt[new_i][j] = PARTICLE.WATER
            return
        end
    end
end

---Input and Main Loop

function brush_size(i, current_particle, x, y)
    for a = -i, i do
        for b = -i, i do
            local draw_x = x + a
            local draw_y = y + b
            -- Check if coordinates are valid AND if the point is within a circle
            if is_valid(draw_x, draw_y) and (a*a + b*b <= i*i) then
                mt[draw_x][draw_y] = current_particle
            end
        end
    end
end

function love.wheelmoved(x, y)
    if y > 0 then
        brushSize = math.min(10, brushSize + 1)
    elseif y < 0 then
        brushSize = math.max(1, brushSize - 1) -- Brush size should be at least 1
    end
end

local time = 0
function love.update(dt)
    time = time + dt
    local i_start, i_end, i_step

    -- **FIX:** Limit FPS to 30 for smoother simulation consistency
    frameTime = frameTime + dt
    if frameTime < (1/30) then
        return
    end
    frameTime = 0

    -- Handle Mouse Input (Moved outside of the main loop for clarity)
    if love.mouse.isDown(1) and mouse then
        local x, y = love.mouse.getPosition()
        local icon_w = 50 -- Width/Height of hardcoded icons
        local ui_y = 10
        local ui_start_x = WIDTH - 200

        if x > ui_start_x and x < ui_start_x + icon_w and y > ui_y and y < ui_y + icon_w then
            current_particle = PARTICLE.SOLID
        elseif x > ui_start_x + icon_w and x < ui_start_x + 2 * icon_w and y > ui_y and y < ui_y + icon_w then
            current_particle = PARTICLE.SAND
        elseif x > ui_start_x + 2 * icon_w and x < ui_start_x + 3 * icon_w and y > ui_y and y < ui_y + icon_w then
            current_particle = PARTICLE.WATER
        elseif x > ui_start_x + 3 * icon_w and x < ui_start_x + 4 * icon_w and y > ui_y and y < ui_y + icon_w then
            current_particle = PARTICLE.EMPTY -- Eraser
        else
            -- Calculate 1-based indices
            local x_converted = math.floor(x/CELL_SIZE) + 1
            local y_converted = math.floor(y/CELL_SIZE) + 1
            brush_size(brushSize, current_particle, x_converted, y_converted)
            mouse = false
        end
    else 
        mouse = true
    end

    -- **FIX:** Alternate the horizontal sweep direction to eliminate simulation bias.
    if current_sweep_direction == 1 then
        i_start, i_end, i_step = 1, N, 1
    else
        i_start, i_end, i_step = N, 1, -1
    end
    current_sweep_direction = -current_sweep_direction -- Flip for the next frame

    entity_count = 0
    -- Iterate bottom-up (j=M to 1) for gravity simulation
    for j = M, 1, -1 do
        -- Iterate left-right or right-left (i=i_start to i_end)
        for i = i_start, i_end, i_step do
            local particle_type = mt[i][j]
            if particle_type ~= PARTICLE.EMPTY then
                entity_count = entity_count + 1
            end

            if particle_type == PARTICLE.SOLID then
                -- **FIX:** Immovable solids do nothing.
                -- Removed the falling solid logic (if you want falling blocks, change the constant)
            elseif particle_type == PARTICLE.SAND then
                update_sand(i, j)
            elseif particle_type == PARTICLE.WATER then
                update_water(i, j)
            end
        end
    end
end

function love.draw()
    love.graphics.clear(0, 0, 0, 1) -- Black background

    -- Draw the grid
    for i = 1, N do
        for j = 1, M do
            local particle_type = mt[i][j]
            local x = (i - 1) * CELL_SIZE
            local y = (j - 1) * CELL_SIZE

            if particle_type == PARTICLE.SOLID then
                love.graphics.setColor(0.4, 0.6, 0.2, 1) -- Green
            elseif particle_type == PARTICLE.SAND then
                love.graphics.setColor(0.8, 0.7, 0.5, 1) -- Brown
            elseif particle_type == PARTICLE.WATER then
                love.graphics.setColor(0.2, 0.4, 0.8, 1) -- Blue
            else    
                love.graphics.setColor(0, 0, 0, 0) -- Transparent/Black
            end
            love.graphics.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE)
        end
    end

    -- Draw UI Text and Stats
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print("Particle Count: " .. tostring(entity_count), 20, 10)
    love.graphics.print("Brush Size: " .. tostring(brushSize), 20, 30)
    love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 20, 50)

    -- Draw UI Icons and Selection
    local icon_w = 50
    local ui_start_x = WIDTH - 200

    -- Icon Drawings (using 1-based index to calculate position)
    love.graphics.draw(solid_icon, ui_start_x + 0 * icon_w, 10, 0, 5, 5)
    love.graphics.draw(sand_icon, ui_start_x + 1 * icon_w, 10, 0, 5 ,5)
    love.graphics.draw(water_icon, ui_start_x + 2 * icon_w, 10, 0, 5, 5)
    love.graphics.draw(eraser_icon, ui_start_x + 3 * icon_w, 10, 0, 5 ,5)

    -- Draw Selection Box
    love.graphics.setColor(1, 0, 0, 1) -- Red
    local selection_x = ui_start_x
    if current_particle == PARTICLE.SOLID then
        selection_x = ui_start_x + 0 * icon_w
    elseif current_particle == PARTICLE.SAND then
        selection_x = ui_start_x + 1 * icon_w
    elseif current_particle == PARTICLE.WATER then
        selection_x = ui_start_x + 2 * icon_w
    else -- Eraser
        selection_x = ui_start_x + 3 * icon_w
    end
    love.graphics.rectangle("line", selection_x, 10, 50, 50)
end
-- Copyright (C) 2017 Robert B. Colton
-- The Pennsylvania State University

MAX_HEIGHT = 300
MIN_HEIGHT = 10
MAX_PITCH = -200
MIN_PITCH = 20

depth = 400

camera = { -- init player camera
	x = 512,
	y = 800,
	height = 100,
	angle = 0,
	v = -100
}

function rayCast(line, x1, y1, x2, y2, d)
	-- x1, y1, x2, y2 are the start and end points on map for ray
	local dx = x2 - x1
	local dy = y2 - y1

	local height = imageData:getWidth()

	-- distance between start and end point
	local r = math.floor(math.sqrt(dx * dx + dy * dy))

	-- calculate stepsize in x and y direction
	dx = dx / r
	dy = dy / r

	-- used for occlusion
	local ymin = 300

	-- we draw from the front to the back
	for i = 1,r do
		x1 = x1 + dx
		y1 = y1 + dy
		-- mirror/wrap our coordinates in case we're oob
		if x1 < 0 then x1 = -x1 end
		if x1 >= mapData:getWidth() then x1 = x1 - mapData:getWidth() end
		if y1 < 0 then y1 = y1 + (1 + math.floor(-y1 / mapData:getHeight())) * mapData:getHeight() end
		if y1 >= mapData:getHeight() then y1 = y1 - mapData:getHeight() end

		-- get height and color
		local data = map[math.floor(x1)][math.floor(y1)]
		local r = bit.rshift(bit.band(data, 0xFF000000), 24)
		local g = bit.rshift(bit.band(data, 0x00FF0000), 16)
		local b = bit.rshift(bit.band(data, 0x0000FF00), 8)
		local h = bit.band(data, 0x000000FF)
		h = camera.height - h

		-- perspective calculation where d is the correction parameter
		local y3 = math.abs(d) * i
		local z3 = math.floor(h / y3 * 100 - camera.v)

		-- draw vertical line
		if z3 < 0 then z3 = 0 end

		if z3 < height - 1 and ymin < height - 1 then
			for k = z3,ymin do
				imageData:setPixel(k, line, r, g, b, 255)
			end
		end

		if ymin > z3 then
			ymin = z3
		end
	end
end

function loadMap(index)
	-- combine height and color data
	mapData = love.image.newImageData("maps/C" .. tostring(index) .. "W.png")
	local heightData = love.image.newImageData("maps/C" .. tostring(index) .. "D.png")
	map = {}
	for x = 0,mapData:getWidth() - 1 do
		map[x] = {}
		for y = 0,mapData:getHeight() - 1 do
			local r,g,b = mapData:getPixel(x, y)
			-- since the heightmap is black/white the r,g,b values of every pixel will be equal
			-- and between 0 and 255 so we can just use the first red value to interpret the height
			local h = heightData:getPixel(x, y)
			map[x][y] = bit.bor(bit.lshift(r, 24), bit.bor(bit.lshift(g, 16), bit.bor(bit.lshift(b, 8), h)))
		end
	end
end

function love.load()
	love.window.setTitle("Voxel Terrain")
	love.mouse.setVisible(false)

	hud = love.graphics.newImage("hud.png")
	sky = love.image.newImageData("sky.png")
	imageData = love.image.newImageData(depth / 2, love.graphics.getWidth() / 2)

	loadMap(1)
end

function love.keyreleased(key)
	if key == "escape" then
		love.event.quit()
	end
end

function love.update(dt)
	if love.keyboard.isDown("a") then
		camera.angle = camera.angle + 0.05
	end
	if love.keyboard.isDown("d") then
		camera.angle = camera.angle - 0.05
	end
	if love.keyboard.isDown("w") then
		camera.x = camera.x - 3 * math.sin(camera.angle)
		camera.y = camera.y - 3 * math.cos(camera.angle)
	end
	if love.keyboard.isDown("s") then
		camera.x = camera.x + 3 * math.sin(camera.angle)
		camera.y = camera.y + 3 * math.cos(camera.angle)
	end
	if love.keyboard.isDown("q") and camera.height < MAX_HEIGHT then
		camera.height = camera.height + 2
	end
	if love.keyboard.isDown("e") and camera.height > MIN_HEIGHT then
		camera.height = camera.height - 2
	end
	if love.keyboard.isDown("up") and camera.v < MIN_PITCH then
		camera.v = camera.v + 2
	end
	if love.keyboard.isDown("down") and camera.v > MAX_PITCH then
		camera.v = camera.v - 2
	end
	if love.keyboard.isDown("return") then
		loadMap(love.math.random(1,4))
	end
end

function love.draw()
	love.graphics.clear(133, 183, 214, 0)

	-- copy the sky into the terrain image buffer
	imageData:paste(sky, 0, 0, 0, 0, sky:getWidth(), sky:getHeight())
	imageData:paste(sky, 0, sky:getHeight(), 0, 0, sky:getWidth(), sky:getHeight())

	-- draw terrain
	local sinAngle = math.sin(camera.angle)
	local cosAngle = math.cos(camera.angle)

	local y3d = -depth * 1.5
	for i = 0,imageData:getHeight() - 1 do
		local x3d = (i - imageData:getHeight() / 2) * 1.5 * 1.5

		local rotX =  cosAngle * x3d + sinAngle * y3d
		local rotY = -sinAngle * x3d + cosAngle * y3d

		rayCast(i, camera.x, camera.y, camera.x + rotX, camera.y + rotY, y3d / math.sqrt(x3d * x3d + y3d * y3d))
	end
	
	if not bufferImage then bufferImage = love.graphics.newImage(imageData)
	else bufferImage:refresh() end

	love.graphics.draw(bufferImage, 0, 0, math.pi / 2,
		(512 / bufferImage:getWidth()),
		-(love.graphics.getWidth() / bufferImage:getHeight()))

	-- draw hud and altimeter
	love.graphics.draw(hud, 0, 0)

	love.graphics.setColor(255, 0, 0)
	love.graphics.print("FPS: "..tostring(love.timer.getFPS()).."\n"..
											"X: "..tostring(camera.x).."\n"..
											"Y: "..tostring(camera.y), 10, 10)
	love.graphics.setColor(255, 255, 255)
end

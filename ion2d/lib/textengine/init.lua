local xterm256 = dofile("/ion2d/lib/textengine/palette.lua")
local width, height = term.getSize(2)

for i = 0, 255 do
	local hex = xterm256[i + 1]
	local r = tonumber(hex:sub(2, 3), 16) / 255
	local g = tonumber(hex:sub(4, 5), 16) / 255
	local b = tonumber(hex:sub(6, 7), 16) / 255
	term.setPaletteColor(i, r, g, b)
end

local fgColor, bgColor = 16, 15

local bit = bit32
local function parseBDF(path)
	local font = {
		name = nil,
		boundingBox = nil,
		glyphs = {},
	}

	local file = fs.open(path, "r")
	assert(file, "Failed to open file: " .. path)

	local content = file.readAll()
	file.close()

	local lines = {}
	for line in content:gmatch("([^\r\n]+)") do
		lines[#lines + 1] = line
	end

	local i = 1
	local function nextLine()
		local l = lines[i]
		i = i + 1
		return l
	end

	while i <= #lines do
		local line = nextLine()
		if not line then
			break
		end

		if line:match("^FONT%s+") then
			font.name = line:sub(6)
		elseif line:match("^FONTBOUNDINGBOX") then
			local w, h, xo, yo = line:match("FONTBOUNDINGBOX%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
			font.boundingBox = {
				tonumber(w),
				tonumber(h),
				tonumber(xo),
				tonumber(yo),
			}
		elseif line == "STARTCHAR" or line:match("^STARTCHAR") then
			local glyph = {
				name = line:sub(10),
				encoding = nil,
				dwidth = nil,
				bbx = nil,
				bitmap = {},
			}

			while true do
				line = nextLine()
				if not line then
					break
				end

				if line:match("^ENCODING") then
					glyph.encoding = tonumber(line:match("ENCODING%s+(%-?%d+)"))
				elseif line:match("^DWIDTH") then
					local x, y = line:match("DWIDTH%s+(%-?%d+)%s+(%-?%d+)")
					glyph.dwidth = { tonumber(x), tonumber(y) }
				elseif line:match("^BBX") then
					local w, h, xo, yo = line:match("BBX%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
					glyph.bbx = {
						tonumber(w),
						tonumber(h),
						tonumber(xo),
						tonumber(yo),
					}
				elseif line == "BITMAP" then
					local width = glyph.bbx[1]
					local height = glyph.bbx[2]
					local bytesPerRow = math.ceil(width / 8)

					for row = 1, height do
						local hex = nextLine()
						if not hex then
							break
						end
						local value = tonumber(hex, 16)
						local bits = {}

						for bitIndex = 0, width - 1 do
							local shift = (bytesPerRow * 8 - 1) - bitIndex
							bits[#bits + 1] = bit.band(bit.rshift(value, shift), 1) == 1
						end

						glyph.bitmap[#glyph.bitmap + 1] = bits
					end
				elseif line == "ENDCHAR" then
					if glyph.encoding and glyph.encoding >= 0 then
						font.glyphs[glyph.encoding] = glyph
					end
					break
				end
			end
		end
	end

	return font
end

local font = parseBDF("/ion2d/lib/textengine/font.bdf")
local cellW = font.boundingBox[1] or error("Could not determine font width")
local cellH = font.boundingBox[2] or error("Could not determine font height")

local termx, termy = 0, 0
local baseline = font.boundingBox[2] + font.boundingBox[4] - 1

local glyphCache = {}

local function buildGlyph(glyph)
	local w, h = glyph.bbx[1], glyph.bbx[2]
	local mask = {}

	for y = 1, h do
		local row = {}
		local src = glyph.bitmap[y]

		for x = 1, w do
			row[x] = src[x] and true or false
		end

		mask[y] = row
	end

	return {
		mask = mask,
		inkW = w,
		inkH = h,
		xoff = glyph.bbx[3],
		yoff = glyph.bbx[4],
		dwidth = glyph.dwidth[1],
	}
end

for code, glyph in pairs(font.glyphs) do
	glyphCache[code] = buildGlyph(glyph)
end

local textengine = {}

function textengine.scroll(y)
	local pixels = term.getPixels(0, y, width, height - y, true)

	term.drawPixels(0, 0, pixels, width, height - y)
	term.drawPixels(0, height - y, 0, width, y)

	termy = termy - y
end

---Sets the foreground color.
---@param fg number # New foreground color value
---@return number # Previous foreground color
function textengine.setTextColor(fg)
	if fg > 256 or fg < 0 then
		-- Instead of erroring, clamp or convert the color
		fg = 16  -- Default to white or some safe color
	end
	local oldFg = fgColor
	fgColor = fg
	return oldFg
end

textengine.setTextColour = textengine.setTextColor

---Sets the background color.
---@param bg number # New background color value
---@return number # Previous background color
function textengine.setBackgroundColor(bg)
	if bg > 256 or bg < 0 then
		-- Instead of erroring, clamp or convert the color
		bg = 15  -- Default to black or some safe color
	end
	local oldBg = bgColor
	bgColor = bg
	return oldBg
end

textengine.setBackgroundColour = textengine.setBackgroundColor

---Gets the current foreground color.
---@return number # Current foreground color
function textengine.getTextColor()
	return fgColor
end

textengine.getTextColour = textengine.getTextColor

---Gets the current background color.
---@return number # Current background color
function textengine.getBackgroundColor()
	return bgColor
end

textengine.getBackgroundColour = textengine.getBackgroundColor

---Sets both foreground and background colors.
---@param fg number # New foreground color
---@param bg number # New background color
---@return number? oldFg # Previous foreground color
---@return number? oldBg # Previous background color
function textengine.setColors(fg, bg)
	if (not fg) or not bg then
		return
	end
	if fg >= 256 or fg < 0 then
		error("Invalid foreground color")
	end
	if bg >= 256 or bg < 0 then
		error("Invalid background color")
	end
	local oldFg, oldBg = fgColor, bgColor
	fgColor, bgColor = fg, bg
	return oldFg, oldBg
end

function textengine.clear(color)
	term.drawPixels(0, 0, color or bgColor, width, height)
end

---Gets both foreground and background colors.
---@return number fg # Current foreground color
---@return number bg # Current background color
function textengine.getColors()
	return fgColor, bgColor
end

local function hexToRGB(value)
	local r, g, b

	if type(value) == "number" then
		r = math.floor(value / 0x10000) % 0x100
		g = math.floor(value / 0x100) % 0x100
		b = value % 0x100
	else
		local hex = value:gsub("#", "")
		r = tonumber(hex:sub(1, 2), 16)
		g = tonumber(hex:sub(3, 4), 16)
		b = tonumber(hex:sub(5, 6), 16)
	end

	return r, g, b
end

function textengine.toXterm256(...)
	local args = { ... }
	local r, g, b
	if #args ~= 3 then
		r, g, b = hexToRGB(args[1])
	else
		r, g, b = args[1], args[2], args[3]
	end

	local bestIndex = 0
	local bestDistance = math.huge

	for i = 1, #xterm256 do
		local xr, xg, xb = hexToRGB(xterm256[i])

		local dr = r - xr
		local dg = g - xg
		local db = b - xb

		local distance = dr * dr + dg * dg + db * db

		if distance < bestDistance then
			bestDistance = distance
			bestIndex = i -- - 1
		end
	end

	return bestIndex
end

function textengine.XtermtoHex(index)
	return xterm256[index]
end

function textengine.hexToRGB(value)
	return hexToRGB(value)
end

local function drawCharCell(fg, bg, g)
	local rows = {}

	for y = 1, cellH do
		local row = {}
		for x = 1, cellW do
			row[x] = bg
		end
		rows[y] = row
	end

	local inkX = g.xoff
	local inkY = baseline - g.yoff - g.inkH + 1

	for y = 1, g.inkH do
		local maskRow = g.mask[y]
		local dstRow = rows[inkY + y]

		if dstRow then
			for x = 1, g.inkW do
				if maskRow[x] then
					dstRow[inkX + x] = fg
				end
			end
		end
	end

	return rows
end

function textengine.writeCode(code)
	local g = glyphCache[code]
	if not g then
		return
	end

	if termx + g.dwidth > width then
		termx = 0
		termy = termy + cellH
	end

	if termy + cellH > height then
		local overflow = termy + cellH - height
		if overflow > 0 then
			local rows = math.ceil(overflow / cellH)
			textengine.scroll(rows * cellH)
		end
	end

	local pixels = drawCharCell(fgColor, bgColor, g)
	term.drawPixels(termx, termy, pixels, cellW, cellH)
	termx = termx + g.dwidth
end

local function writeChar(fg, bg, char)
	local g = glyphCache[string.byte(char)]
	if not g then
		return
	end

	if termx + g.dwidth > width then
		termx = 0
		termy = termy + cellH
	end

	if termy + cellH > height then
		local overflow = termy + cellH - height
		if overflow > 0 then
			local rows = math.ceil(overflow / cellH)
			textengine.scroll(rows * cellH)
		end
	end

	local pixels = drawCharCell(fg, bg, g)
	term.drawPixels(termx, termy, pixels, cellW, cellH)

	termx = termx + g.dwidth
end

local TAB_WIDTH = 4

local function writeText(fg, bg, text)
	for i = 1, #text do
		local c = text:sub(i, i)
		if c == "\n" then
			termx = 0
			termy = termy + cellH

			if termy + cellH > height then
				local overflow = termy + cellH - height
				if overflow > 0 then
					local rows = math.ceil(overflow / cellH)
					textengine.scroll(rows * cellH)
				end
			end
		elseif c == "\t" then
			local spacesToAdd = TAB_WIDTH - (termx / cellW) % TAB_WIDTH
			for j = 1, spacesToAdd do
				writeChar(fg, bg, " ")
			end
		else
			writeChar(fg, bg, c)
		end
	end

	term.setFrozen(false)
end

---Writes one or more values to the terminal.
---@param ... any # Values to write
function textengine.write(...)
	for i = 1, select("#", ...) do
		writeText(fgColor, bgColor, tostring(select(i, ...)))
	end
end

---Sets the terminal's cursor position.
---@param x number # Cursor x position
---@param y number # Cursor y position
function textengine.setCursorPos(x, y)
	if type(x) ~= "number" then
		error("Cursor x position must be a number")
	end
	if type(y) ~= "number" then
		error("Cursor y position must be a number")
	end
	local oldCursorX, oldCursorY = termx, termy
	termx, termy = (x-1) * cellW, (y-1) * cellH
	return oldCursorX, oldCursorY
end

---Returns the terminal's cursor position.
---@return number termx # Cursor x position
---@return number termy # Cursor y position
function textengine.getCursorPos()
	return (termx/cellW)-1, (termy/cellH)-1
end

---Returns the size in pixels of a character.
---@return number cellW # Character cell width
---@return number cellH # Character cell height
function textengine.getTextSize()
	return cellW, cellH
end

function textengine.getSize()
    return math.floor(width/cellW), math.floor(height/cellH)
end

function textengine.isColor()
    return true
end

function textengine.getPixelSize()
    return width, height
end

textengine.isColour = textengine.isColor

textengine.blit = function() end

return textengine

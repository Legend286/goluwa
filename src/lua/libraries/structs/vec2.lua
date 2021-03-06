local structs = (...) or _G.structs

local META = prototype.CreateTemplate("Vec2")

META.NumberType = "double"
META.Args = {{"x", "w", "p"}, {"y", "h", "y"}}

structs.AddAllOperators(META)
-- length stuff
do
	function META:GetLengthSquared()
		return self.x * self.x + self.y * self.y
	end

	function META:SetLength(num)
		local scale = num * 1/math.sqrt(self:GetLengthSquared())

		self.x = self.x * scale
		self.y = self.y * scale
	end

	function META:GetLength()
		return math.sqrt(self:GetLengthSquared())
	end

	META.__len = META.GetLength
	local ffi_is_type = require("ffi").istype

	function META.__lt(a, b)
		if type(a) == "cdata" and ffi_is_type(a, b) and type(b) == "number" then
			return a:GetLength() < b
		elseif type(b) == "cdata" and ffi_is_type(b, a) and type(a) == "number" then
			return b:GetLength() < a
		end
	end

	function META.__le(a, b)
		if type(a) == "cdata" and ffi_is_type(a, b) and type(b) == "number" then
			return a:GetLength() <= b
		elseif type(b) == "cdata" and ffi_is_type(b, a) and type(a) == "number" then
			return b:GetLength() <= a
		end
	end

	function META:SetMaxLength(num)
		local length = self:GetLengthSquared()

		if length * length > num then
			local scale = num * 1/math.sqrt(length)

			self.x = self.x * scale
			self.y = self.y * scale
		end
	end

	function META.Distance(a, b)
		return (a - b):GetLength()
	end
end

function META:Rotate(angle)
	local cs = math.cos(angle);
	local sn = math.sin(angle);

	local xx = self.x * cs - self.y * sn;
	local yy = self.x * sn + self.y * cs;

	self.x = xx
	self.y = yy

	return self
end

structs.AddGetFunc(META, "Rotate", "Rotated")

function META.Lerp(a, mult, b)

	a.x = (b.x - a.x) * mult + a.x
	a.y = (b.y - a.y) * mult + a.y

	return a
end

structs.AddGetFunc(META, "Lerp", "Lerped")

function META.GetDot(a, b)
	return
		a.x * b.x +
		a.y * b.y
	end

function META:Normalize(scale)
	scale = scale or 1
	local length = self:GetLengthSquared()

	if length == 0 then
		self.x = 0
		self.y = 0
		return self
	end
	local inverted_length = scale/math.sqrt(length)

	self.x = self.x * inverted_length
	self.y = self.y * inverted_length

	return self
end

structs.AddGetFunc(META, "Normalize", "Normalized")

function META:GetNormal(scale)
	return Vec2(-self.y * scale, self.x * scale)
end

function META.GetCrossed(a, b)
	return a.x * b.y - a.y * b.x
end

function META:GetReflected(normal)
	local proj = self:GetNormalized()
	local dot = proj:GetDot(normal)

  return Vec2(2 * (-dot) * normal.x + proj.x, 2 * (-dot) * normal.y + proj.y) * self:GetLength()
end

function META:Rotate90CCW()
	local x, y = self:Unpack()

	self.x = -y
	self.y = x

	return self
end

function META:Rotate90CW()
	local x, y = self:Unpack()

	self.x = y
	self.y = -x

	return self
end

function META:GetRad()
	return math.atan2(self.x, self.y)
end

function META:GetDeg()
	return math.deg(self:GetRad())
end

if GRAPHICS then
	META.ToWorld = math3d.ScreenToWorldDirection
end

structs.Register(META)

serializer.GetLibrary("luadata").SetModifier("vec2", function(var) return ("Vec2(%f, %f)"):format(var:Unpack()) end, structs.Vec2, "Vec2")

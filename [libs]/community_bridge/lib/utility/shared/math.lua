Math = Math or {}



---@class Math
---@field public name string @add name field to class Car, you'll see it in code completion
Math = {}


--- Rounds a number to the nearest whole number.
---@param value number: The value to round.
---@return number: The rounded value.
function Math.Round(value)
    return math.floor(value + 0.5)
end

function Math.Truncate(value, decimals)
	local mul = decimals and (10 ^ decimals) or 1
	if value < 0 then
		return math.ceil(value * mul) / mul
	else
		return math.floor(value * mul) / mul
	end
end

--- Warps the number around from max to min and vice versa.
---@param value number: The value to wrap.
---@param min number: The minimum value.
---@param max number: The maximum value.
---@return number: The wrapped value.
function Math.Wrap(value, min, max)
    local range = max - min
    return (value - min) % range + min
end

--- Gets an interpolated value between two numbers.
---@see https://en.wikipedia.org/wiki/Smoothstep
---@param value number The interpolation value.
---@param min number : The minimum value.
---@param max number : The maximum value.
---@return number The interpolated value.
function Math.Smooth(value, min, max)
    value = Math.Clamp((value - min) / (max - min), 0, 1)
    return value * value * (3 - 2 * value)
end

--- Gets the nearest whole number.
--- @param value number The value to round.
--- @return number The rounded value.
function Math.Nearest(value)
    return math.floor(value + 0.5)
end

--- Maps a value from one range to another.
---@param value number The value to map.
---@param inMin number The minimum value for the provided value.
---@param inMax number The maximum value for the provided value.
---@param outMin number The minimum value for the output.
---@param outMax number The maximum value for the output.
function Math.Map(value, inMin, inMax, outMin, outMax)
    return (value - inMin) / (inMax - inMin) * (outMax - outMin) + outMin
end

function Math.Clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

function Math.Remap(value, min, max, newMin, newMax)
    return newMin + (value - min) / (max - min) * (newMax - newMin)
end

function Math.PointInRadius(radius)
    local angle = math.rad(math.random(0, 360))
    return vector2(radius * math.cos(angle), radius * math.sin(angle))
end

function Math.Normalize(value, min, max)
    if max == min then return 0 end -- Avoid division by zero
    return (value - min) / (max - min)
end

function Math.Normalize2D(x, y)
    if type(x) == "vector2" then
        x, y = x.x, x.y
    end
    local length = math.sqrt(x*x + y*y)
    return length ~= 0 and vector2(x / length, y / length) or vector2(0, 0)
end

function Math.Normalize3D(x, y, z)
    if type(x) == "vector3" then
        x, y, z = x.x, x.y, x.z
    end
    local length = math.sqrt(x*x + y*y + z*z)
    return length ~= 0 and vector3(x / length, y / length, z / length) or vector3(0, 0, 0)
end

function Math.Normalize4D(x, y, z, w)
    if type(x) == "vector4" then
        x, y, z, w = x.x, x.y, x.z, x.w
    end
    local length = math.sqrt(x*x + y*y + z*z + w*w)
    return length ~= 0 and vector4(x / length, y / length, z / length, w / length) or vector4(0, 0, 0, 0)
end

function Math.DirectionToTarget(fromV3, toV3)
    return Math.Normalize3D(toV3.x - fromV3.x, toV3.y - fromV3.y, toV3.z - fromV3.z)
end

function Deg2Rad(deg)
    return deg * math.pi / 180.0
end

function RotVector(pos, rot)
    local pitch = Deg2Rad(rot.x)
    local roll  = Deg2Rad(rot.y)
    local yaw   = Deg2Rad(rot.z)

    local cosY = math.cos(yaw)
    local sinY = math.sin(yaw)
    local cosP = math.cos(pitch)
    local sinP = math.sin(pitch)
    local cosR = math.cos(roll)
    local sinR = math.sin(roll)

    local m11 = cosY * cosR + sinY * sinP * sinR
    local m12 = sinR * cosP
    local m13 = -sinY * cosR + cosY * sinP * sinR

    local m21 = -cosY * sinR + sinY * sinP * cosR
    local m22 = cosR * cosP
    local m23 = sinR * sinY + cosY * sinP * cosR

    local m31 = sinY * cosP
    local m32 = -sinP
    local m33 = cosY * cosP

    return vector3(pos.x * m11 + pos.y * m21 + pos.z * m31, pos.x * m12 + pos.y * m22 + pos.z * m32, pos.x * m13 + pos.y * m23 + pos.z * m33)
end


function Math.GetOffsetFromMatrix(position, rotation, offset)
    local rotated = RotVector(offset, rotation)
    print("Rotated: " .. tostring(rotated))
    return position + rotated
end

function Math.InBoundary(pos, boundary)
    if not boundary then return true end

    local x, y, z = table.unpack(pos)

    -- Handle legacy min/max boundary format for backwards compatibility
    if boundary.min and boundary.max then
        local minX, minY, minZ = table.unpack(boundary.min)
        local maxX, maxY, maxZ = table.unpack(boundary.max)
        return x >= minX and x <= maxX and y >= minY and y <= maxY and z >= minZ and z <= maxZ
    end

    -- Handle list of points (polygon boundary)
    if boundary.points and #boundary.points > 0 then
        local points = boundary.points
        local minZ = boundary.minZ or -math.huge
        local maxZ = boundary.maxZ or math.huge

        -- Check Z bounds first
        if z < minZ or z > maxZ then
            return false
        end

        -- Point-in-polygon test using ray casting algorithm (improved version)
        local inside = false
        local n = #points

        for i = 1, n do
            local j = i == n and 1 or i + 1 -- Next point (wrap around)

            local xi, yi = points[i].x or points[i][1], points[i].y or points[i][2]
            local xj, yj = points[j].x or points[j][1], points[j].y or points[j][2]

            -- Ensure xi, yi, xj, yj are numbers
            if not (xi and yi and xj and yj) then
                goto continue
            end

            -- Ray casting test
            if ((yi > y) ~= (yj > y)) then
                -- Calculate intersection point
                local intersect = (xj - xi) * (y - yi) / (yj - yi) + xi
                if x < intersect then
                    inside = not inside
                end
            end

            ::continue::
        end

        return inside
    end

    -- Fallback to true if boundary format is not recognized
    return true
end

exports('Math', Math)

return Math
LA = LA or {}

--https://easings.net
LA.Lerp = function(a, b, t)
  return a + (b - a) * t
end

LA.LerpVector = function(a, b, t)
  return vector3(LA.Lerp(a.x, b.x, t), LA.Lerp(a.y, b.y, t), LA.Lerp(a.z, b.z, t))
end

LA.EaseInSine = function(t)
  return 1 - math.cos((t * math.pi) / 2)
end

LA.EaseOutSine = function(t)
  return math.sin((t * math.pi) / 2)
end

LA.EaseInOutSine = function(t)
  return -(math.cos(math.pi * t) - 1) / 2
end

LA.EaseInCubic = function(t)
  return t ^ 3
end

LA.EaseOutCubic = function(t)
  return 1 - (1 - t) ^ 3
end

LA.EaseInOutCubic = function(t)
  return t < 0.5 and 4 * t ^ 3 or 1 - ((-2 * t + 2) ^ 3) / 2
end

LA.EaseInQuint = function(t)
  return t ^ 5
end

LA.EaseOutQuint = function(t)
  return 1 - (1 - t) ^ 5
end

LA.EaseInOutQuint = function(t)
  return t < 0.5 and 16 * t ^ 5 or 1 - ((-2 * t + 2) ^ 5) / 2
end

LA.EaseInCirc = function(t)
  return 1 - math.sqrt(1 - t ^ 2)
end

LA.EaseOutCirc = function(t)
  return math.sqrt(1 - (t - 1) ^ 2)
end

LA.EaseInOutCirc = function(t)
  return t < 0.5 and (1 - math.sqrt(1 - (2 * t) ^ 2)) / 2 or (math.sqrt(1 - (-2 * t + 2) ^ 2) + 1) / 2
end

LA.EaseInElastic = function(t)
  return t == 0 and 0 or t == 1 and 1 or -2 ^ (10 * t - 10) * math.sin((t * 10 - 10.75) * (2 * math.pi) / 3)
end

LA.EaseOutElastic = function(t)
  return t == 0 and 0 or t == 1 and 1 or 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end

LA.EaseInOutElastic = function(t)
  return t == 0 and 0 or t == 1 and 1 or t < 0.5 and -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * (2 * math.pi) / 4.5)) / 2 or (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * (2 * math.pi) / 4.5)) / 2 + 1
end

LA.EaseInQuad = function(t)
  return t ^ 2
end

LA.EaseOutQuad = function(t)
  return 1 - (1 - t) ^ 2
end

LA.EaseInOutQuad = function(t)
  return t < 0.5 and 2 * t ^ 2 or 1 - (-2 * t + 2) ^ 2 / 2
end

LA.EaseInQuart = function(t)
  return t ^ 4
end

LA.EaseOutQuart = function(t)
  return 1 - (1 - t) ^ 4
end

LA.EaseInOutQuart = function(t)
  return t < 0.5 and 8 * t ^ 4 or 1 - ((-2 * t + 2) ^ 4) / 2
end

LA.EaseInExpo = function(t)
  return t == 0 and 0 or 2 ^ (10 * t - 10)
end

LA.EaseOutExpo = function(t)
  return t == 1 and 1 or 1 - 2 ^ (-10 * t)
end

LA.EaseInOutExpo = function(t)
  return t == 0 and 0 or t == 1 and 1 or t < 0.5 and 2 ^ (20 * t - 10) / 2 or (2 - 2 ^ (-20 * t + 10)) / 2
end

LA.EaseInBack = function(t)
  return 2.70158 * t ^ 3 - 1.70158 * t ^ 2
end

LA.EaseOutBack = function(t)
  return 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2
end

LA.EaseInOutBack = function(t)
  return t < 0.5 and (2 * t) ^ 2 * ((1.70158 + 1) * 2 * t - 1.70158) / 2 or ((2 * t - 2) ^ 2 * ((1.70158 + 1) * (t * 2 - 2) + 1.70158) + 2) / 2
end

LA.EaseInBounce = function(t)
  print(1 - LA.EaseOutBounce(1 - t))
  return 1 - LA.EaseOutBounce(1 - t)
end

LA.EaseOutBounce = function(t)
  if t < 1 / 2.75 then
    return 7.5625 * t ^ 2
  elseif t < 2 / 2.75 then
    return 7.5625 * (t - 1.5 / 2.75) ^ 2 + 0.75
  elseif t < 2.5 / 2.75 then
    return 7.5625 * (t - 2.25 / 2.75) ^ 2 + 0.9375
  else
    return 7.5625 * (t - 2.625 / 2.75) ^ 2 + 0.984375
  end
end

LA.EaseInOutBounce = function(t)
  return t < 0.5 and (1 - LA.EaseOutBounce(1 - 2 * t)) / 2 or (1 + LA.EaseOutBounce(2 * t - 1)) / 2
end

LA.EaseIn = function(t, easingType)
  easingType = string.lower(easingType)
  if easingType == "linear" then
      return t
  elseif easingType == "sine" then
      return LA.EaseInSine(t)
  elseif easingType == "cubic" then
      return LA.EaseInCubic(t)
  elseif easingType == "quint" then
      return LA.EaseInQuint(t)
  elseif easingType == "circ" then
      return LA.EaseInCirc(t)
  elseif easingType == "elastic" then
      return LA.EaseInElastic(t)
  elseif easingType == "quad" then
      return LA.EaseInQuad(t)
  elseif easingType == "quart" then
      return LA.EaseInQuart(t)
  elseif easingType == "expo" then
      return LA.EaseInExpo(t)
  elseif easingType == "back" then
      return LA.EaseInBack(t)
  elseif easingType == "bounce" then
      return LA.EaseInBounce(t)
  end
end

LA.EaseOut = function(t, easingType)
  easingType = string.lower(easingType)
  if easingType == "linear" then
      return t
  elseif easingType == "sine" then
      return LA.EaseOutSine(t)
  elseif easingType == "cubic" then
      return LA.EaseOutCubic(t)
  elseif easingType == "quint" then
      return LA.EaseOutQuint(t)
  elseif easingType == "circ" then
      return LA.EaseOutCirc(t)
  elseif easingType == "elastic" then
      return LA.EaseOutElastic(t)
  elseif easingType == "quad" then
      return LA.EaseOutQuad(t)
  elseif easingType == "quart" then
      return LA.EaseOutQuart(t)
  elseif easingType == "expo" then
      return LA.EaseOutExpo(t)
  elseif easingType == "back" then
      return LA.EaseOutBack(t)
  elseif easingType == "bounce" then
      return LA.EaseOutBounce(t)
  end
end

LA.EaseInOut = function(t, easingType)
  easingType = string.lower(easingType)
  if easingType == "linear" then
      return t
  elseif easingType == "sine" then
      return LA.EaseInOutSine(t)
  elseif easingType == "cubic" then
      return LA.EaseInOutCubic(t)
  elseif easingType == "quint" then
      return LA.EaseInOutQuint(t)
  elseif easingType == "circ" then
      return LA.EaseInOutCirc(t)
  elseif easingType == "elastic" then
      return LA.EaseInOutElastic(t)
  elseif easingType == "quad" then
      return LA.EaseInOutQuad(t)
  elseif easingType == "quart" then
      return LA.EaseInOutQuart(t)
  elseif easingType == "expo" then
      return LA.EaseInOutExpo(t)
  elseif easingType == "back" then
      return LA.EaseInOutBack(t)
  elseif easingType == "bounce" then
      return LA.EaseInOutBounce(t)
  end
end

LA.EaseInVector = function(a, b, t, easingType)
  local tEase = LA.EaseIn(t, easingType)
  local x, y, z = a.x, a.y, a.z
  local x2, y2, z2 = b.x, b.y, b.z
  local x3, y3, z3 = x2 - x, y2 - y, z2 - z
  local x4, y4, z4 = x3 * tEase, y3 * tEase, z3 * tEase
  local x5, y5, z5 = x + x4, y + y4, z + z4
  return vector3(x5, y5, z5)
end

LA.EaseOutVector = function(a, b, t, easingType)
  local tEase = LA.EaseOut(t, easingType)
  local x, y, z = a.x, a.y, a.z
  local x2, y2, z2 = b.x, b.y, b.z
  local x3, y3, z3 = x2 - x, y2 - y, z2 - z
  local x4, y4, z4 = x3 * tEase, y3 * tEase, z3 * tEase
  local x5, y5, z5 = x + x4, y + y4, z + z4
  return vector3(x5, y5, z5)
end

LA.EaseInOutVector = function(a, b, t, easingType)
  local tEase = LA.EaseInOut(t, easingType)
  local x, y, z = a.x, a.y, a.z
  local x2, y2, z2 = b.x, b.y, b.z
  local x3, y3, z3 = x2 - x, y2 - y, z2 - z
  local x4, y4, z4 = x3 * tEase, y3 * tEase, z3 * tEase
  local x5, y5, z5 = x + x4, y + y4, z + z4
  return vector3(x5, y5, z5)
end

LA.EaseVector = function(inout, a, b, t, easingType)
  inout = string.lower(inout)
  if inout == "in" then
      return LA.EaseInVector(a, b, t, easingType)
  elseif inout == "out" then
      return LA.EaseOutVector(a, b, t, easingType)
  elseif inout == "inout" then
      return LA.EaseInOutVector(a, b, t, easingType)
  end
  assert(false, "Invalid type")
end

LA.EaseOnAxis = function(inout, a, b, t, easingType, axis)
    axis = axis or vector3(0, 0, 0)
    local x, y, z = a.x, a.y, a.z
    local increment = 0
    if inout == "in" then
        increment = LA.EaseIn(t, easingType)
    elseif inout == "out" then
        increment = LA.EaseOut(t, easingType)
    elseif inout == "inout" then
        increment = LA.EaseInOut(t, easingType)
    end
    return axis * increment
end

LA.TestCheck = function(point1, point2)
  local dx = point1.x - point2.x
  local dy = point1.y - point2.y
  local dz = point1.z - point2.z
  return math.sqrt(dx*dx + dy*dy + dz*dz)
end

LA.BoxZoneCheck = function(point, lower, upper)
  local x1, y1, z1 = lower.x, lower.y, lower.z
  local x2, y2, z2 = upper.x, upper.y, upper.z
  return point.x > x1 and point.x < x2 and point.y > y1 and point.y < y2 and point.z > z1 and point.z < z2
end

LA.DistanceCheck = function(pointA, pointB)
    return #(pointA - pointB) < 0.5
end

LA.Chance = function(chance)
  assert(chance, "Chance must be passed")
  assert(type(chance) == "number", "Chance must be a number")
  assert(chance >= 0 and chance <= 100, "Chance must be between 0 and 100")
  return math.random(1, 100) <= chance
end

LA.Vector4To3 = function(vector4)
  assert(vector4, "Vector4 must be passed")
  assert(type(vector4) == "vector4", "Vector4 must be a vector4")
  return vector3(vector4.x, vector4.y, vector4.z), vector4.w
end

LA.Dot = function(vectorA, vectorB)
    return vectorA.x * vectorB.x + vectorA.y * vectorB.y + vectorA.z * vectorB.z
end

LA.Length = function(vector)
    return math.sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
end

LA.Normalize = function(vector)
    local length = LA.Length(vector)
    return vector3(vector.x / length, vector.y / length, vector.z / length)
end

LA.Create2DRotationMatrix = function(angle) -- angle in radians
    local c = math.cos(angle)
    local s = math.sin(angle)
    return {
        c, -s, 0, 0,
        s,  c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1,
    }
end

LA.Create3DAxisRotationMatrix = function(vector)
    local yaw = vector.z
    local pitch = vector.x
    local roll = vector.y

    local cy = math.cos(yaw)
    local sy = math.sin(yaw)
    local cp = math.cos(pitch)
    local sp = math.sin(pitch)
    local cr = math.cos(roll)
    local sr = math.sin(roll)

    local matrix = {
        vector3(cp * cy, cp * sy, -sp),
        vector3(cy * sp * sr - cr * sy, sy * sp * sr + cr * cy, cp * sr),
        vector3(cy * sp * cr + sr * sy, cr * cy * sp - sr * sy, cp * cr)
    }

    return matrix
end

LA.Circle = function(t, radius, center)
    local x = radius * math.cos(t) + center.x
    local y = radius * math.sin(t) + center.y
    return vector3(x, y, center.z)
end

LA.Clamp = function(value, min, max)
    return math.min(math.max(value, min), max)
end

LA.CrossProduct = function(a, b)
    local x = a.y * b.z - a.z * b.y
    local y = a.z * b.x - a.x * b.z
    local z = a.x * b.y - a.y * b.x
    return vector3(x, y, z)
end

LA.CreateTranslateMatrix = function(x, y, z)
    return {
        1, 0, 0, x,
        0, 1, 0, y,
        0, 0, 1, z,
        0, 0, 0, 1,
    }
end

LA.MultiplyMatrix = function(m1, m2)
    local result = {}
    for i = 1, 4 do
        for j = 1, 4 do
            local sum = 0
            for k = 1, 4 do
                sum = sum + m1[(i - 1) * 4 + k] * m2[(k - 1) * 4 + j]
            end
            result[(i - 1) * 4 + j] = sum
        end
    end
    return result
end

LA.MultiplyMatrixByVector = function(m, v)
    local result = {}
    for i = 1, 4 do
        local sum = 0
        for j = 1, 4 do
            sum = sum + m[(i - 1) * 4 + j] * v[j]
        end
        result[i] = sum
    end
    return result
end

--Slines
LA.SplineLerp = function(nodes, start, endPos, t)
  -- Ensure t is clamped between 0 and 1
  t = LA.Clamp(t, 0, 1)

  -- Find the two closest nodes around t
  local prevNode, nextNode = nil, nil
  for i = 1, #nodes - 1 do
      if nodes[i].time <= t and nodes[i + 1].time >= t then
          prevNode, nextNode = nodes[i], nodes[i + 1]
          break
      end
  end

  -- Edge cases: If t is before or after the defined range
  if not prevNode then return start end
  if not nextNode then return endPos end

  -- Normalize t within the segment
  local segmentT = (t - prevNode.time) / (nextNode.time - prevNode.time)

  -- Interpolate the value (y-axis)
  local smoothedT = LA.Lerp(prevNode.value, nextNode.value, segmentT)

  -- Perform final Lerp using the interpolated smoothing factor
  return LA.Lerp(start, endPos, smoothedT)
end

LA.SplineSmooth = function(nodes, points, t)
  -- Ensure valid input
  if #points < 2 then return points end
  t = LA.Clamp(t, 0, 1)

  local smoothedPoints = {}

  for i = 1, #points - 1 do
      local smoothedPos = LA.SplineLerp(nodes, points[i], points[i + 1], t)
      table.insert(smoothedPoints, smoothedPos)
  end

  -- Ensure last point remains unchanged
  table.insert(smoothedPoints, points[#points])

  return smoothedPoints
end

LA.Spline = function(points, resolution)
  -- Ensure valid input
  if #points < 2 then return points end

  -- Create a list of nodes
  local nodes = {}
  for i = 1, #points do
      table.insert(nodes, { time = i / (#points - 1), value = i })
  end

  -- Smooth the points
  local smoothedPoints = {}
  for i = 0, 1, resolution do
      local smoothedPos = LA.SplineSmooth(nodes, points, i)
      table.insert(smoothedPoints, smoothedPos)
  end

  return smoothedPoints
end

LA.SplineCatmullRom = function(points, resolution)
  -- Ensure valid input
  if #points < 4 then return points end

  -- Create a list of nodes
  local nodes = {}
  for i = 1, #points do
      table.insert(nodes, { time = i / (#points - 1), value = i })
  end

  -- Smooth the points
  local smoothedPoints = {}
  for i = 0, 1, resolution do
      local smoothedPos = LA.SplineSmooth(nodes, points, i)
      table.insert(smoothedPoints, smoothedPos)
  end

  return smoothedPoints
end

exports('LA', LA)
return LA

-- local easingTypes = {
--     "linear",
--     "sine",
--     "cubic",
--     "quint",
--     "circ",
--     "elastic",
--     "quad",
--     "quart",
--     "expo",
--     "back",
--     "bounce"
-- }

--local inout = {
--    "in",
--    "out",
--    "inout"
--}


-- LA.LerpAngle = function(a, b, t)
--     local num = math.abs(b - a) % 360
--     local num2 = 360 - num
--     if num < num2 then
--         return a + num * t
--     else
--         return a - num2 * t
--     end
-- end

-- LA.LerpVectorAngle = function(a, b, t)
--     local x, y, z = a.x, a.y, a.z
--     local x2, y2, z2 = b.x, b.y, b.z
--     local x3, y3, z3 = LA.LerpAngle(x, x2, t), LA.LerpAngle(y, y2, t), LA.LerpAngle(z, z2, t)
--     return vector3(x3, y3, z3)
-- end

-- return LA
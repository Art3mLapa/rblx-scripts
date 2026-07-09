-- art3mlapa
-- no skid pwease
-- yes star pleas
-- (VR ONLY!!!!)

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting   = game:GetService("Lighting")

-- arcane lib
local LIB_URL = "https://raw.githubusercontent.com/Oracle228/Inertia/refs/heads/main/Arcane(Lib).lua"
local loader = loadstring(game:HttpGet(LIB_URL))
if loader then loader() end

-- load lib or no
if typeof(Neverlose) ~= "table" or not Neverlose.CreateWindow then
    notify("Opposed.REWORK", "Arcane library did not load correctly", 5)
    error("Arcane library did not load correctly")
end


-- bw theme
local theme = {
    Background = Color3.fromRGB(10, 10, 10),
    Section    = Color3.fromRGB(20, 20, 20),
    Accent     = Color3.fromRGB(255, 255, 255),
    Outline    = Color3.fromRGB(45, 45, 45),
    Text       = Color3.fromRGB(255, 255, 255),
    TextDark   = Color3.fromRGB(125, 125, 125),
    Button     = Color3.fromRGB(28, 28, 28),
}
Neverlose:AddTheme("Opposed", theme)
Neverlose:AddTheme("Default", theme)

for _, d in ipairs(drawings) do
    pcall(function()
        if d.ZIndex == 100 then d.Color = theme.Section
        elseif d.ZIndex == 101 then d.Color = theme.Accent
        elseif d.Filled == false and d.Thickness == 1.5 then d.Color = theme.Accent end
    end)
end

-- offset tysm imtheo

local Offsets = {}
pcall(function()
    local src = game:HttpGet("https://offsets.imtheo.lol/offsets.txt")
    for line in src:gmatch("[^\r\n]+") do
        local sec, key, val = line:match("^%s*(%w+)%s*::%s*(%w+)%s*=%s*(0x%x+)")
        if sec and key and val then
            Offsets[sec] = Offsets[sec] or {}
            Offsets[sec][key] = tonumber(val) or tonumber(val:sub(3), 16)
        end
    end
end)
local function off(section, key, fallback)
    local s = Offsets[section]
    return (s and s[key]) or fallback
end

--window gui

local Window = Neverlose:CreateWindow("Opposed", Vector2.new(650, 450), "Opposed")

-- bg watermark image
local bgImage = Drawing.new("Image")
bgImage.Visible = false
bgImage.ZIndex = 2
bgImage.Color = Color3.fromRGB(255, 255, 255)
bgImage.Transparency = 0.05  -- 95% transparent

local bgLoaded = false
pcall(function()
    local data = game:HttpGet("https://kappa.lol/tA5Te0")
    if data and #data > 0 then bgImage.Data = data; bgLoaded = true end
end)
table.insert(drawings, bgImage)

-- config format

local Config = {
    ESP = { Player = false },
    Visual = { FullBright = false },
    Aimbot = {
        RightHand     = false,
        LeftHand      = false,
        FOV           = 30,
        Smoothness    = 50,       -- 0 = instant, 100 = very smooth
        TargetPart    = "Head",   -- "Head" / "Torso" / "Any"
        DistanceCheck = false,
        MaxDistance   = 500,
        TeamCheck     = false,
    },
    Detector = {
        Staff  = false,
        Lethal = false,
    },
    Other = {
        NoCollideRight = false,
        NoCollideLeft  = false,
    },
}
local Controls = {}

-- env world setup

local ENV_LIGHT = Lighting.Address
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local ENV_ATMO = atmo and atmo.Address or 0

local ENV_OFF = {
    Lighting = {
        Brightness           = off("Lighting", "Brightness", 0x110),
        FogStart             = off("Lighting", "FogStart", 0x128),
        FogEnd               = off("Lighting", "FogEnd", 0x124),
        Ambient              = off("Lighting", "Ambient", 0xC8),
        OutdoorAmbient       = off("Lighting", "OutdoorAmbient", 0xF8),
        GlobalShadows        = off("Lighting", "GlobalShadows", 0x138),
        ExposureCompensation = off("Lighting", "ExposureCompensation", 0x11C),
    },
    Atmosphere = {
        Density = off("Atmosphere", "Density", 0xD0),
        Glare   = off("Atmosphere", "Glare", 0xD4),
        Haze    = off("Atmosphere", "Haze", 0xD8),
        Offset  = off("Atmosphere", "Offset", 0xDC),
    },
}

-- buggy shit (little bit fixed)
local envColorFmt
do
    local ambOff = ENV_OFF.Lighting.Ambient
    local ok, amb = pcall(function() return Lighting.Ambient end)
    if ok and amb then
        local r, g, b = amb.R, amb.G, amb.B
        local _, b0, b1, b2 = pcall(memory_read, "byte", ENV_LIGHT + ambOff)
        _, b1 = pcall(memory_read, "byte", ENV_LIGHT + ambOff + 1)
        _, b2 = pcall(memory_read, "byte", ENV_LIGHT + ambOff + 2)
        local _, f0, f1, f2
        _, f0 = pcall(memory_read, "float", ENV_LIGHT + ambOff)
        _, f1 = pcall(memory_read, "float", ENV_LIGHT + ambOff + 4)
        _, f2 = pcall(memory_read, "float", ENV_LIGHT + ambOff + 8)
        if r > 1 then  -- Matcha returns 0-255
            if b0 == math.floor(r) and b1 == math.floor(g) and b2 == math.floor(b) then envColorFmt = "packed"
            elseif f0 and math.abs(f0 - r/255) < 0.01 then envColorFmt = "floats" end
        else
            if b0 and math.abs(b0 - r*255) < 1 then envColorFmt = "packed"
            elseif f0 and math.abs(f0 - r) < 0.01 then envColorFmt = "floats" end
        end
    end
end

local envOrig = {}
local function envCapture()
    local L, A = ENV_OFF.Lighting, ENV_OFF.Atmosphere
    pcall(function() envOrig.Brightness = memory_read("float", ENV_LIGHT + L.Brightness) end)
    pcall(function() envOrig.FogStart   = memory_read("float", ENV_LIGHT + L.FogStart) end)
    pcall(function() envOrig.FogEnd     = memory_read("float", ENV_LIGHT + L.FogEnd) end)
    pcall(function() envOrig.Shadows    = memory_read("byte",  ENV_LIGHT + L.GlobalShadows) end)
    pcall(function() envOrig.Exposure   = memory_read("float", ENV_LIGHT + L.ExposureCompensation) end)
    pcall(function() envOrig.Ambient    = memory_read("int",   ENV_LIGHT + L.Ambient) end)
    pcall(function() envOrig.OutAmbient = memory_read("int",   ENV_LIGHT + L.OutdoorAmbient) end)
    if ENV_ATMO > 0 then
        pcall(function() envOrig.Density = memory_read("float", ENV_ATMO + A.Density) end)
        pcall(function() envOrig.Glare   = memory_read("float", ENV_ATMO + A.Glare) end)
        pcall(function() envOrig.Haze    = memory_read("float", ENV_ATMO + A.Haze) end)
        pcall(function() envOrig.Offset  = memory_read("float", ENV_ATMO + A.Offset) end)
    end
end
envCapture()

local function envWriteColor(off, val)
    if envColorFmt == "packed" then
        for i = 0, 2 do pcall(memory_write, "byte", ENV_LIGHT + off + i, val) end
        pcall(memory_write, "byte", ENV_LIGHT + off + 3, 0)
    elseif envColorFmt == "floats" then
        local n = val / 255
        pcall(memory_write, "float", ENV_LIGHT + off, n)
        pcall(memory_write, "float", ENV_LIGHT + off + 4, n)
        pcall(memory_write, "float", ENV_LIGHT + off + 8, n)
    end
end

local function envApplyFullBright()
    local L = ENV_OFF.Lighting
    pcall(memory_write, "byte",  ENV_LIGHT + L.GlobalShadows, 0)
    pcall(memory_write, "float", ENV_LIGHT + L.Brightness, 1)
    pcall(memory_write, "float", ENV_LIGHT + L.ExposureCompensation, 0)
    envWriteColor(L.Ambient, 255)
    envWriteColor(L.OutdoorAmbient, 255)
    if ENV_ATMO > 0 then pcall(memory_write, "float", ENV_ATMO + ENV_OFF.Atmosphere.Density, 0) end
end

local function envRestoreAll()
    local L, A = ENV_OFF.Lighting, ENV_OFF.Atmosphere
    if envOrig.Brightness  ~= nil then pcall(memory_write, "float", ENV_LIGHT + L.Brightness,           envOrig.Brightness) end
    if envOrig.FogStart    ~= nil then pcall(memory_write, "float", ENV_LIGHT + L.FogStart,             envOrig.FogStart) end
    if envOrig.FogEnd      ~= nil then pcall(memory_write, "float", ENV_LIGHT + L.FogEnd,               envOrig.FogEnd) end
    if envOrig.Shadows     ~= nil then pcall(memory_write, "byte",  ENV_LIGHT + L.GlobalShadows,        envOrig.Shadows) end
    if envOrig.Exposure    ~= nil then pcall(memory_write, "float", ENV_LIGHT + L.ExposureCompensation, envOrig.Exposure) end
    if envOrig.Ambient     ~= nil then pcall(memory_write, "int",   ENV_LIGHT + L.Ambient,              envOrig.Ambient) end
    if envOrig.OutAmbient  ~= nil then pcall(memory_write, "int",   ENV_LIGHT + L.OutdoorAmbient,       envOrig.OutAmbient) end
    if ENV_ATMO > 0 then
        if envOrig.Density ~= nil then pcall(memory_write, "float", ENV_ATMO + A.Density, envOrig.Density) end
        if envOrig.Glare   ~= nil then pcall(memory_write, "float", ENV_ATMO + A.Glare,   envOrig.Glare) end
        if envOrig.Haze    ~= nil then pcall(memory_write, "float", ENV_ATMO + A.Haze,    envOrig.Haze) end
        if envOrig.Offset  ~= nil then pcall(memory_write, "float", ENV_ATMO + A.Offset,  envOrig.Offset) end
    end
end

-- gui buttons

Window:CreateTabSection("Categories")
Window:CreateTab("Visual")
Window:CreateTab("Combat")
Window:CreateTab("Other")

-- other: detectors
local detSection = Window:CreateSection("Detectors", "Other")
Controls.DET_Staff = detSection:AddToggle("Staff Detector", false, function(v)
    Config.Detector.Staff = v
end)
Controls.DET_Lethal = detSection:AddToggle("Lethal Detector", false, function(v)
    Config.Detector.Lethal = v
end)

-- other: no collide
local collSection = Window:CreateSection("No Collide", "Other")
Controls.OTH_NoCollideR = collSection:AddToggle("Right Arm", false, function(v)
    Config.Other.NoCollideRight = v
end)
Controls.OTH_NoCollideL = collSection:AddToggle("Left Arm", false, function(v)
    Config.Other.NoCollideLeft = v
end)

-- visual: ESP
local espSection = Window:CreateSection("ESP", "Visual")
Controls.ESP_Player = espSection:AddToggle("Player", false, function(v)
    Config.ESP.Player = v
end)

-- visual: environment
local envSection = Window:CreateSection("Environment", "Visual")
Controls.VIS_FullBright = envSection:AddToggle("FullBright", false, function(v)
    Config.Visual.FullBright = v
end)

-- combat: aimbot
local aimbotSection = Window:CreateSection("Aimbot", "Combat")
Controls.Aimbot_Right = aimbotSection:AddToggle("Right Hand", false, function(v)
    Config.Aimbot.RightHand = v
end)
Controls.Aimbot_Left = aimbotSection:AddToggle("Left Hand", false, function(v)
    Config.Aimbot.LeftHand = v
end)
Controls.Aimbot_TargetPart = aimbotSection:AddDropdown("Target Part", { "Head", "Torso", "Any" }, "Head", function(v)
    Config.Aimbot.TargetPart = v
end)
Controls.Aimbot_FOV = aimbotSection:AddSlider("FOV", {
    Min = 5, Max = 180, Default = 30,
    Callback = function(v) Config.Aimbot.FOV = v end,
})
Controls.Aimbot_Smoothness = aimbotSection:AddSlider("Smoothness", {
    Min = 0, Max = 100, Default = 50,
    Callback = function(v) Config.Aimbot.Smoothness = v end,
})
Controls.Aimbot_DistanceCheck = aimbotSection:AddToggle("Distance Check", false, function(v)
    Config.Aimbot.DistanceCheck = v
end)
Controls.Aimbot_MaxDistance = aimbotSection:AddSlider("Max Distance", {
    Min = 5, Max = 2500, Default = 500,
    Callback = function(v) Config.Aimbot.MaxDistance = v end,
})
Controls.Aimbot_TeamCheck = aimbotSection:AddToggle("Team Check", false, function(v)
    Config.Aimbot.TeamCheck = v
end)

local SLIDER_FILL = Color3.fromRGB(70, 70, 70)
for i, item in ipairs(aimbotSection.ContentDrawings) do
    if item.Type == "SliderFrame" then
        local fill = aimbotSection.ContentDrawings[i + 1]
        if fill and fill.Obj then fill.Obj.Color = SLIDER_FILL end
    end
end

-- save/load config

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "opposedart3.json"

local saveableKeys = {
    { ctrl = "ESP_Player",         cfg = function() return Config.ESP.Player end,           apply = function(v) Config.ESP.Player = v end },
    { ctrl = "VIS_FullBright",     cfg = function() return Config.Visual.FullBright end,    apply = function(v) Config.Visual.FullBright = v end },
    { ctrl = "Aimbot_Right",       cfg = function() return Config.Aimbot.RightHand end,     apply = function(v) Config.Aimbot.RightHand = v end },
    { ctrl = "Aimbot_Left",        cfg = function() return Config.Aimbot.LeftHand end,      apply = function(v) Config.Aimbot.LeftHand = v end },
    { ctrl = "Aimbot_TargetPart",  cfg = function() return Config.Aimbot.TargetPart end,    apply = function(v) Config.Aimbot.TargetPart = v end },
    { ctrl = "Aimbot_FOV",            cfg = function() return Config.Aimbot.FOV end,             apply = function(v) Config.Aimbot.FOV = v end },
    { ctrl = "Aimbot_Smoothness",     cfg = function() return Config.Aimbot.Smoothness end,      apply = function(v) Config.Aimbot.Smoothness = v end },
    { ctrl = "Aimbot_DistanceCheck",  cfg = function() return Config.Aimbot.DistanceCheck end,   apply = function(v) Config.Aimbot.DistanceCheck = v end },
    { ctrl = "Aimbot_MaxDistance",    cfg = function() return Config.Aimbot.MaxDistance end,     apply = function(v) Config.Aimbot.MaxDistance = v end },
    { ctrl = "Aimbot_TeamCheck",      cfg = function() return Config.Aimbot.TeamCheck end,       apply = function(v) Config.Aimbot.TeamCheck = v end },
    { ctrl = "DET_Staff",             cfg = function() return Config.Detector.Staff end,         apply = function(v) Config.Detector.Staff = v end },
    { ctrl = "DET_Lethal",            cfg = function() return Config.Detector.Lethal end,        apply = function(v) Config.Detector.Lethal = v end },
    { ctrl = "OTH_NoCollideR",        cfg = function() return Config.Other.NoCollideRight end,  apply = function(v) Config.Other.NoCollideRight = v end },
    { ctrl = "OTH_NoCollideL",        cfg = function() return Config.Other.NoCollideLeft end,   apply = function(v) Config.Other.NoCollideLeft = v end },
}

local function saveConfig()
    local data = {}
    for _, k in ipairs(saveableKeys) do
        data[k.ctrl] = k.cfg()
    end
    pcall(function()
        if not isfolder("Opposed") then makefolder("Opposed") end
        writefile("Opposed/" .. CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    local ok, raw = pcall(function() return readfile("Opposed/" .. CONFIG_FILE) end)
    if not ok or not raw then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    for _, k in ipairs(saveableKeys) do
        local v = data[k.ctrl]
        if v ~= nil then
            k.apply(v)
            local ctrl = Controls[k.ctrl]
            if ctrl then
                pcall(function() ctrl:SetValue(v) end)
            end
        end
    end
    print("[Opposed] Config loaded from Opposed/" .. CONFIG_FILE)
end

loadConfig()

-- player esp

local HUM_OFF = {
    DisplayDistanceType   = off("Humanoid", "DisplayDistanceType", 0x180),
    HealthDisplayDistance = off("Humanoid", "HealthDisplayDistance", 0x18C),
    NameDisplayDistance   = off("Humanoid", "NameDisplayDistance", 0x1B0),
    NameOcclusion         = off("Humanoid", "NameOcclusion", 0x1B4),
}

local function getHumanoids()
    local out, localChar = {}, Players.LocalPlayer and Players.LocalPlayer.Character
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m ~= localChar then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Address and hum.Address > 4096 then out[#out + 1] = hum end
        end
    end
    return out
end

local function espApply()
    for _, hum in ipairs(getHumanoids()) do
        local a = hum.Address
        pcall(memory_write, "byte",  a + HUM_OFF.DisplayDistanceType, 0)
        pcall(memory_write, "float", a + HUM_OFF.HealthDisplayDistance, 9e8)
        pcall(memory_write, "float", a + HUM_OFF.NameDisplayDistance, 9e8)
        pcall(memory_write, "byte",  a + HUM_OFF.NameOcclusion, 0)
    end
end

local function espRestore()
    for _, hum in ipairs(getHumanoids()) do
        local a = hum.Address
        pcall(memory_write, "float", a + HUM_OFF.NameDisplayDistance, 0)
        pcall(memory_write, "float", a + HUM_OFF.HealthDisplayDistance, 0)
        pcall(memory_write, "byte",  a + HUM_OFF.DisplayDistanceType, 0)
        pcall(memory_write, "byte",  a + HUM_OFF.NameOcclusion, 0)
    end
end

spawn(function()
    local wasOn = false
    while true do
        pcall(function()
            if Config.ESP.Player then espApply(); wasOn = true
            elseif wasOn then espRestore(); wasOn = false end
        end)
        wait(0.5)
    end
end)

-- environment loop: re-apply FullBright while on, restore when off
spawn(function()
    local fbOn = false
    while true do
        pcall(function()
            if Config.Visual.FullBright then envApplyFullBright(); fbOn = true
            elseif fbOn then envRestoreAll(); fbOn = false end
        end)
        wait(0.5)
    end
end)

-- aimbot (buggy asf)
local function buildCF(ap, vx, vy, vz)
    local cf
    pcall(function() cf = CFrame.fromMatrix(ap, vx, vy, vz) end)
    if not cf then cf = CFrame.new(ap.X, ap.Y, ap.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z) end
    return cf
end

-- Orient so `axisVec` points at tp, using upHint for roll (no spin/flip).
local function orient(axisVec, ap, tp, upHint)
    local dir = tp - ap
    if dir.Magnitude < 0.01 then return nil end
    dir = dir.Unit
    local up = upHint - upHint:Dot(dir) * dir
    if up.Magnitude < 0.01 then up = Vector3.new(0, 1, 0) end
    up = up.Unit
    local vx, vy, vz
    if axisVec.Y ~= 0 then local d = axisVec.Y * dir; vy = d; vz = up; vx = d:Cross(up)
    elseif axisVec.Z ~= 0 then local d = axisVec.Z * dir; vz = d; vy = up; vx = up:Cross(d)
    else local d = axisVec.X * dir; vx = d; vy = up; vz = d:Cross(up) end
    return buildCF(ap, vx, vy, vz)
end

local function getTargetParts(model)
    local tp = Config.Aimbot.TargetPart
    if tp == "Head" then
        local h = model:FindFirstChild("Head")
        return h and { h } or {}
    elseif tp == "Torso" then
        local t = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
        return t and { t } or {}
    else -- "Any": return all available parts, aimHand picks the closest to FOV center
        local parts = {}
        for _, name in ipairs({ "Head", "Torso", "HumanoidRootPart", "Body" }) do
            local p = model:FindFirstChild(name)
            if p and p:IsA("BasePart") then parts[#parts + 1] = p end
        end
        return parts
    end
end

local targetCache, targetStamp = {}, 0
local function getTargets()
    if os.clock() - targetStamp < 0.5 then return targetCache end
    targetStamp = os.clock()
    local out, lp, myTeam = {}, Players.LocalPlayer, Players.LocalPlayer and Players.LocalPlayer.Team
    local myChar = lp and lp.Character
    local function scan(folder)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= myChar and m.Name ~= lp.Name then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum then
                    local alive = true; pcall(function() alive = hum.Health > 0 end)
                    if alive then
                        -- Team Check: skip same-team players when enabled
                        local sameTeam = false
                        if Config.Aimbot.TeamCheck then
                            local plr = Players:FindFirstChild(m.Name)
                            if plr and plr.Team and myTeam and plr.Team == myTeam then sameTeam = true end
                        end
                        if not sameTeam then
                            for _, part in ipairs(getTargetParts(m)) do
                                out[#out + 1] = { part = part, model = m }
                            end
                        end
                    end
                end
            end
        end
    end
    pcall(scan, workspace:FindFirstChild("NPCs"))
    pcall(scan, workspace)
    targetCache = out
    return out
end

-- Disable arm constraints (AlignOrientation/AlignPosition) so our CFrame sticks.
local function disableConstraints(arm, state)
    if state._done and state._arm == arm then return end
    if state._list then for _, d in ipairs(state._list) do pcall(function() d.Enabled = true end) end end
    state._arm = arm; state._list = {}; state._done = true
    pcall(function()
        for _, d in ipairs(arm:GetDescendants()) do
            if d:IsA("AlignOrientation") or d:IsA("AlignPosition") then
                pcall(function() d.Enabled = false end)
                state._list[#state._list + 1] = d
            end
        end
    end)
end
local function restoreConstraints(state)
    if not state._list then return end
    for _, d in ipairs(state._list) do pcall(function() d.Enabled = true end) end
    state._list = nil; state._done = nil; state._arm = nil
end

local aimStateR, aimStateL = {}, {}

local function aimHand(vHand, armName, state, enabled)
    local lpChar = Players.LocalPlayer.Character
    local arm = lpChar and lpChar:FindFirstChild(armName)
    if not enabled or not arm or not vHand or not vHand.Parent then
        restoreConstraints(state)
        state.smoothPos = nil
        return
    end
    -- Pause if the local player is dead -- let the arm follow the body
    -- naturally during death/respawn instead of floating in place.
    local hum = lpChar:FindFirstChildOfClass("Humanoid")
    local alive = true
    pcall(function() alive = hum and hum.Health > 0 end)
    if not alive then
        restoreConstraints(state)
        state.smoothPos = nil
        return
    end
    disableConstraints(arm, state)

    local hcf = vHand.CFrame
    local look, negUp = hcf.LookVector, -hcf.UpVector
    -- Use the ARM's own position (not the controller's) as the CFrame origin.
    -- This prevents the arm from teleporting to the controller position each frame
    -- (which caused the "jerking to controller" effect). The arm stays at its
    -- natural shoulder position; only the ORIENTATION changes to aim at the target.
    local armPos = arm.CFrame.Position

    -- find best target on fov
    local best, bestAng = nil, math.huge
    local maxDist = Config.Aimbot.DistanceCheck and Config.Aimbot.MaxDistance or 2500
    for _, t in ipairs(getTargets()) do
        local ok, tp = pcall(function() return t.part.Position end)
        if ok and tp then
            local diff = tp - hcf.Position
            local dist = diff.Magnitude
            if dist > 0.5 and dist <= maxDist then
                local ang = math.deg(math.acos(math.clamp(look:Dot(diff / dist), -1, 1)))
                if ang < Config.Aimbot.FOV and ang < bestAng then bestAng = ang; best = t end
            end
        end
    end

    if best then
        local ok, tp = pcall(function() return best.part.Position end)
        if ok and tp then
            -- smoothness (low-pass filter)
            local sf = 1.0 - (Config.Aimbot.Smoothness / 100) * 0.95
            if not state.smoothPos or (state.smoothPos - tp).Magnitude > 30 then
                state.smoothPos = tp
            else
                state.smoothPos = state.smoothPos + (tp - state.smoothPos) * sf
            end
            -- orient from the ARM's position (stays on shoulder), aiming -Y at target
            local tcf = orient(Vector3.new(0, -1, 0), armPos, state.smoothPos, negUp)
            if tcf then pcall(function() arm.CFrame = tcf end) end
        end
    else
        state.smoothPos = nil
    end
end

local aimbotConn = RunService.RenderStepped:Connect(function()
    pcall(function()
        local vLoc = workspace.CurrentCamera:FindFirstChild("VirtualLocations")
        aimHand(vLoc and vLoc:FindFirstChild("RightHand"), "Right Arm", aimStateR, Config.Aimbot.RightHand)
        aimHand(vLoc and vLoc:FindFirstChild("LeftHand"),  "Left Arm",  aimStateL, Config.Aimbot.LeftHand)
    end)
end)

-- no collide
spawn(function()
    while true do
        pcall(function()
            local char = Players.LocalPlayer.Character
            if char then
                if Config.Other.NoCollideRight then
                    local arm = char:FindFirstChild("Right Arm")
                    if arm then pcall(function() arm.CanCollide = false end) end
                end
                if Config.Other.NoCollideLeft then
                    local arm = char:FindFirstChild("Left Arm")
                    if arm then pcall(function() arm.CanCollide = false end) end
                end
            end
        end)
        wait()
    end
end)

-- staff (developers, moderators, suckdickers etc etc etc)
local GROUP_ID     = 9959763
local STAFF_RANKS  = { [250]=1, [251]=1, [252]=1, [253]=1, [254]=1, [54]=1, [55]=1, [53]=1 }
local LETHAL_RANKS = { [25]=1, [52]=1 }
local detHttp      = game:GetService("HttpService")

local function kickLocal(reason)
    pcall(function()
        local lp = Players.LocalPlayer
        if lp then lp:Kick(reason) end
    end)
end

-- thx luavm api
local function getGroupRank(userId)
    local ok, body = pcall(function()
        return game:HttpGet("https://groups.roblox.com/v1/users/" .. userId .. "/groups/roles")
    end)
    if not ok or not body or #body == 0 then return 0 end
    local ok2, parsed = pcall(function() return detHttp:JSONDecode(body) end)
    if not ok2 or not parsed or not parsed.data then return 0 end
    for _, entry in ipairs(parsed.data) do
        if entry.group and entry.group.id == GROUP_ID then
            return entry.role and entry.role.rank or 0
        end
    end
    return 0
end

-- cache
local detectorChecked = {}

local function checkPlayer(plr)
    if not plr or detectorChecked[plr] then return end
    detectorChecked[plr] = true
    local rank = getGroupRank(plr.UserId)
    if rank == 0 then return end
    if Config.Detector.Staff and STAFF_RANKS[rank] then
        kickLocal("[OPPOSED] Staff Detected: " .. plr.Name)
    elseif Config.Detector.Lethal and LETHAL_RANKS[rank] then
        kickLocal("[OPPOSED] Lethal Detected: " .. plr.Name)
    end
end

-- check roles
spawn(function()
    while true do
        pcall(function()
            if Config.Detector.Staff or Config.Detector.Lethal then
                for _, plr in ipairs(Players:GetPlayers()) do
                    checkPlayer(plr)
                end
            end
        end)
        wait(3)
    end
end)

if Players.PlayerAdded then
    Players.PlayerAdded:Connect(function(plr)
        pcall(function()
            if Config.Detector.Staff or Config.Detector.Lethal then
                checkPlayer(plr)
            end
        end)
    end)
end

-- gui
Window:Finalize()

-- about page
Window:CreateTab("About")
local aboutSection = Window:CreateSection("About", "About")
aboutSection.Width = 450
aboutSection:AddLabel("Opposed VR REWORK 0.2 Beta")
aboutSection:AddLabel("By Art3mLapa (https://github.com/Art3mLapa)")
aboutSection:AddLabel("Original Developer (stinky): HackerooMan/OpposedDev")
aboutSection:AddLabel("UI Lib: Arcane (Oracle228)")
aboutSection:AddLabel("Offsets: imtheo")
aboutSection:AddLabel("any bugs or suggestions: dm dis art3mkalapapapapapa")
Window:UpdateVisibility()

-- bg
if bgLoaded then bgImage.Visible = Neverlose.IsOpen end
local _origSetVisible = Window.SetVisible
Window.SetVisible = function(self, state)
    _origSetVisible(self, state)
    if bgLoaded then bgImage.Visible = state end
end

spawn(function()
    while true do
        pcall(function()
            if bgLoaded then
                local h = Window.Size.Y
                bgImage.Size = Vector2.new(h, h)
                bgImage.Position = Window.Pos + Vector2.new(150 + (Window.Size.X - 150 - h) / 2, 0)
            end
        end)
        wait()
    end
end)

-- init
_G.Opposed = { Config = Config, Controls = Controls }
_G.Opposed_Cleanup = function()
    saveConfig()
    pcall(function() aimbotConn:Disconnect() end)
    restoreConstraints(aimStateR)
    restoreConstraints(aimStateL)
    pcall(espRestore)
    pcall(envRestoreAll)
end

-- autosave
spawn(function()
    while true do
        wait(30)
        pcall(saveConfig)
    end
end)

Neverlose:Notify("Opposed.REWORK", "Loaded successfully", 5)
print("[Opposed.REWORK] UI ready.")

if _G.__RadoHubLoaded then pcall(function() _G.__RadoHubUnload() end) end
_G.__RadoHubLoaded = true


local KEY_SECRET  = "Kx9!mQ2vR7#pL4nT8$wY6&bZ3@hJ5^sD1"
local KEY_PRODUCT = "RADO"
local KEY_FILE    = "RadoHub/.key"

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(str)
    str = str:gsub("[^" .. B64_CHARS .. "=]", "")
    local out = {}
    local i = 1
    while i <= #str do
        local c1 = B64_CHARS:find(str:sub(i,i), 1, true)
        local c2 = B64_CHARS:find(str:sub(i+1,i+1), 1, true)
        local c3 = B64_CHARS:find(str:sub(i+2,i+2), 1, true)
        local c4 = B64_CHARS:find(str:sub(i+3,i+3), 1, true)
        if not c1 or not c2 then break end
        c1, c2 = c1 - 1, c2 - 1
        local b1 = c1 * 4 + math.floor(c2 / 16)
        out[#out+1] = string.char(b1)
        if c3 then
            c3 = c3 - 1
            local b2 = (c2 % 16) * 16 + math.floor(c3 / 4)
            out[#out+1] = string.char(b2)
            if c4 then
                c4 = c4 - 1
                local b3 = (c3 % 4) * 64 + c4
                out[#out+1] = string.char(b3)
            end
        end
        i = i + 4
    end
    return table.concat(out)
end

local function hashKey(str)
    local h = 5381
    for i = 1, #str do
        h = ((h * 33) + string.byte(str, i)) % 4294967296
    end
    return string.format("%08x", h)
end

local function validateKey(key)
    if type(key) ~= "string" then return false, "Invalid key format" end
    key = key:gsub("%s+", "")
    if key == "" then return false, "Empty key" end

    local prefix, payloadB64, sigB64 = key:match("^(RADO)%-(.+)%-(.+)$")
    if not prefix then return false, "Bad key format (expected RADO-...-...)" end

    local okP, payload = pcall(b64decode, payloadB64)
    if not okP or not payload or payload == "" then return false, "Corrupt payload" end

    local okS, sigHex = pcall(b64decode, sigB64)
    if not okS or not sigHex or sigHex == "" then return false, "Corrupt signature" end

    local expectedSig = hashKey(payload .. KEY_SECRET)
    if expectedSig ~= sigHex then return false, "Invalid signature" end

    local product, expiresStr = payload:match("^(.-)|(.-)|")
    if product ~= KEY_PRODUCT then return false, "Wrong product" end

    local expiresAt = tonumber(expiresStr) or 0
    if expiresAt > 0 and os.time() > expiresAt then
        return false, "Key expired"
    end

    return true, "OK", expiresAt
end

local SELF_HASH = "REPLACE_ME"

local STRUCTURE_HASH = "23767ea0"

local function bxor(a, b)
    local r, bit = 0, 1
    while a > 0 or b > 0 do
        local abit = a % 2
        local bbit = b % 2
        if abit ~= bbit then r = r + bit end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return r
end

local function fnv1a(s)
    local h = 2166136261
    for i = 1, #s do
        h = bxor(h, string.byte(s, i))
        h = (h * 16777619) % 4294967296
    end
    return string.format("%08x", h)
end

local function buildCanary()
    return table.concat({
        KEY_SECRET,
        KEY_PRODUCT,
        KEY_FILE,
        B64_CHARS,
        "RadoHub",
        "Combat",
        "Visuals",
        "Player",
        "Teleport",
        "Sniper",
        "Configs",
        "RADO-",
        "RadoHub_KeyPrompt",
        "RadoHub/.key",
        tostring(2166136261),
        tostring(16777619),
    }, "|")
end

local function structureHash()
    return fnv1a(buildCanary())
end

local function getSelfSource()
    if type(getscriptbytecode) == "function" then
        local ok, bc = pcall(getscriptbytecode, script)
        if ok and type(bc) == "string" and #bc > 0 then return bc end
    end
    if type(getscriptclosure) == "function" and type(dumpstring) == "function" then
        local ok, cl = pcall(getscriptclosure, script)
        if ok and cl then
            local ok2, ds = pcall(dumpstring, cl)
            if ok2 and type(ds) == "string" and #ds > 0 then return ds end
        end
    end
    if debug and type(debug.getinfo) == "function" then
        local ok, info = pcall(debug.getinfo, 1, "S")
        if ok and info and info.source then return info.source end
    end
    return nil
end

local function poof()
    _G.__RadoHubLoaded = nil
    _G.__RadoHubUnload = nil
    _G.__RadoHubStopFly = nil
    _G.__RadoHubAntiFlingStop = nil
    _G.__RadoHubRefreshConfigs = nil
    _G.__RadoHubKeyPrompt = nil

    pcall(function()
        local pg = game:GetService("Players").LocalPlayer
            and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui.Name == "RadoHub" or gui.Name == "RadoHub_KeyPrompt" then
                    gui:Destroy()
                end
            end
        end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, gui in ipairs(cg:GetChildren()) do
            if gui.Name == "RadoHub" or gui.Name == "RadoHub_KeyPrompt" then
                gui:Destroy()
            end
        end
    end)
    return coroutine.create(function() end)
end

local function verifyIntegrity()
    -- Dev mode: print values so the author can bake them in.
    if SELF_HASH == "REPLACE_ME" or STRUCTURE_HASH == "REPLACE_ME" then
        local src = getSelfSource()
        if src then
            print("[RadoHub] SELF-HASH = " .. fnv1a(src))
        else
            print("[RadoHub] SELF-HASH unavailable (executor lacks source API)")
        end
        print("[RadoHub] STRUCTURE-HASH = " .. structureHash())
        return true
    end

    -- Layer 1: source hash (only if we can read it and user set it).
    if SELF_HASH ~= "REPLACE_ME" then
        local src = getSelfSource()
        if src then
            if fnv1a(src) ~= SELF_HASH then return false end
        end
    end

    -- Layer 2: structure hash — always enforced once baked in.
    if structureHash() ~= STRUCTURE_HASH then return false end

    return true
end

if not verifyIntegrity() then
    poof()
    return
end

--======================================================================
-- MAIN BODY
--======================================================================
local function mainBody(keyExpiresAt)
    keyExpiresAt = keyExpiresAt or 0
    if not verifyIntegrity() then poof() return end

    local Players          = game:GetService("Players")
    local RunService       = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService      = game:GetService("HttpService")
    local TweenService     = game:GetService("TweenService")
    local Lighting         = game:GetService("Lighting")
    local TeleportService  = game:GetService("TeleportService")
    local Camera           = workspace.CurrentCamera
    local LocalPlayer      = Players.LocalPlayer

    local hasFileIO = (typeof(writefile) == "function") and (typeof(readfile) == "function")
    local CONFIG_FOLDER = "RadoHub"
    local function ensureFolder()
        if hasFileIO and isfolder and not isfolder(CONFIG_FOLDER) then
            pcall(function() makefolder(CONFIG_FOLDER) end)
        end
    end

    local function getExecutorName()
        if typeof(identifyexecutor) == "function" then
            local ok, name = pcall(identifyexecutor)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        if typeof(getexecutorname) == "function" then
            local ok, name = pcall(getexecutorname)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        return "Unknown"
    end
    local EXECUTOR_NAME = getExecutorName()

    local Config = {
        AimbotEnabled=false, AimbotUseKey=true, AimbotKey="MB2",
        AimbotFOV=150, AimbotSmoothness=0.2,
        AimbotTeamCheck=true, AimbotVisibleOnly=true, AimbotPart="Head",

        SilentAimEnabled=false, SilentAimUseKey=true, SilentAimKey="MB1",
        SilentAimFOV=150, SilentAimTeamCheck=true, SilentAimVisibleOnly=true,
        SilentAimPart="Head", SilentAimHitChance=100,

        TriggerBotEnabled=false, TriggerBotKey="MB1", TriggerBotDelay=0.05,
        TriggerBotTeamCheck=true, TriggerBotVisibleOnly=true,
        TriggerBotPart="HumanoidRootPart",

        HitboxEnabled=false, HitboxSize=5,
        HitboxTeamCheck=true, HitboxVisibleOnly=true,
        HitboxTransparency=0.7,
        HitboxUseHead=false, HitboxUseHumanoidRootPart=true,

        PredictionEnabled=true,
        PredictionPing=0.05,

        ESPEnabled=false, ESPTeamCheck=true, ESPMaxDistance=1000,
        ESPBox=true, ESPBoxColor={255,60,60}, ESPBoxFilled=false,
        ESPBoxFillColor={255,60,60}, ESPBoxFillAlpha=20, ESPBoxThickness=2,
        ESPHealthBar=true, ESPHealthText=true,
        ESPHealthColor={0,255,100}, ESPHealthLow={255,60,60},
        ESPName=true, ESPNameColor={255,255,255},
        ESPDistance=true, ESPDistanceColor={220,220,220},
        ESPHeadDot=true, ESPHeadDotColor={255,255,255},
        ESPTracer=false, ESPTracerColor={255,60,60}, ESPTracerThick=2, ESPTracerAlpha=0.15,
        ESPTracerOrigin="Bottom",
        ESPSkeleton=false, ESPSkeletonColor={255,255,255},
        FovCircleEnabled=true,

        MoveSpeedEnabled=false, MoveSpeed=16, MoveSpeedKey="None",
        JumpPowerEnabled=false, JumpPower=50, JumpPowerKey="None",
        FlyEnabled=false, FlySpeed=50, FlyKey="F",
        NoclipEnabled=false, NoclipKey="N",
        InfiniteJumpEnabled=false, InfiniteJumpKey="Space",
        HipHeightEnabled=false, HipHeight=2, HipHeightKey="None",

        AntiFlingEnabled=false,
        AntiAfkEnabled=false,
        FullbrightEnabled=false,
        FpsBoostEnabled=false,

        MenuKeybind = "RightShift",
        ShowKeybinds = true,
        ShowUI = true,
        ShowThumbnail = true,
        ThumbnailPos = {20, 20},
    }
    local function C(t) return Color3.fromRGB(t[1],t[2],t[3]) end
    local hasDrawing = (typeof(Drawing) == "table") and Drawing.new ~= nil

    local ORIGINAL = { WalkSpeed=nil, HipHeight=nil, JumpPower=nil, UseJumpPower=nil }
    local hasRequest = (typeof(request) == "function") or (typeof(http_request) == "function")

    local LightStore = nil
    local function brightApply()
        if not LightStore then
            LightStore = {
                Lighting.Brightness, Lighting.ClockTime, Lighting.Ambient,
                Lighting.OutdoorAmbient, Lighting.FogEnd, Lighting.FogStart,
                Lighting.ExposureCompensation, Lighting.GlobalShadows
            }
        end
        pcall(function()
            Lighting.Brightness = math.max(Lighting.Brightness, 3)
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.new(1,1,1)
            Lighting.OutdoorAmbient = Color3.new(1,1,1)
            Lighting.FogStart = 1e6
            Lighting.FogEnd = 1e6
            Lighting.ExposureCompensation = 0
            Lighting.GlobalShadows = false
        end)
    end
    local function brightRestore()
        if LightStore then
            pcall(function()
                Lighting.Brightness, Lighting.ClockTime, Lighting.Ambient =
                    LightStore[1], LightStore[2], LightStore[3]
                Lighting.OutdoorAmbient, Lighting.FogEnd, Lighting.FogStart, Lighting.ExposureCompensation =
                    LightStore[4], LightStore[5], LightStore[6], LightStore[7]
                Lighting.GlobalShadows = LightStore[8]
            end)
            LightStore = nil
        end
    end

    local FpsStore = nil
    local FpsConn = nil
    local function fxKill(e, store)
        if store[e] ~= nil then return end
        if e:IsA("PostEffect") then
            if e.Enabled then e.Enabled = false; store[e] = {"en"} end
        elseif e:IsA("ParticleEmitter") or e:IsA("Trail") or e:IsA("Smoke")
            or e:IsA("Fire") or e:IsA("Sparkles") or e:IsA("Beam") then
            if e.Enabled then e.Enabled = false; store[e] = {"en"} end
        elseif e:IsA("Decal") or e:IsA("Texture") then
            store[e] = {"tr", e.Transparency}; e.Transparency = 1
        end
    end
    local function setFpsBoost(on)
        if on then
            FpsStore = {}
            pcall(function() Lighting.GlobalShadows = false end)
            FpsConn = workspace.DescendantAdded:Connect(function(e)
                if Config.FpsBoostEnabled and FpsStore then
                    task.defer(fxKill, e, FpsStore)
                end
            end)
            task.spawn(function()
                local s = FpsStore
                local n = 0
                for _, e in ipairs(Lighting:GetDescendants()) do fxKill(e, s) end
                for _, e in ipairs(workspace:GetDescendants()) do
                    if not Config.FpsBoostEnabled or FpsStore ~= s then return end
                    fxKill(e, s); n += 1
                    if n % 900 == 0 then RunService.Heartbeat:Wait() end
                end
            end)
        elseif FpsStore then
            local s = FpsStore
            FpsStore = nil
            if FpsConn then FpsConn:Disconnect(); FpsConn = nil end
            task.spawn(function()
                local n = 0
                for e, info in pairs(s) do
                    pcall(function()
                        if info[1] == "en" then e.Enabled = true
                        elseif info[1] == "tr" then e.Transparency = info[2] end
                    end)
                    n += 1
                    if n % 900 == 0 then RunService.Heartbeat:Wait() end
                end
            end)
        end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RadoHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 620, 0, 440)
    Main.Position = UDim2.new(0.5, -310, 0.5, -220)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 100, 180); MainStroke.Thickness = 1; MainStroke.Transparency = 0.3
    MainStroke.Parent = Main

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 34)
    Header.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    Header.BorderSizePixel = 0
    Header.Parent = Main
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

    local HeaderLbl = Instance.new("TextLabel")
    HeaderLbl.Size = UDim2.new(1, -320, 1, 0)
    HeaderLbl.Position = UDim2.new(0, 12, 0, 0)
    HeaderLbl.BackgroundTransparency = 1
    HeaderLbl.Text = "RadoHub  |  Universal  |  " .. tostring(game.GameId) ..
        "  |  " .. tostring(LocalPlayer.UserId) .. "  |  " .. EXECUTOR_NAME
    HeaderLbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    HeaderLbl.Font = Enum.Font.GothamBold
    HeaderLbl.TextSize = 12
    HeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
    HeaderLbl.TextTruncate = Enum.TextTruncate.AtEnd
    HeaderLbl.Parent = Header

    local HideChip = Instance.new("TextButton")
    HideChip.Size = UDim2.new(0, 90, 0, 20)
    HideChip.Position = UDim2.new(1, -222, 0, 7)
    HideChip.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    HideChip.BorderSizePixel = 0
    HideChip.Text = "Hide: " .. Config.MenuKeybind
    HideChip.TextColor3 = Color3.fromRGB(200, 200, 210)
    HideChip.Font = Enum.Font.Gotham
    HideChip.TextSize = 11
    HideChip.Parent = Header
    Instance.new("UICorner", HideChip).CornerRadius = UDim.new(0, 4)
    local HideChipStroke = Instance.new("UIStroke"); HideChipStroke.Color=Color3.fromRGB(70,70,90); HideChipStroke.Thickness=1; HideChipStroke.Parent = HideChip

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(0, 20, 0, 20)
    UnloadBtn.Position = UDim2.new(1, -28, 0, 7)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    UnloadBtn.BorderSizePixel = 0
    UnloadBtn.Text = "×"
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 14
    UnloadBtn.Parent = Header
    Instance.new("UICorner", UnloadBtn).CornerRadius = UDim.new(0, 5)

    local OpenBtn = Instance.new("TextButton")
    OpenBtn.Size = UDim2.new(0, 60, 0, 24)
    OpenBtn.Position = UDim2.new(0, 20, 0.5, -12)
    OpenBtn.BackgroundColor3 = Color3.fromRGB(50, 70, 120)
    OpenBtn.BorderSizePixel = 0
    OpenBtn.Text = "Rado"
    OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    OpenBtn.Font = Enum.Font.GothamBold
    OpenBtn.TextSize = 12
    OpenBtn.Visible = false
    OpenBtn.Active = true
    OpenBtn.Draggable = true
    OpenBtn.Parent = ScreenGui
    Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 5)

    local Thumb = Instance.new("Frame")
    Thumb.Size = UDim2.new(0, 260, 0, 26)
    Thumb.Position = UDim2.new(0, Config.ThumbnailPos[1], 0, Config.ThumbnailPos[2])
    Thumb.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    Thumb.BorderSizePixel = 0
    Thumb.Active = true
    Thumb.Draggable = true
    Thumb.Parent = ScreenGui
    Instance.new("UICorner", Thumb).CornerRadius = UDim.new(0, 6)
    local ThumbStroke = Instance.new("UIStroke")
    ThumbStroke.Color = Color3.fromRGB(60, 100, 180); ThumbStroke.Thickness = 1; ThumbStroke.Transparency = 0.3
    ThumbStroke.Parent = Thumb

    local ThumbGameName = "Unknown"
    pcall(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then ThumbGameName = info.Name end
    end)

    local ThumbLbl = Instance.new("TextLabel")
    ThumbLbl.Size = UDim2.new(1, -12, 1, 0)
    ThumbLbl.Position = UDim2.new(0, 8, 0, 0)
    ThumbLbl.BackgroundTransparency = 1
    ThumbLbl.Text = "RadoHub  |  " .. ThumbGameName .. "  |  " .. LocalPlayer.Name
    ThumbLbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    ThumbLbl.Font = Enum.Font.GothamBold
    ThumbLbl.TextSize = 11
    ThumbLbl.TextXAlignment = Enum.TextXAlignment.Left
    ThumbLbl.TextTruncate = Enum.TextTruncate.AtEnd
    ThumbLbl.Parent = Thumb

    Thumb.Changed:Connect(function(prop)
        if prop == "Position" then
            Config.ThumbnailPos = {Thumb.Position.X.Offset, Thumb.Position.Y.Offset}
        end
    end)

    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -16, 0, 26)
    TabBar.Position = UDim2.new(0, 8, 0, 40)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = Main

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 4)
    TabLayout.Parent = TabBar

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -78)
    Content.Position = UDim2.new(0, 8, 0, 70)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local pages = {}
    local function makeTab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 78, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(180, 180, 200)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.Parent = TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local page = Instance.new("Frame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = Content

        local scrollL = Instance.new("ScrollingFrame")
        scrollL.Size = UDim2.new(0.5, -5, 1, 0)
        scrollL.Position = UDim2.new(0, 0, 0, 0)
        scrollL.BackgroundTransparency = 1
        scrollL.BorderSizePixel = 0
        scrollL.ScrollBarThickness = 3
        scrollL.CanvasSize = UDim2.new(0, 0, 0, 1200)
        scrollL.Parent = page
        local layL = Instance.new("UIListLayout"); layL.Padding = UDim.new(0, 6); layL.SortOrder = Enum.SortOrder.LayoutOrder; layL.Parent = scrollL
        local padL = Instance.new("UIPadding"); padL.PaddingRight = UDim.new(0, 6); padL.Parent = scrollL

        local scrollR = Instance.new("ScrollingFrame")
        scrollR.Size = UDim2.new(0.5, -5, 1, 0)
        scrollR.Position = UDim2.new(0.5, 5, 0, 0)
        scrollR.BackgroundTransparency = 1
        scrollR.BorderSizePixel = 0
        scrollR.ScrollBarThickness = 3
        scrollR.CanvasSize = UDim2.new(0, 0, 0, 1200)
        scrollR.Parent = page
        local layR = Instance.new("UIListLayout"); layR.Padding = UDim.new(0, 6); layR.SortOrder = Enum.SortOrder.LayoutOrder; layR.Parent = scrollR

        pages[name] = {btn = btn, page = page, left = scrollL, right = scrollR}
        btn.MouseButton1Click:Connect(function()
            for _, d in pairs(pages) do
                d.page.Visible = false
                d.btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
                d.btn.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
            page.Visible = true
            btn.BackgroundColor3 = Color3.fromRGB(50, 70, 120)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)
        return scrollL, scrollR
    end

    local CombatL, CombatR = makeTab("Combat")
    local VisualL, VisualR = makeTab("Visuals")
    local PlayerL, PlayerR = makeTab("Player")
    local TeleportL, TeleportR = makeTab("Teleport")
    local SniperL, SniperR = makeTab("Sniper")
    local ConfigL, ConfigR = makeTab("Configs")

    for _, d in pairs(pages) do d.page.Visible = false end
    pages["Combat"].page.Visible = true
    pages["Combat"].btn.BackgroundColor3 = Color3.fromRGB(50, 70, 120)
    pages["Combat"].btn.TextColor3 = Color3.fromRGB(255, 255, 255)

    local UIREF = {toggles={}, sliders={}, dropdowns={}, chips={}}
    local function regToggle(k,o) UIREF.toggles[k]=o end
    local function regSlider(k,o) UIREF.sliders[k]=o end
    local function regDropdown(k,o) UIREF.dropdowns[k]=o end
    local function regChip(k,o) UIREF.chips[k]=o end

    local function section(parent, text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 22)
        f.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
        f.BorderSizePixel = 0
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 0, 12); bar.Position = UDim2.new(0, 6, 0.5, -6)
        bar.BackgroundColor3 = Color3.fromRGB(90, 130, 200); bar.BorderSizePixel = 0; bar.Parent = f
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -14, 1, 0); lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(190, 200, 220); lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
    end

    local allChips = {}
    local rebindChip = nil

    local function makeChip(parent, keyName)
        if not keyName then return nil end
        local chip = Instance.new("TextButton")
        chip.Size = UDim2.new(0, 60, 0, 18); chip.Position = UDim2.new(1, -66, 0.5, -9)
        chip.BackgroundColor3 = Color3.fromRGB(15, 15, 20); chip.BorderSizePixel = 0
        chip.Text = keyName; chip.TextColor3 = Color3.fromRGB(200, 200, 210)
        chip.Font = Enum.Font.Gotham; chip.TextSize = 11; chip.Parent = parent
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 3)
        local cs = Instance.new("UIStroke"); cs.Color = Color3.fromRGB(70,70,90); cs.Thickness = 1; cs.Parent = chip

        chip.MouseButton1Click:Connect(function()
            if rebindChip then return end
            rebindChip = chip
            chip.Text = "..."
        end)
        table.insert(allChips, chip)
        return chip
    end

    local function toggleRow(parent, text, default, keyName, keyConfigKey, toggleCallback)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 26)
        holder.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        holder.BorderSizePixel = 0
        holder.Parent = parent
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 4)

        local box = Instance.new("TextButton")
        box.Size = UDim2.new(0, 16, 0, 16); box.Position = UDim2.new(0, 6, 0.5, -8)
        box.BackgroundColor3 = default and Color3.fromRGB(70, 130, 220) or Color3.fromRGB(35, 35, 45)
        box.BorderSizePixel = 0; box.Text = ""; box.Parent = holder
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
        local bstroke = Instance.new("UIStroke"); bstroke.Color = Color3.fromRGB(90, 90, 110); bstroke.Thickness = 1; bstroke.Parent = box

        local check = Instance.new("TextLabel")
        check.Size = UDim2.new(1, 0, 1, 0); check.BackgroundTransparency = 1; check.Text = "✓"
        check.TextColor3 = Color3.fromRGB(255, 255, 255); check.Font = Enum.Font.GothamBold
        check.TextSize = 12; check.Visible = default; check.Parent = box

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -160, 1, 0); lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(225, 225, 230); lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = holder

        local chip
        if keyName ~= nil and keyName ~= "None" then
            chip = makeChip(holder, keyName)
            chip:SetAttribute("ConfigKey", keyConfigKey or text .. "Key")
        end

        local state = default
        local function set(v, silent)
            state = v
            box.BackgroundColor3 = state and Color3.fromRGB(70, 130, 220) or Color3.fromRGB(35, 35, 45)
            check.Visible = state
            if toggleCallback and not silent then toggleCallback(state) end
        end
        box.MouseButton1Click:Connect(function() set(not state) end)
        return {set = set, holder = holder, get = function() return state end}
    end

    local function sliderRow(parent, text, min, max, default, isInt, callback)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 40)
        holder.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        holder.BorderSizePixel = 0
        holder.Parent = parent
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 14); lbl.Position = UDim2.new(0, 6, 0, 2)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(170, 170, 185); lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = holder

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -12, 0, 16); bar.Position = UDim2.new(0, 6, 0, 18)
        bar.BackgroundColor3 = Color3.fromRGB(15, 15, 20); bar.BorderSizePixel = 0; bar.Parent = holder
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)
        local bstr = Instance.new("UIStroke"); bstr.Color = Color3.fromRGB(60,60,80); bstr.Thickness = 1; bstr.Parent = bar

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(50, 100, 220); fill.BorderSizePixel = 0; fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

        local fmt = isInt and "%d" or "%.2f"
        local valueLbl = Instance.new("TextLabel")
        valueLbl.Size = UDim2.new(1, -8, 1, 0); valueLbl.Position = UDim2.new(0, 4, 0, 0)
        valueLbl.BackgroundTransparency = 1
        valueLbl.Text = string.format(fmt, default) .. "  /  " .. string.format(fmt, max)
        valueLbl.TextColor3 = Color3.fromRGB(240, 240, 245); valueLbl.Font = Enum.Font.Gotham
        valueLbl.TextSize = 11; valueLbl.TextXAlignment = Enum.TextXAlignment.Center
        valueLbl.ZIndex = 2; valueLbl.Parent = bar

        local function setVal(v, silent)
            local rel = math.clamp((v - min) / (max - min), 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            valueLbl.Text = string.format(fmt, v) .. "  /  " .. string.format(fmt, max)
            if callback and not silent then callback(v) end
        end
        local dragging = false
        local function update(input)
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel
            if isInt then val = math.floor(val + 0.5) end
            setVal(val)
        end
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; update(i)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        return {set = setVal, holder = holder}
    end

    local function dropdown(parent, text, options, default, callback)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 42)
        holder.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        holder.BorderSizePixel = 0
        holder.Parent = parent
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 14); lbl.Position = UDim2.new(0, 6, 0, 2)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(170, 170, 185); lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = holder

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 20); btn.Position = UDim2.new(0, 6, 0, 18)
        btn.BackgroundColor3 = Color3.fromRGB(15, 15, 20); btn.BorderSizePixel = 0
        btn.Text = "  " .. tostring(default)
        btn.TextColor3 = Color3.fromRGB(230, 230, 235); btn.Font = Enum.Font.Gotham
        btn.TextSize = 11; btn.TextXAlignment = Enum.TextXAlignment.Left; btn.Parent = holder
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(60,60,80); bs.Thickness = 1; bs.Parent = btn

        local listOpen = false
        local listFrame
        local current = default
        local currentOptions = options

        local function close()
            if listFrame then listFrame:Destroy(); listFrame = nil end
            listOpen = false
        end

        local function open()
            if listOpen then return end
            listOpen = true
            local abs = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            listFrame = Instance.new("ScrollingFrame")
            listFrame.Name = "RadoDropdown_" .. text
            listFrame.Size = UDim2.fromOffset(math.max(absSize.X, 120),
                math.min(#currentOptions * 22 + 4, 200))
            listFrame.Position = UDim2.fromOffset(abs.X, abs.Y + absSize.Y + 2)
            listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            listFrame.BorderSizePixel = 0
            listFrame.ScrollBarThickness = 3
            listFrame.CanvasSize = UDim2.new(0, 0, 0, #currentOptions * 22)
            listFrame.ZIndex = 500
            listFrame.Parent = ScreenGui
            Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

            for i, opt in ipairs(currentOptions) do
                local ob = Instance.new("TextButton")
                ob.Size = UDim2.new(1, -4, 0, 20)
                ob.Position = UDim2.new(0, 2, 0, (i-1)*22 + 2)
                ob.BackgroundColor3 = (opt == current) and Color3.fromRGB(50, 70, 120) or Color3.fromRGB(30, 30, 40)
                ob.BorderSizePixel = 0
                ob.Text = opt
                ob.TextColor3 = (opt == current) and Color3.fromRGB(255,255,255) or Color3.fromRGB(220, 220, 230)
                ob.Font = Enum.Font.Gotham
                ob.TextSize = 11
                ob.ZIndex = 501
                ob.Parent = listFrame
                Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 3)
                ob.MouseEnter:Connect(function()
                    if opt ~= current then ob.BackgroundColor3 = Color3.fromRGB(45, 45, 60) end
                end)
                ob.MouseLeave:Connect(function()
                    if opt ~= current then ob.BackgroundColor3 = Color3.fromRGB(30, 30, 40) end
                end)
                ob.MouseButton1Click:Connect(function()
                    current = opt
                    btn.Text = "  " .. opt
                    close()
                    if callback then callback(opt) end
                end)
            end
        end

        btn.MouseButton1Click:Connect(function()
            if listOpen then close() else open() end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if not listOpen then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local pos = UserInputService:GetMouseLocation()
            task.defer(function()
                if not listFrame then return end
                local ap = listFrame.AbsolutePosition
                local as = listFrame.AbsoluteSize
                local inside = pos.X >= ap.X and pos.X <= ap.X + as.X
                    and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
                local bap = btn.AbsolutePosition
                local bas = btn.AbsoluteSize
                local onBtn = pos.X >= bap.X and pos.X <= bap.X + bas.X
                    and pos.Y >= bap.Y and pos.Y <= bap.Y + bas.Y
                if not inside and not onBtn then close() end
            end)
        end)

        return {
            set = function(v)
                current = v
                btn.Text = "  " .. tostring(v)
                if callback then callback(v) end
            end,
            refresh = function(newOptions, keepSelection)
                currentOptions = newOptions or {}
                if not keepSelection then
                    local found = false
                    for _, o in ipairs(currentOptions) do
                        if o == current then found = true break end
                    end
                    if not found then
                        current = currentOptions[1]
                        btn.Text = "  " .. tostring(current or "(none)")
                    end
                end
                if listOpen then close(); open() end
            end,
        }
    end

    local function button(parent, text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 28); btn.BackgroundColor3 = color or Color3.fromRGB(50, 70, 120)
        btn.BorderSizePixel = 0; btn.Text = text; btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end

    local function textbox(parent, default, placeholder, callback)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 26)
        box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        box.BorderSizePixel = 0
        box.Text = default or ""
        box.PlaceholderText = placeholder or ""
        box.TextColor3 = Color3.fromRGB(230,230,235)
        box.PlaceholderColor3 = Color3.fromRGB(120,120,140)
        box.Font = Enum.Font.Gotham
        box.TextSize = 12
        box.ClearTextOnFocus = false
        box.Parent = parent
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
        local s = Instance.new("UIStroke"); s.Color=Color3.fromRGB(60,60,80); s.Thickness=1; s.Parent=box
        if callback then box.FocusLost:Connect(function() callback(box.Text) end) end
        return box
    end

    --======================================================================
    -- COMBAT TAB
    --======================================================================
    section(CombatL, "Aimbot")
    regToggle("AimbotEnabled", toggleRow(CombatL, "Enabled", Config.AimbotEnabled, Config.AimbotKey, "AimbotKey", function(v) Config.AimbotEnabled=v end))
    regToggle("AimbotUseKey", toggleRow(CombatL, "Use Key", Config.AimbotUseKey, nil, nil, function(v) Config.AimbotUseKey=v end))
    regToggle("AimbotTeamCheck", toggleRow(CombatL, "Team Check", Config.AimbotTeamCheck, nil, nil, function(v) Config.AimbotTeamCheck=v end))
    regToggle("AimbotVisibleOnly", toggleRow(CombatL, "Visible Check", Config.AimbotVisibleOnly, nil, nil, function(v) Config.AimbotVisibleOnly=v end))
    regSlider("AimbotFOV", sliderRow(CombatL, "FOV", 10, 500, Config.AimbotFOV, true, function(v) Config.AimbotFOV=v end))
    regSlider("AimbotSmoothness", sliderRow(CombatL, "Smoothness", 0, 1, Config.AimbotSmoothness, false, function(v) Config.AimbotSmoothness=v end))
    regDropdown("AimbotPart", dropdown(CombatL, "Hitbox", {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, Config.AimbotPart, function(v) Config.AimbotPart=v end))

    section(CombatR, "Silent Aim")
    regToggle("SilentAimEnabled", toggleRow(CombatR, "Enabled", Config.SilentAimEnabled, Config.SilentAimKey, "SilentAimKey", function(v) Config.SilentAimEnabled=v end))
    regToggle("SilentAimUseKey", toggleRow(CombatR, "Use Key", Config.SilentAimUseKey, nil, nil, function(v) Config.SilentAimUseKey=v end))
    regToggle("SilentAimTeamCheck", toggleRow(CombatR, "Team Check", Config.SilentAimTeamCheck, nil, nil, function(v) Config.SilentAimTeamCheck=v end))
    regToggle("SilentAimVisibleOnly", toggleRow(CombatR, "Visible Check", Config.SilentAimVisibleOnly, nil, nil, function(v) Config.SilentAimVisibleOnly=v end))
    regSlider("SilentAimFOV", sliderRow(CombatR, "FOV", 10, 500, Config.SilentAimFOV, true, function(v) Config.SilentAimFOV=v end))
    regSlider("SilentAimHitChance", sliderRow(CombatR, "Hit Chance %", 0, 100, Config.SilentAimHitChance, true, function(v) Config.SilentAimHitChance=v end))
    regDropdown("SilentAimPart", dropdown(CombatR, "Hitbox", {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, Config.SilentAimPart, function(v) Config.SilentAimPart=v end))

    section(CombatL, "Trigger Bot")
    regToggle("TriggerBotEnabled", toggleRow(CombatL, "Enabled", Config.TriggerBotEnabled, Config.TriggerBotKey, "TriggerBotKey", function(v) Config.TriggerBotEnabled=v end))
    regToggle("TriggerBotTeamCheck", toggleRow(CombatL, "Team Check", Config.TriggerBotTeamCheck, nil, nil, function(v) Config.TriggerBotTeamCheck=v end))
    regToggle("TriggerBotVisibleOnly", toggleRow(CombatL, "Visible Check", Config.TriggerBotVisibleOnly, nil, nil, function(v) Config.TriggerBotVisibleOnly=v end))
    regSlider("TriggerBotDelay", sliderRow(CombatL, "Fire Delay", 0, 1, Config.TriggerBotDelay, false, function(v) Config.TriggerBotDelay=v end))
    regDropdown("TriggerBotPart", dropdown(CombatL, "Detect Part", {"Head","HumanoidRootPart","UpperTorso"}, Config.TriggerBotPart, function(v) Config.TriggerBotPart=v end))

    section(CombatR, "Hitbox Expander")
    regToggle("HitboxEnabled", toggleRow(CombatR, "Enabled", Config.HitboxEnabled, nil, nil, function(v) Config.HitboxEnabled=v end))
    regToggle("HitboxTeamCheck", toggleRow(CombatR, "Team Check", Config.HitboxTeamCheck, nil, nil, function(v) Config.HitboxTeamCheck=v end))
    regToggle("HitboxVisibleOnly", toggleRow(CombatR, "Visible Check", Config.HitboxVisibleOnly, nil, nil, function(v) Config.HitboxVisibleOnly=v end))
    regToggle("HitboxUseHead", toggleRow(CombatR, "Expand Head", Config.HitboxUseHead, nil, nil, function(v) Config.HitboxUseHead=v end))
    regToggle("HitboxUseHRP", toggleRow(CombatR, "Expand HumanoidRootPart", Config.HitboxUseHumanoidRootPart, nil, nil, function(v) Config.HitboxUseHumanoidRootPart=v end))
    regSlider("HitboxSize", sliderRow(CombatR, "Size (studs)", 1, 20, Config.HitboxSize, true, function(v) Config.HitboxSize=v end))
    regSlider("HitboxTransparency", sliderRow(CombatR, "Visual Transparency", 0, 1, Config.HitboxTransparency, false, function(v) Config.HitboxTransparency=v end))

    section(CombatR, "Projectile Prediction")
    regToggle("PredictionEnabled", toggleRow(CombatR, "Enabled", Config.PredictionEnabled, nil, nil, function(v) Config.PredictionEnabled=v end))
    regSlider("PredictionPing", sliderRow(CombatR, "Ping Offset (s)", 0, 0.3, Config.PredictionPing, false, function(v) Config.PredictionPing=v end))

    --======================================================================
    -- VISUALS TAB
    --======================================================================
    section(VisualL, "ESP")
    regToggle("ESPEnabled", toggleRow(VisualL, "Enabled", Config.ESPEnabled, "None", nil, function(v) Config.ESPEnabled=v end))
    regToggle("ESPTeamCheck", toggleRow(VisualL, "Team Check", Config.ESPTeamCheck, nil, nil, function(v) Config.ESPTeamCheck=v end))
    regSlider("ESPMaxDistance", sliderRow(VisualL, "Max Distance", 50, 5000, Config.ESPMaxDistance, true, function(v) Config.ESPMaxDistance=v end))
    regToggle("FovCircleEnabled", toggleRow(VisualL, "Show FOV Circle", Config.FovCircleEnabled, nil, nil, function(v) Config.FovCircleEnabled=v end))

    section(VisualL, "ESP — Box")
    regToggle("ESPBox", toggleRow(VisualL, "Show Box", Config.ESPBox, nil, nil, function(v) Config.ESPBox=v end))
    regToggle("ESPBoxFilled", toggleRow(VisualL, "Box Filled", Config.ESPBoxFilled, nil, nil, function(v) Config.ESPBoxFilled=v end))
    regSlider("ESPBoxThickness", sliderRow(VisualL, "Box Thickness", 1, 5, Config.ESPBoxThickness, true, function(v) Config.ESPBoxThickness=v end))
    regSlider("ESPBoxFillAlpha", sliderRow(VisualL, "Box Fill Alpha", 0, 100, Config.ESPBoxFillAlpha, true, function(v) Config.ESPBoxFillAlpha=v end))

    section(VisualR, "ESP — Info")
    regToggle("ESPHealthBar", toggleRow(VisualR, "Show Health Bar", Config.ESPHealthBar, nil, nil, function(v) Config.ESPHealthBar=v end))
    regToggle("ESPHealthText", toggleRow(VisualR, "Show Health Text", Config.ESPHealthText, nil, nil, function(v) Config.ESPHealthText=v end))
    regToggle("ESPName", toggleRow(VisualR, "Show Name", Config.ESPName, nil, nil, function(v) Config.ESPName=v end))
    regToggle("ESPDistance", toggleRow(VisualR, "Show Distance", Config.ESPDistance, nil, nil, function(v) Config.ESPDistance=v end))
    regToggle("ESPHeadDot", toggleRow(VisualR, "Show Head Dot", Config.ESPHeadDot, nil, nil, function(v) Config.ESPHeadDot=v end))

    section(VisualR, "ESP — Tracer")
    regToggle("ESPTracer", toggleRow(VisualR, "Show Tracer", Config.ESPTracer, nil, nil, function(v) Config.ESPTracer=v end))
    regSlider("ESPTracerThick", sliderRow(VisualR, "Tracer Thickness", 1, 6, Config.ESPTracerThick, true, function(v) Config.ESPTracerThick=v end))
    regSlider("ESPTracerAlpha", sliderRow(VisualR, "Tracer Alpha", 0, 1, Config.ESPTracerAlpha, false, function(v) Config.ESPTracerAlpha=v end))
    regDropdown("ESPTracerOrigin", dropdown(VisualR, "Tracer Origin",
        {"Bottom","Bottom Left","Bottom Right","Top","Center","Mouse"},
        Config.ESPTracerOrigin, function(v) Config.ESPTracerOrigin=v end))

    section(VisualR, "ESP — Skeleton")
    regToggle("ESPSkeleton", toggleRow(VisualR, "Show Skeleton", Config.ESPSkeleton, nil, nil, function(v) Config.ESPSkeleton=v end))

    section(VisualL, "World & Render")
    regToggle("FullbrightEnabled", toggleRow(VisualL, "Fullbright", Config.FullbrightEnabled, nil, nil, function(v)
        Config.FullbrightEnabled = v
        if v then brightApply() else brightRestore() end
    end))
    regToggle("FpsBoostEnabled", toggleRow(VisualL, "FPS Boost", Config.FpsBoostEnabled, nil, nil, function(v)
        Config.FpsBoostEnabled = v
        setFpsBoost(v)
    end))

    --======================================================================
    -- PLAYER TAB
    --======================================================================
    local walkSpeedSlider, jumpPowerSlider, flySpeedSlider, hipHeightSlider

    section(PlayerL, "Movement")
    regToggle("MoveSpeedEnabled", toggleRow(PlayerL, "WalkSpeed", Config.MoveSpeedEnabled, "None", "MoveSpeedKey", function(v)
        Config.MoveSpeedEnabled = v
        walkSpeedSlider.holder.Visible = v
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = ORIGINAL.WalkSpeed or 16 end
        end
    end))
    walkSpeedSlider = sliderRow(PlayerL, "Speed", 8, 500, Config.MoveSpeed, true, function(v) Config.MoveSpeed=v end)
    walkSpeedSlider.holder.Visible = Config.MoveSpeedEnabled
    regSlider("MoveSpeed", walkSpeedSlider)

    regToggle("JumpPowerEnabled", toggleRow(PlayerL, "JumpPower", Config.JumpPowerEnabled, "None", "JumpPowerKey", function(v)
        Config.JumpPowerEnabled = v
        jumpPowerSlider.holder.Visible = v
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if ORIGINAL.UseJumpPower ~= nil then hum.UseJumpPower = ORIGINAL.UseJumpPower end
                hum.JumpPower = ORIGINAL.JumpPower or 50
            end
        end
    end))
    jumpPowerSlider = sliderRow(PlayerL, "Jump Power", 50, 250, Config.JumpPower, true, function(v) Config.JumpPower=v end)
    jumpPowerSlider.holder.Visible = Config.JumpPowerEnabled
    regSlider("JumpPower", jumpPowerSlider)

    regToggle("FlyEnabled", toggleRow(PlayerL, "Fly", Config.FlyEnabled, Config.FlyKey, "FlyKey", function(v)
        Config.FlyEnabled = v
        flySpeedSlider.holder.Visible = v
        if not v and _G.__RadoHubStopFly then _G.__RadoHubStopFly() end
    end))
    flySpeedSlider = sliderRow(PlayerL, "Fly Speed", 10, 500, Config.FlySpeed, true, function(v) Config.FlySpeed=v end)
    flySpeedSlider.holder.Visible = Config.FlyEnabled
    regSlider("FlySpeed", flySpeedSlider)

    regToggle("NoclipEnabled", toggleRow(PlayerL, "Noclip", Config.NoclipEnabled, Config.NoclipKey, "NoclipKey", function(v)
        Config.NoclipEnabled = v
        if not v then
            local char = LocalPlayer.Character
            if char then for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end end
        end
    end))

    section(PlayerR, "Extras")
    regToggle("InfiniteJumpEnabled", toggleRow(PlayerR, "Infinite Jump", Config.InfiniteJumpEnabled, Config.InfiniteJumpKey, "InfiniteJumpKey", function(v) Config.InfiniteJumpEnabled=v end))

    regToggle("HipHeightEnabled", toggleRow(PlayerR, "Custom Hip Height", Config.HipHeightEnabled, "None", "HipHeightKey", function(v)
        Config.HipHeightEnabled = v
        hipHeightSlider.holder.Visible = v
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.HipHeight = ORIGINAL.HipHeight or 2 end
        end
    end))
    hipHeightSlider = sliderRow(PlayerR, "Hip Height", -5, 20, Config.HipHeight, false, function(v) Config.HipHeight=v end)
    hipHeightSlider.holder.Visible = Config.HipHeightEnabled
    regSlider("HipHeight", hipHeightSlider)

    section(PlayerR, "Safety")
    regToggle("AntiFlingEnabled", toggleRow(PlayerR, "Anti-Fling", Config.AntiFlingEnabled, nil, nil, function(v)
        Config.AntiFlingEnabled = v
        if not v and _G.__RadoHubAntiFlingStop then _G.__RadoHubAntiFlingStop() end
    end))
    regToggle("AntiAfkEnabled", toggleRow(PlayerR, "Anti-AFK", Config.AntiAfkEnabled, nil, nil, function(v) Config.AntiAfkEnabled = v end))

    --======================================================================
    -- TELEPORT TAB
    --======================================================================
    local tpTargetList = function()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then t[#t+1] = p.Name end
        end
        if #t == 0 then t[1] = "(no other players)" end
        return t
    end

    local function resolvePlayer(name)
        if not name or name == "" or name == "(no other players)" then return nil end
        local p = Players:FindFirstChild(name)
        if p then return p end
        local lname = name:lower()
        for _, q in ipairs(Players:GetPlayers()) do
            if q.Name:lower() == lname or (q.DisplayName or ""):lower() == lname then return q end
        end
        return nil
    end

    section(TeleportL, "Player Actions")
    local tpSelected = nil
    regDropdown("TpTarget", dropdown(TeleportL, "Target", tpTargetList(), "(none)", function(v) tpSelected = v end))

    button(TeleportL, "Teleport To Player", Color3.fromRGB(60, 100, 180), function()
        local p = resolvePlayer(tpSelected)
        if not p then return warn("[RadoHub] Pick a valid player") end
        local ch = p.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return warn("[RadoHub] That player has no character") end
        local myCh = LocalPlayer.Character
        local myHrp = myCh and myCh:FindFirstChild("HumanoidRootPart")
        if not myHrp then return warn("[RadoHub] You have no character") end
        myHrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
        myHrp.AssemblyLinearVelocity = Vector3.zero
    end)

    button(TeleportL, "Refresh Player List", Color3.fromRGB(60, 60, 90), function()
        if UIREF.dropdowns.TpTarget and UIREF.dropdowns.TpTarget.refresh then
            UIREF.dropdowns.TpTarget.refresh(tpTargetList(), true)
            print("[RadoHub] Player list refreshed")
        end
    end)

    Players.PlayerAdded:Connect(function()
        task.defer(function()
            if UIREF.dropdowns.TpTarget and UIREF.dropdowns.TpTarget.refresh then
                UIREF.dropdowns.TpTarget.refresh(tpTargetList(), true)
            end
        end)
    end)
    Players.PlayerRemoving:Connect(function()
        task.defer(function()
            if UIREF.dropdowns.TpTarget and UIREF.dropdowns.TpTarget.refresh then
                UIREF.dropdowns.TpTarget.refresh(tpTargetList(), true)
            end
        end)
    end)

    section(TeleportR, "Server Actions")
    button(TeleportR, "Rejoin Server", Color3.fromRGB(60, 100, 180), function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)

    button(TeleportR, "Server Hop", Color3.fromRGB(0, 130, 80), function()
        task.spawn(function()
            local ok, res = pcall(function()
                return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId ..
                    "/servers/Public?sortOrder=Desc&limit=100")
            end)
            if not ok then return warn("[RadoHub] Server list failed") end
            local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
            if not ok2 or not data or not data.data then return warn("[RadoHub] Bad server data") end
            local candidates = {}
            for _, sv in ipairs(data.data) do
                if sv.id ~= game.JobId and ((sv.maxPlayers or 0) - (sv.playing or 0)) >= 2 then
                    table.insert(candidates, sv)
                end
            end
            if #candidates == 0 then return warn("[RadoHub] No servers with room") end
            local chosen = candidates[math.random(1, math.min(#candidates, 5))]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
            end)
        end)
    end)

    --======================================================================
    -- SNIPER TAB
    --======================================================================
    section(SniperL, "User Lookup")

    local sniperUserBox = textbox(SniperL, "", "Username...", nil)

    local SniperTargetId = nil
    local SniperProfileFrame = Instance.new("Frame")
    SniperProfileFrame.Size = UDim2.new(1, 0, 0, 130)
    SniperProfileFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    SniperProfileFrame.BorderSizePixel = 0
    SniperProfileFrame.Parent = SniperL
    Instance.new("UICorner", SniperProfileFrame).CornerRadius = UDim.new(0, 6)

    local SniperAvatar = Instance.new("ImageLabel")
    SniperAvatar.Size = UDim2.fromOffset(64, 64)
    SniperAvatar.Position = UDim2.fromOffset(10, 10)
    SniperAvatar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    SniperAvatar.BorderSizePixel = 0
    SniperAvatar.ScaleType = Enum.ScaleType.Fit
    SniperAvatar.Parent = SniperProfileFrame
    Instance.new("UICorner", SniperAvatar).CornerRadius = UDim.new(0, 6)

    local SniperName = Instance.new("TextLabel")
    SniperName.Size = UDim2.new(1, -90, 0, 16)
    SniperName.Position = UDim2.fromOffset(84, 10)
    SniperName.BackgroundTransparency = 1
    SniperName.Text = "@ -"
    SniperName.TextColor3 = Color3.fromRGB(255, 255, 255)
    SniperName.Font = Enum.Font.GothamBold
    SniperName.TextSize = 13
    SniperName.TextXAlignment = Enum.TextXAlignment.Left
    SniperName.Parent = SniperProfileFrame

    local SniperDisplay = Instance.new("TextLabel")
    SniperDisplay.Size = UDim2.new(1, -90, 0, 14)
    SniperDisplay.Position = UDim2.fromOffset(84, 28)
    SniperDisplay.BackgroundTransparency = 1
    SniperDisplay.Text = ""
    SniperDisplay.TextColor3 = Color3.fromRGB(160, 160, 175)
    SniperDisplay.Font = Enum.Font.Gotham
    SniperDisplay.TextSize = 11
    SniperDisplay.TextXAlignment = Enum.TextXAlignment.Left
    SniperDisplay.Parent = SniperProfileFrame

    local SniperJoined = Instance.new("TextLabel")
    SniperJoined.Size = UDim2.new(1, -90, 0, 14)
    SniperJoined.Position = UDim2.fromOffset(84, 44)
    SniperJoined.BackgroundTransparency = 1
    SniperJoined.Text = ""
    SniperJoined.TextColor3 = Color3.fromRGB(160, 160, 175)
    SniperJoined.Font = Enum.Font.Gotham
    SniperJoined.TextSize = 11
    SniperJoined.TextXAlignment = Enum.TextXAlignment.Left
    SniperJoined.Parent = SniperProfileFrame

    local SniperPresence = Instance.new("TextLabel")
    SniperPresence.Size = UDim2.new(1, -20, 0, 60)
    SniperPresence.Position = UDim2.fromOffset(10, 78)
    SniperPresence.BackgroundTransparency = 1
    SniperPresence.Text = ""
    SniperPresence.TextColor3 = Color3.fromRGB(120, 165, 255)
    SniperPresence.Font = Enum.Font.Gotham
    SniperPresence.TextSize = 11
    SniperPresence.TextXAlignment = Enum.TextXAlignment.Left
    SniperPresence.TextYAlignment = Enum.TextYAlignment.Top
    SniperPresence.TextWrapped = true
    SniperPresence.Parent = SniperProfileFrame

    local function httpRequest(opts)
        local fn = request or http_request
        if not fn then return nil end
        local ok, res = pcall(fn, opts)
        if ok then return res end
        return nil
    end

    local function sniperLookup()
        local name = sniperUserBox.Text:gsub("%s+", "")
        if name == "" then
            SniperPresence.Text = "Enter a username first."
            return
        end
        SniperPresence.Text = "Searching..."
        task.spawn(function()
            local ok, uid = pcall(function()
                return Players:GetUserIdFromNameAsync(name)
            end)
            if not ok or not uid then
                SniperPresence.Text = "User not found."
                return
            end
            SniperTargetId = uid

            local profileRes = httpRequest({
                Url = "https://users.roblox.com/v1/users/" .. tostring(uid),
                Method = "GET",
            })
            if profileRes and profileRes.Body then
                local ok2, info = pcall(function() return HttpService:JSONDecode(profileRes.Body) end)
                if ok2 and info then
                    SniperDisplay.Text = info.displayName or ""
                    SniperJoined.Text = "Joined " .. ((info.created and info.created:sub(1, 10)) or "?")
                end
            end

            local okThumb, thumb = pcall(function()
                return Players:GetUserThumbnailAsync(uid,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
            if okThumb and thumb then SniperAvatar.Image = thumb end

            SniperName.Text = "@" .. name

            local presenceRes = httpRequest({
                Url = "https://presence.roblox.com/v1/presence/users",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({userIds = {uid}}),
            })
            if presenceRes and presenceRes.Body then
                local okP, pdata = pcall(function() return HttpService:JSONDecode(presenceRes.Body) end)
                if okP and pdata and pdata.userPresences and pdata.userPresences[1] then
                    local p = pdata.userPresences[1]
                    local typeNames = {[0]="Offline", [1]="Online (web)", [2]="In game", [3]="In Studio", [4]="Invisible"}
                    local label = typeNames[p.userPresenceType] or "Unknown"
                    if p.userPresenceType == 2 then
                        local loc = (p.lastLocation and p.lastLocation ~= "") and p.lastLocation or "Unknown game"
                        SniperPresence.Text = "Playing: " .. loc .. "\nPlaceId: " .. tostring(p.placeId) ..
                            "  |  GameId: " .. tostring(p.gameId or "?")
                    else
                        SniperPresence.Text = "Status: " .. label
                    end
                else
                    SniperPresence.Text = "Presence lookup failed. Make sure your executor sends cookies."
                end
            else
                SniperPresence.Text = "Presence request failed."
            end
        end)
    end

    button(SniperL, "Lookup User", Color3.fromRGB(60, 100, 180), sniperLookup)
    sniperUserBox.FocusLost:Connect(function(enter) if enter then sniperLookup() end end)

    section(SniperR, "Join")
    button(SniperR, "Join Their Server", Color3.fromRGB(0, 130, 80), function()
        if not SniperTargetId then
            SniperPresence.Text = "Look up a user first."
            return
        end
        SniperPresence.Text = "Fetching presence..."
        task.spawn(function()
            local presenceRes = httpRequest({
                Url = "https://presence.roblox.com/v1/presence/users",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({userIds = {SniperTargetId}}),
            })
            if not presenceRes or not presenceRes.Body then
                SniperPresence.Text = "Presence request failed."
                return
            end
            local okP, pdata = pcall(function() return HttpService:JSONDecode(presenceRes.Body) end)
            if not okP or not pdata.userPresences or not pdata.userPresences[1] then
                SniperPresence.Text = "Bad presence data."
                return
            end
            local p = pdata.userPresences[1]
            if p.userPresenceType ~= 2 then
                SniperPresence.Text = "User is not in a joinable game."
                return
            end
            if not p.placeId then
                SniperPresence.Text = "No placeId in presence."
                return
            end

            SniperPresence.Text = "Trying to join " .. tostring(p.placeId) .. "..."
            local joined = pcall(function()
                TeleportService:Teleport(p.placeId, LocalPlayer)
            end)
            if not joined then
                SniperPresence.Text = "Teleport failed. Game may be private or full."
            end
        end)
    end)

    button(SniperR, "Copy Their PlaceId", Color3.fromRGB(60, 60, 90), function()
        local txt = SniperPresence.Text
        local pid = txt:match("PlaceId: (%d+)")
        if pid and typeof(setclipboard) == "function" then
            pcall(setclipboard, pid)
            SniperPresence.Text = "Copied PlaceId: " .. pid
        end
    end)

    --======================================================================
    -- CONFIGS TAB
    --======================================================================
    section(ConfigL, "Key")

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(1, 0, 0, 42)
    keyLabel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    keyLabel.BorderSizePixel = 0
    keyLabel.Text = ""
    keyLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    keyLabel.Font = Enum.Font.Gotham
    keyLabel.TextSize = 11
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.TextYAlignment = Enum.TextYAlignment.Top
    keyLabel.TextWrapped = true
    keyLabel.Parent = ConfigL
    Instance.new("UICorner", keyLabel).CornerRadius = UDim.new(0, 4)
    local keyLabelPad = Instance.new("UIPadding")
    keyLabelPad.PaddingLeft = UDim.new(0, 8)
    keyLabelPad.PaddingTop = UDim.new(0, 6)
    keyLabelPad.PaddingRight = UDim.new(0, 6)
    keyLabelPad.Parent = keyLabel

    local function fmtDuration(secs)
        if secs <= 0 then return "expired" end
        local days = math.floor(secs / 86400)
        local hours = math.floor((secs % 86400) / 3600)
        local mins = math.floor((secs % 3600) / 60)
        if days > 0 then
            return string.format("%dd %dh %dm", days, hours, mins)
        elseif hours > 0 then
            return string.format("%dh %dm", hours, mins)
        else
            return string.format("%dm %ds", mins, math.floor(secs % 60))
        end
    end

    local function updateKeyLabel()
        if keyExpiresAt == 0 then
            keyLabel.Text = "Type: Lifetime key\nExpires: never"
            keyLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
            return
        end
        local remaining = keyExpiresAt - os.time()
        if remaining <= 0 then
            keyLabel.Text = "Type: Time-limited key\nStatus: EXPIRED — restart the script to re-enter a key"
            keyLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        else
            keyLabel.Text = "Type: Time-limited key\nRemaining: " .. fmtDuration(remaining) ..
                "  (" .. os.date("%Y-%m-%d %H:%M", keyExpiresAt) .. ")"
            if remaining < 86400 then
                keyLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                keyLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
            end
        end
    end

    updateKeyLabel()
    task.spawn(function()
        while _G.__RadoHubLoaded do
            updateKeyLabel()
            task.wait(1)
        end
    end)

    section(ConfigL, "Interface")
    regToggle("ShowUI", toggleRow(ConfigL, "Show UI", Config.ShowUI, nil, nil, function(v)
        Config.ShowUI = v
        Main.Visible = v
        OpenBtn.Visible = not v
    end))
    regToggle("ShowThumbnail", toggleRow(ConfigL, "Show Thumbnail", Config.ShowThumbnail, nil, nil, function(v)
        Config.ShowThumbnail = v
        Thumb.Visible = v
    end))
    regToggle("ShowKeybinds", toggleRow(ConfigL, "Show Keybinds", Config.ShowKeybinds, nil, nil, function(v)
        Config.ShowKeybinds = v
        for _, chip in ipairs(allChips) do chip.Visible = v end
        HideChip.Visible = v
    end))

    section(ConfigL, "Config Files")
    local selectedConfig = nil

    local function saveConfig(name)
        if not hasFileIO then warn("No file IO") return end
        if not name or name == "" then warn("Select or create a config first") return end
        ensureFolder()
        local ok, enc = pcall(function() return HttpService:JSONEncode(Config) end)
        if ok then pcall(function() writefile(CONFIG_FOLDER.."/"..name..".json", enc) end); print("Saved "..name) end
    end

    local function loadConfig(name)
        if not hasFileIO then warn("No file IO") return end
        if not name or name == "" then warn("Select a config") return end
        ensureFolder()
        local ok, data = pcall(function() return readfile(CONFIG_FOLDER.."/"..name..".json") end)
        if not ok or not data then warn("Not found") return end
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
        if not ok2 then warn("Corrupt") return end
        for k,v in pairs(decoded) do if Config[k] ~= nil then Config[k] = v end end
        for k,o in pairs(UIREF.toggles) do if Config[k] ~= nil then o.set(Config[k], true) end end
        for k,o in pairs(UIREF.sliders) do if Config[k] ~= nil then o.set(Config[k], true) end end
        for k,o in pairs(UIREF.dropdowns) do if Config[k] ~= nil then o.set(Config[k]) end end
        walkSpeedSlider.holder.Visible = Config.MoveSpeedEnabled
        jumpPowerSlider.holder.Visible = Config.JumpPowerEnabled
        flySpeedSlider.holder.Visible = Config.FlyEnabled
        hipHeightSlider.holder.Visible = Config.HipHeightEnabled
        Main.Visible = Config.ShowUI
        OpenBtn.Visible = not Config.ShowUI
        Thumb.Visible = Config.ShowThumbnail
        for _, chip in ipairs(allChips) do chip.Visible = Config.ShowKeybinds end
        if Config.ThumbnailPos then
            Thumb.Position = UDim2.new(0, Config.ThumbnailPos[1], 0, Config.ThumbnailPos[2])
        end
        print("Loaded "..name)
    end

    local function deleteConfig(name)
        if not hasFileIO then return end
        if not name or name == "" then return end
        ensureFolder()
        pcall(function() delfile(CONFIG_FOLDER.."/"..name..".json") end)
        print("Deleted "..name)
    end

    local newNameBox = textbox(ConfigL, "", "new config name...", nil)

    button(ConfigL, "Create New Config", Color3.fromRGB(60, 100, 180), function()
        local nm = newNameBox.Text
        if nm and nm ~= "" then
            saveConfig(nm)
            newNameBox.Text = ""
            selectedConfig = nm
            if _G.__RadoHubRefreshConfigs then _G.__RadoHubRefreshConfigs() end
        end
    end)

    section(ConfigR, "Saved Configs (click to select)")

    local ConfigListFrame = Instance.new("ScrollingFrame")
    ConfigListFrame.Size = UDim2.new(1, 0, 0, 140)
    ConfigListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    ConfigListFrame.BorderSizePixel = 0
    ConfigListFrame.ScrollBarThickness = 3
    ConfigListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ConfigListFrame.Parent = ConfigR
    Instance.new("UICorner", ConfigListFrame).CornerRadius = UDim.new(0, 4)
    local cfgListLayout = Instance.new("UIListLayout")
    cfgListLayout.Padding = UDim.new(0, 2); cfgListLayout.Parent = ConfigListFrame
    local cfgPad = Instance.new("UIPadding"); cfgPad.PaddingTop = UDim.new(0,4); cfgPad.PaddingLeft=UDim.new(0,4); cfgPad.PaddingRight=UDim.new(0,4); cfgPad.Parent = ConfigListFrame

    local cfgButtons = {}
    local function refreshConfigList()
        for _, b in ipairs(cfgButtons) do b:Destroy() end
        cfgButtons = {}
        if not hasFileIO then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -8, 0, 24); lbl.BackgroundTransparency = 1
            lbl.Text = "(no file IO support)"; lbl.TextColor3 = Color3.fromRGB(200,200,200)
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.Parent = ConfigListFrame
            table.insert(cfgButtons, lbl)
            return
        end
        ensureFolder()
        local files = {}
        local ok, fs = pcall(function() return listfiles(CONFIG_FOLDER) end)
        if ok and fs then
            for _, p in ipairs(fs) do local n = p:match("([^/\\]+)%.json$"); if n then table.insert(files, n) end end
        end
        if #files == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -8, 0, 24); lbl.BackgroundTransparency = 1
            lbl.Text = "(no configs yet)"; lbl.TextColor3 = Color3.fromRGB(150,150,160)
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.Parent = ConfigListFrame
            table.insert(cfgButtons, lbl)
            return
        end
        for _, name in ipairs(files) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 24); b.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
            b.BorderSizePixel = 0; b.Text = "  " .. name
            b.TextColor3 = Color3.fromRGB(220, 220, 230)
            b.Font = Enum.Font.Gotham; b.TextSize = 12
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Parent = ConfigListFrame
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
            b.MouseButton1Click:Connect(function()
                selectedConfig = name
                for _, other in ipairs(cfgButtons) do
                    if other:IsA("TextButton") then
                        other.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
                        other.TextColor3 = Color3.fromRGB(220, 220, 230)
                    end
                end
                b.BackgroundColor3 = Color3.fromRGB(50, 70, 120)
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
            end)
            table.insert(cfgButtons, b)
        end
        ConfigListFrame.CanvasSize = UDim2.new(0, 0, 0, #files * 26 + 8)
    end
    refreshConfigList()
    _G.__RadoHubRefreshConfigs = refreshConfigList

    local selLabel = Instance.new("TextLabel")
    selLabel.Size = UDim2.new(1, 0, 0, 20); selLabel.BackgroundTransparency = 1
    selLabel.Text = "Selected: (none)"; selLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
    selLabel.Font = Enum.Font.Gotham; selLabel.TextSize = 11
    selLabel.TextXAlignment = Enum.TextXAlignment.Left; selLabel.Parent = ConfigL

    task.spawn(function()
        while _G.__RadoHubLoaded do
            selLabel.Text = "Selected: " .. (selectedConfig or "(none)")
            task.wait(0.25)
        end
    end)

    button(ConfigL, "Load Selected", Color3.fromRGB(60, 100, 180), function() loadConfig(selectedConfig) end)
    button(ConfigL, "Overwrite Selected", Color3.fromRGB(0, 130, 80), function() saveConfig(selectedConfig) end)
    button(ConfigL, "Delete Selected", Color3.fromRGB(150, 60, 60), function()
        deleteConfig(selectedConfig); selectedConfig = nil; refreshConfigList()
    end)

    --======================================================================
    -- ESP DRAWING
    --======================================================================
    local espData = {}
    local connections = {}
    local addConn = function(c) table.insert(connections, c); return c end
    local function newDraw(c) if not hasDrawing then return nil end local ok,o=pcall(Drawing.new,c); if ok then return o end return nil end

    local function createESPSet()
        local d = {}
        d.boxFill  = newDraw("Square")
        d.bTop     = newDraw("Square")
        d.bBottom  = newDraw("Square")
        d.bLeft    = newDraw("Square")
        d.bRight   = newDraw("Square")
        d.healthBG = newDraw("Square")
        d.healthBar= newDraw("Square")
        d.name     = newDraw("Text")
        d.distance = newDraw("Text")
        d.healthText=newDraw("Text")
        d.tracer   = newDraw("Line")
        d.headDot  = newDraw("Circle")
        d.sk1      = newDraw("Line")
        d.sk2      = newDraw("Line")
        d.sk3      = newDraw("Line")
        d.sk4      = newDraw("Line")
        d.sk5      = newDraw("Line")

        if d.boxFill then d.boxFill.Filled = true; d.boxFill.Thickness = 1; d.boxFill.Visible = false end
        for _, k in ipairs({"bTop","bBottom","bLeft","bRight"}) do
            local r = d[k]; if r then r.Filled = true; r.Thickness = 1; r.Visible = false end
        end
        if d.healthBG then d.healthBG.Filled=true;d.healthBG.Color=Color3.new(0,0,0);d.healthBG.Transparency=0.4;d.healthBG.Visible=false end
        if d.healthBar then d.healthBar.Filled=true;d.healthBar.Visible=false end
        if d.name then d.name.Center=true;d.name.Outline=true;d.name.Size=14;d.name.Visible=false end
        if d.distance then d.distance.Center=true;d.distance.Outline=true;d.distance.Size=13;d.distance.Visible=false end
        if d.healthText then d.healthText.Center=true;d.healthText.Outline=true;d.healthText.Size=13;d.healthText.Visible=false end
        if d.tracer then d.tracer.Thickness=2;d.tracer.Transparency=0.15;d.tracer.Visible=false end
        if d.headDot then d.headDot.Filled=true;d.headDot.Radius=3;d.headDot.Visible=false end
        for _, k in ipairs({"sk1","sk2","sk3","sk4","sk5"}) do
            local l = d[k]; if l then l.Thickness=2; l.Visible=false end
        end
        return d
    end
    local function destroyESPSet(d) for _,o in pairs(d) do if o and o.Remove then pcall(function() o:Remove() end) end end end
    local function hideESPSet(d) for _,o in pairs(d) do if o then pcall(function() o.Visible=false end) end end end

    local function setupPlayer(p) if p==LocalPlayer then return end if espData[p] then return end espData[p]=createESPSet() end
    local function removePlayer(p) if espData[p] then destroyESPSet(espData[p]); espData[p]=nil end end
    if hasDrawing then
        for _,p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
        addConn(Players.PlayerAdded:Connect(setupPlayer))
        addConn(Players.PlayerRemoving:Connect(removePlayer))
    end

    local function getBox(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not head or not hum then return nil end
        local hrpPos = Camera:WorldToViewportPoint(hrp.Position)
        if hrpPos.Z <= 0 then return nil end
        local topWorld = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.4, 0)
        local bottomWorld = hrp.Position - Vector3.new(0, hum.HipHeight + 0.9, 0)
        local topS = Camera:WorldToViewportPoint(topWorld)
        local botS = Camera:WorldToViewportPoint(bottomWorld)
        local topY, botY = topS.Y, botS.Y
        if topY > botY then topY, botY = botY, topY end
        local h = botY - topY
        if h < 5 then return nil end
        local w = h * 0.55
        return {
            x = hrpPos.X - w/2, y = topY, w = w, h = h,
            cx = hrpPos.X, cy = (topY + botY) / 2,
            top = topY, bottom = botY,
            left = hrpPos.X - w/2, right = hrpPos.X + w/2,
        }, hum, head
    end

    local function tracerOrigin()
        local vp = Camera.ViewportSize
        local from = Config.ESPTracerOrigin
        if from == "Top" then return Vector2.new(vp.X*0.5, 0) end
        if from == "Center" then return Vector2.new(vp.X*0.5, vp.Y*0.5) end
        if from == "Bottom Left" then return Vector2.new(0, vp.Y) end
        if from == "Bottom Right" then return Vector2.new(vp.X, vp.Y) end
        if from == "Mouse" then
            local m = UserInputService:GetMouseLocation()
            return Vector2.new(m.X, m.Y)
        end
        return Vector2.new(vp.X*0.5, vp.Y)
    end

    local function getSkeletonLines(char, head)
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then return nil end
        local pts = {}
        table.insert(pts, {head, torso})
        for _, name in ipairs({"LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg"}) do
            local p = char:FindFirstChild(name)
            if p then table.insert(pts, {torso, p}) end
        end
        return pts
    end

    local function updateESP()
        if not hasDrawing then return end
        for player,d in pairs(espData) do
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local show = Config.ESPEnabled and char and hrp and hum and hum.Health>0
            if show and Config.ESPTeamCheck and player.Team and player.Team==LocalPlayer.Team then show=false end
            local dist
            if show then dist=(Camera.CFrame.Position-hrp.Position).Magnitude; if dist>Config.ESPMaxDistance then show=false end end
            local box,humanoid,head
            if show then box,humanoid,head=getBox(char); if not box then show=false end end
            if not show then hideESPSet(d); continue end

            local col = C(Config.ESPBoxColor)
            local th = Config.ESPBoxThickness

            if d.boxFill then
                if Config.ESPBox and Config.ESPBoxFilled then
                    d.boxFill.Visible = true
                    d.boxFill.Color = C(Config.ESPBoxFillColor)
                    d.boxFill.Transparency = 1 - (Config.ESPBoxFillAlpha / 100)
                    d.boxFill.Size = Vector2.new(box.w, box.h)
                    d.boxFill.Position = Vector2.new(box.left, box.top)
                else d.boxFill.Visible = false end
            end
            local borderVis = Config.ESPBox
            if d.bTop then
                d.bTop.Visible = borderVis; d.bBottom.Visible = borderVis
                d.bLeft.Visible = borderVis; d.bRight.Visible = borderVis
                if borderVis then
                    d.bTop.Size = Vector2.new(box.w, th); d.bTop.Position = Vector2.new(box.left, box.top); d.bTop.Color = col; d.bTop.Transparency = 0
                    d.bBottom.Size = Vector2.new(box.w, th); d.bBottom.Position = Vector2.new(box.left, box.bottom - th); d.bBottom.Color = col; d.bBottom.Transparency = 0
                    d.bLeft.Size = Vector2.new(th, box.h); d.bLeft.Position = Vector2.new(box.left, box.top); d.bLeft.Color = col; d.bLeft.Transparency = 0
                    d.bRight.Size = Vector2.new(th, box.h); d.bRight.Position = Vector2.new(box.right - th, box.top); d.bRight.Color = col; d.bRight.Transparency = 0
                end
            end
            if d.name then
                if Config.ESPName then d.name.Visible=true;d.name.Color=C(Config.ESPNameColor);d.name.Text=player.Name;d.name.Position=Vector2.new(box.cx,box.top-16)
                else d.name.Visible=false end
            end
            if d.distance then
                if Config.ESPDistance then d.distance.Visible=true;d.distance.Color=C(Config.ESPDistanceColor);d.distance.Text=string.format("[%d studs]",math.floor(dist));d.distance.Position=Vector2.new(box.cx,box.bottom+4)
                else d.distance.Visible=false end
            end
            if d.healthBG then
                if Config.ESPHealthBar then d.healthBG.Visible=true;d.healthBG.Size=Vector2.new(3,box.h);d.healthBG.Position=Vector2.new(box.right+3,box.top)
                else d.healthBG.Visible=false end
            end
            if d.healthBar then
                if Config.ESPHealthBar then
                    local hp=math.clamp(humanoid.Health/math.max(humanoid.MaxHealth,1),0,1);local barH=box.h*hp
                    d.healthBar.Visible=true;d.healthBar.Color=C(Config.ESPHealthColor):Lerp(C(Config.ESPHealthLow),1-hp)
                    d.healthBar.Transparency=0;d.healthBar.Size=Vector2.new(3,barH);d.healthBar.Position=Vector2.new(box.right+3,box.top+(box.h-barH))
                else d.healthBar.Visible=false end
            end
            if d.healthText then
                if Config.ESPHealthText then d.healthText.Visible=true;d.healthText.Color=C(Config.ESPHealthColor);d.healthText.Text=tostring(math.floor(humanoid.Health));d.healthText.Position=Vector2.new(box.right+12,box.cy)
                else d.healthText.Visible=false end
            end
            if d.headDot then
                if Config.ESPHeadDot and head then
                    local hp=Camera:WorldToViewportPoint(head.Position)
                    d.headDot.Visible=true;d.headDot.Color=C(Config.ESPHeadDotColor);d.headDot.Transparency=0;d.headDot.Radius=3;d.headDot.Position=Vector2.new(hp.X,hp.Y)
                else d.headDot.Visible=false end
            end
            if d.tracer then
                if Config.ESPTracer then
                    local o = tracerOrigin()
                    d.tracer.Visible=true;d.tracer.Color=C(Config.ESPTracerColor);d.tracer.Thickness=Config.ESPTracerThick;d.tracer.Transparency=Config.ESPTracerAlpha
                    d.tracer.From=o;d.tracer.To=Vector2.new(box.cx,box.bottom)
                else d.tracer.Visible=false end
            end
            local skVisible = Config.ESPSkeleton
            if skVisible then
                local pts = getSkeletonLines(char, head)
                local keys = {"sk1","sk2","sk3","sk4","sk5"}
                for i, k in ipairs(keys) do
                    local line = d[k]
                    if line then
                        local p = pts and pts[i]
                        if p and p[1] and p[2] and p[1].Parent and p[2].Parent then
                            local a = Camera:WorldToViewportPoint(p[1].Position)
                            local b = Camera:WorldToViewportPoint(p[2].Position)
                            if a.Z > 0 and b.Z > 0 then
                                line.Visible = true
                                line.Color = C(Config.ESPSkeletonColor)
                                line.Thickness = 2
                                line.From = Vector2.new(a.X, a.Y)
                                line.To = Vector2.new(b.X, b.Y)
                            else line.Visible = false end
                        else line.Visible = false end
                    end
                end
            else
                for _, k in ipairs({"sk1","sk2","sk3","sk4","sk5"}) do
                    local line = d[k]; if line then line.Visible = false end
                end
            end
        end
    end

    --======================================================================
    -- AIMBOT + SILENT
    --======================================================================
    local aimbotActive = false
    local silentActive = false

    local function inputMatchesKey(input, keyName)
        if not keyName or keyName == "" or keyName == "None" then return false end
        if keyName == "MB1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
        if keyName == "MB2" then return input.UserInputType == Enum.UserInputType.MouseButton2 end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            return input.KeyCode.Name == keyName
        end
        return false
    end

    addConn(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end

        if rebindChip then
            local chip = rebindChip
            rebindChip = nil
            local newKey
            if input.UserInputType == Enum.UserInputType.Keyboard then
                newKey = input.KeyCode.Name
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then newKey = "MB1"
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then newKey = "MB2" end
            if newKey then
                chip.Text = newKey
                local cfgKey = chip:GetAttribute("ConfigKey")
                if chip == HideChip then
                    Config.MenuKeybind = newKey
                    HideChip.Text = "Hide: " .. newKey
                elseif cfgKey and Config[cfgKey] ~= nil then
                    Config[cfgKey] = newKey
                end
            else
                chip.Text = "None"
                local cfgKey = chip:GetAttribute("ConfigKey")
                if cfgKey then Config[cfgKey] = "None" end
            end
            return
        end

        if inputMatchesKey(input, Config.MenuKeybind) then
            Config.ShowUI = not Config.ShowUI
            Main.Visible = Config.ShowUI
            OpenBtn.Visible = not Config.ShowUI
            if UIREF.toggles.ShowUI then UIREF.toggles.ShowUI.set(Config.ShowUI, true) end
            return
        end

        if inputMatchesKey(input, Config.AimbotKey) then aimbotActive = true end
        if inputMatchesKey(input, Config.SilentAimKey) then silentActive = true end

        local function handleToggle(keyCfg, setter)
            if Config[keyCfg] and Config[keyCfg] ~= "None"
                and inputMatchesKey(input, Config[keyCfg]) then
                setter()
            end
        end

        handleToggle("FlyKey", function()
            Config.FlyEnabled = not Config.FlyEnabled
            if UIREF.toggles.FlyEnabled then UIREF.toggles.FlyEnabled.set(Config.FlyEnabled, true) end
            flySpeedSlider.holder.Visible = Config.FlyEnabled
            if not Config.FlyEnabled and _G.__RadoHubStopFly then _G.__RadoHubStopFly() end
        end)
        handleToggle("NoclipKey", function()
            Config.NoclipEnabled = not Config.NoclipEnabled
            if UIREF.toggles.NoclipEnabled then UIREF.toggles.NoclipEnabled.set(Config.NoclipEnabled, true) end
        end)
        handleToggle("InfiniteJumpKey", function()
            Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
            if UIREF.toggles.InfiniteJumpEnabled then UIREF.toggles.InfiniteJumpEnabled.set(Config.InfiniteJumpEnabled, true) end
        end)
        handleToggle("MoveSpeedKey", function()
            Config.MoveSpeedEnabled = not Config.MoveSpeedEnabled
            if UIREF.toggles.MoveSpeedEnabled then UIREF.toggles.MoveSpeedEnabled.set(Config.MoveSpeedEnabled, true) end
            walkSpeedSlider.holder.Visible = Config.MoveSpeedEnabled
        end)
        handleToggle("JumpPowerKey", function()
            Config.JumpPowerEnabled = not Config.JumpPowerEnabled
            if UIREF.toggles.JumpPowerEnabled then UIREF.toggles.JumpPowerEnabled.set(Config.JumpPowerEnabled, true) end
            jumpPowerSlider.holder.Visible = Config.JumpPowerEnabled
        end)
        handleToggle("HipHeightKey", function()
            Config.HipHeightEnabled = not Config.HipHeightEnabled
            if UIREF.toggles.HipHeightEnabled then UIREF.toggles.HipHeightEnabled.set(Config.HipHeightEnabled, true) end
            hipHeightSlider.holder.Visible = Config.HipHeightEnabled
        end)
    end))

    addConn(UserInputService.InputEnded:Connect(function(input)
        if inputMatchesKey(input, Config.AimbotKey) then aimbotActive = false end
        if inputMatchesKey(input, Config.SilentAimKey) then silentActive = false end
    end))

    OpenBtn.MouseButton1Click:Connect(function()
        Config.ShowUI = true
        Main.Visible = true
        OpenBtn.Visible = false
        if UIREF.toggles.ShowUI then UIREF.toggles.ShowUI.set(true, true) end
    end)
    HideChip.MouseButton1Click:Connect(function()
        if rebindChip then return end
        rebindChip = HideChip
        HideChip.Text = "..."
    end)

    local function hasLOS(targetPart)
        local origin = Camera.CFrame.Position
        local dir = targetPart.Position - origin
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        local result = workspace:Raycast(origin, dir, params)
        if not result then return true end
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end

    local function predictPos(part, pingTime)
        if not Config.PredictionEnabled then return part.Position end
        local vel = part.AssemblyLinearVelocity
        local ping = math.max(pingTime or 0, Config.PredictionPing)
        return part.Position + vel * ping
    end

    local function findTarget(part, fov, teamCheck, visibleOnly)
        local closest, shortest = nil, fov
        local mp = UserInputService:GetMouseLocation()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == LocalPlayer then continue end
            if teamCheck and pl.Team and pl.Team == LocalPlayer.Team then continue end
            local ch = pl.Character; if not ch then continue end
            local hu = ch:FindFirstChildOfClass("Humanoid"); if not hu or hu.Health <= 0 then continue end
            local tp = ch:FindFirstChild(part); if not tp then continue end
            if visibleOnly and not hasLOS(tp) then continue end
            local pos = predictPos(tp)
            local sp, on = Camera:WorldToViewportPoint(pos)
            if not on or sp.Z <= 0 then continue end
            local ds = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
            if ds < shortest then shortest = ds; closest = tp end
        end
        return closest
    end

    --======================================================================
    -- TRIGGER BOT
    --======================================================================
    local lastTriggerFire = 0
    addConn(RunService.Heartbeat:Connect(function()
        if not Config.TriggerBotEnabled then return end
        local now = os.clock()
        if now - lastTriggerFire < Config.TriggerBotDelay then return end
        local center = Camera.ViewportSize * 0.5
        local ray = Camera:ViewportPointToRay(center.X, center.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        if not hit then return end
        local model = hit.Instance:FindFirstAncestorOfClass("Model")
        if not model then return end
        local pl = Players:GetPlayerFromCharacter(model)
        if not pl or pl == LocalPlayer then return end
        if Config.TriggerBotTeamCheck and pl.Team and pl.Team == LocalPlayer.Team then return end
        local targetPart = model:FindFirstChild(Config.TriggerBotPart) or model:FindFirstChild("Head")
        if not targetPart then return end
        lastTriggerFire = now
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end)
    end))

    --======================================================================
    -- HITBOX EXPANDER
    --======================================================================
    local hitboxStore = {}
    addConn(RunService.Heartbeat:Connect(function()
        if not Config.HitboxEnabled then
            for plr, parts in pairs(hitboxStore) do
                for _, data in ipairs(parts) do
                    if data.part and data.part.Parent then
                        pcall(function()
                            data.part.Size = data.origSize
                            data.part.Transparency = data.origTrans
                            data.part.CanCollide = data.origCollide
                            data.part.Massless = data.origMassless
                        end)
                    end
                end
                hitboxStore[plr] = nil
            end
            return
        end

        local wantSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
        local function revert(pl)
            if not hitboxStore[pl] then return end
            for _, data in ipairs(hitboxStore[pl]) do
                if data.part and data.part.Parent then
                    pcall(function()
                        data.part.Size = data.origSize
                        data.part.Transparency = data.origTrans
                        data.part.CanCollide = data.origCollide
                        data.part.Massless = data.origMassless
                    end)
                end
            end
            hitboxStore[pl] = nil
        end

        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == LocalPlayer then continue end
            if Config.HitboxTeamCheck and pl.Team and pl.Team == LocalPlayer.Team then revert(pl); continue end
            local char = pl.Character
            if not char then revert(pl); continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then revert(pl); continue end
            if Config.HitboxVisibleOnly then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and not hasLOS(hrp) then revert(pl); continue end
            end

            local partsToEdit = {}
            if Config.HitboxUseHumanoidRootPart then
                local p = char:FindFirstChild("HumanoidRootPart")
                if p then table.insert(partsToEdit, p) end
            end
            if Config.HitboxUseHead then
                local p = char:FindFirstChild("Head")
                if p then table.insert(partsToEdit, p) end
            end

            if not hitboxStore[pl] then hitboxStore[pl] = {} end

            for _, part in ipairs(partsToEdit) do
                local existing
                for _, data in ipairs(hitboxStore[pl]) do
                    if data.part == part then existing = data break end
                end
                if not existing then
                    existing = {
                        part = part,
                        origSize = part.Size,
                        origTrans = part.Transparency,
                        origCollide = part.CanCollide,
                        origMassless = part.Massless,
                    }
                    table.insert(hitboxStore[pl], existing)
                end
                if part.Size ~= wantSize then
                    pcall(function()
                        part.Size = wantSize
                        part.Transparency = Config.HitboxTransparency
                        part.CanCollide = false
                        part.Massless = true
                    end)
                end
            end
        end
    end))

    addConn(Players.PlayerRemoving:Connect(function(pl)
        if hitboxStore[pl] then
            for _, data in ipairs(hitboxStore[pl]) do
                if data.part and data.part.Parent then
                    pcall(function()
                        data.part.Size = data.origSize
                        data.part.Transparency = data.origTrans
                        data.part.CanCollide = data.origCollide
                        data.part.Massless = data.origMassless
                    end)
                end
            end
            hitboxStore[pl] = nil
        end
    end))

    --======================================================================
    -- ANTI-FLING
    --======================================================================
    local antiFlingActive = false
    local antiFlingConns = {}
    addConn(RunService.Heartbeat:Connect(function()
        if not Config.AntiFlingEnabled then
            if antiFlingActive then
                antiFlingActive = false
                for _, c in ipairs(antiFlingConns) do pcall(function() c:Disconnect() end) end
                antiFlingConns = {}
            end
            return
        end
        if antiFlingActive then return end
        antiFlingActive = true

        local function anchor()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local lv = hrp.AssemblyLinearVelocity
            if lv.Magnitude > 200 then
                hrp.AssemblyLinearVelocity = lv.Unit * 200
            end
            if lv.Y > 250 then
                hrp.AssemblyLinearVelocity = Vector3.new(lv.X, 250, lv.Z)
            end
            local av = hrp.AssemblyAngularVelocity
            if av.Magnitude > 20 then
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
        table.insert(antiFlingConns, RunService.Stepped:Connect(anchor))
        table.insert(antiFlingConns, RunService.Heartbeat:Connect(anchor))

        table.insert(antiFlingConns, LocalPlayer.CharacterAdded:Connect(function(ch)
            ch.DescendantAdded:Connect(function(d)
                if not Config.AntiFlingEnabled then return end
                if d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity")
                    or d:IsA("LinearVelocity") or d:IsA("AngularVelocity")
                    or d:IsA("BodyThrust") or d:IsA("BodyForce") then
                    if d.Parent and (d.Parent:IsDescendantOf(LocalPlayer.Character)) then
                        task.defer(function() pcall(function() d:Destroy() end) end)
                    end
                end
            end)
        end))
    end))

    _G.__RadoHubAntiFlingStop = function()
        for _, c in ipairs(antiFlingConns) do pcall(function() c:Disconnect() end) end
        antiFlingConns = {}
        antiFlingActive = false
    end

    --======================================================================
    -- FLY
    --======================================================================
    local flyConn, flyBV, flyBG
    local function stopFly()
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if flyConn then flyConn:Disconnect(); flyConn = nil end

        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum then
                pcall(function() hum.PlatformStand = false end)
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            end
            if hrp then
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end
    _G.__RadoHubStopFly = stopFly

    local function startFly()
        stopFly()
        local char = LocalPlayer.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        hum.PlatformStand = true
        flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4; flyBG.Parent = hrp
        flyConn = RunService.RenderStepped:Connect(function()
            if not Config.FlyEnabled or not hrp.Parent then return end
            local move = Vector3.zero
            local cam = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
            if move.Magnitude > 0 then move = move.Unit end
            flyBV.Velocity = move * Config.FlySpeed
            flyBG.CFrame = cam
        end)
    end

    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            ORIGINAL.WalkSpeed = hum.WalkSpeed
            ORIGINAL.HipHeight = hum.HipHeight
            ORIGINAL.JumpPower = hum.JumpPower
            ORIGINAL.UseJumpPower = hum.UseJumpPower
        end
    end
    if LocalPlayer.Character then onChar(LocalPlayer.Character) end
    addConn(LocalPlayer.CharacterAdded:Connect(onChar))

    addConn(RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if Config.MoveSpeedEnabled then hum.WalkSpeed = Config.MoveSpeed end
            if Config.HipHeightEnabled then hum.HipHeight = Config.HipHeight end
            if Config.JumpPowerEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = Config.JumpPower
            end
        end
        if Config.NoclipEnabled and char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
        if Config.FlyEnabled and not flyConn then startFly()
        elseif not Config.FlyEnabled and flyConn then stopFly() end
    end))

    addConn(UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJumpEnabled then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    addConn(LocalPlayer.Idled:Connect(function()
        if not Config.AntiAfkEnabled then return end
        local vu = game:GetService("VirtualUser")
        if not vu then return end
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0, 0))
        end)
    end))

    --======================================================================
    -- MAIN LOOP
    --======================================================================
    addConn(RunService.RenderStepped:Connect(function()
        updateESP()

        if Config.AimbotEnabled then
            local shouldAim = (not Config.AimbotUseKey) or aimbotActive
            if shouldAim then
                local t = findTarget(Config.AimbotPart, Config.AimbotFOV, Config.AimbotTeamCheck, Config.AimbotVisibleOnly)
                if t then
                    local targetPos = predictPos(t)
                    local cf = CFrame.new(Camera.CFrame.Position, targetPos)
                    Camera.CFrame = Config.AimbotSmoothness > 0 and Camera.CFrame:Lerp(cf, 1 - Config.AimbotSmoothness) or cf
                end
            end
        end

        if Config.SilentAimEnabled then
            local shouldAim = (not Config.SilentAimUseKey) or silentActive
            if shouldAim and math.random(1, 100) <= Config.SilentAimHitChance then
                local t = findTarget(Config.SilentAimPart, Config.SilentAimFOV, Config.SilentAimTeamCheck, Config.SilentAimVisibleOnly)
                if t then
                    local targetPos = predictPos(t)
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                end
            end
        end
    end))

    local fovCircle = Instance.new("Frame")
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 0
    fovCircle.ZIndex = 999
    fovCircle.Parent = ScreenGui
    Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
    local fovStroke = Instance.new("UIStroke")
    fovStroke.Color = Color3.fromRGB(255,255,255); fovStroke.Thickness = 1; fovStroke.Transparency = 0.4
    fovStroke.Parent = fovCircle

    addConn(RunService.RenderStepped:Connect(function()
        local active = (Config.AimbotEnabled and Config.AimbotUseKey) or (Config.SilentAimEnabled and Config.SilentAimUseKey)
        if active and Config.FovCircleEnabled and Config.ShowUI then
            local m = UserInputService:GetMouseLocation()
            local fov = Config.AimbotEnabled and Config.AimbotFOV or Config.SilentAimFOV
            fovCircle.Size = UDim2.new(0, fov*2, 0, fov*2)
            fovCircle.Position = UDim2.new(0, m.X, 0, m.Y)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end))

    --======================================================================
    -- UNLOAD
    --======================================================================
    local function unload()
        _G.__RadoHubLoaded = false
        for plr, parts in pairs(hitboxStore) do
            for _, data in ipairs(parts) do
                if data.part and data.part.Parent then
                    pcall(function()
                        data.part.Size = data.origSize
                        data.part.Transparency = data.origTrans
                        data.part.CanCollide = data.origCollide
                        data.part.Massless = data.origMassless
                    end)
                end
            end
        end
        hitboxStore = {}
        if Config.FullbrightEnabled then brightRestore() end
        if Config.FpsBoostEnabled then setFpsBoost(false) end
        if _G.__RadoHubAntiFlingStop then _G.__RadoHubAntiFlingStop() end
        for _, d in pairs(espData) do destroyESPSet(d) end
        espData = {}
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
        stopFly()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if ORIGINAL.WalkSpeed then hum.WalkSpeed = ORIGINAL.WalkSpeed end
            if ORIGINAL.HipHeight then hum.HipHeight = ORIGINAL.HipHeight end
            if ORIGINAL.JumpPower then hum.JumpPower = ORIGINAL.JumpPower end
            if ORIGINAL.UseJumpPower ~= nil then hum.UseJumpPower = ORIGINAL.UseJumpPower end
            hum.PlatformStand = false
        end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        pcall(function() ScreenGui:Destroy() end)
        print("[RadoHub] Unloaded.")
    end

    UnloadBtn.MouseButton1Click:Connect(unload)
    _G.__RadoHubUnload = unload

    print("[RadoHub] Loaded | Drawing:", hasDrawing, "| FileIO:", hasFileIO, "| Request:", hasRequest, "| Executor:", EXECUTOR_NAME)
end

--======================================================================
-- KEY GATE + BOOT
--======================================================================
local function loadSavedKey()
    local hasFileIO = (typeof(writefile) == "function") and (typeof(readfile) == "function")
    if not hasFileIO then return nil end
    local ok, data = pcall(function() return readfile(KEY_FILE) end)
    if not ok or not data or data == "" then return nil end
    return data
end

local function saveKey(key)
    local hasFileIO = (typeof(writefile) == "function") and (typeof(readfile) == "function")
    if not hasFileIO then return end
    if isfolder and not isfolder("RadoHub") then
        pcall(function() makefolder("RadoHub") end)
    end
    pcall(function() writefile(KEY_FILE, key) end)
end

local function buildKeyPrompt(reason, onSuccess)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local promptGui = Instance.new("ScreenGui")
    promptGui.Name = "RadoHub_KeyPrompt"
    promptGui.ResetOnSpawn = false
    promptGui.IgnoreGuiInset = true
    promptGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    promptGui.DisplayOrder = 100
    promptGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 420, 0, 260)
    bg.Position = UDim2.new(0.5, -210, 0.5, -130)
    bg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    bg.BorderSizePixel = 0
    bg.Active = true
    bg.Draggable = true
    bg.Parent = promptGui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = Color3.fromRGB(60, 100, 180)
    bgStroke.Thickness = 1
    bgStroke.Transparency = 0.2
    bgStroke.Parent = bg

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    header.BorderSizePixel = 0
    header.Parent = bg
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "RadoHub  |  Key Required"
    title.TextColor3 = Color3.fromRGB(230, 230, 235)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 34)
    subtitle.Position = UDim2.new(0, 20, 0, 46)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Paste your RADO- key below to unlock the script."
    subtitle.TextColor3 = Color3.fromRGB(200, 205, 220)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = bg

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 22)
    status.Position = UDim2.new(0, 20, 0, 82)
    status.BackgroundTransparency = 1
    status.Text = reason or ""
    status.TextColor3 = Color3.fromRGB(255, 120, 120)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextWrapped = true
    status.Parent = bg

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 32)
    box.Position = UDim2.new(0, 20, 0, 112)
    box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "RADO-...-..."
    box.TextColor3 = Color3.fromRGB(230, 230, 235)
    box.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Parent = bg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    local bs = Instance.new("UIStroke")
    bs.Color = Color3.fromRGB(60, 60, 80)
    bs.Thickness = 1
    bs.Parent = box

    local submit = Instance.new("TextButton")
    submit.Size = UDim2.new(1, -40, 0, 34)
    submit.Position = UDim2.new(0, 20, 0, 158)
    submit.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
    submit.BorderSizePixel = 0
    submit.Text = "Unlock"
    submit.TextColor3 = Color3.fromRGB(255, 255, 255)
    submit.Font = Enum.Font.GothamBold
    submit.TextSize = 13
    submit.Parent = bg
    Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 5)

    local linkBtn = Instance.new("TextButton")
    linkBtn.Size = UDim2.new(1, -40, 0, 26)
    linkBtn.Position = UDim2.new(0, 20, 0, 200)
    linkBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    linkBtn.BorderSizePixel = 0
    linkBtn.Text = "Get a key from the developer (Discord)"
    linkBtn.TextColor3 = Color3.fromRGB(180, 200, 230)
    linkBtn.Font = Enum.Font.Gotham
    linkBtn.TextSize = 11
    linkBtn.Parent = bg
    Instance.new("UICorner", linkBtn).CornerRadius = UDim.new(0, 5)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -40, 0, 18)
    hint.Position = UDim2.new(0, 20, 0, 232)
    hint.BackgroundTransparency = 1
    hint.Text = "Your key is saved locally for next time."
    hint.TextColor3 = Color3.fromRGB(140, 150, 170)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 10
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = bg

    local function attempt()
        local key = box.Text
        local ok, msg, expiresAt = validateKey(key)
        if ok then
            if not verifyIntegrity() then
                poof()
                return
            end
            saveKey(key)
            status.TextColor3 = Color3.fromRGB(120, 255, 160)
            status.Text = "Key accepted! Loading..."
            task.wait(0.4)
            promptGui:Destroy()
            onSuccess(expiresAt)
        else
            status.TextColor3 = Color3.fromRGB(255, 120, 120)
            status.Text = "✗ " .. msg
        end
    end

    submit.MouseButton1Click:Connect(attempt)
    box.FocusLost:Connect(function(enter)
        if enter then attempt() end
    end)
    task.defer(function() pcall(function() box:CaptureFocus() end) end)

    return promptGui
end

--// Boot logic //--
local savedKey = loadSavedKey()
local passed = false
local expiryMsg = ""

if savedKey then
    local ok, msg, expiresAt = validateKey(savedKey)
    if ok then
        passed = true
        if expiresAt and expiresAt > 0 then
            expiryMsg = "Key valid for " .. math.floor((expiresAt - os.time()) / 86400) .. " more days."
        else
            expiryMsg = "Key valid (lifetime)."
        end
    else
        print("[RadoHub] Saved key rejected: " .. tostring(msg))
        local hasFileIO = (typeof(writefile) == "function") and (typeof(readfile) == "function")
        if hasFileIO then pcall(function() delfile(KEY_FILE) end) end
    end
end

if passed then
    print("[RadoHub] " .. expiryMsg)
    local _, _, expiresAt = validateKey(savedKey)
    mainBody(expiresAt)
else
    local prompt
    prompt = buildKeyPrompt("Enter your key to continue.", function(expiresAt)
        _G.__RadoHubKeyPrompt = nil
        if expiresAt and expiresAt > 0 then
            print("[RadoHub] Key valid for " .. math.floor((expiresAt - os.time()) / 86400) .. " more days.")
        else
            print("[RadoHub] Key valid (lifetime).")
        end
        mainBody(expiresAt)
    end)
    _G.__RadoHubKeyPrompt = prompt
end

--// ==========================================================
--// ROYALITY HUB | V18
--// Correções principais:
--//  * mira acompanha slide/pulo (sem offset fixo e sem descartar alvo)
--//  * aimbot só puxa a câmera enquanto você atira
--//  * kit médico com equipar confirmado + reservas de clique
--//  * loops antigos são desconectados ao reexecutar
--//  * voo restaura o PlatformStand ao desligar
--//  * anti-lag / neblina reversíveis
--//  * filtros de loot não re-escaneiam o mapa inteiro
--//  * Rayfield: 4 fontes + painel simples se a UI não carregar
--// ==========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Royality] " .. tostring(err)) end
    return ok
end

--// ---- limpeza da execução anterior -------------------------
safeCall(function()
    for _, c in ipairs(getgenv().RoyalityConns or {}) do
        pcall(function() c:Disconnect() end)
    end
    getgenv().RoyalityConns = {}

    if getgenv().RoyalityLoop then
        pcall(function() getgenv().RoyalityLoop:Disconnect() end)
    end
    getgenv().RoyalityLoop = nil

    if getgenv().RoyalityFOV then
        pcall(function() getgenv().RoyalityFOV:Remove() end)
    end
    getgenv().RoyalityFOV = nil

    if getgenv().RoyalityLootConn then
        pcall(function() getgenv().RoyalityLootConn:Disconnect() end)
    end
    getgenv().RoyalityLootConn = nil

    getgenv().RoyalityBotScanner = false
    getgenv().RoyalityMedLoop = false

    for _, inst in ipairs(getgenv().RoyalityVisuals or {}) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().RoyalityVisuals = {}

    local root = nil
    pcall(function()
        root = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    local roots = { root }
    pcall(function() table.insert(roots, LP:FindFirstChildOfClass("PlayerGui")) end)
    pcall(function() table.insert(roots, game:GetService("Players").LocalPlayer
        :FindFirstChildOfClass("PlayerGui")) end)

    for _, r in ipairs(roots) do
        if r then
            for _, v in ipairs(r:GetChildren()) do
                local n = v.Name:lower()
                if n:find("rayfield") or n:find("royality") then
                    pcall(function() v:Destroy() end)
                end
            end
        end
    end

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.PlatformStand then
        hum.PlatformStand = false
    end
end)

--// Cada execução ganha um id próprio: loops antigos morrem sozinhos
--// mesmo que você aperte "execute" várias vezes seguidas.
getgenv().RoyalityRunId = (getgenv().RoyalityRunId or 0) + 1
local RUN_ID = getgenv().RoyalityRunId

--// ---- aviso rápido (funciona sem Rayfield) -------------------
local Rayfield = nil

local function toast(title, text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = dur or 4
        })
    end)
    pcall(function()
        Rayfield:Notify({
            Title = tostring(title),
            Content = tostring(text),
            Duration = dur or 4
        })
    end)
end

--// ---- Rayfield (várias fontes, sem desistir na primeira) ----
local RAYFIELD_SOURCES = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
    "https://rayfield.dev/source",
    "https://raw.githubusercontent.com/Footagesus/Rayfield/main/source.lua"
}

local lastErr = "?"

for _, url in ipairs(RAYFIELD_SOURCES) do
    if Rayfield then break end
    local ok, res = pcall(function()
        local src = game:HttpGet(url, true)
        if type(src) ~= "string" or #src < 2000 then
            error("resposta inválida")
        end
        return loadstring(src)()
    end)
    if ok and type(res) == "table" then
        Rayfield = res
    else
        lastErr = tostring(res)
    end
end

if type(Rayfield) ~= "table" then
    warn("[Royality] Rayfield falhou: " .. lastErr)
end

--// ---- configuração -----------------------------------------
local Defaults = {
    ESPEnabled = true,
    ESPAntenna = true,
    LootESPEnabled = false,
    LootWeapons = true,
    LootAmmo = true,
    LootMedKits = true,
    AutoMedKit = true,
    AimbotEnabled = true,
    AutoFireEnabled = false,
    TeamCheck = false,
    WallCheck = true,
    MaxAimDistance = 350,
    AimPart = "Head",
    FOVRadius = 400,
    AimbotStrength = 20,
    RapidFireEnabled = false,
    AutoSwitchEnabled = true,
    DamageMultiplier = 3.0,
    FlyEnabled = false,
    FlySpeed = 60,
    KillAuraEnabled = false,
    AntiLagEnabled = false,
    AgressiveRemoteFire = false,
    NoFogEnabled = false
}

local Config = getgenv().Config
if type(Config) ~= "table" then Config = {} end
for k, v in pairs(Defaults) do
    if Config[k] == nil then Config[k] = v end
end
getgenv().Config = Config

local State = {
    firing = false,
    lockChar = nil,
    lockPlayer = nil,
    lockPart = nil,
    screenDist = 1e9,
    lastShot = 0,
    lastMed = 0,
    lastAura = 0,
    frame = 0,
    bots = {},
    loot = {},
    lootCatalog = {},
    fx = {},
    fog = nil,
    lootToken = 0,
    ui = {},
    warned = false
}

local function trackVisual(inst)
    table.insert(getgenv().RoyalityVisuals, inst)
    return inst
end

--// ---- alvos -------------------------------------------------
--// Aceita alvo em slide, pulo e ragdoll: só descarta quem está morto.
local function isTargetAliveAndStanding(targetChar, hum)
    if not targetChar or not targetChar.Parent or not hum then return false end
    if hum.Health <= 0 then return false end

    local ok, state = pcall(function() return hum:GetState() end)
    if ok and state == Enum.HumanoidStateType.Dead then return false end

    if targetChar:GetAttribute("Dead") == true
        or targetChar:GetAttribute("Downed") == true
        or targetChar:GetAttribute("Knocked") == true
        or targetChar:GetAttribute("Eliminated") == true
        or targetChar:GetAttribute("IsDead") == true then
        return false
    end

    return true
end

local function getAimPartForChar(targetChar)
    if Config.AimPart == "Head" then
        return targetChar:FindFirstChild("Head")
            or targetChar:FindFirstChild("UpperTorso")
            or targetChar:FindFirstChild("Torso")
    end
    return targetChar:FindFirstChild("UpperTorso")
        or targetChar:FindFirstChild("Torso")
        or targetChar:FindFirstChild("HumanoidRootPart")
        or targetChar:FindFirstChild("Head")
end

local function isVisible(targetPart, targetCharacter)
    if not Config.WallCheck then return true end
    if not Cam then return true end

    local origin = Cam.CFrame.Position
    local direction = targetPart.Position - origin
    local ignore = { Cam }
    if LP.Character then table.insert(ignore, LP.Character) end

    for _ = 1, 3 do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true

        local result = workspace:Raycast(origin, direction, params)
        if not result then return true end

        local hit = result.Instance
        if hit:IsDescendantOf(targetCharacter) then return true end

        if hit.Transparency >= 0.8 or not hit.CanCollide
            or hit:FindFirstAncestorOfClass("Accessory") then
            table.insert(ignore, hit)
        else
            return false
        end
    end

    return false
end

local function isMedTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("med") or n:find("kit") or n:find("heal")
        or n:find("band") or n:find("cura") or n:find("vida")
        or n:find("syringe") or n:find("potion") or n:find("first")
        or n:find("medico") or n:find("bandage") or n:find("curativo")
end

local function findMedTool(char)
    local equipped = char and char:FindFirstChildOfClass("Tool")
    if isMedTool(equipped) then return equipped end

    local backpack = LP:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if isMedTool(tool) then return tool end
        end
    end
    return nil
end

local function isStandingStill(hum, root)
    if not hum or not root then return false end

    local ok, state = pcall(function() return hum:GetState() end)
    if ok and (state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall) then
        return false
    end

    local v = root.AssemblyLinearVelocity
    local hSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
    if hSpeed >= 4 then return false end

    --// Tolerância: alguns jogos deixam MoveDirection com resíduo.
    if hum.MoveDirection.Magnitude > 0.35 and hSpeed >= 1 then return false end

    return true
end

--// ---- FOV ---------------------------------------------------
local FOVCircle = nil
safeCall(function()
    if Drawing then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = Config.AimbotEnabled
        FOVCircle.Transparency = 0.6
        FOVCircle.Color = Color3.fromRGB(255, 50, 50)
        FOVCircle.Thickness = 1.8
        FOVCircle.NumSides = 32
        FOVCircle.Radius = Config.FOVRadius
        FOVCircle.Filled = false
        getgenv().RoyalityFOV = FOVCircle
    end
end)

--// ---- bots / NPCs ------------------------------------------
local function registerBot(model)
    if not model or not model:IsA("Model") or model == LP.Character then return end
    if Players:GetPlayerFromCharacter(model) then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and model:FindFirstChild("Head") then
        State.bots[model] = true
    end
end

getgenv().RoyalityBotScanner = true
local scannerRun = RUN_ID
task.spawn(function()
    task.wait(0.5)
    local list = workspace:GetDescendants()
    for i, obj in ipairs(list) do
        if not getgenv().RoyalityBotScanner
            or getgenv().RoyalityRunId ~= scannerRun then break end
        if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
            registerBot(obj.Parent)
        end
        if i % 500 == 0 then task.wait() end
    end
end)

--// ---- loot ---------------------------------------------------
local clearLootVisuals
local refreshLootLabels
local rebuildLootCache

safeCall(function()
    for _, inst in ipairs(getgenv().RoyalityLootVisuals or {}) do
        if inst and inst.Parent then pcall(function() inst:Destroy() end) end
    end
end)
getgenv().RoyalityLootVisuals = {}

local ignoredNames = {
    lootspot = true, loot = true, spawn = true, spawner = true,
    itemspawn = true, weaponspawn = true, dropzone = true,
    handle = true, part = true, meshpart = true, union = true,
    hitbox = true, root = true, primarypart = true, attachment = true
}

local function isPlayerCharacter(inst)
    if LP.Character and inst:IsDescendantOf(LP.Character) then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and inst:IsDescendantOf(p.Character) then return true end
    end
    for model in pairs(State.bots) do
        if model and model.Parent and inst:IsDescendantOf(model) then return true end
    end
    return false
end

local function cleanText(txt)
    if type(txt) ~= "string" then return nil end
    local s = txt:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
    if s == "" or #s < 2 then return nil end
    return s
end

local function resolveRealItemName(obj)
    for _, desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name ~= "RoyLootLabel" then
            local raw = cleanText(desc.Text)
            if raw then
                local low = raw:lower()
                if not ignoredNames[low] and not low:find("^%[") and not low:find("^pegar") then
                    return raw
                end
            end
        end
    end

    local curr = obj
    while curr and curr ~= workspace do
        local attrName = curr:GetAttribute("ItemName")
            or curr:GetAttribute("DisplayName")
            or curr:GetAttribute("Name")
        if type(attrName) == "string" and attrName ~= ""
            and not ignoredNames[attrName:lower()] then
            return attrName
        end

        for _, child in ipairs(curr:GetChildren()) do
            if child:IsA("StringValue") then
                local cn = child.Name:lower()
                if (cn:find("name") or cn:find("item")) and child.Value ~= "" then
                    return child.Value
                end
            end
        end

        local prompt = curr:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            local ot = cleanText(prompt.ObjectText)
            if ot and not ignoredNames[ot:lower()] then return ot end
            local at = cleanText(prompt.ActionText)
            if at and not ignoredNames[at:lower()] then return at end
        end

        if curr ~= obj and not ignoredNames[curr.Name:lower()] then
            return curr.Name
        end

        curr = curr.Parent
    end

    if not ignoredNames[obj.Name:lower()] then return obj.Name end
    return nil
end

local function classifyRealLoot(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("Terrain") or obj:IsA("Camera") or obj:IsA("Folder") then return nil end
    if isPlayerCharacter(obj) then return nil end

    local low = obj.Name:lower()
    if low == "lootspot" or low == "loot" or low == "spawner" then return nil end

    local targetPart = nil
    if obj:IsA("Tool") then
        targetPart = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("Model") or obj:IsA("BasePart") then
        local hasPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        local hasUI = obj:FindFirstChildWhichIsA("BillboardGui", true)
        local parentName = obj.Parent and obj.Parent.Name:lower() or ""
        local inContainer = parentName:find("loot") or parentName:find("drop")
            or parentName:find("item") or parentName:find("pickup")
            or parentName:find("weapon") or parentName:find("gun")

        if hasPrompt or hasUI or inContainer then
            if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
                if State.lootCatalog[obj.Parent] then return nil end
            end
            targetPart = obj:IsA("BasePart") and obj
                or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
            if targetPart and targetPart.Size.Magnitude >= 25 then targetPart = nil end
        end
    end

    if not targetPart or not targetPart.Parent then return nil end

    local realName = resolveRealItemName(obj)
    if not realName or ignoredNames[realName:lower()] then return nil end

    local n = realName:lower()
    local category = "Weapon"
    if n:find("med") or n:find("kit") or n:find("heal") or n:find("band")
        or n:find("cura") or n:find("vida") or n:find("syringe")
        or n:find("potion") or n:find("medico") or n:find("curativo") then
        category = "Med"
    elseif n:find("ammo") or n:find("bullet") or n:find("mag")
        or n:find("shell") or n:find("munic") or n:find("cart") then
        category = "Ammo"
    end

    return { category = category, part = targetPart, name = realName, source = obj }
end

local function categoryEnabled(category)
    if category == "Weapon" then return Config.LootWeapons end
    if category == "Ammo" then return Config.LootAmmo end
    if category == "Med" then return Config.LootMedKits end
    return false
end

local function makeLootLabel(obj, info)
    if State.loot[obj] then return end
    local part = info.part
    if not part or not part.Parent then return end

    local color
    if info.category == "Med" then
        color = Color3.fromRGB(0, 255, 110)
    elseif info.category == "Ammo" then
        color = Color3.fromRGB(0, 220, 255)
    else
        color = Color3.fromRGB(255, 165, 0)
    end

    local bill = Instance.new("BillboardGui")
    bill.Name = "RoyLootText"
    bill.Adornee = part
    bill.Size = UDim2.new(0, 150, 0, 28)
    bill.StudsOffset = Vector3.new(0, 1.8, 0)
    bill.MaxDistance = 400
    bill.AlwaysOnTop = true

    local txt = Instance.new("TextLabel")
    txt.Name = "RoyLootLabel"
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Text = info.name
    txt.TextColor3 = color
    txt.TextStrokeTransparency = 0
    txt.TextSize = 13
    txt.Font = Enum.Font.GothamBold
    txt.Parent = bill

    bill.Parent = part
    State.loot[obj] = bill
    table.insert(getgenv().RoyalityLootVisuals, bill)
end

local function dropLootLabel(obj)
    local bill = State.loot[obj]
    if bill then
        if bill.Parent then bill:Destroy() end
        State.loot[obj] = nil
    end
end

refreshLootLabels = function()
    if not Config.LootESPEnabled then
        for obj in pairs(State.loot) do dropLootLabel(obj) end
        return
    end

    for obj, info in pairs(State.lootCatalog) do
        local alive = obj and obj.Parent and info.part and info.part.Parent
        if not alive then
            dropLootLabel(obj)
            State.lootCatalog[obj] = nil
        elseif categoryEnabled(info.category) then
            makeLootLabel(obj, info)
        else
            dropLootLabel(obj)
        end
    end

    for obj in pairs(State.loot) do
        if not State.lootCatalog[obj] then dropLootLabel(obj) end
    end
end

local function registerLootCandidate(obj)
    if not obj or not obj.Parent then return end
    if State.lootCatalog[obj] then return end
    local info = classifyRealLoot(obj)
    if not info then return end
    State.lootCatalog[obj] = info
    if Config.LootESPEnabled and categoryEnabled(info.category) then
        makeLootLabel(obj, info)
    end
end

clearLootVisuals = function()
    for obj in pairs(State.loot) do dropLootLabel(obj) end
    for obj in pairs(State.lootCatalog) do State.lootCatalog[obj] = nil end
end

rebuildLootCache = function()
    local token = State.lootToken + 1
    State.lootToken = token

    task.spawn(function()
        local list = workspace:GetDescendants()
        for i, obj in ipairs(list) do
            if State.lootToken ~= token then return end
            if getgenv().RoyalityRunId ~= RUN_ID then return end
            if not Config.LootESPEnabled then return end
            if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
                registerLootCandidate(obj)
            end
            if i % 400 == 0 then task.wait() end
        end
        if State.lootToken == token then refreshLootLabels() end
    end)
end

--// ---- conexões de loot --------------------------------------
getgenv().RoyalityLootConn = workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
        task.defer(function() registerBot(obj.Parent) end)
    end

    if not Config.LootESPEnabled then return end

    local isCandidate = obj:IsA("Tool") or obj:IsA("Model")
        or obj:IsA("BasePart") or obj:IsA("TextLabel")
    if not isCandidate then return end

    task.delay(0.2, function()
        if not Config.LootESPEnabled or not obj.Parent then return end
        local target = obj
        if obj:IsA("TextLabel") then
            target = obj:FindFirstAncestorWhichIsA("Model")
                or obj:FindFirstAncestorWhichIsA("BasePart")
        end
        if target then registerLootCandidate(target) end
    end)
end)
table.insert(getgenv().RoyalityConns, getgenv().RoyalityLootConn)

--// ---- efeitos reversíveis -----------------------------------
local function stopAllEffects(inst)
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail")
            or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
            if State.fx[d] == nil then State.fx[d] = d.Enabled end
            d.Enabled = false
        end
    end
end

local function restoreAllEffects()
    for obj, wasEnabled in pairs(State.fx) do
        if obj and obj.Parent then obj.Enabled = wasEnabled end
    end
    State.fx = {}
end

local function setAntiLag(on)
    Config.AntiLagEnabled = on
    if on then
        task.spawn(function()
            local list = workspace:GetDescendants()
            for i, obj in ipairs(list) do
                if not Config.AntiLagEnabled then return end
                if obj:IsA("Model") or obj:IsA("BasePart") then
                    stopAllEffects(obj)
                end
                if i % 400 == 0 then task.wait() end
            end
        end)
    else
        restoreAllEffects()
    end
end

local function setNoFog(on)
    Config.NoFogEnabled = on
    if on then
        if State.fog == nil then
            State.fog = {
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                FogColor = Lighting.FogColor
            }
        end
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                if State.fog[child] == nil then State.fog[child] = child.Density end
                child.Density = 0
            end
        end
    else
        if State.fog then
            if State.fog.FogEnd then
                Lighting.FogEnd = State.fog.FogEnd
                Lighting.FogStart = State.fog.FogStart
                Lighting.FogColor = State.fog.FogColor
            end
            for obj, density in pairs(State.fog) do
                if typeof(obj) == "Instance" and obj.Parent then
                    pcall(function() obj.Density = density end)
                end
            end
        end
        State.fog = nil
    end
end

--// ---- disparo -----------------------------------------------
--// Ordem: Activate() -> 1 clique -> (opcional) remotes do próprio tool.
--// O disparo por remote só acontece se você ligar a opção, porque
--// RemoteEvent adivinhado por nome costuma derrubar a conta.
local function fireTool(char)
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or isMedTool(tool) then return end

    pcall(function() tool:Activate() end)

    pcall(function()
        if mouse1click then mouse1click() end
    end)

    if Config.AgressiveRemoteFire then
        pcall(function()
            for _, rem in ipairs(tool:GetChildren()) do
                if rem:IsA("RemoteEvent") then
                    local n = rem.Name:lower()
                    if n:find("fire") or n:find("shoot")
                        or n:find("attack") or n:find("hit") then
                        rem:FireServer()
                    end
                end
            end
        end)
    end
end

--// ---- kit médico --------------------------------------------
--// Roda fora do RenderStepped: pode esperar o equipar replicar.
getgenv().RoyalityMedLoop = true
local medRun = RUN_ID
task.spawn(function()
    while getgenv().RoyalityMedLoop
        and getgenv().RoyalityRunId == medRun do
        task.wait(0.25)

        if Config.AutoMedKit then
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if hum and root and hum.Health > 0 and hum.Health <= 60
                and os.clock() - State.lastMed >= 2
                and isStandingStill(hum, root) then

                local tool = findMedTool(char)
                if tool then
                    State.lastMed = os.clock()
                    local before = hum.Health

                    if tool.Parent ~= char then
                        pcall(function() hum:EquipTool(tool) end)
                        local waited = 0
                        while tool.Parent ~= char and waited < 0.8
                            and hum.Health > 0 do
                            task.wait(0.05)
                            waited += 0.05
                        end
                    end

                    if tool.Parent == char then
                        pcall(function() tool:Activate() end)
                        task.wait(0.35)

                        if hum.Health <= before and hum.Health > 0
                            and hum.Health <= 60 and tool.Parent == char then
                            pcall(function()
                                if mouse1click then mouse1click() end
                            end)
                            task.wait(0.25)
                        end

                        if hum.Health <= before and hum.Health > 0
                            and hum.Health <= 60 and tool.Parent == char then
                            pcall(function()
                                local cam = workspace.CurrentCamera
                                if cam then
                                    local pos = Vector2.new(
                                        cam.ViewportSize.X / 2,
                                        cam.ViewportSize.Y / 2
                                    )
                                    VirtualUser:Button1Down(pos, cam.CFrame)
                                    task.wait(0.03)
                                    VirtualUser:Button1Up(pos, cam.CFrame)
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end)

--// ---- interface ---------------------------------------------
local usedFallback = false
local Window = nil

if type(Rayfield) == "table" then
    local ok, res = pcall(function()
        return Rayfield:CreateWindow({
            Name = "Royality Hub | Ultimate Final v18",
            LoadingTitle = "Carregando Hub...",
            LoadingSubtitle = "Delta Executor",
            ConfigurationSaving = { Enabled = false },
            KeySystem = false
        })
    end)
    if ok and res then
        Window = res
    else
        usedFallback = true
        warn("[Royality] CreateWindow falhou: " .. tostring(res))
    end
else
    usedFallback = true
end

local T1, T2, T3, T4
if not usedFallback then
    T1 = Window:CreateTab("Combate & Aim", 4483362458)
    T2 = Window:CreateTab("Voo & Movimento", 4483345998)
    T3 = Window:CreateTab("Visual (ESP & Loot)", 4483345998)
    T4 = Window:CreateTab("Sistema", 4483345998)
end

local UI = State.ui

if not usedFallback then

--// Aba Combate
UI.aimbot = T1:CreateToggle({
    Name = "🎯 Aimbot (liga só ao atirar)",
    CurrentValue = Config.AimbotEnabled,
    Flag = "AE",
    Callback = function(v)
        Config.AimbotEnabled = v
        if FOVCircle then FOVCircle.Visible = v end
        if not v then
            State.lockChar = nil
            State.lockPlayer = nil
            State.lockPart = nil
        end
    end
})

UI.autofire = T1:CreateToggle({
    Name = "🔫 Atirar Sozinho (Auto Fire)",
    CurrentValue = Config.AutoFireEnabled,
    Flag = "AF",
    Callback = function(v) Config.AutoFireEnabled = v end
})

UI.wallcheck = T1:CreateToggle({
    Name = "🧱 WallCheck (não puxa através de parede)",
    CurrentValue = Config.WallCheck,
    Flag = "WC",
    Callback = function(v) Config.WallCheck = v end
})

UI.distance = T1:CreateSlider({
    Name = "Distância Máxima do Aimbot",
    Range = { 50, 600 },
    Increment = 25,
    Suffix = " studs",
    CurrentValue = Config.MaxAimDistance,
    Flag = "MAD",
    Callback = function(v) Config.MaxAimDistance = v end
})

UI.strength = T1:CreateSlider({
    Name = "Força de Puxada do Aimbot",
    Range = { 1, 20 },
    Increment = 1,
    CurrentValue = Config.AimbotStrength,
    Flag = "ABS",
    Callback = function(v) Config.AimbotStrength = v end
})

UI.aimpart = T1:CreateDropdown({
    Name = "Parte do Corpo Alvo",
    Options = { "Cabeça", "Peito" },
    CurrentOption = Config.AimPart == "Head" and "Cabeça" or "Peito",
    Flag = "AP",
    Callback = function(o)
        local choice = type(o) == "table" and o[1] or o
        Config.AimPart = (choice == "Cabeça") and "Head" or "UpperTorso"
    end
})

UI.fov = T1:CreateSlider({
    Name = "Raio de Mira (FOV)",
    Range = { 50, 800 },
    Increment = 25,
    CurrentValue = Config.FOVRadius,
    Flag = "FOV",
    Callback = function(v)
        Config.FOVRadius = v
        if FOVCircle then FOVCircle.Radius = v end
    end
})

UI.rapid = T1:CreateToggle({
    Name = "⚡ Rapid Fire (disparo rápido)",
    CurrentValue = Config.RapidFireEnabled,
    Flag = "RF",
    Callback = function(v) Config.RapidFireEnabled = v end
})

UI.autoswitch = T1:CreateToggle({
    Name = "🔄 Trocar Arma Automático (ao descarregar)",
    CurrentValue = Config.AutoSwitchEnabled,
    Flag = "AS",
    Callback = function(v) Config.AutoSwitchEnabled = v end
})

UI.medkit = T1:CreateToggle({
    Name = "💉 Auto Kit Médico (vida <= 60 & parado)",
    CurrentValue = Config.AutoMedKit,
    Flag = "AMK",
    Callback = function(v)
        Config.AutoMedKit = v
        if v then State.lastMed = 0 end
    end
})

UI.teamcheck = T1:CreateToggle({
    Name = "Ignorar Time (TeamCheck)",
    CurrentValue = Config.TeamCheck,
    Flag = "TC",
    Callback = function(v) Config.TeamCheck = v end
})

UI.remotefire = T1:CreateToggle({
    Name = "⚠️ Disparo por Remote (experimental / ban risk)",
    CurrentValue = Config.AgressiveRemoteFire,
    Flag = "ARF",
    Callback = function(v) Config.AgressiveRemoteFire = v end
})

--// Aba Voo & Movimento
UI.fly = T2:CreateToggle({
    Name = "✈️ Ativar Voo Suave",
    CurrentValue = Config.FlyEnabled,
    Flag = "FT",
    Callback = function(v)
        Config.FlyEnabled = v
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not v and h then
            h.PlatformStand = false
            local root = c:FindFirstChild("HumanoidRootPart")
            if root then root.AssemblyLinearVelocity = Vector3.zero end
        end
    end
})

UI.flyspeed = T2:CreateSlider({
    Name = "Velocidade do Voo",
    Range = { 20, 200 },
    Increment = 10,
    CurrentValue = Config.FlySpeed,
    Flag = "FS",
    Callback = function(v) Config.FlySpeed = v end
})

UI.killaura = T2:CreateToggle({
    Name = "⚔️ Kill Aura Próximo (seguro)",
    CurrentValue = Config.KillAuraEnabled,
    Flag = "KA",
    Callback = function(v) Config.KillAuraEnabled = v end
})

--// Aba Visual
UI.esp = T3:CreateToggle({
    Name = "👁️ ESP Player e Bots",
    CurrentValue = Config.ESPEnabled,
    Flag = "ESP",
    Callback = function(v) Config.ESPEnabled = v end
})

UI.antenna = T3:CreateToggle({
    Name = "Antena Player",
    CurrentValue = Config.ESPAntenna,
    Flag = "ANT",
    Callback = function(v) Config.ESPAntenna = v end
})

UI.lootesp = T3:CreateToggle({
    Name = "📦 ESP Loot (nomes e cores)",
    CurrentValue = Config.LootESPEnabled,
    Flag = "LESP",
    Callback = function(v)
        Config.LootESPEnabled = v
        if v then
            rebuildLootCache()
        else
            refreshLootLabels()
        end
    end
})

UI.lootweapons = T3:CreateToggle({
    Name = "Filtro: Armas (laranja)",
    CurrentValue = Config.LootWeapons,
    Flag = "LWEP",
    Callback = function(v)
        Config.LootWeapons = v
        if Config.LootESPEnabled then refreshLootLabels() end
    end
})

UI.lootammo = T3:CreateToggle({
    Name = "Filtro: Munição (azul)",
    CurrentValue = Config.LootAmmo,
    Flag = "LAMM",
    Callback = function(v)
        Config.LootAmmo = v
        if Config.LootESPEnabled then refreshLootLabels() end
    end
})

UI.lootmed = T3:CreateToggle({
    Name = "Filtro: Kits Médicos (verde)",
    CurrentValue = Config.LootMedKits,
    Flag = "LMED",
    Callback = function(v)
        Config.LootMedKits = v
        if Config.LootESPEnabled then refreshLootLabels() end
    end
})

UI.fog = T3:CreateToggle({
    Name = "Remover Neblina",
    CurrentValue = Config.NoFogEnabled,
    Flag = "NFOG",
    Callback = function(v)
        pcall(function() setNoFog(v) end)
    end
})

--// Aba Sistema
UI.antilag = T4:CreateToggle({
    Name = "Anti-Lag Booster",
    CurrentValue = Config.AntiLagEnabled,
    Flag = "ALAG",
    Callback = function(v)
        pcall(function() setAntiLag(v) end)
    end
})

T4:CreateButton({
    Name = "📋 Copiar JobId do Servidor",
    Callback = function()
        local ok = pcall(function()
            if setclipboard then setclipboard(game.JobId) end
        end)
        Rayfield:Notify({
            Title = ok and "Copiado!" or "Aviso",
            Content = ok and game.JobId or "Seu executor não tem setclipboard.",
            Duration = 4
        })
    end
})

T4:CreateButton({
    Name = "🔄 Reconectar neste Servidor",
    Callback = function()
        Rayfield:Notify({
            Title = "Reconectando...",
            Content = "Voltando para o mesmo servidor.",
            Duration = 3
        })
        task.spawn(function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId, game.JobId, LP
                )
            end)
        end)
    end
})

T4:CreateButton({
    Name = "🔄 Resetar Configurações para o Padrão",
    Callback = function()
        for k, v in pairs(Defaults) do Config[k] = v end
        State.lockChar = nil
        State.lockPlayer = nil
        State.lockPart = nil
        State.lastMed = 0
        pcall(function() setNoFog(Defaults.NoFogEnabled) end)
        pcall(function() setAntiLag(Defaults.AntiLagEnabled) end)
        pcall(function() clearLootVisuals() end)
        if FOVCircle then
            FOVCircle.Radius = Config.FOVRadius
            FOVCircle.Visible = Config.AimbotEnabled
        end

        pcall(function() UI.aimbot:Set(Config.AimbotEnabled) end)
        pcall(function() UI.autofire:Set(Config.AutoFireEnabled) end)
        pcall(function() UI.wallcheck:Set(Config.WallCheck) end)
        pcall(function() UI.distance:Set(Config.MaxAimDistance) end)
        pcall(function() UI.strength:Set(Config.AimbotStrength) end)
        pcall(function() UI.fov:Set(Config.FOVRadius) end)
        pcall(function() UI.rapid:Set(Config.RapidFireEnabled) end)
        pcall(function() UI.autoswitch:Set(Config.AutoSwitchEnabled) end)
        pcall(function() UI.medkit:Set(Config.AutoMedKit) end)
        pcall(function() UI.teamcheck:Set(Config.TeamCheck) end)
        pcall(function() UI.remotefire:Set(Config.AgressiveRemoteFire) end)
        pcall(function() UI.fly:Set(Config.FlyEnabled) end)
        pcall(function() UI.flyspeed:Set(Config.FlySpeed) end)
        pcall(function() UI.killaura:Set(Config.KillAuraEnabled) end)
        pcall(function() UI.esp:Set(Config.ESPEnabled) end)
        pcall(function() UI.antenna:Set(Config.ESPAntenna) end)
        pcall(function() UI.lootesp:Set(Config.LootESPEnabled) end)
        pcall(function() UI.lootweapons:Set(Config.LootWeapons) end)
        pcall(function() UI.lootammo:Set(Config.LootAmmo) end)
        pcall(function() UI.lootmed:Set(Config.LootMedKits) end)
        pcall(function() UI.fog:Set(Config.NoFogEnabled) end)
        pcall(function() UI.antilag:Set(Config.AntiLagEnabled) end)
        pcall(function()
            UI.aimpart:Set(Config.AimPart == "Head" and "Cabeça" or "Peito")
        end)

        Rayfield:Notify({
            Title = "Resetado!",
            Content = "Todas as configurações voltaram ao padrão.",
            Duration = 3
        })
    end
})
end --// fecha o bloco da interface Rayfield

--// ---- painel de emergência (se o Rayfield não carregar) ------
local function buildFallbackPanel()
    local root = nil
    pcall(function() root = gethui and gethui() end)
    if not root then
        pcall(function() root = game:GetService("CoreGui") end)
    end
    if not root then
        pcall(function() root = LP:WaitForChild("PlayerGui", 5) end)
    end
    if not root then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "RoyalityFallback"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = root

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 270, 0, 500)
    frame.Position = UDim2.new(0, 20, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "ROYALITY v18 (modo simples)"
    title.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 28, 0, 28)
    close.Position = UDim2.new(1, -34, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Text = "X"
    close.Parent = frame
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    close.MouseButton1Click:Connect(function() sg:Destroy() end)

    local y = 44

    local function row(labelText, getValue, setValue)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 32)
        btn.Position = UDim2.new(0, 10, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = Color3.fromRGB(235, 235, 235)
        btn.Text = ""
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 10)

        local function paint()
            local on = getValue()
            btn.Text = labelText .. ": " .. (on and "ON" or "OFF")
            btn.BackgroundColor3 = on and Color3.fromRGB(0, 110, 75)
                or Color3.fromRGB(32, 32, 38)
        end

        btn.MouseButton1Click:Connect(function()
            local ok = pcall(function() setValue(not getValue()) end)
            if not ok then return end
            paint()
        end)

        paint()
        y = y + 36
    end

    row("Aimbot (só ao atirar)", function()
        return Config.AimbotEnabled
    end, function(v)
        Config.AimbotEnabled = v
        if FOVCircle then FOVCircle.Visible = v end
        if not v then
            State.lockChar = nil
            State.lockPlayer = nil
        end
    end)

    row("Atirar Sozinho", function()
        return Config.AutoFireEnabled
    end, function(v) Config.AutoFireEnabled = v end)

    row("WallCheck", function()
        return Config.WallCheck
    end, function(v) Config.WallCheck = v end)

    row("Auto Kit Médico", function()
        return Config.AutoMedKit
    end, function(v)
        Config.AutoMedKit = v
        if v then State.lastMed = 0 end
    end)

    row("ESP Player e Bots", function()
        return Config.ESPEnabled
    end, function(v) Config.ESPEnabled = v end)

    row("Antena", function()
        return Config.ESPAntenna
    end, function(v) Config.ESPAntenna = v end)

    row("ESP Loot", function()
        return Config.LootESPEnabled
    end, function(v)
        Config.LootESPEnabled = v
        if v then rebuildLootCache() else refreshLootLabels() end
    end)

    row("Voo", function()
        return Config.FlyEnabled
    end, function(v)
        Config.FlyEnabled = v
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not v and h then
            h.PlatformStand = false
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then r.AssemblyLinearVelocity = Vector3.zero end
        end
    end)

    row("Anti-Lag", function()
        return Config.AntiLagEnabled
    end, function(v) setAntiLag(v) end)

    row("Remover Neblina", function()
        return Config.NoFogEnabled
    end, function(v) setNoFog(v) end)

    local note = Instance.new("TextLabel")
    note.Size = UDim2.new(1, -20, 0, 40)
    note.Position = UDim2.new(0, 10, 0, y + 4)
    note.BackgroundTransparency = 1
    note.Font = Enum.Font.Gotham
    note.TextSize = 11
    note.TextWrapped = true
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.TextColor3 = Color3.fromRGB(150, 150, 160)
    note.Text = "Rayfield não carregou (internet/fonte). "
        .. "O script e todos os recursos estão ativos; "
        .. "só esta lista simples aparece."
    note.Parent = frame
end

if usedFallback then
    pcall(buildFallbackPanel)
    toast("Royality v18", "Interface completa não carregou. Usei o painel simples.", 6)
end

--// ---- ESP ---------------------------------------------------
local function applyESPToCharacter(char)
    if not char or not char.Parent then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    local hl = char:FindFirstChild("RoyESP")
    local antenna = char:FindFirstChild("RoyAntenna")
    local alive = isTargetAliveAndStanding(char, hum)

    if Config.ESPEnabled then
        if not hl then
            hl = trackVisual(Instance.new("Highlight"))
            hl.Name = "RoyESP"
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = char
        end
        hl.Enabled = true
        hl.FillColor = alive and Color3.fromRGB(255, 0, 0)
            or Color3.fromRGB(0, 100, 255)
    elseif hl then
        hl.Enabled = false
    end

    if Config.ESPAntenna and head and alive then
        if not antenna then
            antenna = trackVisual(Instance.new("BillboardGui"))
            antenna.Name = "RoyAntenna"
            antenna.Adornee = head
            antenna.Size = UDim2.new(0, 2, 0, 150)
            antenna.StudsOffset = Vector3.new(0, 8, 0)
            antenna.AlwaysOnTop = true

            local line = Instance.new("Frame")
            line.Size = UDim2.new(1, 0, 1, 0)
            line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            line.BorderSizePixel = 0
            line.Parent = antenna

            antenna.Parent = head
        end
        antenna.Enabled = true
    elseif antenna then
        antenna.Enabled = false
    end
end

--// ---- input ------------------------------------------------
--// gpe = true quando o clique é na interface (não conta como tiro).
local inputBeganConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.KeyCode == Enum.KeyCode.ButtonR2 then
        State.firing = true
    end
end)
table.insert(getgenv().RoyalityConns, inputBeganConn)

local inputEndedConn = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.KeyCode == Enum.KeyCode.ButtonR2 then
        State.firing = false
    end
end)
table.insert(getgenv().RoyalityConns, inputEndedConn)

--// ---- loop principal ----------------------------------------
getgenv().RoyalityLoop = RunService.RenderStepped:Connect(function(dt)
    pcall(function()
        Cam = workspace.CurrentCamera
        if not Cam then return end

        if FOVCircle then
            FOVCircle.Position = Vector2.new(
                Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2
            )
        end

        State.frame = State.frame + 1
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local backpack = LP:FindFirstChildOfClass("Backpack")

        --// ESP: não precisa rodar a cada frame
        if State.frame % 6 == 0 then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    applyESPToCharacter(p.Character)
                end
            end
            for botChar in pairs(State.bots) do
                if not botChar.Parent then
                    State.bots[botChar] = nil
                elseif botChar ~= LP.Character then
                    applyESPToCharacter(botChar)
                end
            end
        end

        --// Limpeza do loot
        if State.frame % 90 == 0 and Config.LootESPEnabled then
            for obj, info in pairs(State.lootCatalog) do
                if not obj or not obj.Parent or not info.part
                    or not info.part.Parent or isPlayerCharacter(obj) then
                    dropLootLabel(obj)
                    State.lootCatalog[obj] = nil
                end
            end
        end

        --// ---------------- AIMBOT ----------------
        local aiming = Config.AimbotEnabled
            and (State.firing or Config.AutoFireEnabled)
        State.lockPart = nil
        State.screenDist = 1e9

        if aiming and root then
            local camPos = Cam.CFrame.Position
            local center = Vector2.new(
                Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2
            )
            local bestPart, bestChar, bestPlayer = nil, nil, nil
            local bestScore, bestScreen = math.huge, math.huge

            local function evaluate(targetChar, targetPlayer, isLock)
                if not targetChar or not targetChar.Parent then return end
                if targetChar == char then return end

                local tHum = targetChar:FindFirstChildOfClass("Humanoid")
                if not isTargetAliveAndStanding(targetChar, tHum) then return end

                if Config.TeamCheck and targetPlayer and LP.Team
                    and targetPlayer.Team == LP.Team then
                    return
                end

                local part = getAimPartForChar(targetChar)
                local tRoot = targetChar:FindFirstChild("HumanoidRootPart") or part
                if not part or not tRoot then return end
                if (tRoot.Position - root.Position).Magnitude > Config.MaxAimDistance then
                    return
                end

                local screenPos, onScreen = Cam:WorldToViewportPoint(part.Position)
                if not onScreen then return end

                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                local fovLimit = isLock and (Config.FOVRadius * 1.4) or Config.FOVRadius
                if dist > fovLimit then return end
                if not isVisible(part, targetChar) then return end

                local score = isLock and (dist * 0.65) or dist
                if score < bestScore then
                    bestScore = score
                    bestPart = part
                    bestChar = targetChar
                    bestPlayer = targetPlayer
                    bestScreen = dist
                end
            end

            --// Alvo atual tem prioridade: não solta no meio do slide.
            evaluate(State.lockChar, State.lockPlayer, true)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and p.Character ~= State.lockChar then
                    evaluate(p.Character, p, false)
                end
            end
            for botChar in pairs(State.bots) do
                if botChar.Parent and botChar ~= State.lockChar then
                    evaluate(botChar, nil, false)
                end
            end

            State.lockChar = bestChar
            State.lockPlayer = bestPlayer
            State.lockPart = bestPart
            State.screenDist = bestScreen

            if bestPart then
                --// Usa a velocidade da própria parte mirada (cabeça):
                --// acompanha slide, pulo e strafe sem cair no chão.
                local vel = bestPart.AssemblyLinearVelocity
                local distance = (bestPart.Position - camPos).Magnitude
                local lead = math.clamp(distance / 1200, 0.008, 0.035)
                local aimPos = bestPart.Position + (vel * lead)

                local baseAlpha = 0.10
                    + (math.clamp(Config.AimbotStrength, 1, 20) / 20) * 0.55
                local speedBoost = math.clamp(vel.Magnitude / 60, 0, 0.35)
                local alpha = math.clamp(
                    (baseAlpha + speedBoost) * math.max(dt, 0.001) * 60,
                    0.05, 1
                )

                Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(camPos, aimPos), alpha)
                if FOVCircle then FOVCircle.Color = Color3.fromRGB(0, 255, 120) end
            elseif FOVCircle then
                FOVCircle.Color = Color3.fromRGB(255, 50, 50)
            end
        else
            State.lockChar = nil
            State.lockPlayer = nil
            if FOVCircle then FOVCircle.Color = Color3.fromRGB(255, 50, 50) end
        end

        --// ---------------- AUTO FIRE ----------------
        if Config.AutoFireEnabled and State.lockPart and char
            and State.screenDist <= 75 then
            local delay = Config.RapidFireEnabled and 0.04 or 0.12
            if os.clock() - State.lastShot >= delay then
                State.lastShot = os.clock()
                fireTool(char)
            end
        end

        --// ---------------- AUTO SWITCH ----------------
        if Config.AutoSwitchEnabled and char and backpack and hum then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and not isMedTool(tool) then
                local holder = tool:FindFirstChild("Ammo")
                    or tool:FindFirstChild("Clip")
                    or tool:FindFirstChild("Bullets")
                    or tool:FindFirstChild("StoredAmmo")
                    or tool:FindFirstChild("Mag")

                local empty = false
                if holder and (tonumber(holder.Value) or 1) <= 0 then
                    empty = true
                else
                    local n = tonumber(
                        tool:GetAttribute("Ammo") or tool:GetAttribute("Clip")
                    )
                    if n and n <= 0 then empty = true end
                end

                if empty then
                    for _, other in ipairs(backpack:GetChildren()) do
                        if other:IsA("Tool") and other ~= tool
                            and not isMedTool(other) then
                            pcall(function() hum:EquipTool(other) end)
                            break
                        end
                    end
                end
            end
        end

        --// ---------------- VOO ----------------
        if Config.FlyEnabled and root and hum then
            hum.PlatformStand = true
            local moveDir = hum.MoveDirection
            local dir = Vector3.zero

            if moveDir.Magnitude > 0 then
                dir = Cam.CFrame.LookVector * moveDir.Magnitude
            end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then
                dir += Vector3.new(0, 1, 0)
            end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                dir += Vector3.new(0, -1, 0)
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame += dir * Config.FlySpeed * dt
        end

        --// ---------------- KILL AURA ----------------
        if Config.KillAuraEnabled and root and char then
            if os.clock() - State.lastAura >= 0.1 then
                State.lastAura = os.clock()
                local hit = false

                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local pHum = p.Character:FindFirstChildOfClass("Humanoid")
                        local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        if pRoot and isTargetAliveAndStanding(p.Character, pHum) then
                            local teamOk = not Config.TeamCheck
                                or not LP.Team or p.Team ~= LP.Team
                            if teamOk and (root.Position - pRoot.Position).Magnitude <= 20 then
                                hit = true
                            end
                        end
                    end
                end

                if not hit then
                    for botChar in pairs(State.bots) do
                        if botChar.Parent and botChar ~= LP.Character then
                            local bHum = botChar:FindFirstChildOfClass("Humanoid")
                            local bRoot = botChar:FindFirstChild("HumanoidRootPart")
                                or botChar:FindFirstChild("Head")
                            if bRoot and isTargetAliveAndStanding(botChar, bHum)
                                and (root.Position - bRoot.Position).Magnitude <= 20 then
                                hit = true
                                break
                            end
                        end
                    end
                end

                if hit then fireTool(char) end
            end
        end
    end)
end)

table.insert(getgenv().RoyalityConns, getgenv().RoyalityLoop)

toast(
    "Royality Hub v18",
    usedFallback and "Rodando no painel simples (Rayfield falhou)."
        or "Carregado. Aimbot só puxa quando você atira.",
    5
)


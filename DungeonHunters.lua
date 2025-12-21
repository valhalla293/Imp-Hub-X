local function LoadWithBackup(primary, backup)
    local success, result = pcall(function() return loadstring(game:HttpGet(primary))() end)
    if success then return result end
    local backupSuccess, backupResult = pcall(function() return loadstring(game:HttpGet(backup))() end)
    if backupSuccess then return backupResult else error("Error loading UI Library") end
end

local repo = "https://raw.githubusercontent.com/Nanana291/Kong/refs/heads/main/"
local repo_backup = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = LoadWithBackup(repo .. "Library.lua", repo_backup .. "Library.lua")
local ThemeManager = LoadWithBackup(repo .. "ThemeManager.lua", "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/addons/ThemeManager.lua")
local SaveManager = LoadWithBackup("https://raw.githubusercontent.com/Nanana291/Lib/refs/heads/main/SaveManager.lua", repo_backup .. "addons/SaveManager.lua")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local AbilityBar = nil
if require then
    pcall(function()
        AbilityBar = require(ReplicatedStorage:WaitForChild("AbilityBar"):WaitForChild("Script"):WaitForChild("AbilityBarClientClass"))
    end)
end

local LocalPlayer = Players.LocalPlayer
local CharacterParts = {}
local CurrentTween = nil
local RecycleBin = Workspace:FindFirstChild("Recycle")

local DodgeAngle = 0
local CompletedDoors = {}
local ActiveNoclip = false
local DoingDoor = false

local Window = Library:CreateWindow({
    Title = "Imp Hub X",
    Footer = "Dungeon Hunters",
    Icon = 79000737943964,
    IconSize = UDim2.fromOffset(37.5, 37.5),
    NotifySide = "Right",
    CornerRadious = 6.5,
    DisableSearch = true,
    Compact = true,
    ShowCustomCursor = true,
})

local Options = Library.Options
local Toggles = Library.Toggles

local Tabs = {
    Dungeon = Window:AddTab({ Title = "Dungeon", Description = "Auto Farm", Icon = "swords" }),
    DSettings = Window:AddTab({ Title = "Dungeon Settings", Description = "Game Options", Icon = "settings-2" }),
    Lobby = Window:AddTab({ Title = "Lobby", Description = "Rewards & Shop", Icon = "home" }),
    Player = Window:AddTab({ Title = "Player", Description = "Speed & Jump", Icon = "user" }),
    About = Window:AddTab({ Title = "About", Description = "Info", Icon = "info" }),
    Settings = Window:AddTab({ Title = "UI Settings", Description = "Theme", Icon = "wrench" }),
}

local function RefreshCharacterParts()
    table.clear(CharacterParts)
    if LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then
                table.insert(CharacterParts, v)
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    RefreshCharacterParts()
end)

local function EnableNoclip(state)
    ActiveNoclip = state
    if state then RefreshCharacterParts() end
end

RunService.Stepped:Connect(function()
    if ActiveNoclip then
        for _, part in ipairs(CharacterParts) do
            if part and part.Parent then
                part.CanCollide = false
            end
        end
    end
end)

local function GetClosestMob()
    local creature = Workspace:FindFirstChild("Creature")
    if not creature then return nil end
    local activation = creature:FindFirstChild("Activation")
    if not activation then return nil end

    if not RecycleBin then RecycleBin = Workspace:FindFirstChild("Recycle") end

    local closestMob = nil
    local minDistance = Options.MaxDistance.Value
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if not myRoot then return nil end

    for _, group in pairs(activation:GetChildren()) do
        if group:IsA("Model") then
            for _, mob in pairs(group:GetChildren()) do
                if RecycleBin and mob:IsDescendantOf(RecycleBin) then return end
                if mob:GetAttribute("InRecycle") == true then return end

                if Players:GetPlayerFromCharacter(mob) then return end 

                if mob:GetAttribute("UId") and mob ~= myChar then
                    local root = mob:FindFirstChild("HumanoidRootPart")
                    local hum = mob:FindFirstChild("Humanoid")
                    
                    if root and hum and hum.Health > 0 then
                        local dist = (myRoot.Position - root.Position).Magnitude
                        if dist <= minDistance then
                            minDistance = dist
                            closestMob = mob
                        end
                    end
                end
            end
        end
    end
    return closestMob
end

local function AttackMob(mob)
    if not mob then return end
    if AbilityBar then
        pcall(function() AbilityBar:CastAbility(LocalPlayer, 1) end)
    end
end

local function CancelTween()
    if CurrentTween then
        CurrentTween:Cancel()
        CurrentTween = nil
    end
end

local function ServerHop()
    local placeId = game.PlaceId
    local servers = {}
    local cursor = ""
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local raw = game:HttpGet(url .. ((cursor and "&cursor="..cursor) or ""))
        return HttpService:JSONDecode(raw)
    end

    local serverList = ListServers(cursor)
    if serverList.data then
        for _, server in ipairs(serverList.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(servers, server.id)
            end
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)], LocalPlayer)
    else
        Library:Notify({Title="Server Hop", Description="No servers found, retrying...", Type="error", Time=3})
    end
end

local FarmGroup = Tabs.Dungeon:AddLeftGroupbox("Auto Farm", "sword") 
FarmGroup:AddToggle("EnableFarm", { Text = "Enable Auto Farm", Default = false })

FarmGroup:AddSlider("TravelSpeed", { Text = "Move Speed", Default = 60, Min = 16, Max = 150, Rounding = 0, Suffix = " Speed" })
FarmGroup:AddDropdown("TweenStyle", { Values = { "Linear", "Sine", "Quad", "Quart", "Exponential" }, Default = 1, Text = "Movement Style" })

FarmGroup:AddSlider("AttackDelay", { Text = "Attack Speed", Default = 0.5, Min = 0.1, Max = 3, Rounding = 1, Suffix = "s" })
FarmGroup:AddSlider("MaxDistance", { Text = "Scan Range", Default = 125, Min = 100, Max = 500, Rounding = 0, Suffix = " Range" })

FarmGroup:AddDivider()

FarmGroup:AddToggle("BossCustomTP", { Text = "Smart Boss Position", Default = true })
FarmGroup:AddSlider("BossDistance", { Text = "Boss Distance", Default = 25, Min = 15, Max = 60, Rounding = 1 })
FarmGroup:AddToggle("DodgeEnabled", { Text = "Auto Dodge", Default = false })
FarmGroup:AddSlider("DodgeSpeed", { Text = "Dodge Speed", Default = 5, Min = 1, Max = 20, Rounding = 1 })
FarmGroup:AddSlider("DodgeRadius", { Text = "Dodge Distance", Default = 10, Min = 5, Max = 25, Rounding = 1 })

local StatusInfo = FarmGroup:AddParagraph({ Text = "Status", Content = "Idle" })

local SkillsGroup = Tabs.Dungeon:AddLeftGroupbox("Auto Skills", "zap")
SkillsGroup:AddToggle("UseSkills", { Text = "Enable Auto Skills", Default = false })
SkillsGroup:AddDropdown("SkillSlots", { Values = { "1", "2", "3", "4", "5" }, Default = 1, Multi = true, Text = "Select Slots" })
SkillsGroup:AddToggle("UseAllSkills", { Text = "Use All Slots (1-5)", Default = false })
SkillsGroup:AddSlider("SkillDelay", { Text = "Cast Delay", Default = 1, Min = 0.1, Max = 5, Rounding = 1 })

local DoorsGroup = Tabs.Dungeon:AddRightGroupbox("Dungeon Doors", "door-open")
DoorsGroup:AddToggle("AutoDoors", { Text = "Auto Vote Doors", Default = false })
DoorsGroup:AddButton({ Text = "Reset Door Glitch", Func = function() CompletedDoors = {} Library:Notify({Title="Doors", Description="Fixed", Type="info", Time=2}) end, DoubleClick = true })

local AuraGroup = Tabs.Dungeon:AddRightGroupbox("Kill Aura", "skull")
AuraGroup:AddToggle("KillAura", { Text = "Enable Kill Aura", Default = false })
AuraGroup:AddSlider("AuraRange", { Text = "Aura Range", Default = 20, Min = 5, Max = 100, Rounding = 0 })

local CardsGroup = Tabs.DSettings:AddLeftGroupbox("Perks", "credit-card")
CardsGroup:AddToggle("AutoCards", { Text = "Auto Pick Cards", Default = false })

local EndingGroup = Tabs.DSettings:AddRightGroupbox("Ending", "flag")
EndingGroup:AddToggle("AutoReplay", { Text = "Auto Replay", Default = false })
EndingGroup:AddToggle("AutoLobby", { Text = "Auto Return Lobby", Default = false })

local QuestGroup = Tabs.Lobby:AddLeftGroupbox("Rewards", "gift")
QuestGroup:AddToggle("AutoQuests", { Text = "Claim Daily Rewards", Default = false })

local SummonGroup = Tabs.Lobby:AddLeftGroupbox("Gacha", "gem")
SummonGroup:AddDropdown("SummonMode", { Values = {"x1", "x10"}, Default = 1, Multi = false, Text = "Amount" })
SummonGroup:AddToggle("AutoSummon", { Text = "Auto Roll Weapon", Default = false })

local EquipGroup = Tabs.Lobby:AddRightGroupbox("Inventory", "shield")
EquipGroup:AddToggle("AutoEquipWeapon", { Text = "Auto Best Weapon", Default = false })
EquipGroup:AddToggle("AutoEquipArmor", { Text = "Auto Best Armor", Default = false })
EquipGroup:AddToggle("AutoEquipOrnament", { Text = "Auto Best Ring", Default = false })

local PlayerGroup = Tabs.Player:AddLeftGroupbox("Character", "run")
PlayerGroup:AddToggle("EnableWalkSpeed", { Text = "Speed Hack", Default = false })
PlayerGroup:AddSlider("WalkSpeed", { Text = "Speed", Default = 16, Min = 16, Max = 200, Rounding = 0 })

PlayerGroup:AddToggle("EnableJumpPower", { Text = "Jump Hack", Default = false })
PlayerGroup:AddSlider("JumpPower", { Text = "Jump Height", Default = 50, Min = 50, Max = 500, Rounding = 0 })

local MiscGroup = Tabs.Player:AddRightGroupbox("Tools", "monitor")
MiscGroup:AddToggle("AntiAFK", { Text = "Anti-AFK", Default = true })
MiscGroup:AddButton({ Text = "Server Hop", Func = function() ServerHop() end })
MiscGroup:AddButton({ Text = "Rejoin Game", Func = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
MiscGroup:AddButton({ Text = "Boost FPS", Func = function() 
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end
    end
    Library:Notify({Title="Graphics", Description="FPS Boosted", Type="success", Time=3})
end })

local AboutInfo = Tabs.About:AddLeftGroupbox("Information", "info")

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then
        local executor = identifyexecutor()
        if executor:lower():find("delta") then
            executorName = "Delta"
        else
            executorName = executor
        end
    end
end)

AboutInfo:AddLabel("Imp Hub X Version: V1.0", true)
AboutInfo:AddLabel("Script Version: V1.0", true)
AboutInfo:AddLabel("UI Library: Obsidian", true)
AboutInfo:AddLabel("User Executor: " .. executorName, true)
AboutInfo:AddDivider()
AboutInfo:AddLabel("Developer: alan11ago", true)
AboutInfo:AddDivider()
AboutInfo:AddLabel("Upcoming Features:", true)
AboutInfo:AddLabel("Webhooks System.", true)

local DiscordInfo = Tabs.About:AddRightGroupbox("Community", "message-circle")

DiscordInfo:AddLabel("Join for:", true)
DiscordInfo:AddLabel("- Free Lifetime Key", true)
DiscordInfo:AddLabel("- Buy Permanent Keys", true)
DiscordInfo:AddLabel("- Giveaways & Events", true)
DiscordInfo:AddLabel("- Bug Reports", true)

DiscordInfo:AddButton({
    Text = "Copy Discord Link",
    Func = function()
        setclipboard("https://dsc.gg/imphub")
        Library:Notify({ Title = "Imp Hub X", Description = "Link Copied!", SubText = "Community", Type = "success", Icon = "clipboard-check", Time = 4, Closable = true })
    end,
})

RunService.Heartbeat:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hum = LocalPlayer.Character.Humanoid
        local root = LocalPlayer.Character.HumanoidRootPart
        
        if Toggles.EnableWalkSpeed.Value then
            if hum.MoveDirection.Magnitude > 0 then
                root.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * Options.WalkSpeed.Value,
                    root.AssemblyLinearVelocity.Y,
                    hum.MoveDirection.Z * Options.WalkSpeed.Value
                )
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Toggles.EnableJumpPower.Value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(
                LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity.X,
                Options.JumpPower.Value,
                LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity.Z
            )
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if Toggles.AntiAFK.Value then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if Toggles.AutoQuests.Value then
            for i = 1, 11 do 
                pcall(function() game:GetService("ReplicatedStorage").Quest.Remote.ApplyDailyQuestReward:InvokeServer(tostring(i)) end) 
            end
            Library:Notify({Title="Quests", Description="Claiming Rewards...", Type="success", Time=1})
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1) 
        if Toggles.AutoSummon.Value then
            pcall(function()
                local mode = Options.SummonMode.Value == "x10" and 2 or 1
                game:GetService("ReplicatedStorage").WeaponShop.Remote.ApplyLotteryWeapon:InvokeServer(3, mode)
                Library:Notify({Title="Gacha", Description="Rolling Weapon...", Type="info", Time=0.5})
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if Toggles.AutoEquipWeapon.Value then 
            pcall(function() game:GetService("ReplicatedStorage").EquipmentSystem.Remote.AutoEquipBestWeapons:InvokeServer() end)
            Library:Notify({Title="Equip", Description="Best Weapon Equipped", Type="success", Time=1})
        end
        if Toggles.AutoEquipArmor.Value then 
            pcall(function() game:GetService("ReplicatedStorage").EquipmentSystem.Remote.AutoEquipBestArmors:InvokeServer() end)
            Library:Notify({Title="Equip", Description="Best Armor Equipped", Type="success", Time=1})
        end
        if Toggles.AutoEquipOrnament.Value then 
            pcall(function() game:GetService("ReplicatedStorage").EquipmentSystem.Remote.AutoEquipBestOrnament:InvokeServer() end)
            Library:Notify({Title="Equip", Description="Best Ring Equipped", Type="success", Time=1})
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(Options.SkillDelay.Value)
        if Toggles.UseSkills.Value and AbilityBar then
            local slotsToCast = {}
            if Toggles.UseAllSkills.Value then slotsToCast = {1, 2, 3, 4, 5}
            else
                for slotStr, active in pairs(Options.SkillSlots.Value) do if active then table.insert(slotsToCast, tonumber(slotStr)) end end
            end
            for _, slot in ipairs(slotsToCast) do pcall(function() AbilityBar:CastAbility(LocalPlayer, slot) end) task.wait(0.05) end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if Toggles.EnableFarm.Value and not DoingDoor then
            local mob = GetClosestMob()
            local char = LocalPlayer.Character
            
            if mob and char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                local currentTarget = mob
                StatusInfo:SetText("Target: " .. mob.Name)
                EnableNoclip(true)
                
                local searchTick = tick()

                while Toggles.EnableFarm.Value and not DoingDoor and mob and mob.Parent and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 do
                    
                    if tick() - searchTick > 0.5 then
                        local potentialNew = GetClosestMob()
                        if potentialNew and potentialNew ~= currentTarget then break end
                        
                        if RecycleBin and mob:IsDescendantOf(RecycleBin) then break end
                        if mob:GetAttribute("InRecycle") == true then break end
                        
                        searchTick = tick()
                    end

                    local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                    if not mobRoot then break end

                    local targetCFrame = mobRoot.CFrame
                    local useDodge = false
                    local currentRadius = Options.DodgeRadius.Value

                    if string.find(mob.Name:lower(), "boss") and Toggles.BossCustomTP.Value then
                        useDodge = true
                        currentRadius = Options.BossDistance.Value
                    elseif Toggles.DodgeEnabled.Value then
                        useDodge = true
                    end

                    if useDodge then
                        DodgeAngle = DodgeAngle + (Options.DodgeSpeed.Value * 0.05)
                        local offsetX = math.cos(DodgeAngle) * currentRadius
                        local offsetZ = math.sin(DodgeAngle) * currentRadius
                        targetCFrame = targetCFrame * CFrame.new(offsetX, 0, offsetZ)
                        targetCFrame = CFrame.new(targetCFrame.Position, mobRoot.Position)
                    end

                    local distance = (root.Position - targetCFrame.Position).Magnitude
                    local speed = Options.TravelSpeed.Value
                    local tweenTime = distance / speed
                    
                    if tweenTime < 0.1 then tweenTime = 0.1 end

                    local tInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[Options.TweenStyle.Value], Enum.EasingDirection.Out)
                    CancelTween()
                    CurrentTween = TweenService:Create(root, tInfo, {CFrame = targetCFrame})
                    CurrentTween:Play()
                    
                    if not useDodge then 
                        task.wait(tweenTime * 0.8) 
                    end

                    AttackMob(mob)
                    task.wait(Options.AttackDelay.Value)
                end
                CancelTween()
                StatusInfo:SetText("Scanning...")
            else
                StatusInfo:SetText("Searching...")
                if not DoingDoor then EnableNoclip(false) end
                task.wait(0.2)
            end
        else
            if not DoingDoor then 
                StatusInfo:SetText("Idle")
                if not Toggles.EnableFarm.Value then EnableNoclip(false) end
            else
                StatusInfo:SetText("Paused (Door)")
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if Toggles.AutoCards.Value then
            pcall(function() for i = 1, 50 do game:GetService("ReplicatedStorage").Perk.Remote.ReqPlayerSelectPerk:InvokeServer(tostring(i)) end end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if Toggles.AutoReplay.Value or Toggles.AutoLobby.Value then
            local gui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndingGui")
            if gui and gui.Enabled then
                if Toggles.AutoReplay.Value then
                    pcall(function() game:GetService("ReplicatedStorage").Dungeon.Remote.RequestReplayDungeon:InvokeServer() end)
                    Library:Notify({ Title = "Ending", Description = "Replaying...", Time = 3 })
                    task.wait(5)
                elseif Toggles.AutoLobby.Value then
                    pcall(function() game:GetService("ReplicatedStorage").Dungeon.Remote.RequestReturnToLobby:InvokeServer() end)
                    Library:Notify({ Title = "Ending", Description = "Lobby...", Time = 3 })
                    task.wait(5)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5) 
        if Toggles.AutoDoors.Value then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local sandbox = Workspace:FindFirstChild("SandboxPlayFolder")
            if root and sandbox then
                for _, obj in ipairs(sandbox:GetDescendants()) do
                    if obj.Name == "DOOR" and obj:FindFirstChild("UPUI") then
                        if not CompletedDoors[obj] then
                            DoingDoor = true 
                            EnableNoclip(true)
                            CancelTween()
                            Library:Notify({ Title = "Auto Doors", Description = "Voting...", Type = "info", Time = 1 })
                            local tween = TweenService:Create(root, TweenInfo.new(1), {CFrame = obj.UPUI.CFrame})
                            tween:Play() tween.Completed:Wait()
                            task.wait(1.5) 
                            CompletedDoors[obj] = true
                            DoingDoor = false 
                            Library:Notify({ Title = "Auto Doors", Description = "Resumed", Type = "success", Time = 2 })
                            if not Toggles.EnableFarm.Value then EnableNoclip(false) end
                            break 
                        end
                    end
                end
            end
        else
            DoingDoor = false
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(Options.AttackDelay.Value)
        if Toggles.KillAura.Value and not Toggles.EnableFarm.Value and not DoingDoor then
            local mob = GetClosestMob()
            if mob then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                if root and mobRoot then
                    if (root.Position - mobRoot.Position).Magnitude <= Options.AuraRange.Value then
                        AttackMob(mob)
                    end
                end
            else
                task.wait(0.5)
            end
        end
    end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ImpHub")
SaveManager:SetFolder("ImpHub/DungeonHunters")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:Notify({
    Title = "Imp Hub X",
    Description = "Loaded Successfully.",
    SubText = "Dungeon Hunters",
    Type = "success",
    Icon = "check-circle",
    Time = 5
})

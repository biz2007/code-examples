-- Project: Dealership Service
-- Author: biz / bluware
-- Details: Vehicle Dealership Handler
-- Date: 26/03/2024
-- Version: 0.1


-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TouchInputService = game:GetService("TouchInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Utility Modules
local Net = require(ReplicatedStorage.UtilityModules.Net)
local SearchIndex = require(ReplicatedStorage.Framework.Utility.SearchIndex)

-- Networking
local DealershipEvent
local DealershipInformation

local DealershipService = {}
local DealershipServiceCooldown = {}
local DealershipSpawn = {}
local DataManager = require(ServerScriptService.GameFramework.DataFramework.DataManager)

-- Variables
local ProfileManager = require(ServerScriptService.GameFramework.DataFramework.ProfileManager)
local DealershipFramework = ReplicatedStorage.Framework.SharedFrameworks.DealershipFramework
local Vehicles = DealershipFramework.Vehicles
local VehiclesFolder = workspace.Vehicles

-- Vehicle Modules
local ColourVehicle
local GetVehicle

-- Utilities
local SearchIndex = require(ReplicatedStorage.Framework.Utility.SearchIndex)
local DeepCopy = require(ReplicatedStorage.Framework.Utility.DeepCopy)

-- Vehicle Local Functions



function DealershipService:Start()
    ColourVehicle = require(ReplicatedStorage.Framework.SharedFrameworks.DealershipFramework.ColourVehicle)
    GetVehicle = require(ReplicatedStorage.Framework.SharedFrameworks.DealershipFramework.GetVehicle)
    
	DealershipEvent = Net:RemoteEvent("DealershipEvent")
	DealershipInformation = Net:RemoteFunction("DealershipInformation")

	Net:Handle("DealershipInformation", function(Player)
		local Profile = DataManager:GetProfile(Player)
		return Profile
	end)

    Net:Connect("DealershipEvent", function(Player: Player, EventType: string, SelectedVehicle, ...)
       if DealershipServiceCooldown[Player] then return end
       DealershipServiceCooldown[Player] = Player
		if EventType == "PurchaseVehicle" then
			local Profile = DataManager:GetProfile(Player)
			local getVehicle = Vehicles.Civilian:FindFirstChild(SelectedVehicle.Name)
			local selectedVehicleColour = ...

			if not getVehicle and Player.PlayerData.Wallet.Value < getVehicle:GetAttribute("VehiclePrice") then
				return
			end
			if getVehicle.Name == SearchIndex(Profile.VehicleData, getVehicle.Name) then
				return
			end
			local VehicleProfile = DeepCopy(require(script.VehicleTemplate))
			VehicleProfile.VehicleOwner = Player.Name
			VehicleProfile.VehiclePrice = getVehicle:GetAttribute("VehiclePrice")
			VehicleProfile.VehicleColour = `{selectedVehicleColour}`

			Profile["VehicleData"][SelectedVehicle.Name] = VehicleProfile
			DataManager:SubtractMoney(Player, "Wallet", VehicleProfile.VehiclePrice, Profile)
			task.wait(2)
			ProfileManager:SaveProfile(true, Player, Profile)
			-- ProfileManager:SaveProfile(true, Player, Profile)
			--      DataManager:AddData(Player, "VehicleData", nil, SelectedVehicle.Name)
		elseif EventType == "SellVehicle" then
			local Profile = DataManager:GetProfile(Player)
			local getVehicle = Vehicles.Civilian:FindFirstChild(SelectedVehicle.Name)
			if
				not getVehicle
				and getVehicle:GetAttribute("VehiclePrice") == Profile["VehicleData"][getVehicle.Name]
			then
				return
			end
			if getVehicle.Name ~= SearchIndex(Profile.VehicleData, getVehicle.Name) then
				return
			end

			Profile.VehicleData[getVehicle.Name] = nil
			DataManager:AddMoney(Player, "Wallet", getVehicle:GetAttribute("VehiclePrice") * 0.7, Profile)
			print(Profile)
			task.wait(2)
            ProfileManager:SaveProfile(true, Player, Profile)
            
            if GetVehicle(Player) ~= nil then
                Debris:AddItem(GetVehicle(Player), 0)
            end
        elseif EventType == "SpawnVehicle" then
            
            if DealershipSpawn[Player] then return end
            DealershipSpawn[Player] = Player
			local EventArgs = { ... }
			local GetPart = EventArgs[1] :: BasePart
            local SelectedVehicleColour = EventArgs[2] :: {}
            
            local vR, vG, vB = math.round(SelectedVehicleColour[1]), math.round(SelectedVehicleColour[2]), math.round(SelectedVehicleColour[3])
            local GetRGB = Color3.fromRGB(vR, vG, vB)
            print(GetRGB)

			local PartLocations = GetPart:FindFirstChild("Locations") :: Folder

			local getVehicle = Vehicles:FindFirstChild(Player.Team.Name):FindFirstChild(SelectedVehicle.Name) :: Model
			assert(getVehicle, "Selected Vehicle does not exist")


            local function SetVehicleSpawn(RandomSpawn: BasePart, CurrentVehicle: Model)
                assert(CurrentVehicle, 'Current Vehicle does not exist')
                CurrentVehicle:PivotTo(RandomSpawn.CFrame)
                RandomSpawn:SetAttribute("Occupied", true)
                task.delay(10, function()
                    RandomSpawn:SetAttribute("Occupied", false)
                end)
            end

            local function RandomiseVehicleSpawn()
                assert(PartLocations, 'Part Locations does not exist')
                local Part = PartLocations:GetChildren()[math.random(1, #PartLocations:GetChildren())]
                if Part:GetAttribute("Occupied") == true then
                    RandomiseVehicleSpawn(PartLocations)
                    return
                end
                return Part
            end
            
            if GetPart and PartLocations then
                local CURRENT_VEHICLE = GetVehicle(Player)
                local RandomSpawn = RandomiseVehicleSpawn() :: BasePart
                
                if CURRENT_VEHICLE ~= nil and CURRENT_VEHICLE.Name == getVehicle.Name then 
                    SetVehicleSpawn(RandomSpawn, CURRENT_VEHICLE)
                elseif CURRENT_VEHICLE ~= getVehicle.Name then
                    if getVehicle ~= nil then Debris:AddItem(CURRENT_VEHICLE, 0) end
                    
                    local playerVehicle = getVehicle:Clone()
                    playerVehicle:SetAttribute("VehicleOwner", Player.Name)
                    SetVehicleSpawn(RandomSpawn, playerVehicle)
                    ColourVehicle(playerVehicle, GetRGB)
                    playerVehicle.Parent = VehiclesFolder
                end
            end
            task.wait(1)
            DealershipSpawn[Player] = nil
        elseif EventType == 'DespawnVehicle' then
            if GetVehicle(Player) ~= nil then
                Debris:AddItem(GetVehicle(Player), .3)
            end
        end
        task.wait(.5)
        DealershipServiceCooldown[Player] = nil
	end)
end
return DealershipService

--
-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.TrunkFramework.Remotes
local InitializeEvent = Remotes.InitializeEvent
local Update = Remotes.Update

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Classes = { -- list every class which has to do with value here
	"IntValue",
	"BoolValue",
	"StringValue",
	"NumberValue",
}


local function getClass(data)
	for i, v in pairs(Classes) do
		if string.find(v:lower(), data:lower()) then
			return v
		elseif data == "Number" then
			return "IntValue"
		elseif data == "Boolean" then
			return "BoolValue"

		end
	end
end

local TrunkFramework = {}


TrunkFramework.__index = TrunkFramework

TrunkFramework.ToolClasses = {
	["Misc"] = "rbxassetid://16487024084",
	["Knife"] = "rbxassetid://16486900474",
	["Gun"] = "rbxassetid://16486913721",
}
TrunkFramework.Vehicles = game:GetService("ReplicatedStorage").TrunkFramework.Vehicles

-- Server

function TrunkFramework.CreateTrunk(model)
	if RunService:IsServer() then
		print('Trunk Framework is running on server')
		local self = setmetatable({}, TrunkFramework)
		self.Vehicle = model
		self.Prompt = nil
		self.WeightLimit = 8
		self.CurrentWeight = 0
		self.OwnerValue	= ""

		-- Functions
		local function createPrompt()
			if model:IsA("Part") then
				local template = Instance.new("ProximityPrompt", self.Vehicle)
				template.ActionText = "Open Trunk"
				template.HoldDuration = 3
				template.RequiresLineOfSight = true
				template.MaxActivationDistance = 5

				return template
			end
		end

		local function createTrunkProperties(trunk)
			if  (self.Vehicle == nil or self.Prompt == nil) then return end
			if (self.Vehicle:IsA("Part")) then self.Vehicle.Name = string.format("%s's Trunk", self.OwnerValue) end
			if (game:GetService("Players")[self.OwnerValue]:FindFirstChild("TrunkStorage")) then return end
			print('creating properties')
			local trunkStorage = Instance.new("Folder")
			local attributes = {
				["CurrentWeight"] = self.CurrentWeight;
				["WeightLimit"] = self.WeightLimit;
				["OwnerValue"] = self.OwnerValue;

			}
			
			local classes = {
				"BoolValue"
			}

			trunkStorage.Name = "TrunkStorage"
			trunkStorage.Parent = game:GetService("Players")[self.OwnerValue]

			for str, val in pairs(attributes) do
				local getData = string.lower(type(val))
				local finalizeData = getData:sub(1, 1):upper()..getData:sub(2, -1)
				local getClass = getClass(finalizeData)
				local getProperty = Instance.new(getClass)
				getProperty.Value = val
				getProperty.Name = str
				getProperty.Parent = trunkStorage
				print('successfully set trunk attributes')
			end


		end

		local function openTrunk(player)
			if (tostring(player) == self.OwnerValue) or (self.OwnerValue == "claimType") then
				-- check if player has trunkstorage already
				
				if (self.OwnerValue == "claimType") then self.OwnerValue = player.Name end
				if player:FindFirstChild("TrunkStorage") then
					for i, v in pairs(player:FindFirstChild("TrunkStorage"):GetChildren()) do
						if v:IsA("BaseValue") then
						self[i] = v.Value  
						end
					end
				end
				print("Player: "..tostring(player), "Owner: "..self.OwnerValue)
				if (player.PlayerGui:FindFirstChild("TrunkUI")) then return end
				local trunkUI = game:GetService("ServerScriptService").TrunkServer.TrunkUI
				trunkUI:Clone().Parent = player.PlayerGui

				local playerUI = player.PlayerGui:WaitForChild("TrunkUI")
				InitializeEvent:FireClient(player, "Load")
				createTrunkProperties()
				print('loaded')
			else
				print('No access')
			end
		end

		if (self.Vehicle:FindFirstChildOfClass("ProximityPrompt")) then
			local prompt = self.Vehicle:FindFirstChildOfClass("ProximityPrompt")
			self.Prompt = prompt

			prompt.Triggered:Connect(function(player)
				openTrunk(player)
			end)

		else
			if (self.Vehicle:FindFirstChildOfClass("ProximityPrompt")) then return end
			local prompt = createPrompt()
			self.Prompt = prompt
			prompt.Triggered:Connect(function(player)
				openTrunk(player)
			end)
		end


		return self
	end
end

function TrunkFramework:SetVehicle(vehicle)
	self.Vehicle = vehicle
end

function TrunkFramework:SetPrompt(prompt)
	self.Prompt = prompt
end

function TrunkFramework:SetLimit(int)
	self.WeightLimit = tonumber(int)
end

function TrunkFramework:SetOwner(str) 
	self.OwnerValue = str
end



return TrunkFramework
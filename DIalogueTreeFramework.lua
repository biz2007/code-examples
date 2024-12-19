-- biz
-- Made using Knit Framework
-- Services
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Player Variables
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- Modules
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Maid = require(Knit.Util.Maid)

-- Utilities
local CoreCall = require(Players.LocalPlayer.PlayerScripts.Knit.Modules.CoreCall)
local SetBind = require(ReplicatedStorage.Knit.Utilities.SetBind)
local Controls

-- Misc
local GuiStorage = ReplicatedStorage.Storage.GuiStorage

local DialogueController = Knit.CreateController({ Name = "DialogueController" })
DialogueController.__index = DialogueController

--- Types & Tables
DialogueController.Template = {
	NPCTitle = "",
	NPCReputation = 0,
	DialogueType = "",
	DialogueText = "",
	Options = {
		{
			Keybind = Enum.KeyCode.One,
			Description = "I'm In",
		},
		{
			Keybind = Enum.KeyCode.Two,
			Description = "Leave conversation",
		},
	},
}

function DialogueController:KnitStart()
	-- Utilities
	Controls = require(Player.PlayerScripts.PlayerModule):GetControls()
end

function DialogueController:KnitInit() end

function DialogueController:SetCamera(cameraType: Enum.CameraType, cameraPart: Part)
	assert(cameraType, "Camera type is not available")
	local CurrentCamera = self.CurrentCamera
	CurrentCamera.CameraType = cameraType
	CurrentCamera.CFrame = cameraPart.CFrame
end

function DialogueController:TweenCamera(part: BasePart, cameraType: Enum.CameraType)
	local createTween = TweenService:Create(self.CurrentCamera, TweenInfo.new(1), { CFrame = part.CFrame })
	createTween:Play()
	createTween.Completed:Connect(function()
		self:SetCamera(cameraType, part)
	end)
end

function DialogueController:CreateCamera()
	assert(self.NPCObject, "NPC Object does not exist")
	self.DialogueCamera = Instance.new("Part")
	self.DialogueCamera.Name = "DialogueCamera"
	self.DialogueCamera.Anchored = true
	self.DialogueCamera.Size = Vector3.new(1, 1, 1)
	self.DialogueCamera.CanCollide = false
	self.DialogueCamera.Transparency = 1
	self.DialogueCamera.CFrame = CFrame.new(
		self.NPCObject.Head.CFrame:PointToWorldSpace(Vector3.new(0, -0.2, -3)),
		self.NPCObject.Head.Position - self.NPCObject.Head.CFrame.LookVector
	)
	self._Maid:GiveTask(self.DialogueCamera)
end

function DialogueController.New(npcObject: Model, dialogueSettings: {})
	-- Conditions before creating dialogue object
	if Player.PlayerGui:FindFirstChild("DialogueUI") and not npcObject:IsA("Model") then
		return
	end

	local self = setmetatable({}, DialogueController)

	-- Create maid object
	self._Maid = Maid.new()

	-- Create NPC objects & dialogue settings
	self.NPCObject = npcObject
	self.DialogueSettings = TableUtil.Reconcile(dialogueSettings, self.Template)
	self.DialogueOptions = self.DialogueSettings.Options
	self.CurrentCamera = workspace.CurrentCamera

	-- Dialogue Interface
	self.DialogueUI = GuiStorage.DialogueUI:Clone()
	self.DialogueUI.Parent = Player.PlayerGui
	self.DialogueMainFrame = self.DialogueUI.MainFrame
	self.DialogueStorage = self.DialogueUI.Storage

	-- Set Dialogue Interface
	self.DialogueMainFrame.NPCTitle.Text = self.DialogueSettings.NPCTitle
	self.DialogueMainFrame.NPCReputation.Text = `{self.DialogueSettings.NPCReputation} REP`
	self.DialogueMainFrame.DialogueType.Text = self.DialogueSettings.DialogueType
	self.DialogueMainFrame.DialogueFrame.DialogueText.Text = self.DialogueSettings.DialogueText
	TableUtil.Find(self.DialogueOptions, function(value, key)
		local CreateOption = self.DialogueStorage.Option:Clone()
		CreateOption.Name = `{key}`
		CreateOption.Keybind.Text = UserInputService:GetStringForKeyCode(value.Keybind)
		CreateOption.Description.Text = value.Description
		CreateOption.Parent = self.DialogueMainFrame.OptionsFrame

		-- Set up signals for dialogue options
		self[`Option {key}`] = Signal.new()
		self._Maid:GiveTask(self[`Option {key}`])

		SetBind(`Option {key}`, value.Keybind, function()
			if self[`Option {key}`] then
				self[`Option {key}`]:Fire()
			end
		end)
	end)

	-- Create camera object
	self:CreateCamera()

	-- Load Functions
	Controls:Disable()
	Humanoid:UnequipTools()
	CoreCall:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	return self
end

function DialogueController:Start()
	self:TweenCamera(self.DialogueCamera, Enum.CameraType.Scriptable)
	task.defer(function()
		self.DialogueMainFrame:TweenPosition(
			UDim2.fromScale(0.334, 0.674),
			Enum.EasingDirection.In,
			Enum.EasingStyle.Linear,
			0.5,
			true,
			nil)		
	end)
end

function DialogueController:Stop()
	self.DialogueMainFrame:TweenPosition(
		UDim2.fromScale(0.334, 1),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Linear,
		0.5,
		true,
		nil)
	self:SetCamera(Enum.CameraType.Custom, Character.Head)
	self:Clean()
end

function DialogueController:Clean()
	self._Maid:DoCleaning()
	self.DialogueUI = nil
	Controls:Enable()
	CoreCall:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	for key, _ in pairs(self.DialogueOptions) do
		ContextActionService:UnbindAction(`Option {key}`)
	end
end

return DialogueController

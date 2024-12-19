--!strict
-- biz // 25/3/2024
-- PromptAnimations

-- Services
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules
local ClientModules = ReplicatedStorage.Framework.ClientModules
local FadeUIModule = require(ClientModules.FadeUI)
local UIAnimations = require(ClientModules.UIAnimations)

-- Utility
local Utility = ReplicatedStorage.Framework.Utility
local assert = require(Utility.Assert)

local UtilityModules = game:GetService("ReplicatedStorage").UtilityModules
local Promise = require(UtilityModules.Promise)

-- Variables
local CurrentCamera

-- Player Variables
local Player = PlayerService.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

-- Local Functions
local function FadeCallback(...)
    assert({...}, 'Variadic table does not exist')
    local self: (any), frame: (Frame), cameraPart: (BasePart), cameraType: (Enum.CameraType) = table.unpack({...})
    FadeUIModule:FadeIn(frame, 0.5)
    Promise.try(function()
        self:SetCamera(cameraType, cameraPart)
    end)
    FadeUIModule:FadeOut(frame, 0.5)
    return true
end

local function Interface(bool: boolean)
    Promise.try(function()
        for i, v in pairs(Player.PlayerGui:GetChildren())  do
            if v:IsA("ScreenGui") and v.Name ~= "FadeUI" then
                v.Enabled = bool
            end
        end
    end)
end

-- Prompt Animations
local PromptAnimations = {}

function PromptAnimations:SetCamera(cameraType: Enum.CameraType, cameraPart: Part)
    assert(cameraType, "Camera type is not available")
    repeat
        task.wait()
        CurrentCamera.CameraType = cameraType
    until CurrentCamera.CameraType == cameraType
    CurrentCamera.CFrame = cameraPart.CFrame
end

function PromptAnimations:FadeCamera(cameraPart: Part, cameraType: string, callback)
    -- variables
    CurrentCamera = workspace.CurrentCamera:: Camera
    local FadeUI = Player.PlayerGui:WaitForChild("FadeUI") :: ScreenGui
    local FadeFrame = FadeUI:WaitForChild('Frame') :: Frame
    local Completed = false

    Interface(false)
    
    assert(CurrentCamera, "Cannot find camera in workspace")
    assert(cameraPart, "Camera Part does not exist")
    assert(FadeUI, "Fade User Interface does not exist")

    if cameraType == "Start" then
        Completed = FadeCallback(self, FadeFrame, cameraPart, Enum.CameraType.Scriptable)
    elseif cameraType == "End" then
        Completed = FadeCallback(self, FadeFrame, Character.PrimaryPart, Enum.CameraType.Custom)
        Interface(true)
    end

    Completed = true and callback()
end

return PromptAnimations
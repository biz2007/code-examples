-- Project: Interactions Wrapper
-- Author: biz / bluware
-- Details: Wraps Interactions on the server for prompting
-- Date: 30/03/2024
-- Version: 0.1

-- Services
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Shared Framework
local Framework = ReplicatedStorage.Framework

local UtilityModules = game:GetService("ReplicatedStorage").UtilityModules
local Promise = require(UtilityModules.Promise)
local Janitor = require(UtilityModules.Janitor)
local Net = require(ReplicatedStorage.UtilityModules.Net)

local Utility = Framework.Utility
local assert = require(Utility.Assert)

-- Interactions Handler
local InteractionsFolder = ServerScriptService.Server.Interactions

-- Functions
local function getInteraction(interactionName: string)
    local requireInteraction = InteractionsFolder:FindFirstChild(interactionName)
    assert(requireInteraction, "Interaction Required does not exist")
    return requireInteraction
end
--
local InteractionsWrapper = {}

function InteractionsWrapper:Start()
    Net:RemoteEvent("InteractionServer")
end

Net:Connect("InteractionServer", function(Player: Player, InteractionName: string, InteractionPart: BasePart)
    assert(getInteraction(InteractionName), "Interaction which is getting wrapped does not exist")
    local CurrentInteraction = require(getInteraction(InteractionName))
    CurrentInteraction:LoadInteraction(Player, InteractionPart)
end)

-- TeamService Wrapper
--TODO: Instead of using teams to set attributes use teamservice module made in shared framework misc modules team onstart function already made to load its settings
function InteractionsWrapper:IsPlayerInGroup(player: Player, groupID: number)
    return Promise.new(function(resolve)
        resolve(player:IsInGroup(groupID))
    end)
end


return InteractionsWrapper
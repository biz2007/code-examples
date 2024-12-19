--!strict
-- Project: Profile Manager
-- Author: biz / bluware
-- Details: Manages Profile Datastore Framework
-- Date: 19/03/2024
-- Version: 1.2

-- Services
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DatastoreService = game:GetService("DataStoreService")
local ServerModules = game:GetService("ServerScriptService").Server.Modules
local Players = PlayerService:GetPlayers()
local PlayersCount = #Players

-- Profile Handler
local ProfileSettings = require(script.Parent.ProfileSettings)
local ProfileVersion = script:GetAttribute("Version")
local GetProfileVersion = DatastoreService:GetDataStore("VERSION" .. ProfileVersion)

-- Utility Tools & Libraries
local UtilityModules = game:GetService("ReplicatedStorage").UtilityModules
local Signal = require(UtilityModules.Signal)
local Promise = require(UtilityModules.Promise)

local Shared = game:GetService("ReplicatedStorage").Shared
local Packages = Shared.Packages
local TableUtil = require(Packages["table-util"])

local Utilities = game:GetService("ReplicatedStorage").Framework.Utility
local assert = require(Utilities.Assert)
-- Player Handler
local ProfileManager = {}
ProfileManager.__index = ProfileManager
ProfileManager.ProfileLists = {}
ProfileManager.ShutdownSignal = Signal.new()

local ProfileList: ProfileSettings.Profile = {
    Wallet = 100000,
    Bank = 500,
    DirtyWallet = 0,
    CurrentOccupation = "None",
    TimePlayed = 0,
    DataVersion = 0,
    LockedSession = false,
    CurrentSession = "",
}

local BlacklistList = {}

local Classes = {
    number = "IntValue",
    boolean = "BoolValue",
    string = "StringValue",
}

local SessionList = {}
local GenericList = {
    ["VehicleData"] = {},
}

local Settings = {
    DetermineDeadSession = 900,
    AutomaticSave = 300,
    MaxRetries = 3,
}

-- Local Functions
local function createGenericData(getCurrentData: {})
    --> Checks for the generic list which contain tables that we want to add to the player without making it a profile,
    -- checks if it already exists in their current data if not it insrts it
    for key, value in pairs(GenericList) do
        if getCurrentData[key] == nil then
            getCurrentData[key] = value
        end
    end
end

-- DEPRECATED (USING TABLEUTIL RECONCILE)
--[[local function mapoldData(oldData: {}, newData: {})
    for index, value in pairs(oldData) do
        -- If data which is new required by saving the profile does not exist --> Set the key of the new data --> value of the old data
        if not newData[index] then
            newData[index] = value
            --> If value is a dictionary inside the table it will check th type --> iterate through the dictionary / nested table --> check if newData exists on the indexed key -->
        elseif type(value) == "table" then
            for dictKey, dictValue in pairs(value) do
                if not newData[index] then
                    --> Get's the new data table with its key and the nested table's key --> sets it to the dictionaries value
                    newData[index][dictKey] = dictValue
                end
            end
        end
    end
end]]

-- (_ functions)

function ProfileManager:_requestBudget(budgetRequest: Enum.DataStoreRequestType)
    local getBudget = DatastoreService:GetRequestBudgetForRequestType(budgetRequest)
    print(`Current Budget: {getBudget}`)
    while getBudget == 0 do
        print(getBudget)
        getBudget = DatastoreService:GetRequestBudgetForRequestType(budgetRequest)
        task.wait(10)
    end
end
function ProfileManager:_retryDataAttempts()
    local asyncSuccess
    local asyncData
    local dataAttempts = 0
    return Promise.new(function(resolve, reject)
        assert(self.Player, "Player does not exist")
        assert(self:_getkey(), `Profile key of {self.Player.Name} does not exist`)
        self:_requestBudget(Enum.DataStoreRequestType.GetAsync)

        repeat dataAttempts += 1

            asyncData = GetProfileVersion:GetAsync(self:_getkey())

        until asyncData ~= nil or dataAttempts >= Settings.MaxRetries

        if asyncData ~= nil then
            resolve(asyncData)
        else
            reject()
        end
    end)

end

function ProfileManager:_getkey(): number
    assert(self.Player, "Player does not exist")
    return self.Player.UserId
end

-- Profile Functions
function ProfileManager:IsPlayerLoaded(): boolean
    assert(self.Player, "Player does not exist")
    local getProfile = ProfileManager.ProfileLists[self.Player.UserId] and true or false
    return getProfile
end

function ProfileManager.CreateProfile(player: Player)
    local self = setmetatable({}, ProfileManager)
    --> Treats self.Player as player and its playerdata
    assert(player, "Player does not exist")

    self.Player = player
    self.PlayerData = player:WaitForChild("PlayerData") :: any
    self.Created = false
    self.CurrentData = {}
    SessionList[self.Player] = tick()

    Promise.try(function()
        self.Created = self:CreateStatistics(self.PlayerData)
    end)
        :andThen(function()
            self:LoadProfile()
            :catch(function()
                self.Player:Kick("Fetching new session, data has not loaded")
            end)
            :andThen(function(getData)
                self.CurrentData = TableUtil.Copy(getData, true)
                print('Current Data', self.CurrentData)
                for key, value in pairs(self.PlayerData:GetChildren()) do 
                if value :: ValueBase and getData[value.Name] then
                    value.Value = getData[value.Name]
                end
            end
            end)

            print(`{self.Player.Name}'s profile has been sucessfully created and loaded!`)
            ProfileManager.ProfileLists[self:_getkey()] = self
            print(ProfileManager.ProfileLists)
        end)
        :catch(function()
            print("Player's statistics has not been created yet")
        end)

    return self
end

function ProfileManager:CreateStatistics(class: Folder)
    local done = false
    for int, val in ProfileList do
        if class:FindFirstChild(int :: string) then
            return false
        end
        local getType = type(val)
        local classFunc = Classes[getType]

        if classFunc then
            local dataType = Instance.new(classFunc) :: any
            dataType.Name = int
            dataType.Value = val
            dataType.Parent = class
            done = true
        end
    end
    print("Created Statistics")
    return done
end

function ProfileManager:GetProfile(getPlayer: Player): {}
    assert(self:IsPlayerLoaded() == true, "Player's profile has not loaded or has not been created")
    local player = self.Player or getPlayer
    local getUpdatedData = Promise.retry(self:_retryDataAttempts(), Settings.MaxRetries)
        :catch(function(rejectError)
            self.Player:Kick(rejectError)
        end)

    assert(getUpdatedData, "Data attempts to receive Player Data is unsuccessful")
    return getUpdatedData
end

function ProfileManager:LoadProfile()
    return Promise.new(function(resolve, reject, onCancel)
        assert(self.Player, "Player does not exist")
        local fetchSession
        local currentSession = HttpService:GenerateGUID(false)
        local key = self:_getkey()
        local getData

        self:_retryDataAttempts()
            :catch(function()
                self.Player:Kick("Fetching new session, data has not loaded")
            end)
            :andThen(function(data)
                print("Player's data has loaded")
                getData = data
            end):expect()

        self:_requestBudget(Enum.DataStoreRequestType.UpdateAsync)
        GetProfileVersion:UpdateAsync(self:_getkey(), function(pastData)
            getData = pastData or getData
            createGenericData(getData)
            print(getData)
            --> Checks if the old data's session is currently locked
            if pastData.LockedSession then
                --> Check if current locked session time is lesser than 15 minutes (60 * 15)
                if
                    (os.time() - pastData.LockedSession < Settings.DetermineDeadSession)
                    and pastData.CurrentSession ~= ""
                then
                    fetchSession = true
                    print("Fetching new session")
                else
                    --> Otherwise, it sets session lock to the currentr time and sets the currentData to oldData, fetching currentData as past data
                    print("Fetching past data: ", pastData)
                    pastData.LockedSession = os.time()
                    getData = pastData
                end
            else
                print("Fetching past data: ", pastData)
                pastData.LockedSession = os.time()
                getData = pastData
            end
            return getData
        end)

        task.wait(5)
        fetchSession = (fetchSession ~= nil) == false
        resolve(getData) 
        if not getData then reject() end
    end)
end


function ProfileManager:SaveProfile(fetchSession: boolean, getPlayer: Player, updatedProfile: {})
    return Promise.new(function(resolve, reject)
            --	assert(self:IsPlayerLoaded() == true, "Player's profile has not loaded or has not been created")
    local data = {} :: any
    local getLastData
    local player = getPlayer == nil and self.Player or getPlayer
    local playerProfile = ProfileManager.ProfileLists[player.UserId]
    local dataFolder = player:FindFirstChild("PlayerData") :: any
    local key = player.UserId
    local sessionTime = SessionList[player]
    local sessionPlayed = tick() - sessionTime

    assert(dataFolder, `Player Data of {player} does not exist`)

    dataFolder.TimePlayed.Value += sessionPlayed
    if updatedProfile == nil then
        for i, v in pairs(dataFolder:GetChildren()) do
            data[v.Name] = v.Value
        end
    else
        data = updatedProfile
    end

        GetProfileVersion:UpdateAsync(player.UserId, function(pastData)
            print("Data has been saved!")
            if pastData == nil then
                return data
            end
            if pastData.DataVersion ~= dataFolder.DataVersion.Value then return nil end
            data.DataVersion += 1
            data.LockedSession = fetchSession and os.time() or nil :: any
            --> if old data is not found on the newData such as generic data, it will map old data --> new data with its data
            --  mapoldData(oldData, data)
            data = TableUtil.Reconcile(data, playerProfile.CurrentData)
            print(data)
            return data
        end)
    end)
end


function ProfileManager:SaveProfiles()
    coroutine.wrap(function()
        print("Saving profiles function initialised")
        while task.wait(Settings.AutomaticSave) do
            for i, player in ipairs(PlayerService:GetPlayers()) do
                self:SaveProfile(true, player)
            end
        end
    end)
end

return ProfileManager
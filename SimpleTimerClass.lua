-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Knit Modules
local Knit = require(ReplicatedStorage.Packages.Knit)

local maid = require(Knit.Util.Maid)

local Timer = {}
Timer.__index = Timer

function Timer.new(
	timeLimit: number,
	timerCallback: (...any) -> (),
	finishedCallback: (...any) -> (),
	timerEndedCallback: (...any) -> ()
)
	local self = {}
	self._Maid = maid.new()
	self.CurrentTime = timeLimit
	self.TimeLimit = timeLimit

    --print(timeLimit, timerCallback, finishedCallback, timerEndedCallback)
	-- Run
	self.Elapsed = os.time()
	self._Maid:GiveTask(RunService.RenderStepped:Connect(function()
		self.CurrentTime = self.TimeLimit - (os.time() - self.Elapsed)
		timerCallback()

		-- If for whatever reason you want to end the timer run finished callback
		if finishedCallback ~= nil and finishedCallback() == true then
			self:Clean()
		end

		-- If the timer runs out and has ended run timer ended callback
		if (os.time() - self.Elapsed) >= self.TimeLimit then
			self:Clean()
			timerEndedCallback()
		end
	end))

	return setmetatable(self, Timer)
end

function Timer:GetCurrentTime()
    return self.CurrentTime
end

function Timer:GetTimeLimit()
    return self.TimeLimit
end

function Timer:GetElapsedTime()
	return self.Elapsed
end

function Timer:Clean()
    self._Maid:DoCleaning()
end
return Timer

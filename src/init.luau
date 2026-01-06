--!strict
--!optimize 2
--!native

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)
local RemotePackage = require(Packages.Remote)
local Remote = RemotePackage.RemoteEvent
local Function = RemotePackage.RemoteFunction
local Sift = require(Packages.Sift)

local InputEvent = Remote.new("Input", false)
local SetMappingEvent = Remote.new("SetMappings", false)
local CamCFrameEvent = Remote.new("PlayerInfo", false)

local IsServer = RunService:IsServer()

local module = {
	PlayerData = {} :: {
		[Player]: {
			Mappings: Mappings,
			Signals: { [string]: Signal.Signal<boolean?> },
			States: { [string]: boolean? },
		},
	},
}

local InitMappings = Function.new("InitMappings", IsServer and function(plr: Player)
	return module.PlayerData[plr].Mappings :: any
end or nil :: any)

export type Mappings = {
	[string]: string,
}

local function InitPlayer(plr: Player, mappings: Mappings)
	warn(plr, "has been inited")
	module.PlayerData[plr] = {
		Mappings = mappings,
		Signals = {},
		States = {},
	}

	module.PlayerData[plr].Mappings = mappings
end

local function HandleAction(plr, action, state)
	local PlrData = module.PlayerData[plr]
	if not PlrData then
		return
	end

	if Sift.Dictionary.includes(PlrData.Mappings, action) then
		PlrData.States[action] = state
		if PlrData.Signals[action] then
			PlrData.Signals[action]:Fire(state)
		end
	end
end

function module.Init(self: InputService, mappings: Mappings)
	if IsServer then
		Players.PlayerAdded:Connect(function(plr)
			InitPlayer(plr, mappings)
		end)

		task.spawn(function()
			for _, plr in Players:GetPlayers() do
				InitPlayer(plr, mappings)
			end
		end)

		InputEvent.OnFired:Connect(function(plr: Player, input: string, state: boolean)
			HandleAction(plr, input, state)
		end)

		CamCFrameEvent.OnFired:Connect(function(plr: Player, cframe: CFrame)
			--add sanity check later zzz
			plr:SetAttribute("Camera", cframe)
		end)
	else
		--local InitialMappings =

		local plr = Players.LocalPlayer
		InitPlayer(plr, InitMappings:Invoke())

		local PlrData = self.PlayerData[plr]

		SetMappingEvent.OnFired:Connect(function(Mappings)
			PlrData.Mappings = table.clone(Mappings)
		end)

		local function HandleInput(input: InputObject, state: boolean, process: boolean?)
			if process then
				return
			end

			if input.KeyCode.Name ~= "Unknown" then
				local action = PlrData.Mappings[input.KeyCode.Name]

				if not action then
					return
				end

				InputEvent:Fire(action, state)
				HandleAction(plr, action, state)
			else
				local action = PlrData.Mappings[input.UserInputType.Name]

				if not action then
					return
				end

				InputEvent:Fire(action, state)
				HandleAction(plr, action, state)
			end
		end

		UserInputService.InputBegan:Connect(function(input, process)
			HandleInput(input, true, process)
		end)

		UserInputService.InputEnded:Connect(function(input, process)
			HandleInput(input, false)
		end)
	end
end

function module.ChangeMappings(self: InputService, plr: Player, Mappings: Mappings)
	if not IsServer then
		return
	end

	SetMappingEvent:Fire(plr, Mappings)
	self.PlayerData[plr].Mappings = Mappings
end

function module.GetInputState(self: InputService, plr: Player, input: string): boolean
	return self.PlayerData[plr].States[input] :: boolean
end

function module.AwaitInputState(self: InputService, plr: Player, input: string, state: boolean?): boolean?
	return self:GetInputSignal(plr, input):Wait()
end

function module.GetInputSignal(self: InputService, plr: Player, input: string): Signal.Signal<boolean?>
	local PlrData = assert(self.PlayerData[plr], "no data booooooo")

	if PlrData.Signals[input] then
		return PlrData.Signals[input]
	end

	local NewSignal = Signal.new()
	PlrData.Signals[input] = NewSignal

	return NewSignal
end

type InputService = typeof(module)

return module

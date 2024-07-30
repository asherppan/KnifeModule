-- [[ Roblox Services ]] --

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local TweenService = game:GetService("TweenService");
local Debris = game:GetService("Debris");

-- [[ Modules ]] --

local Modules = ServerStorage.Modules;

local DataManager = require(Modules.DataManager);
local FastCast = require(Modules.FastCastRedux);
local PartCache = require(Modules.PartCache);
local Kill = require(Modules.Kill);
local Tool6D = require(ReplicatedStorage.Modules.Tool6D)

local GetModel = require(ReplicatedStorage.Modules.GetModel)

-- [[ Variables ]] --

local Events = ReplicatedStorage.Events;

local ProjectileContainer = workspace._Ignore

-- [[ Constants ]] --

local Info = require(ReplicatedStorage.Modules.KnifeInfo)

-- [[ Public ]] --

local knife = {};
knife.__index = knife;

function knife.new(player)
	local profile = DataManager.Profiles[player];
	local self = {};
	self.player = player;
	
	self.slash_debounce = false;
	self.throw_debounce = false;
	self.tool = nil;
	self.direction = nil;
	self.knife_angle = nil;
	self.Caster = nil;
	self.CastBehavior = nil;
	self.stab_active = false;
	
	-- create a metatable to organize knife
	
	return (setmetatable(self, knife))
end;

function knife:Tool()
	-- method is called on player spawn to give them a new knife
	if (self.CastBehavior and self.CastBehavior.CosmeticBulletProvider) then
		self.CastBehavior.CosmeticBulletProvider:Dispose();
	end;
	
	local profile = DataManager.RepeatGetProfile(self.player);
	self.tool = ReplicatedStorage.Assets.Tools.Knives:FindFirstChild(profile.Data.EquippedKnife):Clone();
	self.tool.Name = "Knife";
	
	Tool6D(self.player.Character, self.tool) -- make the tool animatable
	
	if (self.ablity and self.ability.CastBehavior and self.ability.CastBehavior.CosmeticBulletProvider) then
		self.ability.CastBehavior.CosmeticBulletProvider:Dispose(); -- cleaning up previous tool
	end
	
	self.ability = nil
	
	if profile.Data.EquippedKnifeAbility ~= nil then
		self.ability = require(ServerStorage.Abilities.Knife:FindFirstChild(profile.Data.EquippedKnifeAbility)).new(self.player, self.tool)
		local dbValue = Instance.new("IntValue")
		dbValue.Value = self.ability.Debounce
		dbValue.Name = "Debounce"
		dbValue.Parent = self.tool
		for _, scriptClone in pairs(ServerStorage.KnifeScripts:GetChildren()) do
			if self.tool:FindFirstChild(scriptClone.Name) then
				continue
			end
			scriptClone = scriptClone:Clone()
			scriptClone.Parent = self.tool;
			if scriptClone:IsA("BaseScript") then
				scriptClone.Enabled = true;
			end;
		end;
		-- checking for player ability and setting it up if possible
		return
	end
	
	for _, scriptClone in pairs(ServerStorage.KnifeScripts:GetChildren()) do -- set up knife scripts from 2 central scripts to maintain organization
		if self.tool:FindFirstChild(scriptClone.Name) then
			continue
		end
		scriptClone = scriptClone:Clone()
		scriptClone.Parent = self.tool;
		if scriptClone:IsA("BaseScript") then
			scriptClone.Enabled = true;
		end;
	end;
	
	local Caster = FastCast.new(); -- using fastcast to efficiently raycast on server
	--FastCast.VisualizeCasts = true --debug mode

	local TemplateCosmetic = Instance.new("Part") -- creating a part template, this part is purely for positioning and raycasting to be easily segmented on the server, the actual effect meshpart will be displayed on each client
	TemplateCosmetic.Transparency = 1
	TemplateCosmetic.CanCollide = false
	TemplateCosmetic.Anchored = true
	TemplateCosmetic.Size = Vector3.new(0.1, 0.1, 0.1)

	local CosmeticPartProvider = PartCache.new(TemplateCosmetic, 5, ProjectileContainer);

	local CastParams = RaycastParams.new(); -- setting default castparams, will be changed in the future
	--CastParams.BruteForceAllSlow = true
	--CastParams.RespectCanCollide = true;
	CastParams.FilterType = Enum.RaycastFilterType.Exclude;
	CastParams.FilterDescendantsInstances = Info.DefaultIgnore(self)
	CastParams.IgnoreWater = true

	local CastBehavior = FastCast.newBehavior();
	CastBehavior.RaycastParams = CastParams;
	CastBehavior.MaxDistance = Info.Distance;
	CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default;
	CastBehavior.CosmeticBulletProvider = CosmeticPartProvider;
	CastBehavior.Acceleration = Vector3.new() -- setting properties for future casts

	self.Caster = Caster;
	self.CastBehavior = CastBehavior;

	self.Caster.RayHit:Connect(function(cast, RayResult: RaycastResult, _, cosmetic) ---add sound and vfx (particles)
		local hit, rayPos, normal, target = RayResult.Instance, RayResult.Position, RayResult.Normal, nil
		
		target, rayPos, hit = GetModel(hit, rayPos, self.player) -- get associated character from hit part
		
		-- creating effect for when knife hits an object (from segmented raycast)
		
		cast:SetVelocity(Vector3.new(0,0,0)); -- stop the knife
		ReplicatedStorage.Events.StopTrackKnife:FireAllClients(cosmetic) -- stop the client knife effect on all clients
		local debris: BasePart = self.tool.Handle:Clone();
		debris.CFrame = CFrame.lookAt(rayPos, self.tool.Handle.Position) * CFrame.new(0,0,-0.2) * CFrame.Angles(math.rad(120), 0, 0)
		--debris.Position = cosmetic.Position
		TweenService:Create(debris, TweenInfo.new(1), {CFrame = CFrame.lookAt(rayPos, self.tool.Handle.Position) * CFrame.Angles(math.rad(120), 0, 0)}):Play()
		debris.Anchored = true
		debris.Parent = workspace._Ignore
		
		Debris:AddItem(debris, 3)
		
		local effectPart = Instance.new("Part")
		Debris:AddItem(effectPart, 3)
		local weld = Instance.new("WeldConstraint")
		weld.Parent = effectPart
		weld.Part0 = effectPart
		weld.Part1 = hit
		effectPart.Anchored = false
		effectPart.CanCollide = false
		effectPart.Size = Vector3.new(1.3,1.3,0.1)
		effectPart.CFrame = CFrame.lookAt(rayPos, rayPos + normal) -- set the cframe of the effectpart to hit position and along the hit normal
		effectPart.Transparency = 1;
		effectPart.Parent = workspace._Ignore

		for _, effect in pairs(ServerStorage.Assets.Effects.Knife:GetChildren()) do
			effect = effect:Clone()
			effect.Parent = effectPart
			--effect.Orientation=Vector3.new(0,0,0)
		end
		for _, particle in pairs(effectPart.Effect:GetChildren()) do
			particle:Emit(15)
		end
		effectPart.Effect.ParticleEmitter.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, hit.Color),
			ColorSequenceKeypoint.new(1, hit.Color)
		}
		
		if (hit == nil or target == nil or target:FindFirstChild("HumanoidRootPart") == nil or target:FindFirstChild("Humanoid") == nil or self.player.Character == nil or self.player.Character.Humanoid == nil or self.player.Character.Humanoid.Health <= 0) then
			local sound = ServerStorage.Assets.Sounds.Knife.Hit:Clone()
			sound.Parent = debris
			sound:Play()
			return;
		end;
		
		local sound = ServerStorage.Assets.Sounds.Knife.HitStab:Clone()
		sound.Parent = hit
		sound:Play()

		local ragdoll = Kill(self.player, target, self.direction, self.tool.Handle);

		if ragdoll == nil then
			return
		end

		local weldc = Instance.new("WeldConstraint");
		weldc.Part0 = ragdoll:FindFirstChild(hit.Name);
		weldc.Part1 = debris;
		weldc.Parent = ragdoll:FindFirstChild(hit.Name);
		debris.Anchored = false
	end);
	self.Caster.LengthChanged:Connect(function(cast, segmentOrigin, segmentDirection, length, segmentVelocity, cosmeticBulletObject)
		-- math to update the cframe
		if cosmeticBulletObject == nil then return end;
		local bulletLength = cosmeticBulletObject.Size.Z / 2;
		local baseCFrame = CFrame.new(segmentOrigin, segmentOrigin + segmentDirection);
		cosmeticBulletObject.CFrame = baseCFrame * CFrame.new(0, 0, -(length - bulletLength))
	end);
	self.Caster.CastTerminating:Connect(function(cast)
		-- clean up knife effect on all clients
		local cosmeticBullet = cast.RayInfo.CosmeticBulletObject;
		if cosmeticBullet ~= nil then
			self.CastBehavior.CosmeticBulletProvider:ReturnPart(cosmeticBullet);
		end;
		ReplicatedStorage.Events.StopTrackKnife:FireAllClients(cosmeticBullet)
	end);
	
	self.tool.Parent = self.player.Backpack;
	
	self.tool.Equipped:Connect(function()
		-- play equip effects, and also update the raycast ignore list
		local sound = ServerStorage.Assets.Sounds.Knife.Equip:Clone()
		sound.Parent = self.tool.Handle
		sound:Play()
		task.spawn(function()
			sound.Ended:Wait()
			sound:Destroy()
		end)
		if CastParams == nil then
			return
		end
		CastParams.FilterType = Enum.RaycastFilterType.Exclude;
		CastParams.FilterDescendantsInstances = Info.DefaultIgnore(self)
	end)
end;

function knife:Throw(mouseHit: CFrame, startPos: Vector3, power: number)
	-- called when knife is thrown
	if self.tool == nil or self.tool:FindFirstChild("Handle") == nil then
		return
	end
	
	if self.throw_debounce or self.stab_active then
		return
	end
	
	local shoot = ServerStorage.Assets.Sounds.Knife.Shoot:Clone()
	shoot.Parent = self.tool.Handle
	shoot:Play()
	
	Debris:AddItem(shoot, shoot.TimeLength)
	
	self.throw_debounce = true;
	
	if self.ability then
		self.ability:Use(mouseHit, startPos, power) -- handle player knife abilities
		task.delay(self.ability.Debounce, function()
			self.throw_debounce = false;
		end);
		return
	end
	
	task.delay(self.tool:GetAttribute("Debounce") or Info.Debounce, function()
		self.throw_debounce = false;
	end);
	
	self.tool.Handle.Anchored = true
	--self:Tween()
	
	local direction = (mouseHit.Position - startPos).Unit;
	if power > 1 then
		power = 1
	end
	
	local modifiedBulletSpeed = (direction * Info.Speed * (Info.DefaultCharge + (power*(1-Info.DefaultCharge))));
	
	local cast = self.Caster:Fire(startPos, direction, modifiedBulletSpeed, self.CastBehavior);
	
	ReplicatedStorage.Events.TrackKnife:FireAllClients(cast.RayInfo.CosmeticBulletObject, self.tool.Handle) -- create visible effect part on each client to avoid server lag
	
	self.direction = direction;
	
	self.tool.Handle.Anchored = false
end;

function knife:StabSound()
	if self.stabsound_db == nil then
		self.stabsound_db = false
	end
	if self.stabsound_db == true then
		return
	end
	self.stabsound_db = true
	
	local slash = ServerStorage.Assets.Sounds.Knife.Slash:Clone() -- play knife stab sound
	slash.Parent = self.tool.Handle
	slash:Play()
	
	slash.Ended:Wait()
	
	slash:Destroy()
	self.stabsound_db = false
end

function knife:Stab()
	-- called to stab, but target is empty
	if self.slash_debounce or self.stab_active then
		return;
	end;
	--self:Tween()
	self.slash_debounce = true;
	self.stab_active = true
	task.delay(self.tool:GetAttribute("Debounce") or Info.Debounce, function()
		self.slash_debounce = false;
		self.stab_active = false
	end);
end;

function knife:StabTarget(target, rayPos, normal, hit) -- ray info is passed from client
	-- called to stab, but target is not empty
	if self.tool == nil or self.tool:FindFirstChild("Handle") == nil then
		return
	end
	if self.stab_active == false then
		return
	end
	self.stab_active = false
	if target and (target.PrimaryPart.Position - self.player.Character.PrimaryPart.Position).Magnitude <= 8 then -- anticheat
		Kill(self.player, target, self.player.Character.PrimaryPart.CFrame.LookVector, self.tool.Handle) -- custom kill function for ragdolling, checking for team, etc
	end
	
	local effectPart = Instance.new("Part") -- create stab effect
	local weld = Instance.new("WeldConstraint")
	weld.Parent = effectPart
	weld.Part0 = effectPart
	weld.Part1 = hit
	effectPart.Anchored = false
	effectPart.CanCollide = false
	effectPart.Size = Vector3.new(1.3,1.3,0.1)
	effectPart.CFrame = CFrame.lookAt(rayPos, rayPos + normal)
	effectPart.Transparency = 1;
	effectPart.Parent = workspace._Ignore
	
	for _, effect in pairs(ServerStorage.Assets.Effects.Knife:GetChildren()) do
		effect = effect:Clone()
		effect.Parent = effectPart
	end
	for _, particle in pairs(effectPart.Effect:GetChildren()) do
		particle:Emit(15)
	end
	effectPart.Effect.ParticleEmitter.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, hit.Color),
		ColorSequenceKeypoint.new(1, hit.Color)
	}
	
	local sound = ServerStorage.Assets.Sounds.Knife.HitStab:Clone()
	sound.Parent = effectPart
	sound:Play()
	sound.Ended:Wait()
	sound:Destroy()
	
	Debris:AddItem(effectPart, 2)
end

return (knife);

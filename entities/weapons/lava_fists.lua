AddCSLuaFile()

if SERVER then
	resource.AddFile( "materials/models/hands/hands_color.vmt")
	resource.AddFile( "materials/models/hands/hands_color_jive.vmt")
	resource.AddFile( "materials/models/hands/pimp_body_color.vmt")
	resource.AddFile( "materials/models/hands/sleeves.vmt")
	resource.AddFile( "models/v_me_fists.mdl")
end

SWEP.PrintName = "Fists"
SWEP.Author = "Kilburn, robotboy655, MaxOfS2D & Tenrys"
SWEP.Purpose = "Well we sure as hell didn't use guns! We would just wrestle Hunters to the ground with our bare hands! I used to kill ten, twenty a day, just using my fists."
SWEP.Slot = 0
SWEP.SlotPos = 4
SWEP.Spawnable = true
SWEP.ViewModel = "models/v_me_fists.mdl"
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 70
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.DrawCrosshair = true
SWEP.DrawAmmo = false
SWEP.HitDistance = 48
local SwingSound = Sound("WeaponFrag.Throw")
local HitSound = Sound("Flesh.ImpactHard")
local tVal
local math = math
local util = util
local Vector = Vector
local m_HasDispatchedEgg

function SWEP:Initialize()
	self:SetHoldType("normal")
	self:SetEggs(6)
end

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "Eggs")
	self:NetworkVar("Float", 0, "NextMeleeAttack")
	self:NetworkVar("Float", 1, "NextSprint")
end

function SWEP:UpdateNextSprint()
	local vm = self.Owner:GetViewModel()
	self:SetNextSprint(CurTime() + vm:SequenceDuration() / vm:GetPlaybackRate())
end

function SWEP:PrimaryAttack(NoForce)
	if not NoForce then
		hook.Call("Lava.FistsSecondaryAttack", nil, self.Owner, self )
	end

	self.Owner:SetAnimation(PLAYER_ATTACK1)
	local anim = "Shove"
	tVal = not NoForce
	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
	self:EmitSound(SwingSound)
	self:UpdateNextSprint()
	self:SetNextMeleeAttack(CurTime() + 0.2)
	self:SetNextPrimaryFire(CurTime() + 0.6)
	self:SetNextSecondaryFire(CurTime() + 0.6)
	self.Owner:SetNW2Int("$fist_attack_index", self.Owner:GetNW2Int("$fist_attack_index") + 1)

	if not NoForce then
		if ( Rounds.CurrentState ) == "Preround" then return end

		local tR_v = util.TraceLine({
			start = self.Owner:GetShootPos(),
			endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
			filter = self.Owner,
			mask = MASK_SHOT_HULL
		})

		if not IsValid(tR_v.Entity) then
			tR_v = util.TraceHull({
				start = self.Owner:GetShootPos(),
				endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
				filter = self.Owner,
				mins = Vector(-10, -10, -8),
				maxs = Vector(10, 10, 8),
				mask = MASK_SHOT_HULL
			})
		end

		if tR_v.Hit then
			self:EmitSound(HitSound)

			if SERVER then
				self.Owner:ViewPunch(Angle(0, (-2):random(2), (-2):random(2)))
			end

			local Entity = tR_v.Entity
			if not IsValid(Entity) then return end
			if Entity:IsPlayer() and Entity:GetMoveType() == 9 then
				Entity:SetMoveType( 2 )
			end
			if not Entity:IsPlayer() then
				if Entity:GetPhysicsObject():IsValid() then
					Entity:GetPhysicsObject():AddVelocity(self.Owner:GetAimVector() * (10000 * Entity:GetPhysicsObject():GetMass():Clamp(1, 100)))
				end
			elseif hook.Call( "Lava.PlayerPushPlayer", nil, self.Owner, Entity ) == nil then
				Entity:SetVelocity(self.Owner:GetForward():SetZ(Entity:OnGround() and 0.2 or -0.2) * 1000)
				Entity.m_LastShovedBy = self.Owner
			end
		end
	end
end

function SWEP:Reload()
	hook.Call("Lava.FistsReload", nil, self.Owner, self )
	if not self.Owner:HasAbility("Limpy Larry") then return end
	self.NextRagdollTime = self.NextRagdollTime or CurTime() + 1

	if SERVER and self.NextRagdollTime < CurTime() then
		Ragdoll.Enable(self.Owner)
		self.Owner:Flashlight(false)
		self.Owner.m_NextRagdollifcationTime = CurTime() + 1
	end
end

function SWEP:SecondaryAttack()
	hook.Call("Lava.FistsSecondaryAttack", nil, self.Owner, self )
	self:PrimaryAttack(self:GetEggs() > 0)
	if self:GetEggs() < 1 then return end
	self:SetEggs(self:GetEggs() - 1)
	m_HasDispatchedEgg = true

	if SERVER then
		local egg = ents.Create("prop_physics")
		egg:SetPos(self.Owner:GetShootPos())
		egg:SetModel("models/props_phx/misc/egg.mdl")
		egg.m_EggParent = self.Owner
		egg:Spawn()
		egg:SetOwner(self.Owner)
		egg:Activate()
		local m_Vel = hook.Call("Lava.PlayerEggDispatched", nil, self.Owner, self, egg )
		egg:GetPhysicsObject():AddAngleVelocity(self.Owner:GetAimVector() * (m_Vel or 1024))
		egg:GetPhysicsObject():AddVelocity(self.Owner:GetAimVector() * (m_Vel or 1024))
		egg.m_Velocity = egg:GetVelocity()

		if not Mutators.IsActive("Eggplosive Annihilation") then
			self.Owner:IncrementStat("Eggs Thrown")
		end

		if m_Vel == false then
			egg:Remove()
			return
		end

		FrameDelay(function()
			if IsValid(egg) then
				egg:SetOwner()
				egg.m_Velocity = egg:GetVelocity()
			end
		end)
	end
end

function SWEP:OnDrop()
	self:Remove()
end

function SWEP:Deploy()
	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("Draw"))
	vm:SetPlaybackRate(1)
	self:SetNextPrimaryFire(CurTime() + vm:SequenceDuration() / 1)
	self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() / 1)
	self:UpdateNextSprint()

	return true
end

function SWEP:Think()
	local owner = self:GetOwner()
	local vm = owner:GetViewModel()
	local anim = vm:GetSequenceName(vm:GetSequence())
	local curtime = CurTime()
	local Sprinttime = self:GetNextSprint()

	if (Sprinttime > 0 and curtime > Sprinttime) and owner:GetVelocity():Length2D() > owner:GetRunSpeed() - 10 and owner:OnGround() then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("Sprint"))
		self:UpdateNextSprint()
	elseif owner:GetNW2String("$climbquery", "") ~= "" and anim ~= "Shove" then
		self:SendWeaponAnim(191)
		self:SetCycle(0)
		vm:SetCycle(0)
		self:SetPlaybackRate(0)
	elseif not owner:OnGround() then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("Attack_Charge_Idle"))
	elseif owner:OnGround() and anim == "Attack_Charge_Idle" then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("Idle"))
	end

	if SERVER then
		local rand = util.SharedRandom("m_SharedPunch", -1, 1, os.time())

		if not owner:OnGround() and not owner.m_FistsHasJumped then
			owner.m_FistsHasJumped = true
			owner:ViewPunch(Angle(-5, rand, rand))
		elseif owner:OnGround() and owner.m_FistsHasJumped then
			owner.m_FistsHasJumped = nil
			owner:ViewPunch(Angle(-2, rand, rand))
		end

		if owner:OnGround() and (owner:KeyDown(4) or owner:Crouching()) and not owner.m_FistHasCrouched then
			owner:ViewPunch(Angle(-3.5, rand / 2, rand / 2))
			owner.m_FistHasCrouched = true
		elseif (not owner:KeyDown(4) and not owner:Crouching()) and owner.m_FistHasCrouched then
			owner:ViewPunch(Angle(-2, rand / 2, rand / 2))
			owner.m_FistHasCrouched = nil
		end
	end
end

function SWEP:PreDrawViewModel(View, Weapon, Player)
	View.RenderOverride = function() end
end

if SERVER then
	local net = net
	local Values = Values
	local player = player
	util.AddNetworkString("egged")

	hook.Add("PropBreak", "PropVengeance", function(Player, Object)
		if Object.m_EggParent and Object:GetModel() == "models/props_phx/misc/egg.mdl" then
			if Object.m_Velocity then
				util.Decal("BirdPoop", Object:GetPos(), Object:GetPos() + Object.m_Velocity, Object)
			end

			for Player in Values(player.GetAll()) do
				if Player:EyePos():Distance(Object:GetPos()) < 28 then
					if Object.m_EggParent ~= Player then
						Object.m_EggParent:IncrementStat("Eggs Hit")

						local Weapon = Object.m_EggParent:GetActiveWeapon()

						if IsValid(Weapon) and Weapon:GetClass() == "lava_fists" then
							Weapon:SetEggs(Weapon:GetEggs() + 1)
						end
					end

					net.Start("egged")
					net.WriteEntity( Player )
					net.Broadcast()
					break
				end
			end
		end
	end)
else
	local m_AmEgged
	local m_EggRefract = 1
	local DrawMaterialOverlay = DrawMaterialOverlay
	local FrameTime = FrameTime
	local EggCount
	local m_ShouldPlus
	local m_Position
	local White = color_white

	net.Receive("egged", function()
		local Player = net.ReadEntity()

		if Player == LocalPlayer() then
			m_EggRefract = 1
			m_AmEgged = true
		end

		Player:AddVCDSequenceToGestureSlot( GESTURE_SLOT_FLINCH, Player:LookupSequence("zombie_attack_frenzy"), 0, false )
		Player:EmitSound("vo/npc/male01/ow02.wav")

		timer.Simple( 3, function()
			if IsValid( Player ) then
				Player:AddVCDSequenceToGestureSlot( GESTURE_SLOT_FLINCH, Player:LookupSequence("zombie_attack_frenzy"), 0, true )
			end
		end)
	end)

	hook.Add("RenderScreenspaceEffects", "E G G E D", function()
		if m_AmEgged then
			DrawMaterialOverlay("models/props_lab/tank_glass001", m_EggRefract)
			DrawMaterialOverlay("effects/water_warp01", m_EggRefract)
			DrawMaterialOverlay("models/shadertest/shader3", m_EggRefract)
			m_EggRefract = m_EggRefract:lerp(0, FrameTime())

			if m_EggRefract < 0.01 then
				m_AmEgged = nil
			end
		end
	end)

	hook.Add("HUDPaint", "AddEggz", function()
		local Weapon = LocalPlayer():GetActiveWeapon()

		if Weapon:IsValid() and Weapon:GetClass() == "lava_fists" then
			EggCount = EggCount or Weapon:GetEggs()

			if ( LocalPlayer():HasAbility("Egg Meister") and m_HasDispatchedEgg ) or EggCount < Weapon:GetEggs() then
				if m_HasDispatchedEgg then
					m_HasDispatchedEgg = nil
				end
				EggCount = Weapon:GetEggs()
				m_Position = ScrH() - ScrH() / 7
				m_ShouldPlus = true
			elseif EggCount ~= Weapon:GetEggs() then
				EggCount = Weapon:GetEggs()
			end
		end

		if m_ShouldPlus then
			draw.WebImage(WebElements.PlusSign, ScrW() * 0.925 + (CurTime() * 3):sin() * 15, m_Position, 50, 50, White:Alpha(m_Position / 5))
			m_Position = m_Position - FrameTime() * 255

			if m_Position < ScrH() / 3 then
				m_ShouldPlus = false
			end
		end
	end)
end

if SERVER then return end
local surface = surface
local draw = draw
local c_CValue = 1
local pColor = pColor
local vgui = vgui

function SWEP:DrawHUD()
	if vgui.CursorVisible() then return end
	local Player = SpectatingPlayer() or LocalPlayer()
	local tr = Player:GetEyeTrace()
	local tosc

	cam.Wrap3D(function()
		tosc = tr.HitPos:ToScreen()
	end)

	c_CValue = c_CValue:lerp(Player:GetVelocity():Length() / 5)

	if tVal then
		c_CValue = c_CValue + ScrH() / 20
		tVal = nil
	end

	if LocalPlayer():ShouldDrawLocalPlayer() then
		c_CValue = c_CValue:Clamp(10, ScrH() / 20)
	end

	local xE, xT = (ScrH() / 100 + c_CValue), (c_CValue * ScrH() / 300)
	draw.WebImage(WebElements.QuadCircle, tosc.x, tosc.y, xE / 2 + (CurTime() * 10):sin() * 5, xE / 2 + (CurTime() * 10):sin() * 5, pColor():Alpha(255 - c_CValue), (c_CValue / 5):sin() * 180)
	draw.WebImage(WebElements.CircleOutline, tosc.x, tosc.y, xT + (CurTime() * 10):sin() * 5, xT + (CurTime() * 10):sin() * 5, pColor():Alpha(255 - c_CValue), 0)
	local Size = ScrH() / 12

	for i = 1, self:GetEggs() do
		draw.WebImage(Emoji.Get(2204), ScrW() - Size * (0.3 * i) - Size, ScrH() - Size * 1.5, Size, Size, nil, i == self:GetEggs() and (CurTime() * 5):sin() * 15 or -15, true)
	end
end

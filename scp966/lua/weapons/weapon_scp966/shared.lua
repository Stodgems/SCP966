SWEP.PrintName = "SCP 966"
SWEP.Author = "Charlie"
SWEP.Instructions = "Left click to attack. Click H to target a player to stalk."
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/c_arms_citizen.mdl")
SWEP.WorldModel = ""


function SWEP:Initialize()
    self.TargetPlayer = nil
    self.StalkPercentage = 0
    if IsValid(self.Owner) then
        self:MakeInvisible()
    else
        timer.Simple(0.1, function()
            if IsValid(self) and IsValid(self.Owner) then
                self:MakeInvisible()
            end
        end)
    end
    if CLIENT then
        hook.Add("Think", self, self.HandleKeyPress)
    end
    if SERVER then
        timer.Create("StalkTimer", 1, 0, function() self:IncreaseStalkPercentage() end)
    end
end

function SWEP:PrimaryAttack()
    if SERVER then
        self:MakeVisible()
        self.Owner:LagCompensation(true)
        local tr = self.Owner:GetEyeTrace()
        if tr.Hit and tr.HitPos:Distance(self.Owner:GetPos()) <= 75 then
            if tr.Entity == self.TargetPlayer and self.StalkPercentage == 100 then
                local dmg = DamageInfo()
                dmg:SetDamage(tr.Entity:Health())
                dmg:SetAttacker(self.Owner)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_SLASH)
                tr.Entity:TakeDamageInfo(dmg)
                self.StalkPercentage = 0
            else
                local dmg = DamageInfo()
                dmg:SetDamage(50)
                dmg:SetAttacker(self.Owner)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_SLASH)
                tr.Entity:TakeDamageInfo(dmg)
            end
        end
        self.Owner:LagCompensation(false)
    end
    self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:SecondaryAttack()
    -- No secondary fire functionality
end

function SWEP:MakeInvisible()
    if IsValid(self.Owner) then
        self.Owner:SetNoDraw(true)
    end
    self:SetNWBool("Invisible", true)
end

function SWEP:MakeVisible()
    if IsValid(self.Owner) then
        self.Owner:SetNoDraw(false)
        self.Owner:DrawWorldModel(true)
    end
    self:SetNWBool("Invisible", false)
    if not timer.Exists("InvisibilityTimer") then
        timer.Create("InvisibilityTimer", 2, 1, function()
            if IsValid(self) and IsValid(self.Owner) then
                self:MakeInvisible()
            end
        end)
    end
end

function SWEP:HandleKeyPress()
    if input.IsKeyDown(KEY_H) then
        self:SelectTargetPlayer()
    end
end

function SWEP:SelectTargetPlayer()
    self.StalkPercentage = 0
    net.Start("UpdateTargetPlayer")
    net.WriteEntity(nil)
    net.SendToServer()
    net.Start("UpdateStalkPercentage")
    net.WriteInt(self.StalkPercentage, 8)
    net.SendToServer()
    if CLIENT then
        local tr = self.Owner:GetEyeTrace()
        local fov = 10
        local players = player.GetAll()
        local closestPlayer = nil
        local closestAngle = fov

        for _, ply in ipairs(players) do
            if ply ~= self.Owner and ply:Alive() and self.Owner:IsLineOfSightClear(ply) then
                local angle = math.deg(math.acos(self.Owner:GetAimVector():Dot((ply:GetPos() - self.Owner:GetPos()):GetNormalized())))
                if angle < closestAngle then
                    closestPlayer = ply
                    closestAngle = angle
                end
            end
        end

        if closestPlayer then
            if IsValid(self.TargetPlayer) then
                self.TargetPlayer:SetWalkSpeed(160)
                self.TargetPlayer:SetRunSpeed(240)
                self.TargetPlayer:Freeze(false)
            end
            self.TargetPlayer = closestPlayer
            self.StalkPercentage = 0
            net.Start("UpdateTargetPlayer")
            net.WriteEntity(self.TargetPlayer)
            net.SendToServer()
            net.Start("UpdateStalkPercentage")
            net.WriteInt(self.StalkPercentage, 8)
            net.SendToServer()
        elseif self.TargetPlayer and IsValid(self.TargetPlayer) then
            self.TargetPlayer:SetWalkSpeed(160)
            self.TargetPlayer:SetRunSpeed(240)
            self.TargetPlayer:Freeze(false)
            self.TargetPlayer = nil
            self.StalkPercentage = 0
            net.Start("UpdateTargetPlayer")
            net.WriteEntity(nil)
            net.SendToServer()
            net.Start("UpdateStalkPercentage")
            net.WriteInt(0, 8)
            net.SendToServer()
        end
    end
end

if SERVER then
    util.AddNetworkString("UpdateTargetPlayer")
    util.AddNetworkString("UpdateStalkPercentage")
    util.AddNetworkString("ApplyBlackScreenEffect")
    net.Receive("UpdateTargetPlayer", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "weapon_scp966" then
            if IsValid(weapon.TargetPlayer) then
                weapon.TargetPlayer:SetWalkSpeed(160)
                weapon.TargetPlayer:SetRunSpeed(240)
                weapon.TargetPlayer:Freeze(false)
            end
            weapon.TargetPlayer = net.ReadEntity()
            weapon.StalkPercentage = 0
            net.Start("UpdateStalkPercentage")
            net.WriteInt(weapon.StalkPercentage, 8)
            net.Send(ply) 
        end
    end)
end

function SWEP:IncreaseStalkPercentage()
    if SERVER and self.TargetPlayer and IsValid(self.TargetPlayer) then
        if self.TargetPlayer:Alive() and self.Owner:IsLineOfSightClear(self.TargetPlayer) then
            if self.StalkPercentage < 100 then
                self.StalkPercentage = math.min(self.StalkPercentage + 2, 100)
                self.TargetPlayer:SetWalkSpeed(160 * (1 - self.StalkPercentage / 100))
                self.TargetPlayer:SetRunSpeed(240 * (1 - self.StalkPercentage / 100))
                net.Start("UpdateStalkPercentage")
                net.WriteInt(self.StalkPercentage, 8)
                net.Broadcast()
            end
            if self.StalkPercentage >= 100 then
                self.TargetPlayer:Freeze(true)
                net.Start("ApplyBlackScreenEffect")
                net.Send(self.Owner)
            end
        else
            self.TargetPlayer:SetWalkSpeed(160)
            self.TargetPlayer:SetRunSpeed(240)
            self.TargetPlayer:Freeze(false)
            self.TargetPlayer = nil
            self.StalkPercentage = 0
            net.Start("UpdateTargetPlayer")
            net.WriteEntity(nil)
            net.Broadcast()
            net.Start("UpdateStalkPercentage")
            net.WriteInt(0, 8)
            net.Broadcast()
        end
    end
end

if CLIENT then
    net.Receive("ApplyBlackScreenEffect", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "weapon_scp966" then
            weapon:ApplyBlackScreenEffect(LocalPlayer())
        end
    end)
end

function SWEP:ApplyBlackScreenEffect(target)
    if CLIENT then
        if target == LocalPlayer() then
            hook.Add("HUDPaint", "BlackScreenEffect", function()
                if not target:Alive() then
                    hook.Remove("HUDPaint", "BlackScreenEffect")
                    return
                end
                if self.StalkPercentage >= 100 then
                    surface.SetDrawColor(Color(0,0,0, 254))
                    surface.DrawRect( 0,0, ScrW(), ScrH() )

                    draw.SimpleText("You are unconscious", "Trebuchet24", ScrW() / 2, ScrH() / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end)
        end
    end
end

function SWEP:OnRemove()
    if CLIENT then
        hook.Remove("Think", self)
        hook.Remove("HUDPaint", "BlackScreenEffect")
    end
    if SERVER then
        timer.Remove("StalkTimer")
        timer.Remove("InvisibilityTimer")
    end
end

hook.Add("PlayerDeath", "ResetTargetOnDeath", function(victim)
    victim:Freeze(false)
    for _, ply in ipairs(player.GetAll()) do
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "weapon_scp966" and victim == weapon.TargetPlayer then
            weapon.TargetPlayer = nil
            net.Start("UpdateTargetPlayer")
            net.WriteEntity(nil)
            net.Broadcast()
            net.Start("UpdateStalkPercentage")
            net.WriteInt(0, 8)
            net.Broadcast()
        end
    end
end)

if CLIENT then
    function SWEP:DrawHUD()
        local invisible = self:GetNWBool("Invisible", false)
        if invisible == true then
            draw.SimpleText("You are invisible", "Trebuchet24", ScrW() / 2, ScrH() - 50, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif invisible == false then
            draw.SimpleText("You are visible", "Trebuchet24", ScrW() / 2, ScrH() - 50, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local targetinstructions = "Press H to target a player"
        draw.SimpleText(targetinstructions, "Trebuchet24", ScrW() / 2, ScrH() - 125, Color(238, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local targetText = "Target: " .. (self.TargetPlayer and IsValid(self.TargetPlayer) and self.TargetPlayer:Nick() or "No one")
        local stalkText = "Stalk: " .. self.StalkPercentage .. "%"
        draw.SimpleText(targetText, "Trebuchet24", ScrW() / 2, ScrH() - 100, Color(255, 94, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(stalkText, "Trebuchet24", ScrW() / 2, ScrH() - 75, Color(255, 94, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    net.Receive("UpdateTargetPlayer", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "weapon_scp966" then
            weapon.TargetPlayer = net.ReadEntity()
        end
    end)

    net.Receive("UpdateStalkPercentage", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "weapon_scp966" then
            weapon.StalkPercentage = net.ReadInt(8)
        end
    end)
end

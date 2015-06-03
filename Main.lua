local StartOfCombat = {}
local KillOnNextLogin = {}

function Initialize(Plugin)
	-- Set name & version
	Plugin:SetName("AntiCombatLog")
	Plugin:SetVersion(2)
	
	-- Register Hooks
	cPluginManager:AddHook(cPluginManager.HOOK_KILLING,          OnKilling        )
	cPluginManager:AddHook(cPluginManager.HOOK_TAKE_DAMAGE,	     OnTakeDamage     )
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_SPAWNED,   OnPlayerSpawned  )
	cPluginManager:AddHook(cPluginManager.HOOK_EXECUTE_COMMAND,  OnExecuteCommand )
	cPluginManager:AddHook(cPluginManager.HOOK_ENTITY_TELEPORT,  OnEntityTeleport )
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_DESTROYED, OnPlayerDestroyed)

	-- Load the InfoReg shared library
	dofile(cPluginManager:GetPluginsPath() .. "/InfoReg.lua")
	-- Bind all the commands
	RegisterPluginInfoCommands()
	-- Bind all the console commands
	RegisterPluginInfoConsoleCommands()
	
	DoTick(cRoot:Get():GetDefaultWorld())
	
	LOG("[AntiCombatLog] Version " .. Plugin:GetVersion() .. ", initialized.")
	return true
end

function ApplyCombatTo(Player)
	Player = tolua.cast(Player,"cPlayer")
	if not Player:HasPermission("combat.bypass") then
		if StartOfCombat[Player:GetUniqueID()] == nil then
			if ChatNotifications or Player:GetClientHandle():GetProtocolVersion() < 6 then
				Player:SendMessage("§4[CombatLog]§r " .. "§fYou are now in combat.")
				Player:SendMessage("§4[CombatLog]§r " .. "§fDo not disconnect or you'll die.")
			end
		end
		if not ChatNotifications then
			if CombatTime == 1 then
				Player:SendAboveActionBarMessage("§f§l " .. CombatTime .. " second of combat left")
			else
				Player:SendAboveActionBarMessage("§f§l " .. CombatTime .. " seconds of combat left")
			end
		end
		StartOfCombat[Player:GetUniqueID()] = GetTime()
	end
end

function OnKilling(Victim, Killer)
	if Victim:IsPlayer() then
		Victim = tolua.cast(Victim,"cPlayer")
		StartOfCombat[Victim:GetUniqueID()] = nil
	end
end

function OnTakeDamage(Receiver, TDI)
	if TDI.Attacker == nil then
		return false  
	end
	if (Receiver:IsPlayer() and TDI.Attacker:IsPlayer()) then
		ApplyCombatTo(Receiver)
		ApplyCombatTo(TDI.Attacker)
	end
	if MobCombat and (Receiver:IsPlayer() or TDI.Attacker:IsPlayer()) and (Receiver:IsMob() or TDI.Attacker:IsMob()) then
		if Receiver:IsPlayer() then
			ApplyCombatTo(Receiver)
		else
			ApplyCombatTo(TDI.Attacker)
		end
	end
end

function OnPlayerSpawned(Player)
	if KillOnNextLogin[Player:GetName()] or KillOnNextLogin[Player:GetUUID()] then
		KillOnNextLogin[Player:GetName()] = nil
		if Player:GetUUID() ~= "" then
			KillOnNextLogin[Player:GetUUID()] = nil
		end
		Player:SendMessage("§4[CombatLog]§r " .. "§fYou disconnected while in combat.")
		Player:SendMessage("§4[CombatLog]§r " .. "§fThe sentence is death.")
	end
end

function OnExecuteCommand(Player, Command)
	if Player == nil then
		return false
	end
	if not CommandsInCombat and not ( StartOfCombat[Player:GetUniqueID()] == nil ) and not Player:HasPermission("combat.bypass.commands") then
		Player:SendMessage("§4[CombatLog]§r " .. "You cannot use commands in combat.")
		return true
	end
end

function OnEntityTeleport(Entity, OldPosition, NewPosition)
	if not Entity:IsPlayer() then
		return false
	end
	Entity = tolua.cast(Entity,"cPlayer")
	if not TeleportInCombat and not ( StartOfCombat[Entity:GetUniqueID()] == nil ) and not Entity:HasPermission("combat.bypass.teleport") then
		Entity:SendMessage("§4[CombatLog]§r " .. "You cannot teleport in combat.")
		return true
	end
end

function OnPlayerDestroyed(Player)
	if not ( StartOfCombat[Player:GetUniqueID()] == nil ) then
		LOG("[CombatLog] " .. Player:GetName() .. " disconnected while in combat!")
		if DropXPOnCombatLog and Player:GetCurrentXp() > 0 then
			local tempxp = Player:GetCurrentXp()
			Player:GetWorld():ScheduleTask(20, function(World)
				World:SpawnExperienceOrb(Player:GetPosX(), Player:GetPosY()+2, Player:GetPosZ(), math.min(tempxp,MAX_EXPERIENCE_ORB_SIZE))
			end)
			Player:SetCurrentExperience(0)
		end
		if BroadcastOnCombatLog then
			cRoot:Get():BroadcastChat("§4[CombatLog]§r " .. Player:GetName() .. " disconnected while in combat!")
		end
		Player:TakeDamage(dtPlugin, nil, 2*Player:GetHealth(), 2*Player:GetHealth(), 0)
		StartOfCombat[Player:GetUniqueID()]   = nil
		KillOnNextLogin[Player:GetName()]     = true
		if Player:GetUUID() ~= "" then
			KillOnNextLogin[Player:GetUUID()] = true
		end
	end
end

function DoTick(World)
	cRoot:Get():ForEachPlayer(function(Player)
		if not ( StartOfCombat[Player:GetUniqueID()] == nil ) then
			if StartOfCombat[Player:GetUniqueID()] + CombatTime > GetTime() then
				if not ChatNotifications then
					if StartOfCombat[Player:GetUniqueID()] == GetTime() - CombatTime + 1 then
						Player:SendAboveActionBarMessage("§f§l " .. CombatTime - (GetTime() - StartOfCombat[Player:GetUniqueID()])  .. " second of combat left")
					else
						Player:SendAboveActionBarMessage("§f§l " .. CombatTime - (GetTime() - StartOfCombat[Player:GetUniqueID()]) .. " seconds of combat left")
					end
				end
			else 
				StartOfCombat[Player:GetUniqueID()] = nil
				if ChatNotifications or Player:GetClientHandle():GetProtocolVersion() < 6 then 
					Player:SendMessage("§4[CombatLog]§r " .. "§fYou are no longer in combat.")
				else
					Player:SendAboveActionBarMessage("§f§l You are no longer in combat")
				end
			end
		end
	end)
	World:ScheduleTask(5, DoTick)
end

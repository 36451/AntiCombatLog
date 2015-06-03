local StartOfCombat = {}

function Initialize(Plugin)
	-- Set name & version
	Plugin:SetName("AntiCombatLog")
	Plugin:SetVersion(1)
	
	-- Register Hooks
	cPluginManager:AddHook(cPluginManager.HOOK_KILLING,          OnKilling        )
	cPluginManager:AddHook(cPluginManager.HOOK_TAKE_DAMAGE,	     OnTakeDamage     )
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
	
	LOG("[" .. Plugin:GetName() .. "] Version " .. Plugin:GetVersion() .. ", initialised")
	return true
end

function ApplyCombatTo(Player)
	Player = tolua.cast(Player,"cPlayer")
	if not Player:HasPermission("combat.bypass") then
		if StartOfCombat[Player:GetUniqueID()] == nil then
			if ChatNotifications or Player:GetClientHandle():GetProtocolVersion() < 6 then
				Player:SendMessageInfo("§fYou are now in combat.")
				Player:SendMessageInfo("§fDo not disconnect or you'll die.")
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

function OnExecuteCommand(Player, Command)
	if Player == nil then
		return false
	end
	if not CommandsInCombat and not ( StartOfCombat[Player:GetUniqueID()] == nil ) and not Player:HasPermission("combat.bypass.commands") then
		Player:SendMessageFailure("You cannot use commands in combat.")
		return true
	end
end

function OnEntityTeleport(Entity, OldPosition, NewPosition)
	if not Entity:IsPlayer() then
		return false
	end
	Entity = tolua.cast(Entity,"cPlayer")
	if not TeleportInCombat and not ( StartOfCombat[Entity:GetUniqueID()] == nil ) and not Entity:HasPermission("combat.bypass.teleport") then
		Entity:SendMessageFailure("You cannot teleport in combat.")
		return true
	end
end

function OnPlayerDestroyed(Player)
	if not ( StartOfCombat[Player:GetUniqueID()] == nil ) then
		StartOfCombat[Player:GetUniqueID()] = nil
		if BroadcastOnCombatLog then
			cRoot:Get():BroadcastChat(Player:GetName().." disconnected while in combat!")
		end
		if DropItemsOnCombatLog then
			local Items = cItems()
			Player:GetInventory():CopyToItems(Items)
			Player:GetWorld():SpawnItemPickups( Items, Player:GetPosX(), Player:GetPosY(), Player:GetPosZ(), 0, 2, 0 )
			Player:GetInventory():Clear()
		end
		if DropXPOnCombatLog then
			local tempxp = Player:GetCurrentXp()
			Player:GetWorld():ScheduleTask(20, function(World)
				World:SpawnExperienceOrb(Player:GetPosX(), Player:GetPosY()+2, Player:GetPosZ(), math.min(tempxp,MAX_EXPERIENCE_ORB_SIZE))
			end)
			Player:SetCurrentExperience(0)
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
					Player:SendMessageInfo("§fYou are no longer in combat.")
				else
					Player:SendAboveActionBarMessage("§f§l You are no longer in combat")
				end
			end
		end
	end)
	World:ScheduleTask(5, DoTick)
end

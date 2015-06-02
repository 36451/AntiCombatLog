
-- Info.lua

-- Implements the g_PluginInfo standard plugin description

g_PluginInfo =
{
	Name = "AntiCombatLog",
	Version = "1",
	Date = "2015-05-02",
	Description = [[AntiCombatLog plugin]],
	
	Commands =
	{
	},
	
	ConsoleCommands =
	{
	},
	
	Permissions =
	{
		["combat.bypass"] =
		{
			Description = "Exemption from CombatLog sanctions",
			RecommendedGroups = "Operators",
		},
		["combat.bypass.commands"] =
		{
			Description = "Exemption from command restriction during combat",
			RecommendedGroups = "VIPs",
		},
		["combat.bypass.teleport"] =
		{
			Description = "Exemption from teleporting restriction during combat",
			RecommendedGroups = "VIPs",
		},
	}
	
}





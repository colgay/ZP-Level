#include <amxmodx>
#include <hamsandwich>
#include <hlsdk_const>
#include <nvault>
#include <zp50_core>
#include <zp50_gamemodes>

const MAX_LEVEL = 100;
const Float:X_EXP = 0.3;
const Float:Y_EXP = 2.0;

// player variables
new g_Level[MAX_PLAYERS + 1]; // [MAX_PLAYERS + 1] == [33]
new g_Exp[MAX_PLAYERS + 1];
new Float:g_Damage[MAX_PLAYERS + 1];

// cvar setting
new CvarToZero;
new CvarInitLevel;
new CvarInfectExp;
new CvarKillZombieExp;
new CvarHumanWinExp;
new CvarZombieWinExp;
new CvarDamage, CvarDamageExp;

new g_Vault;

public plugin_init()
{
	register_plugin("[ZP] Player Level", "0.1", "holla");

	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");

	// register event
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", 1);

	// 升級後 exp 歸 0
	new pcvar = create_cvar("zp_level_to_zero", "0");
	bind_pcvar_num(pcvar, CvarToZero);

	// init level
	pcvar = create_cvar("zp_level_init", "1");
	bind_pcvar_num(pcvar, CvarInitLevel);

	// 喪屍傳染人類得到多少exp
	pcvar = create_cvar("zp_level_infect_exp", "10");
	bind_pcvar_num(pcvar, CvarInfectExp);

	// 人類殺死喪屍得到多少exp
	pcvar = create_cvar("zp_level_kill_zombie_exp", "10");
	bind_pcvar_num(pcvar, CvarKillZombieExp);

	pcvar = create_cvar("zp_level_human_win_exp", "5");
	bind_pcvar_num(pcvar, CvarHumanWinExp);

	pcvar = create_cvar("zp_level_zombie_win_exp", "5");
	bind_pcvar_num(pcvar, CvarZombieWinExp);

	pcvar = create_cvar("zp_level_human_damage", "400");
	bind_pcvar_num(pcvar, CvarDamage);

	pcvar = create_cvar("zp_level_human_damage_exp", "2");
	bind_pcvar_num(pcvar, CvarDamageExp);
}

public plugin_natives()
{
	register_library("zp_level");

	register_native("zp_level_get", "native_get");
	register_native("zp_level_get_exp", "native_get_exp");
	register_native("zp_level_get_req_exp", "native_get_req_exp");
	register_native("zp_level_add_exp", "native_add");
}

public plugin_cfg()
{
	// prepare vault
	g_Vault = nvault_open("level");
}

public plugin_end()
{
	nvault_close(g_Vault);
}

public native_get()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player (%d) is not connected", id);
		return 0;
	}

	return g_Level[id];
}


public native_get_exp()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player (%d) is not connected", id);
		return 0;
	}

	return g_Exp[id];
}

public native_get_req_exp()
{
	new level = get_param(1);
	if (level < 1 || level >= MAX_LEVEL)
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Level (%d) out of range", level);
		return 0;
	}

	return GetRequiredExp(level);
}

public native_add()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player (%d) is not connected", id);
		return 0;
	}

	new exp = get_param(2);
	return AddExp(id, exp);
}

// player(human) infected by zombie event(or forward)
public zp_fw_core_infect_post(id, attacker)
{
	// is valid attacker(or infector)
	if (is_user_connected(attacker))
	{
		AddExp(attacker, CvarInfectExp);
	}
}

public zp_fw_gamemodes_end()
{
	if (!zp_core_get_zombie_count()) // human wins
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			// skip if player is not connected
			if (!is_user_connected(i))
				continue;

			if (!zp_core_is_zombie(i)) // human
				AddExp(i, CvarHumanWinExp); // give exp to all humans
		}
	}
	else if (!zp_core_get_human_count()) // zombie wins
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			// skip if player is not connected
			if (!is_user_connected(i))
				continue;

			if (zp_core_is_zombie(i)) // zombie
				AddExp(i, CvarZombieWinExp); // give exp to all zombies
		}
	}
	/*
	else // no one wins
	{
	}
	*/
}

// player killed by someone event
public OnPlayerKilled_Post(victim, attacker)
{
	// is valid killer && victim is zombie && killer is human
	if (is_user_connected(attacker) && zp_core_is_zombie(victim) && !zp_core_is_zombie(attacker))
	{
		AddExp(attacker, CvarKillZombieExp);
	}
}

public OnPlayerTakeDamage(id, inflictor, attacker, Float:damage, damagebits)
{
	if (is_user_alive(attacker) && (damagebits & DMG_BULLET) && inflictor == attacker)
	{
		if (zp_core_is_zombie(id) && !zp_core_is_zombie(attacker))
		{
			g_Damage[attacker] += damage;

			if (g_Damage[attacker] >= CvarDamage)
			{
				AddExp(attacker, CvarDamageExp);
				g_Damage[attacker] = 0.0;
			}
		}
	}
}

// player joined server
public client_putinserver(id)
{
	LoadData(id);
}

// player disconnected
public client_disconnected(id)
{
	if (is_user_connected(id))
	{
		SaveData(id)
	}

	g_Level[id] = CvarInitLevel;
	g_Exp[id] = 0;
}

// id = player index
AddExp(id, exp)
{
	// skip if player has already exceed max level
	if (g_Level[id] >= MAX_LEVEL)
		return 0;

	g_Exp[id] += exp;
	client_print(id, print_center, "+ %d EXP", exp);

	new old_level = g_Level[id];
	new required_exp = GetRequiredExp(g_Level[id]);

	// 檢查 exp 大於當前等級所需經驗
	while (g_Exp[id] >= required_exp)
	{
		g_Level[id]++; // level up

		if (CvarToZero)
			g_Exp[id] -= required_exp; // 升級後 exp 歸 0

		required_exp = GetRequiredExp(g_Level[id]); // update var
	}

	if (g_Level[id] > old_level)
	{
		client_cmd(id, "spk %s", "misc/cow");
		client_print(id, print_center, "!!! LEVEL UP !!!");
		client_print(0, print_chat, "[ZP] %n 升了 %d 個等級, 現在是 Lv.%d", id, g_Level[id] - old_level, g_Level[id]);
	}

	return g_Level[id] - old_level;
}

// exp formula
GetRequiredExp(level)
{
	return floatround(floatpower(level / X_EXP, Y_EXP));
}

LoadData(id)
{
	new steamid[50], data_str[64];
	get_user_authid(id, steamid, charsmax(steamid));
	
	// load player data from vault
	if (nvault_get(g_Vault, steamid, data_str, charsmax(data_str))) // found data
	{
		new level_str[4], exp_str[16];

		// parse data string
		parse(data_str, level_str, charsmax(level_str), exp_str, charsmax(exp_str));

		g_Level[id] = str_to_num(level_str); // convert string to integer
		g_Exp[id] = str_to_num(exp_str);
	}
	else // no data found
	{
		g_Level[id] = CvarInitLevel;
		g_Exp[id] = 0;
	}
}

SaveData(id)
{
	new steamid[50], data_str[64];
	get_user_authid(id, steamid, charsmax(steamid));

	formatex(data_str, charsmax(data_str), "%d %d", g_Level[id], g_Exp[id]);
	nvault_set(g_Vault, steamid, data_str);
}
#include <cstrike>
#include <sourcemod>

public const Plugin myinfo = {
    name = "Player Respawn", author = "LAN of DOOM",
    description = "Enables player respawn after death", version = "1.0.0",
    url = "https://github.com/lanofdoom/counterstrike-respawn"};

static ConVar g_respawn_enabled_cvar;
static ConVar g_respawn_time_cvar;

static bool g_between_rounds = false;

//
// Logic
//

static Action TimerElapsed(Handle timer, any userid) {
  if (!GetConVarBool(g_respawn_enabled_cvar) || g_between_rounds) {
    return Plugin_Stop;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Stop;
  }

  if (!IsClientInGame(client) || IsPlayerAlive(client)) {
    return Plugin_Stop;
  }

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT) {
    return Plugin_Stop;
  }

  CS_RespawnPlayer(client);

  return Plugin_Stop;
}

static void Respawn(int userid) {
  float time = GetConVarFloat(g_respawn_time_cvar);
  if (time < 0.0) {
    time = 0.0;
  }

  CreateTimer(time, TimerElapsed, userid, TIMER_FLAG_NO_MAPCHANGE);
}

//
// Hooks
//

static Action OnPlayerClass(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  PrintToServer("OnPlayerClass %d", userid);
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  if (IsFakeClient(client)) {
    return Plugin_Continue;
  }

  Respawn(userid);

  return Plugin_Continue;
}

static Action OnPlayerDeath(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  PrintToServer("OnPlayerDeath %d", userid);
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  Respawn(userid);

  return Plugin_Continue;
}

static Action OnPlayerTeam(Event event, const char[] name,
                           bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  PrintToServer("OnPlayerTeam %d", userid);
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  if (!IsFakeClient(client)) {
    return Plugin_Continue;
  }

  CS_RespawnPlayer(client);

  return Plugin_Continue;
}

static Action OnRoundEnd(Event event, const char[] name, bool dont_broadcast) {
  g_between_rounds = true;
  return Plugin_Continue;
}

static Action OnRoundStart(Event event, const char[] name,
                           bool dont_broadcast) {
  g_between_rounds = false;
  return Plugin_Continue;
}

//
// Forwards
//

public void OnPluginStart() {
  g_respawn_enabled_cvar =
      CreateConVar("sm_lanofdoom_respawn_enabled", "1",
                   "If true, players respawn after death.");

  g_respawn_time_cvar =
      CreateConVar("sm_lanofdoom_respawn_time", "2.0",
                   "Time in seconds after which dead players will respawn.");

  HookEvent("player_class", OnPlayerClass);
  HookEvent("player_death", OnPlayerDeath);
  HookEvent("player_team", OnPlayerTeam);
  HookEvent("round_end", OnRoundEnd);
  HookEvent("round_start", OnRoundStart);
}
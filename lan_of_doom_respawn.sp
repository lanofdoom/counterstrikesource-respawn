#include <cstrike>
#include <sourcemod>

public const Plugin myinfo = {
    name = "Player Respawn", author = "LAN of DOOM",
    description = "Enables player respawn after death", version = "1.0.0",
    url = "https://github.com/lanofdoom/counterstrike-respawn"};

static ConVar g_respawn_enabled_cvar;
static ConVar g_respawn_time_cvar;

static bool g_between_rounds = false;
static ArrayList g_respawn_timers;

//
// Logic
//

static Action TimerElapsed(Handle timer, any userid) {
  g_respawn_timers.Set(userid, INVALID_HANDLE);

  if (!GetConVarBool(g_respawn_enabled_cvar)) {
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

static void CancelRespawn(int userid) {
  while (g_respawn_timers.Length <= userid) {
    g_respawn_timers.Push(INVALID_HANDLE);
  }

  Handle timer = g_respawn_timers.Get(userid);

  if (timer != INVALID_HANDLE) {
    g_respawn_timers.Set(userid, INVALID_HANDLE);
    KillTimer(timer);
  }
}

static void CancelAllRespawns() {
  for (int userid = 0; userid < g_respawn_timers.Length; userid++) {
    CancelRespawn(userid);
  }
}

static void Respawn(int userid) {
  CancelRespawn(userid);

  float time = GetConVarFloat(g_respawn_time_cvar);
  if (time < 0.0) {
    time = 0.0;
  }

  Handle timer =
      CreateTimer(time, TimerElapsed, userid, TIMER_FLAG_NO_MAPCHANGE);
  g_respawn_timers.Set(userid, timer);
}

//
// Hooks
//

static Action OnPlayerDeath(Event event, const char[] name,
                            bool dont_broadcast) {
  if (g_between_rounds) {
    return Plugin_Continue;
  }

  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  Respawn(userid);

  return Plugin_Continue;
}

static Action OnPlayerSpawn(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  CancelRespawn(userid);

  return Plugin_Continue;
}

static Action OnPlayerTeam(Event event, const char[] name,
                           bool dont_broadcast) {
  if (g_between_rounds) {
    return Plugin_Continue;
  }

  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  int team = GetEventInt(event, "team");
  if (team != CS_TEAM_T && team != CS_TEAM_CT) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (client && IsFakeClient(client)) {
    CS_RespawnPlayer(client);
  } else {
    Respawn(userid);
  }

  return Plugin_Continue;
}

static Action OnRoundEnd(Event event, const char[] name, bool dont_broadcast) {
  g_between_rounds = true;
  CancelAllRespawns();
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

public void OnMapEnd() { g_respawn_timers.Clear(); }

public void OnPluginStart() {
  g_respawn_enabled_cvar =
      CreateConVar("sm_lanofdoom_respawn_enabled", "1",
                   "If true, players respawn after death.");

  g_respawn_time_cvar =
      CreateConVar("sm_lanofdoom_respawn_time", "2.0",
                   "Time in seconds after which dead players will respawn.");

  g_respawn_timers = CreateArray(1, 0);

  HookEvent("player_death", OnPlayerDeath);
  HookEvent("player_spawn", OnPlayerSpawn);
  HookEvent("player_team", OnPlayerTeam);
  HookEvent("round_end", OnRoundEnd);
  HookEvent("round_start", OnRoundStart);
}
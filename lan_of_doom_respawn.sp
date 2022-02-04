#include <cstrike>
#include <sourcemod>

public const Plugin myinfo = {
    name = "Player Respawn", author = "LAN of DOOM",
    description = "Enables player respawn after death", version = "1.1.0",
    url = "https://github.com/lanofdoom/counterstrikesource-respawn"};

static ConVar g_respawn_enabled_cvar;
static ConVar g_respawn_time_cvar;

static bool g_between_rounds = false;
static bool g_skip_ct_wins_round_end = false;
static bool g_skip_t_wins_round_end = false;
static ArrayList g_respawn_timers;

static bool g_first_spawn[MAXPLAYERS + 1] = {
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false};

//
// Logic
//

static Action TimerElapsed(Handle timer, any userid) {
  if (!GetConVarBool(g_respawn_enabled_cvar)) {
    g_respawn_timers.Set(userid, INVALID_HANDLE);
    return Plugin_Stop;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    g_respawn_timers.Set(userid, INVALID_HANDLE);
    return Plugin_Stop;
  }

  if (!IsClientInGame(client) || IsPlayerAlive(client)) {
    g_respawn_timers.Set(userid, INVALID_HANDLE);
    return Plugin_Stop;
  }

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT) {
    return Plugin_Continue;
  }

  CS_RespawnPlayer(client);

  g_respawn_timers.Set(userid, INVALID_HANDLE);

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

  Handle timer = CreateTimer(time, TimerElapsed, userid,
                             TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  g_respawn_timers.Set(userid, timer);
}

static bool WholeTeamDead(int team) {
  for (int client = 1; client <= MaxClients; client++) {
    if (IsClientInGame(client) && IsPlayerAlive(client) &&
        team == GetClientTeam(client)) {
      return false;
    }
  }
  return true;
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

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  int team = GetClientTeam(client);
  if (team == CS_TEAM_CT) {
    bool team_dead = WholeTeamDead(team);
    if (team_dead) {
      g_skip_t_wins_round_end = true;
    }
  } else if (team == CS_TEAM_T) {
    bool team_dead = WholeTeamDead(team);
    if (team_dead) {
      g_skip_ct_wins_round_end = true;
    }
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

  if (g_first_spawn[client]) {
    g_first_spawn[client] = false;
    return Plugin_Continue;
  }

  if (IsPlayerAlive(client)) {
    CancelRespawn(userid);
  }

  int team = GetClientTeam(client);
  if (team == CS_TEAM_CT) {
    g_skip_t_wins_round_end = false;
  } else if (team == CS_TEAM_T) {
    g_skip_ct_wins_round_end = false;
  }

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

  Respawn(userid);

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

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason) {
  if (!GetConVarBool(g_respawn_enabled_cvar)) {
    g_skip_ct_wins_round_end = false;
    g_skip_t_wins_round_end = false;
    return Plugin_Continue;
  }

  if (reason == CSRoundEnd_CTWin && g_skip_ct_wins_round_end) {
    g_skip_ct_wins_round_end = false;
    return Plugin_Stop;
  }

  if (reason == CSRoundEnd_TerroristWin && g_skip_t_wins_round_end) {
    g_skip_t_wins_round_end = false;
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

public void OnMapEnd() {
  for (int client = 0; client < MAXPLAYERS + 1; client++) {
    g_first_spawn[client] = false;
  }
  g_respawn_timers.Clear();
}

public void OnClientPutInServer(int client) { g_first_spawn[client] = true; }

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
#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.0.1"

ConVar g_cPluginEnabled;
ConVar g_cRoundRestartTime;
ConVar g_cVoteThreshold;

bool g_bPluginEnabled;
float g_fRoundRestartTime = 5.0;

int g_iCurrentPlayer;
int g_iVrrCmdVotes;
int g_iRequiredPlayerNum;
float g_fVoteThreshold;

bool votedPlayers[MAXPLAYERS+1];
bool g_bIsRestarting;

public Plugin myinfo =
{
    name = "Vote round restart",
    author = "faketuna",
    description = "Restart round with vote",
    version = PLUGIN_VERSION,
    url = "https://short.f2a.dev/s/github"
};

public void OnPluginStart() {
    LoadTranslations("voteRoundRestart.phrases");

    g_cPluginEnabled        = CreateConVar("vrr_enabled", "1", "Enable Disable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cVoteThreshold        = CreateConVar("vrr_vote_threshold", "0.6", "How many votes requires in vote. (percent)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cRoundRestartTime     = CreateConVar("vrr_round_restart_time", "5.0", "How long to take restarting round when vote passed.");

    RegConsoleCmd("sm_vrr", CommandVRR, "");


    g_cPluginEnabled.AddChangeHook(OnCvarsChanged);
    g_cVoteThreshold.AddChangeHook(OnCvarsChanged);
    g_cRoundRestartTime.AddChangeHook(OnCvarsChanged);

    g_iCurrentPlayer = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientConnected(i)) {
            OnClientConnected(i);
        }
    }
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
}

public Action CommandVRR(int client, int agrs) {
    if(!g_bPluginEnabled) {
        CPrintToChatAll("Plugin not enabled yet!");
        return Plugin_Handled;
    }

    if (IsFakeClient(client)) {
        CPrintToChatAll("Fake client!");
        return Plugin_Handled;
    }

    if (g_bIsRestarting) {
        CReplyToCommand(client, "%t%t", "vrr prefix", "vrr cmd restarting");
        return Plugin_Handled;
    }

    if (votedPlayers[client]) {
        CReplyToCommand(client, "%t%t", "vrr prefix", "vrr cmd already", g_iVrrCmdVotes, g_iRequiredPlayerNum);
        return Plugin_Handled;
    }
    char name[32];
    GetClientName(client, name, sizeof(name));
    g_iVrrCmdVotes++;
    votedPlayers[client] = true;
    TryRestart();
    CPrintToChatAll("%t%t", "vrr prefix", "vrr cmd wants restart", name, g_iVrrCmdVotes, g_iRequiredPlayerNum);
    return Plugin_Handled;
}

public void OnClientConnected(int client) {
    if(!IsFakeClient(client)) {
        g_iCurrentPlayer++;
        g_iRequiredPlayerNum = RoundToCeil(float(g_iCurrentPlayer) * g_fVoteThreshold);
    }
}

public void OnClientDisconnect(int client) {
    if(!IsFakeClient(client)) {
        g_iCurrentPlayer--;
        g_iRequiredPlayerNum = RoundToCeil(float(g_iCurrentPlayer) * g_fVoteThreshold);
        if(votedPlayers[client]) {
            votedPlayers[client] = false;
            g_iVrrCmdVotes--;
            TryRestart();
        }
    }
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    Reset();
    return Plugin_Handled;
}

public void syncValues() {
    g_fRoundRestartTime = g_cRoundRestartTime.FloatValue;
    g_bPluginEnabled    = g_cPluginEnabled.BoolValue;
    g_fVoteThreshold    = g_cVoteThreshold.FloatValue;
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    syncValues();
}

public void OnConfigsExecuted() {
    syncValues();
}

public void Reset() {
    g_bIsRestarting = false;
    g_iVrrCmdVotes = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientConnected(i) && !IsFakeClient(i)) {
            votedPlayers[i] = false;
        }
    }
}

public void RestartRound() {
    CS_TerminateRound(g_fRoundRestartTime, CSRoundEnd_Draw, true);
}

public void TryRestart() {
    if(g_iVrrCmdVotes >= g_iRequiredPlayerNum) {
        g_bIsRestarting = true;
        LogAction(0, -1, "Round restart vote passed! restarting round...");
        CPrintToChatAll("%t%t", "vrr prefix", "vrr vote success", RoundToFloor(g_fRoundRestartTime));
        RestartRound();
    }
}
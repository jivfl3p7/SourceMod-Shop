/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          shop-chat.sp                                   */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/01 11:37:14                                           */
/*                                                                */
/*  This code is licensed under the GPLv3 License.                */
/*                                                                */
/******************************************************************/


#pragma semicolon 1
#pragma newdecls required

#include <shop>
#include <clientprefs>

#define TYPE_NC 0
#define TYPE_CC 1
#define TYPE_NT 2

#define PI_NAME "MagicGirl.NET - Shop :: Chat Processor "
#define PI_AUTH "Kyle"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "[DARLING IN THE FRANXX] v" ... MAJORV ... "." ... MINORV ... "." ... BUILDs
#define PI_URLS "https://MagicGirl.net"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

enum Chat
{
    String:szUniqueId[32],
    String:szData[32],

    // other data.
    String:szName[128],
    String:szDesc[128]
}

any g_Chat[3][100][Chat];
int g_iChat[3];
Handle g_cookies[3];

UserMsg g_umUMId;
StringMap g_tMsgFmt;

int g_iClientTeam[MAXPLAYERS+1];
bool g_bChat[MAXPLAYERS+1];

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("This plugin only for CS:GO!");
        return;
    }
    
    g_umUMId = GetUserMessageId("SayText2");
    if(g_umUMId == INVALID_MESSAGE_ID)
    {
        SetFailState("SayText2 is invalid message ID!");
        return;
    }
    HookUserMessage(g_umUMId, OnSayText2, true);
    GenerateMessageFormats();
    
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    // category
    MG_Shop_RegItemCategory("namecolor", true, OnMenuInventory);
    MG_Shop_RegItemCategory("chatcolor", true, OnMenuInventory);
    MG_Shop_RegItemCategory("nametag",   true, OnMenuInventory);

    // cookies
    g_cookies[TYPE_NC] = RegClientCookie("chat_nc", "", CookieAccess_Private);
    g_cookies[TYPE_CC] = RegClientCookie("chat_cc", "", CookieAccess_Private);
    g_cookies[TYPE_NT] = RegClientCookie("chat_nt", "", CookieAccess_Private);

    // databse and item.
    ConnectAndLoad();

    // events
    HookEventEx("player_team", Event_PlayerTean, EventHookMode_Post);
    
    // hook cvars
    ConVar sv_full_alltalk = FindConVar("sv_full_alltalk");
    if(sv_full_alltalk != null)
    {
        sv_full_alltalk.SetInt(1);
        HookConVarChange(sv_full_alltalk, OnConVarChanged);
    }
    else
        LogError("sv_full_alltalk is null");
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    convar.SetInt(1);
}

void GenerateMessageFormats()
{
    g_tMsgFmt = new StringMap();
    
    g_tMsgFmt.SetString("Cstrike_Chat_CT_Loc", "(CT) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_CT", "(CT) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_T_Loc", "(TE) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_T", "(TE) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_CT_Dead", " \x07*DEAD* \x01(\x0BCT\x01) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_T_Dead", " \x07*DEAD* \x01(\x05TE\x01) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_Spec", "(SPEC) {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_All", " {1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_AllDead", " \x07*DEAD* \x01{1} \x01:  {2}");
    g_tMsgFmt.SetString("Cstrike_Chat_AllSpec", " \x0A*SPEC* \x01{1} \x01:  {2}");
}

public void ConnectAndLoad()
{
    char error[256];
    Database mySQL = SQL_Connect("default", true, error, 256);
    if(mySQL == null)
        SetFailState("Connect to database Error.");
    
    mySQL.SetCharset("utf8");

    // load items
    DBResultSet items = SQL_Query(mySQL, "SELECT a.*, b.fullname, b.description FROM dxg_items_chat a LEFT JOIN dxg_items b ON a.uniqueId = b.uniqueId ORDER BY a.id ASC;");
    if(items == null)
    {
        SQL_GetError(mySQL, error, 256);
        SetFailState("Can not retrieve items.skin from database: %s", error);
    }

    if(items.RowCount <= 0)
        SetFailState("Can not retrieve items.skin from database: no result row");

    char szType[32];
    while(items.FetchRow())
    {
        items.FetchString(1, szType, 32);

        int type = -1;
        if(strcmp(szType, "nametag") == 0)
            type = TYPE_NT;
        else if(strcmp(szType, "namecolor") == 0)
            type = TYPE_NC;
        else if(strcmp(szType, "chatcolor") == 0)
            type = TYPE_CC;
        else continue;

        items.FetchString(2, g_Chat[type][g_iChat[type]][szUniqueId],  32);
        items.FetchString(3, g_Chat[type][g_iChat[type]][szData],      32);
        items.FetchString(4, g_Chat[type][g_iChat[type]][szName],     128);
        items.FetchString(5, g_Chat[type][g_iChat[type]][szDesc],      32);
        
        g_iChat[type]++;
    }

    delete items;
    delete mySQL;
}

public void OnPluginEnd()
{
    MG_Shop_RemoveItemCategory("namecolor");
    MG_Shop_RemoveItemCategory("chatcolor");
    MG_Shop_RemoveItemCategory("nametag");
}

public void OnClientConnected(int client)
{
    g_bChat[client] = false;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    g_bChat[client] = true;
    CreateTimer(0.1, Timer_Say, client);
}

public Action Timer_Say(Handle timer, int client)
{
    g_bChat[client] = false;
    return Plugin_Stop;
}

public void Event_PlayerTean(Event event, const char[] name, bool dontBroadcast)
{
    g_iClientTeam[GetClientOfUserId(event.GetInt("userid"))] = event.GetInt("team");
}

public Action OnSayText2(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
    int m_iSender = msg.ReadInt("ent_idx");

    if(m_iSender <= 0)
        return Plugin_Continue;
    
    if(!g_bChat[m_iSender])
        return Plugin_Handled;

    g_bChat[m_iSender] = false;

    bool m_bChat = msg.ReadBool("chat");

    char m_szFlag[32], m_szName[128], m_szMsg[256], m_szFmt[32];

    msg.ReadString("msg_name", m_szFlag, 32);
    msg.ReadString("params", m_szName, 128, 0);
    msg.ReadString("params", m_szMsg, 256, 1);

    if(!GetTrieString(g_tMsgFmt, m_szFlag, m_szFmt, 32))
        return Plugin_Continue;

    RemoveAllColors(m_szName, 128);
    RemoveAllColors(m_szMsg, 256);

    ProcessChat(m_iSender, m_szName, m_szMsg);

    DataPack hPack = new DataPack();
    hPack.WriteCell(m_iSender);
    hPack.WriteCell(m_bChat);
    hPack.WriteString(m_szName);
    hPack.WriteString(m_szMsg);
    hPack.WriteString(m_szFlag);
    hPack.WriteString(m_szFmt);
    hPack.Reset();

    RequestFrame(Frame_OnChatMessage_SayText2, hPack);

    return Plugin_Handled;
}

void ProcessChat(int client, char name[128], char msg[256])
{
    char uid[3][32];
    GetClientCookie(client, g_cookies[TYPE_NT], uid[TYPE_NT], 32);
    GetClientCookie(client, g_cookies[TYPE_NC], uid[TYPE_NC], 32);
    GetClientCookie(client, g_cookies[TYPE_CC], uid[TYPE_CC], 32);
    
    int data[3];
    data[TYPE_NT] = UTIL_GetItem(uid[TYPE_NT]);
    data[TYPE_NC] = UTIL_GetItem(uid[TYPE_NC]);
    data[TYPE_CC] = UTIL_GetItem(uid[TYPE_CC]);
    
    char str[3][256];
    strcopy(str[TYPE_NT],  64, "");
    strcopy(str[TYPE_NC], 128, name);
    strcopy(str[TYPE_CC], 128, msg);

    if(data[TYPE_NT] > -1)
    {
        strcopy(str[TYPE_NT], 64, g_Chat[TYPE_NT][data[TYPE_NT]][szData]);
    }
    
    if(data[TYPE_NC] > -1)
    {
        FormatEx(str[TYPE_NC], 128, "%s%s", g_Chat[TYPE_NC][data[TYPE_NC]][szData], name);
    }
    else
    {
        switch(g_iClientTeam[client])
        {
            case  3: FormatEx(str[TYPE_NC], 128, "\x0B%s", name);
            case  2: FormatEx(str[TYPE_NC], 128, "\x05%s", name);
            default: FormatEx(str[TYPE_NC], 128, "\x0A%s", name);
        }
    }

    if(data[TYPE_CC] > -1)
    {
        FormatEx(str[TYPE_CC], 128, "%s%s", g_Chat[TYPE_CC][data[TYPE_CC]][szData], msg);
    }

    FormatEx(name, 128, "\x01%s %s", str[TYPE_NT], str[TYPE_NC]);
    FormatEx( msg, 256, "\x01%s"   , str[TYPE_CC]);
}

int UTIL_GetItem(const char[] uniqueId)
{
    for(int i = 0; i < g_iChat[TYPE_CC]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_CC][i][szUniqueId]) == 0)
            return i;
    
    for(int i = 0; i < g_iChat[TYPE_NC]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_NC][i][szUniqueId]) == 0)
            return i;
        
    for(int i = 0; i < g_iChat[TYPE_NT]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_NT][i][szUniqueId]) == 0)
            return i;
        
    return -1;
}

int UTIL_GetType(const char[] uniqueId)
{
    for(int i = 0; i < g_iChat[TYPE_CC]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_CC][i][szUniqueId]) == 0)
            return TYPE_CC;
    
    for(int i = 0; i < g_iChat[TYPE_NC]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_NC][i][szUniqueId]) == 0)
            return TYPE_NC;
        
    for(int i = 0; i < g_iChat[TYPE_NT]; ++i)
        if(strcmp(uniqueId, g_Chat[TYPE_NT][i][szUniqueId]) == 0)
            return TYPE_NT;

    return -1;
}

void Frame_OnChatMessage_SayText2(DataPack data)
{
    int m_iSender = data.ReadCell();
    bool m_bChat = data.ReadCell();

    char m_szName[128];
    data.ReadString(m_szName, 128);

    char m_szMsg[256];
    data.ReadString(m_szMsg, 256);

    char m_szFlag[32];
    data.ReadString(m_szFlag, 32);

    char m_szFmt[32];
    data.ReadString(m_szFmt, 32);

    delete data;

    int target_list[MAXPLAYERS+1], target_count;

    if(!ChatFromDead(m_szFlag) || g_iClientTeam[m_iSender] <= 1)
    {
        if(ChatToAll(m_szFlag))
        {
            for(int i = 1; i <= MaxClients; ++i)
                if(IsClientInGame(i) && !IsFakeClient(i))
                    target_list[target_count++] = i;
        }
        else
        {
            for(int i = 1; i <= MaxClients; ++i)
                if(IsClientInGame(i) && !IsFakeClient(i) && g_iClientTeam[i] == g_iClientTeam[m_iSender])
                    target_list[target_count++] = i;
        }
    }
    else
    {
        if(ChatToAll(m_szFlag))
        {
            for(int i = 1; i <= MaxClients; ++i)
                if(IsClientInGame(i) && !IsFakeClient(i))
                    target_list[target_count++] = i;
        }
        else
        {
            for(int i = 1; i <= MaxClients; ++i)
                if(IsClientInGame(i) && !IsFakeClient(i) && g_iClientTeam[i] == g_iClientTeam[m_iSender])
                    target_list[target_count++] = i;
        }
    }

    char m_szBuffer[512];
    strcopy(m_szBuffer, 512, m_szFmt);

    ReplaceString(m_szBuffer, 512, "{1}", m_szName);
    ReplaceString(m_szBuffer, 512, "{2}", m_szMsg);

    ReplaceColorsCode(m_szBuffer, 512);

    Protobuf pb = UserMessageToProtobuf(StartMessageEx(g_umUMId, target_list, target_count, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
    pb.SetInt("ent_idx", m_iSender);
    pb.SetBool("chat", m_bChat);
    pb.SetString("msg_name", m_szBuffer);
    pb.AddString("params", "");
    pb.AddString("params", "");
    pb.AddString("params", "");
    pb.AddString("params", "");
    EndMessage();
}

void ReplaceColorsCode(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{normal}",      "\x01", false);
    ReplaceString(message, maxLen, "{default}",     "\x01", false);
    ReplaceString(message, maxLen, "{white}",       "\x01", false);
    ReplaceString(message, maxLen, "{darkred}",     "\x02", false);
    ReplaceString(message, maxLen, "{pink}",        "\x03", false);
    ReplaceString(message, maxLen, "{green}",       "\x04", false);
    ReplaceString(message, maxLen, "{highlight}",   "\x04", false);
    ReplaceString(message, maxLen, "{yellow}",      "\x05", false);
    ReplaceString(message, maxLen, "{lightgreen}",  "\x05", false);
    ReplaceString(message, maxLen, "{cyan}",        "\x06", false);
    ReplaceString(message, maxLen, "{lime}",        "\x06", false);
    ReplaceString(message, maxLen, "{lightred}",    "\x07", false);
    ReplaceString(message, maxLen, "{red}",         "\x07", false);
    ReplaceString(message, maxLen, "{gray}",        "\x08", false);
    ReplaceString(message, maxLen, "{grey}",        "\x08", false);
    ReplaceString(message, maxLen, "{olive}",       "\x09", false);
    ReplaceString(message, maxLen, "{orange}",      "\x10", false);
    ReplaceString(message, maxLen, "{silver}",      "\x0A", false);
    ReplaceString(message, maxLen, "{lightblue}",   "\x0B", false);
    ReplaceString(message, maxLen, "{blue}",        "\x0C", false);
    ReplaceString(message, maxLen, "{purple}",      "\x0E", false);
    ReplaceString(message, maxLen, "{darkorange}",  "\x0F", false);
}

void RemoveAllColors(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{normal}",      "", false);
    ReplaceString(message, maxLen, "{default}",     "", false);
    ReplaceString(message, maxLen, "{white}",       "", false);
    ReplaceString(message, maxLen, "{darkred}",     "", false);
    ReplaceString(message, maxLen, "{teamcolor}",   "", false);
    ReplaceString(message, maxLen, "{pink}",        "", false);
    ReplaceString(message, maxLen, "{green}",       "", false);
    ReplaceString(message, maxLen, "{HIGHLIGHT}",   "", false);
    ReplaceString(message, maxLen, "{lime}",        "", false);
    ReplaceString(message, maxLen, "{lightgreen}",  "", false);
    ReplaceString(message, maxLen, "{lime}",        "", false);
    ReplaceString(message, maxLen, "{lightred}",    "", false);
    ReplaceString(message, maxLen, "{red}",         "", false);
    ReplaceString(message, maxLen, "{gray}",        "", false);
    ReplaceString(message, maxLen, "{grey}",        "", false);
    ReplaceString(message, maxLen, "{olive}",       "", false);
    ReplaceString(message, maxLen, "{yellow}",      "", false);
    ReplaceString(message, maxLen, "{orange}",      "", false);
    ReplaceString(message, maxLen, "{silver}",      "", false);
    ReplaceString(message, maxLen, "{lightblue}",   "", false);
    ReplaceString(message, maxLen, "{blue}",        "", false);
    ReplaceString(message, maxLen, "{purple}",      "", false);
    ReplaceString(message, maxLen, "{darkorange}",  "", false);
    
    ReplaceString(message, maxLen, "\x01", "", false);
    ReplaceString(message, maxLen, "\x02", "", false);
    ReplaceString(message, maxLen, "\x03", "", false);
    ReplaceString(message, maxLen, "\x04", "", false);
    ReplaceString(message, maxLen, "\x05", "", false);
    ReplaceString(message, maxLen, "\x06", "", false);
    ReplaceString(message, maxLen, "\x07", "", false);
    ReplaceString(message, maxLen, "\x08", "", false);
    ReplaceString(message, maxLen, "\x09", "", false);
    ReplaceString(message, maxLen, "\x10", "", false);
    ReplaceString(message, maxLen, "\x0A", "", false);
    ReplaceString(message, maxLen, "\x0B", "", false);
    ReplaceString(message, maxLen, "\x0C", "", false);
    ReplaceString(message, maxLen, "\x0D", "", false);
    ReplaceString(message, maxLen, "\x0E", "", false);
    ReplaceString(message, maxLen, "\x0F", "", false);
}

bool ChatToAll(const char[] flag)
{
    if(StrContains(flag, "_All", false) != -1)
        return true;

    return false;
}

bool ChatFromDead(const char[] flag)
{
    if(StrContains(flag, "Dead", false) != -1)
        return true;

    return false;
}

public void OnMenuInventory(int client, const char[] uniqueId, bool inventory)
{
    Menu menu = new Menu(MenuHandler_InvMenu);
    
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    
    int type = UTIL_GetType(uniqueId);
    if(type == -1)
    {
        PrintToChat(client, "[\x04Shop\x01]   \x10该物品目前不可用...");
        MG_Shop_DisplayPreviousMenu(client);
        return;
    }
    
    int item = UTIL_GetItem(uniqueId);
    
    bool equip = false;
    for(int i; i < 3; ++i)
    {
        char data[32];
        GetClientCookie(client, g_cookies[i], data, 32);
        if(strcmp(uniqueId, data) == 0)
            equip = true;
    }

    switch(type)
    {
        case TYPE_CC : menu.SetTitle("商店 - %s\n余额: %d G\n \n聊天颜色 :: %s\n%s\n ", inventory ? "库存" : "展柜", MG_Shop_GetClientMoney(client), g_Chat[TYPE_CC][item][szName], g_Chat[TYPE_CC][item][szDesc]);
        case TYPE_NT : menu.SetTitle("商店 - %s\n余额: %d G\n \n名字标签 :: %s\n%s\n ", inventory ? "库存" : "展柜", MG_Shop_GetClientMoney(client), g_Chat[TYPE_NT][item][szName], g_Chat[TYPE_NT][item][szDesc]);
        case TYPE_NC : menu.SetTitle("商店 - %s\n余额: %d G\n \n名字颜色 :: %s\n%s\n ", inventory ? "库存" : "展柜", MG_Shop_GetClientMoney(client), g_Chat[TYPE_NC][item][szName], g_Chat[TYPE_NC][item][szDesc]);
    }


    menu.AddItem(uniqueId, "预览");
    menu.AddItem(uniqueId, !equip ? "装备" : "卸下", inventory ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem(uniqueId, !inventory ? "购买" : "售出");

    menu.Display(client, 60);
}

public int MenuHandler_InvMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char uniqueId[32];
        menu.GetItem(param2, uniqueId, 32);
        
        int type = UTIL_GetType(uniqueId);
        int item = UTIL_GetItem(uniqueId);

        switch(param2)
        {
            case 0: 
            {
                char name[128] = "这是你的名字";
                char msg[128]  = "s这是你打字的内容!";

                if(item > -1)
                {
                    if(type == TYPE_CC)
                        FormatEx(msg, 128, "%s这是你打字的内容!", g_Chat[TYPE_CC][item][szData]);
                    else if(type == TYPE_NC)
                        FormatEx(name, 128, "%s这是你的名字", g_Chat[TYPE_NC][item][szData]);
                    else if(type == TYPE_NT)
                        FormatEx(name, 128, "%s这是你的名字", g_Chat[TYPE_NT][item][szData]);
                }

                PrintToChat(param1, "%s :  %s", name, msg);
            }
            case 1: 
            {
                bool equip = false;
                for(int i; i < 3; ++i)
                {
                    char data[32];
                    GetClientCookie(param1, g_cookies[i], data, 32);
                    if(strcmp(uniqueId, data) == 0)
                        equip = true;
                }
                
                if(!equip)
                    EquipItem(param1, uniqueId);
                else
                    UnEquipItem(param1, UTIL_GetType(uniqueId));
            }
            case 2: 
            {
                if(MG_Shop_HasClientItem(param1, uniqueId))
                {
                    MG_Shop_BuyItemMenu(param1, uniqueId);
                    return;
                }
                
                PrintToChat(param1, "[\x04Shop\x01]   暂时不开放售出");
            }
        }

        MG_Shop_DisplayItemMenu(param1, uniqueId);
    }
    else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
        MG_Shop_DisplayPreviousMenu(param1);
    else if(action == MenuAction_End)
        delete menu;
}

void EquipItem(int client, const char[] uniqueId)
{
    int item = UTIL_GetItem(uniqueId);
    int type = UTIL_GetType(uniqueId);

    SetClientCookie(client, g_cookies[type], uniqueId);
    
    switch(type)
    {
        case TYPE_CC : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已保存\x04聊天颜色\x01为[\x10%s\x01]", g_Chat[type][item][szName]);
        case TYPE_NT : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已保存\x04名字标签\x01为[\x10%s\x01]", g_Chat[type][item][szName]);
        case TYPE_NC : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已保存\x04名字颜色\x01为[\x10%s\x01]", g_Chat[type][item][szName]);
    }
}

void UnEquipItem(int client, int type)
{
    SetClientCookie(client, g_cookies[type], "");

    switch(type)
    {
        case TYPE_CC : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已取消装备\x04聊天颜色");
        case TYPE_NT : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已取消装备\x04名字标签");
        case TYPE_NC : PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   已取消装备\x04名字颜色");
    }
}
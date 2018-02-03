/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          menu.sp                                        */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/01 11:37:14                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


int iMenuLevels[MAXPLAYERS+1];
int iMenuParent[MAXPLAYERS+1];
bool bInventory[MAXPLAYERS+1];

void DisplayMainMenu(int client)
{
    iMenuLevels[client] = 0;

    Menu menu = new Menu(MenuHandler_MainMenu);
    
    menu.SetTitle("商店 - 主菜单\n余额: %d G", g_ClientData[client][iMoney]);
    
    menu.AddItem("code:002", "商店");
    menu.AddItem("code:016", "库存");
    
    menu.ExitButton = true;
    menu.ExitBackButton = false;

    menu.Display(client, 15);
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        if(param2 == 0)
            DisplayShopMenu(param1, false);
        else if(param2 == 1)
            DisplayShopMenu(param1, true);
        else
            LogMessage("wtf?");
    }
    else if(action == MenuAction_End)
        delete menu;
}

void DisplayShopMenu(int client, bool invMode, int parent = -1, int lastItem = -1)
{
    iMenuLevels[client] = 1;
    bInventory[client]  = invMode;

    Menu menu = new Menu(MenuHandler_ShopMenu);
    
    menu.ExitButton = true;
    menu.ExitBackButton = true;

    if(parent != -1)
    {
        menu.SetTitle("%s - %s\n余额: %d G\n ", invMode ? "商店" : "库存", g_Items[parent][szShortName], g_ClientData[client][iMoney]);
        iMenuParent[client] = g_Items[parent][iParent];
    }
    else
        menu.SetTitle("%s - 总览\n余额: %d G\n ", invMode ? "商店" : "库存", g_ClientData[client][iMoney]);

    for(int item = 0; item < g_iItems; ++item)
    {
        if(g_Items[item][iParent] != parent)
            continue;

        bool hasItem = UTIL_HasClientItem(client, g_Items[item][szUniqueId]);
        
        if(invMode && !hasItem && g_Items[item][iCategory] != g_iFakeCategory)
            continue;
        
        if(!invMode && hasItem && g_Items[item][iCategory] != g_iFakeCategory)
            continue;
        
        if(!invMode && strlen(g_Items[item][szPersonalId][0]) > 3)
            continue;

        menu.AddItem(g_Items[item][szUniqueId], g_Items[item][szFullName], (g_Items[item][iCategory] == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }
    
    if(menu.ItemCount == 0)
    {
        Chat(client, "\x07当前%s无物品可用...", invMode ? "库存" : "商店");
        DisplayMainMenu(client);
        delete menu;
        return;
    }

    if(lastItem == -1)
        menu.Display(client, 0);
    else
        menu.DisplayAt(client, (lastItem/menu.Pagination)*menu.Pagination, 0);
}

public int MenuHandler_ShopMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_End)
        delete menu;
    else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
        DisplayPreviousMenu(param1);
    else if(action == MenuAction_Select)
    {
        char unique[32];
        menu.GetItem(param2, unique, 32);
        
        int itemid = UTIL_FindItemByUniqueId(unique);

        iMenuLevels[param1] = 2;
        iMenuParent[param1] = g_Items[itemid][iParent];

        if(g_Items[itemid][iCategory] != g_iFakeCategory)
        {
            Call_StartFunction(g_Category[g_Items[itemid][iCategory]][hPlugin], g_Category[g_Items[itemid][iCategory]][fnMenu]);
            Call_PushCell(param1);
            Call_PushString(unique);
            Call_PushCell(UTIL_HasClientItem(param1, unique));
            Call_Finish();
            
            return;
        }

        DisplayShopMenu(param1, bInventory[param1], itemid, -1);
    }
}

void DisplayPreviousMenu(int client)
{
    switch(iMenuLevels[client])
    {
        case 0: DisplayMainMenu(client);
        case 1: DisplayMainMenu(client);
        case 2: DisplayShopMenu(client, bInventory[client], iMenuParent[client]);
    }
}
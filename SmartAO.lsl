 
/*
   SmartAO by lickx
   2021-12-06
  
   Just drop in animations in the HUD. No notecard needed.
   Accepted animations (others will simply be ignored):
   
     Crouching
     CrouchWalking
     Falling Down
     Floating
     Flying
     FlyingSlow
     Hovering
     Hovering Down (sometimes called Flying Down)
     Hovering Up (sometimes called Flying Up)
     Jumping
     Landing
     PreJumping
     Running
     Sitting
     Sitting on Ground
     Standing (see note below)
     Standing Up
     Striding
     Soft Landing
     Swimming (sometimes called Swimming Forward)
     Swimming Down
     Swimming Up
     Taking Off
     Turning Left
     Turning Right
     Walking (see note below)

   There can be one or more standing animations as long as they are
   prefixed with "Standing". They can be random or sequential (see menu).

   The same goes for walking animations, as long as they are prefixed
   with "Walking". Walks change randomly on g_iStandTime intervals.
   
   Using "Test Walks" you can choose which walks to keep or else delete.
   While in this mode, the same buttons are used as for Stands.
   
   The water resistance (=slower movement) only works with ubODE physics.
   When starting to float (press home when standing on the seafloor), give
   it 3 seconds before swimming (press forward), otherwise you'll fly out
   of the water. This differs from SL physics.

 */

key g_kOwner;

list g_lAnimWalking;
integer g_iCurrentWalk = 0;

integer g_iRlvOn = 0;
integer g_iRlvHandle;
integer RLV_CHANNEL = 5050;
integer g_iRlvTimeout = 0;

integer g_iHaveSwimAnims; // bitfield of swimming anims we have: swimming, floating, swim down, swim up
integer g_iUsingSwimAnims; // do we have swim anims activated instead of flying anims?
float g_fWaterLevel;

integer g_iHaveFlyAnims;

list g_lAnimStanding; // list of stands (animations with name starting with "Standing")
integer g_iStandTime = 30;      // stand time in seconds
integer g_iRandomStands = TRUE; // TRUE=random, FALSE=sequential
integer g_iNextStandStart;
integer g_iCurrentStand;
string g_sLastStand;  // to recover to from coming out of suspending

integer g_iEnabled = TRUE;
integer g_iSitAnywhere = FALSE;
integer g_iMenuOpened;

integer LOCKMEISTER_CH = -8888;
integer g_iLMHandle;
integer g_iEnableLM;
integer g_iOpenCollar_CH;

float g_fGroundsitHover = 0.0;
float g_fSitHover = 0.0;
float HOVER_INCREMENT = 0.05;
integer g_iHoverAdjusted = FALSE;

integer g_iDialogHandle;
integer g_iDialogChannel;

string g_sTexture;

integer g_iHoverInfo = FALSE;
integer g_iTestingWalks = FALSE;

string g_sAnimToDelete;

integer g_iLastMenu = 0;
integer MENU_NONE = 0;
integer MENU_STAND = 1;
integer MENU_GROUNDSIT = 2;
integer MENU_SIT = 3;

string Hover2String(float fHover)
{
    string sHover = (string)fHover;
    if (llGetSubString(sHover, 0, 0) == "-") return llGetSubString(sHover, 0, 4);
    else return llGetSubString(sHover, 0, 3);
}

Swim2Fly()
{
    if (g_iHaveFlyAnims & 1)
        llSetAnimationOverride("Flying","Flying");
    if (g_iHaveFlyAnims & 2)
        llSetAnimationOverride("Hovering","Hovering");
    if (g_iHaveFlyAnims & 4)
        llSetAnimationOverride("Hovering Down","Hovering Down");
    if (g_iHaveFlyAnims & 8)
        llSetAnimationOverride("Hovering Up","Hovering Up");
    g_iUsingSwimAnims=FALSE;
}

Fly2Swim()
{
    if (g_iHaveSwimAnims & 1)
        llSetAnimationOverride("Flying","Swimming");
    if (g_iHaveSwimAnims & 2)
        llSetAnimationOverride("Hovering","Floating");
    if (g_iHaveSwimAnims & 4)
        llSetAnimationOverride("Hovering Down","Swimming Down");
    if (g_iHaveSwimAnims & 8)
        llSetAnimationOverride("Hovering Up","Swimming Up");    
    g_iUsingSwimAnims=TRUE;
}

NextStand()
{
    integer iNumStands = llGetListLength(g_lAnimStanding);
    if (iNumStands == 0) return;
    else if (iNumStands == 1) g_iCurrentStand = 0;
    else if (g_iRandomStands) {
        g_iCurrentStand = llRound(llFrand(iNumStands-1));
    } else {
        if (g_iCurrentStand < iNumStands-1) g_iCurrentStand++;
        else g_iCurrentStand = 0;
    }
    string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
    llSetAnimationOverride("Standing",sAnim);
    g_sLastStand = sAnim;
    if (g_iHoverInfo) llSetText(llList2String(g_lAnimStanding, g_iCurrentStand), <1,1,1>, 1);
}

PrevStand()
{
    integer iNumStands = llGetListLength(g_lAnimStanding);
    if (g_iRandomStands) {
        NextStand();
        return;
    }
    if (iNumStands == 0) return;
    else if (iNumStands == 1) g_iCurrentStand = 0;
    else if (g_iCurrentStand > 0) g_iCurrentStand--;
    else g_iCurrentStand = iNumStands-1;
    string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
    llSetAnimationOverride("Standing",sAnim);
    g_sLastStand = sAnim;
    if (g_iHoverInfo) llSetText(llList2String(g_lAnimStanding, g_iCurrentStand), <1,1,1>, 1);
}

SpecificStand(string sAnim)
{
    integer idx = llListFindList(g_lAnimStanding, [sAnim]);
    if (~idx) {
        llSetAnimationOverride("Standing",sAnim);
        g_iCurrentStand = idx;
        g_sLastStand = sAnim;
        if (g_iHoverInfo) llSetText(llList2String(g_lAnimStanding, g_iCurrentStand), <1,1,1>, 1);
    } else {
        NextStand();
    }
}

PrevTestWalk()
{
    integer iNumWalks = llGetListLength(g_lAnimWalking);
    if (iNumWalks == 0) return;
    else if (iNumWalks == 1) g_iCurrentWalk = 0;
    else if (g_iCurrentWalk > 0) g_iCurrentWalk--;
    else g_iCurrentWalk = iNumWalks-1;
    string sAnim = llList2String(g_lAnimWalking, g_iCurrentWalk);
    llSetAnimationOverride("Standing",sAnim);
    if (g_iHoverInfo) llSetText("(Testing walks)\n"+llList2String(g_lAnimWalking, g_iCurrentWalk), <1,1,1>, 1);
}

NextTestWalk()
{
    integer iNumWalks = llGetListLength(g_lAnimWalking);
    if (iNumWalks == 0) return;
    else if (iNumWalks == 1) g_iCurrentWalk = 0;
    else if (g_iCurrentWalk < iNumWalks-1) g_iCurrentWalk++;
    else g_iCurrentWalk = 0;
    string sAnim = llList2String(g_lAnimWalking, g_iCurrentWalk);
    llSetAnimationOverride("Standing",sAnim);
    if (g_iHoverInfo) llSetText("(Testing walks)\n"+llList2String(g_lAnimWalking, g_iCurrentWalk), <1,1,1>, 1);
}

Enable()
{
    list VALID_ANIMS = ["Crouching", "CrouchWalking", "Falling Down", "Flying",
        "FlyingSlow", "Hovering", "Hovering Down", "Hovering Up", "Jumping",
        "Landing", "PreJumping", "Running", "Sitting", "Sitting on Ground",
        "Standing Up", "Striding", "Soft Landing", "Taking Off", "Turning Left",
        "Turning Right"];
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE, 0, g_sTexture, <1,1,0>, <0,0.5,0>, 0]);
    llResetAnimationOverride("ALL");
    g_lAnimStanding = [];
    g_lAnimWalking = [];
    g_iHaveFlyAnims = 0;
    g_iHaveSwimAnims = 0;
    integer i = 0;
    while (i < llGetInventoryNumber(INVENTORY_ANIMATION)) {
        string sAnim = llGetInventoryName(INVENTORY_ANIMATION, i++);
        if ((~llSubStringIndex(sAnim, "Standing")) && sAnim != "Standing Up") g_lAnimStanding += sAnim;
        if ((~llSubStringIndex(sAnim, "Walking")) && sAnim != "CrouchWalking") g_lAnimWalking += sAnim;
        else if (sAnim == "Flying") g_iHaveFlyAnims = g_iHaveFlyAnims | 1;
        else if (sAnim == "Hovering") g_iHaveFlyAnims = g_iHaveFlyAnims | 2;
        else if (sAnim == "Hovering Down") g_iHaveFlyAnims = g_iHaveFlyAnims | 4;
        else if (sAnim == "Hovering Up") g_iHaveFlyAnims = g_iHaveFlyAnims | 8;
        else if (sAnim == "Swimming") g_iHaveSwimAnims = g_iHaveSwimAnims | 1;
        else if (sAnim == "Floating") g_iHaveSwimAnims = g_iHaveSwimAnims | 2;
        else if (sAnim == "Swimming Down") g_iHaveSwimAnims = g_iHaveSwimAnims | 4;
        else if (sAnim == "Swimming Up") g_iHaveSwimAnims = g_iHaveSwimAnims | 8;
        else if (~llListFindList(VALID_ANIMS, [sAnim])) llSetAnimationOverride(sAnim, sAnim);
    }

    if (llGetAnimation(g_kOwner) != "Sitting") {
        llOwnerSay("@adjustheight:1;0;0.0=force");
        g_iHoverAdjusted = FALSE;
    }

    if (llGetListLength(g_lAnimStanding)) {
        SpecificStand(g_sLastStand);
        llSetTimerEvent(g_iStandTime);
    }

    if (llGetListLength(g_lAnimWalking)) {
        PickWalk();
        llSetTimerEvent(g_iStandTime);
    }

    float fWaterLevel = llWater(ZERO_VECTOR);
    vector vPos = llGetPos();
    if (g_iHaveFlyAnims && vPos.z >= fWaterLevel) Swim2Fly();
    else if (g_iHaveSwimAnims) Fly2Swim();

    g_iEnabled = TRUE;
    VALID_ANIMS = []; // maybe needed for yEngine, free up list memory.
}

Disable()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE, 0, g_sTexture, <1,1,0>, <0,0,0>, 0]);
    llSetTimerEvent(0.0);
    llResetAnimationOverride("ALL");
    g_iEnabled = FALSE;
}

HideMenu()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 4, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 5, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 6, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0
    ]);
    if (g_iHoverInfo) llSetText("", <1,1,1>, 1);
    g_iLastMenu = MENU_NONE;
}

ShowStandMenu()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 1, g_sTexture, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 4, g_sTexture, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 5, g_sTexture, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 6, g_sTexture, <1,1,0>, <0,0,0>, 0
    ]);
    if (g_iHoverInfo) {
        if (!g_iTestingWalks) llSetText(llList2String(g_lAnimStanding, g_iCurrentStand), <1,1,1>, 1);
        else llSetText("(Testing walks)\n"+llList2String(g_lAnimWalking, g_iCurrentWalk), <1,1,1>, 1);
    }
    g_iLastMenu = MENU_STAND;
}

ShowGroundsitMenu()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 1, g_sTexture, <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 4, g_sTexture, <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 5, g_sTexture, <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 6, g_sTexture, <1,1,0>, <0,0.5,0>, 0
    ]);
    if (g_iHoverInfo) llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
    g_iLastMenu = MENU_GROUNDSIT;
}

ShowSitMenu()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 1, g_sTexture, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 4, g_sTexture, <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 5, g_sTexture, <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 6, g_sTexture, <1,1,0>, <0,0.5,0>, 0
    ]);
    if (g_iHoverInfo) llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
    g_iLastMenu = MENU_SIT;
}

DeleteDialog(string sAnim)
{
    llSetTimerEvent(0.0);
    g_sAnimToDelete = sAnim;
    g_iDialogChannel = -393939;
    g_iDialogHandle = llListen(g_iDialogChannel, "", g_kOwner, "");
    llDialog(g_kOwner, "Delete animation '"+g_sAnimToDelete+"'?", ["Delete", "Cancel"], g_iDialogChannel);
}

DeleteAnim(string sAnim)
{
    integer iOwnerPerms = llGetInventoryPermMask(sAnim, MASK_OWNER);
    if (iOwnerPerms & PERM_COPY)
        llRemoveInventory(sAnim);
    else
        llGiveInventory(g_kOwner, sAnim);
}

OptionDialog()
{
    g_iDialogChannel = -393939;
    g_iDialogHandle = llListen(g_iDialogChannel, "", g_kOwner, "");
    list lButtons;
    if (g_iTestingWalks) lButtons += "??? Test Walks";
    else lButtons += "??? Test Walks";
    lButtons += "Reload";
    lButtons += "Close";
    if (g_iRandomStands) lButtons += "??? Random";
    else lButtons += "??? Random";
    if (g_iEnableLM) lButtons += "??? Lockmeister";
    else lButtons += "??? Lockmeister";
    if (g_iHoverInfo) lButtons += "??? Hover Info";
    else lButtons += "??? Hover Info";
    lButtons += ["15 sec.", "30 sec.", "45 sec."];
    llDialog(g_kOwner, "SmartAO Options", lButtons, g_iDialogChannel);
}

RestoreSettings()
{
    integer iLinkSettings = osGetLinkNumber("settings");
    if (iLinkSettings == -1) return;
    string sDesc = llList2String(llGetLinkPrimitiveParams(iLinkSettings, [PRIM_DESC]), 0);
    list lSettings = llParseString2List(sDesc, [",","="], []);
    integer i;
    for (i = 0; i < llGetListLength(lSettings); i+=2)
    {
        string sSetting = llList2String(lSettings, i);
        if (sSetting == "hover") g_fGroundsitHover = llList2Float(lSettings, i+1);
        else if (sSetting == "random") g_iRandomStands = llList2Integer(lSettings, i+1);
        else if (sSetting == "standtime") g_iStandTime = llList2Integer(lSettings, i+1);
        else if (sSetting == "info") g_iHoverInfo = llList2Integer(lSettings, i+1);
        else if (sSetting == "lm") g_iEnableLM = llList2Integer(lSettings, i+1);
    }
}

SaveSettings()
{
    integer iLinkSettings = osGetLinkNumber("settings");
    if (iLinkSettings == -1) return;
    string sSettings;
    sSettings += "hover="+Hover2String(g_fGroundsitHover);
    sSettings += ",random="+(string)g_iRandomStands;
    sSettings += ",standtime="+(string)g_iStandTime;
    sSettings += ",info="+(string)g_iHoverInfo;
    sSettings += ",lm="+(string)g_iEnableLM;
    llSetLinkPrimitiveParamsFast(iLinkSettings, [PRIM_DESC, sSettings]);
}

PickWalk()
{
    integer iNumWalks = llGetListLength(g_lAnimWalking);
    integer iWalk;
    if (iNumWalks == 0) return;
    if (iNumWalks == 1) iWalk = 0;
    else iWalk = (integer)llFrand(llGetListLength(g_lAnimWalking));
    string sNextWalk = llList2String(g_lAnimWalking, iWalk);
    llSetAnimationOverride("Walking", sNextWalk);
}

Init()
{
    g_kOwner = llGetOwner();
    g_sTexture = llGetInventoryName(INVENTORY_TEXTURE, 0);
    llSetTexture(g_sTexture, ALL_SIDES);
    g_fWaterLevel = llWater(ZERO_VECTOR);
    RestoreSettings();
    if (llGetAttached()) llRequestPermissions(g_kOwner, PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TAKE_CONTROLS);
    g_iOpenCollar_CH = -llAbs((integer)("0x" + llGetSubString(g_kOwner,30,-1)));
    llListen(g_iOpenCollar_CH, "", "", "");
    if (g_iEnableLM) g_iLMHandle = llListen(LOCKMEISTER_CH, "", "", "");
    g_iRlvHandle = llListen(RLV_CHANNEL, "", g_kOwner, "");
    g_iRlvTimeout = llGetUnixTime() + 60;
    llOwnerSay("@versionnew="+(string)RLV_CHANNEL);
}

default
{
    state_entry()
    {
        // Script lost state or has been reset/recompiled:
        if (g_kOwner == NULL_KEY || g_kOwner == "") Init();
    }

    on_rez(integer i)
    {
        if (llGetAttached()) Init();
        else Disable();
    }
    
    attach(key kID)
    {
        if (kID == NULL_KEY) llResetAnimationOverride("ALL");
    }
    
    touch_end(integer i)
    {
        if (llDetectedKey(0) != g_kOwner) return;
        
        integer iButton = llDetectedTouchFace(0);
        string sAnim = llGetAnimation(g_kOwner);
        if (iButton == 0) {
            // Power
            g_iEnabled = !g_iEnabled;
            if (g_iEnabled) Enable();
            else Disable();
        } else if (iButton == 1) {
            g_iSitAnywhere = !g_iSitAnywhere;
            if (g_iSitAnywhere) {
                if (llGetInventoryType("Sitting on Ground")!=INVENTORY_ANIMATION) return;
                // Fake groundsit
                llSetTimerEvent(0.0);
                llSetAnimationOverride("Standing", "Sitting on Ground");
                // If all viewers conformed to RLV this would be possible instead:
                //llOwnerSay("@sitground=force");
            } else {
                // stand up from fake groundsit and re-enable timer
                NextStand();
                if (llGetListLength(g_lAnimStanding) > 1) llSetTimerEvent(g_iStandTime);
            }
        } else if (iButton == 2) OptionDialog();
        else if (iButton == 4) {
            if (g_iTestingWalks) PrevTestWalk();
            else if (sAnim == "Standing" && !g_iSitAnywhere) PrevStand();
            else if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Adjust groundsit height upwards
                g_fGroundsitHover+=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                if (g_iHoverInfo) llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Adjust regular sit height upwards
                g_fSitHover+=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                if (g_fSitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                if (g_iHoverInfo) llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
            }
        } else if (iButton == 5) {
            if (g_iTestingWalks) NextTestWalk();
            else if (sAnim == "Standing" && !g_iSitAnywhere) NextStand();
            else if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Adjust groundsit height downwards
                g_fGroundsitHover-=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                if (g_iHoverInfo) llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Adjust regular sit height downwards
                g_fSitHover-=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                if (g_fSitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                if (g_iHoverInfo) llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
            }
        } else if (iButton == 6) {
            if (g_iTestingWalks) DeleteDialog(llList2String(g_lAnimWalking, g_iCurrentWalk));
            else if (sAnim == "Standing" && !g_iSitAnywhere) DeleteDialog(llList2String(g_lAnimStanding, g_iCurrentStand));
            else if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Reset groundsit height
                g_fGroundsitHover=0.0;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                g_iHoverAdjusted = FALSE;
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Reset regular sit height
                g_fSitHover = 0.0;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                g_iHoverAdjusted = FALSE;
            }
        }
    }
    
    listen(integer iChannel, string sName, key kID, string sMsg)
    {
        if (iChannel == RLV_CHANNEL) {
            g_iRlvOn = TRUE;
            llListenRemove(g_iRlvHandle);
            g_iRlvHandle = 0;
            g_iRlvTimeout = 0;
        } else if (iChannel == g_iDialogChannel) {
            if (sMsg == "Delete") {
                if (g_iTestingWalks) {
                    integer idx = llListFindList(g_lAnimWalking, [g_sAnimToDelete]);
                    if (~idx) {
                        g_lAnimWalking = llDeleteSubList(g_lAnimWalking, idx, idx);
                        DeleteAnim(g_sAnimToDelete);
                        NextTestWalk();
                    }
                } else {
                    // stands
                    integer idx = llListFindList(g_lAnimStanding, [g_sAnimToDelete]);
                    if (~idx) {
                        g_lAnimStanding = llDeleteSubList(g_lAnimStanding, idx, idx);
                        DeleteAnim(g_sAnimToDelete);
                        NextStand();
                    }
                }
            } else if (sMsg == "Reload") {
                llResetScript();
            } else if (sMsg == "??? Random") {
                g_iRandomStands = FALSE;
                NextStand();
            } else if (sMsg == "??? Random") {
                g_iRandomStands = TRUE;
                NextStand();
            } else if (sMsg == "??? Lockmeister") {
                g_iEnableLM = FALSE;
                llListenRemove(g_iLMHandle);
            } else if (sMsg == "??? Lockmeister") {
                g_iEnableLM = TRUE;
                llListen(LOCKMEISTER_CH, "", "", "");
            } else if (sMsg == "??? Hover Info") {
                g_iHoverInfo = FALSE;
                llSetText("", <1,1,1>, 1);
            } else if (sMsg == "??? Hover Info") {
                g_iHoverInfo = TRUE;
            } else if (sMsg == "??? Test Walks") {
                g_iTestingWalks = FALSE;
                NextStand();
            } else if (sMsg == "??? Test Walks") {
                g_iTestingWalks = TRUE;
                llSetTimerEvent(0.0);
                NextTestWalk();
            } else if (sMsg == "15 secs." || sMsg == "30 secs." || sMsg == "45 secs.") {
                g_iStandTime = (integer)llGetSubString(sMsg, 0, 1);
                NextStand();
            }
            SaveSettings();
            llListenRemove(g_iDialogHandle);
            llSetTimerEvent(g_iStandTime);
        } else if (iChannel == LOCKMEISTER_CH) {
            if (llGetSubString(sMsg,0,35) == (string)g_kOwner) {
                sMsg = llGetSubString(sMsg,36,-1);
                if (sMsg == "booton") Enable();
                else if (sMsg == "bootoff") Disable();
            } else return;
        } else if (llGetOwnerKey(kID) != g_kOwner) return;
        else if (iChannel == g_iOpenCollar_CH) {
            if(sMsg == "ZHAO_STANDON" || sMsg == "ZHAO_AOON") Enable();
            else if (sMsg == "ZHAO_STANDOFF" || sMsg == "ZHAO_AOOFF") Disable();
        }
    }
    
    run_time_permissions(integer iPerms)
    {
        if (iPerms & PERMISSION_OVERRIDE_ANIMATIONS) Enable();
        if (iPerms & PERMISSION_TAKE_CONTROLS)
            llTakeControls(CONTROL_BACK|CONTROL_FWD|CONTROL_UP|CONTROL_DOWN, TRUE, TRUE);
    }
    
    control(key kID, integer iLevels, integer iEdges)
    {
        if (!g_iHaveSwimAnims) return;

        vector vPos = llGetPos();
        if (vPos.z >= g_fWaterLevel) {
            if (g_iUsingSwimAnims) Swim2Fly();
            return;
        }

        if (!g_iUsingSwimAnims) Fly2Swim();
        string sCurAnim = llGetAnimation(g_kOwner);
        if (sCurAnim=="Walking" || sCurAnim=="Running") return;
        vector vMove = ZERO_VECTOR;
        if ( iLevels & ~iEdges & CONTROL_FWD) vMove.x += 1.5;
        if ( iLevels & ~iEdges & CONTROL_BACK) vMove.x += -1.5;
        if ( iLevels & ~iEdges & CONTROL_UP) vMove.z += 0.8;
        if ( iLevels & ~iEdges & CONTROL_DOWN) vMove.z += -0.2;
        vMove.z += -0.2; // gravity
        if (sCurAnim=="Hovering Down") vMove.z = 0; // hack to avoid ground bouncing
        if (vMove != ZERO_VECTOR) llApplyImpulse((vMove*llGetRot()), FALSE);
    }

    changed(integer iChange)
    {
        if ((iChange & CHANGED_INVENTORY) && g_iEnabled) Enable();
        if (iChange & CHANGED_REGION || iChange & CHANGED_TELEPORT) {
            g_fWaterLevel = llWater(ZERO_VECTOR);
            if (!(llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS)) llRequestPermissions(g_kOwner, PERMISSION_OVERRIDE_ANIMATIONS);
            if (!(llGetPermissions() & PERMISSION_TAKE_CONTROLS)) llRequestPermissions(g_kOwner, PERMISSION_TAKE_CONTROLS);
        }
        if (g_iEnabled && (iChange & CHANGED_ANIMATION)) {
            // Note: never call llSetAnimationOverride in the changed event
            // or you'll get a recursive lag loop=crash
            string sAnim = llGetAnimation(g_kOwner);
            if (sAnim == "Sitting on Ground") {
                // Real groundsit
                if (g_iRlvOn && g_fGroundsitHover != 0.0) {
                    llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                    g_iHoverAdjusted = TRUE;
                }
                if (g_iLastMenu != MENU_GROUNDSIT) ShowGroundsitMenu();
                llSetTimerEvent(0.0);
            } else if (sAnim == "Sitting") {
                // Regular sit, reset hover everytime we sit on something new
                g_fSitHover = 0.0;
                if (g_iRlvOn && g_iHoverAdjusted) {
                    llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                    g_iHoverAdjusted = FALSE;
                }
                if (g_iLastMenu != MENU_SIT) ShowSitMenu();
                llSetTimerEvent(0.0);
            } else if (sAnim == "Standing") {
                if (g_iTestingWalks) {
                    // Testing walks
                    llSetTimerEvent(0.0);
                    if (g_iRlvOn && g_iHoverAdjusted) {
                        llOwnerSay("@adjustheight:1;0;0=force");
                        g_iHoverAdjusted = FALSE;
                    }
                    if (g_iLastMenu != MENU_STAND) ShowStandMenu();
                } else if (g_iSitAnywhere) {
                    // Fake groundsit (actually playing the anim while standing)
                    llSetTimerEvent(0.0);
                    if (g_iRlvOn && g_fGroundsitHover != 0.0) {
                        llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                        g_iHoverAdjusted = TRUE;
                    }
                    if (g_iLastMenu != MENU_GROUNDSIT) ShowGroundsitMenu();
                } else {
                    // Regular stand
                    if (g_iRlvOn && g_iHoverAdjusted) {
                        llOwnerSay("@adjustheight:1;0;0=force");
                        g_iHoverAdjusted = FALSE;
                    }
                    if (g_iLastMenu != MENU_STAND) ShowStandMenu();
                    if (llGetListLength(g_lAnimStanding) > 1) {
                        g_iNextStandStart = llGetUnixTime() + g_iStandTime;
                        llSetTimerEvent(g_iStandTime);
                    }
                }
            } else {
                // All other anim states
                if (g_iRlvOn && g_iHoverAdjusted) {
                    llOwnerSay("@adjustheight:1;0;0=force");
                    g_iHoverAdjusted = FALSE;
                }
                //llSetText("", <1,1,1>, 1);
                if (g_iLastMenu != MENU_NONE) HideMenu();
                // don't schedule next stand while not standing
                llSetTimerEvent(0.0);
            }
        }
    }

    timer()
    {
        // Switch stands after g_iStandTime seconds
        if (llGetUnixTime() >= g_iNextStandStart &&
                llGetAnimation(g_kOwner) == "Standing" &&
                !g_iSitAnywhere && !g_iTestingWalks) {
            if (llGetListLength(g_lAnimStanding) > 1) NextStand();
            if (llGetListLength(g_lAnimWalking) > 1) PickWalk();  //because we will call this from the arrows too...
        }
        if (g_iRlvTimeout) {
            if (llGetUnixTime() >= g_iRlvTimeout) {
                g_iRlvTimeout = 0;
                g_iRlvOn = FALSE;
                llListenRemove(g_iRlvHandle);
                llOwnerSay("No RLV detected, some features will be limited");
            } else llOwnerSay("@versionnew="+(string)RLV_CHANNEL);
        }
    }
}
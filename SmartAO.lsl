
/*
   SmartAO
   2021-01-04 - lickx / Okie Meow
  
   Just drop in animations in the HUD. No notecard needed.
   Accepted animations (others will simply be ignored):
   
     Crouching
     CrouchWalking
     Falling Down
     Floating
     Flying
     FlyingSlow
     Hovering
     Hovering Down
     Hovering Up
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
     Swimming
     Swimming Down
     Swimming Up
     Taking Off
     Turning Left
     Turning Right
     Walking

   You can have one or more standing animations as long as they are
   prefixed with "Standing".

   The water resistance (=slower movement) only works with ubODE physics.
   When starting to float (press home when standing on the seafloor), give
   it 3 seconds before swimming (press forward), otherwise you'll fly out
   of the water.

 */

list g_lAnimStanding; // list of stands (animations with name starting with "Standing")

integer g_iHaveSwimAnims; // bitfield of swimming anims we have: swimming, floating, swim down, swim up
integer g_iUsingSwimAnims; // do we have swim anims activated instead of flying anims?
float g_fWaterLevel;

integer g_iHaveFlyAnims;

integer g_iStandTime = 45;      // stand time in seconds
integer g_iRandomStands = TRUE; // TRUE=random, FALSE=sequential
integer g_iNextStandStart;
integer g_iCurrentStand;

integer g_iEnabled = TRUE;
integer g_iSitAnywhere = FALSE;
integer g_iMenuOpened;

integer LOCKMEISTER_CH = -8888;
integer g_iLMHandle;
integer g_iEnableLM;
integer g_iOpenCollar_CH;

float g_fHover;
float HOVER_INCREMENT = 0.05;

integer g_iDialogHandle;
integer g_iDialogChannel;

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
    if (g_iRandomStands) {
        integer iNumStands = llGetListLength(g_lAnimStanding);
        g_iCurrentStand = (integer)llFrand(iNumStands-1);
    } else {
        integer iNumStands = llGetListLength(g_lAnimStanding);
        if (g_iCurrentStand < iNumStands-1) g_iCurrentStand++;
        else g_iCurrentStand = 0;
    }
    string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
    llSetAnimationOverride("Standing",sAnim);
    g_iNextStandStart = llGetUnixTime() + g_iStandTime;
}

PrevStand()
{
    if (g_iRandomStands) {
        NextStand();
        return;
    }
    integer iNumStands = llGetListLength(g_lAnimStanding);
    if (g_iCurrentStand > 0) g_iCurrentStand--;
    else g_iCurrentStand = iNumStands-1;
    string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
    llSetAnimationOverride("Standing",sAnim);
    g_iNextStandStart = llGetUnixTime() + g_iStandTime;
}

Enable()
{
    list VALID_ANIMS = ["Crouching", "CrouchWalking", "Falling Down", "Flying",
        "FlyingSlow", "Hovering", "Hovering Down", "Hovering Up", "Jumping",
        "Landing", "PreJumping", "Running", "Sitting", "Sitting on Ground",
        "Standing Up", "Striding", "Soft Landing", "Taking Off", "Turning Left",
        "Turning Right", "Walking"];
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE, 0, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0.5,0>, 0]);
    llResetAnimationOverride("ALL");
    g_lAnimStanding = [];
    g_iHaveFlyAnims = 0;
    g_iHaveSwimAnims = 0;
    integer i = 0;
    while (i < llGetInventoryNumber(INVENTORY_ANIMATION)) {
        string sAnim = llGetInventoryName(INVENTORY_ANIMATION, i++);
        if ((~llSubStringIndex(sAnim, "Standing")) && sAnim != "Standing Up") g_lAnimStanding += sAnim;
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
    Swim2Fly();
    NextStand();
    // Only use the timer if we have more than 1 stand:
    if (llGetListLength(g_lAnimStanding) > 1) llSetTimerEvent(g_iStandTime);
    else llSetTimerEvent(0.0);
    g_iEnabled = TRUE;
    VALID_ANIMS = []; // maybe needed for yEngine, free up list memory.
}

Disable()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE, 0, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0,0>, 0]);
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
}

ShowStandMenu()
{
    llOwnerSay("@adjustheight:1;0;0=force");
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 1, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 4, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 5, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 6, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0,0>, 0
    ]);
}

ShowGroundsitMenu()
{
    llOwnerSay("@adjustheight:1;0;"+(string)g_fHover+"=force");
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXTURE, 1, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 4, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 5, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0.5,0>, 0,
        PRIM_TEXTURE, 6, llGetInventoryName(INVENTORY_TEXTURE, 0), <1,1,0>, <0,0.5,0>, 0
    ]);
}

DeleteDialog()
{
    llSetTimerEvent(0.0);
    string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
    g_iDialogChannel = -393939;
    g_iDialogHandle = llListen(g_iDialogChannel, "", "", "");
    llDialog(llGetOwner(), "Delete stand '"+sAnim+"'?", ["Confirm", "Cancel"], g_iDialogChannel);
}

OptionDialog()
{
    g_iDialogChannel = -393939;
    g_iDialogHandle = llListen(g_iDialogChannel, "", "", "");
    list lButtons;
    if (g_iRandomStands) lButtons += "☑ Random";
    else lButtons += "☐ Random";
    if (g_iEnableLM) lButtons += "☑ Lockmeister";
    else lButtons += "☐ Lockmeister";
    lButtons += "Close";
    lButtons += ["15 sec.", "30 sec.", "45 sec."];
    llDialog(llGetOwner(), "SmartAO Options", lButtons, g_iDialogChannel);
}

RestoreSettings()
{
    list lSettings = llParseString2List(llGetObjectDesc(), [",","="], []);
    integer i;
    for (i = 0; i < llGetListLength(lSettings); i+=2)
    {
        string sSetting = llList2String(lSettings, i);
        if (sSetting == "hover") g_fHover = llList2Float(lSettings, i+1);
        else if (sSetting == "random") g_iRandomStands = llList2Integer(lSettings, i+1);
        else if (sSetting == "standtime") g_iStandTime = llList2Integer(lSettings, i+1);
    }
}

SaveSettings()
{
    string sSettings;
    sSettings += "hover="+(string)g_fHover;
    sSettings += ",random="+(string)g_iRandomStands;
    sSettings += ",standtime="+(string)g_iStandTime;
    llSetObjectDesc(sSettings);
}

default
{
    state_entry()
    {
        g_fWaterLevel = llWater(ZERO_VECTOR);
        RestoreSettings();
        if (llGetAttached()) llRequestPermissions(llGetOwner(), PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TAKE_CONTROLS);
        g_iOpenCollar_CH = -llAbs((integer)("0x" + llGetSubString(llGetOwner(),30,-1)));
        llListen(g_iOpenCollar_CH, "", "", "");
        if (g_iEnableLM) g_iLMHandle = llListen(LOCKMEISTER_CH, "", "", "");
    }
    
    attach(key kID)
    {
        if (kID == NULL_KEY) llResetAnimationOverride("ALL");
        else llResetScript();
    }
    
    touch_end(integer i)
    {
        if (llDetectedKey(0) != llGetOwner()) return;
        
        integer iButton = llDetectedTouchFace(0);
        string sAnim = llGetAnimation(llGetOwner());
        if (iButton == 0) {
            // Power
            g_iEnabled = !g_iEnabled;
            if (g_iEnabled) Enable();
            else Disable();
        } else if (iButton == 1) {
            // Groundsit
            g_iSitAnywhere = !g_iSitAnywhere;
            if (g_iSitAnywhere) {
                if (llGetInventoryType("Sitting on Ground")!=INVENTORY_ANIMATION) return;
                llSetTimerEvent(0.0);
                llSetAnimationOverride("Standing", "Sitting on Ground");
                ShowGroundsitMenu();
            } else {
                NextStand();
                llSetTimerEvent(g_iStandTime);
                ShowStandMenu();
            }
        } else if (iButton == 2) OptionDialog();
        else if (iButton == 4) {
            if (sAnim == "Standing" && !g_iSitAnywhere) PrevStand();
            else if (sAnim == "Sitting on Ground" || g_iSitAnywhere) {
                // Adjust groundsit height upwards
                g_fHover+=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fHover+"=force");
                SaveSettings();
            }
        } else if (iButton == 5) {
            if (sAnim == "Standing" && !g_iSitAnywhere) NextStand();
            else if (sAnim == "Sitting on Ground" || g_iSitAnywhere) {
                // Adjust groundsit height downwards
                g_fHover-=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fHover+"=force");
                SaveSettings();
            }
        } else if (iButton == 6) {
            if (sAnim == "Standing" && !g_iSitAnywhere) DeleteDialog();
            else if (sAnim == "Sitting on Ground" || g_iSitAnywhere) {
                // Reset groundsit height
                g_fHover=0;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fHover+"=force");
                SaveSettings();
            }
        }
    }
    
    listen(integer iChannel, string sName, key kID, string sMsg)
    {
        if (iChannel == g_iDialogChannel) {
            if (sMsg == "Confirm") {
                string sAnim = llList2String(g_lAnimStanding, g_iCurrentStand);
                llRemoveInventory(sAnim);
                llDeleteSubList(g_lAnimStanding, g_iCurrentStand, g_iCurrentStand);
                NextStand();
            } else if (sMsg == "☑ Random") {
                g_iRandomStands = TRUE;
                NextStand();
            } else if (sMsg == "☐ Random") {
                g_iRandomStands = FALSE;
                NextStand();
            } else if (sMsg == "☑ Lockmeister") {
                g_iEnableLM = TRUE;
                llListen(LOCKMEISTER_CH, "", "", "");
            } else if (sMsg == "☐ Lockmeister") {
                g_iEnableLM = FALSE;
                llListenRemove(g_iLMHandle);
            } else if (sMsg == "15 secs." || sMsg == "30 secs." || sMsg == "45 secs.") {
                g_iStandTime = (integer)llGetSubString(sMsg, 0, 1);
                NextStand();
            }
            llListenRemove(g_iDialogHandle);
            llSetTimerEvent(g_iStandTime);
        } else if (iChannel == LOCKMEISTER_CH) {
            if (llGetSubString(sMsg,0,35) == llGetOwner()) {
                sMsg = llGetSubString(sMsg,36,-1);
                if (sMsg == "booton") Enable();
                else if (sMsg == "bootoff") Disable();
            } else return;
        } else if (llGetOwnerKey(kID) != llGetOwner()) return;
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
        string sCurAnim = llGetAnimation(llGetOwner());
        vector vMove = ZERO_VECTOR;
        if ( iLevels & ~iEdges & CONTROL_FWD) vMove.x += 1.0;
        if ( iLevels & ~iEdges & CONTROL_BACK) vMove.x += -1.0;
        if ( iLevels & ~iEdges & CONTROL_UP) vMove.z += 0.8;
        if ( iLevels & ~iEdges & CONTROL_DOWN) vMove.z += -0.2;
        vMove.z += -0.3; // gravity
        if (sCurAnim=="Hovering Down") vMove.z = 0; // hack to avoid ground bouncing
        if (vMove != ZERO_VECTOR) llApplyImpulse((vMove*llGetRot()), FALSE);
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY) llResetScript();
        if (iChange & CHANGED_REGION || iChange & CHANGED_TELEPORT) {
            g_fWaterLevel = llWater(ZERO_VECTOR);
            if (!(llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS)) llRequestPermissions(llGetOwner(), PERMISSION_OVERRIDE_ANIMATIONS);
            if (!(llGetPermissions() & PERMISSION_TAKE_CONTROLS)) llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS);
        }
        if (iChange & CHANGED_ANIMATION) {
            string sAnim = llGetAnimation(llGetOwner());
            if (sAnim == "Sitting on Ground") ShowGroundsitMenu();
            else if (sAnim == "Standing") {
                if (g_iSitAnywhere) ShowGroundsitMenu();
                else ShowStandMenu();
            } else HideMenu();
        }
    }

    timer()
    {
        llSetTimerEvent(0.0);
        
        // Switch stands after g_iStandTime seconds
        if (llGetUnixTime() >= g_iNextStandStart) NextStand();

        llSetTimerEvent(g_iStandTime);
    }
}

/*
   SmartAO by lickx
   2021-05-30
  
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
     Standing
     Standing Up
     Striding
     Soft Landing
     Swimming (sometimes called Swimming Forward)
     Swimming Down
     Swimming Up
     Taking Off
     Turning Left
     Turning Right
     Walking

   The water resistance (=slower movement) only works with ubODE physics.
   When starting to float (press home when standing on the seafloor), give
   it 3 seconds before swimming (press forward), otherwise you'll fly out
   of the water. This differs from SL physics.

 */

integer g_iRlvOn = 0;
integer g_iRlvHandle;
integer RLV_CHANNEL = 5050;
integer g_iRlvTimeout = 0;

integer g_iHaveSwimAnims; // bitfield of swimming anims we have: swimming, floating, swim down, swim up
integer g_iUsingSwimAnims; // do we have swim anims activated instead of flying anims?
float g_fWaterLevel;

integer g_iHaveFlyAnims;

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

Enable()
{
    list VALID_ANIMS = ["Crouching", "CrouchWalking", "Falling Down", "Flying",
        "FlyingSlow", "Hovering", "Hovering Down", "Hovering Up", "Jumping",
        "Landing", "PreJumping", "Running", "Sitting", "Sitting on Ground", "Standing",
        "Standing Up", "Striding", "Soft Landing", "Taking Off", "Turning Left",
        "Turning Right", "Walking"];
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_TEXTURE, 0, g_sTexture, <1,1,0>, <0,0.5,0>, 0]);
    llResetAnimationOverride("ALL");
    g_iHaveFlyAnims = 0;
    g_iHaveSwimAnims = 0;
    integer i = 0;
    while (i < llGetInventoryNumber(INVENTORY_ANIMATION)) {
        string sAnim = llGetInventoryName(INVENTORY_ANIMATION, i++);
        if (sAnim == "Flying") g_iHaveFlyAnims = g_iHaveFlyAnims | 1;
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
        PRIM_TEXTURE, 1, g_sTexture, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 4, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 5, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, 6, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0
    ]);
    llSetText("", <1,1,1>, 1);
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
    if (g_fGroundsitHover != 0.0) llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
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
    if (g_fSitHover != 0.0) llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
    g_iLastMenu = MENU_SIT;
}

OptionDialog()
{
    g_iDialogChannel = -393939;
    g_iDialogHandle = llListen(g_iDialogChannel, "", llGetOwner(), "");
    list lButtons;
    if (g_iEnableLM) lButtons += "☑ Lockmeister";
    else lButtons += "☐ Lockmeister";
    lButtons += "Reload";
    lButtons += "Close";
    llDialog(llGetOwner(), "SmartAO Options", lButtons, g_iDialogChannel);
}

RestoreSettings()
{
    list lSettings = llParseString2List(llGetObjectDesc(), [",","="], []);
    integer i;
    for (i = 0; i < llGetListLength(lSettings); i+=2)
    {
        string sSetting = llList2String(lSettings, i);
        if (sSetting == "hover") g_fGroundsitHover = llList2Float(lSettings, i+1);
        else if (sSetting == "lm") g_iEnableLM = llList2Integer(lSettings, i+1);
    }
}

SaveSettings()
{
    string sSettings;
    sSettings += "hover="+Hover2String(g_fGroundsitHover);
    sSettings += ",lm="+(string)g_iEnableLM;
    llSetObjectDesc(sSettings);
}

default
{
    state_entry()
    {
        if (llGetAttached()==0) {
            Disable();
            return;
        }
        g_sTexture = llGetInventoryName(INVENTORY_TEXTURE, 0);
        llSetTexture(g_sTexture, ALL_SIDES);
        g_fWaterLevel = llWater(ZERO_VECTOR);
        RestoreSettings();
        if (llGetAttached()) llRequestPermissions(llGetOwner(), PERMISSION_OVERRIDE_ANIMATIONS | PERMISSION_TAKE_CONTROLS);
        g_iOpenCollar_CH = -llAbs((integer)("0x" + llGetSubString(llGetOwner(),30,-1)));
        llListen(g_iOpenCollar_CH, "", "", "");
        if (g_iEnableLM) g_iLMHandle = llListen(LOCKMEISTER_CH, "", "", "");
        g_iRlvHandle = llListen(RLV_CHANNEL, "", llGetOwner(), "");
        g_iRlvTimeout = llGetUnixTime() + 60;
        llOwnerSay("@versionnew="+(string)RLV_CHANNEL);
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
            g_iSitAnywhere = !g_iSitAnywhere;
            if (g_iSitAnywhere) {
                if (llGetInventoryType("Sitting on Ground")!=INVENTORY_ANIMATION) return;
                // Fake groundsit
                llSetAnimationOverride("Standing", "Sitting on Ground");
                llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                // If all viewers conformed to RLV this would be possible instead:
                //llOwnerSay("@sitground=force");
            } else llSetAnimationOverride("Standing", "Standing"); // stand up from fake groundsit
        } else if (iButton == 2) OptionDialog();
        else if (iButton == 4) {
            if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Adjust groundsit height upwards
                g_fGroundsitHover+=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Adjust regular sit height upwards
                g_fSitHover+=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
            }
        } else if (iButton == 5) {
            if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Adjust groundsit height downwards
                g_fGroundsitHover-=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Adjust regular sit height downwards
                g_fSitHover-=HOVER_INCREMENT;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                if (g_fGroundsitHover != 0.0) g_iHoverAdjusted = TRUE;
                else g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
            }
        } else if (iButton == 6) {
            if (g_iRlvOn && (sAnim == "Sitting on Ground" || g_iSitAnywhere)) {
                // Reset groundsit height
                g_fGroundsitHover=0.0;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fGroundsitHover), <1,1,1>, 1);
                SaveSettings();
            } else if (g_iRlvOn && sAnim == "Sitting") {
                // Reset regular sit height
                g_fSitHover = 0.0;
                llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                g_iHoverAdjusted = FALSE;
                llSetText(Hover2String(g_fSitHover), <1,1,1>, 1);
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
            llSetTimerEvent(0.0);
        } else if (iChannel == g_iDialogChannel) {
            if (sMsg == "Reload") llResetScript();
            else if (sMsg == "☑ Lockmeister") {
                g_iEnableLM = FALSE;
                llListenRemove(g_iLMHandle);
            } else if (sMsg == "☐ Lockmeister") {
                g_iEnableLM = TRUE;
                llListen(LOCKMEISTER_CH, "", "", "");
            }
            SaveSettings();
            llListenRemove(g_iDialogHandle);
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
        if (sCurAnim=="Walking" || sCurAnim=="Running") return;
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
        if (iChange & CHANGED_INVENTORY) Disable();
        if (iChange & CHANGED_REGION || iChange & CHANGED_TELEPORT) {
            g_fWaterLevel = llWater(ZERO_VECTOR);
            if (!(llGetPermissions() & PERMISSION_OVERRIDE_ANIMATIONS)) llRequestPermissions(llGetOwner(), PERMISSION_OVERRIDE_ANIMATIONS);
            if (!(llGetPermissions() & PERMISSION_TAKE_CONTROLS)) llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS);
        }
        if (g_iEnabled && (iChange & CHANGED_ANIMATION)) {
            string sAnim = llGetAnimation(llGetOwner());
            if (sAnim == "Sitting on Ground") {
                // Real groundsit
                if (g_iRlvOn && g_fGroundsitHover != 0.0) {
                    llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                    g_iHoverAdjusted = TRUE;
                }                
                if (g_iLastMenu != MENU_GROUNDSIT) ShowGroundsitMenu();
            } else if (sAnim == "Sitting") {
                // Regular sit, reset hover everytime we sit on something new
                g_fSitHover = 0.0;
                if (g_iRlvOn && g_iHoverAdjusted) {
                    llOwnerSay("@adjustheight:1;0;"+(string)g_fSitHover+"=force");
                    g_iHoverAdjusted = FALSE;
                }
                if (g_iLastMenu != MENU_SIT) ShowSitMenu();
            } else if (sAnim == "Standing") {
                if (g_iSitAnywhere) {
                    // Fake groundsit (actually playing the anim while standing)
                    if (g_iRlvOn && g_fGroundSitHover != 0.0) {
                        llOwnerSay("@adjustheight:1;0;"+(string)g_fGroundsitHover+"=force");
                        g_iHoverAdjusted = TRUE;
                    }
                    if (g_iLastMenu != MENU_GROUNDSIT) ShowGroundsitMenu();
                } else {
                    // Regular stand
                    if (g_iRlvOn && g_iHoverAdjusted) {
                        llOwnerSay("@adjustheight:1;0;0.0=force");
                        g_iHoverAdjusted = FALSE;
                    }
                    if (g_LastMenu != MENU_HIDE) HideMenu();
                }
            } else {
                // All other anim states
                if (g_iLastMenu != MENU_NONE) HideMenu();
        }
    }

    timer()
    {
        if (g_iRlvTimeout) {
            if (llGetUnixTime() >= g_iRlvTimeout) {
                g_iRlvTimeout = 0;
                g_iRlvOn = FALSE;
                llListenRemove(g_iRlvHandle);
                llOwnerSay("No RLV detected, some features will be limited");
            } else llOwnerSay("@versionnew="+(string)RLV_CHANNEL);
        } else llSetTimerEvent(0.0);
    }
}
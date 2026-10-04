// Halloween Morpher - one Mono LSL root script for a 16-prim linkset.
// Drop this script into link 1 of an object containing exactly sixteen prims.
// Links 13, 14, and 15 are the three simultaneous aura emitters.

integer REQUIRED_PRIMS = 16;
integer CHANNEL;
integer listenHandle;
key menuUser;
integer page;
integer inputMode;

integer shape;                 // 0 pumpkin, 1 skull, 2 guardian, 3 hat
integer expression;            // 0 sleeping, 1 watching, 2 awakening, 3 angry, 4 automatic
integer triggerMode;           // 0 touch, 1 proximity, 2 both
integer speedLevel = 1;
integer auraLevel = 2;
integer colorChoice;
float objectGlow;
float objectAlpha = 1.0;
integer useNamedAssets = TRUE;
integer soundOn = TRUE;
float soundVolume = 0.7;
string customTexture;

vector homePos;
rotation homeRot;
key homeParcel;
float lastTrigger = -9999.0;
float nextAuto;
integer morphing;
float morphStart;
float morphDuration = 2.4;
integer validLinkset;
integer nearestSeen;
vector lookLocal;

list curPos;
list curRot;
list curScale;
list fromPos;
list fromRot;
list fromScale;
list toPos;
list toRot;
list toScale;

list PALETTE = [<1.00,0.28,0.02>, <0.16,0.72,1.00>, <0.32,1.00,0.12>,
                <0.62,0.12,0.90>, <0.92,0.92,0.86>, <0.06,0.06,0.07>];
list COLOR_NAMES = ["Pumpkin", "Ghost Blue", "Toxic", "Witch Purple", "Bone", "Midnight"];

float speedFactor()
{
    if (speedLevel == 0) return 0.65;
    if (speedLevel == 2) return 1.55;
    return 1.0;
}

float ease(float x)
{
    if (x < 0.0) x = 0.0;
    if (x > 1.0) x = 1.0;
    return x * x * (3.0 - 2.0 * x);
}

vector mixV(vector a, vector b, float t) { return a + (b - a) * t; }

float clampFloat(float value, float low, float high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

string shapeName()
{
    if (shape == 0) return "Pumpkin Creature";
    if (shape == 1) return "Floating Skull";
    if (shape == 2) return "Horned Guardian";
    return "Witch Hat";
}

string expressionName()
{
    if (expression == 0) return "Sleeping";
    if (expression == 1) return "Watching";
    if (expression == 2) return "Awakening";
    if (expression == 3) return "Angry";
    return "Automatic Transformation";
}

string findAsset(integer kind, string wanted)
{
    integer n = llGetInventoryNumber(kind);
    string needle = llToLower(wanted);
    integer i;
    for (i = 0; i < n; ++i)
    {
        string name = llGetInventoryName(kind, i);
        if (llSubStringIndex(llToLower(name), needle) != -1) return name;
    }
    return "";
}

string bodyTexture()
{
    if (customTexture != "") return customTexture;
    if (useNamedAssets)
    {
        string found = findAsset(INVENTORY_TEXTURE, llList2String(["pumpkin", "skull", "guardian", "hat"], shape));
        if (found == "") found = findAsset(INVENTORY_TEXTURE, "body");
        if (found != "") return found;
    }
    return TEXTURE_BLANK;
}

playNamed(string cue)
{
    if (!soundOn) return;
    string found = findAsset(INVENTORY_SOUND, cue);
    if (found == "") found = findAsset(INVENTORY_SOUND, "morph");
    if (found != "") llTriggerSound(found, soundVolume);
}

saveSettings()
{
    llLinksetDataWrite("HM.settings", llList2CSV([shape, expression, triggerMode, speedLevel,
        auraLevel, colorChoice, objectGlow, objectAlpha, useNamedAssets, soundOn, soundVolume]));
    llLinksetDataWrite("HM.texture", customTexture);
    llLinksetDataWrite("HM.homepos", (string)homePos);
    llLinksetDataWrite("HM.homerot", (string)homeRot);
}

loadSettings()
{
    string data = llLinksetDataRead("HM.settings");
    if (data != "")
    {
        list v = llCSV2List(data);
        if (llGetListLength(v) >= 11)
        {
            shape = (integer)llList2String(v,0);
            expression = (integer)llList2String(v,1);
            triggerMode = (integer)llList2String(v,2);
            speedLevel = (integer)llList2String(v,3);
            auraLevel = (integer)llList2String(v,4);
            colorChoice = (integer)llList2String(v,5);
            objectGlow = (float)llList2String(v,6);
            objectAlpha = (float)llList2String(v,7);
            useNamedAssets = (integer)llList2String(v,8);
            soundOn = (integer)llList2String(v,9);
            soundVolume = (float)llList2String(v,10);
        }
    }
    customTexture = llLinksetDataRead("HM.texture");
    string hp = llLinksetDataRead("HM.homepos");
    string hr = llLinksetDataRead("HM.homerot");
    if (hp != "" && hr != "")
    {
        homePos = (vector)hp;
        homeRot = (rotation)hr;
    }
    else
    {
        homePos = llGetPos();
        homeRot = llGetRot();
        saveSettings();
    }
    homeParcel = llList2Key(llGetParcelDetails(homePos, [PARCEL_DETAILS_ID]), 0);
}

list poses(integer which)
{
    // Sixteen local positions. Link 1 is the unmoving root; each arrangement
    // deliberately reuses every physical prim to produce a complete silhouette.
    if (which == 0) return [
        ZERO_VECTOR, <-.38,0,.08>, <.38,0,.08>, <0,-.30,.10>, <0,.30,.10>,
        <-.20,-.39,.10>, <.20,-.39,.10>, <0,-.49,-.12>, <0,0,.68>,
        <-.46,0,-.48>, <.46,0,-.48>, <-.52,0,-.93>, <0,.30,.72>, <0,0,.88>, <0,-.25,.73>, <0,.12,-.36>];
    if (which == 1) return [
        ZERO_VECTOR, <-.31,0,.09>, <.31,0,.09>, <0,0,.32>, <-.20,-.35,.14>,
        <.20,-.35,.14>, <0,-.39,-.08>, <0,-.35,-.33>, <-.18,-.34,-.39>,
        <.18,-.34,-.39>, <-.37,0,-.03>, <.37,0,-.03>, <-.11,-.38,-.08>, <.11,-.38,-.08>, <0,.16,.40>, <0,0,-.64>];
    if (which == 2) return [
        ZERO_VECTOR, <-.34,0,.02>, <.34,0,.02>, <0,-.36,.07>, <-.19,-.39,.11>,
        <.19,-.39,.11>, <0,-.43,-.17>, <-.49,0,.43>, <.49,0,.43>,
        <-.72,0,.69>, <.72,0,.69>, <-.42,0,-.42>, <0,.28,.48>, <0,0,.64>, <0,-.22,.55>, <.42,0,-.42>];
    return [
        ZERO_VECTOR, <-.42,0,-.35>, <.42,0,-.35>, <0,-.40,-.34>, <0,.34,-.34>,
        <-.63,0,-.36>, <.63,0,-.36>, <0,0,.04>, <0,0,.45>,
        <.13,0,.83>, <.25,0,1.16>, <.42,0,1.38>, <-.25,-.15,.70>, <.26,.10,1.04>, <0,-.30,-.34>, <0,0,-.70>];
}

list scales(integer which)
{
    if (which == 0) return [
        <.72,.72,.82>, <.62,.68,.75>, <.62,.68,.75>, <.72,.62,.72>, <.72,.62,.72>,
        <.12,.08,.24>, <.12,.08,.24>, <.34,.08,.12>, <.18,.18,.48>,
        <.18,.22,.52>, <.18,.22,.52>, <.22,.26,.62>, <.08,.08,.08>, <.08,.08,.08>, <.08,.08,.08>, <.42,.42,.26>];
    if (which == 1) return [
        <.72,.58,.72>, <.48,.50,.64>, <.48,.50,.64>, <.54,.48,.55>, <.18,.09,.18>,
        <.18,.09,.18>, <.30,.14,.20>, <.52,.42,.23>, <.08,.08,.14>,
        <.08,.08,.14>, <.22,.20,.35>, <.22,.20,.35>, <.08,.07,.13>, <.08,.07,.13>, <.34,.28,.28>, <.22,.22,.52>];
    if (which == 2) return [
        <.74,.58,.72>, <.52,.52,.62>, <.52,.52,.62>, <.60,.45,.54>, <.15,.08,.20>,
        <.15,.08,.20>, <.34,.15,.20>, <.18,.18,.52>, <.18,.18,.52>,
        <.14,.14,.58>, <.14,.14,.58>, <.28,.30,.48>, <.10,.10,.10>, <.10,.10,.10>, <.10,.10,.10>, <.28,.30,.48>];
    return [
        <.82,.72,.16>, <.72,.60,.14>, <.72,.60,.14>, <.74,.48,.12>, <.74,.48,.12>,
        <.54,.38,.10>, <.54,.38,.10>, <.65,.58,.45>, <.54,.48,.48>,
        <.43,.39,.47>, <.34,.31,.42>, <.22,.22,.32>, <.13,.08,.28>, <.12,.08,.30>, <.16,.08,.11>, <.25,.25,.40>];
}

list rotations(integer which)
{
    rotation z = ZERO_ROTATION;
    if (which == 0) return [z,z,z,z,z,z,z,z,z,z,z,z,z,z,z,z];
    if (which == 1) return [z,z,z,z,z,z,z,z,llEuler2Rot(<0,0,.25>),llEuler2Rot(<0,0,-.25>),z,z,z,z,z,z];
    if (which == 2) return [z,z,z,z,z,z,z,llEuler2Rot(<0,.55,-.45>),llEuler2Rot(<0,-.55,.45>),llEuler2Rot(<0,.80,-.58>),llEuler2Rot(<0,-.80,.58>),z,z,z,z,z];
    return [z,z,z,z,z,z,z,llEuler2Rot(<0,0,.10>),llEuler2Rot(<0,0,.15>),llEuler2Rot(<0,0,.20>),llEuler2Rot(<0,0,.30>),llEuler2Rot(<0,0,.48>),z,z,z,z];
}

integer primKind(integer which, integer link)
{
    if (which == 0 && (link == 6 || link == 7 || link == 8)) return PRIM_TYPE_BOX;
    if (which == 1 && link >= 8 && link <= 14) return PRIM_TYPE_BOX;
    if (which == 2 && link >= 8 && link <= 11) return PRIM_TYPE_CYLINDER;
    if (which == 3 && link >= 8 && link <= 14) return PRIM_TYPE_CYLINDER;
    return PRIM_TYPE_SPHERE;
}

setPrimType(integer link, integer kind)
{
    if (kind == PRIM_TYPE_SPHERE)
        llSetLinkPrimitiveParamsFast(link,[PRIM_TYPE,PRIM_TYPE_SPHERE,PRIM_HOLE_DEFAULT,<0,1,0>,0.0,<0,0,0>,<1,1,0>]);
    else
        llSetLinkPrimitiveParamsFast(link,[PRIM_TYPE,kind,PRIM_HOLE_DEFAULT,<0,1,0>,0.0,<0,0,0>,<1,1,0>,<0,0,0>]);
}

vector partColor(integer link)
{
    vector main = llList2Vector(PALETTE, colorChoice);
    if (shape == 0)
    {
        if (link >= 6 && link <= 8) return <.08,.02,.01>;
        if (link == 9) return <.18,.42,.05>;
    }
    if (shape == 1)
    {
        if (link == 5 || link == 6 || link >= 13 && link <= 14) return <.03,.07,.08>;
        if (colorChoice == 0) return <.86,.84,.70>;
    }
    if (shape == 2)
    {
        if (link >= 8 && link <= 11) return <.18,.08,.04>;
        if (link >= 13 && link <= 15) return <.12,1.0,.16>;
    }
    if (shape == 3)
    {
        if (link == 15) return <1.0,.32,.02>;
        if (colorChoice == 0) return <.22,.03,.30>;
    }
    return main;
}

applyAppearance()
{
    string tex = bodyTexture();
    integer i;
    for (i = 1; i <= REQUIRED_PRIMS; ++i)
    {
        setPrimType(i, primKind(shape,i));
        llSetLinkPrimitiveParamsFast(i,[PRIM_COLOR,ALL_SIDES,partColor(i),objectAlpha,
            PRIM_GLOW,ALL_SIDES,objectGlow,PRIM_TEXTURE,ALL_SIDES,tex,<1,1,0>,ZERO_VECTOR,0.0]);
    }
}

setParticles()
{
    integer count = auraLevel;
    if (count == 0)
    {
        llLinkParticleSystem(13,[]); llLinkParticleSystem(14,[]); llLinkParticleSystem(15,[]);
        return;
    }
    string ember = findAsset(INVENTORY_TEXTURE,"ember");
    string ghost = findAsset(INVENTORY_TEXTURE,"ghost");
    string smoke = findAsset(INVENTORY_TEXTURE,"smoke");
    list common = [PSYS_PART_FLAGS,PSYS_PART_INTERP_COLOR_MASK|PSYS_PART_INTERP_SCALE_MASK|PSYS_PART_EMISSIVE_MASK,
        PSYS_SRC_PATTERN,PSYS_SRC_PATTERN_ANGLE_CONE,PSYS_SRC_BURST_RATE,0.28,
        PSYS_SRC_BURST_PART_COUNT,count,PSYS_PART_MAX_AGE,2.0,PSYS_SRC_MAX_AGE,0.0,
        PSYS_SRC_ANGLE_BEGIN,0.05,PSYS_SRC_ANGLE_END,0.65,PSYS_SRC_BURST_RADIUS,0.05];
    list a = common + [PSYS_PART_START_COLOR,<1,.20,.01>,PSYS_PART_END_COLOR,<1,.65,.04>,
        PSYS_PART_START_ALPHA,.75,PSYS_PART_END_ALPHA,0.0,PSYS_PART_START_SCALE,<.05,.05,0>,PSYS_PART_END_SCALE,<.015,.015,0>,
        PSYS_SRC_BURST_SPEED_MIN,.25,PSYS_SRC_BURST_SPEED_MAX,.65,PSYS_SRC_ACCEL,<0,0,.35>];
    list b = common + [PSYS_PART_START_COLOR,<.15,.75,1>,PSYS_PART_END_COLOR,<.55,1,1>,
        PSYS_PART_START_ALPHA,.55,PSYS_PART_END_ALPHA,0.0,PSYS_PART_START_SCALE,<.04,.04,0>,PSYS_PART_END_SCALE,<.11,.11,0>,
        PSYS_SRC_BURST_SPEED_MIN,.15,PSYS_SRC_BURST_SPEED_MAX,.40,PSYS_SRC_ACCEL,<0,0,.12>];
    list c = common + [PSYS_PART_START_COLOR,<.25,1,.05>,PSYS_PART_END_COLOR,<.05,.20,.01>,
        PSYS_PART_START_ALPHA,.38,PSYS_PART_END_ALPHA,0.0,PSYS_PART_START_SCALE,<.10,.10,0>,PSYS_PART_END_SCALE,<.34,.34,0>,
        PSYS_SRC_BURST_SPEED_MIN,.03,PSYS_SRC_BURST_SPEED_MAX,.18,PSYS_SRC_ACCEL,<0,0,.08>];
    if (ember != "") a += [PSYS_SRC_TEXTURE,ember];
    if (ghost != "") b += [PSYS_SRC_TEXTURE,ghost];
    if (smoke != "") c += [PSYS_SRC_TEXTURE,smoke];
    llLinkParticleSystem(13,a); llLinkParticleSystem(14,b); llLinkParticleSystem(15,c);
}

startMorph(integer next)
{
    if (!validLinkset) return;
    shape = next;
    fromPos = curPos; fromRot = curRot; fromScale = curScale;
    toPos = poses(shape); toRot = rotations(shape); toScale = scales(shape);
    morphStart = llGetTime();
    morphDuration = 2.4 / speedFactor();
    morphing = TRUE;
    applyAppearance();
    setParticles();
    playNamed("morph");
    saveSettings();
}

configureSensor()
{
    llSensorRemove();
    if (triggerMode != 0) llSensorRepeat("",NULL_KEY,AGENT,9.5,PI,2.0);
}

showMenu(integer which)
{
    page = which;
    string prompt;
    list buttons;
    if (which == 0)
    {
        prompt = "HALLOWEEN MORPHER\n" + shapeName() + " / " + expressionName() +
            "\nTouch menus are private. No public chat commands.";
        buttons = ["Shape","Expression","Trigger","Speed","Aura","Colors","Glow","Opacity","Texture","Sound","Home","Stop"];
    }
    else if (which == 1) { prompt="Choose silhouette"; buttons=["Pumpkin","Skull","Guardian","Witch Hat","◀ Back"]; }
    else if (which == 2) { prompt="Choose expression / mode"; buttons=["Sleeping","Watching","Awakening","Angry","Automatic","◀ Back"]; }
    else if (which == 3) { prompt="Trigger mode (proximity is same-parcel, 9.5m, cooldown protected)"; buttons=["Touch Only","Proximity","Both","◀ Back"]; }
    else if (which == 4) { prompt="Animation speed"; buttons=["Slow","Normal","Fast","◀ Back"]; }
    else if (which == 5) { prompt="Shared particle budget across three child emitters"; buttons=["Aura Off","Aura Low","Aura Med","Aura High","◀ Back"]; }
    else if (which == 6) { prompt="Named colors"; buttons=COLOR_NAMES+["◀ Back"]; }
    else if (which == 7) { prompt="Glow: " + (string)objectGlow; buttons=["Glow 0","Glow .05","Glow .12","Glow .25","◀ Back"]; }
    else if (which == 8) { prompt="Opacity: " + (string)objectAlpha; buttons=["100%","80%","55%","25%","◀ Back"]; }
    else if (which == 9) { prompt="Texture / UUID. Auto searches inventory for shape/body named textures."; buttons=["Blank","Auto Assets","Enter UUID","◀ Back"]; }
    else if (which == 10) { prompt="Sound: " + (string)soundOn + " volume " + (string)soundVolume; buttons=["Sound On","Sound Off","Volume +","Volume -","Test","◀ Back"]; }
    else { prompt="Home is persistent. Motion is always clamped to 10m."; buttons=["Set Home","Go Home","◀ Back"]; }
    llDialog(menuUser,prompt,buttons,CHANNEL);
}

setExpression(integer value)
{
    expression = value;
    nextAuto = llGetTime() + 7.0 / speedFactor();
    if (value == 3) playNamed("angry");
    else playNamed("awaken");
    saveSettings();
}

returnHome()
{
    llSetRegionPos(homePos);
    llSetRot(homeRot);
}

default
{
    state_entry()
    {
        validLinkset = (llGetNumberOfPrims() == REQUIRED_PRIMS);
        CHANNEL = -100000 - (integer)("0x" + llGetSubString((string)llGetKey(),0,6));
        listenHandle = llListen(CHANNEL,"",NULL_KEY,"");
        loadSettings();
        curPos = poses(shape); curRot = rotations(shape); curScale = scales(shape);
        fromPos = curPos; fromRot = curRot; fromScale = curScale;
        toPos = curPos; toRot = curRot; toScale = curScale;
        if (!validLinkset)
        {
            llOwnerSay("This object must contain exactly 16 linked prims; found " + (string)llGetNumberOfPrims() + ". Animation is disabled.");
        }
        else
        {
            applyAppearance(); setParticles(); startMorph(shape);
        }
        configureSensor();
        nextAuto = llGetTime() + 7.0;
        llSetTimerEvent(0.05);
    }

    on_rez(integer p) { llResetScript(); }
    changed(integer c)
    {
        if (c & (CHANGED_LINK|CHANGED_INVENTORY|CHANGED_OWNER)) llResetScript();
    }

    touch_start(integer total)
    {
        key who = llDetectedKey(0);
        if (llGetTime() - lastTrigger < 1.0) return;
        lastTrigger = llGetTime();
        menuUser = who;
        showMenu(0);
        if (triggerMode == 0 || triggerMode == 2)
        {
            if (expression == 0) setExpression(1);
        }
    }

    listen(integer chan, string name, key id, string msg)
    {
        if (chan != CHANNEL || id != menuUser) return;
        if (inputMode)
        {
            inputMode = FALSE;
            key test = (key)msg;
            if (test != NULL_KEY) { customTexture = msg; useNamedAssets = FALSE; applyAppearance(); saveSettings(); }
            showMenu(9); return;
        }
        if (msg == "◀ Back") { showMenu(0); return; }
        if (msg == "Shape") showMenu(1);
        else if (msg == "Expression") showMenu(2);
        else if (msg == "Trigger") showMenu(3);
        else if (msg == "Speed") showMenu(4);
        else if (msg == "Aura") showMenu(5);
        else if (msg == "Colors") showMenu(6);
        else if (msg == "Glow") showMenu(7);
        else if (msg == "Opacity") showMenu(8);
        else if (msg == "Texture") showMenu(9);
        else if (msg == "Sound") showMenu(10);
        else if (msg == "Home") showMenu(11);
        else if (msg == "Stop") { setExpression(0); returnHome(); showMenu(0); }
        else if (msg == "Pumpkin") { startMorph(0); showMenu(1); }
        else if (msg == "Skull") { startMorph(1); showMenu(1); }
        else if (msg == "Guardian") { startMorph(2); showMenu(1); }
        else if (msg == "Witch Hat") { startMorph(3); showMenu(1); }
        else if (msg == "Sleeping") { setExpression(0); showMenu(2); }
        else if (msg == "Watching") { setExpression(1); showMenu(2); }
        else if (msg == "Awakening") { setExpression(2); showMenu(2); }
        else if (msg == "Angry") { setExpression(3); showMenu(2); }
        else if (msg == "Automatic") { setExpression(4); showMenu(2); }
        else if (msg == "Touch Only") { triggerMode=0; configureSensor(); saveSettings(); showMenu(3); }
        else if (msg == "Proximity") { triggerMode=1; configureSensor(); saveSettings(); showMenu(3); }
        else if (msg == "Both") { triggerMode=2; configureSensor(); saveSettings(); showMenu(3); }
        else if (msg == "Slow") { speedLevel=0; saveSettings(); showMenu(4); }
        else if (msg == "Normal") { speedLevel=1; saveSettings(); showMenu(4); }
        else if (msg == "Fast") { speedLevel=2; saveSettings(); showMenu(4); }
        else if (msg == "Aura Off") { auraLevel=0; setParticles(); saveSettings(); showMenu(5); }
        else if (msg == "Aura Low") { auraLevel=1; setParticles(); saveSettings(); showMenu(5); }
        else if (msg == "Aura Med") { auraLevel=2; setParticles(); saveSettings(); showMenu(5); }
        else if (msg == "Aura High") { auraLevel=3; setParticles(); saveSettings(); showMenu(5); }
        else if (llListFindList(COLOR_NAMES,[msg]) != -1) { colorChoice=llListFindList(COLOR_NAMES,[msg]); applyAppearance(); saveSettings(); showMenu(6); }
        else if (llGetSubString(msg,0,4) == "Glow ") { objectGlow=(float)llGetSubString(msg,5,-1); applyAppearance(); saveSettings(); showMenu(7); }
        else if (msg == "100%" || msg == "80%" || msg == "55%" || msg == "25%") { objectAlpha=(float)msg/100.0; applyAppearance(); saveSettings(); showMenu(8); }
        else if (msg == "Blank") { customTexture=""; useNamedAssets=FALSE; applyAppearance(); saveSettings(); showMenu(9); }
        else if (msg == "Auto Assets") { customTexture=""; useNamedAssets=TRUE; applyAppearance(); setParticles(); saveSettings(); showMenu(9); }
        else if (msg == "Enter UUID") { inputMode=TRUE; llTextBox(id,"Paste a texture UUID (private menu channel):",CHANNEL); }
        else if (msg == "Sound On") { soundOn=TRUE; saveSettings(); showMenu(10); }
        else if (msg == "Sound Off") { soundOn=FALSE; saveSettings(); showMenu(10); }
        else if (msg == "Volume +") { soundVolume+=.1; if(soundVolume>1.0)soundVolume=1.0; saveSettings(); showMenu(10); }
        else if (msg == "Volume -") { soundVolume-=.1; if(soundVolume<0.0)soundVolume=0.0; saveSettings(); showMenu(10); }
        else if (msg == "Test") { playNamed("morph"); showMenu(10); }
        else if (msg == "Set Home") { homePos=llGetPos(); homeRot=llGetRot(); homeParcel=llList2Key(llGetParcelDetails(homePos,[PARCEL_DETAILS_ID]),0); saveSettings(); showMenu(11); }
        else if (msg == "Go Home") { returnHome(); showMenu(11); }
    }

    sensor(integer n)
    {
        nearestSeen = TRUE;
        vector avatar = llDetectedPos(0);
        lookLocal = (avatar - llGetPos()) / llGetRot();
        key parcel = llList2Key(llGetParcelDetails(avatar,[PARCEL_DETAILS_ID]),0);
        if (parcel == homeParcel && llGetTime() - lastTrigger > 12.0)
        {
            lastTrigger = llGetTime();
            if (expression == 0) setExpression(1);
            else if (expression == 1) setExpression(2);
        }
    }
    no_sensor() { nearestSeen = FALSE; }

    timer()
    {
        if (!validLinkset) return;
        float now = llGetTime();
        if (llVecDist(llGetPos(),homePos) > 10.0) returnHome();
        if (expression == 4 && now >= nextAuto)
        {
            startMorph((shape + 1) % 4);
            nextAuto = now + 7.0 / speedFactor();
        }
        float t = 1.0;
        if (morphing)
        {
            t = (now - morphStart) / morphDuration;
            if (t >= 1.0) { t=1.0; morphing=FALSE; }
            t = ease(t);
        }
        float phase = now * 2.2 * speedFactor();
        integer i;
        list newP=[]; list newR=[]; list newS=[];
        for (i=0; i<REQUIRED_PRIMS; ++i)
        {
            vector p=mixV(llList2Vector(fromPos,i),llList2Vector(toPos,i),t);
            vector s=mixV(llList2Vector(fromScale,i),llList2Vector(toScale,i),t);
            rotation r=llAxisAngle2Rot(<0,0,1>,0.0);
            rotation ra=llList2Rot(fromRot,i); rotation rb=llList2Rot(toRot,i);
            r=llSlerp(ra,rb,t);
            float pulse=llSin(phase);
            if (!morphing)
            {
                if (shape==0) // squash/stretch body and animate facial pieces
                {
                    if (i<=4) s += <.025,.025,-.035>*pulse;
                    if (i>=5 && i<=7) p.z += .025*pulse;
                }
                else if (shape==1 && i>=7 && i<=9) p.z -= .08*(.5+.5*pulse); // jaw
                else if (shape==2 && i>=7 && i<=10) s.z += .06*(.5+.5*pulse); // horns
                else if (shape==3 && i>=7 && i<=13) r *= llEuler2Rot(<0,.05*llSin(phase*.7),.07*pulse>); // hat wobble
                if ((expression==2 || expression==3) && i>=12 && i<=14) p.z += .035*pulse;
                if (expression==3) r *= llEuler2Rot(<0,0,.035*pulse>);
                if (expression==1 && nearestSeen && i>=4 && i<=5)
                {
                    p.x += clampFloat(lookLocal.x,-2.0,2.0)*.015;
                    p.z += clampFloat(lookLocal.z,-2.0,2.0)*.015;
                }
            }
            newP += [p]; newR += [r]; newS += [s];
            list rules=[PRIM_SIZE,s,PRIM_ROT_LOCAL,r];
            if (i>0) rules += [PRIM_POS_LOCAL,p];
            llSetLinkPrimitiveParamsFast(i+1,rules);
        }
        curPos=newP; curRot=newR; curScale=newS;
    }
}

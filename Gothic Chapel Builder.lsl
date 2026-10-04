// Gothic Chapel Builder
// One root-prim Mono script for a pre-linked, exactly 89 prim chapel.
// Link order: 1 foundation, 2-13 floors, 14-33 walls, 34-49 roofs,
// 50-61 frames, 62-69 buttresses, 70-77 furniture, 78-83 steps,
// 84-89 finials.

integer EXPECTED_PRIMS = 89;
integer CH_DIALOG;
integer CH_TEXT;
integer listenDialog;
integer listenText;
string menuPage = "MAIN";

float chapelWidth = 18.0;
float chapelLength = 30.0;
float wallHeight = 9.0;
float roofPitch = 42.0;
integer showWindows = TRUE;
integer showFurniture = TRUE;
integer ruinAmount = 0;          // 0..3; deterministic, never physical
float animDuration = 8.0;
float groupDelay = 0.35;
integer animStyle = 0;           // 0 Direct Morph, 1 Rise, 2 Fold
integer fxEnabled = TRUE;
integer colorScheme = 0;
string presetName = "Moonlit Chapel";

// Section texture mapping: 0 structure, 1 roof, 2 glass, 3 furniture.
list sectionTextures = [TEXTURE_BLANK, TEXTURE_BLANK, TEXTURE_BLANK, TEXTURE_BLANK];
integer textureSection = 2;
integer textureCursor = -1;

list targetPos;
list targetSize;
list targetRot;
list targetColor;
list targetAlpha;
list targetSection;

integer moving;
float moveStart;
integer moveDirection = 1;
integer lastStage = -1;

float clampf(float value, float low, float high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

integer sectionForLink(integer link)
{
    if (link <= 33 || (link >= 62 && link <= 69) || (link >= 78 && link <= 89)) return 0;
    if (link <= 49) return 1;
    if (link <= 61) return 2;
    return 3;
}

vector schemeColor(integer section)
{
    if (colorScheme == 1) // mossy ruin
    {
        if (section == 1) return <0.18,0.20,0.17>;
        if (section == 2) return <0.35,0.46,0.34>;
        return <0.39,0.40,0.35>;
    }
    if (colorScheme == 2) // vampire
    {
        if (section == 1) return <0.10,0.04,0.05>;
        if (section == 2) return <0.55,0.04,0.08>;
        if (section == 3) return <0.22,0.04,0.04>;
        return <0.24,0.22,0.24>;
    }
    if (colorScheme == 3) // winter
    {
        if (section == 1) return <0.70,0.76,0.82>;
        if (section == 2) return <0.62,0.78,0.92>;
        return <0.76,0.79,0.82>;
    }
    if (section == 1) return <0.12,0.15,0.22>;
    if (section == 2) return <0.28,0.38,0.65>;
    if (section == 3) return <0.24,0.16,0.12>;
    return <0.37,0.39,0.44>;
}

integer geometryValid()
{
    if (llGetNumberOfPrims() != EXPECTED_PRIMS) return FALSE;
    if (chapelWidth < 10.0 || chapelWidth > 40.0) return FALSE;
    if (chapelLength < 16.0 || chapelLength > 60.0) return FALSE;
    if (wallHeight < 5.0 || wallHeight > 20.0) return FALSE;
    if (roofPitch < 20.0 || roofPitch > 65.0) return FALSE;
    // Keep every requested child dimension inside normal prim limits.
    if (chapelWidth / 3.0 > 10.0 || chapelLength / 6.0 > 10.0) return FALSE;
    return TRUE;
}

addPart(vector pos, vector size, rotation rot, integer section, integer visible)
{
    // Controlled ruin offsets are local, repeatable, and never use physics.
    integer link = llGetListLength(targetPos) + 1;
    if (ruinAmount > 0 && link != 1 && section != 2)
    {
        integer seed = link * 37 + ruinAmount * 11;
        float amount = (float)ruinAmount;
        pos += <((seed % 5) - 2) * 0.035 * amount,
                (((seed / 5) % 5) - 2) * 0.035 * amount,
                -((seed / 25) % 3) * 0.035 * amount>;
        rot *= llEuler2Rot(<0.0,0.0,((seed % 7) - 3) * 0.006 * amount>);
        // Only selected nonessential pieces disappear; entrance/foundation remain.
        if (ruinAmount >= 2 && (link % (8 - ruinAmount)) == 0) visible = FALSE;
    }
    targetPos += [pos];
    targetSize += [size];
    targetRot += [rot];
    targetSection += [section];
    targetColor += [schemeColor(section)];
    targetAlpha += [(float)visible];
}

buildGeometry()
{
    targetPos = []; targetSize = []; targetRot = []; targetSection = [];
    targetColor = []; targetAlpha = [];
    float W = chapelWidth;
    float L = chapelLength;
    float H = wallHeight;
    float bay = L / 6.0;
    float panel = W / 3.0;
    float rise = (W * 0.5) * llTan(roofPitch * DEG_TO_RAD);
    rise = clampf(rise, 2.0, 9.5);
    float slope = llSqrt((W * 0.5) * (W * 0.5) + rise * rise);
    slope = clampf(slope, 2.0, 10.0);
    float roofAngle = llAtan2(rise, W * 0.5);

    addPart(ZERO_VECTOR, <W,L,0.5>, ZERO_ROTATION, 0, TRUE); // root remains at its world transform

    integer i;
    // 12 floor slabs: paired thirds leave a clearly contrasting central aisle.
    for (i = 0; i < 6; ++i)
    {
        float y = -L * 0.5 + bay * (i + 0.5);
        addPart(<-W/6.0,y,0.35>, <panel,bay - 0.08,0.20>, ZERO_ROTATION, 0, TRUE);
        addPart(< W/6.0,y,0.35>, <panel,bay - 0.08,0.20>, ZERO_ROTATION, 0, TRUE);
    }

    // 20 walls: 12 side bays, 3 back panels, and 5 front pieces around an open entrance.
    for (i = 0; i < 6; ++i)
    {
        float sy = -L * 0.5 + bay * (i + 0.5);
        addPart(<-W/2.0,sy,H/2.0 + 0.5>, <0.45,bay - 0.12,H>, ZERO_ROTATION, 0, TRUE);
        addPart(< W/2.0,sy,H/2.0 + 0.5>, <0.45,bay - 0.12,H>, ZERO_ROTATION, 0, TRUE);
    }
    for (i = -1; i <= 1; ++i)
        addPart(<i * panel, L/2.0,H/2.0 + 0.5>, <panel - 0.1,0.45,H>, ZERO_ROTATION, 0, TRUE);
    float doorW = W * 0.22;
    float sideW = (W - doorW) * 0.5;
    addPart(<-(doorW + sideW)/2.0,-L/2.0,H/2.0 + 0.5>, <sideW,0.45,H>, ZERO_ROTATION, 0, TRUE);
    addPart(< (doorW + sideW)/2.0,-L/2.0,H/2.0 + 0.5>, <sideW,0.45,H>, ZERO_ROTATION, 0, TRUE);
    addPart(<0.0,-L/2.0,H - 0.25>, <doorW,0.45,1.5>, ZERO_ROTATION, 0, TRUE);
    addPart(<-doorW/2.0,-L/2.0,4.0>, <0.45,0.55,7.0>, ZERO_ROTATION, 0, TRUE);
    addPart(< doorW/2.0,-L/2.0,4.0>, <0.45,0.55,7.0>, ZERO_ROTATION, 0, TRUE);

    // 16 roof pieces: twelve slopes plus four ridge/cap elements.
    rotation leftSlope = llEuler2Rot(<0.0,roofAngle,0.0>);
    rotation rightSlope = llEuler2Rot(<0.0,-roofAngle,0.0>);
    for (i = 0; i < 6; ++i)
    {
        float ry = -L * 0.5 + bay * (i + 0.5);
        addPart(<-W/4.0,ry,H + 0.5 + rise/2.0>, <slope,bay + 0.12,0.35>, leftSlope, 1, TRUE);
        addPart(< W/4.0,ry,H + 0.5 + rise/2.0>, <slope,bay + 0.12,0.35>, rightSlope, 1, TRUE);
    }
    for (i = 0; i < 4; ++i)
        addPart(<0.0,-L/2.0 + L*(i + 0.5)/4.0,H + rise + 0.55>, <0.5,L/4.0,0.55>, ZERO_ROTATION, 1, TRUE);

    // 12 stained-glass/door frames, centered in side bays.
    for (i = 0; i < 6; ++i)
    {
        float fy = -L * 0.5 + bay * (i + 0.5);
        integer visible = showWindows;
        addPart(<-W/2.0 - 0.24,fy,H*0.58>, <0.12,bay*0.48,H*0.48>, llEuler2Rot(<0.0,PI_BY_TWO,0.0>), 2, visible);
        addPart(< W/2.0 + 0.24,fy,H*0.58>, <0.12,bay*0.48,H*0.48>, llEuler2Rot(<0.0,PI_BY_TWO,0.0>), 2, visible);
    }

    // 8 exterior buttresses.
    for (i = 0; i < 4; ++i)
    {
        float by = -L*0.5 + L*(i + 0.5)/4.0;
        addPart(<-W/2.0 - 0.8,by,H*0.38>, <1.4,1.1,H*0.76>, ZERO_ROTATION, 0, TRUE);
        addPart(< W/2.0 + 0.8,by,H*0.38>, <1.4,1.1,H*0.76>, ZERO_ROTATION, 0, TRUE);
    }

    // 8 furnishings: six benches and a raised two-piece altar, preserving the aisle.
    for (i = 0; i < 3; ++i)
    {
        float py = -L*0.28 + i * bay;
        addPart(<-W*0.27,py,1.05>, <W*0.28,1.15,1.3>, ZERO_ROTATION, 3, showFurniture);
        addPart(< W*0.27,py,1.05>, <W*0.28,1.15,1.3>, ZERO_ROTATION, 3, showFurniture);
    }
    addPart(<0.0,L*0.34,0.85>, <W*0.34,2.8,0.7>, ZERO_ROTATION, 3, showFurniture);
    addPart(<0.0,L*0.39,2.05>, <W*0.22,0.9,1.8>, ZERO_ROTATION, 3, showFurniture);

    // 6 broad entrance steps.
    for (i = 0; i < 6; ++i)
        addPart(<0.0,-L/2.0 - 0.65 - i*0.55,0.22 - i*0.06>, <doorW + 1.2 + i*0.65,1.0,0.30>, ZERO_ROTATION, 0, TRUE);

    // 6 finials along the ridge.
    for (i = 0; i < 6; ++i)
        addPart(<0.0,-L/2.0 + bay*(i+0.5),H + rise + 1.35>, <0.45,0.45,1.6>, ZERO_ROTATION, 0, TRUE);
}

string textureForSection(integer section)
{
    string texture = llList2String(sectionTextures, section);
    if (texture == "") return TEXTURE_BLANK;
    return texture;
}

applyLink(integer link, vector pos, rotation rot)
{
    integer index = link - 1;
    vector size = llList2Vector(targetSize,index);
    vector color = llList2Vector(targetColor,index);
    float alpha = llList2Float(targetAlpha,index);
    integer section = llList2Integer(targetSection,index);
    list rules = [PRIM_SIZE,size, PRIM_COLOR,ALL_SIDES,color,alpha,
                  PRIM_TEXTURE,ALL_SIDES,textureForSection(section),<1.0,1.0,0.0>,ZERO_VECTOR,0.0,
                  PRIM_PHYSICS_SHAPE_TYPE,PRIM_PHYSICS_SHAPE_CONVEX];
    if (link != LINK_ROOT) rules += [PRIM_POS_LOCAL,pos,PRIM_ROT_LOCAL,rot];
    llSetLinkPrimitiveParamsFast(link,rules);
}

applyFinal()
{
    integer link;
    for (link = 1; link <= EXPECTED_PRIMS; ++link)
        applyLink(link,llList2Vector(targetPos,link-1),llList2Rot(targetRot,link-1));
}

vector foldedPosition(integer link, vector finalPos)
{
    if (link == 1) return finalPos;
    if (animStyle == 1) return <finalPos.x,finalPos.y,-4.0>; // Rise
    if (animStyle == 2) return <finalPos.x * 0.08,finalPos.y * 0.08,0.45>; // Fold
    return finalPos;
}

rotation foldedRotation(integer link, rotation finalRot)
{
    if (link == 1 || animStyle != 2) return finalRot;
    return llEuler2Rot(<0.0,PI_BY_TWO,0.0>) * finalRot;
}

integer stageForLink(integer link)
{
    if (link <= 13) return 0; // foundation/floors
    if (link <= 33 || (link >= 62 && link <= 69)) return 1; // walls/buttresses
    if (link <= 49) return 3; // roof
    if (link <= 61) return 2; // arches/frames
    if (link <= 83) return 4; // furniture/steps
    return 5; // finials
}

startAnimation(integer direction)
{
    if (!geometryValid())
    {
        llOwnerSay("Build refused: linkset must contain exactly 89 prims and dimensions must be valid.");
        return;
    }
    buildGeometry();
    moveDirection = direction;
    if (animStyle == 0 || animDuration <= 0.1)
    {
        applyFinal();
        saveSettings();
        return;
    }
    // The root foundation is resized now but its position and rotation are never changed.
    applyLink(LINK_ROOT,llList2Vector(targetPos,0),llList2Rot(targetRot,0));
    integer link;
    for (link = 1; link <= EXPECTED_PRIMS; ++link)
    {
        vector finalPos = llList2Vector(targetPos,link-1);
        rotation finalRot = llList2Rot(targetRot,link-1);
        vector folded = foldedPosition(link,finalPos);
        rotation foldRot = foldedRotation(link,finalRot);
        if (direction > 0)
        {
            if (link != 1) applyLink(link,folded,foldRot);
        }
    }
    moveStart = llGetTime();
    moving = TRUE;
    lastStage = -1;
    llSetTimerEvent(0.20);
}

revealParticles(integer stage)
{
    if (!fxEnabled) return;
    // Root-only, short, low-rate reveal: hard cap is 0.5 seconds at 10 particles/sec.
    integer colorSection = 0;
    if (stage == 3) colorSection = 1;
    vector c = schemeColor(colorSection);
    llParticleSystem([PSYS_PART_FLAGS,PSYS_PART_EMISSIVE_MASK,
        PSYS_SRC_PATTERN,PSYS_SRC_PATTERN_EXPLODE,PSYS_PART_START_COLOR,c,
        PSYS_PART_END_COLOR,c,PSYS_PART_START_ALPHA,0.30,PSYS_PART_END_ALPHA,0.0,
        PSYS_PART_START_SCALE,<0.08,0.08,0.0>,PSYS_PART_END_SCALE,<0.30,0.30,0.0>,
        PSYS_PART_MAX_AGE,0.8,PSYS_SRC_BURST_RATE,0.10,PSYS_SRC_BURST_PART_COUNT,1,
        PSYS_SRC_BURST_RADIUS,1.0,PSYS_SRC_MAX_AGE,0.5]);
}

saveSettings()
{
    string data = llDumpList2String([presetName,chapelWidth,chapelLength,wallHeight,roofPitch,
        showWindows,showFurniture,ruinAmount,animDuration,groupDelay,animStyle,fxEnabled,
        colorScheme,llList2String(sectionTextures,0),llList2String(sectionTextures,1),
        llList2String(sectionTextures,2),llList2String(sectionTextures,3)],"|");
    llLinksetDataWrite("GCB_SETTINGS",data);
}

loadSettings()
{
    string data = llLinksetDataRead("GCB_SETTINGS");
    if (data == "") return;
    list p = llParseStringKeepNulls(data,["|"],[]);
    if (llGetListLength(p) < 17) return;
    presetName=llList2String(p,0); chapelWidth=llList2Float(p,1); chapelLength=llList2Float(p,2);
    wallHeight=llList2Float(p,3); roofPitch=llList2Float(p,4); showWindows=llList2Integer(p,5);
    showFurniture=llList2Integer(p,6); ruinAmount=llList2Integer(p,7); animDuration=llList2Float(p,8);
    groupDelay=llList2Float(p,9); animStyle=llList2Integer(p,10); fxEnabled=llList2Integer(p,11);
    colorScheme=llList2Integer(p,12); sectionTextures=llList2List(p,13,16);
}

setPreset(string name)
{
    presetName = name;
    showWindows = TRUE; showFurniture = TRUE; ruinAmount = 0; fxEnabled = TRUE;
    if (name == "Moonlit Chapel") { colorScheme=0; roofPitch=42.0; wallHeight=9.0; }
    else if (name == "Ruined Abbey") { colorScheme=1; roofPitch=36.0; wallHeight=8.0; ruinAmount=3; showWindows=FALSE; }
    else if (name == "Vampire Sanctuary") { colorScheme=2; roofPitch=52.0; wallHeight=11.0; animStyle=2; }
    else { colorScheme=3; roofPitch=46.0; wallHeight=9.5; showFurniture=FALSE; }
    saveSettings();
    startAnimation(1);
}

showMenu(key who, string page)
{
    menuPage = page;
    if (listenDialog) llListenRemove(listenDialog);
    CH_DIALOG = -1000000 - (integer)("0x" + llGetSubString((string)llGetKey(),-6,-1));
    listenDialog = llListen(CH_DIALOG,"",who,"");
    list buttons;
    string msg = "Gothic Chapel Builder\n" + presetName + " | 89 prims\n";
    if (page == "MAIN")
    {
        buttons=["Presets","Dimensions","Features","Colors","Textures","Animation","Effects","BUILD","FOLD","Close"];
        msg += "Choose a configuration page. BUILD validates then morphs in construction order.";
    }
    else if (page == "PRESET") buttons=["Moonlit","Ruined","Vampire","Winter","Back"];
    else if (page == "DIM")
    {
        msg += "W "+(string)chapelWidth+"  L "+(string)chapelLength+"  H "+(string)wallHeight+"  Pitch "+(string)roofPitch;
        buttons=["W +","W -","L +","L -","H +","H -","Pitch +","Pitch -","Back"];
    }
    else if (page == "FEATURE")
    {
        msg += "Windows: "+(string)showWindows+"  Furniture: "+(string)showFurniture+"  Ruin: "+(string)ruinAmount;
        buttons=["Windows","Furniture","Ruin +","Ruin -","Back"];
    }
    else if (page == "COLOR") buttons=["Moonstone","Moss","Crimson","Frost","Back"];
    else if (page == "TEXTURE")
    {
        msg += "Mapping section: "+llList2String(["Structure","Roof","Glass","Furniture"],textureSection)+"\nUse inventory discovery, blank tint, or paste a UUID.";
        buttons=["Section +","Inventory","Blank","Enter UUID","Back"];
    }
    else if (page == "ANIM")
    {
        msg += "Mode: "+llList2String(["Direct Morph","Rise","Fold"],animStyle)+"  Duration: "+(string)animDuration+"  Delay: "+(string)groupDelay;
        buttons=["Direct","Rise","Fold Mode","Time +","Time -","Delay +","Delay -","Back"];
    }
    else
    {
        msg += "Particle reveal: "+(string)fxEnabled+" (strictly capped).";
        buttons=["Particles","Preview FX","Back"];
    }
    llDialog(who,msg,buttons,CH_DIALOG);
}

discoverTexture()
{
    integer count = llGetInventoryNumber(INVENTORY_TEXTURE);
    if (count == 0)
    {
        llOwnerSay("No texture assets found in root inventory; keeping current mapping.");
        return;
    }
    textureCursor = (textureCursor + 1) % count;
    string name = llGetInventoryName(INVENTORY_TEXTURE,textureCursor);
    sectionTextures = llListReplaceList(sectionTextures,[name],textureSection,textureSection);
    llOwnerSay("Mapped inventory texture '"+name+"' to "+llList2String(["structure","roof","glass","furniture"],textureSection)+".");
    saveSettings();
}

default
{
    state_entry()
    {
        llSetMemoryLimit(65536);
        loadSettings();
        if (geometryValid()) { buildGeometry(); applyFinal(); }
        else llOwnerSay("Gothic Chapel Builder requires one linkset of exactly 89 prims. Link in the documented order, then touch the root.");
    }

    changed(integer change)
    {
        if (change & CHANGED_LINK)
        {
            moving=FALSE; llSetTimerEvent(0.0);
            if (geometryValid()) { buildGeometry(); applyFinal(); }
            else llOwnerSay("Link count invalid: expected exactly 89; no geometry was applied.");
        }
        if (change & CHANGED_INVENTORY) textureCursor=-1;
        if (change & CHANGED_OWNER) llResetScript();
    }

    touch_start(integer total)
    {
        key who=llDetectedKey(0);
        if (who != llGetOwner()) return;
        showMenu(who,"MAIN");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (id != llGetOwner()) return;
        if (channel == CH_TEXT)
        {
            if ((key)message)
            {
                sectionTextures=llListReplaceList(sectionTextures,[message],textureSection,textureSection);
                saveSettings();
                llOwnerSay("UUID mapped. Use BUILD to apply it.");
            }
            else llOwnerSay("That is not a valid texture UUID.");
            llListenRemove(listenText); listenText=0;
            showMenu(id,"TEXTURE");
            return;
        }
        if (message=="Close") return;
        if (message=="Back") { showMenu(id,"MAIN"); return; }
        if (message=="Presets") { showMenu(id,"PRESET"); return; }
        if (message=="Dimensions") { showMenu(id,"DIM"); return; }
        if (message=="Features") { showMenu(id,"FEATURE"); return; }
        if (message=="Colors") { showMenu(id,"COLOR"); return; }
        if (message=="Textures") { showMenu(id,"TEXTURE"); return; }
        if (message=="Animation") { showMenu(id,"ANIM"); return; }
        if (message=="Effects") { showMenu(id,"FX"); return; }
        if (message=="BUILD") { startAnimation(1); showMenu(id,"MAIN"); return; }
        if (message=="FOLD") { startAnimation(-1); return; }
        if (message=="Moonlit") { setPreset("Moonlit Chapel"); return; }
        if (message=="Ruined") { setPreset("Ruined Abbey"); return; }
        if (message=="Vampire") { setPreset("Vampire Sanctuary"); return; }
        if (message=="Winter") { setPreset("Winter Memorial"); return; }
        if (message=="W +") chapelWidth=clampf(chapelWidth+1.0,10.0,30.0);
        else if (message=="W -") chapelWidth=clampf(chapelWidth-1.0,10.0,30.0);
        else if (message=="L +") chapelLength=clampf(chapelLength+2.0,16.0,60.0);
        else if (message=="L -") chapelLength=clampf(chapelLength-2.0,16.0,60.0);
        else if (message=="H +") wallHeight=clampf(wallHeight+1.0,5.0,20.0);
        else if (message=="H -") wallHeight=clampf(wallHeight-1.0,5.0,20.0);
        else if (message=="Pitch +") roofPitch=clampf(roofPitch+3.0,20.0,65.0);
        else if (message=="Pitch -") roofPitch=clampf(roofPitch-3.0,20.0,65.0);
        else if (message=="Windows") showWindows=!showWindows;
        else if (message=="Furniture") showFurniture=!showFurniture;
        else if (message=="Ruin +") ruinAmount=(ruinAmount+1)%4;
        else if (message=="Ruin -") { --ruinAmount; if (ruinAmount<0) ruinAmount=3; }
        else if (message=="Moonstone") colorScheme=0;
        else if (message=="Moss") colorScheme=1;
        else if (message=="Crimson") colorScheme=2;
        else if (message=="Frost") colorScheme=3;
        else if (message=="Section +") textureSection=(textureSection+1)%4;
        else if (message=="Inventory") discoverTexture();
        else if (message=="Blank") sectionTextures=llListReplaceList(sectionTextures,[TEXTURE_BLANK],textureSection,textureSection);
        else if (message=="Enter UUID")
        {
            if (listenText) llListenRemove(listenText);
            CH_TEXT=CH_DIALOG-1; listenText=llListen(CH_TEXT,"",id,"");
            llTextBox(id,"Paste one texture asset UUID for the selected section.",CH_TEXT);
            return;
        }
        else if (message=="Direct") animStyle=0;
        else if (message=="Rise") animStyle=1;
        else if (message=="Fold Mode") animStyle=2;
        else if (message=="Time +") animDuration=clampf(animDuration+1.0,1.0,30.0);
        else if (message=="Time -") animDuration=clampf(animDuration-1.0,1.0,30.0);
        else if (message=="Delay +") groupDelay=clampf(groupDelay+0.1,0.0,2.0);
        else if (message=="Delay -") groupDelay=clampf(groupDelay-0.1,0.0,2.0);
        else if (message=="Particles") fxEnabled=!fxEnabled;
        else if (message=="Preview FX") revealParticles(0);
        saveSettings();
        showMenu(id,menuPage);
    }

    timer()
    {
        if (!moving) { llSetTimerEvent(0.0); llParticleSystem([]); return; }
        float elapsed=llGetTime()-moveStart;
        integer link;
        integer done=TRUE;
        for (link=2; link<=EXPECTED_PRIMS; ++link)
        {
            integer stage=stageForLink(link);
            float local=(elapsed-stage*groupDelay)/animDuration;
            local=clampf(local,0.0,1.0);
            if (local<1.0) done=FALSE;
            float t = local;
            if (moveDirection < 0) t = 1.0 - local;
            // Smoothstep eliminates abrupt starts/stops.
            t=t*t*(3.0-2.0*t);
            vector folded=foldedPosition(link,llList2Vector(targetPos,link-1));
            rotation foldRot=foldedRotation(link,llList2Rot(targetRot,link-1));
            vector p=folded+(llList2Vector(targetPos,link-1)-folded)*t;
            rotation r=llAxisAngle2Rot(llRot2Axis(llList2Rot(targetRot,link-1)/foldRot),
                llRot2Angle(llList2Rot(targetRot,link-1)/foldRot)*t)*foldRot;
            applyLink(link,p,r);
            if (moveDirection>0 && stage>lastStage && local>0.0) { lastStage=stage; revealParticles(stage); }
        }
        if (done)
        {
            moving=FALSE; llSetTimerEvent(0.0); llParticleSystem([]);
            if (moveDirection>0) applyFinal();
            saveSettings();
        }
    }
}

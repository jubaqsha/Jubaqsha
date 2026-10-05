// Morphing Familiar - one Mono LSL script for an 18-prim linked object.
// Drop this script in the root prim.  Link numbers 1..18 are controlled explicitly.
// The build is generated entirely with prim parameters; optional inventory textures
// and sounds are discovered automatically.

integer PARTS = 18;
integer DIALOG_CHAN;
integer INPUT_CHAN;
integer listenDialog;
integer listenInput;
key menuUser;
string menuPage = "MAIN";

integer creature = 0; // raven, bat, spider, orb
integer targetCreature = 0;
integer motion = 0;   // stay, hover, circle, roam, transform loop
integer auraOn = TRUE;
integer glowStep = 1;
integer alphaStep = 10;
integer colorIndex = 0;
integer textureIndex = -1; // -1 means blank/default
integer soundOn = TRUE;

float moveSpeed = 0.8;
float rotationSpeed = 0.8;
float wingSpeed = 1.2;
float transitionTime = 2.5;
vector home;
rotation homeRot;
string homeRegion;
vector roamTarget;
float phase;
float loopClock;
integer transforming;
float transformClock;

list COLOR_NAMES = ["Midnight","Raven","Blood","Violet","Ghost","Emerald","Azure","Gold"];
list COLORS = [<0.015,0.020,0.035>,<0.08,0.10,0.14>,<0.38,0.015,0.02>,<0.22,0.03,0.38>,<0.70,0.78,0.90>,<0.02,0.30,0.16>,<0.02,0.18,0.48>,<0.60,0.36,0.03>];
list textures;
list textureNames;
list sounds;
list soundNames;

// Each pose is 18 strides of: local position, local Euler rotation (radians), size.
list ravenPose;
list batPose;
list spiderPose;
list orbPose;

list posePart(vector p, vector r, vector s) { return [p,r,s]; }

buildPoses()
{
    // 1 root/body, 2 chest, 3 head, 4 beak, 5-8 wings, 9-10 tail,
    // 11-12 feet, 13-14 eyes, 15-18 feather tips.
    ravenPose =
        posePart(<0,0,0>,<0,0,0>,<0.75,0.48,0.72>) +
        posePart(<0.10,0,0.27>,<0,0,0>,<0.55,0.40,0.56>) +
        posePart(<0.18,0,0.62>,<0,0,0>,<0.38,0.35,0.36>) +
        posePart(<0.43,0,0.62>,<0,PI_BY_TWO,0>,<0.16,0.18,0.34>) +
        posePart(<0.00,0.35,0.16>,<0.05,0.10,0.18>,<0.72,0.15,0.36>) +
        posePart(<-0.08,0.78,0.12>,<0.08,0.18,0.35>,<0.78,0.12,0.30>) +
        posePart(<0.00,-0.35,0.16>,<-0.05,-0.10,-0.18>,<0.72,0.15,0.36>) +
        posePart(<-0.08,-0.78,0.12>,<-0.08,-0.18,-0.35>,<0.78,0.12,0.30>) +
        posePart(<-0.48,0.13,-0.10>,<0,-0.75,0.12>,<0.65,0.16,0.25>) +
        posePart(<-0.48,-0.13,-0.10>,<0,-0.75,-0.12>,<0.65,0.16,0.25>) +
        posePart(<0.10,0.18,-0.45>,<0,0,0>,<0.10,0.10,0.34>) +
        posePart(<0.10,-0.18,-0.45>,<0,0,0>,<0.10,0.10,0.34>) +
        posePart(<0.34,0.14,0.69>,<0,0,0>,<0.065,0.065,0.065>) +
        posePart(<0.34,-0.14,0.69>,<0,0,0>,<0.065,0.065,0.065>) +
        posePart(<-0.17,1.13,0.06>,<0,0,0.48>,<0.44,0.07,0.20>) +
        posePart(<-0.17,-1.13,0.06>,<0,0,-0.48>,<0.44,0.07,0.20>) +
        posePart(<-0.75,0.22,-0.18>,<0,-0.55,0.18>,<0.38,0.10,0.18>) +
        posePart(<-0.75,-0.22,-0.18>,<0,-0.55,-0.18>,<0.38,0.10,0.18>);

    // 1 body, 2 head, 3-8 three rigid segments per wing, 9-10 ears,
    // 11-12 feet, 13-14 eyes, 15-16 fangs, 17-18 tail membrane accents.
    batPose =
        posePart(<0,0,0>,<0,0,0>,<0.64,0.38,0.64>) +
        posePart(<0.28,0,0.24>,<0,0,0>,<0.40,0.34,0.36>) +
        posePart(<0.02,0.43,0.12>,<0,0,0.20>,<0.63,0.12,0.29>) +
        posePart(<-0.08,0.91,0.08>,<0,0,-0.12>,<0.72,0.10,0.26>) +
        posePart(<0.02,1.43,-0.02>,<0,0,-0.45>,<0.66,0.08,0.23>) +
        posePart(<0.02,-0.43,0.12>,<0,0,-0.20>,<0.63,0.12,0.29>) +
        posePart(<-0.08,-0.91,0.08>,<0,0,0.12>,<0.72,0.10,0.26>) +
        posePart(<0.02,-1.43,-0.02>,<0,0,0.45>,<0.66,0.08,0.23>) +
        posePart(<0.28,0.15,0.52>,<0,-0.25,0.15>,<0.14,0.10,0.34>) +
        posePart(<0.28,-0.15,0.52>,<0,-0.25,-0.15>,<0.14,0.10,0.34>) +
        posePart(<0.02,0.16,-0.42>,<0,0,0>,<0.09,0.09,0.28>) +
        posePart(<0.02,-0.16,-0.42>,<0,0,0>,<0.09,0.09,0.28>) +
        posePart(<0.43,0.13,0.31>,<0,0,0>,<0.06,0.06,0.06>) +
        posePart(<0.43,-0.13,0.31>,<0,0,0>,<0.06,0.06,0.06>) +
        posePart(<0.47,0.08,0.13>,<0,0,0>,<0.04,0.04,0.14>) +
        posePart(<0.47,-0.08,0.13>,<0,0,0>,<0.04,0.04,0.14>) +
        posePart(<-0.37,0.20,-0.06>,<0,-0.65,0.30>,<0.48,0.08,0.22>) +
        posePart(<-0.37,-0.20,-0.06>,<0,-0.65,-0.30>,<0.48,0.08,0.22>);

    // 1-2 abdomen/thorax, 3 head, 4-5 eyes, 6-7 fangs, 8-15 eight rigid legs,
    // 16-17 pedipalps, 18 abdomen marking.
    spiderPose =
        posePart(<-0.18,0,0>,<0,0,0>,<0.78,0.64,0.48>) +
        posePart(<0.35,0,0.02>,<0,0,0>,<0.52,0.48,0.36>) +
        posePart(<0.68,0,0.03>,<0,0,0>,<0.34,0.34,0.27>) +
        posePart(<0.82,0.12,0.11>,<0,0,0>,<0.06,0.06,0.06>) +
        posePart(<0.82,-0.12,0.11>,<0,0,0>,<0.06,0.06,0.06>) +
        posePart(<0.85,0.09,-0.07>,<0,0.45,0>,<0.06,0.06,0.18>) +
        posePart(<0.85,-0.09,-0.07>,<0,0.45,0>,<0.06,0.06,0.18>) +
        posePart(<0.35,0.52,-0.04>,<0.15,0,0.75>,<0.90,0.10,0.10>) +
        posePart(<0.05,0.67,-0.06>,<0.25,0,1.10>,<0.92,0.10,0.10>) +
        posePart(<-0.25,0.65,-0.07>,<0.28,0,1.45>,<0.90,0.10,0.10>) +
        posePart(<-0.48,0.48,-0.08>,<0.20,0,1.85>,<0.86,0.10,0.10>) +
        posePart(<0.35,-0.52,-0.04>,<-0.15,0,-0.75>,<0.90,0.10,0.10>) +
        posePart(<0.05,-0.67,-0.06>,<-0.25,0,-1.10>,<0.92,0.10,0.10>) +
        posePart(<-0.25,-0.65,-0.07>,<-0.28,0,-1.45>,<0.90,0.10,0.10>) +
        posePart(<-0.48,-0.48,-0.08>,<-0.20,0,-1.85>,<0.86,0.10,0.10>) +
        posePart(<0.64,0.26,-0.10>,<0,0,0.55>,<0.38,0.08,0.08>) +
        posePart(<0.64,-0.26,-0.10>,<0,0,-0.55>,<0.38,0.08,0.08>) +
        posePart(<-0.20,0,0.25>,<0,0,0>,<0.28,0.20,0.05>);

    // Compact magical orb: every prim forms a core, three rings, and sparks.
    orbPose =
        posePart(<0,0,0>,<0,0,0>,<0.72,0.72,0.72>) +
        posePart(<0,0,0>,<0,0,0>,<0.90,0.90,0.90>) +
        posePart(<0,0,0>,<PI_BY_TWO,0,0>,<1.05,1.05,0.055>) +
        posePart(<0,0,0>,<0,PI_BY_TWO,0>,<1.18,1.18,0.045>) +
        posePart(<0,0,0>,<0,0,0>,<1.30,1.30,0.035>) +
        posePart(<0.62,0,0>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<-0.62,0,0>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<0,0.62,0>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<0,-0.62,0>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<0,0,0.62>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<0,0,-0.62>,<0,0,0>,<0.13,0.13,0.13>) +
        posePart(<0.42,0.42,0.30>,<0,0,0>,<0.10,0.10,0.10>) +
        posePart(<0.42,-0.42,-0.30>,<0,0,0>,<0.10,0.10,0.10>) +
        posePart(<-0.42,0.42,-0.30>,<0,0,0>,<0.10,0.10,0.10>) +
        posePart(<-0.42,-0.42,0.30>,<0,0,0>,<0.10,0.10,0.10>) +
        posePart(<0.30,0.30,-0.48>,<0,0,0>,<0.09,0.09,0.09>) +
        posePart(<0.30,-0.30,0.48>,<0,0,0>,<0.09,0.09,0.09>) +
        posePart(<-0.30,0.30,0.48>,<0,0,0>,<0.09,0.09,0.09>);
}

list getPose(integer which)
{
    if (which == 0) return ravenPose;
    if (which == 1) return batPose;
    if (which == 2) return spiderPose;
    return orbPose;
}

vector mixV(vector a, vector b, float t) { return a + ((b-a)*t); }
float clamp(float v, float lo, float hi) { if (v < lo) return lo; if (v > hi) return hi; return v; }

integer isEye(integer link)
{
    if ((creature == 0 || creature == 1) && (link == 13 || link == 14)) return TRUE;
    if (creature == 2 && (link == 4 || link == 5)) return TRUE;
    return FALSE;
}

integer isRing(integer link) { return creature == 3 && link >= 3 && link <= 5; }

applyPart(integer link, vector pos, vector er, vector size, float visible)
{
    vector col = llList2Vector(COLORS,colorIndex);
    list shape;
    list p;
    if (isEye(link)) col = <0.8,0.02,0.02>;
    if (creature == 3) col = mixV(col,<0.55,0.80,1.0>,0.38);
    shape = [PRIM_TYPE,PRIM_TYPE_SPHERE,PRIM_HOLE_DEFAULT,<0.0,1.0,0.0>,0.0,<0.0,0.0,0.0>,<0.0,1.0,0.0>];
    if (isRing(link))
        shape = [PRIM_TYPE,PRIM_TYPE_TORUS,PRIM_HOLE_DEFAULT,
            <0.0,1.0,0.0>,0.0,<0.0,0.0,0.0>,<1.0,0.06,0.0>,
            <0.0,0.0,0.0>,<0.0,1.0,0.0>,<0.0,0.0,0.0>,1.0,0.0,0.0];
    // PRIM_POS_LOCAL on link 1 is a region position, so never feed the root a
    // pose-relative coordinate.  This also makes hiding/gathering teleport-safe.
    if (link == LINK_ROOT) p = [PRIM_SIZE,size] + shape;
    else p = [PRIM_POS_LOCAL,pos,PRIM_ROT_LOCAL,llEuler2Rot(er),PRIM_SIZE,size] + shape;
    p +=
        [PRIM_COLOR,ALL_SIDES,col,visible*(float)alphaStep/10.0,PRIM_GLOW,ALL_SIDES,(float)glowStep*0.05,
         PRIM_FULLBRIGHT,ALL_SIDES,(creature == 3 || isEye(link))];
    if (textureIndex >= 0 && textureIndex < llGetListLength(textures))
        p += [PRIM_TEXTURE,ALL_SIDES,llList2String(textures,textureIndex),<1,1,0>,ZERO_VECTOR,0];
    else p += [PRIM_TEXTURE,ALL_SIDES,TEXTURE_BLANK,<1,1,0>,ZERO_VECTOR,0];
    llSetLinkPrimitiveParamsFast(link,p);
}

applyPose(list pose, float visibility)
{
    integer i;
    for (i=1; i<=PARTS; ++i)
    {
        integer n=(i-1)*3;
        applyPart(i,llList2Vector(pose,n),llList2Vector(pose,n+1),llList2Vector(pose,n+2),visibility);
    }
}

applyTransition(float amount)
{
    list src=getPose(creature);
    list dst=getPose(targetCreature);
    integer i;
    float vis=1.0;
    for (i=1; i<=PARTS; ++i)
    {
        integer n=(i-1)*3;
        vector p1=llList2Vector(src,n); vector r1=llList2Vector(src,n+1); vector s1=llList2Vector(src,n+2);
        vector p2=llList2Vector(dst,n); vector r2=llList2Vector(dst,n+1); vector s2=llList2Vector(dst,n+2);
        vector center=<0,0,0>; vector tiny=<0.05,0.05,0.05>;
        vector p; vector r; vector s;
        if (amount < 0.33)
        {
            float q=amount/0.33; p=mixV(p1,center,q); r=mixV(r1,ZERO_VECTOR,q); s=mixV(s1,tiny,q);
        }
        else if (amount < 0.66)
        {
            float q=(amount-0.33)/0.33; p=center; r=mixV(ZERO_VECTOR,r2,q); s=mixV(tiny,s2*0.35,q);
        }
        else
        {
            float q=(amount-0.66)/0.34; p=mixV(center,p2,q); r=r2; s=mixV(s2*0.35,s2,q);
        }
        applyPart(i,p,r,s,vis);
    }
}

animateParts()
{
    list p=getPose(creature);
    float w=llSin(phase*wingSpeed*2.0);
    integer i;
    for (i=1; i<=PARTS; ++i)
    {
        integer n=(i-1)*3;
        vector pos=llList2Vector(p,n); vector er=llList2Vector(p,n+1); vector sz=llList2Vector(p,n+2);
        if (creature == 0)
        {
            if (i >= 5 && i <= 8) er.x += w*0.42*((i<7)*2-1);
            if (i == 3 || i == 4 || i == 13 || i == 14) er.z += llSin(phase*0.7)*0.35;
        }
        else if (creature == 1 && i >= 3 && i <= 8)
            er.x += w*0.62*((i<6)*2-1);
        else if (creature == 2 && i >= 8 && i <= 15)
        {
            float side=1.0; if (i>=12) side=-1.0;
            er.x += llSin(phase*1.5+(float)i)*0.22*side;
            pos.z += llSin(phase*1.5+(float)i)*0.05;
        }
        else if (creature == 3)
        {
            float pulse=1.0+0.10*llSin(phase*2.0);
            sz *= pulse;
            if (i>=3 && i<=5) er.z += phase*0.25*(float)(i-3);
        }
        if (i == LINK_ROOT) llSetLinkPrimitiveParamsFast(i,[PRIM_SIZE,sz]);
        else llSetLinkPrimitiveParamsFast(i,[PRIM_POS_LOCAL,pos,PRIM_ROT_LOCAL,llEuler2Rot(er),PRIM_SIZE,sz]);
    }
}

setAura()
{
    vector c=llList2Vector(COLORS,colorIndex);
    integer flags=PSYS_PART_INTERP_COLOR_MASK|PSYS_PART_INTERP_SCALE_MASK|PSYS_PART_EMISSIVE_MASK;
    string tex="";
    float rate=0.12;
    vector start=<0.10,0.10,0>;
    vector finish=<0.01,0.01,0>;
    float life=1.8;
    integer pattern=PSYS_SRC_PATTERN_EXPLODE;
    llLinkParticleSystem(LINK_ROOT,[]);
    if (!auraOn) return;
    if (textureIndex >= 0) tex=llList2String(textures,textureIndex);
    if (creature==0) { rate=0.18; start=<0.12,0.05,0>; finish=<0.03,0.01,0>; life=2.4; pattern=PSYS_SRC_PATTERN_ANGLE_CONE; }
    else if (creature==1) { c=<0.08,0.02,0.12>; start=<0.22,0.10,0>; finish=<0.04,0.02,0>; }
    else if (creature==2) { c=<0.28,0.32,0.34>; start=<0.32,0.32,0>; finish=<0.65,0.65,0>; rate=0.24; life=3.0; }
    else { c=mixV(c,<0.5,0.8,1>,0.5); start=<0.07,0.07,0>; finish=<0.01,0.01,0>; rate=0.08; life=1.2; }
    llLinkParticleSystem(LINK_ROOT,[PSYS_PART_FLAGS,flags,PSYS_SRC_PATTERN,pattern,PSYS_PART_START_COLOR,c,
        PSYS_PART_END_COLOR,c,PSYS_PART_START_ALPHA,0.75,PSYS_PART_END_ALPHA,0.0,
        PSYS_PART_START_SCALE,start,PSYS_PART_END_SCALE,finish,PSYS_PART_MAX_AGE,life,
        PSYS_SRC_TEXTURE,tex,PSYS_SRC_BURST_RATE,rate,PSYS_SRC_BURST_PART_COUNT,2,
        PSYS_SRC_BURST_SPEED_MIN,0.05,PSYS_SRC_BURST_SPEED_MAX,0.35,
        PSYS_SRC_ACCEL,<0,0,0.08>,PSYS_SRC_ANGLE_BEGIN,0.0,PSYS_SRC_ANGLE_END,PI]);
}

discoverAssets()
{
    integer i;
    integer n=llGetInventoryNumber(INVENTORY_TEXTURE);
    textures=[]; textureNames=[]; sounds=[]; soundNames=[];
    for (i=0;i<n;++i) { string x=llGetInventoryName(INVENTORY_TEXTURE,i); textures += [llGetInventoryKey(x)]; textureNames += [x]; }
    n=llGetInventoryNumber(INVENTORY_SOUND);
    for (i=0;i<n;++i) { string s=llGetInventoryName(INVENTORY_SOUND,i); sounds += [llGetInventoryKey(s)]; soundNames += [s]; }
}

playSound()
{
    if (soundOn && llGetListLength(sounds)>0) llTriggerSound(llList2String(sounds,creature%llGetListLength(sounds)),0.7);
}

startTransform(integer next)
{
    if (transforming || next==creature) return;
    targetCreature=next; transforming=TRUE; transformClock=0.0; playSound();
}

string creatureName() { return llList2String(["Raven","Bat","Spider","Orb"],creature); }
string motionName() { return llList2String(["Stay","Hover","Circle","Roam","Transform Loop"],motion); }

showMenu(string page)
{
    list buttons;
    string msg="Morphing Familiar\n"+creatureName()+" • "+motionName()+"\n";
    menuPage=page;
    if (page=="MAIN") buttons=["Creature","Motion","Aura","Colors","Glow","Alpha","Textures","Sounds","Set Home","Return Home","Save","Load"];
    else if (page=="CREATURE") buttons=["Raven","Bat","Spider","Orb","◀ Main"];
    else if (page=="MOTION") buttons=["Stay","Hover","Circle","Roam","Transform Loop","Tuning","◀ Main"];
    else if (page=="TUNING") buttons=["Move -","Move +","Turn -","Turn +","Wing -","Wing +","Time -","Time +","◀ Main"];
    else if (page=="AURA") buttons=["Aura On","Aura Off","◀ Main"];
    else if (page=="COLORS") buttons=COLOR_NAMES+["◀ Main"];
    else if (page=="GLOW") buttons=["Glow -","Glow +","◀ Main"];
    else if (page=="ALPHA") buttons=["Alpha -","Alpha +","◀ Main"];
    else if (page=="SOUNDS") buttons=["Sound On","Sound Off","Play Sound","◀ Main"];
    else if (page=="TEXTURES")
    {
        buttons=["Default","Previous","Next","Enter UUID","◀ Main"];
        if (textureIndex>=0) msg += "Texture: "+llList2String(textureNames,textureIndex)+"\n";
        else msg += "Texture: Default\n";
    }
    llDialog(menuUser,msg+"Move "+(string)moveSpeed+" | Turn "+(string)rotationSpeed+" | Wing "+(string)wingSpeed+" | Transition "+(string)transitionTime,buttons,DIALOG_CHAN);
}

saveSettings()
{
    string data=llList2CSV([creature,motion,auraOn,glowStep,alphaStep,colorIndex,textureIndex,soundOn,moveSpeed,rotationSpeed,wingSpeed,transitionTime]);
    llLinksetDataWrite("familiar.settings",data);
    llOwnerSay("Familiar settings saved.");
}

loadSettings()
{
    list d=llCSV2List(llLinksetDataRead("familiar.settings"));
    if (llGetListLength(d)<12) { llOwnerSay("No saved settings yet."); return; }
    creature=(integer)llList2String(d,0); targetCreature=creature; motion=(integer)llList2String(d,1);
    auraOn=(integer)llList2String(d,2); glowStep=(integer)llList2String(d,3); alphaStep=(integer)llList2String(d,4);
    colorIndex=(integer)llList2String(d,5); textureIndex=(integer)llList2String(d,6); soundOn=(integer)llList2String(d,7);
    moveSpeed=(float)llList2String(d,8); rotationSpeed=(float)llList2String(d,9); wingSpeed=(float)llList2String(d,10); transitionTime=(float)llList2String(d,11);
    applyPose(getPose(creature),1.0); setAura();
}

setHome()
{
    home=llGetPos(); homeRot=llGetRot(); homeRegion=llGetRegionName(); roamTarget=ZERO_VECTOR;
    llLinksetDataWrite("familiar.home",llList2CSV([homeRegion,home.x,home.y,home.z,homeRot.x,homeRot.y,homeRot.z,homeRot.s]));
    llOwnerSay("Home stored for this region.");
}

loadHome()
{
    list h=llCSV2List(llLinksetDataRead("familiar.home"));
    // A home belongs to one simulator region.  An object rezzed after being
    // transported must never try to use the same numeric coordinates in a
    // different region as an old roaming anchor.
    if (llGetListLength(h)==8 && llList2String(h,0)==llGetRegionName())
    {
        homeRegion=llList2String(h,0);
        home=<(float)llList2String(h,1),(float)llList2String(h,2),(float)llList2String(h,3)>;
        homeRot=<(float)llList2String(h,4),(float)llList2String(h,5),(float)llList2String(h,6),(float)llList2String(h,7)>;
    }
    else setHome();
}

moveObject()
{
    vector here=llGetPos();
    vector wanted=here;
    float t=phase*moveSpeed;
    vector delta;
    if (motion==1) wanted=<home.x,home.y,home.z+0.35+0.20*llSin(t)>;
    else if (motion==2) wanted=home+<llCos(t)*4.0,llSin(t)*4.0,0.7+0.25*llSin(t*2.0)>;
    else if (motion==3)
    {
        if (llVecDist(here,roamTarget)<0.4 || roamTarget==ZERO_VECTOR)
        {
            float a=llFrand(TWO_PI); float r=llFrand(10.0);
            roamTarget=home+<llCos(a)*r,llSin(a)*r,llFrand(1.5)>;
        }
        wanted=here+llVecNorm(roamTarget-here)*moveSpeed*0.10;
    }
    if (llVecDist(wanted,home)>10.0) wanted=home+llVecNorm(wanted-home)*10.0;
    if (motion>0 && motion<4)
    {
        llSetRegionPos(wanted);
        delta=wanted-here;
        if (llVecMag(delta)>0.01)
        {
            float yaw=llAtan2(delta.y,delta.x);
            float current=llRot2Euler(llGetRot()).z;
            float difference=yaw-current;
            if (difference>PI) difference-=TWO_PI;
            else if (difference < -PI) difference+=TWO_PI;
            float step=rotationSpeed*0.10;
            llSetRot(llEuler2Rot(<0,0,current+clamp(difference,-step,step)>));
        }
    }
    if (motion==4 && !transforming)
    {
        loopClock += 0.1;
        if (loopClock>=8.0) { loopClock=0.0; startTransform((creature+1)%4); }
    }
}

handleButton(string m)
{
    integer x;
    if (m=="◀ Main") { showMenu("MAIN"); return; }
    if (m=="Creature" || m=="Motion" || m=="Aura" || m=="Colors" || m=="Glow" || m=="Alpha" || m=="Sounds" || m=="Textures" || m=="Tuning") { showMenu(llToUpper(m)); return; }
    x=llListFindList(["Raven","Bat","Spider","Orb"],[m]); if (x>=0) { startTransform(x); showMenu("CREATURE"); return; }
    x=llListFindList(["Stay","Hover","Circle","Roam","Transform Loop"],[m]); if (x>=0) { motion=x; showMenu("MOTION"); return; }
    x=llListFindList(COLOR_NAMES,[m]); if (x>=0) { colorIndex=x; applyPose(getPose(creature),1.0); setAura(); showMenu("COLORS"); return; }
    if (m=="Aura On") auraOn=TRUE; else if (m=="Aura Off") auraOn=FALSE;
    else if (m=="Glow -") glowStep=(integer)llMax(0,glowStep-1); else if (m=="Glow +") glowStep=(integer)llMin(4,glowStep+1);
    else if (m=="Alpha -") alphaStep=(integer)llMax(1,alphaStep-1); else if (m=="Alpha +") alphaStep=(integer)llMin(10,alphaStep+1);
    else if (m=="Move -") moveSpeed=clamp(moveSpeed-0.2,0.2,3.0); else if (m=="Move +") moveSpeed=clamp(moveSpeed+0.2,0.2,3.0);
    else if (m=="Turn -") rotationSpeed=clamp(rotationSpeed-0.2,0.2,3.0); else if (m=="Turn +") rotationSpeed=clamp(rotationSpeed+0.2,0.2,3.0);
    else if (m=="Wing -") wingSpeed=clamp(wingSpeed-0.2,0.2,4.0); else if (m=="Wing +") wingSpeed=clamp(wingSpeed+0.2,0.2,4.0);
    else if (m=="Time -") transitionTime=clamp(transitionTime-0.5,0.5,8.0); else if (m=="Time +") transitionTime=clamp(transitionTime+0.5,0.5,8.0);
    else if (m=="Sound On") soundOn=TRUE; else if (m=="Sound Off") soundOn=FALSE; else if (m=="Play Sound") playSound();
    else if (m=="Set Home") setHome(); else if (m=="Return Home") { llSetRegionPos(home); llSetRot(homeRot); }
    else if (m=="Save") saveSettings(); else if (m=="Load") loadSettings();
    else if (m=="Default") textureIndex=-1;
    else if (m=="Previous" && llGetListLength(textures)>0) { --textureIndex; if (textureIndex<0) textureIndex=llGetListLength(textures)-1; }
    else if (m=="Next" && llGetListLength(textures)>0) { ++textureIndex; if (textureIndex>=llGetListLength(textures)) textureIndex=0; }
    else if (m=="Enter UUID") { llTextBox(menuUser,"Paste a texture UUID (or type default).",INPUT_CHAN); return; }
    applyPose(getPose(creature),1.0); setAura(); showMenu(menuPage);
}

default
{
    state_entry()
    {
        if (llGetNumberOfPrims()!=PARTS) llOwnerSay("This object must contain exactly 18 linked prims; found "+(string)llGetNumberOfPrims()+".");
        DIALOG_CHAN=-(100000+(integer)llFrand(900000.0)); INPUT_CHAN=DIALOG_CHAN-1;
        listenDialog=llListen(DIALOG_CHAN,"",NULL_KEY,""); listenInput=llListen(INPUT_CHAN,"",NULL_KEY,"");
        buildPoses(); discoverAssets(); loadHome(); loadSettings(); applyPose(getPose(creature),1.0); setAura();
        llSetTimerEvent(0.10);
    }

    changed(integer c)
    {
        if (c & CHANGED_INVENTORY) { discoverAssets(); setAura(); }
        if (c & CHANGED_LINK) { if (llGetNumberOfPrims()==PARTS) applyPose(getPose(creature),1.0); else llOwnerSay("Exactly 18 linked prims are required."); }
        if (c & CHANGED_OWNER) llResetScript();
    }

    touch_start(integer count)
    {
        key who=llDetectedKey(0);
        if (who!=llGetOwner()) return;
        menuUser=who; showMenu("MAIN");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (id!=llGetOwner()) return;
        menuUser=id;
        if (channel==INPUT_CHAN)
        {
            if (llToLower(message)=="default") textureIndex=-1;
            else if ((key)message!=NULL_KEY) { textures += [(key)message]; textureNames += ["Custom UUID"]; textureIndex=llGetListLength(textures)-1; }
            else llOwnerSay("That is not a valid texture UUID.");
            applyPose(getPose(creature),1.0); setAura(); showMenu("TEXTURES"); return;
        }
        handleButton(message);
    }

    timer()
    {
        float q;
        phase += 0.10;
        if (transforming)
        {
            transformClock += 0.10;
            q=clamp(transformClock/transitionTime,0.0,1.0);
            // Smoothstep makes gather and unfolding ease in and out.
            q=q*q*(3.0-2.0*q); applyTransition(q);
            if (transformClock>=transitionTime)
            {
                creature=targetCreature; transforming=FALSE; applyPose(getPose(creature),1.0); setAura();
            }
        }
        else animateParts();
        moveObject();
    }
}

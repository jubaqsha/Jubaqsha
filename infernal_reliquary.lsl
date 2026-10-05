/*
    INFERNAL RELIQUARY -- single-script, nineteen-link installation

    Drop this Mono script in the ROOT of an object containing exactly 19 prims.
    Link numbers are deliberately the only rigging convention: the script builds
    every mesh-like form from ordinary prims, so no helper object or notecard is
    required.  The root is link 1 and is recoloured, reshaped, made luminous and
    pulsed in every form rather than serving as an invisible controller.

    Touch any prim for the dialog.  Text-box replies are used only for UUID entry;
    there are no typed chat commands. Settings and home are stored in linkset data.
*/

integer LINKS = 19;
integer DIALOG;
integer listenHandle;
key menuUser;
string page = "MAIN";
integer paletteTarget;             // 0 body, 1 particles

integer mode = 1;                 // 0 Display, 1 Animate, 2 Absorb, 3 Release
integer shape = 0;                // star, serpent, mask, portal
float effectSpeed = 1.0;
float rotationSpeed = 1.0;
float transitionTime = 6.0;       // constrained to 3..15 seconds
float phaseClock;
float transitionClock;
integer transitionPhase;          // 0 idle, 1 Gather, 2 Reshape, 3 Reveal

vector bodyColor = <0.35,0.02,0.55>;
vector particleColor = <0.65,0.05,1.0>;
float bodyGlow = 0.12;
float bodyAlpha = 1.0;
string textureID = TEXTURE_BLANK;
string soundID = "";
vector homePos;
rotation homeRot;

list startPos; list startRot; list startSize; list startAlpha;
list gatherPos; list targetPos; list targetRot; list targetSize;

float clampf(float v, float lo, float hi) { if (v < lo) return lo; if (v > hi) return hi; return v; }
vector mixv(vector a, vector b, float t) { return a + (b-a)*t; }
rotation mixr(rotation a, rotation b, float t) { return llSlerp(a,b,t); }
rotation euler(vector degrees) { return llEuler2Rot(degrees*DEG_TO_RAD); }

vector polar(float radius, float angle, float z)
{ return <radius*llCos(angle),radius*llSin(angle),z>; }

// Compact serializers keep persistent data human inspectable in linkset data.
string V(vector v) { return (string)v; }
saveSettings()
{
    llLinksetDataWrite("IR_SETTINGS", llList2CSV([shape,mode,effectSpeed,rotationSpeed,
        transitionTime,V(bodyColor),V(particleColor),bodyGlow,bodyAlpha,textureID,soundID]));
    llLinksetDataWrite("IR_HOME", llList2CSV([V(homePos),(string)homeRot]));
}

loadSettings()
{
    string s = llLinksetDataRead("IR_SETTINGS");
    if (s != "")
    {
        list a = llCSV2List(s);
        shape=(integer)llList2String(a,0); mode=(integer)llList2String(a,1);
        effectSpeed=(float)llList2String(a,2); rotationSpeed=(float)llList2String(a,3);
        transitionTime=clampf((float)llList2String(a,4),3.0,15.0);
        bodyColor=(vector)llList2String(a,5); particleColor=(vector)llList2String(a,6);
        bodyGlow=(float)llList2String(a,7); bodyAlpha=(float)llList2String(a,8);
        textureID=llList2String(a,9); soundID=llList2String(a,10);
    }
    s = llLinksetDataRead("IR_HOME");
    if (s != "") { list h=llCSV2List(s); homePos=(vector)llList2String(h,0); homeRot=(rotation)llList2String(h,1); }
    else { homePos=llGetPos(); homeRot=llGetRot(); }
}

// Inventory assets are preferred automatically. Names may be anything; the first
// texture and sound are selected. UUID settings remain available for external assets.
detectAssets()
{
    if (llGetInventoryNumber(INVENTORY_TEXTURE) > 0)
        textureID = llGetInventoryName(INVENTORY_TEXTURE,0);
    if (llGetInventoryNumber(INVENTORY_SOUND) > 0)
        soundID = llGetInventoryName(INVENTORY_SOUND,0);
}

snapshot()
{
    startPos=[]; startRot=[]; startSize=[]; startAlpha=[];
    integer i;
    for(i=1;i<=LINKS;++i)
    {
        list d=llGetLinkPrimitiveParams(i,[PRIM_POS_LOCAL,PRIM_ROT_LOCAL,PRIM_SIZE,PRIM_COLOR,ALL_SIDES]);
        startPos += [llList2Vector(d,0)]; startRot += [llList2Rot(d,1)];
        startSize += [llList2Vector(d,2)]; startAlpha += [llList2Float(d,4)];
    }
}

// Generate all target transforms procedurally. Each list always contains 19 entries.
buildShape(integer which)
{
    targetPos=[]; targetRot=[]; targetSize=[]; gatherPos=[];
    integer i; float a; vector p; vector sz; rotation r;
    for(i=0;i<LINKS;++i)
    {
        if (which == 0) // five-bar pentagram plus fourteen orbiting ornaments
        {
            if(i<5)
            {
                a=TWO_PI*(float)i/5.0;
                p=polar(1.05,a,0.0); sz=<0.20,2.15,0.16>;
                r=euler(<90,0,(a*RAD_TO_DEG)-18.0>);
            }
            else
            {
                a=TWO_PI*(float)(i-5)/14.0;
                p=polar(2.15,a,0.18*llSin(a*3.0)); sz=<0.24,0.24,0.24>;
                r=euler(<0,a*RAD_TO_DEG,a*RAD_TO_DEG>);
            }
        }
        else if (which == 1) // segmented, rising coil
        {
            a=(float)i*0.72;
            p=polar(0.55+0.045*(float)i,a,-1.35+0.15*(float)i);
            sz=<0.42,0.58,0.38>; if(i==18) sz=<0.65,0.80,0.52>;
            r=euler(<0,18.0*llSin(a),a*RAD_TO_DEG+90.0>);
        }
        else if (which == 2) // bilateral horns, brows, muzzle and articulated jaw
        {
            integer row=i/5; integer col=i%5;
            p=<(float)(col-2)*0.55,0.16*llAbs((float)(col-2)),-0.70+(float)row*0.55>;
            sz=<0.48,0.34,0.46>; r=euler(<0,0,(float)(col-2)*-8.0>);
            if(i>=15) { p.z=1.0+(float)(i-15)*0.32; p.x=((i&1)*2-1)*(1.25+0.15*(float)(i-15)); sz=<0.30,0.30,0.85>; r=euler(<0,20,(i&1)*30-15>); }
            if(i>=10 && i<=14) { p.z=-1.08; sz=<0.48,0.42,0.28>; } // jaw links
        }
        else // irregular, jagged portal oval
        {
            a=TWO_PI*(float)i/19.0;
            p=<1.75*llCos(a),0.0,2.30*llSin(a)>;
            sz=<0.30+0.12*llFabs(llSin(a*4.0)),0.42,0.72>;
            r=euler(<90,a*RAD_TO_DEG+90,7.0*llSin(a*5.0)>);
        }
        targetPos += [p]; targetRot += [r]; targetSize += [sz];
        // Gather is derived from the destination but starts from the live snapshot.
        gatherPos += [p*0.18];
    }
}

setGeometry(integer link, vector p, rotation r, vector sz, float alpha)
{
    integer type=PRIM_TYPE_BOX;
    if(shape==1) type=PRIM_TYPE_SPHERE;
    else if(shape==2) type=PRIM_TYPE_SCULPT; // replaced below: keep ordinary prim fallback
    else if(shape==3) type=PRIM_TYPE_PRISM;
    list params=[PRIM_POS_LOCAL,p,PRIM_ROT_LOCAL,r,PRIM_SIZE,sz,
        PRIM_COLOR,ALL_SIDES,bodyColor,clampf(alpha,0.02,1.0),
        PRIM_GLOW,ALL_SIDES,bodyGlow,PRIM_TEXTURE,ALL_SIDES,textureID,<1,1,0>,ZERO_VECTOR,0.0];
    // Never request a sculpt asset: the mask is formed from tapered boxes.
    if(shape==0) params += [PRIM_TYPE,PRIM_TYPE_BOX,0,<0,1,0>,0,<0,0,0>,<1,1,0>];
    else if(shape==1) params += [PRIM_TYPE,PRIM_TYPE_SPHERE,0,<0,1,0>,0.0,<0,0,0>,<0,1,0>];
    else if(shape==2) params += [PRIM_TYPE,PRIM_TYPE_BOX,0,<0.18,0.82,0>,0,<0,0,0>,<1,1,0>];
    else params += [PRIM_TYPE,PRIM_TYPE_PRISM,0,<0,1,0>,0,<0,0>,<0.65,1,0>];
    // A root has no meaningful local position: moving it would move the whole
    // installation.  It still visibly participates through size/type/material,
    // colour, glow and pulse, while child links receive complete transforms.
    if(link==1) params=llDeleteSubList(params,0,3);
    llSetLinkPrimitiveParamsFast(link,params);
}

beginTransition(integer next)
{
    snapshot(); shape=next; buildShape(shape); transitionClock=0.0; transitionPhase=1;
    if(soundID!="") llTriggerSound(soundID,0.6);
}

transitionStep(float dt)
{
    transitionClock += dt;
    float each=transitionTime/3.0;
    float t=clampf(transitionClock/each,0.0,1.0);
    integer i; vector p; rotation r; vector sz; float al;
    for(i=0;i<LINKS;++i)
    {
        vector sp=llList2Vector(startPos,i); rotation sr=llList2Rot(startRot,i);
        vector ss=llList2Vector(startSize,i); float sa=llList2Float(startAlpha,i);
        vector gp=llList2Vector(gatherPos,i); vector tp=llList2Vector(targetPos,i);
        rotation tr=llList2Rot(targetRot,i); vector ts=llList2Vector(targetSize,i);
        if(transitionPhase==1) { p=mixv(sp,gp,t); r=mixr(sr,ZERO_ROTATION,t); sz=mixv(ss,ss*0.35,t); al=sa*(1.0-0.75*t); }
        else if(transitionPhase==2) { p=mixv(gp,tp,t); r=mixr(ZERO_ROTATION,tr,t); sz=mixv(ss*0.35,ts,t); al=0.25; }
        else { p=tp; r=tr; sz=ts; al=0.25+(bodyAlpha-0.25)*t; }
        setGeometry(i+1,p,r,sz,al);
    }
    if(t>=1.0)
    {
        transitionClock=0.0; ++transitionPhase;
        if(transitionPhase>3) { transitionPhase=0; saveSettings(); }
    }
}

particles(integer link, integer kind)
{
    if(mode==0 || mode==2) { llLinkParticleSystem(link,[]); return; }
    vector c1=particleColor; vector c2=particleColor*0.35;
    integer flags=PSYS_PART_INTERP_COLOR_MASK|PSYS_PART_INTERP_SCALE_MASK|PSYS_PART_EMISSIVE_MASK;
    integer pattern=PSYS_SRC_PATTERN_ANGLE_CONE; float burst=0.10/effectSpeed;
    float speed=0.8; vector accel=<0,0,0.3>;
    if(kind==1) { c2=<1,0.03,0.0>; speed=1.8; accel=<0,0,-0.4>; }       // crimson embers
    else if(kind==2) { c1=<0.05,0.8,0.25>; c2=<0,0.12,0.05>; speed=0.25; accel=<0,0,0.08>; } // mist
    else if(kind==3) { c1=<1,1,1>; c2=particleColor; speed=2.4; }       // spectral sparks
    llLinkParticleSystem(link,[PSYS_PART_FLAGS,flags,PSYS_SRC_PATTERN,pattern,
        PSYS_PART_START_COLOR,c1,PSYS_PART_END_COLOR,c2,
        PSYS_PART_START_ALPHA,0.85,PSYS_PART_END_ALPHA,0.0,
        PSYS_PART_START_SCALE,<0.11,0.11,0>,PSYS_PART_END_SCALE,<0.02,0.02,0>,
        PSYS_PART_MAX_AGE,1.8/effectSpeed,PSYS_SRC_MAX_AGE,0.0,
        PSYS_SRC_BURST_RATE,clampf(burst,0.02,1.0),PSYS_SRC_BURST_PART_COUNT,2,
        PSYS_SRC_BURST_SPEED_MIN,speed*0.5,PSYS_SRC_BURST_SPEED_MAX,speed,
        PSYS_SRC_ACCEL,accel,PSYS_SRC_ANGLE_BEGIN,0.0,PSYS_SRC_ANGLE_END,0.35,
        PSYS_SRC_OMEGA,<0,0,rotationSpeed>]);
}

refreshParticles()
{ integer i; for(i=1;i<=LINKS;++i) particles(i,(i-1)%4); }

animate(float dt)
{
    phaseClock += dt*effectSpeed;
    integer i;
    for(i=0;i<LINKS;++i)
    {
        vector p=llList2Vector(targetPos,i); rotation r=llList2Rot(targetRot,i);
        vector sz=llList2Vector(targetSize,i); float pulse=0.5+0.5*llSin(phaseClock*2.0+(float)i);
        if(mode==1 || mode==3)
        {
            if(shape==0 && i>=5) r=r*euler(<0,0,phaseClock*rotationSpeed*35.0>);
            else if(shape==1) { p.z += 0.15*llSin(phaseClock*2.0-(float)i*0.65); p.x += 0.08*llSin(phaseClock-(float)i*0.3); }
            else if(shape==2 && i>=10 && i<=14) r=r*euler(<12.0*pulse,0,0>);
            else if(shape==3) sz *= 0.88+0.20*pulse;
        }
        setGeometry(i+1,p,r,sz,bodyAlpha);
        llSetLinkPrimitiveParamsFast(i+1,[PRIM_GLOW,ALL_SIDES,clampf(bodyGlow+0.12*pulse,0,1)]);
    }
}

returnHome()
{
    vector here=llGetPos(); vector delta=homePos-here; float d=llVecMag(delta);
    if(d>10.0) delta=llVecNorm(delta)*10.0; // hard roaming limit per invocation
    llSetRegionPos(here+delta); llSetRot(homeRot);
}

dialog(string p)
{
    page=p; list b; string msg="Infernal Reliquary\n";
    if(p=="MAIN") b=["Shape","Theme","Motion","Aura","Glow/Alpha","Assets","Save/Load","Home"];
    else if(p=="SHAPE") b=["Pentagram","Serpent","Demon Mask","Portal","Shape Cycle","Back"];
    else if(p=="MOTION") { msg+="Effect "+(string)effectSpeed+" | Rotation "+(string)rotationSpeed+" | Transition "+(string)transitionTime+"s"; b=["Display","Animate","Absorb","Release","FX -","FX +","Rot -","Rot +","Time -","Time +","Back"]; }
    else if(p=="THEME") b=["Named Colors","Body Palette","Particle Pal","Back"];
    else if(p=="COLORS") b=["Violet","Crimson","Emerald","Spectral","Back"];
    else if(p=="AURA") b=["Violet Trail","Crimson Ember","Emerald Mist","White Sparks","Aura Off","Aura On","Back"];
    else if(p=="GLOW") b=["Glow -","Glow +","Alpha -","Alpha +","Back"];
    else if(p=="ASSET") b=["Auto Detect","Texture UUID","Sound UUID","Clear Texture","Clear Sound","Back"];
    else if(p=="STORE") b=["Save","Load","Set Home","Go Home","Back"];
    llDialog(menuUser,msg,b,DIALOG);
}

setNamed(string name, integer particlesOnly)
{
    vector c=<0.65,0.05,1>;
    if(name=="Crimson") c=<0.85,0.02,0.03>;
    else if(name=="Emerald") c=<0.02,0.65,0.18>;
    else if(name=="Spectral") c=<0.92,0.96,1.0>;
    if(particlesOnly) particleColor=c; else bodyColor=c;
}

default
{
    state_entry()
    {
        if(llGetNumberOfPrims()!=LINKS)
        { llOwnerSay("This installation requires exactly 19 linked prims; found "+(string)llGetNumberOfPrims()+"."); return; }
        DIALOG=-100000-(integer)llFrand(900000000.0);
        listenHandle=llListen(DIALOG,"",NULL_KEY,"");
        loadSettings(); detectAssets(); buildShape(shape); snapshot();
        // Start through the same no-snap pipeline used by every later selection.
        transitionClock=0; transitionPhase=1; refreshParticles(); llSetTimerEvent(0.08);
    }

    changed(integer c)
    {
        if(c&CHANGED_LINK) llResetScript();
        if(c&CHANGED_INVENTORY) { detectAssets(); refreshParticles(); }
    }

    touch_start(integer n)
    {
        menuUser=llDetectedKey(0); if(llGetNumberOfPrims()!=LINKS) return; dialog("MAIN");
    }

    timer()
    {
        // The installation may be repositioned, but never farther than ten
        // metres from its persisted home anchor.
        vector offset=llGetPos()-homePos;
        if(llVecMag(offset)>10.0) llSetRegionPos(homePos+llVecNorm(offset)*10.0);
        if(transitionPhase) transitionStep(0.08);
        else animate(0.08);
    }

    listen(integer channel,string name,key id,string m)
    {
        if(id!=menuUser) return;
        if(page=="TEXTURE_INPUT") { if((key)m) textureID=m; saveSettings(); beginTransition(shape); dialog("ASSET"); return; }
        if(page=="SOUND_INPUT") { if((key)m) soundID=m; saveSettings(); dialog("ASSET"); return; }
        if(m=="Back") { dialog("MAIN"); return; }
        if(m=="Shape") dialog("SHAPE"); else if(m=="Theme") dialog("THEME");
        else if(m=="Motion") dialog("MOTION"); else if(m=="Aura") dialog("AURA");
        else if(m=="Glow/Alpha") dialog("GLOW"); else if(m=="Assets") dialog("ASSET");
        else if(m=="Save/Load") dialog("STORE"); else if(m=="Home") returnHome();
        else if(m=="Pentagram") beginTransition(0); else if(m=="Serpent") beginTransition(1);
        else if(m=="Demon Mask") beginTransition(2); else if(m=="Portal") beginTransition(3);
        else if(m=="Shape Cycle") beginTransition((shape+1)%4);
        else if(m=="Display") { mode=0; refreshParticles(); dialog("MOTION"); }
        else if(m=="Animate") { mode=1; refreshParticles(); dialog("MOTION"); }
        else if(m=="Absorb") { mode=2; snapshot(); buildShape(shape); transitionPhase=1; transitionClock=0; refreshParticles(); dialog("MOTION"); }
        else if(m=="Release") { mode=3; beginTransition(shape); refreshParticles(); dialog("MOTION"); }
        else if(m=="FX -") { effectSpeed=clampf(effectSpeed-0.25,0.25,3); refreshParticles(); dialog("MOTION"); }
        else if(m=="FX +") { effectSpeed=clampf(effectSpeed+0.25,0.25,3); refreshParticles(); dialog("MOTION"); }
        else if(m=="Rot -") { rotationSpeed=clampf(rotationSpeed-0.25,0,4); dialog("MOTION"); }
        else if(m=="Rot +") { rotationSpeed=clampf(rotationSpeed+0.25,0,4); dialog("MOTION"); }
        else if(m=="Time -") { transitionTime=clampf(transitionTime-1,3,15); dialog("MOTION"); }
        else if(m=="Time +") { transitionTime=clampf(transitionTime+1,3,15); dialog("MOTION"); }
        else if(m=="Named Colors") { dialog("COLORS"); }
        else if(m=="Body Palette") { paletteTarget=0; dialog("COLORS"); }
        else if(m=="Particle Pal") { paletteTarget=1; dialog("COLORS"); }
        else if(m=="Violet"||m=="Crimson"||m=="Emerald"||m=="Spectral")
        { setNamed(m,paletteTarget); if(paletteTarget) refreshParticles(); else beginTransition(shape); dialog("COLORS"); }
        else if(m=="Violet Trail") { particleColor=<.65,.05,1>; refreshParticles(); dialog("AURA"); }
        else if(m=="Crimson Ember") { particleColor=<1,.03,0>; refreshParticles(); dialog("AURA"); }
        else if(m=="Emerald Mist") { particleColor=<.02,.7,.2>; refreshParticles(); dialog("AURA"); }
        else if(m=="White Sparks") { particleColor=<1,1,1>; refreshParticles(); dialog("AURA"); }
        else if(m=="Aura Off") { integer i; for(i=1;i<=LINKS;++i) llLinkParticleSystem(i,[]); dialog("AURA"); }
        else if(m=="Aura On") { refreshParticles(); dialog("AURA"); }
        else if(m=="Glow -") { bodyGlow=clampf(bodyGlow-.05,0,1); dialog("GLOW"); }
        else if(m=="Glow +") { bodyGlow=clampf(bodyGlow+.05,0,1); dialog("GLOW"); }
        else if(m=="Alpha -") { bodyAlpha=clampf(bodyAlpha-.1,.1,1); dialog("GLOW"); }
        else if(m=="Alpha +") { bodyAlpha=clampf(bodyAlpha+.1,.1,1); dialog("GLOW"); }
        else if(m=="Auto Detect") { detectAssets(); beginTransition(shape); dialog("ASSET"); }
        else if(m=="Texture UUID") { page="TEXTURE_INPUT"; llTextBox(menuUser,"Paste a texture UUID:",DIALOG); }
        else if(m=="Sound UUID") { page="SOUND_INPUT"; llTextBox(menuUser,"Paste a sound UUID:",DIALOG); }
        else if(m=="Clear Texture") { textureID=TEXTURE_BLANK; beginTransition(shape); dialog("ASSET"); }
        else if(m=="Clear Sound") { soundID=""; dialog("ASSET"); }
        else if(m=="Save") { saveSettings(); dialog("STORE"); }
        else if(m=="Load") { loadSettings(); beginTransition(shape); refreshParticles(); dialog("STORE"); }
        else if(m=="Set Home") { homePos=llGetPos(); homeRot=llGetRot(); saveSettings(); dialog("STORE"); }
        else if(m=="Go Home") { returnHome(); dialog("STORE"); }
    }
}

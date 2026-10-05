// Fantasy Plant Care Simulator
// Complete Mono-compatible LSL for one unlinked plant object or ordinary prim.
// Touch the plant as its owner to open the menus. No inventory assets are required.

string PREFIX = "FPCS:";
integer MENU_CHANNEL;
integer listenHandle;
integer inputMode;                 // 1 = particle UUID text box
key owner;

float water = 80.0;
float lightLevel = 80.0;
float food = 80.0;
float growth = 0.0;
float waterRate = 2.0;             // points lost per hour
float lightRate = 1.5;
float foodRate = 1.0;
integer lastUpdate;
integer lastReminder;
integer restUntil;
integer recovery;
integer stage;
vector baseSize;
vector chosenColor = <0.35, 0.85, 0.30>;
float chosenGlow = 0.05;
string particleTexture = "";
string waterSound = "";
string feedSound = "";
string restSound = "";
integer effectUntil;
integer MAX_OFFLINE = 604800;      // cap unattended decay at seven days

list STAGE_NAMES = ["Seedling", "Sprout", "Budding", "Flowering"];
list STAGE_SCALE = [0.70, 0.95, 1.20, 1.45];
list COLOR_NAMES = ["Leaf Green", "Emerald", "Moon Blue", "Sun Gold", "Rose", "Lavender", "Frost", "Autumn"];
list COLOR_VALUES = [<0.35,0.85,0.30>, <0.10,0.70,0.38>, <0.30,0.58,1.00>, <1.00,0.78,0.20>, <1.00,0.38,0.55>, <0.70,0.48,1.00>, <0.72,0.92,1.00>, <0.95,0.43,0.12>];

float clamp(float value, float low, float high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

string readData(string name, string fallback)
{
    string value = llLinksetDataRead(PREFIX + name);
    if (value == "") return fallback;
    return value;
}

save()
{
    llLinksetDataWrite(PREFIX + "water", (string)water);
    llLinksetDataWrite(PREFIX + "light", (string)lightLevel);
    llLinksetDataWrite(PREFIX + "food", (string)food);
    llLinksetDataWrite(PREFIX + "growth", (string)growth);
    llLinksetDataWrite(PREFIX + "rates", (string)waterRate + "," + (string)lightRate + "," + (string)foodRate);
    llLinksetDataWrite(PREFIX + "time", (string)lastUpdate);
    llLinksetDataWrite(PREFIX + "reminder", (string)lastReminder);
    llLinksetDataWrite(PREFIX + "rest", (string)restUntil);
    llLinksetDataWrite(PREFIX + "base", (string)baseSize);
    llLinksetDataWrite(PREFIX + "color", (string)chosenColor);
    llLinksetDataWrite(PREFIX + "glow", (string)chosenGlow);
    llLinksetDataWrite(PREFIX + "particle", particleTexture);
}

discoverAssets()
{
    // Exact conventional names are preferred; otherwise the first asset of each type is used.
    integer i;
    integer count = llGetInventoryNumber(INVENTORY_TEXTURE);
    for (i = 0; i < count; ++i)
    {
        string n = llGetInventoryName(INVENTORY_TEXTURE, i);
        if (particleTexture == "" || llToLower(n) == "plant particle") particleTexture = n;
    }
    count = llGetInventoryNumber(INVENTORY_SOUND);
    for (i = 0; i < count; ++i)
    {
        string s = llGetInventoryName(INVENTORY_SOUND, i);
        string low = llToLower(s);
        if (waterSound == "") waterSound = s;
        if (low == "water" || low == "watering") waterSound = s;
        if (low == "feed" || low == "feeding") feedSound = s;
        if (low == "rest" || low == "chime") restSound = s;
    }
}

integer calculateStage()
{
    if (growth >= 240.0) return 3;
    if (growth >= 120.0) return 2;
    if (growth >= 40.0) return 1;
    return 0;
}

particles(integer mode)
{
    // This object is the only emitter. Effects replace one another rather than stacking.
    if (mode == 0) { llParticleSystem([]); return; }
    vector color = chosenColor;
    integer flags = PSYS_PART_INTERP_COLOR_MASK | PSYS_PART_INTERP_SCALE_MASK |
        PSYS_PART_EMISSIVE_MASK | PSYS_PART_FOLLOW_VELOCITY_MASK;
    float burst = 1.2;
    vector accel = <0.0,0.0,0.08>;
    float speed = 0.10;
    if (mode == 2) // watering drops
    {
        color = <0.25,0.60,1.00>;
        burst = 0.10;
        accel = <0.0,0.0,-0.35>;
        speed = 0.45;
    }
    llParticleSystem([
        PSYS_PART_FLAGS, flags,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
        PSYS_PART_START_COLOR, color,
        PSYS_PART_END_COLOR, color,
        PSYS_PART_START_ALPHA, 0.65,
        PSYS_PART_END_ALPHA, 0.0,
        PSYS_PART_START_SCALE, <0.05,0.05,0.0>,
        PSYS_PART_END_SCALE, <0.015,0.015,0.0>,
        PSYS_PART_MAX_AGE, 1.8,
        PSYS_SRC_BURST_RATE, burst,
        PSYS_SRC_BURST_PART_COUNT, 2,
        PSYS_SRC_BURST_RADIUS, 0.20,
        PSYS_SRC_BURST_SPEED_MIN, speed * 0.5,
        PSYS_SRC_BURST_SPEED_MAX, speed,
        PSYS_SRC_ACCEL, accel,
        PSYS_SRC_MAX_AGE, 0.0,
        PSYS_SRC_TEXTURE, particleTexture
    ]);
}

applyAppearance()
{
    stage = calculateStage();
    float health = (water + lightLevel + food) / 300.0;
    integer dormant = (llGetUnixTime() < restUntil);
    float brightness = 0.35 + (0.65 * health);
    vector tint = chosenColor * brightness;
    float alpha = 1.0;
    if (dormant) alpha = 0.55;      // dormancy fade
    float factor = llList2Float(STAGE_SCALE, stage);
    // Always derive from the saved baseline: repeated updates never compound scaling.
    vector desired = baseSize * factor;
    desired.x = clamp(desired.x, 0.01, 64.0);
    desired.y = clamp(desired.y, 0.01, 64.0);
    desired.z = clamp(desired.z, 0.01, 64.0);
    llSetScale(desired);            // size only; position and rotation remain untouched
    float glow = 0.0;
    if (stage == 3 && health >= 0.65 && !dormant) glow = chosenGlow;
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_COLOR, ALL_SIDES, tint, alpha,
        PRIM_GLOW, ALL_SIDES, glow]);
    if (health >= 0.72 && !dormant && effectUntil == 0) particles(1);
    else if (effectUntil == 0) particles(0);
}

updateLevels()
{
    integer now = llGetUnixTime();
    integer elapsed = now - lastUpdate;
    if (elapsed < 0) elapsed = 0;
    if (elapsed > MAX_OFFLINE) elapsed = MAX_OFFLINE;
    float hours = (float)elapsed / 3600.0;
    integer resting = (now < restUntil);
    float multiplier = 1.0;
    if (resting) multiplier = 0.20;
    if (recovery) multiplier *= 0.50;
    water = clamp(water - waterRate * hours * multiplier, 0.0, 100.0);
    lightLevel = clamp(lightLevel - lightRate * hours * multiplier, 0.0, 100.0);
    food = clamp(food - foodRate * hours * multiplier, 0.0, 100.0);
    float health = (water + lightLevel + food) / 3.0;
    recovery = (health < 35.0);
    if (health >= 65.0 && !resting) growth = clamp(growth + hours * (health / 100.0), 0.0, 300.0);
    lastUpdate = now;
    save();
    applyAppearance();
}

string statusText()
{
    float health = (water + lightLevel + food) / 3.0;
    string condition = "Thriving";
    if (health < 25.0) condition = "Critical";
    else if (health < 45.0) condition = "Wilted";
    else if (health < 65.0) condition = "Needs care";
    else if (health < 85.0) condition = "Healthy";
    string extra = "";
    if (recovery) extra = "\nRecovery mode: active (decay halved)";
    if (llGetUnixTime() < restUntil) extra += "\nDormant/resting";
    return "Stage: " + llList2String(STAGE_NAMES, stage) +
        "\nHealth: " + condition + " (" + (string)llRound(health) + "%)" +
        "\nWater: " + (string)llRound(water) + "%" +
        " | Light: " + (string)llRound(lightLevel) + "%" +
        " | Nourishment: " + (string)llRound(food) + "%" + extra;
}

openListen()
{
    if (listenHandle) llListenRemove(listenHandle);
    listenHandle = llListen(MENU_CHANNEL, "", owner, "");
    llSetTimerEvent(30.0);
}

dialog(string message, list buttons)
{
    openListen();
    llDialog(owner, message, buttons, MENU_CHANNEL);
}

mainMenu()
{
    updateLevels();
    dialog(statusText(), ["Care", "Growth", "Decay Rates", "Appearance", "Sounds", "Reset"]);
}

playOptional(string sound)
{
    if (sound != "" && llGetInventoryType(sound) == INVENTORY_SOUND) llTriggerSound(sound, 0.8);
}

care(string action)
{
    updateLevels();
    if (action == "Water")
    {
        float amount = 32.0;
        if (recovery) amount = 45.0;
        water = clamp(water + amount, 0.0, 100.0);
        playOptional(waterSound);
        effectUntil = llGetUnixTime() + 8;
        particles(2);
    }
    else if (action == "Feed")
    {
        float amount = 28.0;
        if (recovery) amount = 40.0;
        food = clamp(food + amount, 0.0, 100.0);
        playOptional(feedSound);
    }
    else if (action == "Rest")
    {
        restUntil = llGetUnixTime() + 1800;
        lightLevel = clamp(lightLevel + 25.0, 0.0, 100.0);
        playOptional(restSound);
    }
    growth = clamp(growth + 1.5, 0.0, 300.0);
    lastUpdate = llGetUnixTime();
    recovery = (((water + lightLevel + food) / 3.0) < 35.0);
    save();
    applyAppearance();
    llOwnerSay(action + " complete. " + statusText());
}

setRatePreset(string choice)
{
    if (choice == "Gentle") { waterRate = 0.75; lightRate = 0.50; foodRate = 0.35; }
    else if (choice == "Normal") { waterRate = 2.0; lightRate = 1.5; foodRate = 1.0; }
    else if (choice == "Demanding") { waterRate = 4.0; lightRate = 3.0; foodRate = 2.0; }
    else if (choice == "No Decay") { waterRate = 0.0; lightRate = 0.0; foodRate = 0.0; }
    save();
    llOwnerSay("Decay preset: " + choice + ". Values are points per hour.");
}

default
{
    state_entry()
    {
        owner = llGetOwner();
        MENU_CHANNEL = -100000 - (integer)("0x" + llGetSubString((string)llGetKey(), -6, -1));
        string savedBase = llLinksetDataRead(PREFIX + "base");
        if (savedBase == "")
        {
            baseSize = llGetScale();
            lastUpdate = llGetUnixTime();
            lastReminder = lastUpdate;
        }
        else
        {
            baseSize = (vector)savedBase;
            water = (float)readData("water", "80");
            lightLevel = (float)readData("light", "80");
            food = (float)readData("food", "80");
            growth = (float)readData("growth", "0");
            list rates = llParseString2List(readData("rates", "2,1.5,1"), [","], []);
            waterRate = llList2Float(rates, 0);
            lightRate = llList2Float(rates, 1);
            foodRate = llList2Float(rates, 2);
            lastUpdate = (integer)readData("time", (string)llGetUnixTime());
            lastReminder = (integer)readData("reminder", (string)lastUpdate);
            restUntil = (integer)readData("rest", "0");
            chosenColor = (vector)readData("color", "<0.35,0.85,0.30>");
            chosenGlow = (float)readData("glow", "0.05");
            particleTexture = readData("particle", "");
        }
        discoverAssets();
        updateLevels();
        llSetTimerEvent(30.0);
    }

    on_rez(integer start) { llResetScript(); }

    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_INVENTORY) discoverAssets();
    }

    touch_start(integer count)
    {
        if (llDetectedKey(0) == owner) mainMenu();
        else llRegionSayTo(llDetectedKey(0), 0, "Only my owner can care for me.");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel != MENU_CHANNEL || id != owner) return;
        if (inputMode)
        {
            inputMode = 0;
            if (message == "clear" || message == "CLEAR") particleTexture = "";
            else particleTexture = message; // asset name or texture UUID
            save(); applyAppearance();
            llOwnerSay("Particle texture setting saved.");
            return;
        }
        if (message == "Care") dialog("Choose a care action. Rest creates 30 minutes of dormancy and slower decay.", ["Water", "Feed", "Rest", "Back"]);
        else if (message == "Water" || message == "Feed" || message == "Rest") { care(message); mainMenu(); }
        else if (message == "Growth") { updateLevels(); dialog(statusText() + "\nGrowth points: " + (string)llRound(growth) + "/240", ["Back"]); }
        else if (message == "Decay Rates") dialog("Choose owner-adjustable decay. Current W/L/F per hour: " + (string)waterRate + "/" + (string)lightRate + "/" + (string)foodRate, ["Gentle", "Normal", "Demanding", "No Decay", "Back"]);
        else if (~llListFindList(["Gentle", "Normal", "Demanding", "No Decay"], [message])) { updateLevels(); setRatePreset(message); mainMenu(); }
        else if (message == "Appearance") dialog("Appearance controls", ["Named Colors", "Glow", "Particle Texture/UUID", "Back"]);
        else if (message == "Named Colors") dialog("Choose a tint", COLOR_NAMES + ["Back"]);
        else if (~llListFindList(COLOR_NAMES, [message])) { chosenColor = llList2Vector(COLOR_VALUES, llListFindList(COLOR_NAMES, [message])); save(); applyAppearance(); mainMenu(); }
        else if (message == "Glow") dialog("Flowering glow strength", ["Glow Off", "Glow Low", "Glow Med", "Glow High", "Back"]);
        else if (llGetSubString(message, 0, 4) == "Glow ")
        {
            if (message == "Glow Off") chosenGlow = 0.0;
            else if (message == "Glow Low") chosenGlow = 0.03;
            else if (message == "Glow Med") chosenGlow = 0.10;
            else chosenGlow = 0.20;
            save(); applyAppearance(); mainMenu();
        }
        else if (message == "Particle Texture/UUID")
        {
            inputMode = 1; openListen();
            llTextBox(owner, "Enter an inventory texture name, a texture UUID, or CLEAR. Blank particles still work with the viewer default.", MENU_CHANNEL);
        }
        else if (message == "Sounds")
        {
            discoverAssets();
            dialog("Optional sounds are discovered automatically.\nWater: " + waterSound + "\nFeed: " + feedSound + "\nRest: " + restSound, ["Rescan", "Back"]);
        }
        else if (message == "Rescan") { discoverAssets(); llOwnerSay("Optional assets rescanned."); mainMenu(); }
        else if (message == "Reset") dialog("Reset progress and care settings? The saved original baseline size is retained.", ["CONFIRM RESET", "Back"]);
        else if (message == "CONFIRM RESET")
        {
            llLinksetDataDeleteFound(PREFIX, "");
            // Preserve the original baseline even across a progress reset.
            llLinksetDataWrite(PREFIX + "base", (string)baseSize);
            llResetScript();
        }
        else mainMenu();
    }

    timer()
    {
        updateLevels();
        integer now = llGetUnixTime();
        if (effectUntil && now >= effectUntil) { effectUntil = 0; applyAppearance(); }
        float lowest = llListStatistics(LIST_STAT_MIN, [water, lightLevel, food]);
        integer interval = 7200;
        if (recovery) interval = 1800;
        if (lowest < 35.0 && now - lastReminder >= interval)
        {
            string need = "nourishment";
            if (water <= lightLevel && water <= food) need = "water";
            else if (lightLevel <= food) need = "light/rest";
            llOwnerSay("Care reminder: I need " + need + ". " + statusText());
            lastReminder = now; save();
        }
    }
}

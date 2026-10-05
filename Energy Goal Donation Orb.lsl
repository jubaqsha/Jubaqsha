// Energy Goal Donation Orb
// One-prim, Mono-compatible donation goal display. Drop optional sounds named
// "Donation", "Milestone", and "Celebration", plus a texture named
// "Orb Particle", into the prim. Leave PARTICLE_TEXTURE_UUID empty for generic
// particles, or enter a full-permission texture UUID below.

string PARTICLE_TEXTURE_UUID = "";

string KEY_PREFIX = "energy_orb:";
integer HISTORY_LIMIT = 20;
integer LISTEN_CHANNEL;
integer listenHandle;
integer menuPage;
integer awaitingText;
key menuUser;

integer goal = 1000;
integer total = 0;
list payButtons = [10, 25, 50, 100];
vector lowColor = <0.03, 0.10, 0.35>;
vector highColor = <1.00, 0.72, 0.08>;
float maxGlow = 0.20;
float opacity = 1.0;
integer particlesOn = TRUE;
integer soundsOn = TRUE;
integer breathingOn = TRUE;
integer milestoneMask = 0;
list donorHistory;

vector baseSize;
vector originalColor;
float originalAlpha;
float originalGlow;
float breathPhase;
integer effectMode;
float effectUntil;
string particleTexture;

integer TEXT_NONE = 0;
integer TEXT_GOAL = 1;
integer TEXT_PAY = 2;
integer TEXT_LOW = 3;
integer TEXT_HIGH = 4;
integer TEXT_GLOW = 5;
integer TEXT_ALPHA = 6;

string K(string name)
{
    return KEY_PREFIX + name;
}

integer clampInt(integer value, integer low, integer high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

float clampFloat(float value, float low, float high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

string money(integer amount)
{
    return "L$" + (string)amount;
}

float progress()
{
    if (goal <= 0) return 0.0;
    return clampFloat((float)total / (float)goal, 0.0, 1.0);
}

string percentText()
{
    if (goal <= 0) return "0.0%";
    integer tenths = (integer)(((float)total * 1000.0) / (float)goal);
    return (string)(tenths / 10) + "." + (string)(tenths % 10) + "%";
}

string vectorText(vector value)
{
    return (string)value;
}

integer isVectorText(string value)
{
    value = llStringTrim(value, STRING_TRIM);
    return (llGetSubString(value, 0, 0) == "<" && llGetSubString(value, -1, -1) == ">");
}

vector namedColor(string name)
{
    if (name == "Blue") return <0.03, 0.10, 0.35>;
    if (name == "Gold") return <1.00, 0.72, 0.08>;
    if (name == "Red") return <1.00, 0.08, 0.05>;
    if (name == "Green") return <0.05, 0.80, 0.18>;
    if (name == "Purple") return <0.55, 0.08, 0.90>;
    if (name == "White") return <1.00, 1.00, 1.00>;
    return <0.0, 0.0, 0.0>;
}

save(string name, string value)
{
    llLinksetDataWrite(K(name), value);
}

saveSettings()
{
    save("goal", (string)goal);
    save("total", (string)total);
    save("pay", llList2CSV(payButtons));
    save("low", vectorText(lowColor));
    save("high", vectorText(highColor));
    save("glow", (string)maxGlow);
    save("alpha", (string)opacity);
    save("particles", (string)particlesOn);
    save("sounds", (string)soundsOn);
    save("breathing", (string)breathingOn);
    save("milestones", (string)milestoneMask);
    save("history", llList2Json(JSON_ARRAY, donorHistory));
}

loadSettings()
{
    string value = llLinksetDataRead(K("goal"));
    if (value != "") goal = (integer)value;
    value = llLinksetDataRead(K("total"));
    if (value != "") total = (integer)value;
    value = llLinksetDataRead(K("pay"));
    if (value != "") payButtons = llCSV2List(value);
    value = llLinksetDataRead(K("low"));
    if (value != "") lowColor = (vector)value;
    value = llLinksetDataRead(K("high"));
    if (value != "") highColor = (vector)value;
    value = llLinksetDataRead(K("glow"));
    if (value != "") maxGlow = (float)value;
    value = llLinksetDataRead(K("alpha"));
    if (value != "") opacity = (float)value;
    value = llLinksetDataRead(K("particles"));
    if (value != "") particlesOn = (integer)value;
    value = llLinksetDataRead(K("sounds"));
    if (value != "") soundsOn = (integer)value;
    value = llLinksetDataRead(K("breathing"));
    if (value != "") breathingOn = (integer)value;
    value = llLinksetDataRead(K("milestones"));
    if (value != "") milestoneMask = (integer)value;
    value = llLinksetDataRead(K("history"));
    if (value != "") donorHistory = llJson2List(value);
}

setPayButtons()
{
    list p = payButtons;
    while (llGetListLength(p) < 4) p += [PAY_HIDE];
    llSetPayPrice(PAY_DEFAULT, [
        (integer)llList2String(p, 0), (integer)llList2String(p, 1),
        (integer)llList2String(p, 2), (integer)llList2String(p, 3)]);
}

updateVisual()
{
    float p = progress();
    vector color = lowColor + ((highColor - lowColor) * p);
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_COLOR, ALL_SIDES, color, opacity,
        PRIM_GLOW, ALL_SIDES, maxGlow * p,
        PRIM_TEXT, money(total) + " / " + money(goal) + "  (" + percentText() + ")", color, opacity]);
}

detectAssets()
{
    particleTexture = "";
    if (llGetInventoryType("Orb Particle") == INVENTORY_TEXTURE)
        particleTexture = "Orb Particle";
    else if (PARTICLE_TEXTURE_UUID != "" && (key)PARTICLE_TEXTURE_UUID != NULL_KEY)
        particleTexture = PARTICLE_TEXTURE_UUID;
}

playOptional(string sound)
{
    if (soundsOn && llGetInventoryType(sound) == INVENTORY_SOUND)
        llTriggerSound(sound, 1.0);
}

stopParticles()
{
    llParticleSystem([]);
    effectMode = 0;
}

milestoneRing()
{
    if (!particlesOn) return;
    effectMode = 1;
    effectUntil = llGetTime() + 1.8;
    llParticleSystem([
        PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK | PSYS_PART_INTERP_COLOR_MASK |
            PSYS_PART_INTERP_SCALE_MASK,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE_CONE,
        PSYS_SRC_TEXTURE, particleTexture,
        PSYS_SRC_BURST_RATE, 0.08,
        PSYS_SRC_BURST_PART_COUNT, 12,
        PSYS_SRC_BURST_SPEED_MIN, 0.7,
        PSYS_SRC_BURST_SPEED_MAX, 1.0,
        PSYS_SRC_ANGLE_BEGIN, PI_BY_TWO,
        PSYS_SRC_ANGLE_END, PI_BY_TWO,
        PSYS_PART_START_COLOR, highColor,
        PSYS_PART_END_COLOR, lowColor,
        PSYS_PART_START_ALPHA, 0.9,
        PSYS_PART_END_ALPHA, 0.0,
        PSYS_PART_START_SCALE, <0.10, 0.10, 0.0>,
        PSYS_PART_END_SCALE, <0.03, 0.03, 0.0>,
        PSYS_PART_MAX_AGE, 1.2,
        PSYS_SRC_MAX_AGE, 1.5]);
}

celebrationBurst()
{
    if (!particlesOn) return;
    effectMode = 2;
    effectUntil = llGetTime() + 2.2;
    llParticleSystem([
        PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK | PSYS_PART_INTERP_COLOR_MASK |
            PSYS_PART_INTERP_SCALE_MASK | PSYS_PART_BOUNCE_MASK,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
        PSYS_SRC_TEXTURE, particleTexture,
        PSYS_SRC_BURST_RATE, 0.12,
        PSYS_SRC_BURST_PART_COUNT, 30,
        PSYS_SRC_BURST_SPEED_MIN, 1.0,
        PSYS_SRC_BURST_SPEED_MAX, 2.2,
        PSYS_PART_START_COLOR, highColor,
        PSYS_PART_END_COLOR, <1.0, 1.0, 1.0>,
        PSYS_PART_START_ALPHA, 1.0,
        PSYS_PART_END_ALPHA, 0.0,
        PSYS_PART_START_SCALE, <0.12, 0.12, 0.0>,
        PSYS_PART_END_SCALE, <0.02, 0.02, 0.0>,
        PSYS_PART_MAX_AGE, 1.8,
        PSYS_SRC_ACCEL, <0.0, 0.0, -0.7>,
        PSYS_SRC_MAX_AGE, 1.8]);
}

checkMilestones(integer oldTotal)
{
    integer i;
    list marks = [25, 50, 75, 100];
    for (i = 0; i < 4; ++i)
    {
        integer mark = llList2Integer(marks, i);
        integer bit = 1 << i;
        if (!(milestoneMask & bit) && oldTotal * 100 < goal * mark && total * 100 >= goal * mark)
        {
            milestoneMask = milestoneMask | bit;
            if (mark == 100)
            {
                celebrationBurst();
                playOptional("Celebration");
            }
            else
            {
                milestoneRing();
                playOptional("Milestone");
            }
        }
    }
}

openListen(key user)
{
    if (listenHandle) llListenRemove(listenHandle);
    LISTEN_CHANNEL = -1000000 - (integer)llFrand(1000000000.0);
    listenHandle = llListen(LISTEN_CHANNEL, "", user, "");
    menuUser = user;
    llSetTimerEvent(0.05);
}

mainMenu()
{
    menuPage = 0;
    llDialog(menuUser, "Energy Goal Donation Orb\n" + money(total) + " of " + money(goal) +
        " (" + percentText() + ")", ["Payments", "Goal", "Progress Colors", "Glow", "Opacity",
        "Particles", "Sounds", "Statistics", "Reset"], LISTEN_CHANNEL);
}

colorMenu()
{
    menuPage = 3;
    llDialog(menuUser, "Choose which endpoint to edit.",
        ["Low Color", "High Color", "Back"], LISTEN_CHANNEL);
}

colorChoices(integer high)
{
    menuPage = 30 + high;
    string which = "low-progress";
    if (high) which = "goal";
    llDialog(menuUser, "Choose the " + which + " color.",
        ["Blue", "Gold", "Red", "Green", "Purple", "White", "Custom RGB", "Back"], LISTEN_CHANNEL);
}

statistics()
{
    string history = "No donations recorded.";
    integer count = llGetListLength(donorHistory) / 3;
    if (count)
    {
        history = "Recent donations (newest first):";
        integer i;
        integer shown = count;
        if (shown > 8) shown = 8;
        for (i = 0; i < shown; ++i)
        {
            integer x = i * 3;
            history += "\n" + llList2String(donorHistory, x + 2) + " — " +
                money(llList2Integer(donorHistory, x + 1));
        }
    }
    llDialog(menuUser, "Total: " + money(total) + "\nGoal: " + money(goal) +
        "\nProgress: " + percentText() + "\n\n" + history, ["Back"], LISTEN_CHANNEL);
    menuPage = 8;
}

askText(integer mode, string prompt)
{
    awaitingText = mode;
    llTextBox(menuUser, prompt, LISTEN_CHANNEL);
}

handleColor(string choice, integer high)
{
    if (choice == "Back")
    {
        colorMenu();
        return;
    }
    if (choice == "Custom RGB")
    {
        if (high) askText(TEXT_HIGH, "Enter RGB as <0.0, 0.0, 0.0> through <1.0, 1.0, 1.0>.");
        else askText(TEXT_LOW, "Enter RGB as <0.0, 0.0, 0.0> through <1.0, 1.0, 1.0>.");
        return;
    }
    vector color = namedColor(choice);
    if (high) highColor = color;
    else lowColor = color;
    saveSettings();
    updateVisual();
    colorChoices(high);
}

restoreOriginal()
{
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_SIZE, baseSize,
        PRIM_COLOR, ALL_SIDES, originalColor, originalAlpha,
        PRIM_GLOW, ALL_SIDES, originalGlow,
        PRIM_TEXT, "", ZERO_VECTOR, 0.0]);
    llParticleSystem([]);
}

factoryReset()
{
    restoreOriginal();
    llLinksetDataDeleteFound(K(""), "");
    goal = 1000;
    total = 0;
    payButtons = [10, 25, 50, 100];
    lowColor = <0.03, 0.10, 0.35>;
    highColor = <1.00, 0.72, 0.08>;
    maxGlow = 0.20;
    opacity = 1.0;
    particlesOn = TRUE;
    soundsOn = TRUE;
    breathingOn = TRUE;
    milestoneMask = 0;
    donorHistory = [];
    save("base_size", (string)baseSize);
    save("original_color", (string)originalColor);
    save("original_alpha", (string)originalAlpha);
    save("original_glow", (string)originalGlow);
    saveSettings();
    setPayButtons();
    updateVisual();
}

default
{
    state_entry()
    {
        string storedSize = llLinksetDataRead(K("base_size"));
        if (storedSize == "")
        {
            baseSize = llGetScale();
            originalColor = llList2Vector(llGetLinkPrimitiveParams(LINK_THIS,
                [PRIM_COLOR, 0]), 0);
            originalAlpha = llList2Float(llGetLinkPrimitiveParams(LINK_THIS,
                [PRIM_COLOR, 0]), 1);
            originalGlow = llList2Float(llGetLinkPrimitiveParams(LINK_THIS,
                [PRIM_GLOW, 0]), 0);
            save("base_size", (string)baseSize);
            save("original_color", (string)originalColor);
            save("original_alpha", (string)originalAlpha);
            save("original_glow", (string)originalGlow);
            saveSettings();
        }
        else
        {
            baseSize = (vector)storedSize;
            originalColor = (vector)llLinksetDataRead(K("original_color"));
            originalAlpha = (float)llLinksetDataRead(K("original_alpha"));
            originalGlow = (float)llLinksetDataRead(K("original_glow"));
            loadSettings();
        }
        detectAssets();
        setPayButtons();
        llSetClickAction(CLICK_ACTION_PAY);
        updateVisual();
        llSetTimerEvent(0.05);
    }

    on_rez(integer start)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if (change & (CHANGED_OWNER | CHANGED_LINK)) llResetScript();
        if (change & CHANGED_INVENTORY) detectAssets();
    }

    touch_start(integer detected)
    {
        key user = llDetectedKey(0);
        if (user != llGetOwner())
        {
            llRegionSayTo(user, 0, "Goal progress: " + money(total) + " of " + money(goal) +
                " (" + percentText() + "). Right-click and choose Pay to donate.");
            return;
        }
        openListen(user);
        mainMenu();
    }

    money(key donor, integer amount)
    {
        integer oldTotal = total;
        total += amount;
        string donorName = llGetDisplayName(donor);
        if (donorName == "") donorName = llKey2Name(donor);
        donorHistory = [llGetUnixTime(), amount, donorName] + donorHistory;
        donorHistory = llList2List(donorHistory, 0, HISTORY_LIMIT * 3 - 1);
        checkMilestones(oldTotal);
        saveSettings();
        updateVisual();
        playOptional("Donation");
        llRegionSayTo(donor, 0, "Thank you for your donation of " + money(amount) +
            "! The goal is now " + percentText() + " complete.");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (id != menuUser || channel != LISTEN_CHANNEL) return;

        if (awaitingText)
        {
            integer mode = awaitingText;
            awaitingText = TEXT_NONE;
            message = llStringTrim(message, STRING_TRIM);
            if (mode == TEXT_GOAL)
            {
                integer value = (integer)message;
                if (value > 0)
                {
                    goal = value;
                    milestoneMask = 0;
                    checkMilestones(0);
                }
                else llRegionSayTo(id, 0, "Goal must be a positive whole number.");
            }
            else if (mode == TEXT_PAY)
            {
                list values = llCSV2List(message);
                if (llGetListLength(values) == 4)
                {
                    integer valid = TRUE;
                    integer i;
                    for (i = 0; i < 4; ++i)
                        if ((integer)llList2String(values, i) <= 0) valid = FALSE;
                    if (valid) payButtons = values;
                    else llRegionSayTo(id, 0, "All four payment amounts must be positive whole numbers.");
                }
                else llRegionSayTo(id, 0, "Enter exactly four comma-separated amounts.");
                setPayButtons();
            }
            else if (mode == TEXT_GLOW)
                maxGlow = clampFloat((float)message, 0.0, 1.0);
            else if (mode == TEXT_ALPHA)
                opacity = clampFloat((float)message, 0.0, 1.0);
            else if (mode == TEXT_LOW || mode == TEXT_HIGH)
            {
                if (isVectorText(message))
                {
                    vector c = (vector)message;
                    c.x = clampFloat(c.x, 0.0, 1.0);
                    c.y = clampFloat(c.y, 0.0, 1.0);
                    c.z = clampFloat(c.z, 0.0, 1.0);
                    if (mode == TEXT_LOW) lowColor = c;
                    else highColor = c;
                }
                else llRegionSayTo(id, 0, "RGB was not recognized; use a vector such as <0.2, 0.4, 1.0>.");
            }
            saveSettings();
            updateVisual();
            mainMenu();
            return;
        }

        if (message == "Back")
        {
            mainMenu();
            return;
        }
        if (menuPage == 30 || menuPage == 31)
        {
            handleColor(message, menuPage - 30);
            return;
        }
        if (menuPage == 3)
        {
            if (message == "Low Color") colorChoices(FALSE);
            else if (message == "High Color") colorChoices(TRUE);
            return;
        }
        if (menuPage == 9)
        {
            if (message == "CONFIRM RESET")
            {
                factoryReset();
                llRegionSayTo(id, 0, "Donation orb reset; its baseline size and original appearance were restored before defaults were applied.");
            }
            mainMenu();
            return;
        }
        if (menuPage == 5)
        {
            if (message == "Particles On") particlesOn = TRUE;
            else if (message == "Particles Off")
            {
                particlesOn = FALSE;
                stopParticles();
            }
            else if (message == "Preview Ring") milestoneRing();
            else if (message == "Preview Burst") celebrationBurst();
            saveSettings();
            mainMenu();
            return;
        }
        if (menuPage == 6)
        {
            if (message == "Sounds On") soundsOn = TRUE;
            else if (message == "Sounds Off") soundsOn = FALSE;
            saveSettings();
            mainMenu();
            return;
        }

        if (message == "Payments") askText(TEXT_PAY, "Enter four positive L$ pay-button amounts, separated by commas.");
        else if (message == "Goal") askText(TEXT_GOAL, "Enter a positive whole-number donation goal in L$.");
        else if (message == "Progress Colors") colorMenu();
        else if (message == "Glow") askText(TEXT_GLOW, "Enter maximum glow from 0.0 to 1.0.");
        else if (message == "Opacity") askText(TEXT_ALPHA, "Enter opacity from 0.0 to 1.0.");
        else if (message == "Particles")
        {
            menuPage = 5;
            llDialog(id, "Particle effects are " + llList2String(["OFF", "ON"], particlesOn) + ".",
                ["Particles On", "Particles Off", "Preview Ring", "Preview Burst", "Back"], LISTEN_CHANNEL);
        }
        else if (message == "Sounds")
        {
            menuPage = 6;
            llDialog(id, "Optional inventory sounds are " + llList2String(["OFF", "ON"], soundsOn) + ".",
                ["Sounds On", "Sounds Off", "Back"], LISTEN_CHANNEL);
        }
        else if (message == "Statistics") statistics();
        else if (message == "Reset")
        {
            menuPage = 9;
            llDialog(id, "Reset total, history, milestones, and all settings?", ["CONFIRM RESET", "Back"], LISTEN_CHANNEL);
        }
    }

    timer()
    {
        if (breathingOn)
        {
            breathPhase += 0.10;
            float factor = 1.0 + 0.025 * llSin(breathPhase);
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_SIZE, baseSize * factor]);
        }
        else if (llGetScale() != baseSize)
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_SIZE, baseSize]);

        if (effectMode && llGetTime() >= effectUntil) stopParticles();
    }
}

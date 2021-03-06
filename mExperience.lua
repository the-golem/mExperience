--addon local variables
local bg, normal, rested, text, db;
local XP_FMT_STRING = "XP  %d / %d  (%d%%)"
local XP_REST_FMT_STRING = "XP  %d / %d  (%d%%)  [+%d%% Rest]"
-- lib local variables
local L = LibStub("AceLocale-3.0"):GetLocale("mExperience");
local LSM = LibStub('LibSharedMedia-3.0')

--
local mExperience = LibStub("AceAddon-3.0"):NewAddon("mExperience", "AceEvent-3.0");
local mXP = CreateFrame("Frame", "mExperienceBaseFrame", UIParent);

function mExperience:OnInitialize()
    -- mExperience Default Settings
    ------------------------------
    self:RegisterDefaults();

    -- mExperience Options Table
    -----------------------------
    self:RegisterOptions();

    -- LibDataBroker Launcher
    ---------------------------
    self:RegisterLauncher();

    -- create the frame
    ---------------------------
    mXP:Load();
end

function mXP:Load()
    self:SetFrameStrata("BACKGROUND");
    self:SetFrameLevel("0");
    self:SetClampedToScreen(true);
    self:EnableMouse(true)

    bg = self:CreateTexture(nil, "BACKGROUND");
    bg:SetAllPoints();

    rested = CreateFrame("StatusBar", nil, mXP);

    rested:SetFrameLevel("1")
    rested:SetAllPoints();

    normal = CreateFrame("StatusBar", nil, mXP);
    normal:SetFrameLevel("2")
    normal:SetAllPoints();

    text = normal:CreateFontString();
    text:SetPoint("CENTER");
end

function mExperience:OnEnable()
    self:RegisterEvent('UPDATE_EXHAUSTION', "UpdateExperience");
    self:RegisterEvent('PLAYER_XP_UPDATE', "UpdateExperience");
    self:RegisterEvent('PLAYER_LEVEL_UP', "UpdateExperience");

    self:UpdateBarSettings()
    self:UpdateExperience()
end

function mExperience:RegisterDefaults()
    local defaults = {
        profile = {
            scale = 1,
            alpha = 1,
            width =  500,
            height = 12,
            locked = true,

            anchor = "BOTTOM",
            xOffset = 0,
            yOffset = 100,

            texture = "Blizzard",
            normalColor = { r = 0.7, g = 0, b = 0.7, a = 1, },
            restedColor = { r = 0, g = 0.45, b = 1, a = 0.25, },

            fontName = "Friz Quadrata TT",
            fontSize = 10,
            fontOutline = "OUTLINE",
            alwaysShowText = true,
            showTextOnHover = true,
        },
    };
    self.db = LibStub("AceDB-3.0"):New("mExperienceDB", defaults, true);
    db = self.db;
end

function mExperience:RegisterOptions()
    local LSM = LibStub('LibSharedMedia-3.0')
    local config = LibStub("AceConfig-3.0");
    local dialog = LibStub("AceConfigDialog-3.0");
    local options = {
        name = "mExperience",
        desc = L["A configurable alternate XP bar."],
        type = "group",
        set = function(info, value) db.profile[info[#info]] = value; mExperience:UpdateBarSettings() end,
        get = function(info) return db.profile[info[#info]] end,
        args = {
            locked = {
                name = L["Locked"],
                type = "toggle", order = 50,
            },
            hSizePosition = { name = L["Size and Position"], type = "header", order = 100 },
            width = {
                name = L["Width"],
                type = "range", order = 110,
                min = 100, max = 2000,
                step = 1, bigStep = 10,
            },
            height = {
                name = L["Height"],
                type = "range", order = 120,
                min = 2, max = 50,
                step = 1,
            },
             xOffset = {
                name = L["X Position"],
                type = "range", order = 130,
                step = 0.5, bigStep = 10,
                min =  -500, max =  500,
                disabled = function() return not db.profile.locked end,
            },
            yOffset = {
                name = L["Y Position"],
                type = "range", order = 140,
                step = 0.5, bigStep = 10,
                min =  -500, max =  500,
                disabled = function() return not db.profile.locked end,
            },
            anchor = {
                name = L["Anchor Point"],
                type = "select", order = 150,
                values = {
                    ["CENTER"] = L["Center"],
                    ["LEFT"] = L["Left"],
                    ["RIGHT"] = L["Right"],
                    ["BOTTOM"] = L["Bottom"],
                    ["TOP"] = L["Top"],
                    ["TOPLEFT"] = L["Top Left"],
                    ["TOPRIGHT"] = L["Top Right"],
                    ["BOTTOMLEFT"] = L["Bottom Left"],
                    ["BOTTOMRIGHT"] = L["Bottom Right"],
                },
                disabled = function() return not db.profile.locked end,
            },

            hColor = { name = L["Color and Appearance Options"], type = "header", order = 170 },
            normal = {
                name = L["Normal XP Color"],
                type = "color",
                hasAlpha = false,
                order = 180,
                set = function(info, r, g, b, a)
                    local c = db.profile.normalColor;
                    c.r, c.g, c.b, c.a = r, g, b, a or 1;
                    mExperience:UpdateBarSettings()
                end,
                get = function()
                    local c = db.profile.normalColor;
                    return c.r, c.g, c.b, c.a;
                end,
            },
            rest = {
                name = L["Rest XP Color"],
                type = "color",
                hasAlpha = true,
                order = 190,
                set = function(info, r, g, b, a)
                    if a < 0.25 then a = 0.25 end;
                    local c = db.profile.restedColor;
                    c.r, c.g, c.b, c.a = r, g, b, a;
                    mExperience:UpdateBarSettings()
                end,
                get = function()
                    local c = db.profile.restedColor;
                    return c.r, c.g, c.b, c.a;
                end,
            },
            alpha = {
                name = L["Bar Transparency"],
                type = "range",
                min = 0.1, max =  1,
                step = 0.01, bigStep = 0.05,
                isPercent = true,
                order = 200,
            },
            scale = {
                name = L["Bar Scale"],
                type = "range",
                min = 0.25, max =  2,
                step = 0.01, bigStep = 0.05,
                isPercent = true,
                order = 210,
            },
            isRestForNormal = {
                name = L["Swap Rest Color for Normal Color"],
                desc = L["Colors will only be swapped if there is any rest xp. This emulates the default experience bar."],
                type = "toggle", order = 215,
                width = "double",
            },
            texture = {
                name = L["XP Bar Texture"],
                type = "select",
                dialogControl = 'LSM30_Statusbar', --Select your widget here
                values = LSM:HashTable("statusbar"),
                order = 220,
            },

            hFont = { name = L["Font Options"], type = "header", order = 230 },
            alwaysShowText = {
                name = L["Always Show XP Text"],
                type = "toggle",
                order = 240,
                },
            showTextOnHover = {
                name = L["Show Text on Hover"],
                type = "toggle",
                order = 245,
                disabled = function() return db.profile.alwaysShowText end,
                },
            fontName = {
                name = L["Font Face"],
                type = "select",
                dialogControl = 'LSM30_Font', --Select your widget here
                order = 250,
                values = LSM:HashTable("font"),
                disabled = function() return not db.profile.alwaysShowText end,
            },
            fontSize = {
                name = L["Font Size"],
                type = "range",
                order = 260,
                step = 1,
                min = 6, max = 48,
                disabled = function() return not db.profile.alwaysShowText end,
            },
            fontOutline = {
                name = L["Font Outline"],
                type = "select",
                order = 270,
                    values = {
                        [""] = L["None"],
                        ["OUTLINE"] = L["Outline"],
                        ["THICKOUTLINE"] = L["Thick Outline"]},
                disabled = function() return not db.profile.alwaysShowText end,
            },
        },
    };
    config:RegisterOptionsTable("mExperience", options )
    dialog:AddToBlizOptions("mExperience", "mExperience")
        _G["SLASH_MXP1"] = "/mxp"
        _G["SLASH_MXP2"] = "/mexp"
        _G["SLASH_MXP3"] = "/mexperience"
        _G.SlashCmdList["MXP"] = function() InterfaceOptionsFrame_OpenToCategory("mExperience") end
end

function mExperience:RegisterLauncher()
    local mDateBlock = LibStub("LibDataBroker-1.1"):NewDataObject("mExperience", {
        type = "launcher",
        icon = "Interface\\Icons\\Achievement_PVP_A_15",
        text = "mExperience",

        OnClick = function(self, button)
            if button == "LeftButton" then
                InterfaceOptionsFrame_OpenToCategory("mExperience")
            end
        end,
    })
end

function mExperience:UpdateColors()
    if ( db.profile.isRestForNormal and GetXPExhaustion() ) then
        normal:SetStatusBarColor( db.profile.restedColor.r,
                                  db.profile.restedColor.g,
                                  db.profile.restedColor.b,
                                  db.profile.normalColor.a
                                );

    else
        normal:SetStatusBarColor( db.profile.normalColor.r,
                                  db.profile.normalColor.g,
                                  db.profile.normalColor.b,
                                  db.profile.normalColor.a
                                );
    end;
        rested:SetStatusBarColor( db.profile.restedColor.r,
                                  db.profile.restedColor.g,
                                  db.profile.restedColor.b,
                                  db.profile.restedColor.a
                                );
end

function mExperience:UpdateExperience()
    local max = UnitXPMax("player");
    local norm = UnitXP("player");
    local rest = GetXPExhaustion() or 0;
    local pct = math.floor(100*(norm/max)+0.5);
    local restPct = math.floor(100*(rest/max)+0.5);

    rested:SetMinMaxValues(0, max);
    rested:SetValue(norm+rest);

    normal:SetMinMaxValues(0, max);
    normal:SetValue(norm);

    --update numerical XP display
    ---------------------------
    if rest == nil then
        text:SetFormattedText(XP_REST_FMT_STRING, norm, max, pct, restPct);
    else
        text:SetFormattedText(XP_FMT_STRING, norm, max, pct);
    end
    --update colors if necessary
    ---------------------------
    mExperience:UpdateColors();

    rested:GetStatusBarTexture():SetTexCoord(0, (norm+rest > max and 1 or (norm+rest)/max), 0, 1)
    normal:GetStatusBarTexture():SetTexCoord(0, pct/100, 0, 1)
end

function mExperience:UpdateText()
    local name = LSM:Fetch("font", db.profile.fontName);
    text:SetFont(name, db.profile.fontSize, db.profile.fontOutline);

    --- Always Show XP Text
    ---------------------------
    if db.profile.alwaysShowText then text:Show() else text:Hide(); end

    --- Hide XP Text, but Show on Hover
    ---------------------------
    if db.profile.showTextOnHover and not db.profile.alwaysShowText then
        mXP:SetScript("OnEnter", function() if not db.profile.alwaysShowText then text:Show() else return end end);
        mXP:SetScript("OnLeave", function() if not db.profile.alwaysShowText then text:Hide() else return end end);
    end;
end

function mExperience:UpdateTexture()
    local texture = (LSM and LSM:Fetch('statusbar', db.profile.texture)) or DEFAULT_STATUSBAR_TEXTURE
    normal:SetStatusBarTexture(texture)
    rested:SetStatusBarTexture(texture)
    bg:SetTexture(texture)
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
end

function mExperience:UpdateLayout()
    mXP:SetWidth(db.profile.width);
    mXP:SetHeight(db.profile.height);
    mXP:ClearAllPoints();
    mXP:SetPoint(db.profile.anchor,
                      UIParent,
                      db.profile.anchor,
                      db.profile.xOffset,
                      db.profile.yOffset );
    mXP:SetAlpha(db.profile.alpha);
    mXP:SetScale(db.profile.scale);
end

function mExperience:UpdateBarSettings()	--Stuff that really only needs to be touched when some settings change.
    --Height & Width & Location
    ---------------------------
    self:UpdateLayout();
    --Texture
    ---------------------------
    self:UpdateTexture();

    --Colors
    ---------------------------
    self:UpdateColors();

    --Fonts
    ---------------------------
    self:UpdateText();

    --Redraw XP Statusbars
    ---------------------------
    normal:SetValue(0);
    rested:SetValue(0);
    self:UpdateExperience();

    --Allow for Free Postioning with the Mouse
    ------------------------------------------
    if not db.profile.locked then
        mXP:SetScript("OnMouseDown", function(self) self:SetMovable(true); self:StartMoving(); end )
        mXP:SetScript(
            "OnMouseUp",
            function(self)
                self:StopMovingOrSizing();
                db.profile.anchor,
                _,
                _,
                db.profile.xOffset,
                db.profile.yOffset = self:GetPoint();
            end
        )
    end;
end
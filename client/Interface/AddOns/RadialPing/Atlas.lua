local _, addon = ...

addon.TEXTURE_PING        = "Interface\\WarcraftXL\\RadialPing\\Textures\\uipingsystem2x.blp"
addon.TEXTURE_WHEEL       = "Interface\\WarcraftXL\\RadialPing\\Textures\\uiradialwheel.blp"

-- Per-type stroke textures (individual BLPs, no atlas crop needed)
local STROKE_DIR = "Interface\\WarcraftXL\\RadialPing\\Textures\\"
addon.STROKE_TEXTURE = {
    OnMyWay  = STROKE_DIR .. "Ping_Wheel_Icon_OnMyWay_Glow.blp",
    Attack   = STROKE_DIR .. "Ping_GroundMarker_Stroke_Attack.blp",
    Warning  = STROKE_DIR .. "Ping_GroundMarker_Stroke_Warning.blp",
    Assist   = STROKE_DIR .. "Ping_GroundMarker_Stroke_Assist.blp",
}
addon.TEXTURE_WHEEL_POINTER = STROKE_DIR .. "Radial_Wheel_Select_Pointer.blp"

local function R(width, height, left, right, top, bottom)
    return { width = width, height = height, left = left, right = right, top = top, bottom = bottom }
end

-- All coords sourced from AtlasInfo.lua in the patch MPQ.
-- TEXTURE_WHEEL entries: UIRadialWheel  1x sheet  (uiradialwheel.blp)
-- TEXTURE_PING  entries: UIPingSystem2x 2x sheet  (uipingsystem2x.blp)
addon.atlas = {
    ---------------------------------------------------------------------------
    -- Radial wheel chrome  (uiradialwheel.blp — UIRadialWheel 1x)
    ---------------------------------------------------------------------------

    -- Backgrounds
    Radial_Wheel_BG                         = R(378, 378, 0.000976562, 0.370117,    0.000976562, 0.370117),
    Radial_Wheel_BG_Small                   = R(189, 189, 0.291992,    0.476562,    0.657227,    0.841797),

    -- Frame overlays
    Radial_Wheel_Frame_Count_4              = R(378, 378, 0.37207,     0.741211,    0.000976562, 0.370117),
    Radial_Wheel_Frame_Count_4_Small        = R(189, 189, 0.577148,    0.761719,    0.37207,     0.556641),
    Radial_Wheel_Frame_CoolDown_Count_4     = R(188, 188, 0.763672,    0.947266,    0.37207,     0.555664),
    Radial_Wheel_Frame_CoolDown_Count_4_Small = R(94, 94, 0.478516,   0.570312,    0.657227,    0.749023),

    -- Select elements
    Radial_Wheel_Select_Wedge_Count_4       = R(172, 288, 0.743164,    0.911133,    0.000976562, 0.282227),
    Radial_Wheel_Select_Wedge_Count_4_Small = R( 86, 144, 0.913086,    0.99707,     0.000976562, 0.141602),
    Radial_Wheel_Select_Pointer             = R(120, 120, 0.743164,    0.825195,    0.28418,     0.366211),
    Radial_Wheel_Select_Pointer_Small       = R( 42,  42, 0.913086,    0.954102,    0.143555,    0.18457),
    Radial_Wheel_Select_Close               = R( 48,  48, 0.827148,    0.874023,    0.28418,     0.331055),
    Radial_Wheel_Select_Close_Small         = R( 24,  24, 0.827148,    0.850586,    0.333008,    0.356445),

    -- Close icon
    Radial_Wheel_Icon_Close                 = R( 24,  24, 0.875977,    0.899414,    0.28418,     0.307617),
    Radial_Wheel_Icon_Close_Small           = R( 12,  12, 0.875977,    0.887695,    0.30957,     0.321289),

    -- Cooldown bar elements
    Radial_Wheel_Bar_CoolDown               = R(290, 290, 0.000976562, 0.28418,     0.663086,    0.946289),
    Radial_Wheel_Bar_CoolDown_Small         = R(145, 145, 0.577148,    0.71875,     0.558594,    0.700195),
    Radial_Wheel_BarBG_CoolDown             = R(290, 290, 0.291992,    0.575195,    0.37207,     0.655273),
    Radial_Wheel_BarBG_CoolDown_Small       = R(145, 145, 0.720703,    0.862305,    0.558594,    0.700195),
    Radial_Wheel_Bar_CoolDownFX             = R(296, 296, 0.000976562, 0.290039,    0.37207,     0.661133),
    Radial_Wheel_Bar_CoolDownFX_small       = R(148, 148, 0.291992,    0.436523,    0.84375,     0.988281),

    ---------------------------------------------------------------------------
    -- Ping system art  (uipingsystem2x.blp — UIPingSystem2x 2x)
    ---------------------------------------------------------------------------

    -- Wheel icons — normal
    Ping_Wheel_Icon_OnMyWay                 = R( 76,  76, 0.914551,    0.98877,     0.0756836,   0.149902),
    Ping_Wheel_Icon_Attack                  = R( 76,  76, 0.76416,     0.838379,    0.0756836,   0.149902),
    Ping_Wheel_Icon_Warning                 = R( 76,  76, 0.476074,    0.550293,    0.294434,    0.368652),
    Ping_Wheel_Icon_Assist                  = R( 76,  76, 0.76416,     0.838379,    0.000488281, 0.074707),

    -- Wheel icons — glow
    Ping_Wheel_Icon_OnMyWay_Glow            = R( 76,  76, 0.914551,    0.98877,     0.150879,    0.225098),
    Ping_Wheel_Icon_Attack_Glow             = R( 76,  76, 0.839355,    0.913574,    0.0756836,   0.149902),
    Ping_Wheel_Icon_Warning_Glow            = R( 76,  76, 0.55127,     0.625488,    0.294434,    0.368652),
    Ping_Wheel_Icon_Assist_Glow             = R( 76,  76, 0.914551,    0.98877,     0.000488281, 0.074707),

    -- Wheel icons — disabled
    Ping_Wheel_Icon_OnMyWay_Disabled        = R( 76,  76, 0.839355,    0.913574,    0.150879,    0.225098),
    Ping_Wheel_Icon_Attack_Disabled         = R( 76,  76, 0.76416,     0.838379,    0.150879,    0.225098),
    Ping_Wheel_Icon_Warning_Disabled        = R( 76,  76, 0.476074,    0.550293,    0.369629,    0.443848),
    Ping_Wheel_Icon_Assist_Disabled         = R( 76,  76, 0.839355,    0.913574,    0.000488281, 0.074707),

    -- Wheel icons — small (38x38)
    Ping_Wheel_Icon_OnMyWay_Small           = R( 38,  38, 0.168457,    0.205566,    0.861816,    0.898926),
    Ping_Wheel_Icon_Attack_Small            = R( 38,  38, 0.278809,    0.315918,    0.757324,    0.794434),
    Ping_Wheel_Icon_Warning_Small           = R( 38,  38, 0.206543,    0.243652,    0.861816,    0.898926),
    Ping_Wheel_Icon_Assist_Small            = R( 38,  38, 0.55127,     0.588379,    0.443848,    0.480957),

    -- Wheel icons — small glow
    Ping_Wheel_Icon_OnMyWay_Small_Glow      = R( 38,  38, 0.168457,    0.205566,    0.899902,    0.937012),
    Ping_Wheel_Icon_Attack_Small_Glow       = R( 38,  38, 0.215332,    0.252441,    0.814941,    0.852051),
    Ping_Wheel_Icon_Warning_Small_Glow      = R( 38,  38, 0.244629,    0.281738,    0.861816,    0.898926),
    Ping_Wheel_Icon_Assist_Small_Glow       = R( 38,  38, 0.626465,    0.663574,    0.442871,    0.47998),

    -- Wheel icons — small disabled
    Ping_Wheel_Icon_OnMyWay_Disabled_Small  = R( 38,  38, 0.253418,    0.290527,    0.814941,    0.852051),
    Ping_Wheel_Icon_Attack_Disabled_Small   = R( 38,  38, 0.700684,    0.737793,    0.442871,    0.47998),
    Ping_Wheel_Icon_Warning_Disabled_Small  = R( 38,  38, 0.168457,    0.205566,    0.937988,    0.975098),
    Ping_Wheel_Icon_Assist_Disabled_Small   = R( 38,  38, 0.476074,    0.513184,    0.444824,    0.481934),

    -- Unit marker backgrounds (pinging a unit frame)
    Ping_UnitMarker_BG                      = R( 58,  58, 0.000488281, 0.0571289,   0.757324,    0.813965),
    Ping_UnitMarker_BG_OnMyWay              = R( 58,  58, 0.0581055,   0.114746,    0.757324,    0.813965),
    Ping_UnitMarker_BG_Attack               = R( 58,  58, 0.000488281, 0.0571289,   0.872559,    0.929199),
    Ping_UnitMarker_BG_Warning              = R( 58,  58, 0.0581055,   0.114746,    0.872559,    0.929199),
    Ping_UnitMarker_BG_Assist               = R( 58,  58, 0.000488281, 0.0571289,   0.814941,    0.871582),
    Ping_UnitMarker_BG_NonThreat            = R( 58,  58, 0.000488281, 0.0571289,   0.930176,    0.986816),
    Ping_UnitMarker_BG_Threat               = R( 58,  58, 0.0581055,   0.114746,    0.814941,    0.871582),

    -- Ground marker backgrounds (circle behind world pin)
    Ping_GroundMarker_BG_OnMyWay            = R( 58,  58, 0.774902,    0.831543,    0.368652,    0.425293),
    Ping_GroundMarker_BG_Attack             = R( 58,  58, 0.839355,    0.895996,    0.226074,    0.282715),
    Ping_GroundMarker_BG_Warning            = R( 58,  58, 0.849121,    0.905762,    0.294434,    0.351074),
    Ping_GroundMarker_BG_Assist             = R( 58,  58, 0.76416,     0.820801,    0.226074,    0.282715),
    Ping_GroundMarker_BG_NonThreat          = R( 58,  58, 0.914551,    0.971191,    0.226074,    0.282715),
    Ping_GroundMarker_BG_Threat             = R( 58,  58, 0.0581055,   0.114746,    0.930176,    0.986816),

    -- Ground marker stems (vertical pin line)
    Ping_GroundMarker_Pin_OnMyWay           = R(  4, 114, 0.373535,    0.377441,    0.852051,    0.963379),
    Ping_GroundMarker_Pin_Attack            = R(  4, 114, 0.36377,     0.367676,    0.852051,    0.963379),
    Ping_GroundMarker_Pin_Warning           = R(  4, 114, 0.378418,    0.382324,    0.852051,    0.963379),
    Ping_GroundMarker_Pin_Assist            = R(  4, 114, 0.358887,    0.362793,    0.852051,    0.963379),
    Ping_GroundMarker_Pin_NonThreat         = R(  4, 114, 0.368652,    0.372559,    0.852051,    0.963379),
    Ping_GroundMarker_Pin_Threat            = R(  4, 114, 0.383301,    0.387207,    0.852051,    0.963379),

    -- Ground marker strokes (spinning ring overlay)
    Ping_GroundMarker_Stroke_OnMyWay        = R( 58,  58, 0.906738,    0.963379,    0.352051,    0.408691),
    Ping_GroundMarker_Stroke_Attack         = R( 58,  58, 0.849121,    0.905762,    0.352051,    0.408691),
    Ping_GroundMarker_Stroke_Warning        = R( 58,  58, 0.906738,    0.963379,    0.409668,    0.466309),
    Ping_GroundMarker_Stroke_Assist         = R( 58,  58, 0.906738,    0.963379,    0.294434,    0.351074),
    Ping_GroundMarker_Stroke_NonThreat      = R( 58,  58, 0.849121,    0.905762,    0.409668,    0.466309),
    Ping_GroundMarker_Stroke_Threat         = R( 58,  58, 0.115723,    0.172363,    0.757324,    0.813965),

    -- Marker small icons (standalone, used in world frames)
    Ping_Marker_Icon_OnMyWay                = R( 35,  35, 0.32373,     0.35791,     0.749512,    0.783691),
    Ping_Marker_Icon_Attack                 = R( 35,  35, 0.243652,    0.277832,    0.937012,    0.971191),
    Ping_Marker_Icon_Warning                = R( 35,  35, 0.32373,     0.35791,     0.819824,    0.854004),
    Ping_Marker_Icon_Assist                 = R( 35,  35, 0.280762,    0.314941,    0.899902,    0.934082),
    Ping_Marker_Icon_NonThreat              = R( 35,  35, 0.278809,    0.312988,    0.937012,    0.971191),
    Ping_Marker_Icon_Threat                 = R( 35,  35, 0.32373,     0.35791,     0.784668,    0.818848),

    -- Flipbook animations
    Ping_Marker_FlipBook_OnMyWay            = R(300, 272, 0.32373,     0.616699,    0.48291,     0.748535),
    Ping_Marker_FlipBook_Attack             = R(330, 280, 0.000488281, 0.322754,    0.48291,     0.756348),
    Ping_Marker_FlipBook_Warning            = R(192, 322, 0.617676,    0.805176,    0.48291,     0.797363),
    Ping_Marker_FlipBook_Assist             = R(486, 192, 0.000488281, 0.475098,    0.294434,    0.481934),
    Ping_Marker_FlipBook_NonThreat          = R(390, 300, 0.000488281, 0.381348,    0.000488281, 0.293457),
    Ping_Marker_FlipBook_Threat             = R(390, 300, 0.382324,    0.763184,    0.000488281, 0.293457),

    -- Spot glow (brief flash at cursor on send)
    Ping_SpotGlw_OnMyWay_In                 = R( 37,  37, 0.206543,    0.242676,    0.899902,    0.936035),
    Ping_SpotGlw_OnMyWay_Out                = R( 53,  53, 0.115723,    0.16748,     0.814941,    0.866699),
    Ping_SpotGlw_Attack_In                  = R( 37,  37, 0.589355,    0.625488,    0.443848,    0.47998),
    Ping_SpotGlw_Attack_Out                 = R( 53,  53, 0.17334,     0.225098,    0.757324,    0.809082),
    Ping_SpotGlw_Warning_In                 = R( 37,  37, 0.243652,    0.279785,    0.899902,    0.936035),
    Ping_SpotGlw_Warning_Out                = R( 53,  53, 0.115723,    0.16748,     0.92041,     0.972168),
    Ping_SpotGlw_Assist_In                  = R( 37,  37, 0.51416,     0.550293,    0.444824,    0.480957),
    Ping_SpotGlw_Assist_Out                 = R( 53,  53, 0.774902,    0.82666,     0.42627,     0.478027),
    Ping_SpotGlw_NonThreat_In               = R( 37,  37, 0.282715,    0.318848,    0.861816,    0.897949),
    Ping_SpotGlw_NonThreat_Out              = R( 53,  53, 0.226074,    0.277832,    0.757324,    0.809082),
    Ping_SpotGlw_Threat_In                  = R( 37,  37, 0.206543,    0.242676,    0.937012,    0.973145),
    Ping_SpotGlw_Threat_Out                 = R( 53,  53, 0.115723,    0.16748,     0.867676,    0.919434),

    -- Off-screen indicator arrow (clamped / out-of-view ping)
    Ping_OVMarker_Pointer_BG                = R( 47,  47, 0.168457,    0.214355,    0.814941,    0.86084),
    Ping_OVMarker_Pointer_OnMyWay           = R( 75,  75, 0.700684,    0.773926,    0.294434,    0.367676),
    Ping_OVMarker_Pointer_Attack            = R( 75,  75, 0.626465,    0.699707,    0.294434,    0.367676),
    Ping_OVMarker_Pointer_Warning           = R( 75,  75, 0.774902,    0.848145,    0.294434,    0.367676),
    Ping_OVMarker_Pointer_Assist            = R( 75,  75, 0.55127,     0.624512,    0.369629,    0.442871),
    Ping_OVMarker_Pointer_NonThreat         = R( 75,  75, 0.626465,    0.699707,    0.368652,    0.441895),
    Ping_OVMarker_Pointer_Threat            = R( 75,  75, 0.700684,    0.773926,    0.368652,    0.441895),

    -- Minimap pin icons (small, placed on the minimap)
    Ping_MapPin_OnMyWay                     = R( 16,  20, 0.896973,    0.912598,    0.246582,    0.266113),
    Ping_MapPin_Attack                      = R( 16,  20, 0.821777,    0.837402,    0.246582,    0.266113),
    Ping_MapPin_Warning                     = R( 16,  20, 0.972168,    0.987793,    0.272949,    0.29248),
    Ping_MapPin_Assist                      = R( 16,  20, 0.821777,    0.837402,    0.226074,    0.245605),
    Ping_MapPin_Glw                         = R( 16,  20, 0.821777,    0.837402,    0.26709,     0.286621),
    Ping_MapPin_NonThreat                   = R( 16,  20, 0.896973,    0.912598,    0.226074,    0.245605),
    Ping_MapPin_Threat                      = R( 16,  20, 0.896973,    0.912598,    0.26709,     0.286621),

    -- Map small icons (23x23, used on world map)
    Ping_Map_OnMyWay                        = R( 23,  23, 0.243652,    0.266113,    0.972168,    0.994629),
    Ping_Map_OnMyWayGlw                     = R( 23,  23, 0.278809,    0.30127,     0.972168,    0.994629),
    Ping_Map_Attack                         = R( 23,  23, 0.115723,    0.138184,    0.973145,    0.995605),
    Ping_Map_AttackGlw                      = R( 23,  23, 0.13916,     0.161621,    0.973145,    0.995605),
    Ping_Map_Warning                        = R( 23,  23, 0.358887,    0.381348,    0.828613,    0.851074),
    Ping_Map_WarningGlw                     = R( 15,  15, 0.83252,     0.847168,    0.368652,    0.383301),
    Ping_Map_Assist                         = R( 23,  23, 0.972168,    0.994629,    0.226074,    0.248535),
    Ping_Map_AssistGlw                      = R( 23,  23, 0.972168,    0.994629,    0.249512,    0.271973),
    Ping_Map_NonThreat                      = R( 23,  23, 0.168457,    0.190918,    0.976074,    0.998535),
    Ping_Map_NonThreatGlw                   = R( 23,  23, 0.206543,    0.229004,    0.974121,    0.996582),
    Ping_Map_Threat                         = R( 23,  23, 0.358887,    0.381348,    0.781738,    0.804199),
    Ping_Map_ThreatGlw                      = R( 23,  23, 0.358887,    0.381348,    0.805176,    0.827637),

    -- Minimap overlay blips (36x36)
    Ping_MapOV_OnMyWay                      = R( 36,  36, 0.964355,    0.999512,    0.352051,    0.387207),
    Ping_MapOV_Attack                       = R( 36,  36, 0.73877,     0.773926,    0.442871,    0.478027),
    Ping_MapOV_Warning                      = R( 36,  36, 0.964355,    0.999512,    0.445801,    0.480957),
    Ping_MapOV_Assist                       = R( 36,  36, 0.664551,    0.699707,    0.442871,    0.478027),
    Ping_MapOV_NonThreat                    = R( 36,  36, 0.964355,    0.999512,    0.294434,    0.32959),
    Ping_MapOV_Threat                       = R( 36,  36, 0.964355,    0.999512,    0.409668,    0.444824),

    -- Deprecated whole-map icons (kept for reference)
    Ping_Map_Whole_OnMyWay_Deprecated       = R( 32,  32, 0.32373,     0.35498,     0.919434,    0.950684),
    Ping_Map_Whole_Attack_Deprecated        = R( 32,  32, 0.32373,     0.35498,     0.85498,     0.88623),
    Ping_Map_Whole_Warning_Deprecated       = R( 32,  32, 0.358887,    0.390137,    0.749512,    0.780762),
    Ping_Map_Whole_Assist_Deprecated        = R( 32,  32, 0.291504,    0.322754,    0.814941,    0.846191),
    Ping_Map_Whole_NonThreat_Deprecated     = R( 32,  32, 0.32373,     0.35498,     0.887207,    0.918457),
    Ping_Map_Whole_Threat_Deprecated        = R( 32,  32, 0.32373,     0.35498,     0.95166,     0.98291),

    ---------------------------------------------------------------------------
    -- Ping cursor  (Interface/Cursor/UIPingCursor2x — 1x sheet)
    ---------------------------------------------------------------------------
    cursor_ping_32          = R( 32,  32, 0.509766,   0.572266,  0.261719,   0.386719),
    cursor_ping_48          = R( 48,  48, 0.767578,   0.861328,  0.00390625, 0.191406),
    cursor_ping_64          = R( 64,  64, 0.509766,   0.634766,  0.00390625, 0.253906),
    cursor_ping_96          = R( 96,  96, 0.00195312, 0.189453,  0.511719,   0.886719),
    cursor_ping_128         = R(128, 128, 0.00195312, 0.251953,  0.00390625, 0.503906),
    cursor_unablePing_32    = R( 32,  32, 0.509766,   0.572266,  0.394531,   0.519531),
    cursor_unablePing_48    = R( 48,  48, 0.865234,   0.958984,  0.00390625, 0.191406),
    cursor_unablePing_64    = R( 64,  64, 0.638672,   0.763672,  0.00390625, 0.253906),
    cursor_unablePing_96    = R( 96,  96, 0.255859,   0.443359,  0.511719,   0.886719),
    cursor_unablePing_128   = R(128, 128, 0.255859,   0.505859,  0.00390625, 0.503906),
}

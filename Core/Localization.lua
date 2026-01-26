--[[
 Copyright (c) 2026 s0high
 https://github.com/s0h2x/LossOfControl
    
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua,wow>
local GetLocale = GetLocale;
local pairs = pairs;
local rawget = rawget;
local setmetatable = setmetatable;
local tostring = tostring;

--@class Localization<core>
local L10N = {};
Engine.Localization = L10N;


-- Locale Index Map
----------------------------------------------------------------
local LOCALE_INDEX = {
	enUS = 1, enGB = 1,
	ruRU = 2,
	deDE = 3,
	frFR = 4,
	esES = 5, esMX = 5,
	itIT = 6,
	ptBR = 7,
	zhCN = 8,
	zhTW = 9,
	koKR = 10,
};


-- Localization Data
-- Index: 1=enUS,  2=ruRU,  3=deDE,  4=frFR,  5=esES,  6=itIT,  7=ptBR,  8=zhCN,  9=zhTW,  10=koKR
----------------------------------------------------------------
local TRANSLATIONS = {
	--                       enUS               ruRU                  deDE                  frFR                esES                itIT                  ptBR                zhCN           zhTW             koKR
	STUN                 = { "Stunned",         "Оглушение",          "Betäubt",            "Étourdissement",   "Aturdido",         "Stordito",           "Atordoado",        "昏迷",        "昏迷",          "기절" },
	FEAR                 = { "Feared",          "Страх",              "Verängstigt",        "Peur",             "Asustado",         "Impaurito",          "Amedrontado",      "恐惧",        "恐懼",          "공포" },
	HORROR               = { "Horrified",       "Ужас",               "Entsetzt",           "Horreur",          "Horrorizado",      "Terrorizzato",       "Horrorizado",      "惊骇",        "受驚",          "두려움" },
	ROOT                 = { "Rooted",          "Обездвиженность",    "Bewegungsunfähig",   "Immobilisation",   "Enraizado",        "Immobilizzato",      "Enraizado",        "被定身",      "定身",          "이동 불가" },
	SILENCE              = { "Silenced",        "Немота",             "Stille",             "Silence",          "Silenciado",       "Silenziato",         "Silenciado",       "沉默",        "沉默",          "침묵" },
	DISARM               = { "Disarmed",        "Без оружия",         "Entwaffnet",         "Désarmement",      "Desarmado",        "Disarmato",          "Desarmado",        "缴械",        "繳械",          "무장 해제" },
	POLYMORPH            = { "Polymorphed",     "Превращение",        "Verwandelt",         "Métamorphose",     "Polimorfado",      "Metamorfato",        "Polimorfado",      "变形",        "變形",          "변이" },
	FREEZE               = { "Frozen",          "Заморозка",          "Eingefroren",        "Gel",              "Congelado",        "Congelato",          "Congelado",        "被冻结",      "冰凍",          "빙결" },
	CYCLONE              = { "Cycloned",        "Смерч",              "Außer Gefecht",      "Cyclone",          "Ciclón",           "Ciclonato",          "Ventaneado",       "旋风",        "陷入颶風術",    "회오리바람" },
	BANISH               = { "Banished",        "Изгнание",           "Verbannt",           "Bannissement",     "Desterrado",       "Esiliato",           "Banido",           "放逐",        "放逐",          "추방" },
	CHARM                = { "Charmed",         "Подчинение",         "Betört",             "Charme",           "Embelesado",       "Ammaliato",          "Enfeitiçado",      "魅惑",        "魅惑",          "현혹" },
	CONFUSE              = { "Confused",        "Растерянность",      "Verwirrt",           "Confusion",        "Confundido",       "Confuso",            "Confuso",          "迷惑",        "困惑",          "혼란" },
	DISORIENT            = { "Disoriented",     "Дезориентация",      "Desorientiert",      "Désorientation",   "Desorientado",     "Disorientato",       "Desnorteado",      "迷惑",        "困惑",          "방향 감각 상실" },
	INCAP                = { "Incapacitated",   "Паралич",            "Handlungsunfähig",   "Stupéfaction",     "Incapacitado",     "Inabilitato",        "Incapacitado",     "瘫痪",        "癱瘓",          "행동 불가" },
	SAP                  = { "Sapped",          "Ошеломление",        "Ausgeschaltet",      "Assommement",      "Aporreado",        "Tramortito",         "Aturdido",         "被闷棍",      "中了悶棍",      "혼절" },
	SLEEP                = { "Asleep",          "Сон",                "In Schlaf versetzt", "Sommeil",          "Dormido",          "Addormentato",       "Dormindo",         "沉睡",        "沉睡",          "수면" },
	SNARE                = { "Snared",          "Замедление",         "Verlangsamt",        "Piège",            "Frenado",          "Rallentato",         "Lerdo",            "诱捕",        "緩速",          "감속" },
	DAZE                 = { "Dazed",           "Головокружение",     "Benommen",           "Hébétement",       "Atontado",         "Frastornato",        "Estonteado",       "眩晕",        "暈眩",          "멍해짐" },
	SHACKLE              = { "Shackled",        "Оковы",              "Gefesselt",          "Entraves",         "Encadenado",       "Incatenato",         "Agrilhoado",       "束缚",        "禁錮",          "속박" },
	POSSESS              = { "Possessed",       "Одержимость",        "Besessen",           "Possédé",          "Poseído",          "Posseduto",          "Possuído",         "被占据",      "附身",          "빙의" },
	PACIFY               = { "Pacified",        "Усмирение",          "Befriedet",          "Pacification",     "Pacificado",       "Pacificato",         "Pacificado",       "平静",        "平靜",          "평정" },
	DISTRACT             = { "Distracted",      "Отвлечение",         "Abgelenkt",          "Distraction",      "Distraído",        "Distratto",          "Distraído",        "被吸引",      "分心",          "견제" },
	TAUNT                = { "Taunted",         "Провокация",         "Verspottet",         "Raillé",           "Provocado",        "Provocato",          "Provocado",        "被嘲讽",      "被嘲諷",        "도발당함" },
	INVULNERABILITY      = { "Invulnerable",    "Неуязвимость",       "Unverwundbar",       "Invulnérabilité",  "Invulnerable",     "Invulnerabile",      "Invulnerável",     "无敌",        "免傷",          "무적" },
	-- Interrupt
	SCHOOL_INTERRUPT     = { "Interrupted",     "Прерывание",         "Unterbrochen",       "Interruption",     "Interrumpido",     "Interrotto",         "Interrompido",     "打断",        "中斷",          "차단" },
	INTERRUPT_FMT        = { "%s Locked",       "%s: недоступно",     "%s gesperrt",        "%s verrouillé",    "Bloqueo: %s",      "%s bloccati",        "%s Bloqueado",     "%s被锁定",    "禁用%s法術",     "%s 차단됨" },
	-- Misc
	SECONDS              = { "seconds",         "сек.",               "Sek.",               "secondes",         "segundos",         "secondi",            "segundos",         "秒",          "秒",            "초" },
	-- Settings / UI
	-- ADDON_TITLE          = { "Loss of Control", "Потеря контроля",    "Kontrollverlust",    "Perte de contrôle","Pérdida control",  "Perdita controllo",  "Perda de controle"," 失控警报",   "喪失控制",       "제어 불가" },
	
	-- enUS     ruRU     deDE     frFR     esES     zhCN     zhTW     koKR     itIT
	-- ENABLED              = { "Enabled",         "Включено",           "Aktiviert",          "Activé",           "Abilitato",         "",                "Habilitado",       "已启用",      "已啟用",        "활성화됨" },
	-- DISABLED             = { "Disabled",        "Выключено",          "Deaktiviert",        "Désactivé",        "Deshabilitado",     "Disabilitato",    "",                 "已禁用",      "已停用",        "비활성화됨" },
	-- VIDEO_OPTIONS_ENABLED = ENABLED
	-- MOVE_MODE            = { "Move Mode",       "Режим перемещения",  "Bewegungsmodus",     "Mode déplacement", "Modo de movimiento","Modalità movimento", "", "移动模式", "移動模式", "이동 모드" },
	-- RESET_POSITION       = { "Reset Position", "Сбросить позицию", "Position zurücksetzen", "Réinitialiser la position", "Restablecer posición",  "Reimposta posizione", "", "重置位置", "重置位置", "위치 초기화" },
	-- CMD_HELP             = { "Available commands:", "Доступные команды:", "Verfügbare Befehle:", "Commandes disponibles:", "Comandos disponibles:", "Comandi disponibili:", "", "可用命令：", "可用指令：", "사용 가능한 명령어:" },
};


local fallbackMT = { __index = function(_, key)
		return tostring(key);
	end
};

function L10N:Init()
	local clientLocale = GetLocale();
	local index = LOCALE_INDEX[clientLocale] or 1;

	local L = {};
	for key, values in pairs(TRANSLATIONS) do
		L[key] = values[index] or values[1] or key;
	end

	Engine.Locale = setmetatable(L, fallbackMT);

	TRANSLATIONS = nil;
	LOCALE_INDEX = nil;

	-- Engine.DebugLog("Localization: %s (index %d)", clientLocale, index);
end

-- L10N:Init();

-- API
----------------------------------------------------------------
-- function L10N:HasKey(key)
	-- return rawget(Engine.Locale, key) ~= nil;
-- end

-- function L10N:Extend(translations)
	-- local L = Engine.Locale;
	-- if not L then return end
	
	-- for key, value in pairs(translations) do
		-- if rawget(L, key) == nil then
			-- L[key] = value
		-- end
	-- end
-- end
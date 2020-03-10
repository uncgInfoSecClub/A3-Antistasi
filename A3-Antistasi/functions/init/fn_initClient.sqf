#include "..\Garage\defineGarage.inc"
private _fileName = "initClient.sqf";

//Make sure logLevel is always initialised.
//This should be overridden by the server, as appropriate. Hence the nil check.
if (isNil "logLevel") then { logLevel = 2 };scriptName "initClient.sqf";

[2,"initClient started",_fileName] call A3A_fnc_log;

call A3A_fnc_installSchrodingersBuildingFix;

if (hasInterface) then {
	waitUntil {!isNull player};
	waitUntil {player == player};
	//Disable player saving until they're fully ready, and have chosen whether to load their save.
	player setVariable ["canSave", false, true];
};

if (!isServer) then {
	call A3A_fnc_initFuncs;
	call A3A_fnc_initVar;
	if (!hasInterface) exitWith {
		[2,format ["Headless client version: %1",localize "STR_antistasi_credits_generic_version_text"],_fileName] call A3A_fnc_log;
		[clientOwner] remoteExec ["A3A_fnc_addHC",2];
	};
	[2,format ["MP client version: %1",localize "STR_antistasi_credits_generic_version_text"],_fileName] call A3A_fnc_log;
}
else {
	// SP or hosted, initFuncs/var run in serverInit
	waitUntil {sleep 0.5;(!isNil "serverInitDone")};
};
[] execVM "briefing.sqf";

_isJip = _this select 1;
if (isMultiplayer) then {
	if (side player == teamPlayer) then {
		player setVariable ["eligible",true,true];
	};
	musicON = false;
	//waitUntil {scriptdone _introshot};
	disableUserInput true;
	cutText ["Waiting for Players and Server Init","BLACK",0];
	[2,"Waiting for server...",_fileName] call A3A_fnc_log;
	waitUntil {(!isNil "serverInitDone")};
	cutText ["Starting Mission","BLACK IN",0];
	[2,"Server loaded!",_fileName] call A3A_fnc_log;
	[2,format ["JIP client: %1",_isJIP],_fileName] call A3A_fnc_log;
	if (hasTFAR) then {
		[] execVM "orgPlayers\radioJam.sqf";
	};
	tkPunish = if ("tkPunish" call BIS_fnc_getParamValue == 1) then {true} else {false};
	if (side player == teamPlayer) then {
		private _firedHandlerTk = {
			_typeX = _this select 1;
			if ((_typeX == "Put") or (_typeX == "Throw")) then {
				private _shieldDistance = 100;
				if (player distance petros < _shieldDistance) then {
					["Warning", format ["You cannot throw grenades or place explosives within %1m of base.", _shieldDistance]] call A3A_fnc_customHint;
					deleteVehicle (_this select 6);
					if (_typeX == "Put") then {
						if (player distance petros < 10) then {
							[player, 20, 0.34, petros] call A3A_fnc_punishment;
						};
					};
				};
			};
		};
		player addEventHandler ["Fired", _firedHandlerTk];
		if (hasACE) then {
			["ace_firedPlayer", _firedHandlerTk ] call CBA_fnc_addEventHandler;
		};
	};
	if (!isNil "placementDone") then {_isJip = true};//workaround for BIS fail on JIP detection
}
else {
	theBoss = player;
	groupX = group player;
	if (worldName == "Tanoa") then {groupX setGroupId ["Pulu","GroupColor4"]} else {groupX setGroupId ["Stavros","GroupColor4"]};
	player setIdentity "protagonista";
	player setUnitRank "COLONEL";
	player hcSetGroup [group player];
	player setUnitTrait ["medic", true];
	player setUnitTrait ["engineer", true];
	waitUntil {/*(scriptdone _introshot) and */(!isNil "serverInitDone")};
};

[] spawn A3A_fnc_ambientCivs;
private ["_colourTeamPlayer", "_colorInvaders"];
_colourTeamPlayer = teamPlayer call BIS_fnc_sideColor;
_colorInvaders = Invaders call BIS_fnc_sideColor;
_positionX = if (side player == side (group petros)) then {position petros} else {getMarkerPos "respawn_west"};

{
	_x set [3, 0.33]
} forEach [_colourTeamPlayer, _colorInvaders];

_introShot = [
	_positionX, // Target position
	format ["%1",worldName], // SITREP text
	50, //  altitude
	50, //  radius
	90, //  degrees viewing angle
	0, // clockwise movement
	[
		["\a3\ui_f\data\map\markers\Nato\o_inf.paa", _colourTeamPlayer, markerPos "insertMrk", 1, 1, 0, "Insertion Point", 0],
		["\a3\ui_f\data\map\markers\Nato\o_inf.paa", _colorInvaders, markerPos "towerBaseMrk", 1, 1, 0, "Radio Towers", 0]
	]
] spawn BIS_fnc_establishingShot;

//Initialise membershipEnabled so we can do isMember checks.
membershipEnabled = if (isMultiplayer && "membership" call BIS_fnc_getParamValue == 1) then {true} else {false};

disableUserInput false;

if (isMultiplayer && {playerMarkersEnabled}) then {
	[] spawn A3A_fnc_playerMarkers;
};

[player] spawn A3A_fnc_initRevive;		// with ACE medical, only used for helmet popping & TK checks

if (!hasACE) then {
	[] spawn A3A_fnc_tags;
};

if (player getVariable ["pvp",false]) exitWith {
	lastVehicleSpawned = objNull;
	[player] call A3A_fnc_pvpCheck;
	[player] call A3A_fnc_dress;
	if (hasACE) then {[] call A3A_fnc_ACEpvpReDress};
	respawnTeamPlayer setMarkerAlphaLocal 0;

	player addEventHandler ["GetInMan", {_this call A3A_fnc_ejectPvPPlayerIfInvalidVehicle}];
	player addEventHandler ["SeatSwitchedMan", {[_this select 0, assignedVehicleRole (_this select 0) select 0, _this select 2] call A3A_fnc_ejectPvPPlayerIfInvalidVehicle}];
	player addEventHandler ["InventoryOpened", {
		_override = false;
		_boxX = typeOf (_this select 1);
		if ((_boxX == NATOAmmoBox) or (_boxX == CSATAmmoBox)) then {_override = true};
		_override
	}];
	_nameX = if (side player == Occupants) then {nameOccupants} else {nameInvaders};
	waituntil {!isnull (finddisplay 46)};
	gameMenu = (findDisplay 46) displayAddEventHandler ["KeyDown", {
		_handled = FALSE;
		if (_this select 1 == 207) then {
			if (!hasACEhearing) then {
				if (soundVolume <= 0.5) then {
					0.5 fadeSound 1;
					["Ear Plugs", "You've taken out your ear plugs.", true] call A3A_fnc_customHint;
				}
				else {
					0.5 fadeSound 0.1;
					["Ear Plugs", "You've inserted your ear plugs.", true] call A3A_fnc_customHint;
				};
			};
		}
		else {
			if (_this select 1 == 21) then {
				closedialog 0;
				_nul = createDialog "NATO_player";
			};
		};
		_handled
	}];
};

player setVariable ["score",0,true];
player setVariable ["owner",player,true];
player setVariable ["punish",0,true];
player setVariable ["moneyX",100,true];
player setUnitRank "PRIVATE";
player setVariable ["rankX",rank player,true];

stragglers = creategroup teamPlayer;
(group player) enableAttack false;
player setUnitTrait ["camouflageCoef",0.8];
player setUnitTrait ["audibleCoef",0.8];

//Give the player the base loadout.
[player] call A3A_fnc_dress;

player setvariable ["compromised",0];
player addEventHandler ["FiredMan", {
	_player = _this select 0;
	if (captive _player) then {
		//if ({((side _x== Invaders) or (side _x== Occupants)) and (_x knowsAbout player > 1.4)} count allUnits > 0) then
		if ({if (((side _x == Occupants) or (side _x == Invaders)) and (_x distance player < 300)) exitWith {1}} count allUnits > 0) then {
			[_player,false] remoteExec ["setCaptive",0,_player];
			_player setCaptive false;
		}
		else {
			_city = [citiesX,_player] call BIS_fnc_nearestPosition;
			_size = [_city] call A3A_fnc_sizeMarker;
			_dataX = server getVariable _city;
			if (random 100 < _dataX select 2) then {
				if (_player distance getMarkerPos _city < _size * 1.5) then {
					[_player,false] remoteExec ["setCaptive",0,_player];
					_player setCaptive false;
					if (vehicle _player != _player) then {
						{if (isPlayer _x) then {[_x,false] remoteExec ["setCaptive",0,_x]; _x setCaptive false}} forEach ((assignedCargo (vehicle _player)) + (crew (vehicle _player)) - [player]);
					};
				};
			};
		};
	};
}];
player addEventHandler ["InventoryOpened", {
	private ["_playerX","_containerX","_typeX"];
	_control = false;
	_playerX = _this select 0;
	if (captive _playerX) then {
		_containerX = _this select 1;
		_typeX = typeOf _containerX;
		if (((_containerX isKindOf "Man") and (!alive _containerX)) or (_typeX == NATOAmmoBox) or (_typeX == CSATAmmoBox)) then {
			if ({if (((side _x== Invaders) or (side _x== Occupants)) and (_x knowsAbout _playerX > 1.4)) exitWith {1}} count allUnits > 0) then{
				[_playerX,false] remoteExec ["setCaptive",0,_playerX];
				_playerX setCaptive false;
			}
			else {
				_city = [citiesX,_playerX] call BIS_fnc_nearestPosition;
				_size = [_city] call A3A_fnc_sizeMarker;
				_dataX = server getVariable _city;
				if (random 100 < _dataX select 2) then {
					if (_playerX distance getMarkerPos _city < _size * 1.5) then {
						[_playerX,false] remoteExec ["setCaptive",0,_playerX];
						_playerX setCaptive false;
					};
				};
			};
		};
	};
	_control
}];
/*
player addEventHandler ["InventoryClosed", {
	_control = false;
	_uniform = uniform player;
	_typeSoldier = getText (configfile >> "CfgWeapons" >> _uniform >> "ItemInfo" >> "uniformClass");
	_sideType = getNumber (configfile >> "CfgVehicles" >> _typeSoldier >> "side");
	if ((_sideType == 1) or (_sideType == 0) and (_uniform != "")) then {
		if !(player getVariable ["disguised",false]) then {
			hint "You are wearing an enemy uniform, this will make the AI attack you. Beware!";
			player setVariable ["disguised",true];
			player addRating (-1*(2001 + rating player));
		};
	}
	else {
		if (player getVariable ["disguised",false]) then {
			hint "You removed your enemy uniform";
			player addRating (rating player * -1);
		};
	};
	_control
}];
*/
player addEventHandler ["HandleHeal", {
	_player = _this select 0;
	if (captive _player) then {
		if ({((side _x== Invaders) or (side _x== Occupants)) and (_x knowsAbout player > 1.4)} count allUnits > 0) then {
			[_player,false] remoteExec ["setCaptive",0,_player];
			_player setCaptive false;
		}
		else {
			_city = [citiesX,_player] call BIS_fnc_nearestPosition;
			_size = [_city] call A3A_fnc_sizeMarker;
			_dataX = server getVariable _city;
			if (random 100 < _dataX select 2) then {
				if (_player distance getMarkerPos _city < _size * 1.5) then {
					[_player,false] remoteExec ["setCaptive",0,_player];
					_player setCaptive false;
				};
			};
		};
	};
}];

player addEventHandler
[
    "WeaponAssembled",
    {
        params ["_unit", "_staticWeapon"];
        //Is there any other kind of weapon that can be assembled?
        if (_staticWeapon isKindOf "StaticWeapon") then
        {
            private _marker = [_staticWeapon] call A3A_fnc_isStaticWeaponOnMarker;
            if (_marker != "") then
            {
                hint format ["You deployed the static weapon at %1. If there are militia units stationated here, they will man this weapon shortly!", [_marker] call A3A_fnc_localizar];
                [_staticWeapon, _marker] call A3A_fnc_addStaticToGarrison;

            }
            else
            {
                [_staticWeapon] call A3A_fnc_AIVEHinit;
            };
        }
        else
        {
            _staticWeapon addEventHandler
            [
                "Killed",
                {
                    [_this select 0] remoteExec ["A3A_fnc_postmortem",2]
                }
            ];
        };
    }
];

player addEventHandler
[
    "WeaponDisassembled",
    {
        params ["_unit", "_backpack1", "_backpack2"];
        [_backpack1] call A3A_fnc_AIVEHinit;
        [_backpack2] call A3A_fnc_AIVEHinit;

        private _closestMarker = [airportsX + outposts + resourcesX + factories + seaports + citiesX + ["Synd_HQ"], getPos _unit] call BIS_fnc_nearestPosition;
        if((((getMarkerPos _closestMarker) distance2D _unit) < 250) || {(getPos _unit) inArea _closestMarker}) then
        {
            diag_log format ["The marker is %1", _closestMarker];
            hint format ["You just disassembled a static weapon at %1, it will no longer be used by the stationated garrison!", [_closestMarker] call A3A_fnc_localizar];
        };
    }
];

player addEventHandler ["GetInMan", {
	private ["_unit","_veh"];
	_unit = _this select 0;
	_veh = _this select 2;
	_exit = false;
	if (isMultiplayer) then {
		if !([player] call A3A_fnc_isMember) then {
			_owner = _veh getVariable "ownerX";
			if (!isNil "_owner") then {
				if (_owner isEqualType "") then {
					if ({getPlayerUID _x == _owner} count (units group player) == 0) then {
						["Warning", "You cannot board other player vehicle if you are not in the same group"] call A3A_fnc_customHint;
						moveOut _unit;
						_exit = true;
					};
				};
			};
		};
	};
	if (!_exit) then {
		if (((typeOf _veh) in arrayCivVeh) or ((typeOf _veh) in civBoats)) then {
			if (!(_veh in reportedVehs)) then {
				[] spawn A3A_fnc_goUndercover;
			};
		};
	};
}];

call A3A_fnc_initUndercover;

if (isMultiplayer) then {
	["InitializePlayer", [player]] call BIS_fnc_dynamicGroups;//Exec on client
	if (membershipEnabled) then {
		if !([player] call A3A_fnc_isMember) then {
			private _isMember = false;
			if (isServer) then {
				_isMember = true;
			};
			if (serverCommandAvailable "#logout") then {
				_isMember = true;
				["General Info", "You are not in the member's list, but as you are Server Admin, you have been added. Welcome!"] call A3A_fnc_customHint;
			};

			if (_isMember) then {
				membersX pushBack (getPlayerUID player);
				publicVariable "membersX";
			} else {
				_nonMembers = {(side group _x == teamPlayer) and !([_x] call A3A_fnc_isMember)} count (call A3A_fnc_playableUnits);
				if (_nonMembers >= (playableSlotsNumber teamPlayer) - bookedSlots) then {["memberSlots",false,1,false,false] call BIS_fnc_endMission};
				if (memberDistance != 16000) then {[] execVM "orgPlayers\nonMemberDistance.sqf"};

				["General Info", "Welcome Guest<br/><br/>You have joined this server as guest"] call A3A_fnc_customHint;
			};
		};
	};
};

[] remoteExec ["A3A_fnc_assignBossIfNone", 2];

waitUntil { scriptDone _introshot };

if (_isJip) then {
	[2,"Joining In Progress (JIP)",_filename] call A3A_fnc_log;

	waitUntil {!(isNil "missionsX")};
	if (count missionsX > 0) then {
		{
			_tsk = _x select 0;
			if ([_tsk] call BIS_fnc_taskExists) then {
				_state = _x select 1;
				if ((_tsk call BIS_fnc_taskState) != _state) then {
					/*
					_tskVar = _tsk call BIS_fnc_taskVar;
					_tskVar setTaskState _state;
					*/
					[_tsk,_state] call bis_fnc_taskSetState;
				};
			};
		} forEach missionsX;
	};
}
else
{
	[2,"Not Joining in Progress (JIP)",_filename] call A3A_fnc_log;
};

[] spawn A3A_fnc_modBlacklist;

//Move this
//HC_commanderX synchronizeObjectsAdd [player];
//player synchronizeObjectsAdd [HC_commanderX];

_textX = [];

if ((hasTFAR) or (hasACRE)) then {
	_textX = ["TFAR or ACRE Detected\n\nAntistasi detects TFAR or ACRE in the server config.\nAll players will start with addon default radios.\nDefault revive system will shut down radios while players are unconscious.\n\n"];
};
if (hasACE) then {
	_textX = _textX + ["ACE 3 Detected\n\nAntistasi detects ACE modules in the server config.\nACE items added to arsenal and ammoboxes. Default AI control is disabled\nIf ACE Medical is used, default revive system will be disabled.\nIf ACE Hearing is used, default earplugs will be disabled."];
};
if (hasRHS) then {
	_textX = _textX + ["RHS Detected\n\nAntistasi detects RHS in the server config.\nDepending on the modules will have the following effects.\n\nAFRF: Replaces CSAT by a mix of russian units\n\nUSAF: Replaces NATO by a mix of US units\n\nGREF: Recruited AI will count with RHS as basic weapons, replaces FIA with Chdk units. Adds some civilian trucks"];
};
if (hasFFAA) then {
	_textX = _textX + ["FFAA Detected\n\nAntistasi detects FFAA in the server config.\nFIA Faction will be replaced by Spanish Armed Forces"];
};

if (hasTFAR or hasACE or hasRHS or hasACRE or hasFFAA) then {
	[_textX] spawn {
		sleep 0.5;
		_textX = _this select 0;
		"Integrated Mods Detected" hintC _textX;
		hintC_arr_EH = findDisplay 72 displayAddEventHandler ["unload", {
			0 = _this spawn {
				_this select 0 displayRemoveEventHandler ["unload", hintC_arr_EH];
				hintSilent "";
			};
		}];
	};
};
waituntil {!isnull (finddisplay 46)};
gameMenu = (findDisplay 46) displayAddEventHandler ["KeyDown",A3A_fnc_keys];
//removeAllActions boxX;

//if ((!isServer) and (isMultiplayer)) then {boxX call jn_fnc_arsenal_init};

boxX allowDamage false;
boxX addAction ["Transfer Vehicle cargo to Ammobox", {[] spawn A3A_fnc_empty;}, 4];
boxX addAction ["Move this asset", A3A_fnc_moveHQObject,nil,0,false,true,"","(_this == theBoss)", 4];
flagX allowDamage false;
flagX addAction ["Unit Recruitment", {if ([player,300] call A3A_fnc_enemyNearCheck) then {["Recruit Unit", "You cannot recruit units while there are enemies near you"] call A3A_fnc_customHint;} else { [] spawn A3A_fnc_unit_recruit; }},nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)"];
flagX addAction ["Move this asset", A3A_fnc_moveHQObject,nil,0,false,true,"","(_this == theBoss)", 4];

//Adds a light to the flag
private _flagLight = "#lightpoint" createVehicle (getPos flagX);
_flagLight setLightDayLight true;
_flagLight setLightColor [1, 1, 0.9];
_flagLight setLightBrightness 0.2;
_flagLight setLightAmbient [1, 1, 0.9];
_flagLight lightAttachObject [flagX, [0, 0, 4]];
_flagLight setLightAttenuation [7, 0, 0.5, 0.5];

vehicleBox allowDamage false;
vehicleBox addAction ["Heal, Repair and Rearm", A3A_fnc_healAndRepair,nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
vehicleBox addAction ["Vehicle Arsenal", JN_fnc_arsenal_handleAction, [], 0, true, false, "", "alive _target && vehicle _this != _this", 10];
if (isMultiplayer) then {
	vehicleBox addAction ["Personal Garage", { [GARAGE_PERSONAL] spawn A3A_fnc_garage },nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
};
vehicleBox addAction ["Faction Garage", { [GARAGE_FACTION] spawn A3A_fnc_garage; },nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
vehicleBox addAction ["Buy Vehicle", {if ([player,300] call A3A_fnc_enemyNearCheck) then {["Purchase Vehicle", "You cannot buy vehicles while there are enemies near you"] call A3A_fnc_customHint;} else {nul = createDialog "vehicle_option"}},nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
vehicleBox addAction ["Move this asset", A3A_fnc_moveHQObject,nil,0,false,true,"","(_this == theBoss)", 4];

fireX allowDamage false;
[fireX, "fireX"] call A3A_fnc_flagaction;

mapX allowDamage false;
mapX addAction ["Game Options", {["Game Options", format ["Antistasi - %2<br/><br/>Version: %1<br/><br/>Difficulty: %3<br/>Unlock Weapon Number: %4<br/>Limited Fast Travel: %5",antistasiVersion,worldName,if (skillMult == 2) then {"Normal"} else {if (skillMult == 1) then {"Easy"} else {"Hard"}},minWeaps,if (limitedFT) then {"Yes"} else {"No"}]] call A3A_fnc_customHint; nul=CreateDialog "game_options";},nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
mapX addAction ["Map Info", A3A_fnc_cityinfo,nil,0,false,true,"","(isPlayer _this) and (_this == _this getVariable ['owner',objNull]) and (side (group _this) == teamPlayer)", 4];
mapX addAction ["Move this asset", A3A_fnc_moveHQObject,nil,0,false,true,"","(_this == theBoss)", 4];
if (isMultiplayer) then {mapX addAction ["AI Load Info", { [] remoteExec ["A3A_fnc_AILoadInfo",4];},nil,0,false,true,"","((_this == theBoss) || (serverCommandAvailable ""#logout""))"]};
_nul = [player] execVM "OrgPlayers\unitTraits.sqf";

// only add petros actions if he's static
if (petros == leader group petros) then {
	group petros setGroupId ["Petros","GroupColor4"];
	[petros,"remove"] call A3A_fnc_flagaction;		// in case we already created them in initserver
	[petros,"mission"] call A3A_fnc_flagaction;
};
petros setIdentity "friendlyX";
if (worldName == "Tanoa") then {petros setName "Maru"} else {petros setName "Petros"};

disableSerialization;
//1 cutRsc ["H8erHUD","PLAIN",0,false];
_layer = ["statisticsX"] call bis_fnc_rscLayer;
_layer cutRsc ["H8erHUD","PLAIN",0,false];
[] spawn A3A_fnc_statistics;

//Check if we need to relocate HQ
if (isNil "placementDone") then {
	if (isNil "playerPlacingHQ" || {!(playerPlacingHQ in (call A3A_fnc_playableUnits))}) then {
		playerPlacingHQ = player;
		publicVariable "playerPlacingHQ";
		call A3A_fnc_placementSelection;
	};
};

//Load the player's personal save.
if (isMultiplayer) then {
	[] spawn A3A_fnc_createDialog_shouldLoadPersonalSave;
}
else
{
	if (loadLastSave) then {
		[] spawn A3A_fnc_loadPlayer;
	};
};

//Move the player to HQ now they're initialised.
player setPos (getMarkerPos respawnTeamPlayer);

//Disables rabbits and snakes, because they cause the log to be filled with "20:06:39 Ref to nonnetwork object Agent 0xf3b4a0c0"
//Can re-enable them if we find the source of the bug.
enableEnvironment [false, true];

[2,"initClient completed",_fileName] call A3A_fnc_log;

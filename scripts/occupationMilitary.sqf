private["_wp","_wp2","_wp3"];

if (!isServer) exitWith {};
_logDetail = format ["[OCCUPATION Military]:: Starting Monitor"];
[_logDetail] call SC_fnc_log;

_maxAIcount 		= SC_maxAIcount;
_minFPS 			= SC_minFPS;
_useLaunchers 		= DMS_ai_use_launchers;
_scaleAI			= SC_scaleAI;

_buildings 			= SC_buildings; // Class names for the military buildings to patrol
_building 			= [];

_currentPlayerCount = count playableUnits;
if(_currentPlayerCount > _scaleAI) then 
{
	_maxAIcount = _maxAIcount - (_currentPlayerCount - _scaleAI) ;
};

// Select an area to scan as nearObjects on the entire map is slooooooooow
_areaToScan = [ 0, 900, 1, 500, 500, 0, 0, 0, true, false ] call DMS_fnc_findSafePos;

// Don't spawn additional AI if the server fps is below 8
if(diag_fps < _minFPS) exitWith 
{ 
    _logDetail = format ["[OCCUPATION Military]:: Held off spawning more AI as the server FPS is only %1",diag_fps]; 
    [_logDetail] call SC_fnc_log;
};

_aiActive = {alive _x && side _x == EAST} count allUnits;

//_aiActive = count(_spawnCenter nearEntities ["O_recon_F", _maxDistance+1000]);
if(_aiActive > _maxAIcount) exitWith 
{ 
    _logDetail = format ["[OCCUPATION Military]:: %1 active AI, so not spawning AI this time",_aiActive]; 
    [_logDetail] call SC_fnc_log;
};

for [{_i = 0},{_i < (count _buildings)},{_i =_i + 1}] do
{
	_logDetail = format ["[OCCUPATION Military]:: scanning buildings around %2 started at %1",time,_areaToScan];
    [_logDetail] call SC_fnc_log;
	
	_building = _areaToScan nearObjects [_buildings select _i, 750];
	_currentBuilding = _buildings select _i;
	_logDetail = format ["[OCCUPATION Military]:: scan for %2 building finished at %1",time,_currentBuilding];
    [_logDetail] call SC_fnc_log;
	
    for [{_n = 0},{_n < (count _building)-1},{_n =_n + 1}] do
    {
		_okToSpawn = true;
		Sleep 0.1;
        _foundBuilding = (_building select _n);
		_location = getPos _foundBuilding;
		_pos = [_location select 0, _location select 1, 0];
		
		if(SC_extendedLogging) then 
        { 
            _logDetail = format ["[OCCUPATION Military]:: Testing position: %1",_pos];
            [_logDetail] call SC_fnc_log;
        };
		
		while{_okToSpawn} do
		{			
			// Percentage chance to spawn (roll 60 or more to spawn AI)
			_spawnChance = round (random 100);
			if(_spawnChance < 60) exitWith 
            { 
                _okToSpawn = false; 
                if(SC_extendedLogging) then 
                { 
                    _logDetail = format ["[OCCUPATION Military]:: Rolled %1 so not spawning AI this time",_spawnChance];
                    [_logDetail] call SC_fnc_log;
                };
            };
				
			// Don't spawn if too near a player base
			_nearBase = (nearestObjects [_pos,["Exile_Construction_Flag_Static"],500]) select 0;
			if (!isNil "_nearBase") exitwith 
            { 
                _okToSpawn = false; 
                if(SC_extendedLogging) then 
                { 
                    _logDetail = format ["[OCCUPATION Military]:: %1 is too close to player base",_pos];
                    [_logDetail] call SC_fnc_log;
                };
            };
			
			// Don't spawn AI near traders and spawn zones
			_nearestMarker = [allMapMarkers, _pos] call BIS_fnc_nearestPosition; // Nearest Marker to the Location		
			_posNearestMarker = getMarkerPos _nearestMarker;
			if(_pos distance _posNearestMarker < 500) exitwith 
            { 
                _okToSpawn = false; 
                if(SC_extendedLogging) then 
                { 
                    _logDetail = format ["[OCCUPATION Military]:: %1 is too close to a %2",_pos,_nearestMarker];
                    [_logDetail] call SC_fnc_log;
                }; 
            };
			
			// Don't spawn additional AI if there are already AI in range
			_aiNear = count(_pos nearEntities ["O_recon_F", 500]);
			if(_aiNear > 0) exitwith 
            { 
                _okToSpawn = false; 
                if(SC_extendedLogging) then 
                { 
                    _logDetail = format ["[OCCUPATION Military]:: %1 already has %2 active AI patrolling",_pos,_aiNear];
                    [_logDetail] call SC_fnc_log;
                }; 
            };

			// Don't spawn additional AI if there are players in range
			if([_pos, 200] call ExileClient_util_world_isAlivePlayerInRange) exitwith 
            { 
                _okToSpawn = false; 
                if(SC_extendedLogging) then 
                { 
                    _logDetail = format ["[OCCUPATION Military]:: %1 has players too close",_pos];
                    [_logDetail] call SC_fnc_log;
                }; 
            };
			
			if(_okToSpawn) then
			{
				//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Get AI to patrol the area
				//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				_aiCount = 2 + (round (random 3)); 
				_groupRadius = 100;
				_difficulty = "random";
				_side = "bandit";
				_spawnPosition = _pos;				
										
				// Get the AI to shut the fuck up :)
				enableSentences false;
				enableRadio false;
					
				if(!SC_useWaypoints) then
				{
					DMS_ai_use_launchers = false;
					_group = [_spawnPosition, _aiCount, _difficulty, "random", _side] call DMS_fnc_SpawnAIGroup;
					DMS_ai_use_launchers = true;

					[_group, _pos, _groupRadius] call bis_fnc_taskPatrol;
					_group setBehaviour "SAD";
					_group setCombatMode "RED";
				}
				else
				{

					_buildingPositions = [_foundBuilding, 5] call BIS_fnc_buildingPositions;
					if(count _buildingPositions > 0) then
					{

						// Find Highest Point
						_highest = [0,0,0];
						{
							if(_x select 2 > _highest select 2) then
							{
								_highest = _x;
							};

						} foreach _buildingPositions;		
						_spawnPosition = _highest;
					};
					
									
					DMS_ai_use_launchers = false;
					_group = [_spawnPosition, _aiCount, _difficulty, "random", _side] call DMS_fnc_SpawnAIGroup;
					DMS_ai_use_launchers = true;

					[ _group,_pos,_difficulty,"COMBAT" ] call DMS_fnc_SetGroupBehavior;
					
					_buildings = _pos nearObjects ["house", _groupRadius];
					{
						_buildingPositions = [_x, 10] call BIS_fnc_buildingPositions;
						if(count _buildingPositions > 0) then
						{

							// Find Highest Point
							_highest = [0,0,0];
							{
								if(_x select 2 > _highest select 2) then
								{
									_highest = _x;
								};

							} foreach _buildingPositions;		
							_spawnPosition = _highest;
							
							_i = _buildingPositions find _spawnPosition;
							_wp = _group addWaypoint [_spawnPosition, 0] ;
							_wp setWaypointFormation "Column";
							_wp setWaypointBehaviour "SAD";
							_wp setWaypointCombatMode "RED";
							_wp setWaypointCompletionRadius 1;
							_wp waypointAttachObject _x;
							_wp setwaypointHousePosition _i;
							_wp setWaypointType "MOVE";

						};
					} foreach _buildings;
					if(count _buildings > 0 ) then
					{
						_wp setWaypointType "CYCLE";
					};			
				};				
				
				//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				_logDetail = format ["[OCCUPATION Military]:: Spawning %1 AI in at %2 to patrol",_aiCount,_spawnPosition];
                [_logDetail] call SC_fnc_log;

				if(SC_mapMarkers) then 
				{
					_marker = createMarker [format ["%1", _foundBuilding],_pos];
					_marker setMarkerShape "Icon";
					_marker setMarkerSize [3,3];
					_marker setMarkerType "mil_dot";
					_marker setMarkerBrush "Solid";
					_marker setMarkerAlpha 0.5;
					_marker setMarkerColor "ColorRed";
					_marker setMarkerText "Occupied Military Area";	
				};		
				_okToSpawn = false;			
			};	
		};
    };
};
_logDetail = "[OCCUPATION Military]: Ended";
[_logDetail] call SC_fnc_log;
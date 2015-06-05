// Airshot trainer by athairus

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = {

    name = "Airshot Trainer",
    author = "athairus",
    description = "A plugin designed to assist in tf2 airshot and other projectile weapon training",
    version = "0.1 alpha",
    url = "http://athair.us/"

};

int g_GlowSprite;
int g_iToolsVelocity;
Handle g_hGravity;
bool ticktock;
float targetLocPrev[32][3];
int crosshairEntity[32];
int crosshairSpriteEntity[32];
int shotsfired = 1;
int numhits = 0;

public void OnMapStart() {
    g_GlowSprite = PrecacheModel( "sprites/healbeam_blue.vmt" );
    //g_GlowSprite = PrecacheModel( "sprites/light_glow03.vmt" );
    Event_RoundStart( INVALID_HANDLE, "asdf", true );

}
public void Event_RoundStart( Handle hEvent, const char[] szEventName, bool bDontBroadcast ) {
    // Create prop_physics entities
    for( int target = 0; target < 32; target++ ) {

        float foo = -16.0 + target * 8;
        float origin[ 3 ];
        origin[ 0 ] = foo;

        char crosshairName[ 64 ];
        Format( crosshairName, sizeof( crosshairName), "crosshair_%d", target );

        crosshairEntity[ target ] = CreateEntityByName( "prop_physics" );
        DispatchKeyValue( crosshairEntity[ target ], "targetname", crosshairName );
        SetEntityMoveType( crosshairEntity[ target ], MOVETYPE_NOCLIP ); 
        TeleportEntity( crosshairEntity[ target ], NULL_VECTOR, NULL_VECTOR, NULL_VECTOR );
        //PrintToServer( "PHYSICS target = %d, name = %s, entityid = %d\n", target, crosshairName, crosshairEntity[ target ] );
    }
    

    
    // Create env_sprite entities
    for( int target = 0; target < 32; target++ ) {

        char crosshairName[ 64 ];
        Format( crosshairName, sizeof( crosshairName), "crosshair_%d", target );

        char spriteName[ 64 ];
        Format( spriteName, sizeof( spriteName ), "sprite_%d", target );
        
        crosshairSpriteEntity[ target ] = CreateEntityByName( "env_sprite" );
        DispatchKeyValueVector( crosshairSpriteEntity[ target ], "origin", NULL_VECTOR );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "targetname", spriteName );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "spawnflags", "0" );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "scale", "2" );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "rendermode", "5" );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "rendercolor", "0 255 0" );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "renderamt", "255" );
        DispatchKeyValue( crosshairSpriteEntity[ target ], "model", "vgui/crosshairs/crosshair2.vmt" );
        DispatchSpawn( crosshairSpriteEntity[ target ] );
        AcceptEntityInput( crosshairSpriteEntity[ target ], "ShowSprite" );
        //PrintToServer( "SPRITE target = %d, name = %s, entityid = %d\n", target, spriteName, crosshairSpriteEntity[ target ] );

        DispatchKeyValue( crosshairSpriteEntity[ target ], "parentname", crosshairName );
        SetVariantString( crosshairName );
        AcceptEntityInput( crosshairSpriteEntity[ target ], "SetParent" ); 
    }
}

public void OnClientPutInServer( int client ) {
    SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
    //SDKHook( client, SDKHook_OnPlayerRunCmd, OnPlayerRunCmd );
}
 
public void OnGameFrame() {
    for( int player = 1; player <= MaxClients; player++ ) {     
        if( ConnectedAliveNotSpec( player ) && !( IsFakeClient( player ) ) ) {      

            // iterate through possible targets (including bots)
            for( int target = 1; target <= MaxClients; target++ ) {
                if( ConnectedAliveNotSpec( target ) && ( player != target ) ) {     
                    
                    // calculate airshot location, send to player
                    float crosshairLoc[ 3 ];
                    PredictTarget( player, target, crosshairLoc, 5 );
                    // TE_SetupGlowSprite( crosshairLoc, g_GlowSprite, 0.1, 0.4, 255 );
                    // TE_SendToClient( player );                 

                    float targetLoc[ 3 ], targetVel[ 3 ];

                    // get target's location and velocity
                    GetClientAbsOrigin( target, targetLoc );

                    // some bots (like the ones on tr_walkway) don't return proper velocity data, so calculate their velocity manually 
                    GetVelocity( targetVel, targetLoc, targetLocPrev[ target ], GetTickInterval() ); 
                    for( int x = 0; x < 3; x++ ) targetLocPrev[ target ][ x ] = targetLoc[ x ];
                    TeleportEntity( crosshairEntity[ target ], crosshairLoc, NULL_VECTOR, targetVel );
                        
                }
            }

            // PrintToServer( "Ratio: %f, numhits=%d shotsfired=%d", ( numhits / shotsfired ), numhits, shotsfired );
        }
    }    
    if( ticktock ) ticktock = false;
    else ticktock = true;
}

public void OnPluginStart() {
    
    char sGameType[ 16 ];
    GetGameFolderName( sGameType, sizeof( sGameType ) );

    if( !StrEqual( sGameType, "tf", true ) ) 
        SetFailState( "This plugin is for TF2 only." );

    g_iToolsVelocity = FindSendPropInfo( "CBasePlayer", "m_vecVelocity[0]" );

    g_hGravity = FindConVar( "sv_gravity" );
    if( g_hGravity == INVALID_HANDLE ) {
        SetFailState( "Unable to find convar: sv_gravity" );
    }
    ticktock = true;

    //HookEvent( "round_start", Event_RoundStart );  
    HookEventEx( "teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy );

}

public void OnPluginEnd() {
    for( int target = 0; target < 32; target++ ) {
        AcceptEntityInput( crosshairEntity[ target ], "Deactivate" );
        AcceptEntityInput( crosshairEntity[ target ], "Kill" );
        AcceptEntityInput( crosshairSpriteEntity[ target ], "Deactivate" );
        AcceptEntityInput( crosshairSpriteEntity[ target ], "Kill" );
    }
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon ) {
    if( ( buttons & IN_ATTACK ) == IN_ATTACK ) {
        shotsfired++;
    }
    return Plugin_Continue;
}

public Action OnTakeDamage( int victim, int &attacker, int &inflictor, float &damage, int &damagetype ) {
    if( ConnectedAliveNotSpec( victim ) && ( IsFakeClient( victim ) ) ) {
        numhits++;
    }
    return Plugin_Continue;
}

bool ConnectedAliveNotSpec( int player ) {
    return ( IsValidClient( player ) && IsPlayerAlive( player ) && GetClientTeam( player ) > 1 );
}

stock bool IsValidClient( int iClient ) {
    if( iClient <= 0 ) return false;
    if( iClient > MaxClients ) return false;
    return IsClientInGame( iClient );
}

void PredictTarget( int player, int target, float out[ 3 ], int passes ) {

    float playerLoc[ 3 ];

    float targetLoc[ 3 ];
    float targetVel[ 3 ];

    // get current weapon's projectile velocity
    float projectileVel = GetProjectileVelocity( player );

    // get gravity
    int g = GetConVarInt( g_hGravity ) * -1;

    // get player's location
    GetClientAbsOrigin( player, playerLoc );

    // get target's location and velocity
    GetClientAbsOrigin( target, targetLoc );

    // some bots (like the ones on tr_walkway) don't return proper velocity data, so calculate their velocity manually 
    if( IsFakeClient( target ) ) {
        GetVelocity( targetVel, targetLoc, targetLocPrev[ target ], GetTickInterval() ); 
        for( int x = 0; x < 3; x++ ) targetLocPrev[ target ][ x ] = targetLoc[ x ];
    }
    else for ( int x = 0; x < 3; x++ ) targetVel[ x ] = GetEntDataFloat( target, g_iToolsVelocity + ( x * 4 ) );
    

    float distance, time, gfactor;

    float distanceToGround = GetClientDistanceToGround( target );
    float minDistance = 20.0;


    // calculate the ideal location using n passes
    for( int i = 0; i < passes; i++ ) {

        // calculate travel time by projectile from player to target
        if( i == 0 ) distance = GetVectorDistance( playerLoc, targetLoc );
            else distance = GetVectorDistance( playerLoc, out );
        if( projectileVel != 0.0 ) time = distance / projectileVel;
        else time = 0.0; // hitscan or melee weapon, no travel time

        // compensate for weapon warmup and latency on final pass
        if( i == passes - 1 ) {
            time += GetWarmup( player );
            time += GetClientAvgLatency( player, NetFlow_Both ) / 2;             
        }

        // extrapolate along the trajectory (time) seconds ahead
        out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
        out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;

        // determine if gravity should be accounted for or not
        gfactor = 0.5 * g * time * time;
        if( distanceToGround < minDistance ) gfactor = 0.0;

        out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

    }

    // raise target to chest level, most tf2 class models are 100 HU tall
    out[ 2 ] += 50; 

    //if( player != target && ticktock ) TeleportEntity( crosshairEntity[ target ], out, NULL_VECTOR, targetVel );
    //if( ConnectedAliveNotSpec( target ) && ConnectedAliveNotSpec( player ) ) AcceptEntityInput( crosshairSpriteEntity[ target ], "ShowSprite" );
    //else AcceptEntityInput( crosshairSpriteEntity[ target ], "HideSprite" );

}

void GetVelocity( float out[ 3 ], float current[ 3 ], float previous[ 3 ], float delta ) {
    for( int x = 0; x < 3; x++ ) out[ x ] = ( current[ x ] - previous[ x ] ) / delta;
}

float GetWarmup( int player ) {
    int weapon = GetEntPropEnt( player, Prop_Send, "m_hActiveWeapon" );

    switch( GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) ) {

        case 44:  // sandman
            return 0.25;
        case 648: // the wrap assassin
            return 0.25;

        case 812: // flying guillotine
            return 0.25;
        case 833: // flying guillotine (genuine)
            return 0.25;
    }
    return 0.0;
}


float GetProjectileVelocity( int player ) {
    float pv = 0.0; // if not changed, current weapon is a hitscan/melee weapon

    int weapon = GetEntPropEnt( player, Prop_Send, "m_hActiveWeapon" );


    // http://wiki.teamfortress.com/wiki/Projectiles
    // http://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes

    switch( GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) ) {
        case 56: // huntsman
            pv = 2600.0;
        case 305: // crusader's crossbow
            pv = 2400.0;

        case 44:  // sandman
            pv = 3000.0;
        case 648: // the wrap assassin
            pv = 3000.0;

        case 812: // flying guillotine
            pv = 3000.0;
        case 833: // flying guillotine (genuine)
            pv = 3000.0;

        case 441: // cow mangler 5000
            pv = 1100.0;

        case 442: // righteous bison
            pv = 1200.0;
        case 588: // pomson 6000
            pv = 1200.0;

        case 39: // flare gun 
            pv = 2000.0;
        case 740: // scorch shot 
            pv = 2000.0;
        case 351: // detonator
            pv = 2000.0;

        case 595: // manmelter
            pv = 3000.0;

        case 19:  // grenade laucher
            pv = 1220.0;
        case 206: // renamed gl
            pv = 1220.0;

        case 308: // loch-n-load
            pv = 1525.0;

        case 996: // loose cannon
            pv = 1811.0;

        case 58: // jarate
            pv = 935.0;
        case 222: // mad milk
            pv = 935.0;

        case 18:  // rocket launcher
            pv = 1100.0;
        case 205: // renamed rl
            pv = 1100.0;
        case 228: // black box
            pv = 1100.0;
        case 237: // rocket jumper
            pv = 1100.0;
        case 513: // the orginal
            pv = 1100.0;
        case 730: // beggar's bazooka
            pv = 1100.0;

        case 127: // direct hit
            pv = 1540.0;

        case 414: // liberty launcher
            pv = 1540.0;

        case 581: // MONOCULUS
            pv = 1100.0;

        case 140: // wrangler (level 3 rockets)
            pv = 1100.0;

        case 20: // stickybomb launcher
            pv = 2410.0;
        case 207: // stickybomb launcher (renamed/strange)
            pv = 2410.0;
        case 130: // scottish resistance
            pv = 2410.0;
        case 265: // sticky jumper
            pv = 2410.0;

        case 17: // syringe gun
            pv = 1000.0;
        case 204: // syringe gun (renamed/strange)
            pv = 1000.0;
        case 36: // blutsauger
            pv = 1000.0;
        case 412: // overdose
            pv = 1000.0;

        case 997: // rescue ranger
            pv = 2400.0;

    }

    return pv;
}


stock float GetClientDistanceToGround( int client ) {

    // Player is already standing on the ground?
    if( GetEntPropEnt( client, Prop_Send, "m_hGroundEntity" ) == 0 )
        return 0.0;
    
    float fOrigin[ 3 ], fGround[ 3 ];
    GetClientAbsOrigin( client, fOrigin );
    
    fOrigin[ 2 ] += 10.0;
    
    TR_TraceRayFilter( fOrigin, view_as<float>( { 90.0, 0.0, 0.0 } ), MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client );
    if ( TR_DidHit() ) {
        TR_GetEndPosition( fGround );
        fOrigin[ 2 ] -= 10.0;
        return GetVectorDistance( fOrigin, fGround );
    }
    return 0.0;
}

public bool TraceRayNoPlayers( int entity, int mask, any data ) {

    if( entity == data || ( entity >= 1 && entity <= MaxClients ) ) {
        return false;
    }
    return true;
}  

public bool Eyetest_TraceFilter( int entity, int mask ) {
    return entity > MaxClients;
}

public bool allowAll( int entity, int mask ) {
    return true;
}

/*
TODO:
- add support for instantly calculating where to aim the second rocket after the first one is fired
- offer usable targets when target is on the ground
    - if the crosshairs go below the ground, the impact point will be the ideal target for the next few hundred ms
- air strafing compensation
- add a second crosshair that predicts the ideal airshot location if the enemy were to rocket jump at that instant
- draw a vertical line to help with proper horizontal aiming
- dual sided crosshairs for (unpredictable) horizontal movement
- draw an arc, place crosshairs along arc (good for air straifing)
- improve sticky launcher prediction, constantly check charge level and return appropiate velocity for that
- give more accurate results for projectile weapons that arc
- the more an enemy dances around, the fuzzier the target should be


*/

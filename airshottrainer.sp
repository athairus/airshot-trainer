// airshot trainer by whiplash

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#include <smlib>


public Plugin:myinfo = {

    name = "Airshot Trainer",
    author = "whiplash",
    description = "A plugin designed to assist in tf2 airshot and other projectile weapon training",
    version = "0.1 alpha",
    url = "http://o0whiplash0o.net/projects/tf2/airshottrainer"

};

new g_GlowSprite;
new g_iToolsVelocity;
new Handle:g_hGravity;
new bool:ticktock;

public OnMapStart() {
    g_GlowSprite = PrecacheModel( "sprites/healbeam_blue.vmt" );
    //g_GlowSprite = PrecacheModel( "sprites/light_glow03.vmt" );
}
 
public OnGameFrame() {
    for( new player = 1; player <= MaxClients; player++ ) {     
        if( ConnectedAliveNotSpec( player ) && !( IsFakeClient( player ) ) ) {      

            // iterate through possible targets (including bots)
            for( new target = 1; target <= MaxClients; target++ ) {
                if( ConnectedAliveNotSpec( target ) && ( player != target ) ) {     
                    
                    // calculate airshot location, send to player
                    new Float:glowSpriteLocation[ 3 ];
                    PredictTarget( player, target, glowSpriteLocation, 3 );
                    TE_SetupGlowSprite( glowSpriteLocation, g_GlowSprite, 0.1, 0.4, 255 );
                    TE_SendToClient( player );                    
                        
                }
            }
        }
    }    
    if( ticktock ) ticktock = false;
    else ticktock = true;
}

public OnPluginStart() {
    
    new String:sGameType[ 16 ];
    GetGameFolderName( sGameType, sizeof( sGameType ) );

    if( !StrEqual( sGameType, "tf", true ) ) 
        SetFailState( "This plugin is for TF2 only." );
    
    // LoadTranslations( "common.phrases.txt" );


    g_iToolsVelocity = FindSendPropInfo( "CBasePlayer", "m_vecVelocity[0]" );

    g_hGravity = FindConVar( "sv_gravity" );
    if( g_hGravity == INVALID_HANDLE ) {
        SetFailState( "Unable to find convar: sv_gravity" );
    }
    ticktock = true;

}

ConnectedAliveNotSpec( player ) {
    return ( IsValidClient( player ) && IsPlayerAlive( player ) && GetClientTeam( player ) > 1 );
}

stock bool:IsValidClient( iClient ) {
    if( iClient <= 0 ) return false;
    if( iClient > MaxClients ) return false;
    return IsClientInGame( iClient );
}


PredictAirshotLocation( player, target, Float:out[ 3 ] ) {
    new Float:playerLoc[ 3 ];
    new Float:playerVel[ 3 ];

    new Float:targetLoc[ 3 ];
    new Float:targetVel[ 3 ];

    new Float:projectileVel = 1100.0;   // hard-coded to rocket launcher (1100) for now
    new Float:g = -800.0;               // hard-coded to default tf2 gravity (800) for now

    GetClientAbsOrigin( player, playerLoc );
    for ( new x = 0; x < 3; x++ ) playerVel[ x ] = GetEntDataFloat( player, g_iToolsVelocity + ( x * 4 ) );

    GetClientAbsOrigin( target, targetLoc );
    for ( new x = 0; x < 3; x++ ) targetVel[ x ] = GetEntDataFloat( target, g_iToolsVelocity + ( x * 4 ) );

    // determine player's weapon, set projectileVel accordingly
    projectileVel = GetProjectileVelocity( player );

    // find traveltime by rocket from player to target
    new Float:distance;
    distance = GetVectorDistance( playerLoc, targetLoc );
    distance = FloatAbs( distance );

    new Float:time;
    if( projectileVel != 0 ) {
        time = distance / projectileVel;
    }
    else time = 0.0;

    new Float:distanceToGround = GetClientDistanceToGround( target );
    new Float:minDistance = 20.0;

    // extrapolate along target's trajectory to determine final point
    out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
    out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
    new Float:gfactor = 0.5 * g * time * time;
    //if( distanceToGround < minDistance ) gfactor = 0.0;
    out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

    // do a second pass
    distance = GetVectorDistance( playerLoc, out );
    distance = FloatAbs( distance );
    if( projectileVel != 0 ) time = distance / projectileVel;
    else time = 0.0;
    out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
    out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
    gfactor = 0.5 * g * time * time;
    //if( distanceToGround < minDistance ) gfactor = 0.0;
    out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

    // do a third pass
    distance = GetVectorDistance( playerLoc, out );
    distance = FloatAbs( distance );
    if( projectileVel != 0 ) time = distance / projectileVel;
    else time = 0.0;
    //time += GetClientAvgLatency( player, NetFlow_Both ); // compensate for latency
    out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
    out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
    gfactor = 0.5 * g * time * time;
    //if( distanceToGround < minDistance ) gfactor = 0.0;
    out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

    // do a fourth pass
    distance = GetVectorDistance( playerLoc, out );
    distance = FloatAbs( distance );
    if( projectileVel != 0 ) time = distance / projectileVel;
    else time = 0.0;
    time += GetClientAvgLatency( player, NetFlow_Both ); // compensate for latency
    out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
    out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
    gfactor = 0.5 * g * time * time;
    //if( distanceToGround < minDistance ) gfactor = 0.0;
    out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

    /*
    // do a fifth pass... overkill?
    distance = GetVectorDistance( playerLoc, out );
    distance = FloatAbs( distance );
    if( projectileVel != 0 ) time = distance / projectileVel;
    else time = 0.0;
    time += GetClientAvgLatency( player, NetFlow_Both ); // compensate for latency
    out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
    out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
    gfactor = 0.5 * g * time * time;
    if( distanceToGround < minDistance ) gfactor = 0.0;
    out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;
    */

    
    
    // check if this target is below the ground

    new Float:fGround[ 3 ] = { 0.0, 0.0, -100000.0 };
    out[ 2 ] += 10; 
    TR_TraceRayFilter( out, Float:{ 90.0, 0.0, 0.0 }, MASK_PLAYERSOLID, RayType_Infinite, allowAll );
    out[ 2 ] -= 10; 
    if( !TR_DidHit() ) { // below ground or something else
        //TR_GetEndPosition( fGround );

        // move z value to target level
        out[ 2 ] = targetLoc[ 2 ]; 

        // repeat process
        out[ 2 ] += 10; 
        TR_TraceRayFilter( out, Float:{ 90.0, 0.0, 0.0 }, MASK_PLAYERSOLID, RayType_Infinite, allowAll );
        out[ 2 ] -= 10; 
        if( TR_DidHit() ) { // if that worked...
            TR_GetEndPosition( fGround );
            out[ 2 ] = fGround[ 2 ];
        }
    }
    //new Float:gDistance = GetGround( out, fGround );
    //if( out[ 2 ] < fGround[ 2 ] ) out[ 2 ] = fGround[ 2 ];

    //PrintToConsole( player, "out:{ %f, %f, %f } \n\tground:{ %f, %f, %f } ", out[ 0 ], out[ 1 ], out[ 2 ], fGround[ 0 ], fGround[ 1 ], fGround[ 2 ] );

    // raise target to chest level, most tf2 class models are 100 HU tall
    out[ 2 ] += 50; 

}

PredictTarget( player, target, Float:out[ 3 ], passes ) {

    new Float:playerLoc[ 3 ];
    new Float:playerVel[ 3 ];

    new Float:targetLoc[ 3 ];
    new Float:targetVel[ 3 ];

    // get current weapon's projectile velocity
    new Float:projectileVel = GetProjectileVelocity( player );

    // get gravity
    new g = GetConVarInt( g_hGravity ) * -1;

    // get player's location and velocity
    GetClientAbsOrigin( player, playerLoc );
    for( new x = 0; x < 3; x++ ) playerVel[ x ] = GetEntDataFloat( player, g_iToolsVelocity + ( x * 4 ) );

    // get target's location and velocity
    GetClientAbsOrigin( target, targetLoc );
    for( new x = 0; x < 3; x++ ) targetVel[ x ] = GetEntDataFloat( target, g_iToolsVelocity + ( x * 4 ) );

    if( ticktock ) {
        //targetVel[ 0 ] = -1 * targetVel[ 0 ];
        //targetVel[ 1 ] = -1 * targetVel[ 1 ];
    }

    new Float:distance;
    new Float:time;
    new Float:gfactor;

    // calculate the ideal location using n passes
    for( new i = 0; i < passes; i++ ) {

        // calculate travel time by projectile from player to target
        if( i == 0 ) distance = GetVectorDistance( playerLoc, targetLoc );
            else distance = GetVectorDistance( playerLoc, out );
        if( projectileVel != 0.0 ) time = distance / projectileVel;
        else time = 0.0; // hitscan or melee weapon, no travel time

        // compensate for latency
        if( i == passes - 1 ) time += GetClientAvgLatency( player, NetFlow_Both ); 

        // extrapolate along the trajectory (time) seconds ahead
        out[ 0 ] = targetLoc[ 0 ] + targetVel[ 0 ] * time;
        out[ 1 ] = targetLoc[ 1 ] + targetVel[ 1 ] * time;
        gfactor = 0.5 * g * time * time;
        out[ 2 ] = targetLoc[ 2 ] + targetVel[ 2 ] * time + gfactor;

        //if( i == 0 ) PrintToConsole( player, "pass 0: distance:%f\ntime:%f\n", distance, time );
        //if( i == passes - 1 ) PrintToConsole( player, "final pass: distance:%f\ntime:%f\n", distance, time );

    }

    // raise target to chest level, most tf2 class models are 100 HU tall
    out[ 2 ] += 50; 

}


Float:GetProjectileVelocity( player ) {
    new Float:pv = 0.0; // if not changed, current weapon is a hitscan/melee weapon

    new weapon = GetEntPropEnt( player, Prop_Send, "m_hActiveWeapon" );

    switch( GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) ) {
        case 56: // huntsman
            pv = 2600.0;

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

        case 19:  // grenade laucher
            pv = 1220.0;
        case 206: // renamed gl
            pv = 1220.0;

    }

    return pv;
}


stock Float:GetClientDistanceToGround( client ) {

    // Player is already standing on the ground?
    if( GetEntPropEnt( client, Prop_Send, "m_hGroundEntity" ) == 0 )
        return 0.0;
    
    new Float:fOrigin[ 3 ], Float:fGround[ 3 ];
    GetClientAbsOrigin( client, fOrigin );
    
    fOrigin[ 2 ] += 10.0;
    
    TR_TraceRayFilter( fOrigin, Float:{ 90.0, 0.0, 0.0 }, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client );
    if ( TR_DidHit() ) {
        TR_GetEndPosition( fGround );
        fOrigin[ 2 ] -= 10.0;
        return GetVectorDistance( fOrigin, fGround );
    }
    return 0.0;
}

public bool:TraceRayNoPlayers( entity, mask, any:data ) {

    if( entity == data || ( entity >= 1 && entity <= MaxClients ) ) {
        return false;
    }
    return true;
}  

public bool:Eyetest_TraceFilter(entity, mask) {
    return entity > MaxClients;
}

public bool:allowAll( entity, mask ) {
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


*/

///===========================================================
///===========================================================
// SourceBans for Contagion. Based on the ZPS version.
//		Written by Johan "JonnyBoy0719" Ehrendahl
///===========================================================
///===========================================================

#include "sbans/lang.as"
#include "sbans/cvars.as"
#include "sbans/net.as"
#include "sbans/comm.as"

//------------------------------------------------------------------------------------------------------------------------//

CSQLConnection@ hConnection = null;
JsonValues@ hJsonData = null;

//------------------------------------------------------------------------------------------------------------------------//

CBaseEntity@ ToBaseEntity( CTerrorPlayer@ pPlayer )
{
	CBasePlayer@ pBasePlayer = pPlayer.opCast();
	CBaseEntity@ pEntityPlayer = pBasePlayer.opCast();
	return pEntityPlayer;
}

//------------------------------------------------------------------------------------------------------------------------//

void OnPluginInit()
{
	// Plugin Data
	PluginData::SetVersion( "2.0" );
	PluginData::SetAuthor( "Johan \"JonnyBoy0719\" Ehrendahl" );
	PluginData::SetName( "SourceBans++" );

	// Add our translation file for SourceBans
	Translate::Init();
	Translate::AddTranslation( "sourcebans" );
	Translate::SetFile( "sourcebans" );

	// Read our json data
	ReadJsonFile();

	// Connect to our database
	SQL::Connect(
		FileSystem::GrabString( hJsonData, "Connection", "host" ),
		FileSystem::GrabInt( hJsonData, "Connection", "port" ),
		FileSystem::GrabString( hJsonData, "Connection", "user" ),
		FileSystem::GrabString( hJsonData, "Connection", "password" ),
		FileSystem::GrabString( hJsonData, "Connection", "database" ),
		OnSQLConnect
	);

	// Convar
	CreateConvars();

	// Hooks
	Events::Player::OnPlayerConnected.Hook( @SBans_PlayerConnected );
	Events::Player::OnPlayerInitSpawn.Hook( @SBans_OnPlayerInitSpawn );	// Called when we spawned for the first time
	Events::Player::OnPlayerSpawn.Hook( @SBans_OnPlayerSpawn );
}

//------------------------------------------------------------------------------------------------------------------------//

void OnSQLConnect( CSQLConnection@ pConnection )
{
	// If our connection was a success, then we can save the CSQLConnection object to a local variable.
	// If not, stop here.
	if ( pConnection.Failed() ) return;

	// Let's set a prefix, so we know it's from SourceBans
	SQL::SetErrorPrefix( pConnection, "SQL Error" );

	// Let's also override the location where we save the mysql errors at
	SQL::SetErrorLocation( pConnection, "sourcebans.log" );

	// We want to know the errors
	SQL::PrintErrorsOnIgnoreQuery( pConnection, true );

	// Apply our value
	@hConnection = pConnection;
}

//------------------------------------------------------------------------------------------------------------------------//

string GetLanguage()
{
	return FileSystem::GrabString( hJsonData, "ServerInfo", "language" );
}

//------------------------------------------------------------------------------------------------------------------------//

void OnPluginUnload()
{
	SQL::Disconnect( hConnection );
	Translate::RemoveTranslation( "sourcebans" );
}

//------------------------------------------------------------------------------------------------------------------------//

void ReadJsonFile()
{
	@hJsonData = FileSystem::ReadFile( "sourcebans" );
	if ( hJsonData is null )
	{
		@hJsonData = FileSystem::CreateJson();

		FileSystem::Write( hJsonData, "Connection", "host", "localhost" );
		FileSystem::Write( hJsonData, "Connection", "user", "root" );
		FileSystem::Write( hJsonData, "Connection", "password", "" );
		FileSystem::Write( hJsonData, "Connection", "port", 0 );
		FileSystem::Write( hJsonData, "Connection", "database", "mydatabase" );
		FileSystem::Write( hJsonData, "Connection", "prefix", "sb" );

		FileSystem::Write( hJsonData, "ServerInfo", "language", "english" );
		FileSystem::Write( hJsonData, "ServerInfo", "id", -1 );
		FileSystem::Write( hJsonData, "ServerInfo", "website", "contagion-game.com" );

		FileSystem::CreateFile( "sourcebans", hJsonData );
	}
}

//------------------------------------------------------------------------------------------------------------------------//

int GrabServerID() { return FileSystem::GrabInt( hJsonData, "ServerInfo", "id" ); }
string GrabDatabasePrefix() { return FileSystem::GrabString( hJsonData, "Connection", "prefix" ); }
string GrabServerWebsite() { return FileSystem::GrabString( hJsonData, "ServerInfo", "website" ); }

//------------------------------------------------------------------------------------------------------------------------//

HookReturnCode SBans_PlayerConnected( CTerrorPlayer@ pPlayer )
{
	// Ban check doesn't check for msg print check, only mute/gag does
	NetData nData;
	nData.Write( pPlayer.entindex() );
	nData.Write( 1 );
	Network::CallFunction( "SBans_CheckBanStatus", nData );
	return HOOK_CONTINUE;
}

//------------------------------------------------------------------------------------------------------------------------//

HookReturnCode SBans_OnPlayerInitSpawn( CTerrorPlayer@ pPlayer )
{
	NetData nData;
	nData.Write( pPlayer.entindex() );
	nData.Write( 0 );
	nData.Write( 1 );
	Network::CallFunction( "SBans_CheckBanStatus", nData );
	return HOOK_CONTINUE;
}

//------------------------------------------------------------------------------------------------------------------------//

HookReturnCode SBans_OnPlayerSpawn( CTerrorPlayer@ pPlayer )
{
	// Set this to false, since we are going to check it again.
	// Since we may have ungagged or unmuted this player via the SBans page,
	// or that the time expired.
	AdminSystem.Mute( pPlayer, 1, false, "" );
	AdminSystem.Gag( pPlayer, 1, false, "" );

	NetData nData;
	nData.Write( pPlayer.entindex() );
	nData.Write( 0 );
	nData.Write( 0 );	// We don't want to see any messages being printed
	Network::CallFunction( "SBans_CheckBanStatus", nData );
	return HOOK_CONTINUE;
}

//------------------------------------------------------------------------------------------------------------------------//

string GetPluginTag() {	return Translate::GrabTranslation( GetLanguage(), "SB_Tag" ); }

//------------------------------------------------------------------------------------------------------------------------//

void SBans_SendTextAll( string strMsg )
{
	Chat.PrintToChat( all, GetPluginTag() + " " + strMsg );
}

//------------------------------------------------------------------------------------------------------------------------//

void SBans_SendTextToConsole( CTerrorPlayer@ pPlayer, string strMsg )
{
	if ( pPlayer is null )
	{
		// If player is null, log it instead
		Chat.PrintToConsole( GetPluginTag() + " " + strMsg );
		return;
	}
	//CBasePlayer@ pPlayerEnt = pPlayer.opCast();	// Convert to CBasePlayer
	Chat.PrintToConsolePlayer( pPlayer, GetPluginTag() + " " + strMsg );
}

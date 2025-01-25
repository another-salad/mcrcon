$sessions = New-RconSessionsFromConfigFile
$sessions | Send-ActivePlayersAnnouncement
$sessions | Close-RconSession
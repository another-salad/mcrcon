$sessions = New-RconSessionsFromConfigFile
$msg = "The time is now: $(Get-Date -Format "HH:mm:ss"). Are you still playing?"
$sessions | Send-ServerMsg -Message $msg
$sessions | Close-RconSession

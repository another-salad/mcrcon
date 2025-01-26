$sessions = New-RconSessionsFromConfigFile
$msg = "$(Get-Date -Format "HH:mm:ss")  Are you still playing?"
$sessions | Send-ServerMsg -Message $msg
$sessions | Close-RconSession

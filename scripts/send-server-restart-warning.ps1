param (
    $RestartWarningTimeInMins = 1
)

$sessions = New-RconSessionsFromConfigFile
$msg = "$(Get-Date -Format "HH:mm:ss")  The server will restart in $RestartWarningTimeInMins minute(s). Please get somewhere safe and log off."
$sessions | Send-ServerMsg -Message $msg
$sessions | Close-RconSession
$sessions = New-RconSessionsFromConfigFile
$sessions | Get-Players
$sessions | Close-RconSession
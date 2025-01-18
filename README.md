# mcrcon

Powershell 7+ wrapper for RCON (I'll only be testing this with Minecraft Java edition).  
<https://developer.valvesoftware.com/wiki/Source_RCON_Protocol>  

A warning just in case your brain isn't active...  
**Don't port forward RCON, it's not secure, at all.**  
Even on your LAN, maybe consider some firewalling.  
  
## Example saving session configs  
  
```powershell
$sessionConfig = New-RconSessionConfig  
$sessionConfig.PathToServerProperties = "/some/path/server.properties"  
$sessionConfig.Port = 25575  
$sessionConfig.Address = "10.10.0.50"  
$sessionConfig | Add-RconSessionConfig
```  
  
## Example creating sessions from config
  
```powershell
$sessions = New-RconSessionsFromConfigFile
$sessions

Socket                    Address         Port                     Password
------                    -------         ----                     --------
System.Net.Sockets.Socket 10.10.0.50      25575 System.Security.SecureString
System.Net.Sockets.Socket 10.10.0.51      25575 System.Security.SecureString
```
  
## Example MC command  
  
```powershell
$sessions | get-Players

Session       ServerAddress        Response
-------       -------------        --------
{RconSession} 10.10.0.50:25575 There are 1 of a max of 10 players online: SomeGuy (Some-Tasty-Guid)…
{RconSession} 10.10.0.51:25575 There are 0 of a max of 10 players online: …
```

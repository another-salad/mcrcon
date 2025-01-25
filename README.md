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

Session       ServerAddress        PlayerCount Players
-------       -------------        ----------- -------
{RconSession} 10.10.0.50:25575               1 {@{Username=TotalyRealPerson; UUID=cfa1e851-50d5-4440-926d-ab99951fa3b3}}
{RconSession} 10.10.0.51:25575               0 {}

```

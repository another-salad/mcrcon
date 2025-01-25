# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol

# Constants for RCon packet types
enum RConPacketType {
    SERVERDATA_AUTH = 3
    SERVERDATA_AUTH_RESPONSE = 2
    SERVERDATA_EXECCOMMAND = 2  # Not a typo, the same as the response
    SERVERDATA_RESPONSE_VALUE = 0
}

$script:SessionConfigs = "$($env:HOME)/rconsessionconfig.xml"

# Very Minecraft specific
class RconSessionConfig {
    hidden [string] $_id = (New-Guid).Guid
    [string]$Address
    [int]$Port
    [string]$PathToServerProperties
}

Function New-RconSessionConfig {
    [RconSessionConfig]::new()
}

Function Import-RconSessionConfigs {
    if (Test-Path -Path $script:SessionConfigs) {
        return Import-Clixml -Path $script:SessionConfigs
    } else {
        # create the clixml file
        $null | Export-Clixml -Path $script:SessionConfigs -Force
        return @()
    }
}

Function Add-RconSessionConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSessionConfig[]]$Configs
    )
    begin {
        $currentConfigs = Import-RconSessionConfigs
        $currentConfigsList = [System.Collections.ArrayList]@($currentConfigs)
    }
    process {
        foreach ($config in $Configs) {
            if ($config._id -notin $currentConfigsList._id) {
                [void]$currentConfigsList.Add($config)
            }
        }
    }
    end {
        $currentConfigsList | Export-Clixml -Path $script:SessionConfigs -Force
    }
}

Function Remove-RconSessionConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSessionConfig[]]$Configs
    )
    begin {
        $currentConfigs = Import-RconSessionConfigs
        $currentConfigsList = [System.Collections.ArrayList]@($currentConfigs)
    }
    process {
        foreach ($config in $Configs) {
            $currentConfigsList = $currentConfigsList | Where-Object { $_._id -ne $config._id }
        }
    }
    end {
        $currentConfigsList | Export-Clixml -Path $script:SessionConfigs -Force
    }
}


class RconCommand {
    [string]$Command
    [ValidateSet(2, 3)]
    [int]$Type = ([int][RConPacketType]::SERVERDATA_EXECCOMMAND)

    RconCommand([string]$Command, [int]$Type) {
        $this.Command = $Command
        $this.Type = $Type
    }

    RconCommand([string]$Command) {
        $this.Command = $Command
    }
}

Function New-RconCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Command,
        [Parameter()]
        [int]$Type = ([int][RConPacketType]::SERVERDATA_EXECCOMMAND)
    )
    [RconCommand]::new($Command, $Type)
}

class RconSession {
    hidden [string] $_id = (New-Guid).Guid
    [System.Net.Sockets.Socket]$Socket
    [string]$Address
    [int]$Port
    [securestring]$Password

    RconSession([string]$Address, [int]$Port, [securestring]$Password) {
        $this.Address = $Address
        $this.Port = $Port
        $this.Password = $Password
        $this.Connect()
        $this.Authenticate()
    }

    [void] Connect() {
        $_Socket = [System.Net.Sockets.Socket]::New(
            [System.Net.Sockets.AddressFamily]::InterNetwork,
            [System.Net.Sockets.SocketType]::Stream,
            [System.Net.Sockets.ProtocolType]::Tcp
        )
        $_Socket.Connect($this.Address, $this.Port)
        $this.Socket = $_Socket
    }

    # Would need testing against other Rcon implementations (currently only Minecraft Java Edition)
    [void] Authenticate() {
        $ResponseBuffer = $this.Send((New-RconCommand -Command ($this.Password | ConvertFrom-SecureString -AsPlainText) -Type ([int][RConPacketType]::SERVERDATA_AUTH)))
        if ([BitConverter]::ToInt32($ResponseBuffer[4..7], 0) -eq -1) {
            Write-Error "Authentication failed, bad password?"
        }
    }

    [byte[]] Packet([RconCommand]$RconCommand) {
        $PktId = [byte[]]::new(4)
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($PktId)
        $PktCmdType = [byte[]]::new(4)
        $PktCmdType[0] = $RconCommand.Type
        # The command string, null terminated
        $PktCmdPayload = [System.Text.Encoding]::ASCII.GetBytes($RconCommand.Command) + 0x00
        $PktSize = [BitConverter]::GetBytes($PktCmdPayload.Length + 9)
        # The full packet, in the required structure
        return $PktSize + $PktId + $PktCmdType + $PktCmdPayload + 0x00
    }

    [byte[]] Send([RconCommand]$RconCommand) {
        if (-not $this.Socket.Connected) {
            $this.Connect()
            if (-not $RconCommand.Type -eq [int][RConPacketType]::SERVERDATA_AUTH) {
                Write-Warning "Socket was dead, attempting to Re-Authenticate"
                $this.Authenticate()
            }
        }
        $this.Socket.Send($this.Packet($RconCommand)) | Out-Null
        $ResponseBuffer = [byte[]]::new(4096)
        $this.Socket.Receive($ResponseBuffer) | Out-Null
        return $ResponseBuffer
    }

    [void] Close() {
        if ($null -ne $this.Socket -and $this.Socket.Connected) {
            $this.Socket.Close()
        }
        $this.Socket = $null
    }

}

Function New-RconSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Address,
        [Parameter(Mandatory)]
        [int]$Port,
        [Parameter(Mandatory)]
        [securestring]$Password
    )
    [RconSession]::new($Address, $Port, $Password)
}

Function Close-RconSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session
    )
    process {
        $Session | ForEach-Object { $_.Close() }
    }
}

Function Set-InteractiveSessionPassword {
    $Password = Read-Host -Prompt "Enter RCon password" -AsSecureString
    $Password
}

# Minecraft server specific (only tested with Java Edition)
Function Get-RconPasswordFromServerProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerPropertiesPath
    )
    $rgx = '^rcon\.password='
    (Get-Content $ServerPropertiesPath) | Where-Object { $_ -match $rgx  } | ForEach-Object { $_ -replace $rgx , '' } | ConvertTo-SecureString -AsPlainText -Force
}

Function New-RconSessionsFromConfigFile {
    Import-RconSessionConfigs | ForEach-Object {
        New-RconSession -Address $_.Address -Port $_.Port -Password (Get-RconPasswordFromServerProperties -ServerPropertiesPath $_.PathToServerProperties)
    }
}

Function Get-RconResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Buffer,
        [int]$StartIndex = 12
    )
    [System.Text.Encoding]::ASCII.GetString($Buffer[$StartIndex..($Buffer.Length)])
}

Function Send-RconCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession]$Session,
        [Parameter(Mandatory)]
        [RconCommand]$Command
    )
    $resp = $Session.Send($Command)
    Get-RconResponse $resp
}

# Wraps around Send-RconCommand to provide a consistent output object
Function Send-RconCommandWrapper {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session,
        [Parameter(Mandatory)]
        [string]$Command
    )
    begin {
        # This is to combat the odd behaviour I am seeing when accessing the Address property of the session object
        # Without explicitly setting the index of the object being processed, we get OverloadDefinitions for Address
        # rather than its string value.
        $Index = 0
    }
    process {
        [PSCustomObject]@{
            Session = $Session
            ServerAddress = "$($Session[$Index].Address):$($Session.Port)"
            Response = ($Session | Send-RconCommand -Command (New-RconCommand -Command $Command))
        }
        $Index++
    }
}

#region Minecraft Server commands
# https://minecraft.wiki/w/Commands

Function Get-PlayersRaw {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session,
        [switch]$OmmitUUIDs
    )
    begin {
        $Command = if ($OmmitUUID) { "list" } else { "list uuids" }
    }
    process {
        $Session | Send-RconCommandWrapper -Command $Command
    }
}

Function Get-Players {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session
    )
    process {
        $Session | Get-PlayersRaw | ForEach-Object {
            $response = $_.Response
            $reg = [regex]::new("(?<username>\w+) \((?<uuid>\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\)")
            $AllMatches = $reg.Matches($response)
            $players = @()

            foreach ($match in $AllMatches) {
                $username = $match.Groups["username"].Value
                $uuid = $match.Groups["uuid"].Value
                $players += [PSCustomObject]@{
                    Username = $username
                    UUID = $uuid
                }
            }

            [PSCustomObject]@{
                Session = $_.Session
                ServerAddress = $_.ServerAddress
                PlayerCount = $AllMatches.Count
                Players = $players
            }
        }
    }
}

Function Send-ActivePlayersAnnouncement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session
    )
    process {
        $Session | Get-Players | ForEach-Object {
            if ($_.PlayerCount -gt 0) {
                $players = $_.Players | ForEach-Object { $_.Username }
                $players = $players -join ", "
                $Session | Send-RconCommandWrapper -Command "say Active players: $players"
            }
        }
    }
}

Function Send-ServerMsg {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession[]]$Session,
        [Parameter(Mandatory)]
        [string]$Message
    )
    process {
        $Session | Send-RconCommandWrapper -Command "say $Message"
    }
}

#endregion
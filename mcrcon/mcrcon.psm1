# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol

# Constants for RCon packet types
enum RConPacketType {
    SERVERDATA_AUTH = 3
    SERVERDATA_AUTH_RESPONSE = 2
    SERVERDATA_EXECCOMMAND = 2  # Not a typo, the same as the response
    SERVERDATA_RESPONSE_VALUE = 0
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
    [System.Net.Sockets.Socket]$Socket
    [string]$Address
    [int]$Port
    [securestring]$Password

    RconConnection([string]$Address, [int]$Port, [securestring]$Password) {
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

Function Set-InteractiveSessionPassword {
    $Password = Read-Host -Prompt "Enter RCon password" -AsSecureString
    $Password
}

Function Get-RconPasswordFromServerProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerPropertiesPath
    )
    $rgx = '^rcon\.password='
    (Get-Content $ServerPropertiesPath) | Where-Object { $_ -match $rgx  } | ForEach-Object { $_ -replace $rgx , '' } | ConvertTo-SecureString -AsPlainText -Force
}

Function Send-RconCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession]$Session,
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconCommand]$Command
    )
    process {
        $Session.Send($Command)
    }
}

Function Get-Status {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [RconSession]$Session
    )
    process {
        $Session.Send((New-RconCommand -Command "status"))
    }
}

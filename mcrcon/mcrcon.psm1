# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol

# Constants for RCon packet types
enum RConPacketType {
    SERVERDATA_AUTH = 3
    SERVERDATA_AUTH_RESPONSE = 2
    SERVERDATA_EXECCOMMAND = 2  # Not a typo, the same as the response
    SERVERDATA_RESPONSE_VALUE = 0
}

Function New-RConPayloadPacket {
    [CmdletBinding()]
    param (
        # I would love to use the enum here, but it is far to awkward in a ValidateSet
        [Parameter(Mandatory)]
        [ValidateSet(3, 2)]
        [int]$Type,
        [Parameter(Mandatory)]
        [string]$Command
    )
    # 4 bytes for the packet id, and type
    $PktId = [byte[]]::new(4)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($PktId)
    $PktCmdType = [byte[]]::new(4)
    $PktCmdType[0] = $Type
    # The command string, null terminated
    $PktCmdPayload = [System.Text.Encoding]::ASCII.GetBytes($Command) + 0x00
    $PktSize = [BitConverter]::GetBytes($PktCmdPayload.Length + 9)
    # The full packet, in the required structure
    $PktSize + $PktId + $PktCmdType + $PktCmdPayload + 0x00
}

Function New-RawRconSocket {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Address,
        [Parameter(Mandatory)]
        [int]$Port
    )
    $Socket = [System.Net.Sockets.Socket]::New(
        [System.Net.Sockets.AddressFamily]::InterNetwork,
        [System.Net.Sockets.SocketType]::Stream,
        [System.Net.Sockets.ProtocolType]::Tcp
    )
    $Socket.Connect($Address, $Port)
    $Socket
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

Function New-ResponseBuffer {
    [CmdletBinding()]
    param (
        [int]$Size = 4096
    )
    [byte[]]::new($Size)
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
    $Socket = New-RawRconSocket -Address $Address -Port $Port
    $Socket.Send((New-RConPayloadPacket -Type ([int][RConPacketType]::SERVERDATA_AUTH) -Command ($Password | ConvertFrom-SecureString -AsPlainText))) | Out-Null
    $ResponseBuffer = New-ResponseBuffer
    $Socket.Receive($ResponseBuffer) | Out-Null
    if ([BitConverter]::ToInt32($ResponseBuffer[4..7], 0) -eq -1) {
        Write-Error "Authentication failed, bad password?"
    }
    $Socket
}

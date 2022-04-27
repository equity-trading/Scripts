# c:\home\src\Scripts\Get-LocalUsers.ps1
# c:\home\src\Scripts\Get-LocalUsers.ps1 alexe

#    https://gist.github.com/klezVirus/6479d356fa6e6c4cb4b98b480b14dbc9
function Get-StandardUser() {
    param($Sid)
    Switch ($Sid) {
        'S-1-0'         { 'Null Authority' }
        'S-1-0-0'       { 'Nobody' }
        'S-1-1'         { 'World Authority' }
        'S-1-1-0'       { 'Everyone' }
        'S-1-2'         { 'Local Authority' }
        'S-1-2-0'       { 'Local' }
        'S-1-2-1'       { 'Console Logon ' }
        'S-1-3'         { 'Creator Authority' }
        'S-1-3-0'       { 'Creator Owner' }
        'S-1-3-1'       { 'Creator Group' }
        'S-1-3-2'       { 'Creator Owner Server' }
        'S-1-3-3'       { 'Creator Group Server' }
        'S-1-3-4'       { 'Owner Rights' }
        'S-1-4'         { 'Non-unique Authority' }
        'S-1-5'         { 'NT Authority' }
        'S-1-5-1'       { 'Dialup' }
        'S-1-5-2'       { 'Network' }
        'S-1-5-3'       { 'Batch' }
        'S-1-5-4'       { 'Interactive' }
        'S-1-5-6'       { 'Service' }
        'S-1-5-7'       { 'Anonymous' }
        'S-1-5-8'       { 'Proxy' }
        'S-1-5-9'       { 'Enterprise Domain Controllers' }
        'S-1-5-10'      { 'Principal Self' }
        'S-1-5-11'      { 'Authenticated Users' }
        'S-1-5-12'      { 'Restricted Code' }
        'S-1-5-13'      { 'Terminal Server Users' }
        'S-1-5-14'      { 'Remote Interactive Logon' }
        'S-1-5-15'      { 'This Organization ' }
        'S-1-5-17'      { 'This Organization ' }
        'S-1-5-18'      { 'Local System' }
        'S-1-5-19'      { 'NT Authority' }
        'S-1-5-20'      { 'NT Authority' }
        'S-1-5-80-0'    { 'All Services ' }
        'S-1-5-32-544'  { 'BUILTIN\Administrators' }
        'S-1-5-32-545'  { 'BUILTIN\Users' }
        'S-1-5-32-546'  { 'BUILTIN\Guests' }
        'S-1-5-32-547'  { 'BUILTIN\Power Users' }
        'S-1-5-32-548'  { 'BUILTIN\Account Operators' }
        'S-1-5-32-549'  { 'BUILTIN\Server Operators' }
        'S-1-5-32-550'  { 'BUILTIN\Print Operators' }
        'S-1-5-32-551'  { 'BUILTIN\Backup Operators' }
        'S-1-5-32-552'  { 'BUILTIN\Replicators' }
        'S-1-5-32-554'  { 'BUILTIN\Pre-Windows 2000 Compatible Access' }
        'S-1-5-32-555'  { 'BUILTIN\Remote Desktop Users' }
        'S-1-5-32-556'  { 'BUILTIN\Network Configuration Operators' }
        'S-1-5-32-557'  { 'BUILTIN\Incoming Forest Trust Builders' }
        'S-1-5-32-558'  { 'BUILTIN\Performance Monitor Users' }
        'S-1-5-32-559'  { 'BUILTIN\Performance Log Users' }
        'S-1-5-32-560'  { 'BUILTIN\Windows Authorization Access Group' }
        'S-1-5-32-561'  { 'BUILTIN\Terminal Server License Servers' }
        'S-1-5-32-562'  { 'BUILTIN\Distributed COM Users' }
        'S-1-5-32-569'  { 'BUILTIN\Cryptographic Operators' }
        'S-1-5-32-573'  { 'BUILTIN\Event Log Readers' }
        'S-1-5-32-574'  { 'BUILTIN\Certificate Service DCOM Access' }
        'S-1-5-32-575'  { 'BUILTIN\RDS Remote Access Servers' }
        'S-1-5-32-576'  { 'BUILTIN\RDS Endpoint Servers' }
        'S-1-5-32-577'  { 'BUILTIN\RDS Management Servers' }
        'S-1-5-32-578'  { 'BUILTIN\Hyper-V Administrators' }
        'S-1-5-32-579'  { 'BUILTIN\Access Control Assistance Operators' }
        'S-1-5-32-580'  { 'BUILTIN\Access Control Assistance Operators' }
        Default {
            (Get-LocalUser -Sid $Sid).Name
        }
    }
}

function ConvertFrom-Sid {
    param($SID="S-1-5-21-3101668316-195586092-1316055306-1001")
    try {
        $account = (New-Object System.Security.Principal.SecurityIdentifier($SID)).Translate([System.Security.Principal.NTAccount])
        return $account.Value
    }
    catch {
        return "SID $SID not found"
    }
}

function ConvertTo-Sid {
    param
    (
        [Alias('samAccountName')]
        [Parameter(
            HelpMessage='input user of group account name (exclude "/ \ [ ] : ; | = , + * ? < > and space)',
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateLength(1,104)]
        [ValidatePattern('[^\"/\\\[\]:;\|=\,\+\*\?<>\s]', Options='IgnoreCase')]
        [System.String]
        $accountName, 

        [Alias('NTDomain')]
        [Parameter(
            HelpMessage="input NT domain name or FQDN (exclude `" , ~ : ! @ # $ % ^ & ' ( ) { } _ and space)",
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateLength(1,64)]
        [ValidatePattern("^[a-z0-9][^,~:!@#\$%\^\&\'\(\)\{\}_\s]+[^\-]$|\.", Options='IgnoreCase')]
        [System.String]
        $domain
    )
    try {
        if ([string]::IsNullOrEmpty($domain)) {
            $account = New-Object System.Security.Principal.NTAccount($accountName)
        }
        else {
            if ($domain -eq ".") {$domain=$env:computername}
            $account = New-Object System.Security.Principal.NTAccount($domain,$accountName)
        }
        $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
        return $sid.Value
    }
    catch {
        return "Account $accountName does not exist"
    }
}

function Convert-AzureAdObjectIdToSid {
    <#
    .SYNOPSIS
    Convert an Azure AD Object ID to SID
     
    .DESCRIPTION
    Converts an Azure AD Object ID to a SID.
    Author: Oliver Kieselbach (oliverkieselbach.com)
    The script is provided "AS IS" with no warranties.
     
    .PARAMETER ObjectID
    The Object ID to convert
    #>
    
        param([String] $ObjectId)
    
        $bytes = [Guid]::Parse($ObjectId).ToByteArray()
        $array = New-Object 'UInt32[]' 4    
        [Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
        $sid = "S-1-12-1-$array".Replace(' ', '-')
        return $sid
    }
    
    # $objectId = "73d664e4-0886-4a73-b745-c694da45ddb4"
    # $sid = Convert-AzureAdObjectIdToSid -ObjectId $objectId
    # Write-Output $sid
    # Output:
    # S-1-12-1-1943430372-1249052806-2496021943-3034400218

function Get-LocalUsers1 {
    param($Usr="Administrator",$ComputerName=$env:COMPUTERNAME)

    $Prop=([ADSI] "WinNT://WORKGROUP/$ComputerName/$Usr").PsBase.Properties
    " ** {0,31} : {1} **" -f "User", $Prop.Name.Value; 
    $Prop.Keys | % { $k=$_;$v=$Prop.$k.value;$t=$v.GetType();switch($t) { int {$v=$v.ToString()}; string { if ($k -eq "Name") {$k="-";} }; default {$v="tbd"}}; if($k -ne "-") { "{0,35} : {1}" -f "$k($t)",$v }  }
}

function Get-LocalUsers1a {
    param($Usr="Administrator",$ComputerName=$env:COMPUTERNAME
    $Prop=([ADSI] "WinNT://WORKGROUP/$ComputerName/$Usr").Properties
    " ** {0,31} : {1} **" -f "User", $Prop.Name.Value; 
    $Prop.Keys | % { 
        $k=$_;
        $t=$Prop.$k.value.GetType()
        switch($t) { 
            "byte[]" {
                switch($k) {
                    objectSid  {
                        # ([ADSI] "WinNT://WORKGROUP/WIN11-2/alexe").Properties.objectSid
                        # $v=Convert-AzureAdObjectIdToSid $Prop.$k.value
                        # $array = New-Object 'UInt32[]' 4    
                        # [Buffer]::BlockCopy($Prop.$k.value, 0, $array, 0, 16)
                        # $v = "$array".Replace(' ', '-')
                        [System.Security.Principal.SecurityIdentifier] $sid=$Prop.$k.value
                        $v=$sid.Value
                                    
                    }
                    LoginHours {$v = [bitconverter]::ToString($Prop.$k.value)}
                    default {$v="tbd"}

                }
                # $bytes = [System.Text.Encoding]::Unicode.GetBytes($Prop.$k.value) 
                # $v=[System.Text.Encoding]::ASCII.GetString($bytes) 
                # $v=$v.ToString()
            }
            string { if ($k -eq "Name") {$k="-";}; $v=$Prop.$k.value}; 
            default {$v=$Prop.$k.value}
        };
        if($k -ne "-") { "{0,35} : {1}" -f "$k($t)",$v }  
    }
}


function Get-LocalUsers2 {
    Param([string]$ComputerName=$env:COMPUTERNAME)

    ([ADSI] "WinNT://$Env:ComputerName").Children | where { $_.SchemaClassName -eq 'User' }  | % {
        $hTbl=$_;
        "`n{0,35} : {1}" -f "UserName", $hTbl.Name.Value
        ForEach( $Prop in ($hTbl | Get-Member -MemberType Property).Name ) {
            try { if ($hTbl.$Prop) { $Val=[string]$hTbl.$Prop; if (($Val.Length -gt 0) -and ($Prop -ne "Name") ) { "{0,35} : {1}" -f $Prop, $(switch ($Key) { default { "$($hTbl.$Prop)"}; } ) } } } finally {}
        }
    }
}

function Get-LocalUsers3 {
    Param([string]$ComputerName=$env:COMPUTERNAME)
    ForEach( $Usr in ([ADSI] "WinNT://$ComputerName").psbase.Children | where { $_.psbase.schemaclassname -match 'user' } ) {
        $hTbl=$Usr.PsBase.Properties
        ForEach( $Key in $hTbl.Keys ) {
            "[{0}]='{1}'" -f $key, $(switch ($key) { LoginHours {"LoginHours"} default { "$($hTbl.$key)"}; } )
        }
    }
}

function Get-LocalUsers4 {
    Param([string]$ComputerName=$env:COMPUTERNAME)
    ([ADSI] "WinNT://$ComputerName").Children | where { $_.SchemaClassName -eq 'User' }  | % {
         $hTbl=$_;
         "`n{0,35} : {1}" -f "UserName", $hTbl.Name.Value
         ForEach( $Prop in ($hTbl | Get-Member -MemberType Property).Name ) {
             try { if ($hTbl.$Prop) { $Val=[string]$hTbl.$Prop; if (($Val.Length -gt 0) -and ($Prop -ne "Name") ) { "{0,35} : {1}" -f $Prop, $(switch ($Key) { default { "$($hTbl.$Prop)"}; } ) } } } finally {}
         }
     }
}
function Get-LocalUsers6 {
    Param([string]$ComputerName=$env:COMPUTERNAME)

    [ADSI]$computer="WinNT://$ComputerName"

    $computer.PsBase.Children | Where-Object {$_.SchemaClassName -match "user"} |
    Select-Object @{Name="ComputerName"; Expression={$computer.Name}},
                  @{Name="User"; Expression={$_.PsBase.Properties.Name.Value}},
                  @{Name="Description"; Expression={$_.PsBase.Properties.Description.Value}},
                  @{Name="Disabled"; Expression={[bool]($_.PsBase.Properties.Item("userflags").Value -band 2)}},
                  @{Name="LastLogin"; Expression={ if ($_.PsBase.Properties.LastLogin.Value) {
                                                        [datetime]$_.PsBase.Properties.LastLogin.Value
                                                   } else { "Never" }}}
}

# ([ADSI]"WinNT://$env:COMPUTERNAME").PsBase.Children | Where-Object {$_.SchemaClassName -match "user"}
# set the date to compare against to midnight using '.Date'
# $refDate = (Get-Date).AddDays(-90).Date
# Get-LocalUsers2 | Where-Object { $_.LastLogin -eq 'Never' -or $_.LastLogin -lt $refDate } | Select-Object *

# ConvertFrom-Sid "S-1-5-21-3101668316-195586092-1316055306-1001" # WIN11-2\alexe
ConvertTo-Sid -accountName alexe -domain WIN11-2

Get-LocalUsers1a @args
# Get-LocalUsers2
# Get-LocalUsers3



<#
Get-CimInstance -Class win32_userAccount -Filter "Name = 'alexe'"  | select *

Status                : OK
Caption               : Win11-2\alexe
PasswordExpires       : False
Description           :
InstallDate           :
Name                  : alexe
Domain                : Win11-2
LocalAccount          : True
SID                   : S-1-5-21-3101668316-195586092-1316055306-1001
SIDType               : 1
AccountType           : 512
Disabled              : False
FullName              : Alex Evteev
Lockout               : False
PasswordChangeable    : True
PasswordRequired      : True
PSComputerName        :
CimClass              : root/cimv2:Win32_UserAccount
CimInstanceProperties : {Caption, Description, InstallDate, Name…}
CimSystemProperties   : Microsoft.Management.Infrastructure.CimSystemProperties

PS C:\Users\alexe> Get-LocalUser alexe | select *

AccountExpires         :
Description            :
Enabled                : True
FullName               : Alex Evteev
PasswordChangeableDate : 3/7/2022 3:16:02 PM
PasswordExpires        :
UserMayChangePassword  : True
PasswordRequired       : True
PasswordLastSet        : 3/7/2022 3:16:02 PM
LastLogon              : 3/8/2022 5:47:12 PM
Name                   : alexe
SID                    : S-1-5-21-3101668316-195586092-1316055306-1001
PrincipalSource        : MicrosoftAccount
ObjectClass            : User

 PS C:\Users\alexe> Get-LocalUser | Format-Table Name, Enabled, LastLogon, PasswordRequired, PrincipalSource, PasswordLastSet, Description, Sid

 Name               SID                                           Enabled PasswordRequired  PrincipalSource PasswordLastSet     Description                                                                                     LastLogon
----               ---                                           ------- ----------------  --------------- ---------------     -----------                                                                                     ---------
Administrator      S-1-5-21-3101668316-195586092-1316055306-500    False             True            Local                     Built-in account for administering the computer/domain
alexe              S-1-5-21-3101668316-195586092-1316055306-1001    True             True MicrosoftAccount 3/7/2022 3:16:02 PM                                                                                                 3/8/2022 5:47:12 PM
DefaultAccount     S-1-5-21-3101668316-195586092-1316055306-503    False            False            Local                     A user account managed by the system.
evt20              S-1-5-21-3101668316-195586092-1316055306-1003   False             True MicrosoftAccount 3/7/2022 3:36:49 PM
Guest              S-1-5-21-3101668316-195586092-1316055306-501     True            False            Local                     Built-in account for guest access to the computer/domain                                        4/3/2022 4:33:18 PM
kirae              S-1-5-21-3101668316-195586092-1316055306-1004    True             True MicrosoftAccount 3/7/2022 3:36:49 PM
nikit              S-1-5-21-3101668316-195586092-1316055306-1002   False             True MicrosoftAccount 3/7/2022 3:36:49 PM
WDAGUtilityAccount S-1-5-21-3101668316-195586092-1316055306-504    False             True            Local 3/7/2022 6:03:40 PM A user account managed and used by the system for Windows Defender Application Guard scenarios.
yanae              S-1-5-21-3101668316-195586092-1316055306-1005    True             True MicrosoftAccount 3/7/2022 3:36:49 PM
                                                                 S-1-5-21-3101668316-195586092-1316055306-1005

Disable-LocalUser Guest
Name               SID                                           Enabled PasswordRequired  PrincipalSource PasswordLastSet     Description                                                                                     LastLogon
----               ---                                           ------- ----------------  --------------- ---------------     -----------                                                                                     ---------
Administrator      S-1-5-21-3101668316-195586092-1316055306-500    False             True            Local                     Built-in account for administering the computer/domain
alexe              S-1-5-21-3101668316-195586092-1316055306-1001    True             True MicrosoftAccount 3/7/2022 3:16:02 PM                                                                                                 3/8/2022 5:47:12 PM
DefaultAccount     S-1-5-21-3101668316-195586092-1316055306-503    False            False            Local                     A user account managed by the system.
evt20              S-1-5-21-3101668316-195586092-1316055306-1003   False             True MicrosoftAccount 3/7/2022 3:36:49 PM
Guest              S-1-5-21-3101668316-195586092-1316055306-501    False            False            Local                     Built-in account for guest access to the computer/domain                                        4/3/2022 4:33:18 PM
kirae              S-1-5-21-3101668316-195586092-1316055306-1004    True             True MicrosoftAccount 3/7/2022 3:36:49 PM
nikit              S-1-5-21-3101668316-195586092-1316055306-1002   False             True MicrosoftAccount 3/7/2022 3:36:49 PM
WDAGUtilityAccount S-1-5-21-3101668316-195586092-1316055306-504    False             True            Local 3/7/2022 6:03:40 PM A user account managed and used by the system for Windows Defender Application Guard scenarios.
yanae              S-1-5-21-3101668316-195586092-1316055306-1005    True             True MicrosoftAccount 3/7/2022 3:36:49 PM

$LOGS=$(get-WinEvent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-60))})
Get-WinEvent @{logname=($LOGS.LogName) ; userid='S-1-5-21-3101668316-195586092-1316055306-501'}
Get-WinEvent @{logname=($LOGS.LogName) ; data='S-1-5-21-3101668316-195586092-1316055306-501'}

Get-WinEvent @{logname=($LOGS.LogName) ; data=(Get-LocalUser alexe,Administrator,WDAGUtilityAccount,Guest).Sid.Value}
Get-WinEvent @{logname=($LOGS.LogName) ; data=(Get-LocalUser alexe,Administrator,WDAGUtilityAccount,Guest).Sid.Value} -maxevents 1  | select UserId, LogName, TimeCreated, ProviderName, Level, RecordId, Id, ProcessId, Message

$UserSid=Get-LocalUser | select  Name,Sid
Get-WinEvent @{logname=($LOGS.LogName) ; data=($UserSid | where {$_.name -in "alexe","Administrator","WDAGUtilityAccount","Guest"}).Sid.Value} -maxevents 10  | select UserId, @{n='User';e={$sid=$_.UserId;($UserSid|where {$_.Sid -eq $sid}).Name}},LogName, TimeCreated, ProviderName, Level, RecordId, Id, ProcessId, Message
Get-WinEvent @{logname=($LOGS.LogName) ; data=($UserSid | where {$_.name -in "Guest"}).Sid.Value} -maxevents 10  | select UserId, @{n='User';e={$sid=$_.UserId;($UserSid|where {$_.Sid -eq $sid}).Name}},LogName, TimeCreated, ProviderName, Level, RecordId, Id, ProcessId, Message

 Get-WinEvent @{logname='*' ; data=(Get-LocalUser Guest,Administrator,WDAGUtilityAccount).Sid.Value} -maxevent 20


Get-WinEvent @{logname="*" ; userid=($UserSid | where {$_.name -in "alexe"}).Sid.Value} -maxevent 20| select UserId, @{n='User';e={$sid=$_.UserId;($UserSid|where {$_.Sid -eq $sid}).Name}},LogName, TimeCreated, ProviderName, Level, RecordId, Id, ProcessId, Message

Get-WinEvent @{logname="*" ; Level=1,2; userid=($UserSid | where {$_.name -in "alexe"}).Sid.Value} -maxevent 20| select @{n='User';e={$sid=$_.UserId;($UserSid|where {$_.Sid -eq $sid}).Name}},LogName, UserId, TimeCreated, ProviderName, Level,LevelDisplayName,OpcodeDisplayName, RecordId, Id, ProcessId, @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{250}).+' }}

Get-WinEvent @{logname="*" ; Level=1,2; userid=(Get-LocalUser alexe).Sid.Value} | select @{n='User';e={(Get-LocalUser -Sid $_.UserId).Name}},UserId,TimeCreated,ProviderName,Level,LevelDisplayName,OpcodeDisplayName, RecordId, Id, ProcessId, @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{500}).+' }}

Get-WinEvent @{logname="*" ; Level=1,2} | select @{n='User';e={(Get-LocalUser -Sid $_.UserId).Name}},UserId,TimeCreated,ProviderName,Level,LevelDisplayName,OpcodeDisplayName,RecordId,Id,ProcessId, @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{500}).+' }} > C:\home\tmp\errors-events-2022-04-26.log

Get-WinEvent @{logname="*" ; Level=1,2}  | select @{n='User';e={(Get-StandardUser $_.UserId)}},UserId,TimeCreated,ProviderName,Level,LevelDisplayName,OpcodeDisplayName,RecordId,Id,ProcessId, @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{500}).+' }} > C:\home\tmp\errors-events-2022-04-26.log

Get-WinEvent @{logname="*" ; Level=1,2,3}  | select @{n='User';e={(Get-StandardUser $_.UserId)}},UserId,TimeCreated,ProviderName,Level,LevelDisplayName,OpcodeDisplayName,RecordId,Id,ProcessId, @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{500}).+' }} > C:\home\tmp\errors-warnings-events-2022-04-26.log

#>
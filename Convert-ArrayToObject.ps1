# https://github.com/PowerShell/PowerShell/issues/15848
param (
    [Object[]] [Parameter(ValueFromPipeline)] $InputObject,
    [String[]] $PropertyName,
    [Switch] $DiscardRemaining,
    [Switch] $AsHashtable,
    [Switch] $Help
)

begin {
    $i = 0 
    $overflow = $false
    $maxPropertyIndex = $PropertyName.Count 
    $hashtable = [Ordered]@{}
    
    # $MaxWidth=$($Host.UI.RawUI.WindowSize.Width-16)
    $MyCommand=$MyInvocation.MyCommand
    $Line=$MyInvocation.Line
  
    Write-Verbose '-- begin ---'
    Write-Verbose $('{0,-30} : {1}' -f 'Command', ($Line -replace("$MyCommand",'')))
    Write-Verbose $('{0,-30} : {1}' -f 'PropertyName', $($PropertyName -join(', ')))
    Write-Verbose $('{0,-30} : {1}' -f 'DiscardRemaining', $($DiscardRemaining -join(', ')))
    Write-Verbose $('{0,-30} : {1}' -f 'AsHashtable', $($AsHashtable -join(', ')))
    if ($help) {
        $HelpText=@'
        Usage: $MyCommand -InputObject -PropertyName -DiscardRemaining -AsHashtable -Help
    
        # -- Example 1 
        $date = Get-Date
        $lottery = 1..49 | Get-Random -Count 7
        $env:username, $date, $lottery | Convert-ArrayToObject -PropertyName UserName, Drawing, Result

        # -- Example 2
        PS> 1..10 | Convert-ArrayToObject -PropertyName A,B,C
        A B C              
        - - -              
        1 2 {3, 4, 5, 6...}

        # -- Example 3
        PS> 1..10 | Convert-ArrayToObject -PropertyName A,B,C -DiscardRemaining -AsHashtable
        Name          Value                                                                                                              
        ----          -----                                                                                                              
        A             1                                                                                                                  
        B             2                                                                                                                  
        C             3         

        # -- Example 4
        $EventParam=@{ 
            FilterHash  = @{ LogName = 'System'; Level = 4,5; Id = 19; ProviderName = 'Microsoft-Windows-WindowsUpdateClient' } 
            MaxEvents   = 5 
            ErrorAction = 0
        }
        $FormatParam = @{
            Property = @(
                "TimeCreated","ID","ProcessId","ThreadId"
                , @{N='Level';     E={ $_.LevelDisplayName } }
                , @{N='User';      E={ $_.UserId } }
                , @{N='Opcode';    E={ $_.OpcodeDisplayName } }
                , @{N='Task';      E={ $_.TaskDisplayName } }
                , @{N='Keywords';  E={ $_.KeywordsDisplayNames } }
                , @{N='Values';    E={ $_.Properties.Value | Convert-ArrayToObject -PropertyName Software,GUID,Code  -DiscardRemaining }}
            )
        }
        $ExpandParam = @{ 
            Property = @("TimeCreated","ID","Level","OpCode","Task","Kewords","User","ProcessId","ThreadId")
            Expand   = "Values"
        }
        $OutParam = @{ 
            Property=  @("TimeCreated","ID","Level","OpCode","Task","User","ProcessId","Software","GUID","CODE") 
        }
        $TableParam = @{ 
            Auto=$true
            Property = "*"
        }
        
        Get-WinEvent     @EventParam     | 
          Select-Object  @FormatParam    |
          Select-Object  @ExpandParam    |
          Select-Object  @OutParam       |
          Format-Table   @TableParam
'@
    }

}

PROCESS {
    Write-Verbose '-- process ---'
    Write-Verbose $('{0,-30} : {1}' -f 'InputObject', $($InputObject -join(', ' )))
    # Convert-ArrayToObject -InputObject:$InputObject -PropertyName:$PropertyName -DiscardRemaining:$DiscardRemaining -AsHashtable:$AsHashtable
    if ($Help) {
        Write-Host $HelpText
    } else {
        $InputObject | ForEach-Object {
            if ($i -lt $maxPropertyIndex -and -not $overflow) {
                $hashtable[$PropertyName[$i]] = $_
                $i++
            } else {
                if ($DiscardRemaining) {
                    $overflow = $true
                } else {
                    if (-not $overflow) {
                        $i--
                        $hashtable[$PropertyName[$i]] = [System.Collections.ArrayList]@($hashtable[$PropertyName[$i]])
                        $overflow = $true
                    }
                    $null = $hashtable[$PropertyName[$i]].Add($_)
                }
            }
        }
    }
}

END {
    if ($AsHashtable) {
        return $hashtable
    } else {
        [PSCustomObject]$hashtable
    }
    Write-Verbose '-- end    ---'
}

# 1..3  | Convert-ArrayToObject -PropertyName A,B,C
# 1..10 | Convert-ArrayToObject -PropertyName A,B,C
# 1..10 | Convert-ArrayToObject -PropertyName A,B,C -DiscardRemaining

function Get-LocalUsers1 {
    ForEach-Object ( $Usr in [ADSI] "WinNT://WIN11-2").psbase.Children | where { $_.psbase.schemaclassname -match 'user' } ) {
        $hTbl=$Usr.PsBase.Properties
        ForEach( $Key in $hTbl.Keys ) {
            '[{0}]='{1}'' -f $key, $(switch ($key) { LoginHours {"LoginHours"} default { "$($hTbl.$key)"}; } )
        }
    }
}

function Get-LocalUsers2 {
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

Get-LocalUsers1
Get-LocalUsers2

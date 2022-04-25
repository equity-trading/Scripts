function Get-LocalUsers {
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

# set the date to compare against to midnight using '.Date'
$refDate = (Get-Date).AddDays(-90).Date
Get-LocalUsers | Where-Object { $_.LastLogin -eq 'Never' -or $_.LastLogin -lt $refDate }

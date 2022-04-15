# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
param(	[string] $Command="Get-Events", 
		[int] $EventRecordID, [int] $EventID, [string] $LogName, [string] $ProviderName, 
		[int[]] $Levels, 
		[int] $Hours, [int] $Minutes, [int] $Seconds=0, [int] $ms=1,
        [int]$NoOfOutLines=10, [int] $NoOfEvents, [int]$FilterLogDays,
		[int] $Trace
)
function CodeExecutor {
	# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
#	write-output '[CodeExecutor] -- start ----------------------'
# 	write-output "command: $command; args[$(($args).length)] : $($args -join ' ')"
    
#	Invoke-Command -ScriptBlock { & $command @args} -ArgumentList $args
    # Invoke the script block with `&`
	# write-output '[CodeExecutor] -- end ----------------------'
	# TopEvents @args
    Clear-Variable TOP_EVENTS,GROUPED_EVENTS,EVENT_LOGS -Scope Script -ea 0
    & $command @args
}


function Get-EventLogs () {
	param([int]$FilterLogDays=1)
    if(!$script:EVENT_LOGS) { $script:EVENT_LOGS=get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-$FilterLogDays))} }
	write-debug "LOGS count is $($script:EVENT_LOGS.Count)"
	return $script:EVENT_LOGS.LogName
}

function Get-GroupedEvents () {
	param([int[]]$Levels,[int]$NoOfEvents=1000,[int]$FilterLogDays)
	
	$FilterArray=@()
	$FilterArray+='1 -eq 1'
	if($PSBoundParameters.ContainsKey("Levels")) { $FilterArray+='$_.Level -in $Levels' }
	$FilterString=$FilterArray -join ' -and '
	$FilterBlock=[scriptblock]::Create($FilterString)
	# Get-WinEvent * -maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count	
	# Get-WinEvent $(get-winevent -listlog * -ea 0|where {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10))} ).LogName `
	#		-maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count	
	
    if(!$script:GROUPED_EVENTS) { $script:GROUPED_EVENTS=Get-WinEvent $(Get-EventLogs @PsBoundParameters) -maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count }
	write-debug "GROUPED_EVENTS count is $($script:GROUPED_EVENTS.Count)"
	return $script:GROUPED_EVENTS
}

function Get-TopEvents () {
	param(	[int]$EventRecordID, [int]$EventID, [string] $LogName="", [string] $ProviderName="",
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
			[int]$NoOfOutLines=1000, [int] $NoOfEvents,
			[int]$FilterLogDays)
    
    if(!$script:TOP_EVENTS) { $script:TOP_EVENTS = $(Get-GroupedEvents @PsBoundParameters) |  select-object -first $NoOfOutLines * }
	write-debug "TOP_EVENTS count is $($script:TOP_EVENTS.Count)"
	return $script:TOP_EVENTS
}

function Get-SearchEvents {
	param(	[string[]] $LogName, [string[]] $ProviderName, [int]$NoOfEvents=1,
    [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=1000 )
	$ms+=$Hours*3600*1000+$Minutes*60*1000+$Seconds*1000
	# "{0}:{1}:{2} >> {3}" -f $Hours,$Minutes,$Seconds,$ms
	$XmlSystemParams="TimeCreated[timediff(@SystemTime)<=$ms]"
	if ($EventID -ne 0) {$XmlSystemParams+=" and EventID=$EventID"}
	if ($EventRecordID -ne 0) {$XmlSystemParams+=" and EventRecordID=$EventRecordID"}
	$XmlSearch="*[System[$XmlSystemParams]]"
    Get-WinEvent -ProviderName $ProviderName -FilterXPath "$XmlSearch" -maxevent $NoOfEvents -ea 0
}

function tmp1 {
    return 
    Get-TopEvents @PsBoundParameters | Select-Object -first | Group-Object LogName 
       Select-Object  `
            @{n='Log';e={$_.Group[0].LogName}},
            $LevelCol,
            @{n='Count';e={($_.Group | Measure-Object Count -Sum).Sum}},
            @{n='Providers';e={($_.Group | Select-Object -First 3 @{n='Providers';e={'{0}({1})' -f $_.ProviderName,$_.Count}}).Providers.join(',') }},
            @{n='LastTimeCreated';e={$_.Group | Select-Object -Expand TimeCreated.ToString('MM/dd HH:mm:ss.fff') -First 1}}
            @{n='FirstTime';e={$_.Group | Select-Object -Expand TimeCreated.ToString('MM/dd HH:mm') -Last 1}}
            @{n='LstRecordId';e={$_.Group | Select-Object -Expand RecordId -First 1}}
            @{n='LstEventId';e={$_.Group | Select-Object -Expand Id -First 1}}
            @{n='LstMsg';e={($_.Group | Select-Object -Expand Message -First 1) -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{100}).+' }}
            @{n='LastPid';e={$_.Group | Select-Object -Expand ProcessId -First 1}}
    return
    # Sort-Object | format-Table -AutoSize
    # Write-Output "Top $TopSources active providers" 

    Get-TopEvents @PsBoundParameters | Group-Object ProviderName,Level | Sort-Object -Descending | Select-Object-Object -first $TopSources * |
       Select-Object  `
            @{n='Log';e={$_.Group[0].ProviderName}},
            $LevelCol,
            @{n='Count';e={($_.Group | Measure-Object Count -Sum).Sum}},
            @{n='Logs';e={($_.Group | Select-Object -First 3 @{n='Providers';e={'{0}({1})' -f $_.LogName,$_.Count}}).Providers.join(',') }},
            @{n='LastTimeCreated';e={$_.Group | Select-Object -Expand TimeCreated.ToString('MM/dd HH:mm:ss.fff') -First 1}}
            @{n='FirstTime';e={$_.Group | Select-Object -Expand TimeCreated.ToString('MM/dd HH:mm') -Last 1}}
            @{n='LstRecordId';e={$_.Group | Select-Object -Expand RecordId -First 1}}
            @{n='LstEventId';e={$_.Group | Select-Object -Expand Id -First 1}}
            @{n='LstMsg';e={($_.Group | Select-Object -Expand Message -First 1)} -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{100}).+' }
            @{n='LastPid';e={$_.Group | Select-Object -Expand ProcessId -First 1}}				  

}
function Get-TopGrouppedEvents {
    param(	[int] $FieldNo=0 ,
            [int]$EventRecordID, [int]$EventID, [string] $LogName="", [string] $ProviderName="",
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
			[int]$NoOfOutLines, [int] $NoOfEvents,
			[int]$FilterLogDays)
    # $GroupFields=("LogName","ProviderName","Level")
    # $FieldName=$GroupFields[$FieldNo]
    Get-TopEvents @PsBoundParameters  | Group-Object -Property  @{expression={$_.Values[$FieldNo]}} |
        Select-Object -Property @{n='Count';e={($_.Group | Measure-Object -Property Count -Sum).Sum}},
           @{n="Cnt";e={$_.Count}}, @{n='LogName';e={$_.Group.Values[0]}}, @{n='ProviderName';e={$_.Group.Values[1]}}, @{n='Level';e={$_.Group.Values[2]}},
           @{n='Events';e={$_.Group.Group}}
           # @{n="${FieldName}Cnt";e={$_.Count}},
           # @{n="$FieldName";e={$_.Group.Values[$FieldNo]}},
           # @{n='LogName';e={$_.Group.Values[0]}}, @{n='ProviderName';e={$_.Group.Values[1]}}, @{n='Level';e={$_.Group.Values[2]}},
           # @{n='Values';e={$_.Group.Values}}, 
           
    # Select-Object *
}

function Get-TopLogEvents {
    param(	[int]$EventRecordID, [int]$EventID, [string] $LogName="", [string] $ProviderName="",
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
			[int]$NoOfOutLines, [int] $NoOfEvents,
			[int]$FilterLogDays)
    # $GroupFields=("LogName","ProviderName","Level")
    # $FieldName=$GroupFields[$FieldNo]
    Get-TopEvents @PsBoundParameters  | Group-Object -Property  @{expression={$_.Values[0]}},@{expression={$_.Values[2]}} |
        Select-Object -Property @{n='Count';e={($_.Group | Measure-Object -Property Count -Sum).Sum}},
            @{n="GrpCnt";e={$_.Count}}, @{n='LogName';e={$_.Values[0]}}, @{n='Level';e={$_.Values[1]}},
            @{n='FstEvent';e={($_.Group.Group| Select-Object -first 1 *)}},
            @{n='Events';e={$_.Group.Group}}
            # @{n="${FieldName}Cnt";e={$_.Count}},
           # @{n="$FieldName";e={$_.Group.Values[$FieldNo]}},
           # @{n='LogName';e={$_.Group.Values[0]}}, @{n='ProviderName';e={$_.Group.Values[1]}}, @{n='Level';e={$_.Group.Values[2]}},
           # @{n='Values';e={$_.Group.Values}}, 
           
    # Select-Object *
}

function Get-TopProviderEvents {
    param(	[int]$EventRecordID, [int]$EventID, [string] $LogName="", [string] $ProviderName="",
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
			[int]$NoOfOutLines, [int] $NoOfEvents,
			[int]$FilterLogDays)
    # $GroupFields=("LogName","ProviderName","Level")
    # $FieldName=$GroupFields[$FieldNo]
    Get-TopEvents @PsBoundParameters  | Group-Object -Property  @{expression={$_.Values[1]}},@{expression={$_.Values[2]}} |
        Select-Object -Property @{n='Count';e={($_.Group | Measure-Object -Property Count -Sum).Sum}},
           @{n="GrpCnt";e={$_.Count}}, @{n='ProviderName';e={$_.Values[0]}}, @{n='Level';e={$_.Values[1]}}, 
           @{n='FstEvent';e={($_.Group.Group| Select-Object -first 1 *)}},
           @{n='Events';e={$_.Group.Group}}
           # @{n='FstEvent';e={$_.Group.Group[0]}},
           # @{n="${FieldName}Cnt";e={$_.Count}},
           # @{n="$FieldName";e={$_.Group.Values[$FieldNo]}},
           # @{n='LogName';e={$_.Group.Values[0]}}, @{n='ProviderName';e={$_.Group.Values[1]}}, @{n='Level';e={$_.Group.Values[2]}},
           # @{n='Values';e={$_.Group.Values}}, 
           
    # Select-Object *
}
function Get-Events {
	param(	[string[]] $LogName, [string[]] $ProviderName,
            [int]$EventRecordID=0, [int]$EventID=0, [int]$MaxEvent,
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
            [int]$NoOfOutLines=20, [int] $NoOfEvents)
    if($PSBoundParameters.ContainsKey("NoOfOutLines") -eq "True" ) { $PsBoundParameters.remove("NoOfOutLines") }
	if ($ProviderName -or $LogName ) { 
		Get-SearchEvents @PsBoundParameters | Sort-Object -Descending | Select-Object -first $NoOfOutLines *
	} else {
#		$Host.UI.WriteErrorLine("Missing parameter: either -LogName or -ProviderName must be specified")		
        # Get-TopEvents @PsBoundParameters | select-object @{n='LogName';e={$_.Values[0]}}, @{n='ProviderName';e={$_.Values[1]}}, @{n='Level';e={$_.Values[2]}}, Count,Group
        # Get-TopGrouppedEvents @PsBoundParameters 0 | Select-Object Count,LogName
        # Get-TopProviderEvents
        Get-TopLogEvents
        # Write-Output "ProviderName"; Get-TopGrouppedEvents -FieldNo 1 @PsBoundParameters  | format-table Count,ProviderName 
        # Write-Output "LogName"; Get-TopGrouppedEvents -FieldNo 0 @PsBoundParameters  | format-table Count,LogName
        # Get-TopEvents @PsBoundParameters | select-object @{n='LogName';e={$_.Values[0]}}, @{n='ProviderName';e={$_.Values[1]}}, @{n='Level';e={$_.Values[2]}}, Count,Group
        # @{n='ProviderName';e={$_.Values | Select-Object -Expand ProviderName -First 1}},
        # @{n='Level';e={$_.Values | Select-Object -Expand Level -First 1}},
        # Count,Group
	}
    
}



# Get-TopEvents @PsBoundParameters


# break 

# if($PSBoundParameters.ContainsKey("Command") -eq "True" ) { $PsBoundParameters.remove("Command") }

CodeExecutor -command $command @PsBoundParameters

# Test-PsCallStack Get-Content @PSBoundParameters
# Test-Parameters @PSBoundParameters

# write-output "`n`n * Call 2"
# Test-Args @Parameters
# Measure-Command -Expression { Test-Args @Parameters }


# write-output "end"

# trace-command ParameterBinding -Expression { Test-Args @Parameters } # not clear what ParameterBinding does ?
# Test-AutoVars @PSBoundParameters

# TestCall -a 1 -b 2 -c 3 -d "- D -"

# if ($PSBoundParameters.ContainsKey('Trace')) { Set-PSDebug -Trace 0 }

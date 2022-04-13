# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
param(	[string] $Command="Get-TopEvents", 
		[int] $EventRecordID, [int] $EventID, [string] $LogName, [string] $ProviderName, 
		[int[]] $Levels, 
		[int] $Hours, [int] $Minutes, [int] $Seconds=0, [int] $ms=1,
        [int]$NoOfOutLines=10, [int] $NoOfEvents, [int]$FilterLogDays,
		[int] $Trace
)

function Get-ParameterValues {
    <#
        .Synopsis
            Get the actual values of parameters which have manually set (non-null) default values or values passed in the call
        .Description
            Unlike $PSBoundParameters, the hashtable returned from Get-ParameterValues includes non-empty default parameter values.
            NOTE: Default values that are the same as the implied values are ignored (e.g.: empty strings, zero numbers, nulls).
        .Example
            function Test-Parameters {
                [CmdletBinding()]
                param(
                    $Name = $Env:UserName,
                    $Age
                )
                $Parameters = . Get-ParameterValues
                # This WILL ALWAYS have a value... 
                Write-Host $Parameters["Name"]
                # But this will NOT always have a value... 
                Write-Host $PSBoundParameters["Name"]
            }
    #>
    [CmdletBinding()]
    param(
        # The $MyInvocation for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $Invocation = $MyInvocation,
        # The $PSBoundParameters for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $BoundParameters = $PSBoundParameters
    )

    if($MyInvocation.Line[($MyInvocation.OffsetInLine - 1)] -ne '.') {
        throw "Get-ParameterValues must be dot-sourced, like this: . Get-ParameterValues"
    }

    if($PSBoundParameters.Count -gt 0) {
        throw "You should not pass parameters to Get-ParameterValues, just dot-source it like this: . Get-ParameterValues"
    }

    $ParameterValues = @{}
    foreach($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
        # gm -in $parameter.Value | Out-Default
        try {
            $key = $parameter.Key
            if($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore)) {
                if($value -ne ($null -as $parameter.Value.ParameterType)) {
                    $ParameterValues[$key] = $value
                }
            }
            if($BoundParameters.ContainsKey($key)) {
                $ParameterValues[$key] = $BoundParameters[$key]
            }
        } finally {}
    }
    $ParameterValues
}

function Get-EventLogs () {
	param([int]$FilterLogDays=5)
    if(!$script:EVENT_LOGS) { $script:EVENT_LOGS=get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-$FilterLogDays))} }
	write-debug "LOGS count is $($script:EVENT_LOGS.Count)"
	return $script:EVENT_LOGS.LogName
}

function Get-GroupedEvents () {
	param([int[]]$Levels,[int]$NoOfEvents=5000,[int]$FilterLogDays)
	
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
			[int]$NoOfOutLines=10, [int] $NoOfEvents,
			[int]$FilterLogDays)

    
    if(!$script:TOP_EVENTS) { $script:TOP_EVENTS = $(Get-GroupedEvents @PsBoundParameters) |  select-object -first $NoOfOutLines * }
	write-debug "TOP_EVENTS count is $($script:TOP_EVENTS.Count)"
	return $script:TOP_EVENTS
}

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


# $Parameters = . Get-ParameterValues
# $Parameters

# write-output "`n`n * Call 1"
# CodeExecutor @Parameters
# TopEvents @Parameters

# Get-Events @Parameters
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

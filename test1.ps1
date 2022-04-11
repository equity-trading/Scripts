# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
param(	[string] $command="TopEvents", 
		[int] $EventRecordID=0, [int] $EventID=0, [string] $LogName="", [string] $ProviderName="", 
		[int[]] $Levels, 
		[int] $Hours=10, [int] $Minutes=0, [int] $Seconds=0, [int] $ms=1,
		[int] $NoOfOutLines=20 , [int] $NoOfEvents=1,
		[int] $FilterLogDays=5, 
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

function Get-Logs () {
	param([int]$FilterLogDays=5)
    if(!$script:LOGS) { $script:LOGS=get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-$FilterLogDays))} }
	write-debug "LOGS count is $($script:LOGS.Count)"
	return $script:LOGS.LogName
}

function Get-Events () {
	param([int[]]$Levels,[int]$NoOfEvents=5000,[int]$FilterLogDays=5)
	Get-Logs @PsBoundParameters
	return 
	$FilterArray=@()
	$FilterArray+='1 -eq 1'
	if($PSBoundParameters.ContainsKey("Levels")) { $FilterArray+='$_.Level -in $Levels' }
	$FilterString=$FilterArray -join ' -and '
	$FilterBlock=[scriptblock]::Create($FilterString)
	# Get-WinEvent * -maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count	
	# Get-WinEvent $(get-winevent -listlog * -ea 0|where {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddDays(-10))} ).LogName `
	#		-maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count	
	Get-WinEvent $script:LOGS.LogName -maxevent $NoOfEvents -ea 0 | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count	
}

function TopEvents () {
	param(	[int]$EventRecordID, [int]$EventID, [string] $LogName="", [string] $ProviderName="",
			[int[]]$Levels,
			[int]$Hours, [int]$Minutes, [int]$Seconds, [int]$ms,
			[int]$NoOfOutLines, [int] $NoOfEvents,
			[int]$FilterLogDays)

	$GroupedEvents=Get-Events @PsBoundParameters | select-object -first $NoOfOutLines *
	return $GroupedEvents 
}

$Parameters = . Get-ParameterValues
# $Parameters

function CodeExecutor {
	# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
    param (
        # Define the piece of functionality to accept as a [scriptblock]
        [string]$command="TopEvents"
    )
	write-output '[CodeExecutor] -- start ----------------------'
	write-output "command: $command; args[$(($args).length)] : $($args -join ' ')"
    
	Invoke-Command -ScriptBlock { & $command @args} -ArgumentList $args
    # Invoke the script block with `&`
	write-output '[CodeExecutor] -- end ----------------------'	    
	TopEvents @args
}

# write-output "`n`n * Call 1"
# CodeExecutor @Parameters
# TopEvents @Parameters

Get-Events @Parameters

# break 
# CodeExecutor @Parameters

# Test-PsCallStack Get-Content @PSBoundParameters
# Test-Parameters @PSBoundParameters

# write-output "`n`n * Call 2"
# Test-Args @Parameters
# Measure-Command -Expression { Test-Args @Parameters }


# write-output "end"

# trace-command ParameterBinding -Expression { Test-Args @Parameters } # not clear what ParameterBinding does ?
# Test-AutoVars @PSBoundParameters

# TestCall -a 1 -b 2 -c 3 -d "- D -"

if ($PSBoundParameters.ContainsKey('Trace')) { Set-PSDebug -Trace 0 }

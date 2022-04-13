[CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]

param(	[string]$command="TopEvents", 
		[int]$EventRecordID=0, [int]$EventID=0, [string] $LogName="", [string] $ProviderName="", [int]$MaxEvent=1,
		[int[]]$Levels=$null, 
		[int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=1,
		[int] $TopSources=20 , [int] $TopEvents=2000 
)

$error.Clear()

$LevelCol=@{n='Lvl';e={Switch ($_.Group[0].Level) { 0 {"INF(0)"}; 1 {"FTL(1)"}; 2 {"ERR(2)"}; 3 {"WRN(3)"}; 4 {"INF(4)"}; 5 {"DBG(5)"}; 6 {"TRC(6)"}; default {"UKN($_)"};}}}

$EventProps=@( @{n='Provider';e={$_.Group[0].ProviderName}},
     @{n='Log';e={$_.Group[0].LogName}},
     $LevelCol,
	 @{n='Cnt';e={$_.Count}},
     @{n='LastTimeCreated';e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},
     @{n='FirstTime';e={$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm')}},
     @{n='LstRecordId';e={$_.Group[0].RecordId}},
     @{n='LstEventId';e={$_.Group[0].Id}},
     @{n='LstMsg';e={$_.Group[0].Message -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{100}).+'}},
     @{n='LastPid';e={$_.Group[0].ProcessId}},
	 @{n='LastProcess';e={(Get-Process -ID $_.Group[0].ProcessId).Path}} )


function StrNorm([string] $msg)  {
   $msg -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"'  -replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' -replace '(?<=.{120}).+'
}

function MsgNorm($E)  {
    $E.Message -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"'  -replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' -replace '(?<=.{120}).+'
}

function Invoke-ExpandedChecked {
	[CmdletBinding(
		SupportsShouldProcess = $true,
		ConfirmImpact = 'Medium'
	)]
    param([ScriptBlock]$ScriptBlock)

    $expanded = $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
    $script = [scriptblock]::Create($expanded)
    if ($PSCmdlet.ShouldProcess($script.ToString(), "Execute"))
    {
        & $script
    }
}

function Invoke-Checked {
	[CmdletBinding(
		SupportsShouldProcess = $true,
		ConfirmImpact = 'Medium'
	)]
    param([ScriptBlock]$ScriptBlock)

    $newClosure = $ScriptBlock.GetNewClosure()
    if ($PSCmdlet.ShouldProcess($newClosure.ToString(), "Execute"))
    {
        & $newClosure
    }
}

function GetTopEvents () {
	[CmdletBinding( SupportsShouldProcess = $true, ConfirmImpact = 'Medium' )]
	param([int[]]$Levels=$null, [int] $TopEvents=2000 )
	
	[ScriptBlock] $ScriptBlock={ $TopEvents=$(Get-WinEvent * -maxevent $TopEvents -ea 0 |  Where-Object { $null  -eq $Levels -or $_.Level -in $Levels } | Group-Object LogName,ProviderName,Level ) }
	
	$expanded = $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
	$newClosure = $ScriptBlock.GetNewClosure()
	$expanded.ToString()
	if ($PSCmdlet.ShouldProcess($newClosure.ToString(), "Execute")) {
		& $newClosure
	} 
	
}

function TopEvents () {
	[CmdletBinding(
		SupportsShouldProcess = $true,
		ConfirmImpact = 'Medium'
	)]
	param(	[int]$EventRecordID=0, [int]$EventID=0, [string] $LogName="", [string] $ProviderName="", [int]$MaxEvent=1,
			[int[]]$Levels=$null,
			[int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=1,
			[int] $TopSources=20 , [int] $TopEvents=2000 )

	Write-Output "Getting last $TopEvents events" 
	$TopEvents=$(GetTopEvents $Levels, $TopEvents)
 
	Write-Output "Top $TopSources active providers" 
	$TopEvents=$(Get-WinEvent * -maxevent $TopEvents -ea 0 | Group-Object LogName,ProviderName,Level )

	$TopEvents | Group-Object ProviderName,LogName,Level  |
    Sort-Object -Descending Count | select-object -first $TopSources * |
    Select-Object -Property $EventProps |
	Sort-Object | format-Table -AutoSize
}


function GetEvent {
	[CmdletBinding(
		SupportsShouldProcess = $true,
		ConfirmImpact = 'Medium'
	)]
	param(	[int]$EventRecordID=0, [int]$EventID=0, [string] $LogName="", [string] $ProviderName="", [int]$MaxEvent=1,
			[int[]]$Levels=$null,
			[int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=1,
			[int] $TopSources=20 , [int] $TopEvents=2000 )
	
	$ms+=$Hours*3600*1000+$Minutes*60*1000+$Seconds*1000
	# "{0}:{1}:{2} >> {3}" -f $Hours,$Minutes,$Seconds,$ms

	$XmlSystemParams="TimeCreated[timediff(@SystemTime)<=$ms]"
	if ($EventID -ne 0) {$XmlSystemParams+=" and EventRecordID=$EventID"}
	if ($EventRecordID -ne 0) {$XmlSystemParams+=" and EventRecordID=$EventRecordID"}
	$XmlSearch="*[System[$XmlSystemParams]]"
	
	if ($ProviderName -ne '') { 
		$EventScript={ Get-WinEvent -ProviderName $SearchName -FilterXPath "$XmlSearch" -maxevent $MaxEvent -ea 0 }
	} elseif ($ProviderName -ne '') { 
		$EventScript={ Get-WinEvent $SearchName -FilterXPath "$XmlSearch" -maxevent $MaxEvent -ea 0 }
	} else {
		$Host.UI.WriteErrorLine("Missing parameter: either -LogName or -ProviderName must be specified")

		echo "Getting last $TopEvents events" 
		$TopEvents=$(GetTopEvents $Levels, $TopEvents)
		
		Write-Output "Top $TopSources active logs" 
		
		$TopEvents | Group-Object LogName | Sort -Descending | Select -first $TopSources * |
		   Select-Object  `
				@{n='Log';e={$_.Group[0].LogName}},
				$LevelCol,
				@{n='Count';e={($_.Group | Measure-Object Count -Sum).Sum}},
				@{n='Providers';e={($_.Group | Select -First 3 @{n='Providers';e={'{0}({1})' -f $_.ProviderName,$_.Count}}).Providers.join(',') }},
				@{n='LastTimeCreated';e={$_.Group | Select -Expand TimeCreated.ToString('MM/dd HH:mm:ss.fff') -First 1}}
				@{n='FirstTime';e={$_.Group | Select -Expand TimeCreated.ToString('MM/dd HH:mm') -Last 1}}
				@{n='LstRecordId';e={$_.Group | Select -Expand RecordId -First 1}}
				@{n='LstEventId';e={$_.Group | Select -Expand Id -First 1}}
				@{n='LstMsg';e={($_.Group | Select -Expand Message -First 1) -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{100}).+' }}
				@{n='LastPid';e={$_.Group | Select -Expand ProcessId -First 1}}
		Sort-Object | format-Table -AutoSize

		echo "Top $TopSources active providers" 

		$TopEvents | Group-Object ProviderName,Level | Sort -Descending | Select -first $TopSources * |
		   Select-Object  `
				@{n='Log';e={$_.Group[0].ProviderName}},
				$LevelCol,
				@{n='Count';e={($_.Group | Measure-Object Count -Sum).Sum}},
				@{n='Logs';e={($_.Group | Select -First 3 @{n='Providers';e={'{0}({1})' -f $_.LogName,$_.Count}}).Providers.join(',') }},
				@{n='LastTimeCreated';e={$_.Group | Select -Expand TimeCreated.ToString('MM/dd HH:mm:ss.fff') -First 1}}
				@{n='FirstTime';e={$_.Group | Select -Expand TimeCreated.ToString('MM/dd HH:mm') -Last 1}}
				@{n='LstRecordId';e={$_.Group | Select -Expand RecordId -First 1}}
				@{n='LstEventId';e={$_.Group | Select -Expand Id -First 1}}
				@{n='LstMsg';e={($_.Group | Select -Expand Message -First 1)} -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{100}).+' }
				@{n='LastPid';e={$_.Group | Select -Expand ProcessId -First 1}}				  
						return
	}
		
	$InvokeCommand = @{
		ScriptBlock = {
			[CmdletBinding(
				SupportsShouldProcess = $true,
				ConfirmImpact = 'Medium'
			)]
			param([ScriptBlock]$ScriptBlock,$SearchName,$XmlSearch,$MaxEvent)

			$expanded = $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
			$newClosure = $ScriptBlock.GetNewClosure()
			$expanded.ToString()
			if ($PSCmdlet.ShouldProcess($newClosure.ToString(), "Execute")) {
				& $newClosure
			} 
			# Invoke-Command @ExecCmd
			# Measure-Command @ExecCmd
		}
		ArgumentList = $SearchName,$XmlSearch,$MaxEvent
	}
	# $parameters
	
	Invoke-Command @InvokeCommand
	# Get-WinEvent -ProviderName $ProviderName -FilterXPath $XmlSearch -maxevent $MaxEvent -ea 0
}


function GetEventRecordID([int]$EventRecordID=0, [string] $ProviderName="*", [int]$EventID=0, [int]$Hours=1, [int]$MaxEvent=1) {
}

function GetEventRecordID([int]$EventRecordID=0, [string] $ProviderName="*", [int]$EventID=0, [int]$Hours=1, [int]$MaxEvent=1) {
}

function GetEventXml([string] $ProviderName="*", [int]$EventRecordID=0, [int]$EventID=0, [int]$Hours=1, [int]$MaxEvent=1) {
}


function CodeExecutor {
	[CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
    param (
        # Define the piece of functionality to accept as a [scriptblock]
        [scriptblock] $ExecScriptBlock
    )

	
    
	$expanded = $ExecutionContext.InvokeCommand.ExpandString($ExecScriptBlock)
	$newClosure = $ExecScriptBlock.GetNewClosure()
	
	$expanded.ToString()
	$newClosure.ToString()
	
    # Invoke the script block with `&`
	if ($PSCmdlet.ShouldProcess($newClosure.ToString(), "Execute")) {
		# $script:Call @PSBoundParameters
		& $newClosure
	} 
    
}



$PSBoundParameters.Remove('command')
foreach($key in $MyInvocation.MyCommand.Parameters.Keys){
    $value = Get-Variable $key -ValueOnly -EA SilentlyContinue
    if($value -and !$PSBoundParameters.ContainsKey($key)) {$PSBoundParameters[$key] = $value}
}

'Call: {0} Parameters:' -f $script:Call
$PSBoundParameters



$ScriptBlock_DefaultDynamicParamProcess = {
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]$ScriptPsBoundParameters
        , [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)][ValidateNotNullOrEmpty()]$ScriptPSCmdlet
        , [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 2)][ValidateNotNullOrEmpty()]$DynamicParams
    )
    # For DynamicParam with a default value set that value
    $DynamicParams.Values |
        Where-Object { $_.IsSet -and ($ScriptPSCmdlet.ParameterSetName -in $_.Attributes.ParameterSetName -or '__AllParameterSets' -in $_.Attributes.ParameterSetName) } |
        ForEach-Object {
            If (-not ([System.String]::IsNullOrEmpty($_.Value)))
            {
                $ScriptPsBoundParameters[$_.Name] = $_.Value
            }
        }
    # Convert the DynamicParam inputs into new variables for the script to use
    $ScriptPsBoundParameters.GetEnumerator() |
        ForEach-Object {
            If (-not ([System.String]::IsNullOrEmpty($_.Value)))
            {
                Set-Variable -Name:($_.Key) -Value:($_.Value) -Force
            }
        }
}

& $ScriptBlock_DefaultDynamicParamProcess -ScriptPsBoundParameters:($PsBoundParameters) -ScriptPSCmdlet:($PSCmdlet) -DynamicParams:($RuntimeParameterDictionary) 



if ($PSCmdlet.ShouldProcess({invoke-expression @PSBoundParameters}.ToString(), "Execute")) {
	invoke-expression @PSBoundParameters
}




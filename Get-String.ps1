param ( [Parameter(ValueFromPipeLine = $True)]$InputObject)

# $tHt=$TestHT3; $DebugPreference=0; Get-String $TestHT3; ConvertTo-Json $tHt -compress
# $tHt=$TestHT3; $DebugPreference=2; Get-String $TestHT3; ConvertTo-Json $tHt -compress
# $DebugPreference=0; $tHt=$ComplexHT; $tHt | Get-String ; '{0}' -f ($tHt|ConvertTo-Json -compress -depth 5)
 
function Get-String( [Parameter(ValueFromPipeLine = $True)] $InputObject, $Depth=10, $MaxCount=200, $Iteration) {
	if (!$Iteration) { $Iteration=0; $Global:TotalElements=0 }
	$Iteration++
	$Global:TotalElements++
	Write-Debug $('Iter: {0} Max: {1} TotalElements: {2}  Obj: {3}' -f $Iteration, $Depth, $Global:TotalElements, ($InputObject|Out-String))

	if ($Iteration -gt $Depth) {
		Write-Warning "Depth exceeds -Depth:$Depth ..."
		return "..."
	}
	
	if ($Global:TotalElements -gt $MaxCount) {
		Write-Warning "Number of Elements exceeds -MaxCount:$MaxCount ..."
		return " ..."
	}
	
	if (!$InputObject) { 
		return ""
	} elseif ($InputObject -is [string]) { 
		return "`"$InputObject`""
	} elseif ($InputObject -is [valuetype]) { 
		return "$InputObject"
	}
	

	if ($DebugPreference) {
		$Methods = ($InputObject | gm -MemberType method).Name
		Write-Debug $('Type: {0} Methods[{1}]: {2} ' -f $InputObject.GetType(), $Methods.count, ($Methods -join(', ')))
	}
	
	$Methods = $InputObject.PSObject.Methods
	Write-Debug $('Type: {0} Methods[{1}]: {2} ' -f $InputObject.GetType(), $Methods.count, ($Methods -join(', ')))
	
	if ($Methods['GetEnumerator'] -is [System.Management.Automation.PsMethod]) {
		Write-Debug "GetEnumerator"
		if ($Methods['get_Keys'] -is [System.Management.Automation.PsMethod] -and $Methods['get_Values'] -is [System.Management.Automation.PsMethod]) {
			Write-Debug "List"
			$Arr=@()
			$List=$InputObject.GetEnumerator() | Sort-Object -Property Key
		} else {
			Write-Debug "Arr"
			$Arr = @()
			foreach ($Item in $InputObject) { $Arr+=@(Get-String -InputObject:$Item -Iteration:$Iteration -Depth:$Depth -MaxCount:$MaxCount ) }
			return "@( $($Arr -join ', ') )"
		}
	} else {
		Write-Debug "Try Properties"
		$List = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'Property' }
		if (!$List) { 
			Write-Debug "Try NoteProperty"
			$List = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } 			
		}
	}
	if (!$List) {
		Write-Debug "List is missing"
		return ""
	}
	$Arr=$()
	$List |% { 
		$Key = $_.Name
		$Val = Get-String -InputObject:$_.Value -Iteration:$Iteration -Depth:$Depth -MaxCount:$MaxCount
		$Arr+=@( "$Key=$Val" )
	}
	return "@{ $($Arr -join '; ') }"
}

# $InputObject | Get-String @PsBoundParameters

Write-Debug $('args: {0} PsBoundParameters:{1}' -f $($args|Out-String), $($PsBoundParameters|Out-String) ) 

$InputObject | Get-String @args

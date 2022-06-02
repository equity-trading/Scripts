param ( [Parameter(ValueFromPipeLine = $True)]$InputObject, $MaxDepth, $MaxElements)
<#
$SimpleHT  = @{ A1 = "computer"; A2 = "folder"; A3 = "plane"; A4 = "flower"; A5 = "dog"; }
$ComplexHT = [ordered]@{ 
    WeekDay = @( [ordered]@{Day   = [pscustomobject]@{abbr='Mon';dayno=1}; Mon="Monday"}, [ordered]@{Day   = [pscustomobject]@{abbr='Tue';dayno=2}; Tue="Tuesday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Wen';dayno=3}; Wen="Wednesday"}, [ordered]@{Day   = [pscustomobject]@{abbr='Thu';dayno=4}; Thu="Thursday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Fri';dayno=5}; Fri="Friday"}, [ordered]@{Day   = [pscustomobject]@{abbr='Sat';dayno=6}; Sat="Saturday"}, 
		[ordered]@{Day   = [pscustomobject]@{abbr='Sun';dayno=7}; Sun="Sunday"} )
    WorkDay=[pscustomobject]@{ Monday = [ordered]@{abbr='Mon';dayno=1}; Tuesday = [ordered]@{abbr='Tue';dayno=2}; Wednesday = [ordered]@{abbr='Wen';dayno=3}; Thursday = [ordered]@{abbr='Thu';dayno=4}; Friday = [ordered]@{abbr='Fri';dayno=5} }
    WeekEnd=[pscustomobject]@{ Saturday   = [pscustomobject]@{abbr='Sat';dayno=6}; Sunday     = [pscustomobject]@{abbr='Sun';dayno=7} }
}
# $tHt=$TestHT3; $DebugPreference=0; Get-String $TestHT3; ConvertTo-Json $tHt -compress
# $tHt=$TestHT3; $DebugPreference=2; Get-String $TestHT3; ConvertTo-Json $tHt -compress
# $DebugPreference=0; $tHt=$ComplexHT; $tHt | Get-String ; '{0}' -f ($tHt|ConvertTo-Json -compress -MaxDepth 5)
# $obj=@{ a=1; b=@{ A1="computer"; A2="folder"; }; c=[pscustomobject]@{x=1}}; $DebugPreference=0; Get-String $obj; ConvertTo-Json $obj -MaxDepth 5 -compress



$myht=@{t=1; @{ t=@{t=1} }=1 }
$myht2=@{"k 2"=1;k1=2}
$myobj=[pscustomobject]$myht2

$myobj2=[pscustomobject]@{$myht2=$myht2}
$myarr2=@( '', 'Test', @{ ''=''; test=1; 1=2; 3='test 3'; 'test 3'=3 })
$myarr3=@( '', 'Test', @( @{ $myobj=$myobj; $myht=$myobj}, @{ $myobj=$myht;  $myht=$myht } ), $myht, $myobj )

$DebugPreference=0; Get-String $myarr2 -MaxDepth 11
@( '', 'Test', @( @{@{'t'=@{'t'=1}}=1, 't'=1}, '' ), @{1=2, 3='test 3', 'test'=1}, '' )

#> 

# "type:{0}/{1}`nmethods:{2}`nproperties:{3}`nprop:{4}" -f ($obj.GetType()).BaseType,($obj.GetType()).Name,(($obj.PsObject.Methods).Name -join(', ')), (($obj.PsObject.Properties).Name -join(', ')), (($obj.PsObject.Properties.NoteProperty).Name -join(', '))
begin {
	
	function Get-String2( [Parameter(ValueFromPipeLine = $True)] $InputObject, $MaxDepth=10, $MaxElements=500, $Iteration=0) {
		begin {
			if (!$Iteration) { $Script:NoOfElements=0 }
			$maxlen=$( $Host.UI.RawUI.WindowSize.Width-10 )
		}
		process {			
			if (!$InputObject) { return "''"}
			$Iteration++; $Script:NoOfElements++; $ret=$null;
			if ($Iteration -gt $MaxDepth) { Write-Warning "Depth exceeds -MaxDepth:$MaxDepth ..."; return "'..'" }
			if ($Script:NoOfElements -gt $MaxElements) { Write-Warning "Number of Elements exceeds -MaxElements:$MaxElements ..."; return "'...'" }
			
			if ($InputObject -is [string]) { 
				$ret="'$InputObject'" 
				Write-Debug '[String]'
			} elseif ($InputObject -is [valuetype]) { 
				Write-Debug '[valuetype]'
				if($InputObject -match "\s")  { $ret="'$InputObject'" } else { $ret=$InputObject }
		    } elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod]) {
				Write-Debug '[GetEnumerator]'
				$arr=$InputObject.GetEnumerator() | Get-String -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
				if ($InputObject.Values -is  [Object]) {
					Write-Debug '[Hashtable]'
					$ret='@{{{0}}}' -f ($arr -join('; '))
				} else {
					Write-Debug '[Object]'
					$ret='@({0})' -f ($arr -join(', '))
				}
			} else {
				
			}
			if ($Iteration -eq 1 ) { 
				$ret="[$(($InputObject.GetType()).Name)] $ret" 
				if($ret.Length -gt $maxlen) { $ret=$ret.substring(0,$maxlen-2)+'..' }
			}
			return $ret
		}
	}

	function Get-String-Dbg2( [Parameter(ValueFromPipeLine = $True)] $InputObject, $MaxDepth=10, $MaxElements=500, $Iteration=0) {
		begin {
			if (!$Iteration) { $Script:NoOfElements=0 }
			Write-Debug '[Get-String-Dbg begin]'
			Write-Debug $('MaxDepth:{0} MaxElements:{1} Type:{2} BaseType:{3} Count:{4} Val:{5}' -f $MaxDepth, $MaxElements,($InputObject.GetType()).BaseType, ($InputObject.GetType()).Name, $InputObject.Count, (Get-JsonString $InputObject) )
			$maxlen=$( $Host.UI.RawUI.WindowSize.Width-10 )
		}		
		process {
			if ($InputObject) {
				Write-Debug $('Iter:{0} NoOfElements:{1} Type:{2} BaseType:{3} Count:{4} Val:{5}' -f $Iteration, $Script:NoOfElements, ($InputObject.GetType()).BaseType, ($InputObject.GetType()).Name, $InputObject.Count, (Get-JsonString $InputObject) )
			} else {
				Write-Debug $('Iter:{0} NoOfElements:{1} Value is NULL' -f $Iteration, $Script:NoOfElements )
			}			
			if (!$InputObject) { return "''"}
			$Iteration++; $Script:NoOfElements++; $ret=$null;

			if ($InputObject -is [string]) { 
				Write-Debug '[String]'
				$ret="'$InputObject'" 
			} elseif ($InputObject -is [valuetype]) { 
				Write-Debug '[valuetype]'
				if($InputObject -match "\s")  { $ret="'$InputObject'" } else { $ret=$InputObject }
		    } elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod]) {
				Write-Debug 'Enumerator' 
				$arr=$InputObject.GetEnumerator() | Get-String -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
				if ($InputObject.Values -is  [Object]) {
					Write-Debug $('Hashtable({0})' -f $arr.Count)
					$ret='@{{{0}}}' -f ($arr -join('; '))
				} else {
					Write-Debug $('Array({0})' -f $arr.Count)
					$ret='@({0})' -f ($arr -join(', '))
				}
			} else {
				$arr=$InputObject.PsObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } |% { @{$_.name=$_.Value} }				
				Write-Debug $('Object({0})' -f $arr.Count)
				$ret='@({0})' -f ($arr -join(', '))
			}
			if ($Iteration -eq 1 ) { 
				$ret="[$(($InputObject.GetType()).Name)] $ret" 
				if($ret.Length -gt $maxlen) { $ret=$ret.substring(0,$maxlen-2)+'..' }
			}
			return $ret			
		}
	}
	function Get-String-Prev( [Parameter(ValueFromPipeLine = $True)] $InputObject, $MaxDepth=10, $MaxElements=500, $Iteration) {
		begin {
			if (!$Iteration) { $Iteration=0; $Script:NoOfElements=0 }
			$maxlen=$( $Host.UI.RawUI.WindowSize.Width-10 )
		}
		process {
			$Iteration++; $Script:NoOfElements++
			$List=$null; $ret=$null;
			if ($Iteration -gt $MaxDepth) { Write-Warning "Depth exceeds -MaxDepth:$MaxDepth ..."; return "'..'" }
			if ($Script:NoOfElements -gt $MaxElements) { Write-Warning "Number of Elements exceeds -MaxElements:$MaxElements ..."; return "'...'" }
			if (!$InputObject) { $ret="''" } elseif ($InputObject -is [string]) { $ret="'$InputObject'" 
			} elseif ($InputObject -is [valuetype]) { 
				if($InputObject -match "\s")  { $ret="'$InputObject'" } else { $ret=$InputObject }
			} elseif ($InputObject -is [array]) { 
				$Arr = @()
				$InputObject | % { $Arr+=@(Get-String -InputObject:$_ -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements ) }
				$ret="@( $($Arr -join ', ') )"
		    } elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod] -and $InputObject.get_Values -isnot  [System.Management.Automation.PsMethod] ) { 
				$Arr = @()
				$InputObject | % { $Arr+=@(Get-String -InputObject:$_ -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements ) }
				$ret=" [Collections.Generic.List[object]]@( $($Arr -join ', ') )"
			} elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod] ) { 
				$List=@($InputObject.GetEnumerator())
				if($val.Length -gt $maxlen) { $val=$val.substring(0,$maxlen-2)+'..' }
			} else {
				$List=$InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } | select-object Name, Value
				$List | Sort-Object -Property Name | % { 
					$Key = Get-String -InputObject:$_.Name  -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Val = Get-String -InputObject:$_.Value -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Arr+=@( "$Key=$Val" )
				}
			}
			if ($List) { 
				$Arr=$(); 
				$List | Sort-Object -Property Name | % { 
					$Key = Get-String -InputObject:$_.Name  -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Val = Get-String -InputObject:$_.Value -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Arr+=@( "$Key=$Val" )
				}
				$ret="@{$($Arr -join ', ')}"
			}
			return $ret
		}
	}
	function Get-String-Dbg-Prev ( [Parameter(ValueFromPipeLine = $True)] $InputObject, $MaxDepth=10, $MaxElements=200, $Iteration) {
		begin {
			if (!$Iteration) { $Iteration=0; $Script:NoOfElements=0 }
			Write-Debug '[Get-String-Dbg begin]'
			Write-Debug $('MaxDepth:{0} MaxElements:{1} Type:{2} BaseType:{3} Count:{4} Val:{5}' -f $MaxDepth, $MaxElements,($InputObject.GetType()).BaseType, ($InputObject.GetType()).Name, $InputObject.Count, (Get-JsonString $InputObject) )
			$maxlen=$( $Host.UI.RawUI.WindowSize.Width-10 )
		}
		process {
			$Iteration++; $Script:NoOfElements++
			if ($InputObject) {
				Write-Debug $('Iter:{0} NoOfElements:{1} Type:{2} BaseType:{3} Count:{4} Val:{5}' -f $Iteration, $Script:NoOfElements, ($InputObject.GetType()).BaseType, ($InputObject.GetType()).Name, $InputObject.Count, (Get-JsonString $InputObject) )
			} else {
				Write-Debug $('Iter:{0} NoOfElements:{1} Value is NULL' -f $Iteration, $Script:NoOfElements )
			}
			$List=$null; $ret=$null;
			if ($Iteration -gt $MaxDepth) { Write-Warning "Depth exceeds -MaxDepth:$MaxDepth ..."; return "'..'" }
			if ($Script:NoOfElements -gt $MaxElements) { Write-Warning "Number of Elements exceeds -MaxElements:$MaxElements ..."; return "'...'" }
			if (!$InputObject) { $ret="''" } elseif ($InputObject -is [string]) { $ret="'$InputObject'" 
			} elseif ($InputObject -is [valuetype]) { 
				Write-Debug "This is a valuetype"
				if($InputObject -match "\s")  { $ret="'$InputObject'" } else { $ret=$InputObject }
			} elseif ($InputObject -is [array]) { 
				Write-Debug "This is an array"
				$Arr = @()
				$InputObject | % { $Arr+=@(Get-String-Dbg -InputObject:$_ -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements ) }
				$ret="@( $($Arr -join ', ') )"
		    } elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod] -and $InputObject.get_Values -isnot  [System.Management.Automation.PsMethod] ) { 
				Write-Debug "This is a list of values (e.g. arraylist)"
				$Arr = @()
				$InputObject | % { $Arr+=@(Get-String-Dbg -InputObject:$_ -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements ) }
				$ret=" [Collections.Generic.List[object]]@( $($Arr -join ', ') )"
			} elseif ($InputObject.GetEnumerator -is [System.Management.Automation.PsMethod] ) { 
				Write-Debug "This is a table of key/value pairs (e.g. hashtable)"
				$List=@($InputObject.GetEnumerator())
				if($val.Length -gt $maxlen) { $val=$val.substring(0,$maxlen-2)+'..' }
				Write-Debug $('[{0}] $List[{1}] : {2}' -f ($List.GetType()).Name,$List.Count,(Get-JsonString $List))
			} else {
				Write-Debug "This is a list of named values (e.g. object)"
				$List=$InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'Property' -or $_.MemberType -eq 'NoteProperty' }
			}
			if ($List) { 
				Write-Debug "Reading the List"
				$Arr=$(); 
				$List | Sort-Object -Property Name | % { 
					$Key = Get-String-Dbg -InputObject:$_.Name -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Val = Get-String-Dbg -InputObject:$_.Value -Iteration:$Iteration -MaxDepth:$MaxDepth -MaxElements:$MaxElements
					$Arr+=@( "$Key=$Val" )
				}
				$ret="@{$($Arr -join ', ')}"
			}
			return $ret
		}
	}
	
	if ($DebugPreference) {
		Write-Debug "Begin"
		Write-Debug "End of Begin"
	}

}



# $InputObject | Get-String @PsBoundParameters
process {
	if ($DebugPreference) {
		Write-Debug "Process"
		Write-Debug $('args              : {0}' -f (Get-JsonString $args)) 
		if ($PsBoundParameter) {
			'---- PsBoundParameters -----'
			$PsBoundParameters
			'---- PsBoundParameters.GetEnumerator() -----'
			$PsBoundParameters.GetEnumerator() | select * | fl
			'---- end of $PsBoundParameters'
			Write-Debug $('PsBoundParameters : {0}' -f (Get-JsonString $PsBoundParameters ) )
		} else {
			Write-Debug $('PsBoundParameters : {0}' -f '$null')
		}
		Write-Debug $('InputObject : {0}' -f (Get-JsonString $InputObject) ) 
		Get-String-Dbg -InputObject:$InputObject @PsBoundParameters
		Write-Debug "End Of Process"
	} else {
		Get-String -InputObject:$InputObject  @PsBoundParameters
	}
}

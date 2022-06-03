param ( [Parameter(ValueFromPipeLine = $True)][object]$InputObject, [string[]]$Exclude, [int]$Depth, [switch]$Cut, [switch]$Cast,[switch]$Test)
# [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')]$Objects, 
begin {
# -erroraction:0 doesn't work, see https://github.com/PowerShell/PowerShell/issues/5749
<#       
        } elseif( $io -is [hashtable]) {
            $v='[hashtable]@{{{0}}}' -f $(($io.Keys | Sort |  % { '{0}={1}' -f ( Get-String $_ -iter:$($iter+1)), (Get-String $io.Item($_) -iter:$($iter+1)) }) -join('; '))
#>			
<#			
            'System.Management.Automation.*Info' {$t=''}
			'System.Collections.ObjectModel.*'   {$t=''}
			default { $t='[{0}]' -f $io.PsObject.TypeNames[0] } 
			*Bound*Parameters, UnboundArguments, Line, ScriptName, ScriptLineNumber, PipelineLength

#>			

	$e=[char]27; $nl=[char]10; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; 
	$red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"; 
	$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 
	$bold="$e[1m";$bold_off="$e[22m"; $strk = "$e[9m"; $strk_off="$e[29m"

    function Get-String( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] [object]$io, [string[]]$Exclude, [switch]$Cut, [switch]$Cast, [int]$Depth=10, [int]$Total=500) {
		begin {
			if(!$script:depth) {
				$script:Exclude,$script:Cut,$script:Cast,$script:MaxDepth,$script:MaxTotal,$script:total=$Exclude,$Cut,$Cast,$Depth,$Total,0
				Write-Debug $("$sc${gry}[${red}START${gry}] -Exclude:{0} -Depth:{1} -Cut:{2} -Cast:{3} MaxTotal:{4} MaxDepth:{5}$rc" -f `
				    $script:Exclude, $Depth, $Cut, $Cast, $script:MaxTotal, $script:MaxDepth )
				Write-Debug (($MyInvocation|fl *bound*,line|out-string) -replace '\s+',' ').trim()
				Write-Debug $("${sc}${grn}BoundParamrs$gry[$blu{0}$gry] : {1}${rc}" -f $PsBoundParameters.Count, 
				$(($PsBoundParameters|out-string) -replace("(?s).+(-+[^`r`n]*)+[`r`n]") -replace("[`n`r]*([^ `n`r]+)[ ]+([^`n`r]+)","$grn`$1 :$gry `$2 ") ).trim() )
			}
			Write-Debug $("$sc${gry}[${grn}begin$gry] ({0}|{1}) `$io:{2}$rc" -f $script:depth, $script:total, (([pscustomobject]$io|Out-String) -replace '\s+',' '))
		}
		process {
			$script:depth++; $script:total++
			$v=(([pscustomobject]$io|Out-String) -replace '\s+',' ')
			Write-Debug $("$sc${gry}[${blu}process-start$gry] ({0}|{1}) `$io$grn type :$gry {2}$grn count :$gry {3}$grn content :$gry {4}..$rc" -f $script:depth, $script:total,
			   $(if ($io.PsObject.TypeNames) { $io.PsObject.TypeNames[0] }else{'n/a'}), $io.Count, 
			   $(if($v.Length -gt 40){$v.Substring(0,40)+'..'}else{$v}))
			$t='[n/a]'
			if ($script:total -gt $script:MaxTotal) {
				Write-Warning "Number of processed fields $script:total exceeds maximum $script:MaxTotal, stop traversing"; 
				$v='n/a'
			} elseif (!$io.PsObject.TypeNames) { 
			# if ($io.GetType -isnot [System.Management.Automation.PsMethod]) { return '$null' } 
				$v='$null'
			} else {
				$v=$null
				switch -wildcard ($io.PsObject.TypeNames[0]) {
					'System.Management.Automation.PSCustomObject' {$t='PSCustomObject'}
					'System.Collections.Generic.List*'  {$t='System.Collections.Generic.List[object]'}
					'System.Collections.ArrayList'  {$t='[System.Collections.ArrayList]'}
					default {  $t='{0}' -f $io.PsObject.TypeNames[0] }
				}
				$t='[{0}]' -f $($t -replace('^System.'))
				if ( !$io) {
					$v='""'
				} elseif ( $io -is [string]) {
					$v='"{0}"' -f $($io -replace ('"','`"') )
				} elseif( $io -is [DateTime]) {
					$v="'$io'"
				} elseif( $io -is [TimeSpan]) {
					$v="'$io'"
				} elseif( $io -is [scriptblock]) {
					$v='{{{0}}}'-f $io.ToString()
				} elseif( $io -is [valuetype]) {
					$v="'$io'"
				} 
				if (!$v) {
					if ($script:depth -gt $script:MaxDepth) {
						Write-Warning "Depth <$script:depth> exceeds -depth:$script:MaxDepth, skipping"; 
						$v='<too deep>'
					} elseif ( $io.GetEnumerator -is [System.Management.Automation.PsMethod] -and $io.IndexOf -is [System.Management.Automation.PsMethod] ) {
						$v='@({0})'  -f $(($io.GetEnumerator() |% { '{0}' -f $(Get-String $_)} ) -join(', '))
					} else {
						if ( $io.GetEnumerator -is [System.Management.Automation.PsMethod] ) {
							$pairs=$io.GetEnumerator()
						} else {
							$pairs=$io.PSObject.Properties |? {$_.MemberType -eq 'NoteProperty'}
							if ($pairs.Count -eq 0) { $pairs=$io.PSObject.Properties }
						}
						$v='@{'+
							$(( $pairs | Sort Name |? {$_.Name -notin $script:Exclude } |% {'{0}={1}' -f (Get-String $_.Name),(Get-String $_.Value) }) -join('; '))+
							'}'
					}
					if(!$iter) {  
						if($script:Cut){
							$max=$Host.UI.RawUI.WindowSize.Width
							if($v.Length -gt $max ) { $v=$v.substring(0,$max-2)+".." }
						}
					}		
				}	
			}
			if ($script:Cast) {
				$v='{0}{1}' -f $t,$v
			}
			Write-Debug $("$sc${gry}[${blu}process-done$gry] ({0}/{1}) ${grn}value :$gry {2} $blu ------$rc" -f $script:depth, $script:total, $(if($v.Length -gt 40){$v.Substring(0,40)+'..'}else{$v}) )
			$script:depth--;
			return	$v
		}
		end {
			Write-Debug $("$sc${gry}[${grn}end$gry] ({0}|{1})$rc" -f $script:depth, $script:total)
			if(!$script:depth) {
				Write-Debug $("$sc${gry}[${red}END${gry}] $rc" )
			}
		}
    }
		
	function Get-String-Test() { 
		
		# script:Get-String -io:$MyInvocation -Cast
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

		$num=1234567890
		$str=[string]$num
		$date=Get-Date
		$interval=(Get-Date) - (Get-Date).AddSeconds(-11)
		$ht=@{t=''; num=$num; str=$str; date=$date; interval=$interval }
		$obj=[pscustomobject]$ht
		$arr=@($str,$num,$interval,$date,$ht,$obj,$null)
		$arrlist=[System.Collections.ArrayList]$arr
		$list=[System.Collections.Generic.List[object]]$arr
		
		$num2=1234567890.123456
		$str2=(1..500|%{ $_}) -join (' ')
		$ht2=@{t=$null;  num=$num; str=$str2; date=$date; interval=$interval; num2=$num2; str2=$str2;}
		$obj2=[psobject]$ht2
		$arr2 = [Object[]]::new(10)
		$arr2[0],$arr2[1],$arr2[2],$arr2[3],$arr2[4],$arr2[5],$arr2[6],$arr2[7],$arr2[8]=$str,$str2,$num,$num2,$date,$interval,$ht,$obj,$ht2,$obj2
		$arrlist2=[System.Collections.ArrayList]$arr2
		$list2=[System.Collections.Generic.List[object]]$arr2
		
		
		$ht3=@{t=1; 1='t'; 't 1'=''; ''='t 1'; null=$null}
		$obj3=[pscustomobject]@{t=1; 1='t'; 't 1'=''; null=$null}
		$arr3=@('',$ht2,$obj2,$str2,$num2,$interval,$null)
	
		$ht4=@{ $ht=$ht; $obj=$obj }
		$obj4=[pscustomobject]$ht4
		$arr4=@( '', 'Test', @{ ''=''; test4=4; 4=4; 'test 4'='test 4'; null=$null })
	
		$ht5=@{t=1; @{ t=@{t=1} }=1 }    
		$obj5=[pscustomobject]$ht5

		'== Test 1 =='
		$stopwatch.Restart()
		$str,$num,$date,$interval,$ht,$obj,$arr,$arrlist,$list | Get-String -Cast

		'== Test 2 =='
		$str2,$num2,$ht2,$obj2,$arr2,$arrlist2,$list2 | Get-String -Cast -Cut
		' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		'== Test 3 =='
		$ht3,$obj3,$arr3 | Get-String -Cut
		' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		'== Test 4 =='
		$ht4,$obj4,$arr4 | Get-String 
		' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		'== Test 5 =='
		$ht5,$obj5       | Get-String
		' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		'== Done =='
	}


	function Get-String-Test-PSCmdlet() { 
		$PSCmdlet.MyInvocation 
		$PSCmdlet | Get-String -Exclude:'ScriptBlock' -Depth 2
	}
	
	function Get-String-Test-MyInvocation() { 
		'-- {0,-15} ---------------' -f '$MyInvocation'
		$MyInvocation | Get-String -Exclude:'ScriptBlock' -Depth:3
		'-- {0,-15} ---------------' -f '$PSCmdlet.MyInvocation'
		$PSCmdlet.MyInvocation | Get-String -Exclude:'ScriptBlock' -Depth:3
		'-- {0,-15} ---------------' -f 'Done'
	}
	function Out-Log($LogStr,$ms) { 
		$LogStr=' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Elapsed: $grn{3}$gry ms$rc" -f 'Main', (Split-Path $MyInvocation.ScriptName -leaf), $MyInvocation.ScriptLineNumber, $stopwatch.Elapsed.TotalMilliseconds,$LogStr
	}
	function test-out-dbg {
		out-myinv $args
	}
	function out-dbg( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')]$Objects, $Depth, [switch]$Cut, [switch]$Cast,[switch]$Test) {
		$Invocation = (Get-Variable MyInvocation -Scope 1).Value
		' -- Line ----'
		$MyInvocation.Line -replace '^\s*'
		$Invocation.Line -replace '^\s*'
		' -- PositionMessage ----'
		$MyInvocation.PositionMessage[0] -replace '.*/'
		$Invocation.PositionMessage[0] -replace '.*/'
		' -- MyCommand.PositionMessage ----'
		$MyInvocation.MyCommand.Parameters | ft
		' -- MyCommand.ParameterSets ----'
		$MyInvocation.MyCommand.ParameterSets | ft
		# ' -- 2 ----'
		# ($MyInvocation |out-string -stream ) -match('(?m)^(Line|BoundParameters|UnboundArguments)$')
		# ($Global:MI2.BoundParameters,$Global:MI2.UnBoundarguments).GetEnumerator()
	} 
	$script:depth=0
	$MyInvocationFilter=@{exclude=@('PS*', 'OffsetInLine', 'InvocationName', 'CommandOrigin', 'PositionMessage', 'HistoryId', 'DisplayScriptPosition', 'ScriptName')}
	Write-Debug $("$sc${gry}[${blu}MainBegin${gry}] {0} PsBoundParameters[{1}]: {2} $rc" -f $(($MyInvocation|fl *bound*,line|out-string) -replace '\s+',' ').trim(),
	    $PsBoundParameters.Count,
		$(($PsBoundParameters|out-string) -replace("(?s).+(-+[^`r`n]*)+[`r`n]") -replace("[`n`r]*([^ `n`r]+)[ ]+([^`n`r]+)","$grn`$1 :$gry `$2 ") ).trim() )

}

# $io | Get-String @PsBoundParameters
process {
	Write-Debug $("$sc${gry}[${blu}MainProcess${blu}] {0} ${grn}BoundParamrs$gry[$blu{1}$gry] : {2}$rc" -f `
		$(($MyInvocation|fl *bound*,line|out-string) -replace '\s+',' '), $PsBoundParameters.Count, 
		$(($PsBoundParameters|out-string) -replace("(?s).+(-+[^`r`n]*)+[`r`n]") -replace("[`n`r]*([^ `n`r]+)[ ]+([^`n`r]+)","$grn`$1 :$gry `$2 ") ).trim())

	Write-Debug $("$sc${gry}[${blu}MainProcess${gry}] InputObject[{0}]: {1} $rc" -f $InputObject.Count,$($InputObject|ConvertTo-Json -compress))
	if ($Test) {
		$Objects
		switch ($Objects) {
			'PSCmdlet'  { Get-String-Test-PSCmdlet @PsBoundParameters}
			'MyInvocation' { Get-String-Test-MyInvocation @PsBoundParameters}
			'out-dbg' { test-out-dbg @PsBoundParameters }
			default { Get-String-Test @PsBoundParameters }
		}
	} elseif ($PSBoundParameters.ContainsKey('InputObject'))  {
		$null=$PSBoundParameters.Remove('InputObject')
		Get-String -io:$InputObject @PsBoundParameters
	} else {
		Write-Warning "Mandatory -InputObject parameter is missing"; 		

	}
	Write-Debug "$sc${gry}[${blu}End Of MainProcess${gry}]$blu ---- $rc"

}
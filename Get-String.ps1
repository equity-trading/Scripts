param ( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')]$Objects, $Depth, [switch]$Cut, [switch]$Cast,[switch]$Test)
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
#>			

	$e=[char]27; $nl=[char]10; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; 
	$red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"; 
	$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 
	$bold="$e[1m";$bold_off="$e[22m"; $strk = "$e[9m"; $strk_off="$e[29m"


    function Get-String( $o, [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] $Objects, [switch]$Cut, [switch]$Cast, [int]$Depth=10) {
		if($Objects.Count) {  
			$script:Cut,$script:Cast,$script:MaxDepth,$script:MaxTotal,$script:depth=$Cut,$Cast,$Depth,500,0
		} else { $Objects=$o }
		$script:depth++;
		foreach ($io in $Objects) {
			$script:total++;
			$v=$null
			# if ($io.GetType -isnot [System.Management.Automation.PsMethod]) { return '$null' } 
			if (!$io.PsObject.TypeNames) { '$null'; continue } 
			switch -wildcard ($io.PsObject.TypeNames[0]) {
				'System.Management.Automation.PSCustomObject' {$t='[PSCustomObject]'}
				'System.Collections.Generic.List*'  {$t='[System.Collections.Generic.List[object]]'}
				'System.Collections.ArrayList'  {$t='[System.Collections.ArrayList]'}
				default {  $t='[{0}]' -f $io.PsObject.TypeNames[0] }
			}
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
				} elseif ( $io.GetEnumerator -is [System.Management.Automation.PsMethod] ) {
					$v='@{{{0}}}'  -f $(($io.GetEnumerator() |% {  # | Sort @{ E={ $_.Key } }
						'{0}={1}' -f (Get-String $_.Key), (Get-String $_.Value) }) -join('; '))
				} else {
					$props=$io.PSObject.Properties |? {$_.MemberType -eq 'NoteProperty'}
					if ($props.Count -eq 0) { $props=$io.PSObject.Properties }
					$v='@{{{0}}}'  -f $(( $props | Sort Name |% {
					   '{0}={1}' -f (Get-String $_.Name), (Get-String $_.Value) })  -join('; '))
				}
				if(!$iter) {  
					if($script:Cut){
						$max=$Host.UI.RawUI.WindowSize.Width
						if($v.Length -gt $max ) { $v=$v.substring(0,$max-2)+".." }
					}
				}		
			}
			if ($script:Cast) {
				'{0}{1}' -f $t,$v
			} else {
				'{0}{1}' -f $t,$v
			}
		}
		$script:depth--;
        return
    }
	function Get-String-Test-MyInvocation() { 
		
		script:Get-String -Objects:$MyInvocation -Cast
	}
	function Out-Log($LogStr,$ms) { 
		$LogStr=' [Done] Total:{0} of {1}; Depth:{2} of {3}; Cut:{4} Cast:{5}' -f $script:total, $script:MaxTotal, $script:depth, $script:MaxDepth, $script:Cut, $script:Cast
		"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Elapsed: $grn{3}$gry ms$rc" -f 'Main', (Split-Path $MyInvocation.ScriptName -leaf), $MyInvocation.ScriptLineNumber, $stopwatch.Elapsed.TotalMilliseconds,$LogStr
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

}

# $io | Get-String @PsBoundParameters
process {
	if ($Test) {
		$null=$PSBoundParameters.Remove('Test')
		# Get-String-Test-MyInvocation @PsBoundParameters
		Get-String-Test @PsBoundParameters
	} else {
		Get-String @PsBoundParameters
	}
    
}
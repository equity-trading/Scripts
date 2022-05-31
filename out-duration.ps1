#########
function out-dura ($tm_val) {
	if ( !$tm_val -and $global:prev_time ) { $tm_val = $global:prev_time }
	$global:prev_time=(Get-Date)
	if ( $tm_val ) {
		$dura=$($global:prev_time-$tm_val)
		if($dura.TotalMilliseconds -lt 100) {
			$fmt="{0,-5:g3} Millisecond"
		} elseif ($dura.TotalSeconds -lt 2) {
			$fmt="{0,-5:g4} Milliseconds"
		} elseif ($dura.TotalSeconds -lt 10) {
			$fmt="{3,1}.{1,3} Second"
		} elseif ($dura.TotalMinutes -lt 1) {
			$fmt="{3,-5} Seconds"
		} elseif ($dura.TotalHours -lt 1) {
			$fmt="{4,2:d2}:{3,2:d2} Minutes"
		} elseif ($dura.TotalHours -lt 24) {
			$fmt="{5,2:d2}:{4,2:d2}:{3,2:d2} Hours"
		} else {
			$fmt="{6}:{5,2:d2}:{4,2:d2}:{3,2:d2} Days"
		}
		$fmt -f $dura.TotalMilliseconds, $dura.Milliseconds, $dura.TotalSeconds, $dura.Seconds, $dura.Minutes, $dura.Hours, $dura.Days
		$global:prev_dura=$dura
		$global:prev_dura_fmt=$fmt
	}
	return
}

##############################
function out-duration( [ref] $data, $mode ) {
    if (!$sc) {
		$sc="`e[#p"; $rc="`e[#q"; $red="`e[1;31m"; $grn="`e[1;32m"; $ylw="`e[1;33m"; $blu="`e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; 
		$bold="`e[1m"; $bold_off="`e[22m";
	}

	if ($data.value -is [DateTime]) { $tm=$data.value }
	
	if ( $tm ) {
		$dura=((Get-Date)-$tm)
		if($dura.TotalMilliseconds -lt 100) {
			$fmt="{0,5:g3} Millisecond"
		} elseif ($dura.TotalSeconds -lt 2) {
			$fmt="{0,5:g4} Milliseconds"
		} elseif ($dura.TotalSeconds -lt 10) {
			$fmt="{3,1}.{1,3} Second"
		} elseif ($dura.TotalMinutes -lt 1) {
			$fmt="{3,5} Seconds"
		} elseif ($dura.TotalHours -lt 1) {
			$fmt="{4,2}:{3,2:d2} Minutes"
		} elseif ($dura.TotalHours -lt 24) {
			$fmt="{5,2}:{4,2:d2}:{3,2:d2} Hours"
		} else {
			$fmt="{6,2}:{5,2:d2}:{4,2:d2}:{3,2:d2} Days"
		}

		$tmp=$fmt -replace(':','')
		
		switch($fmt.Length-$tmp.Length) {
			1 { $fmt_clr="$sc${blu}$fmt$rc" }
			2 { $fmt_clr="$sc${ylw}$fmt$rc" }
			3 { $fmt_clr="$sc${mgn}$fmt$rc" }
			4 { $fmt_clr="$sc${red}$fmt$rc" }
			default { $fmt_clr="$sc${grn}$fmt$rc" }
		}

		$fmt_parts=$fmt_clr -split(' ')

		Write-Output "`$mode:$mode `$fmt_parts:$($fmt_parts -join('; '))"
		Write-Output "$($dura.TotalMilliseconds), $($dura.Milliseconds), $($dura.TotalSeconds), $($dura.Seconds), $($dura.Minutes), $( $dura.Hours,$dura.Days)"
		Write-Output "`$fmt:$fmt"
		Write-Output "    fmt: $($fmt     -f $($dura.TotalMilliseconds), $($dura.Milliseconds), $($dura.TotalSeconds), $($dura.Seconds), $($dura.Minutes), $( $dura.Hours,$dura.Days))"
		Write-Output "`$fmt_clr=$fmt_clr"
		Write-Output "fmt_clr: $($fmt_clr -f $($dura.TotalMilliseconds), $($dura.Milliseconds), $($dura.TotalSeconds), $($dura.Seconds), $($dura.Minutes), $( $dura.Hours,$dura.Days))"


		$fmt_inv="$sc${bold}${grn}{0,-15}${bold_off}: {1}$rc" -f $fmt_parts[1],$fmt_parts[0] 

		Write-Output "`$fmt_inv=$fmt_inv"
		Write-Output "fmt_inv: $($fmt_inv -f $($dura.TotalMilliseconds), $($dura.Milliseconds), $($dura.TotalSeconds), $($dura.Seconds), $($dura.Minutes), $( $dura.Hours,$dura.Days))"

		switch ($mode) {
			"inverse" { $out_fmt=$fmt_inv}
			"colors"  { $out_fmt=$fmt_clr }
			default   { $out_fmt=$fmt }
		}
				
		Write-Output "`$out_fmt=$out_fmt"
		Write-Output $($out_fmt -f $dura.TotalMilliseconds, $dura.Milliseconds, $dura.TotalSeconds, $dura.Seconds, $dura.Minutes, $dura.Hours, $dura.Days)
	}
	$data.value =Get-Date
	return
}

out-dura @args
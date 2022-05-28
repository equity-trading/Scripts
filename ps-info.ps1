$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$myscript=$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf)
$e=[char]27; $nl=[char]10; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; $red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"; $strk = "$e[9m"; $nrml="$e[29m"
$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 

#using namespace System.Management.Automation
# Get-Process WDDriveService,Sysmon,Sysmon,ServiceShell

if (!$Global:Users) { $Global:Users=Get-LocalUser }

$e=[char]27; $nl=[char]10; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; $red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"; $strk = "$e[9m"; $nrml="$e[29m"
$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 
$bold="$e[1m";$bold_off="$e[22m";
$fmt_var="{0,-15}"


$W32_PROC_FMT=@{
    Property=@( 'Name', 'Status', @{N='ExecState';E={$_.ExecutionState}}, 'Priority', @{N='PPID';E={$_.ParentProcessId}}, 'ProcessId', 
    @{N='StartDt';E={$V=$_.CreationDate;'{0}-{1}-{2}' -f $V.Substring(0,4),$V.Substring(4,2),$V.Substring(6,2) }},
    @{N='StartTm';E={$V=$_.CreationDate;'{0}:{1}:{2}' -f $V.Substring(8,2),$V.Substring(10,2),$V.Substring(12,2) }},
    'VM', 'WS',
    @{N='PeakVS';E={$_.PeakVirtualSize}}, @{N='PeakWS';E={$_.PeakWorkingSetSize}},
    @{N='ReadOpCnt';E={$_.ReadOperationCount}}, @{N='ReadTrCnt';E={$_.ReadTransferCount}},@{N='WrtOpCnt';E={$_.WriteOperationCount}}, @{N='WrtTrCnt';E={$_.WriteTransferCount}}, @{N='OthOpCnt';E={$_.OtherOperationCount}}, @{N='OthTrCnt';E={$_.OtherTransferCount}}, 
    @{N='Threads';E={$_.ThreadCount}}, @{N='Handles';E={$_.HandleCount}} , 'Handle'
    @{N='Description';E={if($_.Description){$_.Description}else{$_.Caption}}}, 'ExecutablePath',
    @{N='PROPERTY_COUNT';E={$_.__PROPERTY_COUNT}},@{N='PATH';E={$.__PATH}},
    @{N='CLASS';E={$.__CLASS}},@{N='DERIVATION';E={$.__DERIVATION}},@{N='DYNASTY';E={$.__DYNASTY}},
    @{N='GENUS';E={$.__GENUS}},@{N='SUPERCLASS';E={$.__SUPERCLASS}},@{N='NAMESPACE';E={$.__NAMESPACE}}
)
}

$W32_PROC_TBL=@{ Auto=$true; Property='Name','Priority','ProcessID','WS','StartDT','StartTM','PPID','Threads','Handle','ExecutablePath' }
# Get-WmiObject -Query "Select * from Win32_Process" | Select @W32_PROC_FMT | Sort | ft @W32_PROC_TBL

$W32_SERVICE_FMT=@{
    Property=@( 'Name', 'Status', 'State', 'UserName', 
	@{N='PathName';E={$_.BinaryPathName}}, 
	@{N='Startup';E={$_.StartupType}},
	'ProcessId', 
	@{n="ExitCode";e={if($_.ExitCode -eq $_.ServiceSpecificExitCode ){"$($_.ExitCode)"}else{"$($_.ExitCode)($($_.ServiceSpecificExitCode))"} } },
	@{n="StartMode";e={$_.StartMode+$(if($_.DelayedAutoStart){"/Delayed"} ) }},
    @{N='Description';E={($_.Description -replace "(?<=.{100}).+","..")}},
	@{N='DisplayName';E={($_.DisplayName -replace "(?<=.{60}).+","..") }},
	@{N='DependentServices';E={$_.DependentServices}},
	@{N='ServicesDependedOn';E={$_.ServicesDependedOn}},
	@{N='Can';E={@()+$(If($_.CanPauseAndContinue) { @('Pause:Y')}else{@('Pause:N')})+$(If($_.CanShutdown){ @('ShutDown:Y')}else{@('ShutDown:N')})+$(If($_.CanStop){ @('Stop:Y')}else{@('Stop:N')}) }},
	'ServiceType'
	)	
}

$W32_SERVICE_TBL=@{ Auto=$true; Property='Name','Status','State','StartMode','Description','ProcessId','PathName' }

$ServiceCols=@( @{n="Name";e={$_.Name}}
@{n="Status";e={$_.Status}}
@{n="State";e={$_.State}}
@{n="ExitCode";e={$_.ExitCode}}
@{n="Started";e={$_.Started}}
@{n="AcceptStop";e={$_.AcceptStop}} 
@{n="AcceptPause";e={$_.AcceptPause}}
@{n="ProcessId";e={$_.ProcessId}}
@{n="StartMode";e={$_.StartMode}}
@{n="DelayedAutoStart";e={$_.DelayedAutoStart}}
@{n="PathName";e={$_.PathName}}
@{n="StartName";e={$_.StartName}}
@{n="ServiceSpecificExitCode";e={$_.ServiceSpecificExitCode}}
@{n="CimInstanceProperties";e={$_.CimInstanceProperties}}
@{n="InstallDate";e={$_.InstallDate}}
@{n="DesktopInteract";e={$_.DesktopInteract}}
@{n="Description";e={$_.Description}}
@{n="Caption";e={$_.Caption}}
)

$ServiceFmt=@(
@{n="ServiceName";e={$(if( $_.Name -notlike "* *" ){'{0} - ' -f $_.Name}) + $_.Caption}}
@{n="ServiceExitCode";e={if($_.ExitCode -eq $_.ServiceSpecificExitCode ){"$($_.ExitCode)"}else{"$($_.ExitCode)($($_.ServiceSpecificExitCode))"} } }
@{n="ServiceStartMode";e={$_.StartMode+$(if($_.DelayedAutoStart){"/Delayed"} ) }}
)

<#
@{n="Status";e={$_.Status}}
# @{n="Description";e={$_.Description}}
@{n="Caption";e={$_.Caption}}
DisplayName,
SystemName, 
AcceptPause, 
AcceptStop,
StartName,
DelayedAutoStart,
PathName,
DesktopInteract,
ServiceType,
Description,
InstallDate,
ServiceSpecificExitCode,
CimClass, CimInstanceProperties, CimSystemProperties 
#>


##################################

function Get-MyServices($cmds=@("SC")) {	
	"$sc$blu[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$blu]$gry called on line $cyn{3}$gry at $ylw{4}$gry | $ylw{5}$blu[$ylw{6}$blu]${gry}: $ylw{7}$gry. $rc" -f $MyInvocation.MyCommand.Name, 
		$myscript,$(&{$MyInvocation.ScriptLineNumber}),$MyInvocation.ScriptLineNumber, $(Get-Date), 
	   '$PsBoundParameters',$(@($PsBoundParameters.Keys).Count),$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) | Out-Host

	foreach ($cmd in $cmds) {
		switch($cmd) {
			"SC" { 
# https://stackoverflow.com/questions/8097354/how-do-i-capture-the-output-into-a-variable-from-an-external-process-in-powershe/35980675#35980675
# $SC_LINES =sc.exe query 
# $SC_LINES =sc.exe query  | Out-String -stream  # many lines
# $SC_OUTPUT=sc.exe query  | Out-String # just one line
# $SC_LINES =sc.exe query  |? {$_.Trim()} # empty lines removed
# $SC_LINES =sc.exe query  |% {$_.Trim()} # lines are trimmed
# $SC_LINES =sc.exe query  |% {$_.Trim()}|? $_ # lines are trimmed, empty lines removed

				$tArr=@(); $Idx=0; $TestCnt=100000
				exe-cmd "sc.exe query"  # output goes into $Global:CMD_OUT

				##################################
				 # -replace('(\w+)=([0-9]\w*)  (.+)','$1=$2; $1_INFO="$3"') -replace('(\w+)=([0-9]\w*).*','$1=$2') 
				$Global:SC_SERVICES=$(
				##################################
				$Global:CMD_OUT -replace('([\w:]+)\W*:\W*','$1=') -replace('^(\w+)=(.*)','$1="$2"') | 
				Select-Object -first $TestCnt | % {
					# '[{0}] {1}' -f $IDX, $_
					if ($_ -like 'SERVICE_NAME=*') {
						if ($tArr) {  
							$tArr=$( $EXTRA=@(); $tArr |% { if($_ -match '\w+=.*' ) { $_ } else {$EXTRA+=@($_)} }; 'SERVICE_ATTR="{0}"' -f $EXTRA )
							# $scriptblock=[scriptblock]::Create("New-Object -TypeName PSCustomObject -Property ([ordered]@{ IDX=$Idx; $($tArr -join('; '))})")
							& ([scriptblock]::Create("New-Object -TypeName PSCustomObject -Property ([ordered]@{ IDX=$Idx; $($tArr -join('; '))})"))
							$Idx++
						}
						$tArr=@()
					}
					$tArr+=@($_)
				}
				##################################
				)
				'{0} Services loaded. Use: $SC_SERVICES | select-object -First {0} | Format-Table -auto *' -f $Global:SC_SERVICES.Count
				##################################
			}

			"SC2" {
				##################################
				exe-cmd "sc.exe query" # output goes into $Global:CMD_OUT
				$Global:SC_SERVICES=$(
					$prevIdx=0
					for ( $Idx=0; $Idx -lt $Global:SC_LINES.Count; $Idx++)  {
						# '[{0}] {1}' -f $IDX, $_
						if ($Global:SC_LINES[$Idx] -like 'SERVICE_NAME=*') {
							[pscustomobject] (ConvertFrom-StringData $($Global:SC_LINES[$prevIdx..$($Idx-1)] -replace '^\(','EXTRA_ATTR:(' -join("`n"))  -Delimiter ':')
							$prevIdx=$Idx
						}
					}
					##################################
				)
				'{0} Services loaded. Use: $SC_SERVICES | select-object -First {0} | Format-Table -auto *' -f $Global:SC_SERVICES.Count
				##################################
			}

			"CIM" {
				$Global:WIN32_SERVICE=Get-CimInstance Win32_Process -ea 0
			}
			

			default {
				$Global:SERVICES=get-service
			}
		}
	}
}





##################################
function pval($vals, [int]$max,[switch]$noclr,[string]$separator="`n"){
	[string]$Text=""
	[int]$Cnt=0
	foreach ($Obj in pobj $vals) {
		if($Cnt) { $Text+=$separator }
		$Text+=[string]$(
			if($Obj.Cut) {
				if($noclr) { 
					"{0}"  -f $($Obj.Str -replace "(?<=.{$max}).+","...")
				} else { 
					"${sc}${cyn}{0}${rc}"  -f $($Obj.Str -replace "(?<=.{$max}).+","$sc${blu}...$rc" )
				}
			} else {
				$Obj.Str
			}
		)
		$Cnt++
	}
	return $Text
}

function parr($arr, [switch]$noclr, $fmt_body="[{0}] {1}", $fmt_join=", ", $fmt_wrap="@( {0} )", $fmt_cut="...") {
	[string]$body_str=""
	# $cstr"$e[${color}m$($_.Name)${e}[0m"
	if ($arr -ne $null) {
		if(!$noclr) {
		    $fmt_body=$fmt_body -replace("(${fmt_body[0]}${fmt_body[4]}])","$sc$ylw`$0$rc") ;# -replace(${fmt_body[3]},"$sc$ylw${fmt_body[3]}$rc")
			$fmt_join="$sc$blu$fmt_join$rc" 
			<#
		    $fmt_wrap=$fmt_wrap -replace(${fmt_wrap[1]},"$sc$blu@$ylw${fmt_wrap[1]}$rc") -replace(${fmt_wrap[7]},"$sc$ylw${fmt_wrap[7]}$rc")
			$fmt_cut="$sc${blu}$fmt_cut$rc"
			#>
		}
		$idx=0
		"fmt_body:$fmt_body fmt_join:$fmt_join fmt_wrap:$fmt_wrap fmt_cut:$fmt_cut  "  |  Out-Host
		$body_str=$( ($arr |% { $fmt_body -f $idx++, $( pval $_ -noclr )  } ) -join($fmt_join) )		
	    $body_str=$( $fmt_wrap -f $($body_str -replace "(?<=.{$max}).+",$fmt_cut) )+"$nc"
	}
	return $fmt_wrap -f $body_str
}

function pvar($val,[string] $var,[switch] $noclr,[switch] $novar,[string]$scope=1) {
	# pargs
    [string] $str=""
	[int]    $size=0
	[string] $type=""
	if($var) {
		switch -wildcard ($var) { '*:*' { $Scope=$var -replace ':.*',''; $Var=$Var -replace '.*:',''; } } 
		$val=Get-Variable -Name $Var -Scope $Scope -ValueOnly -ErrorAction "SilentlyContinue"
		if (!$?) { 
			$str="N/A" 
		}
		
		# 'scope:{0} var:{1} val:{2}' -f $scope,$var,$val
	}
	if ($val -ne $null ) { 
		if($val -is [hashtable]) { 
			$size=@($val.Keys).Length
			$str=$(pval -vals:$val -noclr:$noclr)
			$type='Hash'
		} elseif ($val -is [array]) {
			$size=$val.Length
			$type='Array'
			$str=$(parr -arr:$val -noclr:$noclr)
		} elseif ($val -is [string]) {
			$type='String'
			$str=$val
			$size=$str.Length
		} elseif ($val -is [int]) {
			$type='Int'
			$str=$val
			$size=$str.Length
			$str=$(pval -vals:$val -noclr:$noclr)
		} elseif ($val -is [scriptblock]) {
			$type='ScripBlock'
			$str=$val.ToString()
			$size=$val.Length
		} elseif ($val -is [object]) {
			$type='Object'
			$size=$val.Length
			$str=$(pval -vals:$val -noclr:$noclr)
        } else {
			$type='Other'
			$size=$val.Length
			$str=$(pval -vals:$val -noclr:$noclr)
		}
	} 
	if ($novar) {
		if ($noclr) {
			$fmt="'[{0}({1}):{2}]'"
		} else {
			$fmt="$sc$ylw[$cyn{0}$ylw($red{1}$ylw)]:{2}$rc"
		}
		$fmt -f $type, $size, $str
	} else {
		# $type=$(($val.GetType()).FullName) -replace '.*\.([^.]*)$','$1'
		if(!$var) { 
			$stack=Get-PSCallStack
			$pos=$stack[1].Position
			$fnc=$stack[0].FunctionName
			$var=$pos -replace("$fnc ",'') 
			# 'pos:{0} fnc:{1} var:{2} type:{3}' -f $pos,$fnc,$var,$type
		}
		if ($noclr) {
			$fmt="{0}[{1}({2})]:{3}"
		} else {
			$fmt="$sc$grn{0}$ylw[$cyn{1}$ylw($red{2}$ylw)]:{3}$rc"
		}
		if ($scope -notmatch '[0-9]') { $var="${scope}:${var}"}
		$fmt -f $var, $type, $size, $str
	}
}

function DbgInfo-Func( [string] $Text, $Vals,[string[]] $Vars,[switch] $noclr) {
	$stack=Get-PSCallStack
	# $stack | ft *
	# (Get-PSCallStack | gm Arguments).Definition 
	[string] $FuncLoc=$stack[1].Location -replace ' line ',''
	[string] $FuncPos=$stack[1].Position
	[string] $FuncName=$stack[1].Command+'('+ $($stack[1].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 
		
	[string] $CallerLoc=$stack[2].Location -replace ' line ',''
	[string] $CallerPos=$stack[2].Position
	[string] $CallerName=$stack[2].Command+'('+ $($stack[2].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 
	[string[]] $rows=@()
	
	if($Text) { 
		if (!$noclr) {
			$Text=$Text -replace ('Error:',"${sc}${errClr}Error${rc}:") -replace ('Warning:',"${sc}${wrnClr}Warning${rc}:")
		}
		
		$rows+=@($Text)
	}  
	
	foreach ($Var in $Vars) {
		$rows+=@(pvar -Var:$Var -scope:2)
	}
	foreach ($Val in $Vals) {
		$rows+=@(pvar $Val -novar -scope:2)
	}
 
	if ($rows.Length) {
		if ($noclr) {
			$fmt="[{0}] {2}"
		} else {
			$fmt="$sc$blu[$ylw{0}$blu] $gry{2}$rc"
		}
		$fmt -f $FuncLoc, $FuncName, $( $rows -join(' '))
	} else {
		# '[{0} {1}] Called in {2} at {3} as {4}' -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos
		if ($noclr) {
			$fmt="[{0}] {1} called at {5} on {3} as {4}"
		} else {
			$fmt="$sc$blu[$ylw{0}$blu] $cyn{1}$gry called at $ylw{5}$gry on $ylw{3}$gry as $cyn{4}$rc"
		}
		$fmt -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos, $(Get-Date)
	}
	if ($stack.Length -gt 10 ) { throw "Stack is too deep : $($stack.Length)." }
	return
}

# Remove-Alias pargs -ErrorAction "SilentlyContinue"
New-Alias -Name pargs -Value 'DbgInfo-Func' -ErrorAction "SilentlyContinue"

function get-ResultObject ($R) {
	if ($R) {
		$global:LastResult=$R
		$global:LastResult | format-list *
	} else {
		$global:LastResult=@{}
	}
}

function get-ServiceInfo2 ($ServiceName,$ProcessId) {
	if ($ServiceName) {
		$global:LastService=get-service -Name $ServiceName 
		$global:LastService | format-list Status,Name,StartupType,UserName,ServiceName,Description,DelayedAutoStart,BinaryPathName,RequiredServices,ServiceType,ServiceHandle,CanPauseAndContinue,CanShutdown,CanStop
		if ($ProcessId) { 
			$global:LastProcess=get-process -id $ProcessId; $global:LastProcess | format-list * 
		} else {
			$global:LastProcess=@{}
		}
	} else {
		$global:LastService=@{}
	}
}

function add-hashtable-values ([object] $ht,[string []] $keys, [object[]] $values) {
	if (!$ht -is [hashtable]) {return}
	if (!$ht) { $ht=@{} }
	if (!$keys.count)         {return}
	[string] $k
	while ($i -lt ($keys.count-1)) {
		$k=$keys[$i]
		if (!$ht.ContainsKey($k))  {
			if ( $i -lt ($keys.count-1) ) { $ht.$k=@{}; } 
		}
		$ht=$ht.$k
		$i++
	}
	$k=$keys[$i]
	if (!$ht.ContainsKey($k)) {  $ht.$k=@()  }

	'k:{0}' -f $k
	foreach ($v in $values) {
		$ht.$k+=@($v)
	}
	return
}
	
function get-connection-map ([switch] $Get) {
	if( $Get -or !$global:Connection.Length ) { $global:Connection=Get-NetTCPConnection -State Listen,Established -AppliedSetting Internet -ea 0 }
	$ConnCnt=0; $Global:RemoteAddrMAP=@{}; $Global:PidLocalRemoteMap=@{}; $Global:ConnInfo=@()
	Foreach($Conn in $Connection ) {
		
		[string]$OwningPid=$Conn.OwningProcess; [string]$rAddr=$Conn.RemoteAddress; [string]$rPort=$Conn.RemotePort; [string]$lPort=$Conn.LocalPort
		
		$Info=@{ Pid=[string]$Conn.OwningProcess; LocalPort=[string]$Conn.LocalPort; RemoteAddress=[string]$Conn.RemoteAddress; RemotePort=[string]$Conn.RemotePort}
		
		# $key=$Info.$Pid
		# $key2=$Info.$LocalPort
		
		add-hashtable-values $PidLocalRemoteMap $Pid.$LocalPort 
		
		add-hashtable-values $Info $Pid.$LocalPort 
		
		if (!$Global:PidLocalRemoteMap.ContainsKey($($Info.Pid))) { $Global:PidLocalRemoteMap.$($Info.Pid)=@{}; $Global:PidLocalRemoteMap.$($Info.Pid).LocalPort=@{Type='LocalPort'} }
		if (!$Global:PidLocalRemoteMap.$($Info.Pid).LocalPort.ContainsKey($lPort)) { $Global:PidLocalRemoteMap.$($Info.Pid).LocalPort.$lPort=@{};  }
		$Global:PidLocalRemoteMap.$($Info.Pid).LocalPort.$lPort+=@{ "$rAddr`:$rPort"=$ConnCnt}
		
		if ( $Conn.AppliedSetting -eq 'Internet' -and $rAddr -notin '0.0.0.0','127.0.0.1','::' ) {
			if (!$Global:RemoteAddrMAP.ContainsKey($rAddr)) { 
				$Global:RemoteAddrMAP.$rAddr=@{}; $Global:RemoteAddrMAP.$rAddr.RemotePort=@{}; $Global:RemoteAddrMAP.$rAddr.OwningPid=@{}; $Global:RemoteAddrMAP.$rAddr.Conn=@()
			}
	# Port: Port.$RemotePort.$OwningProcess=@Conn
			if (!$Global:RemoteAddrMAP.$rAddr.RemotePort.ContainsKey($rPort)) { $Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort=@{} }
			if (!$Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort.ContainsKey($($Info.Pid))) { $Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort.$($Info.Pid)=@{Type='OwningPid'};  }
			if (!$Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort.$($Info.Pid).ContainsKey($lPort)) { $Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort.$($Info.Pid).$lPort=@{Type='LocalPort';Conn=@()};  }
			$Global:RemoteAddrMAP.$rAddr.RemotePort.$rPort.$($Info.Pid).$lPort.Conn+=@($ConnCnt)
			
	# PID: PID.$OwningProcess.$LocalPort=@RemotePort
			if (!$Global:RemoteAddrMAP.$rAddr.OwningPid.ContainsKey($($Info.Pid))) { $Global:RemoteAddrMAP.$rAddr.OwningPid.$($Info.Pid)=@{ LocalPort=@(); RepotePort=@(); Conn=@()} }
			$Global:RemoteAddrMAP.$rAddr.OwningPid.$($Info.Pid).LocalPort+=@($lPort)
			$Global:RemoteAddrMAP.$rAddr.OwningPid.$($Info.Pid).RepotePort+=@($rPort)
			$Global:RemoteAddrMAP.$rAddr.OwningPid.$($Info.Pid).Conn+=@($ConnCnt)

	# Conn: Conn=@Conn
			$Global:RemoteAddrMAP.$rAddr.Conn+=@($ConnCnt)
			$Info+=@{Type='Internet'}
		}
		$Global:ConnInfo+=@( $Info )
		$ConnCnt++
		# if ($ConnCnt -gt 1) {break}
	}
	'[get-connection-map] $Global:Connection[{0}], $Global:ConnInfo[{0}]; Hashtable: $Global:PidLocalRemoteMap[{1}], $Global:RemoteAddrMAP[{2}]. Use ConvertTo-JSON $Global:RemoteAddrMAP -Compress -Depth 5' -f `
	   $Global:Connection.Length,@($Global:PidLocalRemoteMap.Keys).Length,@($Global:RemoteAddrMAP.Keys).Length
# @($Global:RemoteAddrMAP.Keys)[0] | % { $k=$_; '"RemoteAddr":"{0}"' -f $k; ConvertTo-JSON $Global:RemoteAddrMAP.$k  -Compress -Depth 5 }
# ConvertTo-JSON $Global:RemoteAddrMAP -Compress -Depth 5
}
# get-connection-map -get

# Print HashTable
# $Global:ConnInfo[0..1] | ConvertHashtableTo-Object  | ft -auto
# RemotePort Type     LocalPort Pid  RemoteAddress
# ---------- ----     --------- ---  -------------
# 2179       Internet 61686     7572 fe80::1:52b2:a7f2:45b7%40
# 61686      Internet 2179      2728 fe80::1:52b2:a7f2:45b7%40

# Alternative: cast a hash table to a pscustomobject:
# $Global:ConnInfo[0..1] |% {[pscustomobject] $_}     | ft  -auto 
# RemotePort Type     LocalPort Pid  RemoteAddress
# ---------- ----     --------- ---  -------------
# 2179       Internet 61686     7572 fe80::1:52b2:a7f2:45b7%40
# 61686      Internet 2179      2728 fe80::1:52b2:a7f2:45b7%40

# Alternative: ConvertTo-JSON
# $Global:ConnInfo[0..1] | ConvertTo-JSON -depth 3 -compress

##################################
# ConvertHashtableTo-Object
function ConvertHashtableTo-Object {
	# https://gordon.byers.me/powershell/convert-a-powershell-hashtable-to-object
	# alternatives: 
	# $Global:ConnInfo[0..1] |% {[pscustomobject] $_} | ft  -auto 
	# $Global:ConnInfo[0..1] | ConvertTo-JSON -depth 3 -compress
	
    [CmdletBinding()]
    Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [hashtable]$ht
    )
    PROCESS {
        $results = @()

        $ht | %{
            $result = New-Object psobject;
            foreach ($key in $_.keys) {
				[object] $val=$_[$key]
				if ( $val -is [hashtable]) {
					$val=ConvertHashtableTo-Object $val
				} elseif ($val -is [array] ) {
					$val=$val -join (',')
				} 
                $result | Add-Member -MemberType NoteProperty -Name $key -Value $val
             }
             $results += $result;
         }
        return $results
    }
}


function get-process-map ([string[]] $names,[int[]] $ids) {

	$global:Process_MAP=@{}
	$global:Process=@()

	''
	'[get-process-map] names[{0}]:{1} ids[{2}]:{3}' -f $names.Count,($names -join ','),$ids.Count,($ids -join ',')
	
	
	$global:Process=Get-Process -ea 0
	$cnt=$global:Process.Count

	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($global:Process[0..2]).Name -join ','} else {($global:Process).Name -join ','} )
	} else {
		'No object matching the search condition'
	}
	Foreach($P in $global:Process) {
		$ProcessID=$P.ID
		$global:Process_MAP.Add($ProcessID,$P)
	}
}


function get-win32process-map ([string[]] $names,[int[]] $ids) {

	$global:win32process_MAP=@{}
	$global:win32process=@()

	''
	'[get-win32process-map] names[{0}]:{1} ids[{2}]:{3}' -f $names.Count,($names -join ','),$ids.Count,($ids -join ',')
	
	
	$global:win32process=Get-CimInstance Win32_Process -ea 0
	$cnt=$global:win32process.Count

	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($global:win32process[0..2]).ProcessName -join ','} else {($global:win32process).ProcessName -join ','} )
	} else {
		'No object matching the search condition'
	}
	Foreach($P in $global:win32process) {
		$ProcessID=$P.ProcessID
		$global:win32process_MAP.Add($ProcessID,$P)
	}
}


function get-win32service-map ([string[]] $names,[int[]] $ids) {

	$global:win32service_MAP=@{}
	$global:win32service=@()
	$global:win32service_pid_MAP=@{}

	''
	'[get-win32service-map] names[{0}]:{1} ids[{2}]:{3}' -f $names.Count,($names -join ','),$ids.Count,($ids -join ',')
	
	
	$global:win32service=Get-CimInstance Win32_Service -ea 0
	$cnt=$global:win32service.Count

	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($global:win32service[0..2]).Name -join ','} else {($global:win32service).Name -join ','} )
	} else {
		'No object matching the search condition'
	}
	Foreach($S in $global:win32service) {
		$ProcessID=$S.ProcessId
		$ServiceName=$S.Name
		if (!$global:win32service_MAP[$ProcessID]) { $global:win32service_MAP[$ProcessID]=@() }
		$global:win32service_MAP[$ProcessID]+=@($S)		
		$global:win32service_pid_MAP[$ServiceName]=$ProcessID
	}
}


function get-processes($names,[int[]]$ids) {

	$global:Process=@()
	$global:Win32_Process=@()

	''
	'[get-processes] names[{0}]:{1} ids[{2}]:{3}' -f $names.Count,($names -join ','),$ids.Count,($ids -join ',')
	
	$filterName=@()
	$ConditionName=@()
	$filterID=@()
	$ConditionID=@()
	$filterOther=@()
	$ConditionOther=@()
	if ($names) { 
		foreach($name in $names) {
			switch -wildcard ($name)  {
				"[1-9]*"    { $filterName += @($name); if($name -is [int] -and $name -gt 0) { $FilterID += @($name) } }
				'(*'        { $ConditionOther += @($name) }
				'*%*'       { $ConditionOther += @("CommandLine like $name") }
				default     { $filterName += @($name) }
			}
		}
	}
	
# default     { $filterName += @("(Name like '%$name%' or Caption like '%$name%' or DisplayName like '%$name%')")
	
	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($Result[0..2]).LocalPort -join ','} else {($Result).LocalPort -join ','} )
	} else {
		'No object matching the search condition'
	}

	if ($filterName.Count) { 
		$cnt=$filterName.Count
		"{0} name$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($filterName[0..2]) -join ','} else {($filterName) -join ','} )
		foreach ($name in $filterName) {
			$ConditionName+=@( "( CommandLine like '%$name%' )" )
		}
	}
    '[get-processes] filterName[{0}]:{1} ConditionName[{2}]:{3}' -f $filterName.Count,($filterName -join ','),$ConditionName.Count,($ConditionName -join ',')	

	if ($ids.Count) { 
		foreach ($id in $ids) {
			if ($id) { $filterID += @($id) }
		}
	}

    '[get-processes] filterID[{0}]:{1} ids[{2}]:{3}' -f $filterID.Count,($filterID -join ','),$ids.Count,($ids -join ',')	
	if ($filterID.Count) { 
		$cnt=$filterID.Count
		"{0} id$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($filterID[0..2]) -join ','} else {($filterID) -join ','} )
		foreach ($id in $filterID) {
			$ConditionID+=@("ProcessID=$id")
		}
	}
	
    '[get-processes] ConditionID[{0}]:{1}' -f $ConditionID.Count,($ConditionID -join ',')
	
	if ($ConditionOther.Count) { 
        $cnt=$ConditionOther.Count
		"{0} other condition$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($ConditionOther[0..2]) -join ','} else {($ConditionOther) -join ','} )
	}
    '[get-processes] ConditionOther[{0}]:{1}' -f $ConditionOther.Count,($ConditionOther -join ',')	
	

	#$ProcessName = (Get-Process -Id $ProcessPID).Name
	# $CpuCores = (Get-WMIObject Win32_ComputerSystem).NumberOfLogicalProcessors


	$Conditions=@()
	$Conditions=$ConditionName+$ConditionID+$ConditionOther
	$cnt=$Conditions.Count
	
	$filterStr='( {0} )' -f ($Conditions -join ') or (')

	"{0} filter$(if($cnt -ne 1){'s'}): {1}" -f $cnt,$filterStr
		
	$Result=Get-CimInstance Win32_Process -Filter $filterStr -ea 0
	$global:Win32_Process=$Result
	$cnt=$Result.Count

	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($Result[0..2]).Name -join ','} else {($Result).Name -join ','} )
	} else {
		'No object matching the search condition'
	}
	Foreach($P in $Result ) {
		$Key=$P.ProcessId
		$ProcessOwner=Invoke-CimMethod -InputObject $P -MethodName GetOwner -ea 0
		if ($global:RESULT_MAP[$Key]) {
			$global:RESULT_MAP[$Key].ProcessId           = $P.ProcessId
			$global:RESULT_MAP[$Key].CommandLine         = $P.CommandLine
			$global:RESULT_MAP[$Key].Path                = $P.Path
			$global:RESULT_MAP[$Key].ProcessOwner        = $( if ($ProcessOwner.ReturnValue -eq 0) { '{0}/{1}' -f $ProcessOwner.Domain,$ProcessOwner.User} )
			$global:RESULT_MAP[$Key].PPid                = $P.ParentProcessId
			$global:RESULT_MAP[$Key].Process             = $P.ProcessName
			$global:RESULT_MAP[$Key].VM                  = $P.VM
			$global:RESULT_MAP[$Key].WS                  = $P.WS
			$global:RESULT_MAP[$Key].MaxWS               = $P.MaximumWorkingSetSize
			$global:RESULT_MAP[$Key].MinWS               = $P.MinimumWorkingSetSize
			$global:RESULT_MAP[$Key].KernelModeTime      = $P.KernelModeTime
			$global:RESULT_MAP[$Key].UserModeTime        = $P.UserModeTime
			$global:RESULT_MAP[$Key].Handle              = $P.Handle
			$global:RESULT_MAP[$Key].HandleCount         = $P.HandleCount
			$global:RESULT_MAP[$Key].ThreadCount         = $P.ThreadCount
			$global:RESULT_MAP[$Key].SessionId           = $P.SessionId
			$global:RESULT_MAP[$Key].Priority            = $P.Priority
			$global:RESULT_MAP[$Key].OtherOperCnt        = $P.OtherOperationCount
			$global:RESULT_MAP[$Key].OtherTranCnt        = $P.OtherTransferCount
			$global:RESULT_MAP[$Key].ReadTranCnt         = $P.ReadTransferCount
			$global:RESULT_MAP[$Key].ReadOperCnt         = $P.ReadOperationCount
			$global:RESULT_MAP[$Key].WriteOperCnt        = $P.WriteOperationCount
			$global:RESULT_MAP[$Key].WriteTranCnt        = $P.WriteTransferCount
			$global:RESULT_MAP[$Key].StartTime           = $P.CreationDate
			$global:RESULT_MAP[$Key].ExitTime            = $P.TerminationDate
			
		} else {
			$global:RESULT_MAP[$Key]=[pscustomobject]@{
				Service             = 'N/A'
			    ServiceState        = $null
			    StartMode           = $null
			    ServiceOwner        = $null
			    AcceptStop          = $null
			    AcceptPause         = $null
			    ExitCode            = $null
				ProcessId           = $P.ProcessId
				CommandLine         = $P.CommandLine
   			    Path                = $P.Path
				ProcessOwner        = $( if ($ProcessOwner.ReturnValue -eq 0) { '{0}/{1}' -f $ProcessOwner.Domain,$ProcessOwner.User} )
				PPid                = $P.ParentProcessId
				Process             = $P.ProcessName
				VM                  = $P.VM
				WS                  = $P.WS
				MaxWS               = $P.MaximumWorkingSetSize
				MinWS               = $P.MinimumWorkingSetSize
				KernelModeTime      = $P.KernelModeTime
				UserModeTime        = $P.UserModeTime
				Handle              = $P.Handle
				HandleCount         = $P.HandleCount
				ThreadCount         = $P.ThreadCount
				SessionId           = $P.SessionId
				Priority            = $P.Priority
				OtherOperCnt        = $P.OtherOperationCount
				OtherTranCnt        = $P.OtherTransferCount
				ReadTranCnt         = $P.ReadTransferCount
				ReadOperCnt         = $P.ReadOperationCount
				WriteOperCnt        = $P.WriteOperationCount
				WriteTranCnt        = $P.WriteTransferCount
				StartTime           = $P.CreationDate
				ExitTime            = $P.TerminationDate
			}
		}
	}
}

function DbgInfo-Func( [string] $Text, $Vals,[string[]] $Vars,[switch] $noclr) {
	$stack=Get-PSCallStack
	# $stack | ft *
	# (Get-PSCallStack | gm Arguments).Definition 
	[string] $FuncLoc=$stack[1].Location -replace ' line ',''
	[string] $FuncPos=$stack[1].Position
	[string] $FuncName=$stack[1].Command+'('+ $($stack[1].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 
		
	[string] $CallerLoc=$stack[2].Location -replace ' line ',''
	[string] $CallerPos=$stack[2].Position
	[string] $CallerName=$stack[2].Command+'('+ $($stack[2].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 
	[string[]] $rows=@()
	
	if($Text) { 
		if (!$noclr) {
			$Text=$Text -replace ('Error:',"${sc}${errClr}Error${rc}:") -replace ('Warning:',"${sc}${wrnClr}Warning${rc}:")
		}
		
		$rows+=@($Text)
	}  
	
	foreach ($Var in $Vars) {
		$rows+=@(pvar -Var:$Var -scope:2)
	}
	foreach ($Val in $Vals) {
		$rows+=@(pvar $Val -novar -scope:2)
	}
 
	if ($rows.Length) {
		if ($noclr) {
			$fmt="[{0}] {2}"
		} else {
			$fmt="$sc$blu[$ylw{0}$blu] $gry{2}$rc"
		}
		$fmt -f $FuncLoc, $FuncName, $( $rows -join(' '))
	} else {
		# '[{0} {1}] Called in {2} at {3} as {4}' -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos
		if ($noclr) {
			$fmt="[{0}] {1} called at {5} on {3} as {4}"
		} else {
			$fmt="$sc$blu[$ylw{0}$blu] $cyn{1}$gry called at $ylw{5}$gry on $ylw{3}$gry as $cyn{4}$rc"
		}
		$fmt -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos, $(Get-Date)
	}
	if ($stack.Length -gt 10 ) { throw "Stack is too deep : $($stack.Length)." }
	return
}


############################################
# ascii-codes replaces non-ASCII characters with hex codes
# $orig="`e[33m yellow `e[m"; $orig | ascii-codes
# 0x1B[33m yellow 0x1B[m

function ascii-codes() {
    [CmdletBinding()][OutputType([string])] param( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] [string[]]$strings )
	Process {
		$strings |? {$_} |% { 
		
			$orig=$_.TocharArray()
			$new= ( $orig |% { $code=[int] $_; if ( $code -lt 0x20 -or $code -gt 0x7F  ) {'0x{0,2:X2}' -f [int]$_ } else {$_}} )
			$new -join ('')
		}
	}
}

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


function exe-cmd-simple( [string] $cmd_line, [switch]$quiet, [switch] $raw, [int]$sample_lines=4) {
    if (!$sc) {
		$sc="`e[#p"; $rc="`e[#q"; $red="`e[1;31m"; $grn="`e[1;32m"; $ylw="`e[1;33m"; $blu="`e[1;34m"; $mgn="`e[1;35m"; $cyn="`e[1;36m";
		$bold="`e[1m"; $bold_off="`e[22m";
	}
	if (!$cmd_line) {
@" 
$sc${blu}Usage${gry}:
	${cyn}exe-cmd${gry} <cmd_line> [-quiet] [-sample_lines=4]
${blu}Example${gry}:
	`$autorunsc='C:\home\apps\SysinternalsSuite\autorunsc64.exe'
	${cyn}$($MyInvocation.MyCommand)${gry} `"`$autorunsc /accepteula -a * -c -h -s -nobanner '*'`"$rc
"@
	   return
	}
	[string[]] $cmd_arr=$cmd_line -split(" ")
	$exe=$cmd_arr[0] 
	$exe_args=$cmd_arr[1..$($cmd_arr.Count-1)]
	$fmt_var="{0,-15}"	
	if (!$quiet) {

		$tm_start=Get-Date
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1} ${grn}{2}$rc" -f "COMMAND $(if($exe_args.Count){ `"and $($exe_args.Count) args`"})", $exe, $($exe_args -join (' '))
		$exe_watch=[System.Diagnostics.Stopwatch]::New()
		$exe_watch.Start()
	}
	# [array] $Global:CMD_OUT=& $exe $exe_args|% { if ($raw) { $_ } else { $_.Trim() -replace('\p{Cc}+','')} } |? { $_ } # |? { $_ -and $_ -notmatch '\p{Cc}' }
	if($raw) {
		[array] $Global:CMD_OUT=& $exe $exe_args
	} else {
		[array] $Global:CMD_OUT=& $exe $exe_args |% { [regex]::replace($_,'[^\x20-\x7F]','').Trim() } |? { $_ } 
	}
		
    if (!$quiet) {
		$exe_watch.Stop()
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Duration', "$(out-dura $tm_start)"
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1,-5:g5}$rc" -f 'Elapsed', "$($exe_watch.Elapsed.TotalSeconds) s"
		if ($Global:CMD_OUT -is [array]) {
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Sample lines',"$sample_lines"
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $Global:CMD_OUT[$_]}
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$Global:CMD_OUT.Count	
		} else {
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f '$Global:CMD_OUT',"is a string of $($Global:CMD_OUT.Length) symbols length"
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Sample lines',"$sample_lines"
			$tmpArr=@($Global:CMD_OUT -split([environment]::NewLine))
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $($tmpArr[$_] -replace ([environment]::NewLine,'\n')) }
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$tmpArr.Count	
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Data store','$Global:CMD_OUT'
			
		}
    }
}

# $AUTORUN_OUT | select -first 1 | %{ [regex]::replace($_,'[^\x20-\x7F]','.',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline).Trim() } 

function exe-cmd( [string] $cmd_line, [switch]$quiet, [int]$sample_lines=4, [int] $maxcount, [switch] $raw , $mode='array') {

	$e=[char]27; $sc="$e[#p"; $rc="$e[#q"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="`e[1;35m"; $cyn="`e[1;36m";
    $bold="$e[1m";$bold_off="$e[22m"; 
	$fmt_var="{0,-20}"	
	[string[]] $cmd_arr=$cmd_line -split(" ")
	$exe=$cmd_arr[0] 
	$exe_args=$cmd_arr[1..$($cmd_arr.Count-1)]
	if (!$quiet) {
		$tm_start=Get-Date
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1} ${grn}{2}$rc" -f "COMMAND $(if($exe_args.Count){ `"and $($exe_args.Count) args`"})", $exe, $($exe_args -join (' '))
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'mode', $mode
		$exe_watch=[System.Diagnostics.Stopwatch]::New()
		$exe_watch.Start()
	}
	
	switch($mode) {
		'string2' {
			# https://stackoverflow.com/questions/8097354/how-do-i-capture-the-output-into-a-variable-from-an-external-process-in-powershe/35980675#35980675
			$Global:CMD_OUT=& $exe $exe_args | Out-String # Note: Adds a trailing newline.
		}
		'string' { # one string
			# https://stackoverflow.com/questions/8097354/how-do-i-capture-the-output-into-a-variable-from-an-external-process-in-powershe/35980675#35980675
			$Global:CMD_OUT=(& $exe $exe_args ) -join "$newline"
		}
		'test' {
			if($maxcount) { $cnt=$maxcount } else { $cnt=10 }
			$Global:CMD_OUT=& $exe $exe_args | select-object -first $cnt
		}
		'raw' {
			[array] $Global:CMD_OUT=& $exe $exe_args
		}
		default {
			if($raw) {
				[array] $Global:CMD_OUT=& $exe $exe_args
			} else {
				[array] $Global:CMD_OUT=& $exe $exe_args |% { [regex]::replace($_,'[^\x20-\x7F]','').Trim() } |? { $_ } 
			}							
			if ($mode -is [int]) { $maxcount=$mode }
		}
	}
    if (!$quiet) {
		
		"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1,-5:g5}$rc" -f 'Elapsed', "$($exe_watch.Elapsed.TotalSeconds) s"
		if ($Global:CMD_OUT -is [array]) {
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Sample lines',"$sample_lines"
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $Global:CMD_OUT[$_]}
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$Global:CMD_OUT.Count	
		} else {
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f '$Global:CMD_OUT',"is a string of $($Global:CMD_OUT.Length) symbols length"
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Sample lines',"$sample_lines"
			$tmpArr=@($Global:CMD_OUT -split([environment]::NewLine))
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $($tmpArr[$_] -replace ([environment]::NewLine,'\n')) }
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$tmpArr.Count	
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Data store','$Global:CMD_OUT'			
		}
		$exe_watch.Stop()
    }
	if ($maxcount) {
		$Global:CMD_OUT=$Global:CMD_OUT[0..($maxcount-1)]
	}
}

function get-services($names,[int[]]$ids) {

	''
	'[get-services] names:{0} ids:{1}' -f ($names -join ',') ,($ids -join ',')

	$filterName=@()
	$ConditionName=@()
	$filterID=@()
	$ConditionID=@()
	$filterOther=@()
	$ConditionOther=@()
	
	if ($names) { 
		foreach($name in $names) {
			switch -wildcard ($name)  {
				"error"     { $ConditionOther += @("(ExitCode != 0 or Status != 'OK')") }
				"active"    { $ConditionOther += @("(Started = 'True')") }
				"auto"      { $ConditionOther += @("(StartMode = 'auto')") }
				"manual"    { $ConditionOther += @("(StartMode = 'manual')") }
				"[1-9]*"    { $filterName += @($name); if($name -is [int] -and $name -gt 0) { $FilterID += @($name) } }
				"disabled"  { $ConditionOther += @("(StartMode = 'disabled')") }
				'(*'        { $ConditionOther += @($name) }
				'*%*'       { $ConditionOther += @("Name like $name or Caption like") }
				default     { $filterName += @($name) }
			}
		}
	}
	
# default     { $filterName += @("(Name like '%$name%' or Caption like '%$name%' or DisplayName like '%$name%')")

	if ($filterName.Count) { 
		$cnt=$filterName.Count
		"{0} name$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($filterName[0..2]) -join ','} else {($filterName) -join ','} )
		foreach ($name in $filterName) {
			$ConditionName+=@( "( Name like '%$name%' or Caption like '%$name%' or DisplayName like '%$name%' )" )
		}
	} 


	if ($ids.Count) { 
		foreach ($id in $ids) {
			if ($id) { $filterID += @($id) }
		}
	}
	
	if ($filterID.Count) { 
		$cnt=$filterName.Count
		"{0} id$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($filterID[0..2]) -join ','} else {($filterID) -join ','} )
		foreach ($id in $filterID) {
			$ConditionID+=@("ProcessID=$id")
		}
	}
	
	$Conditions=@()
	$Conditions=$ConditionName+$ConditionID+$ConditionOther
	$cnt=$Conditions.Count
	
	$filterStr='( {0} )' -f ($Conditions -join ') or (')

	"{0} filter$(if($cnt -ne 1){'s'}): {1}" -f $cnt,$filterStr
	
	$Result=Get-CimInstance Win32_Service -Filter $filterStr -ea 0 # | Sort-Object State,StartMode,DelayedAutoStart,Name 
	$global:SERVICES=$Result
	
	$cnt=$Result.Count
	if ($cnt) { 
		"{0} object$(if($cnt -ne 1){'s'}) found: {1}$(if($cnt -gt 3){' ...'})" -f $cnt, $( if($cnt -gt 3) {($Result[0..2]).Name -join ','} else {($Result).Name -join ','} )
	} else {
		'No objects matching the search condition'
	}
	
	Foreach($S in $Result ) {
<#
			Service             = '{0}{1}' -f $( if( $S.Name -notlike "* *" ){'{0} - ' -f $S.Name}),$S.Caption
			ServiceState        = $S.State
			ProcessId           = $null
			CommandLine         = $null
			StartMode           = '{0}{1}' -f $S.StartMode,$( if( $S.DelayedAutoStart -eq 'True' ) { '/Delay' } )
			ServiceOwner        = $S.StartName
			ProcessOwner        = $null
			AcceptStop          = $S.AcceptStop
			AcceptPause         = $S.AcceptPause
			PPid                = $null
			ProcessName         = 'N/A'
			VM                  = $null
			WS                  = $null
			MaxWS               = $null
			MinWS               = $null
			KernelModeTime      = $null
			Handle              = $null
			HandleCount         = $null
			ThreadCount         = $null
			SessionId           = $null
			Priority            = $null
			OtherOperCnt        = $null
			OtherTranCnt        = $null
			ReadTranCnt         = $null
			ReadOperCnt         = $null
			WriteOperCnt        = $null
			WriteTranCnt        = $null
			StartTime           = $null
			ExitTime            = $null
			ExitCode            = '{0}{1}' -f  $(if($S.ExitCode){"$($S.ExitCode)"} ), $(if($S.ServiceSpecificExitCode){"$($S.ServiceSpecificExitCode)"})

#>
		if($S.ProcessId) { $Key=$S.ProcessId } else { $Key=$S.Name }
		'Key:{0} ProcessId:{1} ' -f $Key, $S.ProcessId
		if ($global:RESULT_MAP[$Key]) {
			'updating key'
			$global:RESULT_MAP[$Key].Service=$('{0}{1}' -f $( if( $S.Name -notlike "* *" ){'{0} - ' -f $S.Name}),$S.Caption)
			$global:RESULT_MAP[$Key].ServiceState=$S.State
			$global:RESULT_MAP[$Key].StartMode=$('{0}{1}' -f $S.StartMode,$( if( $S.DelayedAutoStart -eq 'True' ) { '/Delay' } ))
			$global:RESULT_MAP[$Key].ServiceOwner=$S.StartName
			$global:RESULT_MAP[$Key].AcceptStop=$S.AcceptStop
			$global:RESULT_MAP[$Key].AcceptPause=$S.AcceptPause
			$global:RESULT_MAP[$Key].ExitCode=$('{0}{1}' -f  $(if($S.ExitCode){"$($S.ExitCode)"} ), $(if($S.ServiceSpecificExitCode){"$($S.ServiceSpecificExitCode)"}))
		} else {
			'adding key'
			$global:RESULT_MAP[$Key]=[pscustomobject]@{
			Service             = $('{0}{1}' -f $( if( $S.Name -notlike "* *" ){'{0} - ' -f $S.Name}),$S.Caption)
			ServiceState        = $S.State
			StartMode           = $('{0}{1}' -f $S.StartMode,$( if( $S.DelayedAutoStart -eq 'True' ) { '/Delay' } ))
			ServiceOwner        = $S.StartName
			AcceptStop          = $S.AcceptStop
			AcceptPause         = $S.AcceptPause
			ExitCode            = $('{0}{1}' -f  $(if($S.ExitCode){"$($S.ExitCode)"} ), $(if($S.ServiceSpecificExitCode){"$($S.ServiceSpecificExitCode)"}))
			}		
		}		
	}
}

function ps-info ( $names) {
	
	$global:RESULT_MAP=@{}
	$global:SERVICES=@()
	
	get-connection-map
	get-process-map
	get-win32process-map
	get-win32service-map
	
	if ($PSBoundParameters.Count -eq 0 ) {
		'Usage:   {0} {1}' -f 'ps-info', '<name>[,<name>]'
		'         {0} {1}' -f 'ps-info', '<id>[,<id>]'
		'         {0} {1}' -f 'ps-info', '<keyword>'
		'         {0} {1}' -f 'ps-info', '(<Win32_Service filter>)'
		'Examples:'
        '         {0}'     -f 'ps-info Intel'
		'         {0}'     -f 'ps-info error     # (ExitCode != 0 or Status != "OK")' 
		'         {0}'     -f 'ps-info active # Started = "true"'
		'         {0}'     -f 'ps-info auto      # StartMode = "auto"'
		'         {0}'     -f 'ps-info disabled  # StartMode = "disabled"'
		'         {0}'     -f 'ps-info "int%"    # Name like <name>'
		'         {0}'     -f "ps-info '(StartMode = `"manual`" and Started = `"True`" )"
		'Error:   {0}'     -f 'parameter must be specified'
		return
	}
	
	get-processes -names:$names 
	get-services -names:$names -ids:$global:RESULT_MAP.Keys	
	get-processes -ids:$(($global:RESULT_MAP.Values).ProcessID)
	
<#			
		if($S.ProcessId) {$P=Get-Process -Pid $S.ProcessId; $pno++} else {$P=@{}}
			PM                  = $P.PM
			NPM                 = $P.NPM
			Parent              = $P.Parent
			Modules             = $P.Modules
			Company             = $P.Company
			FileVersion         = $P.FileVersion
			ProcessDescription  = $P.Description
			StartTime           = $P.StartTime
			ExitTime            = $P.ExitTime
			CPU                 = $P.CPU
			TotalProcessorTime  = $P.TotalProcessorTime
	
	Foreach($S in $Services ) {
		$sno++
		if($S.ProcessId) {
			$Key=$S.ProcessId
			$pno++
			$global:RESULT_MAP[$Key].Service='{0}{1}' -f $( if( $S.Name -notlike "* *" ){'{0} - ' -f $S.Name}),$S.Caption
			$global:RESULT_MAP[$Key].ServiceState=$S.State
			$global:RESULT_MAP[$Key].StartMode='{0}{1}' -f $S.StartMode,$( if( $S.DelayedAutoStart -eq 'True' ) { '/Delay' } )
			$global:RESULT_MAP[$Key].ServiceOwner=$S.StartName
			$global:RESULT_MAP[$Key].AcceptStop=$S.AcceptStop
			$global:RESULT_MAP[$Key].AcceptPause=$S.AcceptPause
			$global:RESULT_MAP[$Key].ExitCode='{0}{1}' -f  $(if($S.ExitCode){"$($S.ExitCode)"} ), $(if($S.ServiceSpecificExitCode){"$($S.ServiceSpecificExitCode)"})
		} else {
			$Key=$S.Name
			$ResultObject=[pscustomobject]@{
				Service             = '{0}{1}' -f $( if( $S.Name -notlike "* *" ){'{0} - ' -f $S.Name}),$S.Caption
				ServiceState        = $S.State
				ProcessId           = $null
				CommandLine         = $null
				StartMode           = '{0}{1}' -f $S.StartMode,$( if( $S.DelayedAutoStart -eq 'True' ) { '/Delay' } )
				ServiceOwner        = $S.StartName
				ProcessOwner        = $null
				AcceptStop          = $S.AcceptStop
				AcceptPause         = $S.AcceptPause
				PPid                = $null
				ProcessName         = $null
				VM                  = $null
				WS                  = $null
				MaxWS               = $null
				MinWS               = $null
				KernelModeTime      = $null
				Handle              = $null
				HandleCount         = $null
				ThreadCount         = $null
				SessionId           = $null
				Priority            = $null
				OtherOperCnt        = $null
				OtherTranCnt        = $null
				ReadTranCnt         = $null
				ReadOperCnt         = $null
				WriteOperCnt        = $null
				WriteTranCnt        = $null
				StartTime           = $null
				ExitTime            = $null
				ExitCode            = '{0}{1}' -f  $(if($S.ExitCode){"$($S.ExitCode)"} ), $(if($S.ServiceSpecificExitCode){"$($S.ServiceSpecificExitCode)"})
			}
			$global:RESULT_MAP[$Key]=$ResultObject
        }
		
		switch($cSrv - $sno) {
			0 { continue }
			$($cSrv-1) { 'Service {0} of {1}: {2}' -f $sno,$cSrv,$S.Name; get-ResultObject $ResultObject } 
		}

	}			
#>

	# if ($sno) { $S=$global:RESULT[$global:RESULT.Count-1]; 'Service {0} of {1}: {2}' -f $sno,$cSrv,$S.Name; get-Serviceinfo $S  }
	$global:RESULT_MAP.Values | Format-Table -auto Service,StartTime,ProcessId,Process,ServiceState,StartMode,ServiceOwner,ProcessOwner,PPid,
		VM,WS,KernelModeTime,ExitCode,ExitTime,
		@{n='CommandLine';w=120;e={$_.CommandLine -replace '(?<=.{120}).+' }}
	''
}

###############################################
# CodeExecutor
function CodeExecutor([string] $Command='ps-info',[switch] $Measure) {
	#   [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
	#	write-output '[CodeExecutor] -- start ----------------------'
	# 	write-output "command: $command; args[$(($args).length)] : $($args -join ' ')"    
	#	Invoke-Command -ScriptBlock { & $command @args} -ArgumentList $args
		# Invoke the script block with `&`
		# write-output '[CodeExecutor] -- end ----------------------'
	
	#   'args[2]:{0} | args[3]:{1}' -f (($args[2]) -join(',')),(($args[3]) -join(','))
		pargs
		# "[{0}] {1} arg{2} {3}" -f $MyInvocation.MyCommand, $PSBoundParameters.Count,$(if($PSBoundParameters.Count -ne 1) {"s"}),(($PSBoundParameters.Keys|%{ "-{0}:{1}" -f $_,($PSBoundParameters[$_] -join(","))} ) -join(" "))
		if ($command) {
			if ($Measure) {
				Measure-Command -Expression { & $command @args  | Out-Default }
			} else {
				& $command @args
			}	
		}
	}
	

$stopwatch.Restart()

"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f 'Main',$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks

CodeExecutor @args

"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Elapsed: $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f 'Main',$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks

$stopwatch.Stop()

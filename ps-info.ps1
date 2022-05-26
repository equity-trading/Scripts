using namespace System.Management.Automation
# Get-Process WDDriveService,Sysmon,Sysmon,ServiceShell

if (!$Global:Users) { $Global:Users=Get-LocalUser }

$e=[char]27; $nl=[char]10; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; $red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"; $strk = "$e[9m"; $nrml="$e[29m"
$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 
$bold="$e[1m";$bold_off="$e[22m";
$fmt_var="{0,-15}"

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

function fnc-start() {
	
	if (!$global:myscript) { $global:myscript=Split-Path $MyInvocation.ScriptName -leaf }
	if (!$global:mywatch) { $global:mywatch=[System.Diagnostics.Stopwatch]::New() }
    

	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks."+
	"Called from ${ylw}line${blu}:$cyn{5}$gry at $ylw{6}$gry "+
	"| $ylw{7}$blu[$ylw{8}$blu]${gry}: $ylw{9}$gry. $rc" -f $MyInvocation.MyCommand, $global:myscript, $MyInvocation.ScriptLineNumber,
		$global:mywatch.Elapsed.milliseconds, $global:mywatch.Elapsed.ticks,$MyInvocation.ScriptLineNumber, $start_tm, 
		'$PsBoundParameters', $(@($PsBoundParameters.Keys).Count), 
		$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '})
}

function fnc-stop() {
	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks. Called from ${ylw}line${blu}:$cyn{5}$gry at $ylw{6}$gry | $ylw{7}$blu[$ylw{8}$blu]${gry}: $ylw{9}$gry. $rc" -f $MyInvocation.MyCommand, $myscript, $(&{$MyInvocation.ScriptLineNumber}),
	$script:watch.Elapsed.milliseconds, $script:watch.Elapsed.ticks,$MyInvocation.ScriptLineNumber, $start_tm, 
	'$PsBoundParameters',$(@($PsBoundParameters.Keys).Count),$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '})
}

function fnc-test($arg1,$arg2='2',$arg3) {
	fnc-start
	$test_var="test"
	'args' -f $( $args | ConvertTo-Json )
	
	'$PsBoundParameters: {0}' -f $( $PsBoundParameters | ConvertTo-Json )
	fnc-stop
}


function exe-cmd( $cmd, [switch]$quiet, [int]$sample_lines=4, [int] $maxcount, $mode='array') {

	if(!$quiet) {
	}
	$newline=[environment]::NewLine
	$nl='\n'
	$exe_watch=[System.Diagnostics.Stopwatch]::New()
	[string[]] $cmd_arr=$cmd -split(" ")
	$exe=$cmd_arr[0] 
	$exe_args=$cmd_arr[1..$($cmd_arr.Count-1)]
	if (!$exe_watch.IsRunning) { $exe_watch.Reset()}
	$exe_watch.Start()
	switch($mode) {
		'string2' {
			# https://stackoverflow.com/questions/8097354/how-do-i-capture-the-output-into-a-variable-from-an-external-process-in-powershe/35980675#35980675
			$Global:CMD_OUT=& $exe $exe_args | Out-String # Note: Adds a trailing newline.
		}
		'string' {
			# https://stackoverflow.com/questions/8097354/how-do-i-capture-the-output-into-a-variable-from-an-external-process-in-powershe/35980675#35980675
			$Global:CMD_OUT=(& $exe $exe_args ) -join "$newline"
		}
		'test' {
			if($maxcount) { $cnt=$maxcount } else { $cnt=10 }
			$Global:CMD_OUT=& $exe $exe_args | select-object -first $cnt
		}
		'arr' {
			[array] $Global:CMD_OUT=& $exe $exe_args
		}
		default {
			if ($mode -is [int]) {
				$Global:CMD_OUT=& $exe $exe_args | select-object -first $cnt
			} else {
				[array] $Global:CMD_OUT=& $exe $exe_args
			}
		}
	}
	$exe_watch.Stop()
	if ($maxcount) {
		$Global:CMD_OUT=$Global:CMD_OUT[0..($maxcount-1)]
	}
    if (!$quiet) {
        "$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f 'COMMAND', $cmd
		"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f 'mode', $mode
		"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f 'Elapsed', "$($exe_watch.Elapsed.ticks) ticks"
		"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f 'Elapsed', "$($exe_watch.Elapsed.milliseconds) ms"
		if ($Global:CMD_OUT -is [array]) {
			"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f '$Global:CMD_OUT',"first $sample_lines lines"
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $Global:CMD_OUT[$_]}
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$Global:CMD_OUT.Count	
		} else {
			"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f '$Global:CMD_OUT',"is a string of $($Global:CMD_OUT.Length) symbols"
			"$sc${bold}${blu}${fmt_var}${bold_off}  : ${ylw}{1}$rc" -f 'Splitting',"first $sample_lines lines"
			$tmpArr=@($Global:CMD_OUT -split("$newline"))
			0..$($sample_lines - 1) |% {"$sc${grn}{0,-5} ${blu}<${ylw}{1}${blu}>$rc" -f $($_+1), $($tmpArr[$_] -replace ("$newline","$nl")) }
			"$sc${bold}${blu}${fmt_var}${bold_off} : ${ylw}{1}$rc" -f 'Total lines',$tmpArr.Count	
		}
    }
}

function get-Services($cmds=@("SC")) {
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
				##################################
				 # -replace('(\w+)=([0-9]\w*)  (.+)','$1=$2; $1_INFO="$3"') -replace('(\w+)=([0-9]\w*).*','$1=$2') 
				$Global:SC_SERVICES=$(
				##################################
				$tArr=@(); $Idx=0; $TestCnt=100000
				$Global:SC_LINES=((sc.exe query | select -first $TestCnt | Out-String -stream ).Trim() |? {$_} )
				$Global:SC_LINES -replace('([\w:]+)\W*:\W*','$1=') -replace('^(\w+)=(.*)','$1="$2"') | 
				select -first $TestCnt | % {
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
				exe-cmd "sc.exe query"
				$Global:SC_SERVICES=$(
					##################################
					$Global:SC_LINES=$Global:CMD_OUT | Out-String -stream ).Trim() |? {$_};
					# ConvertFrom-StringData $($SC_LINES[0..8] -replace ':','=' -replace '^\(','EXTRA_ATTR=(' -join("`n"))
					$Idx=0; $prevIdx=0
					$Global:SC_LINES -replace('([\w:]+)\W*:\W*','$1=') -replace('^(\w+)=(.*)','$1="$2"') | 
					for (($Idx=0), ($prevIdx=0); $Idx -lt $Global:SC_LINES.Count; $Idx++) {
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

ps-info @args



<#
PS C:\Users\alexe> ([wmisearcher]'select * from meta_class').Get() | ? Name -like '*Connect*' |? Name -notlike 'Win32_Perf*' | select * | ft -auto Name,@{n='Props';e={$_.__PROPERTY_COUNT}} -groupby @{n='Dynasty';e={$_.__DYNASTY}}

   Dynasty: __SystemClass

Name                                 Props
----                                 -----
MSFT_NCProvClientConnected               6
MSFT_NetConnectionTimeout                4
MSFT_NetServiceDifferentPIDConnected     5

   Dynasty: CIM_ManagedSystemElement

Name                    Props
----                    -----
CIM_PhysicalConnector      17
Win32_PortConnector        20
Win32_NetworkConnection    17
Win32_ServerConnection     12

   Dynasty: CIM_Component

Name                           Props
----                           -----
Win32_SystemNetworkConnections     2
CIM_LinkHasConnector               2
CIM_ConnectorOnPackage             3

   Dynasty: CIM_Dependency

Name                    Props
----                    -----
Win32_SessionConnection     2
CIM_ConnectedTo             2
Win32_ConnectionShare       2
CIM_DeviceConnection        4

   Dynasty: Win32_OfflineFilesConnectionInfo

Name                             Props
----                             -----


([wmisearcher]$wmidata="select * from Win32_PortConnector").Get() | select -expand properties | ? Value -notlike '' | select * | 
ft @{Name = "Name"; Expression={if ($_.Name -eq 'Name') { "$([char]0x1b)[1;91m$($_.Name)$([char]0x1b)[0m"} else {$_.Name} }},
   @{Name = "Value"; Expression={if ($_.Name -eq 'Name') { "$([char]0x1b)[1;91m{0}$([char]0x1b)[0m" -f $_.Value } else {$_.Value} }},
   @{Name = "Type"; Expression={if ($_.Name -eq 'Name') { "$([char]0x1b)[1;92m"+ $_.Type +"$([char]0x1b)[0m" } else {$_.Type} }},
   @{Name = "Qualifiers"; Expression={if (($_.Qualifiers).Name.Contains('key')) { "$([char]0x1b)[1;93m"+($_.Qualifiers).Name+"$([char]0x1b)[0m"} else { ($_.Qualifiers).Name } }}


([wmisearcher]$wmidata="select * from Win32_PortConnector").Get() | select -first 1 -expand properties | ? Value -notlike '' | select * | 
ft @{Name = "Name";  Expression={ ("$([char]0x1b)[{0}m{1}" -f $(if($_.Name -eq 'Name'){"1"}else{"0"}),$_.Name) } },
   Value,Type,
   @{Name = "Qual";  Expression={ '$([char]0x1b)[{0}m{1}' -f $(if($_.Name -eq 'Name'){"1"}else{"0"}),$(($_.Qualifiers).Name) } }

#>
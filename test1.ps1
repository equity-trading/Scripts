
function Get-Args([System.Management.Automation.InvocationInfo] $Invocation) {
	# (Get-PSCallStack | gm Arguments).Definition 
	foreach ($entry in $Invocation.BoundParameters.GetEnumerator()) {
		$argumentsBuilder+=@("-"+[string]$entry.Key)
		if ($entry.Value) { $argumentsBuilder+=@($entry.Value -join(',')) }
	}

	foreach ($arg in $Invocation.UnboundArguments.GetEnumerator()) {
		if ($arg) {$argumentsBuilder+=@([string] $arg)} else {$argumentsBuilder+=@($null)}

	}
	$FuncArgs=$argumentsBuilder -join (' ')
}

function DbgInfo-Func() {
	$stack=Get-PSCallStack
	# $stack | ft *
	# (Get-PSCallStack | gm Arguments).Definition 
	[string] $FuncLoc=$stack[1].Location -replace ' line ',''
	[string] $FuncPos=$stack[1].Position
	[string] $FuncName=$stack[1].Command+'('+ $($stack[1].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 
		
	[string] $CallerLoc=$stack[2].Location -replace ' line ',''
	[string] $CallerPos=$stack[2].Position
	[string] $CallerName=$stack[2].Command+'('+ $($stack[2].Arguments -replace '{(.*)}','$1' -replace '(?<=.{50}).+','..' ) + ')' ; # 

	if ($args.Length) {
		'[{0}] {2}' -f $FuncLoc, $FuncName, $( $args -join(' '))
	} else {
		# '[{0} {1}] Called in {2} at {3} as {4}' -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos
		'[{0}] At {5} {1} called at {3} as {4}' -f $FuncLoc, $FuncName, $CallerName, $CallerLoc, $CallerPos,$(Get-Date)
	}
}

Remove-Alias pargs -ErrorAction "SilentlyContinue"
New-Alias -Name pargs -Value 'DbgInfo-Func'


# Error: Log count (463) is exceeded Windows Event Log API limit (256). Adjust filter to return less log names.
# Examples:  
#            test1.ps1                                 # last 50000 error events, see output in C:\home\data\Reports\Get-Events-2022-05-18.txt
#            test1.ps1 -Days 10 -Warning -Groups 1,2,3 # 10 days of error and warnings, see output in C:\home\data\Reports\Get-Events-2022-05-18-warnings.txt
#            test1.ps1 -Hour 1 -Warning -ExcludeLogName PSCore,LiveId # exclude logs PSCore and LiveId from the table of groups
#            test1.ps1 -Hour 5 -Warning -ExcludeLogName PSCore,LiveId -FilterMsg '*sqlite3_exec*'
#            test1.ps1 -Hour 24 -Warning -FilterMsg '*sqlite3_exec*'
#  search in $GROUPED_EVENTS  by last pid
#  $GROUPED_EVENTS | ? LstPid -eq 13240 | ft *             
#  $GROUPED_EVENTS[2,6].Group |? ProcessId -eq 13240 | select -first 40 | ft  MsgNo,TimeCreated,Lvl,Id,LogName,ProviderName,ProcessId,Message2
#            test1.ps1 -Groups 1          # 
#            test1.ps1 -NoTable -Group 1  # last 10 error events and xml sampler
#            test1.ps1 -warn          # last 20 errors and warnings
#            test1.ps1 500            # last 500 error events
#            test1.ps1 500 -warn      # last 500 error events
#            test1.ps1 2000 -warn -UseCache -Group 1
#            test1.ps1 -warn -MaxEvents 10000 -Groups 1,2
#            test1.ps1 -UseCache -Groups 1,2
#            Get-Events  -RecIds 14393 -EventIDs 613
#            Get-XmlEvent 0,1,2,3 -Hours 12 -ExceptEventIDs 5379,4798,4799,4100 -ExceptProvider PowerShellCore,Microsoft-Windows-Security-Auditing
#            Get-XmlEvent -Hours 12
#            Get-XmlEvent -Hours 12 -Providers  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch,Microsoft-Windows-Security-Auditing


function Get-XmlEvent {
    Param( [string[]] $LogName, [string[]] $ProviderName, [int[]]$Levels, [int[]]$EventIDs, [int[]] $RecIds, [int[]]$ExceptEventIDs, [string[]]$ExceptProviders,
	[int]$MaxEvents=2000, [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ShowEvents=3, [int]$PrintLines=20 )
	pargs
	$Conditions=@()
	$Global:FILTERXPATH=""	
	if ( ! $PSBoundParameters.Count ) {
		''
		'{0} {1} {2}' -f  $MyInvocation.MyCommand.CommandType, $MyInvocation.MyCommand, $MyInvocation.MyCommand.ParameterSets[0].ToString()
		'{0}' -f "Examples:"
		'    {0} {1}' -f $MyInvocation.MyCommand, "38603,38604,38605  3,4"
		''
		return 
	}

	$Conditions=@()

	if ($RecIds) { $tArr=@('EventRecordID='); $tArr+=@($RecIds -join ' or EventRecordID='); $Conditions+=@("System["+ $($tArr -join '') +"]") } 

	if ($Levels) { $tArr=@('Level='); $tArr+=@($Levels -join ' or Level='); $Conditions+=@("System["+ $($tArr -join '') +"]") }

	if ($EventIDs) { $tArr=@('EventID='); $tArr+=@($EventIDs -join ' or EventID='); $Conditions+=@("System["+ $($tArr -join '') +"]") }
	
	if ($ExceptEventIDs) { $tArr=@('EventID!='); $tArr+=@($ExceptEventIDs -join ' and EventID!='); $Conditions+=@("System["+ $($tArr -join '') +"]") }

	$ms=$ms+$Hours*3600*1000+$Minutes*60*1000+$Seconds*1000
	if ($ms) { $Conditions+=@("System/TimeCreated[timediff(@SystemTime)&lt;=$ms]") }

	if ($ProviderName) { $tArr=@('System/Provider[@Name="'); $tArr+=@($ProviderName -join '"] or System/Provider[@Name="'); $Conditions+=@( ($tArr -join '')+'"]') }
	
	if ($ExceptProviders) { $tArr=@('System/Provider[@Name!="'); $tArr+=@($ExceptProviders -join '"] and System/Provider[@Name!="'); $Conditions+=@( ($tArr -join '') + '"]') }

	$Global:FILTERXPATH=""
	#  $Global:FILTERXPATH="*[System/Provider[@Name='Microsoft-Windows-Kernel-General'] and System[(EventID=12)]]"
	$NoConditions=$Conditions.Count
	# $Global:FILTERXPATH="("+$($Conditions -join ') and (')+")"
	# $Global:FILTERXPATH="*[System[ $Global:FILTERXPATH ]]"
	
	if ($NoConditions) { $Global:FILTERXPATH="*["+$($Conditions -join ' and ')+"]" }
	# ""
	# "`$Global:FILTERXPATH contains $NoConditions condition$(if($NoConditions -ne 1){'s'}): $Global:FILTERXPATH" 
	$lCnt=$LogName.Count
	"Getting WinEvents into `$Global:LOGS, -LogName[$lCnt]:$($LogName[0..3] -join ",")$(if($lCnt -gt 3){' ...'})"
	$global:LOGS=@()
	if ($LogName -eq '*') {
		$global:LOGS=@((get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddHours(-25))}).LogName)
	} else {
		$global:LOGS=@((get-winevent -listlog $LogName -ea 0).LogName)
	}
	$lCnt=$global:LOGS.Count
	
	# "$lCnt log$(if($lCnt -ne 1){'s'}):$($global:LOGS[0..3] -join ",")$(if($lCnt -gt 3){' ...'})"
	# "Getting WinEvents into `$Global:EVENTS, MaxEvents:$MaxEvents ..."
    $Global:EVENTS=Get-WinEvent -LogName $global:LOGS -FilterXPath $Global:FILTERXPATH -MaxEvents $MaxEvents -ea 0 		
}

	
###############################################
# CodeExecutor
function CodeExecutor([string] $Command="Get-Events",[switch] $Measure) {
#   [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
#	write-output '[CodeExecutor] -- start ----------------------'
# 	write-output "command: $command; args[$(($args).length)] : $($args -join ' ')"    
#	Invoke-Command -ScriptBlock { & $command @args} -ArgumentList $args
    # Invoke the script block with `&`
	# write-output '[CodeExecutor] -- end ----------------------'

#   'args[2]:{0} | args[3]:{1}' -f (($args[2]) -join(',')),(($args[3]) -join(','))
	pargs
    # '[{0}] {1} arg{2} {3}' -f $MyInvocation.MyCommand, $PSBoundParameters.Count,$(if($PSBoundParameters.Count -ne 1) {'s'}),(($PSBoundParameters.Keys|%{ '-{0}:{1}' -f $_,($PSBoundParameters[$_] -join(','))} ) -join(' '))
    # "[{0}] {1} arg{2} {3}" -f $MyInvocation.MyCommand, $PSBoundParameters.Count,$(if($PSBoundParameters.Count -ne 1) {"s"}),(($PSBoundParameters.Keys|%{ "-{0}:{1}" -f $_,($PSBoundParameters[$_] -join(","))} ) -join(" "))

    if ($Measure) {
		Measure-Command -Expression { & $command @args  | Out-Default }
	} else {
		& $command @args
	}
}

###############################################
# Get-EventLogs
function Get-EventLogs () {
	param([string[]] $LogName='*',[int] $Seconds=$(24*3600))
    $Global:EVENT_LOGS=get-winevent -listlog $LogName -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddSeconds(-$Seconds))}
	return 
}


##########################################
# Format-ListGroupMessages
function Format-ListGroupMessages ([int] $Group=1, [int[]] $Messages=1,[switch] $UseCache) {
    # '[{0}] {1} arg{2} {3}' -f $MyInvocation.MyCommand, $PSBoundParameters.Count,$(if($PSBoundParameters.Count -ne 1) {'s'}),(($PSBoundParameters.Keys|%{ '-{0}:{1}' -f $_,($PSBoundParameters[$_] -join(','))} ) -join(' '))
	pargs
	if (!$Group) {
		'[{0}] Error: $Group parameter is missing' -f $MyInvocation.MyCommand
		return
	}
	
	if (!$TotMessages) {
		'[{0}] Error: $Messages parameter is missing, $Group is {1}' -f $MyInvocation.MyCommand, $Group
		return
	}

	$TotGroupedEvents=$Global:GROUPED_EVENTS.Length
	$TotEvents=$Global:EVENTS.Length
	$TotMessages=$Messages.Length

	if ($Group -gt $TotGroupedEvents) {
		pargs $('Error: Group Number {0} must not exceed total number of groups {1}' -f $Group, $TotGroupedEvents)
		return
	}
	$GrpIdx=$($Group-1)
	$TotGrpMsg=$($Global:GROUPED_EVENTS[$GrpIdx].Group).Length
	
	# '[{0}] Group No {1}. Printing {2} out of {3} message{4}: {5}' -f $MyInvocation.MyCommand, $Group, $TotMessages, $TotGrpMsg, $(if($TotGrpMsg -gt 1) {'s'}), $($Messages -join (','))
	
	$MessageNo=0
	foreach($MsgNo in $Messages) {
		$MessageNo++
		if ($MsgNo -gt $TotGrpMsg) {
			pargs $('Warning: Group message {0} does not exists, it must not exceed total group''s message number{1}' -f $MsgNo, $TotGrpMsg)
			continue
		}

		$MsgNo=$Global:GROUPED_EVENTS[$GrpIdx].Group[$($MsgNo-1)].MsgNo;

		pargs $('{0} of {1} message{2} - $Global:EVENTS[{3}]' -f $MessageNo, $TotMessages, $(if($TotMessages -gt 1) {'s'}), $MsgNo )
		
		Format-ListWinEvent $MsgNo
	}
	
}

##########################################Format-ListGroups
# Format-ListGroups
function Format-ListGroups ([int[]] $Groups=1, [int[]] $Messages=1,[switch] $NoTable) {
	pargs
	$TotGroupedEvents=$Global:GROUPED_EVENTS.Length
	$TotEvents=$Global:EVENTS.Length
	$TotGroups=$Groups.Length
	$TotMessages=$Messages.Length
	# '[{0}] Printing {1} of {2} group{3}: {4}' -f $MyInvocation.MyCommand, $TotGroups, $TotGroupedEvents, $(if($TotGroupedEvents -gt 1) {'s'}), $($Groups -join (','))
	$No=0
	foreach($Group in $Groups) {
		$No++
		pargs $('[{0}/{1}] Printing {2} message{3} of {4} group' -f $No, $TotGroups, $($Messages -join (',')), $(if($TotMessages -gt 1) {'s'}), $Group )
		if ($Group -gt $TotGroupedEvents) {
			pargs $('Warning: Group {0} does not exists, group number {0} must not exceed total number of groups {1}' -f $Group,$TotGroupedEvents)
			continue
		}
		if ($NoTable) { Format-TableGroupedEvents -Skip $Group }
		Format-ListGroupMessages -Group $Group -Messages $Messages
	}
}

##########################################
# Format-ListWinEvent
function Format-ListWinEvent ( [int[]] $MsgNo) {
    pargs
	$pad=1
	foreach ($No in $MsgNo) {
		$E=$Global:EVENTS[$($No-1)]
		$E.ToXml() -replace("><",">`n<") -split("`n")|% { 
			$str=$_
			if($str -match "^</.*>") {$pad-=2}
			"{0,$pad}{1}" -f "","$str"
			if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>|^[^<]")) {$pad+=2} 
		}
	}
}

<#
	$script:idx=$Start
	Format-Table -auto @{n='Grp';e={($script:idx++)}},
		@{n='MsgNo';w=180;e={$_.Group[0].MsgNo}},
		@{n='Cnt';w=5;e={$_.Count}}, 
		@{n='LogName';w=20;e={$_.Group[0].Log}},
		@{n='Lvl';w=5;e={$_.Group[0].Lvl}},
		@{n='Id';w=8;e={$_.Values[1]}},
		@{n='Days';w=4;e={($_.Group.TimeCreated | Group-Object Day).Length}},
		@{n='FstTime';w=20;e={$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},
		@{n='LstTime';w=20;e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
		# @{n='Msg';w=80;e={$_.Msg}},
		@{n='Prvds';w=5;e={($_.Group.ProviderName | Group-Object ).Length}},
		# @{n='Providers';w=80;e={($_.Group | Group-Object ProviderName | Measure-Object Count -Sum | select *,@{n='P';e={'{0}({1})' -f $_.Name,$_.Count}} ).P}},
		@{n='FstRecId';w=10;e={$_.Group[$_.Count-1].RecordId}},
		@{n='LstRecId';w=10;e={$_.Group[0].RecordId}},
		@{n='LstPid';w=10;e={$_.Group[0].ProcessId}},
		@{n='LstMsg';w=180;e={$_.Group[0].Message2}}
		# , @{n='LastProcess';e={(Get-Process -ID $_.LstPid).Path}}
# for ($script:idx = $Start; $script:idx -le ($First - 1); $script:idx += 1) { }

#>
##########################################
# Format-TableGroupedEvents
function Format-TableGroupedEvents ([int]$First=1, [int]$Skip=1) {
	pargs
	if ($Global:GROUPED_EVENTS.Length -le 0)  { 
		pargs 'Warning: $Global:GROUPED_EVENTS array is empty'
		return 
	}
	if ( $Skip -le $Global:GROUPED_EVENTS.Length ) {
		pargs $('Printing {0} of {1} groups starting from {2}' -f $First, $Global:GROUPED_EVENTS.Length,$Skip)
		$Skip--
		$Global:GROUPED_EVENTS | Select-Object -Skip $Skip -First $First -ExcludeProperty Providers,Group,Values,Msg | ft -auto *

	} else {
		pargs $('Error: Group Number {0} must be smaller than total amount of groups {1}' -f $Skip, $Global:GROUPED_EVENTS.Length)
	}		
}
	
###############################################
# Group-WinEventsByMsg
function Group-WinEventsByMsg ([int]$FirstTop=100, [string[]]$GroupCols=@("LogName","Lvl","Id","Msg") ) {
   pargs
	# 'Grouping {0} events into $Global:GROUPED_EVENTS ...' -f $Global:EVENTS.Length
	$script:Grp=1
	$script:MsgNo=1
	$TotEvents=$Global:EVENTS.Length
# 	$Params = @{  Property = $GroupCols }
	pargs $('output:{0}, {1} event{2}, $FirstTop:{3}, $GroupCols[{4}]: {5}' -f '$Global:GROUPED_EVENTS', $TotEvents, $(if($TotEvents -ne 1) {'s'}), $FirstTop, $GroupCols.Length, $($GroupCols -join(',')) )
	$Global:GROUPED_EVENTS=$Global:EVENTS | 
		Select-Object *, @{n='MsgNo';e={($script:MsgNo++)}},
		    @{n='Log';e={$_.LogName -replace '/.*$','' -replace '(Microsoft-Windows-|Microsoft-Client-|-Admin)','' -replace "PowerShell","PS" }},
			@{n='Lvl';e={'{0}({1})' -f $(Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}),$_.Level } },
			@{n='Msg';     e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace '^This is the first instance.*period','' `
			        -replace "`n+",'\n' -replace  "`r+",'\r' -replace '\s+',' '`
			        -replace '^(Creating Scriptblock text \([^)]+\)|Error Message = |Failed to update Help for the module|A long running thread for device start|Capturing identity for |Error 0x[^:]+: [^:]+:).*','$1' `
			        -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' `
					-replace ' [^ ]+([-\\\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' `
					-replace '(?<=.{120}).+' }},
			@{n='LogType';e={$(
			        $(switch -wildcard ($_.LogName){ 'Microsoft-Windows-*' {'MS-Win'}; 'Microsoft-Client-*' {'MS-Client'}; 'PowerShell*' {'PS'};}),
					$(if($_.LogName -like '*-Admin'){'Admin'}),
			        $(if($_.LogName -like '*/*'){$_.LogName -replace '^.*/','' -replace 'Operational','Oper'}) -ne ''  ) -join(',')}},
			@{n='Provirder';e={$_.ProviderName -replace $($_.LogName `
			    -replace '/.*$','' `
			    -replace 'Known Folders.*','KnownFolders' `
				-replace 'PushNotification','PushNotifications' `
				-replace 'AppXDeploymentServer','AppXDeployment-Server' `
				-replace 'Storage-Storport','StorPort' `
				-replace '(-Events|-Admin)','' `
				),"*" -replace '(Microsoft-Windows-|Windows-)',''}},
			@{n='Message2';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace "^This is the first instance.*$",'' -replace "[`n`r]+",' ' -replace '\s+',' ' -replace '(?<=.{380}).+' }} |
		Group-Object $GroupCols        | 
#		Sort-Object -stable -descending Count  |
        Sort-Object -descending Count,@{e={$(-$_.Group[0].MsgNo)}}  | 
		Select      -First $FirstTop `
		            @{n='Grp'      ;e={($script:Grp++)}},
            		@{n='MsgNo'    ;e={$_.Group[0].MsgNo}},
					@{n='Cnt'      ;e={$_.Count}}, 
					@{n='Days'     ;e={($_.Group.TimeCreated | Group-Object Day).Length}},
					@{n='LogName'  ;e={$_.Values[0]}},
					@{n='LogType'  ;e={$_.Values[1]}},
					@{n='Lvl'      ;e={$_.Values[2]}},
					@{n='Id'       ;e={$_.Values[3]}},
					@{n='Prvd'     ;e={$_.Values[4]}},
					@{n='FstTime'  ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}}},
					@{n='LstTime'  ;e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
					@{n='FstRecId' ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].RecordId}}},
					@{n='LstRecId' ;e={$_.Group[0].RecordId}},
					@{n='LstPid'   ;e={$_.Group[0].ProcessId}},
					@{n='LstMsg'   ;e={$_.Group[0].Message2}},
                    Group
		
	if ($Global:GROUPED_EVENTS.Length) {  
		pargs $('{0} events has been mapped into {1} group{2} of $Global:GROUPED_EVENTS' -f $Global:EVENTS.Length, $Global:GROUPED_EVENTS.Length,$(if($Global:GROUPED_EVENTS.Length -ne 1) {'s'}))
	} else {
		pargs $('Error: {0} events are not mapped into any groups' -f $Global:EVENTS.Length)
	}
	

    pargs
	# 'Grouping {0} events into $Global:GROUPED_EVENTS ...' -f $Global:EVENTS.Length
	$script:Grp=1
	$script:MsgNo=1
	$Global:GROUPED_EVENTS=$Global:EVENTS | 
		Select-Object *, 
		    @{n='MsgNo';e={($script:MsgNo++)}},
			@{n='Log';e={$_.LogName -replace "Microsoft-Windows-","" -replace "Microsoft-Client-","" -replace '/Operational','/Op' }},
			@{n='Lvl';e={Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}}},
			@{n='Message2';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace '^This is the first instance.*period','' `
			         -replace "`n+",'\n' -replace "`r+",'\r' -replace '\s+',' ' -replace '(?<=.{320}).+' }},
			@{n='Msg';     e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace '^This is the first instance.*period','' `
			        -replace "`n+",'\n' -replace  "`r+",'\r' -replace '\s+',' '`
			        -replace '^(Creating Scriptblock text \([^)]+\)|Error Message = |Failed to update Help for the module|A long running thread for device start|Capturing identity for |Error 0x[^:]+: [^:]+:).*','$1' `
			        -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' `
					-replace ' [^ ]+([-\\\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' `
					-replace '(?<=.{120}).+' }}                          |
		Group-Object LogName,Lvl,Id,Msg                                  | 
		Sort-Object -descending Count  |
		Select      @{n='Grp'   ;e={($script:Grp++)}},
            		@{n='MsgNo'   ;e={$_.Group[0].MsgNo}},
					@{n='Cnt'      ;e={$_.Count}}, 
					@{n='LogName'  ;e={$_.Values[0]}},
					@{n='Lvl'      ;e={$_.Values[1]}},
					@{n='Id'       ;e={$_.Values[2]}},
					@{n='Days'     ;e={($_.Group.TimeCreated | Group-Object Day).Length}},
					@{n='FstTime'  ;e={$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},
					@{n='LstTime'  ;e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
					@{n='FstRecId' ;e={$_.Group[$_.Count-1].RecordId}},
					@{n='LstRecId' ;e={$_.Group[0].RecordId}},
					@{n='LstPid'   ;e={$_.Group[0].ProcessId}},
					@{n='LstMsg'   ;e={$_.Group[0].Message2}},
					@{n='Prvd'     ;e={($_.Group.ProviderName | Group-Object ).Length}},
					@{n='Providers';e={($_.Group.ProviderName | Group-Object ProviderName|Group-Object | select @{n='PrvdCnt';e={'{0}({1})' -f $_.Name,$_.Count}}).PrvdCnt -join(',')}},
					@{n='Msg'      ;e={$_.Values[3]}},
                    Values,Group
		
	if ($Global:GROUPED_EVENTS.Length) {  
		pargs $('{0} events has been grouped into {1} groups' -f $Global:EVENTS.Length, $Global:GROUPED_EVENTS.Length)
	} else {
		pargs $('zerro groups matching given params')
	}
	return
}

###############################################
# Group-WinEvents
function Group-WinEvents ([int]$FirstTop=100, [string[]]$GroupCols=@("Log","LogType","Lvl","Id","Provirder"),[string[]] $ExcludeLogName, [string] $FilterMsg ) {
    pargs
	# 'Grouping {0} events into $Global:GROUPED_EVENTS ...' -f $Global:EVENTS.Length
	$script:Grp=1
	$script:MsgNo=1
	$TotEvents=$Global:EVENTS.Length
# 	$Params = @{  Property = $GroupCols }
	pargs $('output:{0}, {1} event{2}, $FirstTop:{3}, $GroupCols[{4}]: {5}' -f '$Global:GROUPED_EVENTS', $TotEvents, $(if($TotEvents -ne 1) {'s'}), $FirstTop, $GroupCols.Length, $($GroupCols -join(',')) )
	$FilterArr=@()
	if ($ExcludeLogName) { $FilterArr+=@('$ExcludeLogName -notcontains $_.Log') }
	if ($FilterMsg)      { $FilterArr+=@('$_.Message -like $FilterMsg') }
	if ($FilterArr.Length) { 
		$FilterStr='( {0} )' -f $($FilterArr -join (') -and ('))
	} else {
		$FilterStr='$_.MsgNo -gt 0'
	}
	$FilterBlock=[scriptblock]::Create( $FilterStr )
	$Global:GROUPED_EVENTS=$Global:EVENTS | 
		Select-Object *, @{n='MsgNo';e={($script:MsgNo++)}},
		    @{n='Log';e={$_.LogName -replace '/.*$','' -replace '(Microsoft-Windows-|Microsoft-Client-|-Admin)','' -replace "PowerShell","PS" }},
			@{n='Lvl';e={'{0}({1})' -f $(Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}),$_.Level } },
			@{n='LogType';e={$(
			        $(switch -wildcard ($_.LogName){ 'Microsoft-Windows-*' {'MS-Win'}; 'Microsoft-Client-*' {'MS-Client'}; 'PowerShell*' {'PS'};}),
					$(if($_.LogName -like '*-Admin'){'Admin'}),
			        $(if($_.LogName -like '*/*'){$_.LogName -replace '^.*/','' -replace 'Operational','Oper'}) -ne ''  ) -join(',')}},
			@{n='Provirder';e={$_.ProviderName -replace $($_.LogName `
			    -replace '/.*$','' `
			    -replace 'Known Folders.*','KnownFolders' `
				-replace 'PushNotification','PushNotifications' `
				-replace 'AppXDeploymentServer','AppXDeployment-Server' `
				-replace 'Storage-Storport','StorPort' `
				-replace '(-Events|-Admin)','' `
				),"*" -replace '(Microsoft-Windows-|Windows-)',''}},
			@{n='Message2';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace "^This is the first instance.*$",'' -replace "[`n`r]+",' ' -replace '\s+',' ' -replace '(?<=.{380}).+' }} |
			Where-Object $FilterBlock |
		Group-Object $GroupCols        | 
#		Sort-Object -stable -descending Count  |
        Sort-Object -descending Count,@{e={$(-$_.Group[0].MsgNo)}}  | 
		Select      -First $FirstTop `
		            @{n='Grp'      ;e={($script:Grp++)}},
            		@{n='MsgNo'   ;e={$_.Group[0].MsgNo}},
					@{n='Cnt'      ;e={$_.Count}}, 
					@{n='Days'     ;e={($_.Group.TimeCreated | Group-Object Day).Length}},
					@{n='LogName'  ;e={$_.Values[0]}},
					@{n='LogType'  ;e={$_.Values[1]}},
					@{n='Lvl'      ;e={$_.Values[2]}},
					@{n='Id'       ;e={$_.Values[3]}},
					@{n='Prvd'     ;e={$_.Values[4]}},
					@{n='FstTime'  ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}}},
					@{n='LstTime'  ;e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
					@{n='FstRecId' ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].RecordId}}},
					@{n='LstRecId' ;e={$_.Group[0].RecordId}},
					@{n='LstPid'   ;e={$_.Group[0].ProcessId}},
					@{n='LstMsg'   ;e={$_.Group[0].Message2}},
                    Group
		
	if ($Global:GROUPED_EVENTS.Length) {  
		pargs $('{0} events has been mapped into {1} group{2} of $Global:GROUPED_EVENTS' -f $Global:EVENTS.Length, $Global:GROUPED_EVENTS.Length,$(if($Global:GROUPED_EVENTS.Length -ne 1) {'s'}))
	} else {
		pargs $('Error: {0} events are not mapped into any groups' -f $Global:EVENTS.Length)
	}
	return
}

###############################################
# Get-XmlSearchWinEvents
function Get-XmlSearchWinEvents {
	param(	[string[]] $LogName, [string[]] $ProviderName, [int[]]$Levels=(1,2), [int[]]$EventIDs, [int[]] $RecIds, [int]$Seconds=0, [int]$MaxEvents )
    pargs
	$Global:XmlSystemParams=""
	if ($Seconds)        { $Global:XmlSystemParams+="TimeCreated[timediff(@SystemTime)<=$($Seconds*1000)]"}
	if ($EventIDs.Count) { $Global:XmlSystemParams+=" and ( EventID="+$($RecIds -join ' or EventIDs=') +" ) " }
	if ($RecIds.Count)   { $Global:XmlSystemParams+=" and ( EventRecordID="+$($RecIds -join ' or EventRecordID=') +" ) "  }
	if ($Levels.Count)   { $Global:XmlSystemParams+=" and ( Level="+$($Levels -join ' or Level=') +" ) " }	
	$Global:XmlSearch="*[System[$Global:XmlSystemParams]]"
	pargs $('output:{0}, MaxEvents:{1}, $Global:XmlSearch:{2}' -f '$Global:EVENTS', $MaxEvents, $Global:XmlSearch)
    $Global:EVENTS=Get-WinEvent -ProviderName $ProviderName -XmlSearch "$Global:XmlSearch" -MaxEvents $MaxEvents -ErrorAction "SilentlyContinue"
	if ($Global:EVENTS.Length) {  
		pargs $('{0} events matching given $Global:XmlSearch. These events have been loaded into $Global:EVENTS' -f $Global:EVENTS.Length)
	} else {
		pargs $('There are no events matching given $Global:XmlSearch')
	}
	return
}

#########################################
# Get-WinEvents
function Get-FilterHashtableWinEvents {
	param( [string[]] $LogName, [string[]] $ProviderName, [int[]]$Levels, [int[]]$EventIDs, [int[]] $RecIds, [int] $Seconds, [int] $MaxEvents=50000)
    pargs
	$Global:FilterHashtable=@{}	
	if ($LogName)       { $Global:FilterHashtable+=@{LogName=$LogName} }
	if ($ProviderName)  { $Global:FilterHashtable+=@{ProviderName=$ProviderName} }
	if ($Seconds)       { $Global:FilterHashtable+=@{StartTime=(Get-Date).AddSeconds(-$Seconds)} }
	if ($Levels)        { $Global:FilterHashtable+=@{Level=$Levels} }
	if ($EventIDs)      { $Global:FilterHashtable+=@{ID=$EventIDs} }
	# '[{0}] $Global:FilterHashtable[{1}] {2}' -f $MyInvocation.MyCommand, $FilterHashtable.Count, (($FilterHashtable.GetEnumerator()|% { if ($_.Value) { '{0}:{1}' -f ($_.Name -join(',')),($_.Value -join(',')) }} ) -join(' '))  
	# 'Reading events into $Global:EVENTS ...'
	pargs $('output:{0}, MaxEvents:{1}, $Global:FilterHashtable[{2}]:{3}' -f '$Global:EVENTS', $MaxEvents, $FilterHashtable.Count, (($FilterHashtable.GetEnumerator()|% { if ($_.Value) { '{0}:{1}' -f ($_.Name -join(',')),($_.Value -join(',')) }} ) -join(' ')) )
	$Global:EVENTS=Get-WinEvent -FilterHashtable $Global:FilterHashtable -MaxEvents $MaxEvents -ErrorAction "SilentlyContinue"
	if ($Global:EVENTS.Length) {  
		# '[{0}] {1} events has been loaded into $Global:EVENTS ' -f $MyInvocation.MyCommand, $Global:EVENTS.Length
		pargs $('{0} events has been loaded into $Global:EVENTS' -f $Global:EVENTS.Length)
	} else {
		pargs 'Error: there are no events matching $Global:FilterHashtable, $Global:EVENTS is emptied'
#		'[{0}] Error: events has not been loaded into $Global:EVENTS ' -f $MyInvocation.MyCommand
	}
}

###############################################
# Get-Events 
function Get-Events {
	param(  [int]      $MaxEvents, 
	        [string[]] $LogName='*', 
			[string[]] $ProviderName, [int[]]$Levels=(1,2), [int[]]$EventIDs, [int[]] $RecIds, 
		    [int]      $Days, [int] $Hours, [int] $Minutes, [int] $Seconds,
			[switch]   $UseCache,
			[int[]]    $Groups, [int[]] $Messages,
			[string[]] $ExcludeLogName,
            [string]   $FilterMsg,
			[int]      $FirstTop,
			[switch]   $NoTable,
			[switch]   $Warnings,
			[switch]   $ByMsg,
			[int]      $PrintLines=100)			

    pargs


	if (!$UseCache) { 

		$Seconds+=($Days*24+$Hours)*3600+$Minutes*60

		if ($Warnings) {
			# if (!$PSBoundParameters.ContainsKey('MaxEvents')) { $PsBoundParameters['MaxEvents']=20; }
			if (!$PSBoundParameters.ContainsKey('Levels')) { $Levels=@(1,2,3) }
		}
		if ($Seconds) { 
			$PsBoundParameters['Seconds']=$Seconds 
			$null=$PSBoundParameters.Remove('Days')
			$null=$PSBoundParameters.Remove('Hours')
			$null=$PSBoundParameters.Remove('Minutes')
		}

		if ( $LogName -eq '*' -and !$Seconds -and !$MaxEvents) { $MaxEvents=15000 }
		$MyArgs=@{ LogName=$LogName; }
		if ($MaxEvents)     {$MyArgs+=@{MaxEvents=$MaxEvents}} 
		if ($ProviderName)  {$MyArgs+=@{ProviderName=$ProviderName}} 
		if ($Seconds)       {$MyArgs+=@{Seconds=$Seconds}} 
		if ($Levels)        {$MyArgs+=@{Levels=$Levels}} 
		if ($EventIDs)      {$MyArgs+=@{EventIDs=$EventIDs}} 
		
		# pargs $( '$MyArgs[{0}]: {1}' -f $MyArgs.Count,(($MyArgs.GetEnumerator()|% { if ($_.Value) { '-{0}:{1}' -f ($_.Name -join(',')),($_.Value -join(',')) }} ) -join(' ')) )
		if ($RecIds) { 
			Get-XmlSearchWinEvents @MyArgs -RecIds $RecIds 
		} else {
			Get-FilterHashtableWinEvents @MyArgs
		}
		$MyArgs=@{}
		if ($FirstTop)        { $MyArgs+=@{ FirstTop=$FirstTop } }
		if ($ExcludeLogName)  { $MyArgs+=@{ ExcludeLogName=$ExcludeLogName } } 
		if ($FilterMsg)       { $MyArgs+=@{ FilterMsg=$FilterMsg } } 
		if ($ByMsg)           { Group-WinEventsByMsg @MyArgs } else { Group-WinEvents @MyArgs }
	}

	if (!$NoTable)  { 
		$MyArgs=@{}
		if($PrintLines)  { $MyArgs+=@{ First=$PrintLines } } 
		Format-TableGroupedEvents @MyArgs
	}

	if ($Groups)   { 
		$MyArgs=@{ Groups=$Groups }
		if($Messages)  { $MyArgs+=@{ Messages=$Messages } } 
		if($NoTable)   { $MyArgs+=@{ NoTable=$true }      } 
		Format-ListGroups @MyArgs
	}

}

# $PSBoundParameters.Remove('command')
# CodeExecutor @PsBoundParameters 

CodeExecutor @args

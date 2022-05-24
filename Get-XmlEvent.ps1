Param(
	[String[]]  $Levels, 
	[Int[]]     $RecIds, 
	[Alias('ID')]
	[Parameter(HelpMessage="Event ID(s) or shortcuts: '',10", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]	
	[Int[]]     $EventIDs, 
	[String[]]  $LogNames, 
	[Int[]]     $ExceptEventIDs, 
	[String[]]  $Providers, 
	[String[]]  $ExceptProviders,
	[Int]       $MaxEvents, 
	[Int]       $Hours, 
	[Int]       $Minutes, 
	[Int]       $Seconds, 
	[Int]       $ms, 
	[Int]       $ShowEvents, 
	[Int]       $ShowStats
)

# Get-XmlEvent -LogName * -FilterXPath "*[System[Ev …"
# Error: Log count (463) is exceeded Windows Event Log API limit (256). Adjust filter to return less log names.
# Examples:  Get-XmlEvent logon # start operating system messages for last 10 days
#            Get-XmlEvent critical 
#            Get-XmlEvent 0,1,2,3,4 38603,38604,38605  
#            Get-XmlEvent -RecIds 14393 -EventIDs 613
#            Get-XmlEvent 0,1,2,3 -Hours 12 -ExceptEventIDs 5379,4798,4799,4100 -ExceptProvider PowerShellCore,Microsoft-Windows-Security-Auditing
#            Get-XmlEvent -Hours 12
#            Get-XmlEvent -Hours 12 -Providers  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch,Microsoft-Windows-Security-Auditing

<#
Param(
        [Parameter(HelpMessage="Event Level(s) or shortcuts: '' - errors for 1 hour , 10 - logins for 10 days", Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        # [ValidateLength(1,104)]
        # [ValidatePattern('[^\"/\\\[\]:;\|=\,\+\*\?<>\s]', Options='IgnoreCase')]
        [System.String[]] $Levels, 
		[int[]] $RecIds, 
		[Alias('ID')]
		[Parameter(HelpMessage="Event ID(s) or shortcuts: '',10", Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[int[]] $EventIDs, 
		[string[]] $LogNames='*', 
		[int[]] $ExceptEventIDs, [string[]] $Providers, [string[]] $ExceptProviders,
		[int] $MaxEvents=10000, [int] $Hours=0, [int] $Minutes=0, [int] $Seconds=0, [int] $ms=0, [int] $ShowEvents=500, [int] $ShowStats=20
	)
#>

function Get-XmlEvent {
    Param([string[]]$Levels, [int[]]$RecIds, [int[]]$EventIDs, [string[]]$LogNames='*', 
	[int[]]$ExceptEventIDs,[string[]]$Providers, [string[]]$ExceptProviders,
	[int]$MaxEvents=20000, [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=0, [int]$ShowEvents=3, [int]$ShowStats=20
	)
	$Conditions=@()
	$Global:FILTERXPATH=""
	if ( ! $PSBoundParameters.Count ) {
		''
		'{0} {1} {2}' -f  $MyInvocation.MyCommand.CommandType, $MyInvocation.MyCommand, $MyInvocation.MyCommand.ParameterSets[0].ToString()
		'{0}' -f "Examples:"
		'    {0} {1,-15} # {2}' -f $MyInvocation.MyCommand, "logon", "User account logons. Log='System'; EventIDs=4624"
		'    {0} {1,-15} # {2}' -f $MyInvocation.MyCommand, "os_start", "OS Start at. during last 10 days; Provider='Microsoft-Windows-Kernel-General'; EventIDs=12"
		'    {0} {1,-15} # {2}' -f $MyInvocation.MyCommand, "critical", "Critical and error messages during last 2 hours"
		''
		return
	} elseif ( $Levels -and $PSBoundParameters.Count -eq 1 ) {
		switch ($Levels) {
			'logon'      { $LogNames='System'; $Levels=@(); $EventIDs=@(4624) }
			'os_start'   { $Providers=@('Microsoft-Windows-Kernel-General'); $Levels=@(); $EventIDs=@(12) }
			# $Global:FILTERXPATH="*[System/Provider[@Name='Microsoft-Windows-Kernel-General'] and System[(EventID=12)]]" 
			'critical'   { $Hours=1; $Levels=@(1,2) } # critical and error events during last hour
			# default { }
		}
	} 
	
	if ($RecIds)   { $tArr=@('EventRecordID='); $tArr+=@($RecIds -join ' or EventRecordID='); $Conditions+=@("System["+ $($tArr -join '') +"]") } 
	if ($Levels)   { $tArr=@('Level='); $tArr+=@($Levels -join ' or Level='); $Conditions+=@("System["+ $($tArr -join '') +"]") }
	if ($EventIDs) { $tArr=@('EventID='); $tArr+=@($EventIDs -join ' or EventID='); $Conditions+=@("System["+ $($tArr -join '') +"]") }
	
	if ($ExceptEventIDs) { $tArr=@('EventID!='); $tArr+=@($ExceptEventIDs -join ' and EventID!='); $Conditions+=@("System["+ $($tArr -join '') +"]") }

	$ms=$ms+$Hours*3600*1000+$Minutes*60*1000+$Seconds*1000
	if ($ms) { $Conditions+=@("System/TimeCreated[timediff(@SystemTime)&lt;=$ms]") }

	if ($Providers) { $tArr=@('System/Provider[@Name="'); $tArr+=@($Providers -join '"] or System/Provider[@Name="'); $Conditions+=@( ($tArr -join '')+'"]') }
	
	if ($ExceptProviders) { $tArr=@('System/Provider[@Name!="'); $tArr+=@($ExceptProviders -join '"] and System/Provider[@Name!="'); $Conditions+=@( ($tArr -join '') + '"]') }
	
	$Global:FILTERXPATH=""
	#  $Global:FILTERXPATH="*[System/Provider[@Name='Microsoft-Windows-Kernel-General'] and System[(EventID=12)]]"
	$NoConditions=$Conditions.Count
	# $Global:FILTERXPATH="("+$($Conditions -join ') and (')+")"
	# $Global:FILTERXPATH="*[System[ $Global:FILTERXPATH ]]"
	
	if ($NoConditions) { $Global:FILTERXPATH="*["+$($Conditions -join ' and ')+"]" }
	""
	"`$Global:FILTERXPATH contains $NoConditions condition$(if($NoConditions -ne 1){'s'}): $Global:FILTERXPATH" 
	$lCnt=$LogNames.Count
	"Getting WinEvents into `$Global:LOGS, -LogNames[$lCnt]:$($LogNames[0..3] -join ",")$(if($lCnt -gt 3){' ...'})"
	$global:LOGS=@()
	if ($LogNames -eq '*') {
		$global:LOGS=@((get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddHours(-25))}).LogName)
	} else {
		$global:LOGS=@((get-winevent -listlog $LogNames -ea 0).LogName)
	}
	$lCnt=$global:LOGS.Count
	
	"$lCnt log$(if($lCnt -ne 1){'s'}):$($global:LOGS[0..3] -join ",")$(if($lCnt -gt 3){' ...'})"
	"Getting WinEvents into `$Global:EVENTS, MaxEvents:$MaxEvents ..."
    $Global:EVENTS=Get-WinEvent -LogName $global:LOGS -FilterXPath $Global:FILTERXPATH -MaxEvents $MaxEvents -ea 0 
		
	$eTot=$Global:EVENTS.Count
    "[done] found $eTot event$(if ($eTot -ne 1) {'s'})"
    if ($eTot) {
		"Printing events, ShowEvents:$ShowEvents ..."
		$eNo=0
        foreach ($E in $Global:EVENTS) {
			$eNo++
			if ( ($eNo -lt $ShowEvents) -or ($eNo -eq $eTot) ) {
				"`n$eNo of $eTot"
				$pad=1; $E.ToXml() -replace("><",">`n<") -split("`n") |
				% { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>|^[^<]")) {$pad+=2} }
			}
        }
			# -replace "^[^<>]*","'" .. |^[^<]*
		"[done] $eNo of $eTot event$(if($eNo -ne 1){'s'}) printed"
		"Grouping WinEvents into `$Global:GROUPED_EVENTS ..."
		$global:GROUPED_EVENTS=$global:EVENTS | 
			Select-Object *, 
				@{n='Log';e={$_.LogName -replace "Microsoft-Windows-","" -replace "Microsoft-Client-","" -replace '/Operational','/Op' }},
				@{n='Message2';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; '))-join '; '}},
				@{n='Msg';e={ $($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>'  -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' `
									  -replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' -replace '(?<=.{120}).+' }} |
			Group-Object LogName,Id,Level,Msg | Sort-Object -descending Count,Group[0].TimeCreated
		$gTot=$Global:GROUPED_EVENTS.Count
		"[done] found $gTot event$(if ($gTot -ne 1) {'s'})"
		if ($ShowStats) {
				"Printing groups, ShowStats:$ShowStats ..."
				$global:GROUPED_EVENTS | Select Count, 
					@{n='LogName';e={$_.Group[0].Log}},
					@{n='Lvl';e={Switch ($_.Values[2]) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}}},
					@{n='Id';e={$_.Values[1]}},
					@{n='FstTime';e={$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},
					@{n='LstTime';e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
					@{n='Msg';e={$_.Values[3] -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' '}},
					@{n='Providers';e={($_.Group | Group-Object ProviderName  | Sort-Object count | select *,@{n='P';e={'{0}:{1}' -f $_.Name,$_.Count}} ).P}},
					@{n='FstRecordId';e={$_.Group[$_.Count-1].RecordId}},
					@{n='LstRecordId';e={$_.Group[0].RecordId}},					
					@{n='LstMsg';e={$_.Group[0].Message2 -replace "`r",'' -replace "`n+",'\n' -replace '\s+',' ' -replace '(?<=.{220}).+'}},
					@{n='LastPid';e={$_.Group[0].ProcessId}}| 
				Select-Object -first $ShowStats * | 
				Format-Table -auto @{n='Cnt';w=5;;e={$_.Count}}, 
					@{n='LogName';w=20;e={$_.LogName}},
					@{n='Lvl';w=5;e={$_.Lvl}},
					@{n='Id';w=8;e={$_.Id}},
					@{n='FstTime';w=20;e={$_.FstTime}},
					@{n='LstTime';w=20;e={$_.LstTime}},	
					# @{n='Msg';w=80;e={$_.Msg}},
					@{n='Providers';w=80;e={$_.Providers}},
					@{n='FstRecId';w=10;e={$_.FstRecordId}},
					@{n='LstRecId';w=10;e={$_.LstRecordId}},
					@{n='LstMsg';w=180;e={$_.LstMsg}},
					@{n='LastPid';w=10;e={$_.LastPid}}
					# , @{n='LastProcess';e={(Get-Process -ID $_.LastPid).Path}}
		}
	}
}

function Get-DayOfEvents {
	param( $Days=1, $LogName="*" )
	Get-WinEvent -FilterHashtable @{ LogName=$LogName; StartTime=((Get-Date).AddDays(-$Days)) }
}

function Get-XmlEventOneLiner {
	param($Days=1, $LogName="*")
	# Example: Get-EventStats | Sort-Object Cnt,LstTime -Descending | Format-Table -AutoSize 
	# Example: Get-EventStats | Select -First 20 * | Format-Table -AutoSize 
	 Get-DayOfEvents @PsBoundParameters | 
	 Select-Object *, @{n='Log';e={$_.LogName -replace "Microsoft-Windows-","" -replace "Microsoft-Client-","" -replace '/Operational','/Op' }},
	 @{n='Lvl';e={Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}}}, 
	 @{n='Msg';e={$_.Message -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" `
		-replace '"[^"]+"','"X"' -replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' -replace ': [^.\n]+',': X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace "(?<=.{120}).+" }} |
		 where {$_.msg.Length -lt 3} | select -first 3 *
}

function Get-XmlEventTest {
    Param(
        [Parameter(HelpMessage="Event Level(s) or shortcuts: '' - errors for 1 hour , 10 - logins for 10 days", Mandatory=$true,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        # [ValidateLength(1,104)]
        # [ValidatePattern('[^\"/\\\[\]:;\|=\,\+\*\?<>\s]', Options='IgnoreCase')]
        [System.String[]] $Levels, 
		[int[]]$RecIds, 
		[Alias('ID')]
		[Parameter(HelpMessage="Event ID(s) or shortcuts: '',10")]	
		[int[]]$EventIDs, [string[]]$LogNames='*', 
		[int[]]$ExceptEventIDs,[string[]]$Providers, [string[]]$ExceptProviders,
		[int]$MaxEvents=10000, [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=0, [int]$ShowEvents=3, [int]$ShowStats=20
	)

	[string] $filterXML

	if (!$global:LOGS) { $global:LOGS=(get-winevent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddHours(-25))}).LogName }
	
	if (0) {
		$filterXML="
		 <Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
		   <System>
			 <Provider Name='Microsoft-Windows-Security-Auditing' Guid='{54849625-5478-4994-a5ba-3e3b0328c30d}'/>
			 <EventID>5379</EventID>
			 <Version>0</Version>
			 <Level>0</Level>
			 <Task>13824</Task>
			 <Opcode>0</Opcode>
			 <Keywords>0x8020000000000000</Keywords>
			 <TimeCreated SystemTime='2022-05-02T02:09:51.4380419Z'/>
			 <EventRecordID>191464</EventRecordID>
			 <Correlation ActivityID='{aa24c1d8-5d76-0004-40c2-24aa765dd801}'/>
			 <Execution ProcessID='1624' ThreadID='17684'/>
			 <Channel>Security</Channel>
			 <Computer>Win11-2</Computer>
			 <Security/>
		   </System>
		   <EventData>
			 <Data Name='SubjectUserSid'>S-1-5-21-3101668316-195586092-1316055306-1001</Data>
			 <Data Name='SubjectUserName'>alexe</Data>
			 <Data Name='SubjectDomainName'>WIN11-2</Data>
			 <Data Name='SubjectLogonId'>0xd8e4d</Data>
			 <Data Name='TargetName'>WindowsLive:(token):name=alex.evteev@outlook.com;serviceuri=*</Data>
			 <Data Name='Type'>0</Data>
			 <Data Name='CountOfCredentialsReturned'>0</Data>
			 <Data Name='ReadOperation'>%%8100</Data>
			 <Data Name='ReturnCode'>3221226021</Data>
			 <Data Name='ProcessCreationTime'>2022-05-02T02:09:51.3046452Z</Data>
			 <Data Name='ClientProcessId'>11904</Data>
		   </EventData>
		 </Event>"
	}

	if (0) {
		$filterXML='
			<QueryList><Query Id="0" Path="System">
			<Select Path="System">*[System[Provider[@Name="Microsoft-Windows-Security-Auditing"] and (Level=0 or Level=1 or Level=2) and (EventID=5379)]]</Select>
			</Query></QueryList>'
	}
	
	if (0) { $filterXML="*[System[ (Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=5379) ]]" }
 
	
	if (0) { $filterXML="*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=5379]]" }

	if (0) { 
	$filterXML='<QueryList>
		  <Query Id="0">
			<Select Path="Application">
				*[System[ ( Provider[@Name="Microsoft-Windows-Security-Auditing"] ) and ( Level=0 or Level=1 or Level=2 or Level =3 ) ]]
			</Select>
			<Suppress Path="Application">
				*[System[ EventID=5379 ]]
			</Suppress>
			<Select Path="System">
				*[System[ ( Provider[@Name"Microsoft-Windows-Security-Auditing"] ) and ( Level=0 or Level=1 or Level=2 or Level =3 ) ]]
			</Select>
			<Suppress Path="System">
				*[System[ EventID=5379 ]]
			</Suppress>
		  </Query>
		</QueryList>'
	}

	if (0) { 
		$filterXML="<QueryList>
		  <Query Id='0'>
			<Select Path='System'>
				*[System[ ( Provider[@Name='Microsoft-Windows-Security-Auditing'] ) and ( Level=0 or Level=1 or Level=2 or Level=3 ) ]]
			</Select>
		  </Query>
		</QueryList>"
	}
	if (0) { 
		# GOOD! ########
		$filterXML="*[System[ ( Provider[@Name='Microsoft-Windows-Security-Auditing'] ) and ( Level=0 or Level=1 or Level=2 or Level=3 ) ]]"
	}
################
	if (0) { $filterXML = '<Select Path="Security">*[System[ ( Provider[@Name="Microsoft-Windows-Security-Auditing"] ) and ( Level=0 or Level=1 or Level=2 or Level=3 ) ]]</Select>' }
	if (0) { $filterXML = '*[System[ ( Provider[@Name="Microsoft-Windows-Security-Auditing"] ) and ( Level=0 or Level=1 or Level=2 or Level=3 ) ]]' }
	
	(Get-WinEvent -LogName $global:LOGS -FilterXPath $filterXML -MaxEvents 1).ToXml()

}
 
#########################
# Events with suppress
function Get-XmlEventSuppressTest {
    Param(
        [Parameter(HelpMessage="Event Level(s) or shortcuts: '' - errors for 1 hour , 10 - logins for 10 days", Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        # [ValidateLength(1,104)]
        # [ValidatePattern('[^\"/\\\[\]:;\|=\,\+\*\?<>\s]', Options='IgnoreCase')]
        [System.String[]] $Levels, 
		[int[]]$RecIds, 
		[Alias('ID')]
		[Parameter(HelpMessage="Event ID(s) or shortcuts: '',10")]	
		[int[]]$EventIDs, [string[]]$LogNames='*', 
		[int[]]$ExceptEventIDs,[string[]]$Providers, [string[]]$ExceptProviders,
		[int]$MaxEvents=10000, [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ms=0, [int]$ShowEvents=3, [int]$ShowStats=20
	)

	$query = "<QueryList>
		  <Query Id='0'>
			<Select Path='Application'>
				*[System[(Level &lt;= 3) and
				TimeCreated[timediff(@SystemTime) &lt;= 86400000]]]
			</Select>
			<Suppress Path='Application'>
				*[System[(Level = 2)]]
			</Suppress>
			<Select Path='System'>
				*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) &lt;= 86400000]]]
			</Select>
		  </Query>
		</QueryList>"

	(Get-WinEvent -FilterXml $query -MaxEvents 1).ToXml()

	<# 
	<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
	<System>
		<Provider Name='Microsoft-Windows-DNS-Client' Guid='{1c95126e-7eea-49a9-a3fe-a378b03ddb4d}'/>
		<EventID>1014</EventID><Version>1</Version><Level>3</Level><Task>1014</Task><Opcode>0</Opcode><Keywords>0x4000000010000000</Keywords>
		<TimeCreated SystemTime='2022-05-01T16:42:10.1995410Z'/>
		<EventRecordID>12774</EventRecordID><Correlation/>
		<Execution ProcessID='2968' ThreadID='13588'/><Channel>System</Channel>
		<Computer>Win11-2</Computer><Security UserID='S-1-5-20'/>
	</System>
	<EventData>
		<Data Name='QueryName'>checkappexec.microsoft.com</Data>
		<Data Name='AddressLength'>128</Data><Data Name='Address'>02000000C0A80101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000</Data>
		<Data Name='ClientPID'>12020</Data>
	</EventData>
	</Event>
	#>

}

##############################################################
# Last five system start times

function Get-SystemStart {
	$filterXML="<QueryList>
	  <Query Id='0' Path='System'>
		<Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Kernel-General'] and (Level=4 or Level=0) and (EventID=12)]]</Select>
	  </Query>
	</QueryList>"
	Get-WinEvent -LogName Security -FilterXPath $filterXML -MaxEvents 1000
}


#####
# Get-EventXmlByRecId 
# Example: Get-EventXmlByRecId -No 0,1

function Get-EventXmlByRecId {
    Param([int]$RecId, [int[]] $No, $Days=15, [int[]] $Levels=@(0,1,2,3,4)) # 0 - LogAlways, 1-Critical, 2-Error, 3-Warning, 4-Informational, 5-Verbose
    $eNo=0;
	if (! $global:ALL_EVENTS) {
		$global:ALL_EVENTS=Get-WinEvent -FilterHashtable @{LogName="*"; Level=$Levels; StartTime=((Get-Date).AddDays(-$Days))} -ErrorAction Ignore 
		"First Event"
		$global:ALL_EVENTS | select -first 1 *
		"Last Event"
		$global:ALL_EVENTS | select -last  1 *
	}
	$eTot=$global:ALL_EVENTS.Count
    "Total Events:$eTot Event$(if ($eTot -ne 1) {'s'}), Days:$Days,  Levels:$($Levels -join(','))"
	if ($RecId) {
		"RecId:$RecId"
		foreach ($E in $global:ALL_EVENTS|where-object {$_.RecordId -eq $RecId}) {
			$eCnt++;$pad=1;$E.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eCnt of $(($EVENTS).Count)") -split("`n") |
				% { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }
		}
		"$eCnt Event$(if ($eCnt -ne 1) {'s'}) events found"
	}
	if ($No.Count) {
		"Checking events positions: $($No -join(','))"
		foreach ($n in $No) {
			if ($global:ALL_EVENTS[$n]) {
				$E=$global:ALL_EVENTS[$n]			
				$eCnt++;$pad=1;$E.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eCnt of $(($EVENTS).Count)") -split("`n") |
					% { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }
			}
		}
		"$eCnt Event$(if ($eCnt -ne 1) {'s'}) events found"
	}
}

function Get-MsgNorm($E)  {
    $E.Message -replace '{[^}]+}','{X}' -replace '\([^)]+\)','(X)' -replace '<[^>]+>','<X>' -replace '\[[^\]]+\]','[X]' -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' -replace '[0-9][A-Za-z0-9-,_\.:]+','X.' -replace '0x[A-Fa-f0-9-\.:]+','0xX' -replace ': [^.\n]+',': X' -replace '(?<=.{120}).+'
}
	
function Get-EventStats {
	Param($mode="RepeatedEvents", $Days=1, [int[]] $Levels=@(0,1,2,3)) # 0 - LogAlways, 1-Critical, 2-Error, 3-Warning, 4-Informational, 5-Verbose
    $eNo=0;
	if ($global:ALL_EVENTS_DAYS=$Days -ne $Days ) {$global:ALL_EVENTS=@()} 
	if ($PSBoundParameters.ContainsKey('Levels')) {$global:ALL_EVENTS=@()}
	if ( !$global:ALL_EVENTS -or $global:ALL_EVENTS.Count -eq 0 ) {
		$global:ALL_EVENTS_DAYS=$Days
		$global:ALL_EVENTS_LEVELS=$Levels
		
		'[ Reading events ] Days:{0}, Levels:{1}' -f $global:ALL_EVENTS_DAYS,$($global:ALL_EVENTS_LEVELS -join(','))
		$global:ALL_EVENTS=Get-WinEvent -FilterHashtable @{LogName="*"; Level=$Levels; StartTime=((Get-Date).AddDays(-$Days))} -ErrorAction Ignore 
	
        '[ Done ] Found {0} events' -f $global:ALL_EVENTS.Count
		
		'[ Reading Event Groups] Group By: Log, EventId, Level, FormatedMsg'
		
		$global:ALL_EVENTS_GROUPED=$global:ALL_EVENTS | Select-Object *,
		      @{n='Log';e={$_.LogName -replace "Microsoft-Windows-","" -replace "Microsoft-Client-","" -replace '/Operational','/Op' }},
			  @{n='Msg';e={$_.Message ` 
    -replace '{[^}]+}','{X}' `
    -replace '\([^)]+\)','(X)' `
    -replace '<[^>]+>','<X>' `
	-replace '\[[^\]]+\]','[X]' `
	-replace "'[^']+'","'X'" `
	-replace '"[^"]+"','"X"' `
	-replace ' [^ ]+([-\._:]+[A-Za-z0-9]+)+',' X-X' `
	-replace '[0-9][A-Za-z0-9-,_\.:]+','X.' `
	-replace '0x[A-Fa-f0-9-\.:]+','0xX' `
	-replace ': [^.\n]+',': X' `
	-replace '(?<=.{120}).+' }} | Group-Object Log,EventId,Level,Msg
	
		'[ Done ] Found {0} groups' -f $global:ALL_EVENTS_GROUPED.Count
	}
	$eTot=$global:ALL_EVENTS.Count
	$gTot=$global:ALL_EVENTS_GROUPED.Count
    '$global:ALL_EVENTS:{0} events, $global:ALL_EVENTS_GROUPED:{1} groups, $global:ALL_EVENTS_DAYS:{2}, $global:ALL_EVENTS_LEVELS:{3}' -f $eTot,$gTot,$global:ALL_EVENTS_DAYS,$($global:ALL_EVENTS_LEVELS -join(','))
	'mode:{0}' -f $mode
	switch ($mode) {
		"RepeatedEvents" {
			if ( $global:ALL_EVENTS_GROUPED -and $global:ALL_EVENTS_GROUPED.Count -gt 0 ) {
			    $global:ALL_EVENTS_GROUPED | Where-Object {$_.Count -gt 2} | 
					Select-Object @{n='Cnt';e={$_.Count}},
						@{n='FstTime';e={$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm')}},
						@{n='LstTime';e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm')}},	
						@{n='Log';e={$_.Group[0].Log}},
						@{n='EventId';e={$_.Group[0].Id}},
						@{n='Lvl';e={Switch ($_.Group[0].Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}}},
						@{n='LastMsg';e={$_.Group[0].Msg}},
						@{n='LastPid';e={$_.Group[0].ProcessId}},
						@{n='LastProcess';e={(Get-Process -ID $_.LastPid).Path}} 
			} else {
				'ALL_EVENTS_GROUPED is not set'
			}
		}
	}
}

# 1355, Microsoft-Windows-WER-PayloadHealth

function Get-EventXmlByRecIdAndProvider {
    Param([int]$RecId=38603, [string]$Provider='Firefox Default Browser Agent')
    "RecID is $RecId; Provider is '$Provider'"
    $EVENTS=Get-WinEvent -ProviderName $Provider -FilterXPath "*[System[EventRecordID=$RecId]]" -ea 0; $eTot=$EVENTS.Count
    "Found $eTot event$(if ($eTot -ne 1) {'s'})"
    if ($eTot) {
		$eNo=0
        foreach ($E in $EVENTS) {
            $pad=1;$eNo++; $E.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eNo of $(($EVENTS).Count)") -split("`n") |
            % { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }
        }
        "RecID: $RecId; Provider:$Provider; Total: $eNo Event$(if ($eNo -ne 1) {'s'})"
    }
}


Get-XmlEvent @PSBoundParameters
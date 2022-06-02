##################################################
#  $Global:Users
$myscript=$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf)

if (!$Global:Users) { $Global:Users=Get-LocalUser }

##################################################
# $Global:EVENTS_OUT_COLS
$Global:EVENTS_OUT_COLS=@( "MsgNo",
	@{n='Day'      ;e={$_.TimeCreated.ToString('MM/dd')}},
	'ProcessId', 
	@{n='Time'     ;e={$_.TimeCreated.ToString('HH:mm:ss.fff')}}
	'RecordId',
	@{n='Lvl'      ;e={'{0}({1})' -f $(Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}),$_.Level }},
	@{n='Log'      ;e={$_.LogName -replace '/.*$','' -replace '(Microsoft-Windows-|Microsoft-Client-|-Admin)','' }},
	@{n='LogType'  ;e={$( $(switch -wildcard ($_.LogName){ 'Microsoft-Windows-*' {'MS-Win'}; 'Microsoft-Client-*' {'MS-Client'};} ),
		$(if($_.LogName -like '*-Admin'){'Admin'}), $(if($_.LogName -like '*/*'){$_.LogName -replace '^.*/','' -replace 'Operational','Oper'}) -ne '' ) -join(',')}},
	@{n='Provider';e={$_.ProviderName -replace $($_.LogName -replace '/.*$','' -replace 'Known Folders.*','KnownFolders' -replace 'PushNotification','PushNotifications' `
		-replace 'AppXDeploymentServer','AppXDeployment-Server' -replace 'Storage-Storport','StorPort' -replace '(-Events|-Admin)','' ),"*" -replace '(Microsoft-Windows-|Windows-)',''}},
	@{n='User'     ;e={$Sid=$_.UserId; '{0}' -f $(Switch ($Sid) { 'S-1-5-18' {"LocalSystem"}; 'S-1-5-20' {"NT Authority"}; default {  $($Global:Users |? Sid -like $Sid).Name }; }) }},
	@{n='OpCode'   ;e={if ($_.Opcode) {'{0}({1})' -f $_.OpcodeDisplayName,$_.Opcode} }},
	@{n='Task'     ;e={if ($_.Task) {'{0}({1})' -f $_.TaskDisplayName,$_.Task} }},
	'ThreadId',		
	@{n='KeyWords' ;e={$_.KeywordsDisplayNames -replace('(?<=.{40}).+','..')}},
	@{n='Message';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace "^This is the first instance.*$",'' -replace "[`n`r]+",' ' -replace '\s+',' ' -replace '(?<=.{260}).+','...' }},
	'Id','TimeCreated'
)
$Global:EVENTS_EXCL_OUT_COLS=@("Message","Properties","Bookmark","ContainerLog","RelatedActivityId","MatchedQueryIds","ProviderId",'TimeCreated')

$Global:EVENT_GROUPS_COLS=(
	@{n='Grp'        ;e={($script:Grp++)}},
	@{n='LstMsg'     ;e={$_.Group[0].MsgNo}},
	@{n='Cnt'        ;e={$_.Count}}, 
	@{n='Days'       ;e={($_.Group.TimeCreated | Group-Object Day).Length}},
	@{n='LogName'    ;e={$_.Values[0]}},
	@{n='LogType'    ;e={$_.Values[1]}},
	@{n='Lvl'        ;e={$_.Values[2]}},
	@{n='Id'         ;e={$_.Values[3]}},
	@{n='Prvd'       ;e={$_.Values[4]}},
	@{n='User'       ;e={$_.Values[5]}},
	@{n='FstTime'    ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}}},
	@{n='LstTime'    ;e={$_.Group[0].TimeCreated.ToString('MM/dd HH:mm:ss.fff')}},	
	@{n='FstRecId'   ;e={if($_.Count -gt 1){$_.Group[$_.Count-1].RecordId}}},
	@{n='LstRecId'   ;e={$_.Group[0].RecordId}},
	@{n='LstPid'     ;e={$_.Group[0].ProcessId}},
	@{n='CntPid'     ;e={($_.Group | Group-Object ProcessID).Length}},
	@{n='Lst3Pids'   ;e={($_.Group | Group-Object ProcessID| Sort-Object -Descending Count -Top 3 | select @{n='List';e={'{0}({1})' -f $_.Name,$_.Count}}).List -join (',')}},					
	@{n='ListOfPids' ;e={($_.Group | Group-Object ProcessID| Sort-Object -Descending Count | select @{n='List';e={'{0}({1})' -f $_.Name,$_.Count}}).List -join (',')}},
	@{n='LstMessage' ;e={$_.Group[0].Message}},
	"Group"
)

$Global:EVENT_GROUPS_OUT_COLS=('Grp','LstMsg','Cnt','Days','LogName','LogType','Lvl','Id','Prvd','User','FstTime','LstTime','FstRecId','LstRecId','LstPid','CntPid','Lst3Pids','ListOfPids','LstMessage','Group' )
$Global:EVENT_GROUPS_EXCL_COLS=("Providers","Group","Values","Msg","ListOfPids","FstRecId","LstPid")

# Error: Log count (463) is exceeded Windows Event Log API limit (256). Adjust filter to return less log names.
# Examples:  
#            Win-Event.ps1                                 # last 50000 error events, see output in C:\home\data\Reports\Get-Events-2022-05-18.txt
#            Win-Event.ps1 Get-MyWinEvents                 # last 50000 error events, see output in C:\home\data\Reports\Get-Events-2022-05-18.txt
#            Win-Event.ps1 Get-MyWinEvents -Table -Raw -ExclLogs:("Core","Store") -Top:10 -Pids:1608
#            Win-Event.ps1 Get-MyWinEvents -List  -Raw -ExclLogs:("Core","Store") -Top:2
#            Win-Event.ps1 -Hours 1                        # All events during last hour
#            Win-Event.ps1 -Pids:1608 -Group 15
#            Win-Event.ps1 -Msgs:'SCM Event' -Top:40
#            Win-Event.ps1 -Days 10 -Warning -Groups 1,2,3 # 10 days of error and warnings, see output in C:\home\data\Reports\Get-Events-2022-05-18-warnings.txt
#            test1.ps1 -Hour 1  -Warning -ExclLogs PSCore,LiveId # exclude logs PSCore and LiveId from the table of groups
#            test1.ps1 -Hour 5  -Warning -ExclLogs PSCore,LiveId -Msgs '*sqlite3_exec*'
#
#  All Messages from the given PID, during 13 hours, printed in groups
#            Win-Event.ps1 -Hour 13 -Pids 20992 -AllGroups -AllMessages 
#            Win-Event.ps1 -Hour 13 -Pids 20992 -AllGroups -AllMessages -UseCache
#            Win-Event.ps1 -UseCache -FilterGroupPid:1
#  Alternatives:
#
#              $ProcId=($Global:EVENT_GROUPS[0].Group | Group-Object ProcessID | Sort-Object -Descending Count | select @{n='ProcessId';e={$_.Values[0]}},Count)[1].ProcessId
#              $EVENT_GROUPS.Group |? ProcessId -eq $ProcId | Sort-Object -Top 10 -Descending TimeCreated| ft -wrap ProcessId,ThreadId,UserId,MsgNo,TimeCreated,Lvl,Id,ProviderName,OpcodeDisplayName,KeywordsDisplayNames,Message
#  one-liners:
# $GrpNo=0; $PidNo=0; $TopCnt=2; $EVENT_GROUPS.Group |? ProcessId -eq $($Global:EVENT_GROUPS[$GrpNo].Group | Group-Object ProcessID | Sort-Object -Descending Count )[$PidNo].Values[0]| Sort-Object -Top $TopCnt -Descending TimeCreated | ConvertTo-Json -depth 3

<# 
 $GrpNo=0; $PidTop=1; $EventTop=3
 $WinEventCols="ProcessId","ThreadId","UserId","MsgNo","TimeCreated","Lvl","Id","ProviderName","OpcodeDisplayName","KeywordsDisplayNames","Message"
 # $WinEventExlcudeCols="Message","ProviderName","KeywordsDisplayNames"
 foreach($P in $($Global:EVENT_GROUPS[$GrpNo].Group | Group-Object ProcessID | Sort-Object -Top $PidTop -Descending Count).Values) { 
	"*** ProcessID:$P ***"; $EVENT_GROUPS.Group |? ProcessId -eq $P | 
	 Sort-Object -Top $EventTop -Descending TimeCreated | 
	 Select-Object @{}+|
	 ft -wrap *
 }
#>
#              $EVENT_GROUPS[0..10].Group |? ProcessId -eq 20992 | ft MsgNo,TimeCreated,ProcessId,Log,LogType,Provider,Lvl,Id,Version,Level,Task,Opcode,Keywords,RecordId,Message2
#              $EVENT_GROUPS[0..10] |? { $_.Group.ProcessId -eq 20992} 
#              ft TimeCreated,ProcessId,Log,LogType,Provider,Lvl,Id,Version,Level,Task,Opcode,Keywords,RecordId,Message2
#              search in $EVENT_GROUPS  by last pid
#              $EVENT_GROUPS | ? LstPid -eq 13240 | ft *             
#
# All Messages produced by the process of the first messages of the group 1, during 13 hours, printed in groups
#            Win-Event.ps1 -Hour 13 -FilterGroupPid 1 -AllGroups -AllMessages 
#
#            Win-Event.ps1 -EventIDs 613 # EventID during last 24 hours 
#            Win-Event.ps1 -Msgs '*sqlite3_exec*'
#            test1.ps1 -Groups 1          # 
#            test1.ps1 -NoTable -Group 1  # last 10 error events and xml sampler
#            test1.ps1 -warn          # last 20 errors and warnings
#            test1.ps1 500            # last 500 error events
#            test1.ps1 500 -warn      # last 500 error events
#            test1.ps1 2000 -warn -UseCache -Group 1
#            test1.ps1 -warn -MaxEvents 10000 -Groups 1,2
#            test1.ps1 -UseCache -Groups 1,2
#            
#            
#            Get-XmlEvent -Hours 12 -Providers  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch
#            Get-XmlEvent -Hours 12 -ExceptProviders  Microsoft-Windows-Hyper-V-VmSwitch,Microsoft-Windows-Security-Auditing
#
# ^^^^^^  OneLiners ***********
#       Get-WinEvent -FilterHash @{LogName='*'; Level=1,2} -Max 1 | fl *
#       (Get-WinEvent -FilterHash @{LogName='*'; Level=1,2} -Max 1).ToXML() -replace("><",">`n<") -split("`n")
#       Get-WinEvent -FilterHash @{LogName='*'; Level=1,2} -Max 1 | ConvertTo-JSON
# ^^^^^^  Use ConvertTo-JSON to read messges ***********
#       $E=(Get-WinEvent -FilterHash @{LogName='*'; Level=1,2} -Max 1); Get-WinEvent $E.LogName -FilterXPath "*[System[EventRecordID=$($E.RecordID)]]" | ConvertTo-JSON


function fnc-start() {
	
	if (!$global:myscript) { $global:myscript=Split-Path $MyInvocation.ScriptName -leaf }
	if (!$global:mywatch) { $global:mywatch=[System.Diagnostics.Stopwatch]::New() }
    
	$fmt="$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks. "+
	"Called from line $cyn{5}$gry at $ylw{6}$gry | $ylw{7}$blu[$ylw{8}$blu]${gry}: $ylw{9}$gry. $rc" 
	
	$fmt -f $MyInvocation.MyCommand, $global:myscript, $MyInvocation.ScriptLineNumber,
		$global:mywatch.Elapsed.milliseconds, $global:mywatch.Elapsed.ticks,$MyInvocation.ScriptLineNumber, $(Get-Date), 
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


#############################################################
#
# Print Variables
#
#############################################################

###############################################
# Convert-HashToString
function Convert-HashToString([hashtable]$value) {
	($value.GetEnumerator()|% { 
		$k=$_.Name; $v=$_.Value; '{0}="{1}";' -f $k, $( 
			if($v -is [hashtable]){
				$v.GetEnumerator()|% {'{0}="{1}";' -f $_.Name,$_.Value}
			} elseif($v -is [array]) {
				($v|% {
					$va=$_; 
					$(if($va -is [hashtable]) {
						$va.GetEnumerator()|% {'{0}="{1}";' -f $_.Name,$_.Value} 
					} else {
						'[{0}]{1}' -f $va.GetType(),$va.ToString() 
					} )
				}) -join(",") 
			} else {
				'[{0}]{1}' -f $v.GetType(),$v.ToString()
			}
		)
	}) -join(';')  -replace ("\s+",' ')
}
	   
function pval($vals, [int]$max=1000, [switch]$noclr, [int]$depth=2, [string[]]$exclude=("*properties","*class"), [switch]$nocompress, [int]$first=1, [string]$separator="`n") {
	[string []] $rows=@()
	# 'vals:{0}' -f $vals
	if ($vals -ne $null) {
	    if($noclr) { $fmt="{0}"; $cut="..." } else { $fmt="${sc}${cyn}{0}${rc}"; $cut="$sc${blu}...$rc" }
		foreach ($val in $vals) {
			if ($val -is [int] -or $val -is [string] ) {
				[string] $str=$val
			} else {
				$val=ConvertTo-JSON -InputObject $($val | select -first:$first -exclude:$exclude ) -depth:$depth -compress:(!$nocompress)
				[string] $str=$($val -replace '\s+',' ' -replace 'System\.[^ ]+ \(([^)]+)\)','$1' )
			}
			$rows+=@($fmt -f $($str -replace "(?<=.{$max}).+",$cut))
		}
	}
	return $rows -join ($separator)
}

function pval($vals, [int]$max,[switch]$noclr,[string]$separator="`n"){
	[string]$Text=""
	[int]$Cnt=0
	foreach ($Obj in $vals) {
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


function pobj($vals, [int]$max=1000) {
	[hashtable []] $Rows=@()
	# 'vals:{0}' -f $vals
	if ($vals -ne $null) {
		foreach ($val in $vals) {
			[string] $Type='n/a'
			[int] $Count=0
			[string] $Str='N/A'
			if ($val -is [int] -or $val -is [string] ) {
				$Type="int"; $Count=1
				$Str='{0}' -f $val
			} elseif ($val -is [string]) {
				$Type='string'; $Count=1
				$Str='{0}' -f $val
			} elseif($val -is [hashtable]) { 
				$Type='hashtable'
				[string []] $tArr=($val.GetEnumerator()|% {'{0}={1} ' -f $_.name,$(pval $_.value) })
				$Count=$tArr.Count
				$Str='{0}' -f $(parr $tArr -noclr:$noclr)
			} elseif ($val -is [array]) {
				$Type='array'; 
				$Count=$val.Count
				$Str='{0}' -f $(parr $val -noclr:$noclr)
			} elseif ($val -is [scriptblock]) {
				$Type='scriptblock'; $Count=1
				$Str=$val.ToString()
			} elseif ($val -is [object]) {
				$Type='Object'; $Count=1
				$Str=[string] $val
			} else {
				$Type='Other'; $Count=1
				$Str=[string] $val
			}
			$Rows+=@{
			  Type=$Type
			  Count=$Count
			  Length=$Str.Length
			  Cut=$($Str.Length -gt $max)
			  Str=$Str
			}
		}
	}
	return $Rows
}

function pvar($val,[string] $var,[switch] $noclr,[switch] $novar,[string]$scope=1) {
	# pargs
    [string] $str=""
	[int]    $size=0
	[string] $type=""
	$VarInfo=@{}
	if($var) {
		switch -wildcard ($var) { '*:*' { $Scope=$var -replace ':.*',''; $Var=$Var -replace '.*:',''; } } 
		$val=Get-Variable -Name $Var -Scope $Scope -ValueOnly -ErrorAction "SilentlyContinue"
		if (!$?) { 
			$str="N/A" 
		}
		
		# 'scope:{0} var:{1} val:{2}' -f $scope,$var,$val
	}
	
	if ($val -ne $null ) { 
		$VarInfo=(pobj $val)[0]
		<#
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
		#>
	}
	
	if ($novar -or $val -eq $null) {
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
		
		$fmt -f $var, $VarInfo.Type, $(if( $VarInfo.Type -eq 'array'){"$VarInfo.Count"}else{"$VarInfo.Length"} ) , $VarInfo.Cut
		# $VarInfo.Type; $VarInfo.Count ; $VarInfo.Length ; $VarInfo.Cut ; $VarInfo.Str
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

###############################################
# ConvertTo-Expression
function ConvertTo-Expression {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Scope = 'Function')] # https://github.com/PowerShell/PSScriptAnalyzer/issues/1472
    [CmdletBinding()][OutputType([scriptblock])] param(
        [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] $Object,
        [int]$Depth = 9,
        [int]$Expand = $Depth,
        [int]$Indentation = 4,
        [string]$IndentChar = ' ',
        [string]$Delimiter = ';',
        [string]$Assign=' = ',
        [switch]$Strong,
        [switch]$Explore,
        [ValidateSet("Name", "Fullname", "Auto")][string]$TypeNaming = 'Auto',
        [string]$NewLine = [System.Environment]::NewLine,
        [switch]$niceprint
    )
    begin {
        if(!$niceprint) { 
            if (!$PSBoundParameters.ContainsKey('NewLine'))     { $NewLine=' '   }
            if (!$PSBoundParameters.ContainsKey('Indentation')) { $Indentation=0 }
            if (!$PSBoundParameters.ContainsKey('Assign'))      { $Assign='='    }
        }
        $ValidUnqoutedKey = '^[\p{L}\p{Lt}\p{Lm}\p{Lo}_][\p{L}\p{Lt}\p{Lm}\p{Lo}\p{Nd}_]*$'
        $ListItem = $Null
        $Tab = $IndentChar * $Indentation
        function Serialize ($Object, $Iteration, $Indent) {
            function Quote ([string]$Item) { "'$($Item.Replace('''', ''''''))'" }
            function QuoteKey ([string]$Key) { if ($Key -cmatch $ValidUnqoutedKey) { $Key } else { Quote $Key } }
            function Here ([string]$Item) { if ($Item -match '[\r\n]') { "@'$NewLine$Item$NewLine'@$NewLine" } else { Quote $Item } }
            function Stringify ($Object, $Cast = $Type, $Convert) {
                $Casted = $PSBoundParameters.ContainsKey('Cast')
                function GetTypeName($Type) {
                    if ($Type -is [Type]) {
                        if ($TypeNaming -eq 'Fullname') { $Typename = $Type.Fullname }
                        elseif ($TypeNaming -eq 'Name') { $Typename = $Type.Name }
                        else {
                            $Typename = "$Type"
                             if ($Type.Namespace -eq 'System' -or $Type.Namespace -eq 'System.Management.Automation') {
                                if ($Typename.Contains('.')) { $Typename = $Type.Name }
                            }
                        }
                        if ($Type.GetType().GenericTypeArguments) {
                            $TypeArgument = ForEach ($TypeArgument in $Type.GetType().GenericTypeArguments) { GetTypeName $TypeArgument }
                            $Arguments = if ($Expand -ge 0) { $TypeArgument -join ', ' } else { $TypeArgument -join ',' }
                            $Typename = $Typename.GetType().Split(0x60)[0] + '[' + $Arguments + ']'
                        }
                        $Typename
                    } else { $Type }
                }
                function Prefix ($Object, [switch]$Parenthesis) {
                    if ($Convert) { if ($ListItem) { $Object = "($Convert $Object)" } else { $Object = "$Convert $Object" } }
                    if ($Parenthesis) { $Object = "($Object)" }
                    if ($Explore) { if ($Strong) { "[$(GetTypeName $Type)]$Object" } else { $Object } }
                    elseif ($Strong -or $Casted) { if ($Cast) { "[$(GetTypeName $Cast)]$Object" } }
                    else { $Object }
                }
                function Iterate ($Object, [switch]$Strong = $Strong, [switch]$ListItem, [switch]$Level) {
                    if ($Iteration -lt $Depth) { Serialize $Object -Iteration ($Iteration + 1) -Indent ($Indent + 1 - [int][bool]$Level) } else { "'...'" }
                }
                if ($Object -is [string]) { Prefix $Object } else {
                    $List, $Properties = $Null; $Methods = $Object.PSObject.Methods
                    if ($Methods['GetEnumerator'] -is [System.Management.Automation.PsMethod]) {
                        if ($Methods['get_Keys'] -is [System.Management.Automation.PsMethod] -and $Methods['get_Values'] -is [System.Management.Automation.PsMethod]) {
                            $List = [Ordered]@{}; foreach ($Key in $Object.get_Keys()) { $List[(QuoteKey $Key)] = Iterate $Object[$Key] }
                        } else {
                            $Level = @($Object).Count -eq 1 -or ($Null -eq $Indent -and !$Explore -and !$Strong)
                            $StrongItem = $Strong -and $Type.Name -eq 'Object[]'
                            $List = @(foreach ($Item in $Object) {
                                    Iterate $Item -ListItem -Level:$Level -Strong:$StrongItem
                                })
                        }
                    } else {
                        $Properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'Property' }
                        if (!$Properties) { $Properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } }
                        if ($Properties) { $List = [Ordered]@{}; foreach ($Property in $Properties) { $List[(QuoteKey $Property.Name)] = Iterate $Property.Value } }
                    }
                    if ($List -is [array]) {
                        #if (!$Casted -and ($Type.Name -eq 'Object[]' -or "$Type".Contains('.'))) { $Cast = 'array' }
                        if (!$List.Count) { Prefix '@()' }
                        elseif ($List.Count -eq 1) {
                            if ($Strong) { Prefix "$List" }
                            elseif ($ListItem) { "(,$List)" }
                            else { ",$List" }
                        }
                        elseif ($Indent -ge $Expand - 1 -or $Type.GetElementType().IsPrimitive) {
                            $Content = if ($Expand -ge 0) { $List -join ', ' } else { $List -join ',' }
                            Prefix -Parenthesis:($ListItem -or $Strong) $Content
                        }
                        elseif ($Null -eq $Indent -and !$Strong -and !$Convert) { Prefix ($List -join ",$NewLine") }
                        else {
                            $LineFeed = $NewLine + ($Tab * $Indent)
                            $Content = "$LineFeed$Tab" + ($List -join ",$LineFeed$Tab")
                            if ($Convert) { $Content = "($Content)" }
                            if ($ListItem -or $Strong) { Prefix -Parenthesis "$Content$LineFeed" } else { Prefix $Content }
                        }
                    } elseif ($List -is [System.Collections.Specialized.OrderedDictionary]) {
                        if (!$Casted) { if ($Properties) { $Casted = $True; $Cast = 'pscustomobject' } else { $Cast = 'hashtable' } }
                        if (!$List.Count) { Prefix '@{}' }
                        elseif ($Expand -lt 0) { Prefix ('@{' + (@(foreach ($Key in $List.get_Keys()) { "$Key$Assign" + $List[$Key] }) -join "$Delimiter") + '}') }
                        elseif ($List.Count -eq 1 -or $Indent -ge $Expand - 1) {
                            Prefix ('@{' + (@(foreach ($Key in $List.get_Keys()) { "$Key$Assign" + $List[$Key] }) -join "$Delimiter") + '}')
                        } else {
                            $LineFeed = $NewLine + ($Tab * $Indent)
                            Prefix ("@{$LineFeed$Tab" + (@(foreach ($Key in $List.get_Keys()) {
                                            if (($List[$Key])[0] -notmatch '[\S]') { "$Key$Assign" + $List[$Key].TrimEnd() } else { "$Key$Assign" + $List[$Key].TrimEnd() }
                                        }) -join "$Delimiter$LineFeed$Tab") + "$LineFeed}")
                        }
                    }
                    else { Prefix ",$List" }
                }
            }
            if ($Null -eq $Object) { "`$Null" } else {
                $Type = $Object.GetType()
                if ($Object -is [Boolean]) { if ($Object) { Stringify '$True' } else { Stringify '$False' } }
                elseif ('adsi' -as [type] -and $Object -is [adsi]) { Stringify "'$($Object.ADsPath)'" $Type }
                elseif ('Char', 'mailaddress', 'Regex', 'Semver', 'Type', 'Version', 'Uri' -contains $Type.Name) { Stringify "'$($Object)'" $Type }
                elseif ($Type.IsPrimitive) { Stringify "$Object" }
                elseif ($Object -is [string]) { Stringify (Here $Object) }
                elseif ($Object -is [securestring]) { Stringify "'$($Object | ConvertFrom-SecureString)'" -Convert 'ConvertTo-SecureString' }
                elseif ($Object -is [pscredential]) { Stringify $Object.Username, $Object.Password -Convert 'New-Object PSCredential' }
                elseif ($Object -is [datetime]) { Stringify "'$($Object.ToString('o'))'" $Type }
                elseif ($Object -is [Enum]) { if ("$Type".Contains('.')) { Stringify "$(0 + $Object)" } else { Stringify "'$Object'" $Type } }
                elseif ($Object -is [scriptblock]) { if ($Object -match "\#.*?$") { Stringify "{$Object$NewLine}" } else { Stringify "{$Object}" } }
                elseif ($Object -is [RuntimeTypeHandle]) { Stringify "$($Object.Value)" }
                elseif ($Object -is [xml]) {
                    $SW = New-Object System.IO.StringWriter; $XW = New-Object System.Xml.XmlTextWriter $SW
                    $XW.Formatting = if ($Indent -lt $Expand - 1) { 'Indented' } else { 'None' }
                    $XW.Indentation = $Indentation; $XW.IndentChar = $IndentChar; $Object.WriteContentTo($XW); Stringify (Here $SW) $Type }
                elseif ($Object -is [System.Data.DataTable]) { Stringify $Object.Rows }
                elseif ($Type.Name -eq "OrderedDictionary") { Stringify $Object 'ordered' }
                elseif ($Object -is [ValueType]) { try { Stringify "'$($Object)'" $Type } catch [NullReferenceException]{ Stringify '$Null' $Type } }
                else { Stringify $Object }
            }
        }
    }
    process {
		if (!$niceprint) {
			(Serialize $Object).TrimEnd() -replace ('(?s)(`|)\r\n\s*',' ')
		} else {
			(Serialize $Object).TrimEnd()
		}
    }
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
    # "[{0}] {1} arg{2} {3}" -f $MyInvocation.MyCommand, $PSBoundParameters.Count,$(if($PSBoundParameters.Count -ne 1) {"s"}),(($PSBoundParameters.Keys|%{ "-{0}:{1}" -f $_,($PSBoundParameters[$_] -join(","))} ) -join(" "))
	if ($command) {
		if ($Measure) {
			Measure-Command -Expression { & $command @args  | Out-Default }
		} else {
			& $command @args
		}	
	}
}


###############################################
##
## VARIABLES 
##
##############################################

# $env:__SuppressAnsiEscapeSequences - Suppress Ansi Escape Sequences : https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-70?view=powershell-7.2
$e=[char]27; $sc="$e[#p"; $rc="$e[#q"; $nc="$e[m"; $red="$e[1;31m"; $grn="$e[1;32m";  $ylw="$e[1;33m";  $blu="$e[1;34m"; $mgn="$e[1;35m"; $cyn="$e[1;36m"; $gry = "$e[1;30m"
$nl=[char]10; $bold="$e[1m";$bold_off="$e[22m"; $strk = "$e[9m"; $nrml="$e[29m"
$red2="$e[0;31m"; $grn2="$e[0;32m"; $ylw2="$e[0;33m"; $blu2="$e[0;34m";  $mgn2="$e[0;35m";  $cyn2="$e[0;36m"; 
$fmt_var="{0,-15}"
$att_clr=$red; $err_clr=$red; $wrn_clr=$ylw2; $log_clr=$cyn2

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_ansi_terminals?view=powershell-7.2
$rstClr=$PSStyle.Reset; 
$errClr=$PSStyle.Formatting.Error;  $alrClr=$PSStyle.Formatting.ErrorAccent
$wrnClr=$PSStyle.Formatting.Warning; 
$vrbClr=$PSStyle.Formatting.Verbose;
$dbgClr=$PSStyle.Formatting.Debug; 
$hdrClr=$PSStyle.Formatting.TableHeader; $fmtClr=$PSStyle.Formatting.FormatAccent

$FgRed=$PSStyle.Foreground.Red;                 $BrightRed=$PSStyle.Foreground.BrightRed
$FgBlack=$PSStyle.Foreground.Black;             $BrightBlack=$PSStyle.Foreground.BrightBlack
$FgWhite=$PSStyle.Foreground.White;             $BrightWhite=$PSStyle.Foreground.BrightWhite
$FgMagenta=$PSStyle.Foreground.Magenta;         $BrightMagenta=$PSStyle.Foreground.BrightMagenta
$FgBlue=$PSStyle.Foreground.Blue;               $BrightBlue=$PSStyle.Foreground.BrightBlue
$FgCyan=$PSStyle.Foreground.Cyan;               $BrightCyan=$PSStyle.Foreground.BrightCyan
$FgGreen=$PSStyle.Foreground.Green;             $BrightGreen=$PSStyle.Foreground.BrightGreen
$FgYellow=$PSStyle.Foreground.Yellow;           $BrightYellow=$PSStyle.Foreground.BrightYellow

# $Beige=$PSStyle.Foreground.FromRgb(0xf5f5dc); $BgBeige=$PSStyle.Background.FromRgb(0xf5f5dc)

$BgRed=$PSStyle.Background.Red;               $BgBrightRed=$PSStyle.Background.BrightRed
$BgBlack=$PSStyle.Background.Black;           $BgBrightBlack=$PSStyle.Background.BrightBlack
$BgWhite=$PSStyle.Background.White;           $BgBrightWhite=$PSStyle.Background.BrightWhite
$BgMagenta=$PSStyle.Background.Magenta;       $BgBrightMagenta=$PSStyle.Background.BrightMagenta
$BgBlue=$PSStyle.Background.Blue;             $BgBrightBlue=$PSStyle.Background.BrightBlue
$BgCyan=$PSStyle.Background.Cyan;             $BgBrightCyan=$PSStyle.Background.BrightCyan
$BgGreen=$PSStyle.Background.Green;           $BgBrightGreen=$PSStyle.Background.BrightGreen
$BgYellow=$PSStyle.Background.Yellow;         $BgBrightYellow=$PSStyle.Background.BrightYellow

# $Global:Users |? Sid -like 'S-1-5*'| select -Exclude Description, Password*, *Class, AccountExpires | ft


<#
###############################################
# Get-EventLogs
function Get-EventLogs () {
	param([string[]] $LogName='*',[int] $Seconds=$(24*3600))
    $Global:EVENT_LOGS=get-winevent -listlog $LogName -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddSeconds(-$Seconds))}
	return 
}

###############################################
# Get-XmlEvent 
function Get-XmlEvent {
    Param( [string[]] $LogName, [string[]] $ProviderName, [int[]]$Levels, [int[]]$EventIDs, [int[]] $RecIds, [int[]]$ExceptEventIDs, [string[]]$ExceptProviders,
	[int]$MaxEvents=2000, [int]$Hours=0, [int]$Minutes=0, [int]$Seconds=0, [int]$ShowEvents=3 )
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
#>


###############################################
##
## BUSINESS FUNCTIONS
##
##############################################


###############################################
##
## MyWinEvents Implementation       
##
##############################################

####################################################
# Get-MyWinEvents
function Get-MyWinEvents( $Logs, $Providers, $Paths, $IDs, $Levels, $UIDs, $Data, 
     [int]$Days, [int]$Hours, [int]$Minutes, [int]$Seconds, 
	 [int]$EndDays, [int]$EndHours, [int]$EndMinutes, [int]$EndSeconds, 
	 $Pids, $Msgs, $RecIds, $ExclLogs, $ExclProviders, $ExclPids, $ExclRecIds, $ExclMsgs,
	 $MaxEvents, $Top,
	 $Cols, $ExclCols,
	 [switch]$UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw ) {

<#
    if ($Global:EVENTS_COUNT -gt 0 -and !$UpdateCache) { 
		$PsBoundParameters['UseCache']=$true 
		"$sc$gry[$cyn{0}$gry] $grn-UpdateCache$gry is not set and $grn{1}$gry is $ylw{2}$gry. Turning on $att_clr-UseCache $rc" -f  $MyInvocation.MyCommand, 
		     '$Global:EVENTS_COUNT',$Global:EVENTS_COUNT | Out-Host
	}
#>

	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $myscript, $(&{$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks  | Out-Host
	
	$start_tm = Get-Date
	"$sc$blu[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$blu]$gry called on ${ylw}{3}${blu}:$cyn{4}$gry at $ylw{5}$gry | $ylw{6}$blu[$ylw{7}$blu]${gry}: $ylw{8}$gry. $rc" -f $MyInvocation.MyCommand.Name, 
		$myscript,$(&{$MyInvocation.ScriptLineNumber}),$myscript,$MyInvocation.ScriptLineNumber, $start_tm, 
	   '$PsBoundParameters',$(@($PsBoundParameters.Keys).Count),$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) | Out-Host

     # =@("ProcessId","ThreadId","UserId","MsgNo","TimeCreated","Lvl","Id","ProviderName","OpcodeDisplayName","KeywordsDisplayNames","Message")	 
	 # "Id","Level","Task","Opcode","Keywords","RecordId","ProviderId","LogName","ProcessId","ThreadId","UserId","TimeCreated","LevelDisplayName","OpcodeDisplayName","TaskDisplayName"
# https://docs.microsoft.com/en-us/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable?view=powershell-7.2


	# Command Paramters  for -h : $MyInvocation.MyCommand.ParameterSets[0].ToString() 
	# $CmdScriptEval=$ExecutionContext.InvokeCommand.ExpandString($Global:ReadEventsCmd)
	# $Global:WhereScript={ 1 -eq 1 -and $_.ProcessId -match "13932|23392|16512|4416"  }
	# $Global:WhereScript={ 1 -eq 1 -and $_.$_.LogName   -notmatch "*Core" }
	# $script:MsgNo=0; Get-WinEvent -FilterHash $Global:FilterHash -Max 10000 | Where-Object $Global:WhereScript | Sort-Object -Descending TimeCreated,RecordId -Top 50 | Select -Property $ColsDefault | ft *
    # $script:MsgNo=0; $Global:MyEvents[0..10]| Where-Object $Global:WhereScript | Sort-Object -Descending TimeCreated,RecordId -Top 50 | Select -Property $ColsDefault | ft *

	Get-WinEvents @PsBoundParameters
	Print-MyWinEvents @PsBoundParameters


	$duration=[int]($(Get-Date)-$start_tm).TotalMilliseconds
	if ($duration -gt 9000) {
		$duration="$att_clr$duration"
	} elseif ($duration -gt 1000) {
		$duration="$ylw$duration"
	}

	"$sc$ylw[$cyn{0}$gry() ${ylw}{1}${blu}:$cyn{2}$ylw] $grn{3}${gry} ms, $cyn DONE at $ylw{4} $grn{5}$ylw[$att_clr{6}$ylw]$gry, $grn{7}$ylw[$att_clr{8}$ylw]$gry.$rc" -f  $MyInvocation.MyCommand, 
	   $myscript, $(&{$MyInvocation.ScriptLineNumber}), $duration, $(Get-Date),
	   '$Global:EVENTS', $Global:EVENTS_COUNT, '$Global:EVENTS_OUT', $Global:EVENTS_OUT_COUNT |  Out-Host
	 "$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$strk ${ylw}Finished$nrml $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $myscript, $(&{$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
}

#########################################
# Get-WinEvents
function Get-WinEvents($Logs=@('*'), $Providers, $Paths, $IDs, $Levels=@(1,2,3), $UIDs, $Data, 
	[int]$Days, [int]$Hours=2, [int]$Minutes, [int]$Seconds, 
	[int]$EndDays, [int]$EndHours, [int]$EndMinutes, [int]$EndSeconds, 
	$Pids, $Msgs, $RecIds, $ExclLogs, $ExclProviders, $ExclPids, $ExclRecIds, $ExclMsgs,
	$MaxEvents=50000,
	[switch]$xml,[switch]$UseCache,[switch]$UpdateCache) {
	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
	$start_tm = Get-Date
	"$sc$blu[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$blu]$gry called on ${ylw}{3}${blu}:$cyn{4}$gry at $ylw{5}$gry | $ylw{6}$blu[$ylw{7}$blu]${gry}: $ylw{8}$gry. $rc" -f $MyInvocation.MyCommand, 
	    $myscript, $(& {$MyInvocation.ScriptLineNumber}),
	    $myscript, $MyInvocation.ScriptLineNumber, $start_tm, 
	   '$PsBoundParameters',$(@($PsBoundParameters.Keys).Count),$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) | Out-Host

	$Global:MaxEvents=$MaxEvents 
	
	$Seconds+=($Days*24+$Hours)*3600+$Minutes*60
	$EndSeconds+=($EndDays*24+$EndHours)*3600+$EndMinutes*60

    if ($xml) {
		$Global:EVENTS_PARAM_CMD={
			$Global:XmlSystemParams=""
			if ($Seconds)        { $Global:XmlSystemParams+="TimeCreated[timediff(@SystemTime)<=$($Seconds*1000)]"}
			if ($EventIDs.Count) { $Global:XmlSystemParams+=" and ( EventID="+$($RecIds -join ' or EventIDs=') +" ) " }
			if ($RecIds.Count)   { $Global:XmlSystemParams+=" and ( EventRecordID="+$($RecIds -join ' or EventRecordID=') +" ) "  }
			if ($Levels.Count)   { $Global:XmlSystemParams+=" and ( Level="+$($Levels -join ' or Level=') +" ) " }	
			$Global:FilterXml="*[System[$Global:XmlSystemParams]]"
			"$sc[$cyn`$Global:FilterXml$gry] $ylw{1}$gry.$rc"  -f  $($Global:FilterHash -join('; ')) | Out-Host
			$Global:EVENTS_PARAM=@{ FilterXml=$Global:FilterXml; MaxEvents=$Global:MaxEvents; ErrorAction="SilentlyContinue" }
            "$sc[$cyn{0}$gry] $ylw{1}$gry.$rc" -f '$Global:EVENTS_PARAM',$('@{ ' + $(($Global:EVENTS_PARAM.GetEnumerator() | % { "$($_.Name)='$($_.Value)'" } ) -join('; '))+' }') | Out-Host
		}
	} else  {
		$Global:EVENTS_PARAM_CMD={
			$Global:FilterHash=@{} + 
				$( if ( $Logs       ) { @{ LogName=$Logs                                   } } else { @{} } ) +
				$( if ( $Providers  ) { @{ ProviderName=$Providers                         } } else { @{} } ) +
				$( if ( $Paths      ) { @{ Path=$Paths                                     } } else { @{} } ) +
				$( if ( $IDs        ) { @{ ID=$IDs                                         } } else { @{} } ) +
				$( if ( $Keywords   ) { @{ Keywords=$Keywords                              } } else { @{} } ) +
				$( if ( $Levels     ) { @{ Level=$Levels                                   } } else { @{} } ) +
				$( if ( $UIDs       ) { @{ UserID=$UIDs                                    } } else { @{} } ) +
				$( if ( $Data       ) { @{ Data=$Data                                      } } else { @{} } ) +
				$( if ( $Seconds    ) { @{ StartTime=(Get-Date).AddSeconds(-$Seconds)      } } else { @{} } ) +
				$( if ( $EndSeconds ) { @{ EndTime=(Get-Date).AddSeconds(-$EndSeconds)     } } else { @{} } ) ;
			"$sc[$grn{0}$gry] $ylw{1}$gry.$rc" -f '$Global:FilterHash',  $('@{ ' + $(($Global:FilterHash.GetEnumerator()   | % { "$($_.Name)='$($_.Value)'" } ) -join('; '))+' }') | Out-Host
			$Global:EVENTS_PARAM=@{ FilterHashtable=$Global:FilterHash; MaxEvents=$Global:MaxEvents; ErrorAction="SilentlyContinue" }
            "$sc[$grn{0}$gry] $ylw{1}$gry.$rc" -f '$Global:EVENTS_PARAM',$('@{ ' + $(($Global:EVENTS_PARAM.GetEnumerator() | % { "$($_.Name)='$($_.Value)'" } ) -join('; '))+' }') | Out-Host
		}
		# $($tht.GetEnumerator() | % { "$($_.Name)='$($_.Value)'" } ) -join(';') -replace("='System.[^']+'","=<..>")
	}
	
	$Global:EVENTS_WHERE_CMD={
		$CondArr=@()
		$CondArr+= `
			$( if( $Pids          ) { @( '$_.ProcessId -match "{0}"'       -f $($Pids          -join('|')) ) } else { @() } ) +
			$( if( $RecIds        ) { @( '$_.RecordId -match "{0}"'        -f $($RecIds        -join('|')) ) } else { @() } ) +
			$( if( $Msgs          ) { @( '$_.Message -match "{0}"'         -f $($Msgs          -join('|')) ) } else { @() } ) +
			$( if( $ExclLogs      ) { @( '$_.LogName -notmatch "{0}"'      -f $($ExclLogs      -join('|')) ) } else { @() } ) +
			$( if( $ExclPids      ) { @( '$_.ProcessId -notmatch "{0}"'    -f $($ExclPids      -join('|')) ) } else { @() } ) +
			$( if( $ExclRecIds    ) { @( '$_.RecordId -notmatch "{0}"'     -f $($ExclRecIds    -join('|')) ) } else { @() } ) +
			$( if( $ExclProviders ) { @( '$_.ProviderName -notmatch "{0}"' -f $($ExclProviders -join('|')) ) } else { @() } ) +
			$( if( $ExclMsgs      ) { @( '$_.Message -notmatch "{0}"'      -f $($ExclMsgs      -join('|')) ) } else { @() } ) ;
		if(!$CondArr) { $CondArr=@('1 -eq 1') }
		$Global:EVENTS_WHERE=$([ScriptBlock]::Create( $($CondArr -join(' -and '))))
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$gry[$grn{3}$gry] $ylw{4}$gry.$rc" -f  @(Get-PSCallStack)[1].InvocationInfo.MyCommand.Name, 
		   $myscript, $MyInvocation.ScriptLineNumber,"`$Global:EVENTS_WHERE$blu[$ylw$($CondArr.Count)$blu]", $Global:EVENTS_WHERE.ToString() | Out-Host
    }

	$Global:EVENTS_LOADER={ $Global:MsgNo=1; $Global:EVENTS=Get-WinEvent @Global:EVENTS_PARAM | Select @{n='MsgNo';e={($Global:MsgNo++)}},*| Where-Object $Global:EVENTS_WHERE; $Global:EVENTS_COUNT=$Global:EVENTS.Count}
	
		
	$PREV_EVENTS_WHERE=$Global:EVENTS_WHERE
	$PREV_EVENTS_PARAM=$Global:EVENTS_PARAM

	& $Global:EVENTS_PARAM_CMD
	& $Global:EVENTS_WHERE_CMD

	if ($UpdateCache) {
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr -UpdateCache$gry is set, forced use loader.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$true
	} elseif ($UseCache) { 
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr -UseCache$gry is set, will not use loader$gry.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$false
	} elseif ($PREV_EVENTS_WHERE -eq $Global:EVENTS_WHERE) { 
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr $Global:EVENTS_WHERE is same$gry, will not use  loader$gry.$rc" -f $MyInvocation.MyCommand.Name, 
			$myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$false
	} elseif ($PREV_EVENTS_PARAM -eq $Global:EVENTS_PARAM) { 
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr $Global:EVENTS_PARAM is same$gry, will not use  loader$gry.$rc" -f $MyInvocation.MyCommand.Name, 
			$myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$false
	} else {
		'$UpdateCache              : {0}' -f $UpdateCache
		'$UseCache                 : {0}' -f $UseCacheUseCache
		'$PREV_EVENTS_WHERE        : {0}' -f $PREV_EVENTS_WHERE
		'$PREV_EVENTS_PARAM        : {0}' -f $PREV_EVENTS_PARAM
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$gry calling$att_clr {3}$gry {4}.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}),
			'$Global:EVENTS_LOADER',$Global:EVENTS_LOADER | Out-Host
		$do_load=$true
	}
	
	######################
	# $do_load=$false
	######################
	
	if ($do_load) {
		& $Global:EVENTS_LOADER
	} else {
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr skipping loader$gry.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
	}

	$duration=[int]($(Get-Date)-$start_tm).TotalMilliseconds
	if ($duration -gt 9000) {
		$duration="$att_clr$duration"
	} elseif ($duration -gt 1000) {
		$duration="$ylw$duration"
	}

	"$sc$ylw[$cyn{0}$gry() ${ylw}{1}${blu}:$cyn{2}$ylw] $grn{3}${gry} ms,$cyn DONE at $ylw{4} $grn{5}$ylw[$att_clr{6}$ylw]$gry.$rc" -f  $MyInvocation.MyCommand, 
	   $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), $duration, $(Get-Date),
	   '$Global:EVENTS', $Global:EVENTS_COUNT |  Out-Host
	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$strk ${ylw}Finished$nrml $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
}

#########################################
# Print-MyWinEvents
function Print-MyWinEvents( $Logs, $Providers, $Paths, $IDs, $Levels, $UIDs, $Data, 
     [int]$Days, [int]$Hours, [int]$Minutes, [int]$Seconds, 
	 [int]$EndDays, [int]$EndHours, [int]$EndMinutes, [int]$EndSeconds, 
	 $Pids, $Msgs, $RecIds, $ExclLogs, $ExclProviders=@("PowerShell"), $ExclPids, $ExclRecIds, $ExclMsgs,
	 $MaxEvents=20000, $Top=40, $Cols, 
	 $ExclCols=@("Message","RelatedActivityId","MatchedQueryIds","ContainerLog","ActivityId","Bookmark","MachineName","Properties","Version","Qualifiers","Keywords","ProviderId"),
    [switch]$List, [switch]$Table, [switch]$Raw, [switch]$UseCache,[switch]$UpdateCache
	) {
	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $myscript, $(& {$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
	$start_tm = Get-Date
	"$sc$blu[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$blu]$gry called on ${ylw}{3}${blu}:$cyn{4}$gry at $ylw{5}$gry | $ylw{6}$blu[$ylw{7}$blu]${gry}: $ylw{8}$gry. $rc" -f $MyInvocation.MyCommand, 
	    $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}),
	    $myscript, $MyInvocation.ScriptLineNumber, $start_tm, 
	   '$PsBoundParameters',$(@($PsBoundParameters.Keys).Count),$( if($(@($PsBoundParameters.Keys).Count)){ '@{ '+$(($PsBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) | Out-Host	
	
	if ( !$PSBoundParameters.ContainsKey('UpdateCache') -and !$PSBoundParameters.ContainsKey('List') -and !$PSBoundParameters.ContainsKey('Table')  ) {
		$Table=$true;
		$Top=5
		"$sc$blu[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$blu]$gry Setting defaults -Table -Top:5 $gry. $rc" -f 
			$MyInvocation.MyCommand, $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber})
	}
	
	$Global:MaxEvents=$MaxEvents
	if(!$Cols) {
		if ( $Raw ) { 
			$Cols=@("*")
		} else { 
			$Cols=$Global:EVENTS_OUT_COLS
		}
	}
	if (!$ExclCols) {
		if($Table) { $ExclCols=$Global:EVENTS_EXCL_OUT_COLS} else { $ExclCols=@("Properties") }
	}
	
	$Global:EVENTS_COUNT=$Global:EVENTS.Count
	if ($Top -gt $Global:EVENTS_COUNT) { $Top=$Global:EVENTS_COUNT }
	$Global:EVENTS_SELECT_PARAM_CMD={
		$Global:EVENTS_SELECT_PARAM=@{} + 
			$( if ( $Cols       ) { @{ Property=$Cols     } } else { @{} } ) +
			$( if ( $ExclCols   ) { @{ Exclude=$ExclCols  } } else { @{} } ) +
			$( if ( $Top        ) { @{ First=$Top         } } else { @{} } ) ;		   
	}
	$ScriptStr='$Global:EVENTS_OUT=$Global:EVENTS | Select-Object -First {0} | Where-Object $Global:EVENTS_WHERE | Select @Global:EVENTS_SELECT_PARAM' -f $MaxEvents
	$Global:EVENTS_OUT_LOADER=[scriptblock]::Create($ScriptStr)

	$PRV_PARAM=$Global:EVENTS_SELECT_PARAM
	$PRV_PARAM_STR=ConvertTo-Json $Global:EVENTS_SELECT_PARAM -compress
	
	$PRV_WHERE=$Global:EVENTS_OUT_WHERE.ToString()
	# $PRV_WHERE={echo 1}
	
	& $Global:EVENTS_WHERE_CMD
	& $Global:EVENTS_SELECT_PARAM_CMD	
	if (!$Global:EVENTS_SELECT_PARAM) {$Global:EVENTS_SELECT_PARAM=@{First=1}}
	
	$NEW_PARAM=$Global:EVENTS_SELECT_PARAM
	$NEW_PARAM_STR=ConvertTo-Json $Global:EVENTS_SELECT_PARAM -compress
	
	$NEW_WHERE=$Global:EVENTS_OUT_WHERE.ToString()
	
	$do_load=$false
	if ($UpdateCache) {
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr -UpdateCache$gry is set$gry, must use loader.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$true
	} elseif ($UseCache) { 
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr -UseCache$gry is set, will not use loader$gry.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		$do_load=$false
	} else {
		if ($NEW_PARAM_STR -ne $NEW_PARAM_STR) { 
			"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr {3}$gry, will use loader$gry.$rc" -f $MyInvocation.MyCommand.Name, 
				$myscript, $(& {$MyInvocation.ScriptLineNumber}),'$Global:EVENTS_SELECT_PARAM is changed' | Out-Host
			$do_load=$true
		}
		if ($PRV_WHERE -ne $NEW_WHERE) { 
			"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr {3}$gry, will use loader$gry.$rc" -f $MyInvocation.MyCommand.Name, 
				$myscript, $(& {$MyInvocation.ScriptLineNumber}),'$Global:EVENTS_WHERE is changed' | Out-Host
			$do_load=$true
		} 
	}
	' ------------------------------------- '
	'{0,40} : {1}'       -f '$do_load',$do_load
	'{0,40} : {1}'       -f '$UpdateCache',$UpdateCache
	'{0,40} : {1}'       -f '$UseCache',$UseCache
	'{0,40} : {1}'       -f '($PRV_WHERE -ne $NEW_WHERE)',$($PRV_WHERE -ne $NEW_WHERE)
	'{0,40} : {1}'       -f '$PRV_WHERE',$PRV_WHERE
	'{0,40} : {1}'       -f '$NEW_WHERE',$NEW_WHERE
	'{0,40} : {1}'       -f '($NEW_PARAM_STR -ne $NEW_PARAM_STR)',$($NEW_PARAM_STR -ne $NEW_PARAM_STR)
	'{0,40} : {1}'       -f '$PRV_PARAM_STR',$PRV_PARAM_STR
	'{0,40} : {1}'       -f '$NEW_PARAM_STR',$NEW_PARAM_STR
#	'{0,40} : {1} {2}'   -f '$PRV_PARAM',$(@($PRV_PARAM.Keys).Count),$( if($(@($PRV_PARAM.Keys).Count)){ '@{ '+$(($PRV_PARAM.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) 
#	'{0,40} : {1} {2}'   -f '$NEW_PARAM',$(@($NEW_PARAM.Keys).Count),$( if($(@($NEW_PARAM.Keys).Count)){ '@{ '+$(($NEW_PARAM.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" } ) -join('; '))+ '} '}) 
	' ------------------------------------- '

	"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$gry loader$ylw {3}${gry}: {4}$ylw {5}${gry}: {6}${gry}.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}),
		'$Global:EVENTS_OUT_LOADER', $Global:EVENTS_OUT_LOADER,'$do_load',$do_load | Out-Host
	if ($do_load) {
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr do load$gry$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
		& $Global:EVENTS_OUT_LOADER
		$Global:EVENTS_OUT_WHERE=$Global:EVENTS_WHERE
	} else {
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr skipping loader$gry.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
	}

	$Global:EVENTS_HELPERS_CMD={
			'Helpers:'
			' $Global:EVENTS_OUT[0]   | fl * '
			' $Global:EVENTS_OUT      | Select -first {0} $Global:EVENTS_OUT_COLS | ft -auto * # $Global:EVENTS_EXCL_OUT_COLS' -f $Top
			' $Global:EVENTS[{0}]       | fl * ' -f $Global:EVENTS_OUT[0].MsgNo  
	}

	if ($Top -gt $EVENTS_OUT_COUNT) { $Top=$Global:EVENTS_OUT_COUNT }
	
	if($Table) {
		$cmd={$Global:EVENTS_OUT | select -First $Top | Format-Table -auto *}
	} elseif ($List) {
		$cmd={$Global:EVENTS_OUT | select -First $Top | Format-List *}
	} else {
		$cmd={}
	}
	if ($cmd.ToString().Length) {
		"$sc$blu[$ylw{0}$blu]$gry[$att_clr{1}$gry] $ylw{2}$gry=$grn{3}$gry | {4}({5}) $ylw{6}$gry.$rc" -f $MyInvocation.MyCommand, 'Display',
			'$Top', $Top, '$cmd', $(($cmd.ToString()).Length), $cmd.ToString() | Out-Host

		& $cmd
	} else {
		"$sc$gry[$cyn{0}$gry]$att_clr nothing to print$gry at $ylw{1}$gry. Neither $grn-Table$gry nor $grn-List$gry are set $rc" -f  $MyInvocation.MyCommand,$(Get-Date)
	}
	$Global:EVENTS_OUT_COUNT=$Global:EVENTS_OUT.Count
	if ($Global:EVENTS_OUT_COUNT) {
		& $Global:EVENTS_HELPERS_CMD | Out-Host
	}
#  $Global:EVENTS_OUT_COUNT,$( if($Global:EVENTS_OUT_COUNT -ne 1){'WinEvents are'}else{'WinEvent is'} ),'$Global:EVENTS_OUT' | Out-Host
	$duration=[int]($(Get-Date)-$start_tm).TotalMilliseconds
	if ($duration -gt 9000) {
		$duration="$att_clr$duration"
	} elseif ($duration -gt 1000) {
		$duration="$ylw$duration"
	}
	"$sc$ylw[$cyn{0}$gry() ${ylw}{1}${blu}:$cyn{2}$ylw] $grn{3}${gry} ms,$cyn DONE at $ylw{4} $grn{5}$ylw[$att_clr{6}$ylw]$gry.$rc" -f  $MyInvocation.MyCommand, 
	   $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), $duration, $(Get-Date),
	   '$Global:EVENTS_OUT', $Global:EVENTS_OUT_COUNT |  Out-Host
	"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$strk ${ylw}Finished$nrml $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f $MyInvocation.MyCommand, $(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
	   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
}


###############################################
##
## End Of MyWinEvents       
##
##############################################



###############################################
##
## Other Functions
##
##############################################


###############################################
# Group-WinEvents
function Group-WinEvents () {
	param(  [int]      $MaxEvents, 
	        [string[]] $LogName='*', 
			[string[]] $ProviderName, 
			[int[]]    $Levels, 
			[int[]]    $EventIDs,
		    [int]      $Days=1, [int] $Hours, [int] $Minutes, [int] $Seconds,
			[switch]   $UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw,
            $Logs, $Pids, $RecIds, $Msgs, $ExclLogs=@('PowerShellCore'),
			$ExclPids, $ExclRecIds, $ExclMsgs,
			[int[]]    $Groups, 
			[int[]]    $Messages,
			[object[]] $FilterGroupPid,
			[switch]   $NoTable,
			[switch]   $Warnings,
			[switch]   $Errors,
			[switch]   $ByMsg,
			[switch]   $AllGroups,
			[switch]   $AllMessages,
			[int]      $Top=65, $Cols )

	pargs
	
<#	
	# 'Grouping {0} events into $Global:EVENT_GROUPS ...' -f $Global:EVENTS.Length
	
	$TotEvents=$Global:EVENTS.Count
# 	$Params = @{  Property = $GroupCols }
	pargs 'Output:$Global:EVENT_GROUPS' -Vars:TotEvents,GroupCols
	pargs 'GroupCols' -Vals:$GroupCols
	$FilterArr=@()
	# if ($ExclLogs) { $FilterArr+=@('$ExclLogs -notcontains $_.Log') }
	if ($Msgs)   { $FilterArr+=@('$_.Message -like $Msgs') }
	if ($Pids)   { $FilterArr+=@( '($_.ProcessID -eq {0})' -f $($Pids -join (' -or $_.ProcessID -eq ')) ) }
	
	if ($FilterArr.Length) { 
		$FilterStr='( {0} )' -f $($FilterArr -join (') -and ('))
		pargs -Vars:FilterStr,FilterArr
	} else {
		$FilterStr='1 -eq 1'
	}
	$FilterBlock=[scriptblock]::Create( $FilterStr )
#>	


	
	
<#
		*, # @{n='MsgNo';e={($script:MsgNo++)}},
		    @{n='Log';e={$_.LogName -replace '/.*$','' -replace '(Microsoft-Windows-|Microsoft-Client-|-Admin)','' -replace "PowerShell","PS" }},
			@{n='Lvl';e={'{0}({1})' -f $(Switch ($_.Level) { 0 {"ALW"}; 1 {"CRT"}; 2 {"ERR"}; 3 {"WRN"}; 4 {"INF"}; 5 {"VRB"}; default {"OTH"}}),$_.Level } },
			@{n='User';e={$Sid=$_.UserId; '{0}' -f $(Switch ($Sid) { 'S-1-5-18' {"LocalSystem"}; 'S-1-5-20' {"NT Authority"}; default {  $($Global:Users |? Sid -like $Sid).Name }; }) }},
			@{n='LogType';e={$(
			        $(switch -wildcard ($_.LogName){ 'Microsoft-Windows-*' {'MS-Win'}; 'Microsoft-Client-*' {'MS-Client'}; 'PowerShell*' {'PS'};}),
					$(if($_.LogName -like '*-Admin'){'Admin'}),
			        $(if($_.LogName -like '*/*'){$_.LogName -replace '^.*/','' -replace 'Operational','Oper'}) -ne ''  ) -join(',')}},
			@{n='Provider';e={$_.ProviderName -replace $($_.LogName `
			    -replace '/.*$','' `
			    -replace 'Known Folders.*','KnownFolders' `
				-replace 'PushNotification','PushNotifications' `
				-replace 'AppXDeploymentServer','AppXDeployment-Server' `
				-replace 'Storage-Storport','StorPort' `
				-replace '(-Events|-Admin)','' `
				),"*" -replace '(Microsoft-Windows-|Windows-)',''}},
			@{n='Message2';e={($_.Message,$(($_.Properties | select -first 3 *).Value -join '; ') -join '; ') -replace "^This is the first instance.*$",'' -replace "[`n`r]+",' ' -replace '\s+',' ' -replace '(?<=.{380}).+' }} 
#>            
	
	
	$Global:MaxGroups=$MaxEvents
	if(!$Cols) {
		if ( $Raw ) { 
			$Cols=@("*")+@(@{N='Original_Message';E={$_.message.Substring(500)}})
		} else { 
			$Cols=$Global:EVENTS_OUT_COLS +@(@{N='Original_Message';E={$_.message}})
		}
	}
	<#
	if (!$ExclCols) {
		if($Table) { $ExclCols=$Global:EVENTS_EXCL_OUT_COLS} else { $ExclCols=@("Properties") }
	}
	#>
	
	if ($ByMsg)       {
		$Global:EventGroupsCols=@("Log","LogType","Message2")
	} else { 
		$Global:EventGroupsCols=@("Log","LogType","Lvl","Id","Provider","User")
	}
	
	$Global:EVENTS_COUNT=$Global:EVENTS.Count
	if ($Top -gt $Global:EVENTS_COUNT) { $Top=$Global:EVENTS_COUNT }
	$Global:EVENT_GROUPS_SELECT_PARAM_CMD={
		$Global:EVENT_GROUPS_SELECT_PARAM=@{} + 
			$( if ( $Cols       ) { @{ Property=$Cols     } } else { @{} } ) +
			$( if ( $ExclCols   ) { @{ Exclude=$ExclCols  } } else { @{} } ) +
			$( if ( $Top        ) { @{ First=$Top         } } else { @{} } ) ;		   
	}
    'ExclLogs: {0}' -f $($ExclLogs -join('. '))
	& $Global:EVENTS_WHERE_CMD
	& $Global:EVENT_GROUPS_SELECT_PARAM_CMD	
	if (!$Global:EVENT_GROUPS_SELECT_PARAM) { $Global:EVENT_GROUPS_SELECT_PARAM=@{First=1} }
	
	$ScriptStr='$Global:EVENT_GROUPS=$Global:EVENTS |Where-Object $Global:EVENTS_WHERE | Select-Object @Global:EVENT_GROUPS_SELECT_PARAM |Group-Object $Global:EventGroupsCols| Select $Global:EVENT_GROUPS_COLS' 

	$do_regroup=$false
	if ($UpdateCache) {
		$do_regroup=$true
		pargs $('$UpdateCache is $true >>> $do_regroup=$true')
	} elseif ($UseCache) {
		$do_regroup=$false
		pargs $('$UseCache is $true >>> $do_regroup=$false')
	} elseif (!$Global:EVENTS_REGROUP_COMMAND) { 
		$do_regroup=$true
		pargs $('$Global:EVENTS_REGROUP_COMMAND is not set >>> $do_regroup=$true')
    } else {
		$NEW_COMMAND='$Global:EVENT_GROUPS=$Global:EVENTS| Select-Object {0}|Where-Object {1} |Group-Object {2}| Select {3}' -f $(ConvertTo-Expression $Global:EVENT_GROUPS_SELECT_PARAM),
		    $(ConvertTo-Expression $Global:EVENTS_WHERE),$(ConvertTo-Expression $Global:EventGroupsCols),$(ConvertTo-Expression $Global:EVENT_GROUPS_COLS)
		if ($Global:EVENTS_REGROUP_COMMAND -eq $NEW_COMMAND)  { 
			$do_regroup=$false 
			pargs $('$Global:EVENTS_REGROUP_COMMAND is the same  >>> $do_regroup=$false')
			pargs $('$Global:EVENTS_REGROUP_COMMAND: {0}' -f $Global:EVENTS_REGROUP_COMMAND)
		} else { 
			pargs $('$Global:EVENTS_REGROUP_COMMAND is different >>> $do_regroup=$true')
			$do_regroup=$true 
		}
	}
	
	if ($do_regroup) {
		$Global:EVENTS_REGROUP_COMMAND='$Global:EVENT_GROUPS=$Global:EVENTS | Where-Object {0} | Select-Object {1} | Group-Object {2} | Select {3}' -f $(ConvertTo-Expression $Global:EVENTS_WHERE),
		    $(ConvertTo-Expression $Global:EVENT_GROUPS_SELECT_PARAM),
		    $(ConvertTo-Expression $Global:EventGroupsCols),$(ConvertTo-Expression $Global:EVENT_GROUPS_COLS)
	    "$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr regrouping${gry}: {3}$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}), $Global:EVENTS_REGROUP_COMMAND | Out-Host
		& $Global:EVENTS_REGROUP_LOADER
		# $Global:EVENTS_REGROUP_COMMAND=$ExecutionContext.InvokeCommand.ExpandString($Global:EVENTS_REGROUP_LOADER -replace '\$Global:EVENTS','`$Global:EVENTS')
	} else 
		"$sc$ylw[$cyn{0} ${ylw}{1}${blu}:$cyn{2}$ylw]$att_clr skipping regrouping$gry.$rc" -f $MyInvocation.MyCommand.Name, $myscript, $(& {$MyInvocation.ScriptLineNumber}) | Out-Host
	}
		
	if ($Global:EVENT_GROUPS_COUNT) {  
		pargs $('{0} events are mapped into {1} group{2} of $Global:EVENT_GROUPS' -f $Global:EVENTS.Length, $Global:EVENT_GROUPS.Length,$(if($Global:EVENT_GROUPS.Length -ne 1) {'s'}))
	} else {
		pargs $('Error: {0} events are not mapped into any groups' -f $Global:EVENTS.Length)
	}
	return
}

##########################################
# Print-EventGroupsTable
function Print-EventGroupsTable ([int]$First=1, [int]$Skip=1, [int]$Top=30 ) {
	pargs
	# 'Grouping {0} events into $Global:EVENT_GROUPS ...' -f $Global:EVENTS.Length
	$TotEvents=$Global:EVENTS.Length
	
	if ($Global:EVENT_GROUPS.Length -le 0)  { 
		pargs 'Warning: $Global:EVENT_GROUPS array is empty'
		return 
	}
	if ( $Skip -le $Global:EVENT_GROUPS.Length ) {
		
		pargs $('Printing {0} of {1} groups starting from {2}' -f $First, $Global:EVENT_GROUPS.Length,$Skip)
		$Skip--


#		Sort-Object -stable -descending Count  |
#        Sort-Object -descending Count,@{e={$(-$_.Group[0].MsgNo)}}  | 		
	# $PREV_EVENTS_PARAM=$Global:EVENTS_PARAM	
#	& $Global:EVENTS_PARAM_CMD
	
		& $Global:EVENTS_WHERE_CMD
		
		$Global:EVENT_GROUPS_PRINT={ 
			$Global:Result=$Global:EVENT_GROUPS | Select-Object -First $Top -Property $Global:EVENT_GROUPS_OUT_COLS -ExcludeProperty $Global:EVENT_GROUPS_EXCL_COLS 
		$Global:Result| ft -auto * }
		
		& $Global:EVENT_GROUPS_PRINT
		'{0} of {1} $Global:EVENT_GROUPS object{2} filtered into $Global:Result' -f $Global:Result.Count,$Global:EVENT_GROUPS.Count,$( if($Global:Result.Count -ne 1){'s'} )
		'Top {0} of {1} $Global:Result object{2} printed into the above table' -f $Top,$Global:Result.Count,$( if($Top -ne 1){'s'} )
		
		$GrpIdx=$($Global:Result[0].Grp-1)
		$MsgIdx=$($Global:EVENT_GROUPS[$GrpIdx].Group[0].MsgNo-1)
		'Helpers:'
		'& $Global:EVENT_GROUPS_PRINT'
		'$Global:Result[0] | fl * '
		'$Global:EVENT_GROUPS[{0}] | ft; $Global:EVENTS[{1}] | fl * ' -f $GrpIdx,  $MsgIdx
		''
		
	} else {
		pargs $('Error: Group Number {0} must be smaller than total amount of groups {1}' -f $Skip, $Global:EVENT_GROUPS.Length)
	}
}


##########################################
# Print-TableMessages
function Print-TableMessages ([int[]] $Groups, [string[]] $ExclLogs, [string] $Msgs, [int[]] $Pids ) {
	pargs
	if (!$Groups) {$Groups=1..$Global:EVENT_GROUPS.Count}
	$TotGroupedEvents=$Global:EVENT_GROUPS.Length
	$TotEvents=$Global:EVENTS.Length
	$TotGroups=$Groups.Length
	$No=0
	
	$FilterArr=@()
	if ($ExclLogs) { $FilterArr+=@('$ExclLogs -notcontains $_.Log') }
	if ($Msgs)     { $FilterArr+=@('$_.Message -like $Msgs') }
	if ($Pids)     { $FilterArr+=@('($_.ProcessID -eq {0})' -f $($Pids -join (' -or $_.ProcessID -eq ')) ) }
	
	if ($FilterArr.Length) { 
		$FilterStr='( {0} )' -f $($FilterArr -join (') -and ('))
	} else {
		$FilterStr='$_.MsgNo -gt 0'
		pargs 'No Filters'
	}
	pargs -Vars:FilterStr,Groups
	$FilterBlock=[scriptblock]::Create( $FilterStr )
	foreach($Group in $Groups) {
		$No++
		$TotMessages=$($Global:EVENT_GROUPS[$($Group-1)].Group).Length
		pargs $('[{0}/{1}] Printing {2} message{3} of the group #{4}' -f $No, $TotGroups, $TotMessages, $(if($TotMessages -gt 1) {'s'}), $Group )
		if ($Group -gt $TotGroupedEvents) {
			pargs $('Warning: Group {0} does not exists, group number {0} must not exceed total number of groups {1}' -f $Group,$TotGroupedEvents)
			continue
		}
		$Global:EVENT_GROUPS[$($Group-1)].Group | Where-Object $FilterBlock | ft TimeCreated,ProcessId,User,Log,LogType,Provider,Lvl,Id,Version,Level,Task,Opcode,Keywords,RecordId,Message2
	}
}

##########################################
# Print-EventGroups
function Print-EventGroups ($Groups, $Messages=1, $FilterGroupPids, $AllMessages, $Top, [switch] $NoTable, [switch] $UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw) {
	pargs

	if (!$NoTable)  {  
		Print-EventGroupsTable @PSBoundParameters 
	}

	if ($FilterGroupPids) {
		Print-WinEvents @PSBoundParameters 
		return
	}
	if (!$Groups) {
		pargs 'Warning: No $Groups'
		return 
	}
	
	if($AllMessages) { 
		Print-TableMessages @PSBoundParameters 
	}
	$TotGroupedEvents=$Global:EVENT_GROUPS.Length
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
		Print-EventGroupMessages -Group $Group -Messages $Messages
	}
}

##########################################
# Print-EventGroupMessages
function Print-EventGroupMessages ([int] $Group=1, [int[]] $Messages=1, [switch] $UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw ) {
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

	Print-EventGroupsTable -Skip $Group
	
	$TotGroupedEvents=$Global:EVENT_GROUPS.Length
	$TotEvents=$Global:EVENTS.Count
	$TotMessages=$Messages.Length

	if ($Group -gt $TotGroupedEvents) {
		pargs $('Error: Group Number {0} must not exceed total number of groups {1}' -f $Group, $TotGroupedEvents)
		return
	}
	$GrpIdx=$($Group-1)
	$TotGrpMsg=$($Global:EVENT_GROUPS[$GrpIdx].Group).Length
	
	# '[{0}] Group No {1}. Printing {2} out of {3} message{4}: {5}' -f $MyInvocation.MyCommand, $Group, $TotMessages, $TotGrpMsg, $(if($TotGrpMsg -gt 1) {'s'}), $($Messages -join (','))	
	$MessageNo=0
	foreach($MsgNo in $Messages) {
		$MessageNo++
		if ($MsgNo -gt $TotGrpMsg) {
			pargs $('Warning: Group message {0} does not exists, it must not exceed total group''s message number{1}' -f $MsgNo, $TotGrpMsg)
			continue
		}
		$MsgNo=$Global:EVENT_GROUPS[$GrpIdx].Group[$($MsgNo-1)].MsgNo;
		pargs $('{0} of {1} message{2} - $Global:EVENTS[{3}]' -f $MessageNo, $TotMessages, $(if($TotMessages -gt 1) {'s'}), $MsgNo )
		Format-EventsList $MsgNo
	}
}

##########################################
# Format-EventsList
function Format-EventsList ( [int[]] $MsgNo) {
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

###############################################
# Print-WinEvents
function Print-WinEvents () {
	param(  [int]      $MaxEvents, 
	        [string[]] $LogName='*', 
			[string[]] $ProviderName, 
			[int[]]    $Levels, 
			[int[]]    $EventIDs,
		    [int]      $Days=1, [int] $Hours, [int] $Minutes, [int] $Seconds,
			[switch]   $UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw,
            $Logs, $Pids, $RecIds, $Msgs, $ExclLogs, $ExclPids, $ExclRecIds, $ExclMsgs,
			[int[]]    $Groups, 
			[int[]]    $Messages,
			[int[]]    $FilterGroupPids,
			[switch]   $NoTable,
			[switch]   $Warnings,
			[switch]   $Errors,
			[switch]   $ByMsg,
			[switch]   $AllGroups,
			[switch]   $AllMessages,
			[int]      $Top=45 )

	pargs
	$Pids=@()
	foreach ( $GroupNo in $FilterGroupPids) {
		if ($GroupNo -lt 1 -or $GroupNo -gt $TotalGroups) {
			pargs 'Error: $GroupNo must be greater than zerro andless than total number of groups' -Vars GroupNo,TotalGroups
			continue
		}
		$TotalMessages=$Global:EVENT_GROUPS[$($GroupNo-1)].Group.Count
		pargs -Vars GroupNo, TotalMessages
		foreach ( $MsgNo in $Messages  ) {
			# $G.Group.ProcessId
			if ($MsgNo -lt 1 -or $MsgNo -gt $TotalMessages) {
				pargs 'Error: $MsgNo must be greater than zerro andless than total number of messages in the group' -Vars MsgNo,GroupNo,TotalMessages
				continue
			}
			$ThisPid=$Global:EVENT_GROUPS[$($GroupNo-1)].Group[$($MsgNo-1)].ProcessID
			$Pids+=@($ThisPid)
		}
	}
	$TotPids=$Pids.Length
	if ($TotPids) {
		pargs "Found $TotPids Pid$( if ($TotPids) {'s'})" -Vars:TotalGroups,FilterGroupPid,Pids
		Print-TableMessages @PSBoundParameters
	} else {
		pargs 'Error:  $FilterGroupPid is set but not PIDs to filter have been actually found'
	}

}

###############################################
# Get-Events 
function Get-Events {
	param(  [int]      $MaxEvents, 
	        [string[]] $LogName='*', 
			[string[]] $ProviderName, 
			[int[]]    $Levels, 
			[int[]]    $EventIDs,
		    [int]      $Days=1, [int] $Hours, [int] $Minutes, [int] $Seconds,
			[switch]   $UseCache, [switch]$UpdateCache, [switch]$List, [switch]$Table, [switch]$Raw,
            $Logs, $Pids, $RecIds, $Msgs, $ExclLogs, $ExclPids, $ExclRecIds, $ExclMsgs,
			[int[]]    $Groups, 
			[int[]]    $Messages,
			[int[]]    $FilterGroupPids,
			[switch]   $NoTable,
			[switch]   $Warnings,
			[switch]   $Errors,
			[switch]   $ByMsg,
			[switch]   $AllGroups,
			[switch]   $AllMessages,
			[int]      $Top=65 )

    pargs
	
<#
$Seconds+=($Days*24+$Hours)*3600+$Minutes*60
	$PsBoundParameters['Seconds']=$Seconds 
	$null=$PSBoundParameters.Remove('Days')
	$null=$PSBoundParameters.Remove('Hours')
	$null=$PSBoundParameters.Remove('Minutes')
	
	$Global:SetCondScriptCmd={

	$CondArr=@( '1 -eq 1' ) + 
# 	    $( if( $Logs        ) { @( '$_.LogName -match "{0}"'      -f $($Logs        -join('|')) ) } else { @() } ) +
 	    $( if( $Pids        ) { @( '$_.ProcessId -match "{0}"'    -f $($Pids        -join('|')) ) } else { @() } ) +
 	    $( if( $RecIds      ) { @( '$_.RecordId -match "{0}"'     -f $($RecIds      -join('|')) ) } else { @() } ) +
 	    $( if( $Msgs        ) { @( '$_.Message -match "{0}"'      -f $($Msgs        -join('|')) ) } else { @() } ) +
 	    $( if( $ExclLogs    ) { @( '$_.LogName -notmatch "{0}"'   -f $($ExclLogs    -join('|')) ) } else { @() } ) +
 	    $( if( $ExclPids    ) { @( '$_.ProcessId -notmatch "{0}"' -f $($ExclPids    -join('|')) ) } else { @() } ) +
 	    $( if( $ExclRecIds  ) { @( '$_.RecordId -notmatch "{0}"'     -f $($ExclRecIds  -join('|')) ) } else { @() } ) +
 	    $( if( $ExclMsgs    ) { @( '$_.Message -notmatch "{0}"'      -f $($ExclMsgs    -join('|')) ) } else { @() } ) ;

		$CondStr=' {0} ' -f $($CondArr -join(' -and '))
		$Global:CondScript=$([ScriptBlock]::Create($CondStr)) 
		pargs -Vars:CondStr,Global:FilterHash,Global:CondScript
	}	

	$null=$PSBoundParameters.Remove('Logs')
	$null=$PSBoundParameters.Remove('Pids')
	$null=$PSBoundParameters.Remove('RecIds')
	$null=$PSBoundParameters.Remove('Msgs')
	$null=$PSBoundParameters.Remove('ExclLogs')
	$null=$PSBoundParameters.Remove('ExclPids')
	$null=$PSBoundParameters.Remove('ExclRecIds')
	$null=$PSBoundParameters.Remove('ExclMsgs')
	
	
	$null=$PSBoundParameters.Remove('UseCache')
	$null=$PSBoundParameters.Remove('ByMsg')
	$null=$PSBoundParameters.Remove('Warnings')
	$null=$PSBoundParameters.Remove('NoTable')
	$null=$PSBoundParameters.Remove('AllMessages')
	$null=$PSBoundParameters.Remove('AllGroups')
	
#>	
    if($AllGroups) { 
		if (!$PSBoundParameters.ContainsKey('Groups')) { 
			$PsBoundParameters['Groups']=$(1..$Global:EVENT_GROUPS.Length) 
		}
	}
		
	If (!$Messages) {
		$PsBoundParameters['Messages']=@(1)
	}

	if ( $LogName -eq '*' -and !$Seconds -and !$MaxEvents) { 
		$PsBoundParameters['MaxEvents']=20000 
	}

	if ($Warnings -and !$Levels ) {
		$PsBoundParameters['Levels']=@(1,2,3) 
	}
	
	if (!$UseCache) { 
		# pargs $( '$MyArgs[{0}]: {1}' -f $MyArgs.Count,(($MyArgs.GetEnumerator()|% { if ($_.Value) { '-{0}:{1}' -f ($_.Name -join(',')),($_.Value -join(',')) }} ) -join(' ')) )
		Get-WinEvents @PSBoundParameters
		Group-WinEvents @PSBoundParameters
	}

	Print-EventGroups @PSBoundParameters
	
}

<# 
 $eLog=@('*'); $ePrvd=@('*WinRM'); $eID=@(); $eLvl=@(); $eUID=@(); $eData=@()
 $eExclCols=@("Message","RelatedActivityId","MatchedQueryIds","ContainerLog","ActivityId","ActivityId","Bookmark","MachineName","Properties","Version","Qualifiers","Keywords","ProviderId"),
 $eFltCmd={ $eFlt=@{}+$(if($ePrvd){@{ProviderName=$ePrvd}}else{@{}})+
   $(if($eLog){@{LogName=$eLog}}else{@{}})+$(if($eID){@{ID=$eID}}else{@{}})+
   $(if($eLvl){@{Level=$eLvl}}else{@{}})+$(if($eID){@{UserID=$eUID}}else{@{}})+
   $(if($eData){@{Data=$eData}}else{@{}}); }

 $eTop=10; $eMax=10000
 $eCondCmd={
$eCondArr=@( '1 -eq 1')+ 
$( if( $Msgs     ) { @( '$_.Message   -match    "{0}"'  -f $($Msgs     -join('|')) ) } else { @() } ) +
$( if( $Pids     ) { @( '$_.ProcessId -match    "{0}"'  -f $($Pids     -join('|')) ) } else { @() } ) +
$( if( $ExclMsgs ) { @( '$_.Message   -notmatch "{0}"'  -f $($ExclMsgs -join('|')) ) } else { @() } ) +
$( if( $ExclPids ) { @( '$_.ProcessId -notmatch "{0}"'  -f $($ExclPids -join('|')) ) } else { @() } ) ;
$eCondStr='({0})' -f $($eCondArr -join(') -and ('))
$eCondScript=$([ScriptBlock]::Create($eCondStr))  }

$PrintCmd={
& $SetCondScriptCmd
'$Global:CondScript is {0}' -f $Global:CondScript;
$Global:Result=$Global:MyServices | Where-Object $Global:CondScript
$Global:Result  | Select-Object -First $Top -Property $Cols -ExcludeProperty $ExclCols | ft -auto * 
'{0} of {1} $Global:MyServices object{2} filtered into $Global:Result' -f $Global:Result.Count,$Global:MyServices.Count,$( if($Global:Result.Count -ne 1){'s'} )
'Top {0} of {1} $Global:Result object{2} printed into the above table' -f $Top,$Global:Result.Count,$( if($Top -ne 1){'s'} )

'Helpers:'
'$Global:Result[0] | fl * '
'$Global:Result    | ft $Global:CimCols'
'$Global:MyServices[{0}] | fl * ' -f $Global:Result[0].No
'' }
& $PrintCmd

 $eCmd={ 
 $e=[char]27
 "$e[#p$e[33m eFlt $e[33m:$e[36m {0} $e[33m eTop $e[33m:$e[36m {1}$e[#q" -f $($eFlt|ConvertTo-JSON -compress),$eTop
 "Reading events into `$Res"    | Out-Host
 $eCnt=0
 $eRes=Get-WinEvent -FilterHash $eFlt -Max $eMax | Select-Object -First $eMax @{n='MsgNo';e={($eCnt++)}},*
 $eTot=$eRes.Count
 "$($eTot) loaded object$($(if($eTot -ne 1){'s'})" | Out-Host
 if($eTop -eq 1) { 
    '1 message found' | Out-Host
 } elseif($eTop -gt $eTot) {
	"Printing $eTot messages" | Out-Host
 } else {
	"Printing $eTop out of $eTot messages" | Out-Host
 }
 $eRes | Select-Object -First:$eTop -Exclude:$eExclCols
 }
 & $eCmd | Sort-Object -Descending TimeCreated,RecordId
#>

# $PSBoundParameters.Remove('command')
# CodeExecutor @PsBoundParameters 


pargs

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew() # TBD: replace it in MyWinEvents implementation with pargs

<#
$stopwatch.Restart()
"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Started $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f 'Main',$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
#>

CodeExecutor @args

<#
"$sc$BgBlue[${ylw}{0}$gry() {1}${gry}:$cyn{2}$blu]$ylw Elapsed: $grn{3}$gry ms, $grn{4}$gry ticks$rc" -f 'Main',$(Split-Path $(& {$MyInvocation.ScriptName}) -leaf), $(& {$MyInvocation.ScriptLineNumber}), 
   $stopwatch.Elapsed.milliseconds,$stopwatch.Elapsed.ticks
$stopwatch.Stop()
#>



<# 
PS C:\Users\alexe> Get-WinEvent -FilterHashtable @{LogName='*'; Level=1,2} -maxevents 1 | ConvertTo-JSON
{ "Id": 142,  
  "Version": 0, 
  "Qualifiers": null,
  "Level": 2, "Task": 10,
  "Opcode": 2,
  "Keywords": 4611686018427387906,
  "RecordId": 1814,
  "ProviderName": "Microsoft-Windows-WinRM",
  "ProviderId": "a7975c8f-ac13-49f1-87da-5a984a4ab417",
  "LogName": "Microsoft-Windows-WinRM/Operational",
  "ProcessId": 21732,
  "ThreadId": 18412,
  "MachineName": "Win11-2",
  "UserId": { "BinaryLength": 12, "AccountDomainSid": null, "Value": "S-1-5-18" },
  "TimeCreated": "2022-05-20T03:01:30.2834368-04:00",
  "ActivityId": "fdababc6-67cb-000a-98cc-b2fdcb67d801",
  "RelatedActivityId": null,
  "ContainerLog": "Microsoft-Windows-WinRM/Operational",
  "MatchedQueryIds": [],
  "Bookmark": {},
  "LevelDisplayName": "Error",
  "OpcodeDisplayName": "Stop",
  "TaskDisplayName": "Response handling",
  "KeywordsDisplayNames": [ "Client" ],
  "Properties": [ { "Value": "Enumeration" }, { "Value": 2150858770 } ],
  "Message": "WSMan operation Enumeration failed, error code 2150858770" }

 PS C:\Users\alexe> Get-WinEvent Microsoft-Windows-WinRM/Operational -FilterXPath "*[System[EventRecordID=1814]]" | ConvertTo-JSON
 PS C:\Users\alexe> Get-WinEvent Microsoft-Windows-WinRM* -FilterXPath "*[System[EventRecordID=1814]]" | ConvertTo-JSON
 
#>

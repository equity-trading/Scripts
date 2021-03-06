#############################################################
# Get Error events occured during last X hours
#

# C:\home\tmp\errors-warnings-events-2022-04-26.log
function Out-Events {
    param($Events)
    foreach ($e in $Events) {
        Format-Table @{n='User';e={(Get-StandardUser $_.UserId)}},
            UserId,
            TimeCreated,
            ProviderName,
            Level,
            LevelDisplayName,
            OpcodeDisplayName,
            RecordId,
            Id,
            ProcessId, 
            @{n='Message Text';e={ $_.Message -replace "`r",'' -replace "`n",'\n' -replace "\s+"," " -replace '(?<=.{500}).+' }}
    }
}

Function Out-Table {
}

Function Out-Record {
}

Function Run-Cmd {
    param([Script] $Cmd)
#    $Cmd="Get-Service -Name '$pattern*' "
    "Cmd: {0}" -f $Cmd
    $Objects=@( Invoke-Command -ScriptBlock { param($LocalCmd) Invoke-Expression -Command:$LocalCmd } -ArgumentList $Cmd )     
    "There are {0} matching objects, cmd: {1}" -f $Objects.Count, $Cmd
	if ($Objects.Count -gt 1) { 
		"There are {0} resulting records, cmd: {1}" -f $Objects.Count, $Cmd
        if ( Get-Command -Name Out-Table -CommmandType Function-ErrorAction Ignore ) {   $Objects | Out-Table  } else {  $Objects | Format-Table * }
	} elseif ($Objects.Count -eq 1) { 
        "There is just one resulting record, cmd: {0}" -f $Cmd
        if ( Get-Command -Name Out-Table -CommmandType Function-ErrorAction Ignore ) {   $Objects | Out-Record  } else {  $Objects | Select-Object * }
	} else {
		"There is no result returned, cmd: {0}" -f $Cmd
	}
}

function Get-UserEvents {
    param([int]$Hours=10, [int[]]$Levels=(1,2),[string[]] $Users="*", [string[]] $Sids="*", [string[]] $Logs="*", [int]$NoOfEvents=1000000)
    $FilterHashtable=@{LogName=$Logs; Level=$Levels; StartTime=((Get-Date).AddHours(-$Hours))}
    "FilterHashtable[$($FilterHashtable.Count)]: $($FilterHashtable.Keys| ForEach-Object { "$_=$($FilterHashtable.$_ -join ',')" })"
    Run-Cmd -Cmd Get-WinEvent -MaxEvent $NoOfEvents -ErrorAction Ignore -FilterHashtable $FilterHashtable
}



function Get-LastEvents {
    param([int]$Hours=10, [int[]]$Levels=(1,2), [int]$NoOfEvents=1000)
    $eNo=0
    $EVENT_LOGS=get-WinEvent -listlog * -ea 0 | where-object {$_.recordcount -gt 0 -and $_.LastWriteTime -gt ((Get-Date).AddHours(-$Hours))}
    $lTot=$EVENT_LOGS.Count
    "Hours: $Hours; Changed Logs: $lTot"
    # $EVENT_LOGS.LogName | Format-Table
    if ($lTot) {
        $FilterArray=@(); $FilterArray+='$_.TimeCreated -ge ((Get-Date).AddHours(-$Hours))'
        if($Levels.Count) { $FilterArray+='$_.Level -in $Levels' }
        $FilterString=$FilterArray -join ' -and '
        $FilterBlock=[scriptblock]::Create($FilterString)

        # 'FilterString : {0}' -f $FilterString
        'FilterBlock : {0}' -f $FilterBlock.ToString()

        $ms=($Hours*3600+$Seconds)*1000*1000        
        $CreatedXpath="TimeCreated[timediff(@SystemTime)<=$ms]" 
        if($Levels.Count) { $LevelXpath = '{0}' -f "Level=$(($Levels) -join ' or Level=')"} else {$LevelXpath='1=1'}

        $xPath = 'Event[System[({0}) and ({1})]' -f $LevelXpath, $CreatedXpath
        'xPath : {0}' -f $xPath.ToString()

        $HashTable=@{LogName=($EVENT_LOGS.LogName); Level=$Levels; StartTime=((Get-Date).AddHours(-$Hours))}
        # 'HashTable[{0}]: {1}' -f $($HashTable.Count), $($HashTable.Keys|ForEach-Object { "$_=$($HashTable.$_ -join ',')" } )
        "HashTable[$($HashTable.Count)]: $($HashTable.Keys| ForEach-Object { "$_=$($HashTable.$_ -join ',')" })"
        # $events = Get-WinEvent -LogName ($EVENT_LOGS.LogName)
        # -FilterXPath $xPath 
        # -FilterHashtable $HashTable
        # $EVENTS=Get-WinEvent -LogName ($EVENT_LOGS.LogName) -MaxEvent $NoOfEvents -ea 0 | Where-Object $FilterBlock
        $EVENTS=Get-WinEvent -MaxEvent $NoOfEvents -ErrorAction Ignore -FilterHashtable $HashTable
        # $EVENTS=Get-WinEvent -LogName ($EVENT_LOGS.LogName) -MaxEvent $NoOfEvents -ErrorAction Ignore -FilterXPath $xPath
        $Providers=$EVENTS.ProviderName | Select-Object -Unique
        # $EVENT_GROUPS=Get-WinEvent $EVENT_LOGS -maxevent $NoOfEvents --ErrorAction Ignore  | Where-Object $FilterBlock | Group-Object LogName,ProviderName,Level | Sort-Object -Descending Count
        $eTot=$EVENTS.Count
        ""
        "Done"
        ""
        "Total: $eTot of $NoOfEvents Event$(($eTot -ne 1)?'s':'') "
        "Providers:$($Providers -join('; '))" 
        

        return 
        if ($eTot) {
#            $EVENTS=$EVENT_GROUPS |  Group-Object -Property  @{expression={$_.Values[0]}},@{expression={$_.Values[2]}} | Select-Object -Property @{n='Count';e={($_.Group | Measure-Object -Property Count -Sum).Sum}}, @{n="GrpCnt";e={$_.Count}}, @{n='LogName';e={$_.Values[0]}}, @{n='D';e={$_.Values[1]}}, @{n='FstEvent';e={($_.Group.Group| Select-Object -first 1 *)}}, @{n='Events';e={$_.Group.Group}}
            foreach ($E in $EVENTS) {
                $pad=1
                $eNo++
                $STRINGS=$E.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eNo of $(($EVENTS).Count)") -split("`n")
                foreach ($str in $STRINGS) {
                    ForEach-Object { if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }
                }
            }
            "RecID: $RecId; Providers:$Providers; Total: $eNo Event$(($eNo -ne 1)?'s':'') "
        }
    }
}

Get-LastEvents
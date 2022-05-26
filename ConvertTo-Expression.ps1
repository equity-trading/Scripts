param( [switch]$Test, [switch]$Measure, [switch]$Verify, [switch]$Quiet )

$WeekdayOrdered = [ordered]@{1 = 'Monday'; 2='Tuesday'; 3='Wednesday'; 4='Thursday'; 5='Friday'}
$WeekendOrdered = [ordered]@{6 = 'Saturday'; 7='Sunday'}
$WeekOrdered=[ordered]@{ 
    Weekday=$WeekdayOrdered; Weekend=$WeekendOrdered ;
    WorkDay=@(
        [ordered]@{abbr='Mon';dayno=1;name="Monday";},
        [ordered]@{abbr='Tue';dayno=2;name="Tuesday";},
        [ordered]@{abbr='Wen';dayno=3;name="Wednesday";},
        [ordered]@{abbr='Thu';dayno=4;name="Thursday";},
        [ordered]@{abbr='Fri';dayno=5;name="Friday";},
        [ordered]@{abbr='Sat';dayno=6;name="Saturday";},
        [ordered]@{abbr='Sun';dayno=7;name="Sunday";}
    )
}
$Weekday = @{1 = 'Monday'; 2='Tuesday'; 3='Wednesday'; 4='Thursday'; 5='Friday'}
$Weekend = @{6 = 'Saturday'; 7='Sunday'}
$Week=[ordered]@{ 
    Weekday=$Weekday; Weekend=$Weekend; 
    WorkDay=@(
        @{abbr='Mon';dayno=1;name="Monday";},
        @{abbr='Tue';dayno=2;name="Tuesday";},
        @{abbr='Wen';dayno=3;name="Wednesday";},
        @{abbr='Thu';dayno=4;name="Thursday";},
        @{abbr='Fri';dayno=5;name="Friday";},
        @{abbr='Sat';dayno=6;name="Saturday";},
        @{abbr='Sun';dayno=7;name="Sunday";}
    )
}

$Complex=[ordered]@{ 
    WeekDay = @(
        [ordered]@{Day   = [pscustomobject]@{abbr='Mon';dayno=1}; Mon="Monday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Tue';dayno=2}; Tue="Tuesday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Wen';dayno=3}; Wen="Wednesday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Thu';dayno=4}; Thu="Thursday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Fri';dayno=5}; Fri="Friday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Sat';dayno=6}; Sat="Saturday"},
        [ordered]@{Day   = [pscustomobject]@{abbr='Sun';dayno=7}; Sun="Sunday"}
    )
    WorkDay=[pscustomobject]@{
        Monday     = [ordered]@{abbr='Mon';dayno=1}
        Tuesday    = [ordered]@{abbr='Tue';dayno=2}
        Wednesday  = [ordered]@{abbr='Wen';dayno=3}
        Thursday   = [ordered]@{abbr='Thu';dayno=4}
        Friday     = [ordered]@{abbr='Fri';dayno=5}
    }
    WeekEnd=[pscustomobject]@{
        Saturday   = [pscustomobject]@{abbr='Sat';dayno=6}
        Sunday     = [pscustomobject]@{abbr='Sun';dayno=7}
    }
}

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
        (Serialize $Object).TrimEnd()
    }
};

#Set-Alias ctex ConvertTo-Expression
$MaxWidth=$($Host.UI.RawUI.WindowSize.Width-16)
$MyCommand=$MyInvocation.MyCommand
$Line=$MyInvocation.Line

if (!$quiet) { 
    '-- started ---' 
    '{0,-30} : {1}' -f 'Command Line', $Line # ($Line -replace(".*$MyCommand",$MyCommand))
}

if ($Test) {
    if (!$args) { $args=@($Week, $WeekOrdered, $Complex) }
    'Test mode: {0} args' -f $args.Count
    $Verify=$true
}

if( !$args ) {
    'Usage: {0} [-Test] [-Measure] [-Verify] [-Quiet] $var1 [$var2 ...] ' -f $MyCommand.Name
} else {

    if ($Measure) {
        $mywatch=[System.Diagnostics.Stopwatch]::StartNew()
        $mywatch.Reset()
    }

    foreach ($value in $args) {
        $IterNo++
        if ($Measure) { $mywatch.Start() }
        $global:ResultString=ConvertTo-Expression $value
        if ($Measure) { $mywatch.Stop() }

        if (!$quiet) {
            ''
            '-- Iter {0,-3} {1,-20} ----------------------' -f $IterNo,$value.GetType().Name
            '-- Result Object --------------------------------------'
            '{0}' -f $($ResultObject[0]|Out-String).Trim()
        } else {
            '-- Iter {0,-3} {1,-20} ----------------------' -f $IterNo,$value.GetType().Name
        }

        If ($Verify) {
            $ResultString=@(); $ResultObject=@(); $checksum=@(); $length=@()
            $global:ResultObject=Invoke-Expression $global:ResultString
            $ResultString+=@( $global:ResultString )
            $ResultObject+=@( $global:ResultObject )
            $checksum+=@( for(($chksum=0),($pos=0);$pos -lt $global:ResultString.Length ;$pos++) { [int]$chksum+=$global:ResultString[$pos] }; $chksum )
            $length+=@( $global:ResultString.Length )
    
            $global:ResultString=ConvertTo-Expression $global:ResultObject
            $global:ResultObject=Invoke-Expression $global:ResultString
            $ResultString+=@( $global:ResultString )
            $ResultObject+=@( $global:ResultObject )
            $checksum+=@( for(($chksum=0),($pos=0);$pos -lt $global:ResultString.Length ;$pos++) { [int]$chksum+=$global:ResultString[$pos] }; $chksum )
            $length+=@( $global:ResultString.Length )            
            if (!$quiet) { 
                '-- Verify Object --------------------------------------'
                '{0}' -f $($ResultObject[1]|Out-String).Trim()
                '-- Checks ---------------------------------------------'
            }
            if( $checksum[0] -eq $checksum[1] ) {
                '{0,-12}: {1} ({2})' -f 'CheckSum','Same',$checksum[0]
            } else {
                '{0,-12}: {1} ({2}/{3})' -f 'CheckSum','Diff',$checksum[0],$checksum[1]
            }
            if( $length[0] -eq $length[1] ) {
                '{0,-12}: {1} ({2})' -f 'Length','Same',$length[0]
            } else {
                '{0,-12}: {1} ({2}/{3})' -f 'Length','Diff',$length[0],$length[1]
            }
            if (!$quiet) {             
                '-- Values ---------------------------------------------'
                '{0,-12}: {1}' -f 'Result',$ResultString[0].Substring(0,$MaxWidth)+$(if($ResultString[0].Length -gt $MaxWidth){'..'})
                '{0,-12}: {1}' -f 'Verify',$ResultString[1].Substring(0,$MaxWidth)+$(if($ResultString[1].Length -gt $MaxWidth){'..'})
                '-------------------------------------------------------'
                ''
            }
        } else {
            $global:ResultString
        }
    }

    if ($Measure) {
        'Elapsed: {0} ms, {1} ticks' -f $mywatch.Elapsed.milliseconds, $mywatch.Elapsed.ticks
        if ($IterNo -gt 1) { 
            '{0} Iterations' -f  $IterNo
            '{0} ms/iter, {1} ticks/iter' -f $($mywatch.Elapsed.milliseconds/$IterNo), $($mywatch.Elapsed.ticks/$IterNo)
        }
    }
    if (!$quiet) { '----------'; }
    $global:ResultObject=Invoke-Expression $global:ResultString
}
if (!$quiet) { 'Last values kept in $Global:ResultString and $Global:ResultObject'; '-- done --'; }
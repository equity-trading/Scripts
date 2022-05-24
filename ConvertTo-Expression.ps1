using namespace System.Management.Automation
param([switch]$Test,[switch]$Measure)

function ConvertTo-Expression {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Scope = 'Function')] # https://github.com/PowerShell/PSScriptAnalyzer/issues/1472
    [CmdletBinding()][OutputType([scriptblock])] param(
        [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] $Object,
        [int]$Depth = 9,
        [int]$Expand = $Depth,
        [int]$Indentation = 4,
        [string]$IndentChar = ' ',
        [switch]$Strong,
        [switch]$Explore,
        [ValidateSet("Name", "Fullname", "Auto")][string]$TypeNaming = 'Auto',
        [string]$NewLine = [System.Environment]::NewLine
    )
    begin {
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
                    if ($Methods['GetEnumerator'] -is [PSMethod]) {
                        if ($Methods['get_Keys'] -is [PSMethod] -and $Methods['get_Values'] -is [PSMethod]) {
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
                        elseif ($Expand -lt 0) { Prefix ('@{' + (@(foreach ($Key in $List.get_Keys()) { "$Key=" + $List[$Key] }) -join ';') + '}') }
                        elseif ($List.Count -eq 1 -or $Indent -ge $Expand - 1) {
                            Prefix ('@{' + (@(foreach ($Key in $List.get_Keys()) { "$Key = " + $List[$Key] }) -join '; ') + '}')
                        } else {
                            $LineFeed = $NewLine + ($Tab * $Indent)
                            Prefix ("@{$LineFeed$Tab" + (@(foreach ($Key in $List.get_Keys()) {
                                            if (($List[$Key])[0] -notmatch '[\S]') { "$Key =" + $List[$Key].TrimEnd() } else { "$Key = " + $List[$Key].TrimEnd() }
                                        }) -join "$LineFeed$Tab") + "$LineFeed}")
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
Set-Alias ctex ConvertTo-Expression
if ($PSBoundParameters.ContainsKey('Test') -or !$args ){
	$tht=@{
		i2 = 2
		ht1 = {k1=11;k2=12}
		ht2 = @{ht3 = @{
				k2 = 2
				k1 = 1
			}}
		i1 = 1
	}
	$args+=@($tht)
}

if ($PSBoundParameters.ContainsKey('Measure')) {
	Measure-Command -expression { ConvertTo-Expression @args }
} else {
	ConvertTo-Expression @args
}


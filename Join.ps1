<#PSScriptInfo
.LICENSEURI https://github.com/iRon7/Join-Object/LICENSE
.PROJECTURI https://github.com/iRon7/Join-Object
.ICONURI https://raw.githubusercontent.com/iRon7/Join-Object/master/Join-Object.png
#>
param($Test,[switch]$Measure)

function Join-Object {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('InjectionRisk.Create', '', Scope = 'Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('InjectionRisk.ForeachObjectInjection', '', Scope = 'Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseLiteralInitializerForHashtable', '', Scope = 'Function')]
    [CmdletBinding(DefaultParameterSetName = 'Default')][OutputType([Object[]])] param(

        [Parameter(ValueFromPipeLine = $True, ParameterSetName = 'Default')]
        [Parameter(ValueFromPipeLine = $True, ParameterSetName = 'On')]
        [Parameter(ValueFromPipeLine = $True, ParameterSetName = 'Using')]
        $LeftObject,

        [Parameter(Position = 0, ParameterSetName = 'Default')]
        [Parameter(Position = 0, ParameterSetName = 'On')]
        [Parameter(Position = 0, ParameterSetName = 'Using')]
        $RightObject,

        [Parameter(Position = 1, ParameterSetName = 'On')]
        [array]$On = @(),

        [Parameter(Position = 1, ParameterSetName = 'Using')]
        [scriptblock]$Using,

        [Parameter(ParameterSetName = 'On')]
        [Alias('Eq')][array]$Equals = @(),

        [Parameter(Position = 2, ParameterSetName = 'Default')]
        [Parameter(Position = 2, ParameterSetName = 'On')]
        [Parameter(Position = 2, ParameterSetName = 'Using')]
        [Alias('NameItems')][AllowEmptyString()][String[]]$Discern,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'On')]
        [Parameter(ParameterSetName = 'Using')]
        $Property,

        [Parameter(Position = 3, ParameterSetName = 'Default')]
        [Parameter(Position = 3, ParameterSetName = 'On')]
        [Parameter(Position = 3, ParameterSetName = 'Using')]
        [scriptblock]$Where = { $True },

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'On')]
        [Parameter(ParameterSetName = 'Using')]
        [ValidateSet('Inner', 'Left', 'Right', 'Full', 'Outer', 'Cross')][String]$JoinType = 'Inner',

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'On')]
        [Parameter(ParameterSetName = 'Using')]
        [string]$ValueName = 'VALUE',

        [Parameter(ParameterSetName = 'On')]
        [switch]$Strict,

        [Parameter(ParameterSetName = 'On')]
        [Alias('CaseSensitive')][switch]$MatchCase
    )
    begin {
        function StopError($Exception, $Id = 'IncorrectArgument', $Group = [Management.Automation.ErrorCategory]::SyntaxError, $Object){
            if ($Exception -isnot [Exception]) { $Exception = [ArgumentException]$Exception }
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new($Exception, $Id, $Group, $Object))
        }
        function GetKeys($Object) {
            if ($Null -eq $Object) { ,@() }
            elseif ($Object.GetType().GetElementType() -and $Object.get_Count() -eq 0) { ,[string[]]$ValueName } # ,[string[]] is used to easy recognise a value arrey
            else {
                $1 = $Object |Select-Object -First 1
                if ($1 -is [string] -or $1 -is [ValueType] -or $1 -is [Array]) { ,[string[]]$ValueName }
                elseif ($1 -is [Collections.ObjectModel.Collection[psobject]]) { ,[string[]]$ValueName }
                elseif ($1 -is [Data.DataRow]) { ,@($1.Table.Columns.ColumnName) }
                elseif ($1 -is [System.Collections.IDictionary]) { ,@($1.Get_Keys()) }
                elseif ($1) { ,@($1.PSObject.Properties.Name) }
            }
        }
        function GetProperties($Object, $Keys) {
            if ($Keys -is [string[]]) { [ordered]@{ $ValueName = $Object } }
            else {
                $Properties = [ordered]@{}
                if ($Null -ne $Object) {
                    foreach ($Key in $Keys) { $Properties.Add($Key, $Object.psobject.properties[$Key].Value) }
                }
                $Properties
            }
        }
        function AsDictionary($Object, $Keys) {
            if ($Object -isnot [array] -and $Object -isnot [Data.DataTable]) { $Object = @($Object) }
            ,@(foreach ($Item in $Object) {
                if ($Item -is [Collections.IDictionary]) { $Object; Break } else { GetProperties $Item $Keys }
            })
        }
        function SetExpression ($Key = '*', $Expression) {
            $Wildcard = if ($Key -is [ScriptBlock]) { $BothKeys } else {
                if (!$BothKeys.Contains($Key)) {
                    if ($Key.Trim() -eq '*') { $BothKeys }
                    else {
                        $Side, $Asterisks = $Key.Split('.', 2)
                        if ($Null -ne $Asterisks -and $Asterisks.Trim() -eq '*') {
                            if ($Side -eq 'Left') { $LeftKeys } elseif ($Side -eq 'Right') { $RightKeys }
                        }
                    }
                }
            }
            if ($Null -ne $Wildcard) {
                if ($Null -eq $Expression) { $Expression = $Key }
                foreach ($Key in $Wildcard) {
                    if ($Null -ne $Key -and !$Expressions.Contains($Key)) {
                        $Expressions[$Key] = $Expression
                    }
                }
            }
            else { $Expressions[$Key] = if ($Expression) { $Expression } else { ' * ' } }
        }
        function OutObject ($LeftIndex, $RightIndex) {
            $Nodes = [Ordered]@{}
                foreach ($_ in $Expressions.Get_Keys()) {
                $Tuple =
                    if ($Expressions[$_] -is [scriptblock]) { @{ 0 = &([scriptblock]::Create($Expressions[$_])) } }
                    else {
                        $Key = $Expressions[$_]
                        if ($Left.Contains($Key) -or $Right.Contains($Key)) {
                            if ($Left.Contains($Key) -and $Right.Contains($Key)) { @{ 0 = $Left[$Key]; 1 = $Right[$Key] } }
                            elseif ($Left.Contains($Key)) { @{ 0 = $Left[$Key] } }
                            else { @{ 0 = $Right[$Key] } } # if($Right.Contains($_))
                        }
                        elseif ($Key.Trim() -eq '*') {
                            if ($Left.Contains($_) -and $Right.Contains($_)) {
                                if ($LeftRight.Contains($_) -and $LeftRight[$_] -eq $_) {
                                    if ($Null -ne $LeftIndex -and $Left.Contains($_)) { @{ 0 = $Left[$_] } } else { @{ 0 = $Right[$_] } }
                                }
                                elseif (!$LeftRight.Contains($_) -and $RightLeft.Contains($_)) { @{ 0 = $Left[$_] } }
                                elseif ($LeftRight.Contains($_) -and !$RightLeft.Contains($_)) { @{ 0 = $Right[$_] } }
                                else { @{ 0 = $Left[$_]; 1 = $Right[$_] } }
                            }
                            elseif ($Left.Contains($_))  {
                                if ($Null -ne $LeftIndex -and $Left.Contains($_)) { @{ 0 = $Left[$_] } }
                                elseif ($LeftRight.Contains($_)) { @{ 0 = $Right[$LeftRight[$_]] } }
                            }
                            elseif ($Right.Contains($_)) {
                                if ($Null -ne $RightIndex -and $Right.Contains($_)) { @{ 0 = $Right[$_] } }
                                elseif ($RightLeft.Contains($_)) { @{ 0 = $Left[$RightLeft[$_]] } }
                            }
                        }
                        else {
                            $Side, $Key = $Key.Split('.', 2)
                            if ($Null -ne $Key) {
                                if ($Side[0] -eq 'L') {
                                    if ($Left.Contains($Key)) { @{ 0 = $Left[$Key] } }
                                    elseif ($Key -eq '*') {
                                        if ($Null -ne $LeftIndex -and $Left.Contains($_)) { @{ 0 = $Left[$_] } }
                                        elseif ($Null -ne $RightIndex -and $Right.Contains($_)) { @{ 0 = $Right[$_] } }
                                    }
                                }
                                if ($Side[0] -eq 'R') {
                                    if ($Right.Contains($Key)) { @{ 0 = $Right[$Key] } }
                                    elseif ($Key -eq '*') {
                                        if ($Null -ne $RightIndex -and $Right.Contains($_)) { @{ 0 = $Right[$_] } }
                                        elseif ($Null -ne $LeftIndex -and $Left.Contains($_)) { @{ 0 = $Left[$_] } }
                                    }
                                }
                            } else { StopError "The property '$Key' doesn't exists" 'MissingProperty' }
                        }
                    }
                if ($Tuple -isnot [System.Collections.IDictionary] ) { $Node = $Null }
                elseif ($Tuple.Count -eq 1) { $Node = $Tuple[0] }
                else {
                    $Node = [Collections.ObjectModel.Collection[psobject]]::new()
                    if ($Tuple[0] -is [Collections.ObjectModel.Collection[psobject]]) { foreach ($Value in $Tuple[0]) { $Node.Add($Value) } } else { $Node.Add($Tuple[0]) }
                    if ($Tuple[1] -is [Collections.ObjectModel.Collection[psobject]]) { foreach ($Value in $Tuple[1]) { $Node.Add($Value) } } else { $Node.Add($Tuple[1]) }
                }
                if ($Node -is [Collections.ObjectModel.Collection[psobject]] -and $Null -ne $Discern) {
                    if ($Node.Count -eq $Discern.Count + 1) { $Nodes[$_] = $Node[$Node.Count - $Discern.Count - 1] }
                    if ($Node.Count -gt $Discern.Count + 1) { $Nodes[$_] = $Node[0..($Node.Count - $Discern.Count - 1)] }
                    for ($i = [math]::Min($Node.Count, $Discern.Count); $i -gt 0; $i--) {
                        $Rename = $Discern[$Discern.Count - $i]
                        $Name = if ($Rename.Contains('*')) { ([regex]"\*").Replace($Rename, $_, 1) } elseif ( $_ -eq $ValueName) { $Rename } else { $Rename + $_ }
                        $Nodes[$Name] = if ($Nodes.Contains($Name)) { @($Nodes[$Name]) + $Node[$Node.Count - $i] } else { $Node[$Node.Count - $i] }
                    }
                } else { $Nodes[$_] = $Node }
            }
            if ($Nodes.Count -eq 1 -and $Nodes.Contains($ValueName)) { ,$Nodes[0] } else { [PSCustomObject]$Nodes }
        }
        function ProcessObject ($Left) {
            if ($Left -isnot [Collections.IDictionary]) { $Left = GetProperties $Left $LeftKeys }
            if (!$LeftIndex) {
                ([ref]$InnerRight).Value = [Boolean[]](@($False) * $RightList.Count)
                foreach ($Key in $LeftKeys) {
                    if ($Left[$Key] -isnot [Collections.ObjectModel.Collection[psobject]]) { $LeftNull[$Key] = $Null }
                    else { $LeftNull[$Key] = [Collections.ObjectModel.Collection[psobject]]( ,$Null * $Left[$Key].Count) }
                }
                foreach ($Key in $RightKeys) {
                    $RightNull[$Key] = if ($RightList) {
                        if ($RightList[0][$Key] -isnot [Collections.ObjectModel.Collection[psobject]]) { $Null }
                        else { [Collections.ObjectModel.Collection[psobject]]( ,$Null * $Left[$Key].Count) }
                    }
                }
                $BothKeys = [System.Collections.Generic.HashSet[string]](@($LeftKeys) + @($RightKeys))
                if ($On.Count) {
                    if ($On.Count -eq 1 -and $On[0] -is [string] -and $On[0].Trim() -eq '*' -and !$BothKeys.Contains('*')) { # Use e.g. -On ' * ' if there exists an '*' property
                        ([Ref]$On).Value = $LeftKeys.Where{ $RightKeys.Contains($_) }
                    }
                        if ($On.Count -gt $Equals.Count) { ([Ref]$Equals).Value += $On[($Equals.Count)..($On.Count - 1)] }
                    elseif ($On.Count -lt $Equals.Count) { ([Ref]$On).Value     += $Equals[($On.Count)..($Equals.Count - 1)] }
                    for ($i = 0; $i -lt $On.Count; $i++) {
                        if ( $On[$i] -is [ScriptBlock] ) { if ( $On[$i] -Like '*$Right*' ) { Write-Warning 'Use the -Using parameter for comparison expressions' } }
                        else {
                            if ($On[$i] -notin $LeftKeys) { StopError "The property $($On[$i]) cannot be found on the left object."  'MissingLeftProperty' }
                            $LeftRight[$On[$i]] = $Equals[$i]
                        }
                        if ( $Equals[$i] -is [ScriptBlock] ) { if ( $On[$i] -Like '*$Left*' ) { Write-Warning 'Use the -Using parameter for comparison expressions' } }
                        else {
                            if ($Equals[$i] -notin $RightKeys) { StopError "The property $($Equals[$i]) cannot be found on the right object." 'MissingRightProperty' }
                            $RightLeft[$Equals[$i]] = $On[$i]
                        }
                    }
                    $RightIndex = 0
                    foreach ($Right in $RightList) {
                        $JoinKeys = foreach ($Key in $Equals) { if ($Key -is [ScriptBlock]) { $Right |ForEach-Object $Key } else { $Right[$Key] } }
                        $HashKey = if (!$Strict) { [string]::Join($EscSeparator, @($JoinKeys)) }
                                   else { [System.Management.Automation.PSSerializer]::Serialize($JoinKeys) }
                        if ($RightIndices.ContainsKey($HashKey)) { $RightIndices[$HashKey].Add($RightIndex++) } else { $RightIndices.Add($HashKey, $RightIndex++) }
                    }
                }
                if ($Property) {
                    foreach ($Item in @($Property)) {
                        if ($Item -is [System.Collections.IDictionary]) { foreach ($Key in $Item.Get_Keys()) { SetExpression $Key $Item[$Key] } }
                        else { SetExpression $Item }
                    }
                } else { SetExpression }
            }
            $Indices =
                if ($On.Count) {
                    if ($JoinType -eq 'Cross') { StopError 'The On parameter cannot be used on a cross join.' 'CrossOn' }
                    $JoinKeys = foreach ($Key in $On) { if ($Key -is [ScriptBlock]) { $Left |ForEach-Object $Key } else { $Left[$Key] } }
                    $HashKey = if (!$Strict) { [string]::Join($EscSeparator, @($JoinKeys)) }
                               else { [System.Management.Automation.PSSerializer]::Serialize($JoinKeys) }
                    $RightIndices[$HashKey]
                }
                elseif ($Using) {
                    if ($JoinType -eq 'Cross') { StopError 'The Using parameter cannot be used on a cross join.' 'CrossUsing' }
                    for ($RightIndex = 0; $RightIndex -lt $RightList.Count; $RightIndex++) {
                        $Right = $RightList[$RightIndex]; if (&([scriptblock]::Create($Using))) { $RightIndex }
                    }
                }
                elseif ($JoinType -eq 'Cross') { 0..($RightList.Length - 1) }
                elseif ($LeftIndex -lt $RightList.Count) { $LeftIndex } else { $Null }
            foreach ($RightIndex in $Indices) {
                $Right = $RightList[$RightIndex]
                if (&([scriptblock]::Create($Where))) {
                    if ($JoinType -ne 'Outer') { OutObject -LeftIndex $LeftIndex -RightIndex $RightIndex }
                    $InnerLeft = $True
                    $InnerRight[$RightIndex] = $True
                }
            }
            $RightIndex = $Null; $Right = $RightNull
            if (!$InnerLeft -and ($JoinType -in 'Left', 'Full', 'Outer')) {
                if (&([scriptblock]::Create($Where))) { OutObject -LeftIndex $LeftIndex -RightIndex $RightIndex }
            }
        }
        if ($PSBoundParameters.ContainsKey('Discern') -and !$Discern) { $Discern = @() }
        if ($JoinType -eq 'Outer' -and !$PSBoundParameters.ContainsKey('On')) { $On = '*' }
        $Esc = [char]27; $EscSeparator = $Esc + ', '
        $Expressions = [Ordered]@{}
        $StringComparer = if ($MatchCase) { [StringComparer]::Ordinal } Else { [StringComparer]::OrdinalIgnoreCase }
        $LeftKeys, $InnerLeft, $RightKeys, $InnerRight, $Pipeline, $LeftList = $Null
        $RightIndices = [Collections.Generic.Dictionary[string, [Collections.Generic.List[Int]]]]::new($StringComparer)
        $LeftRight = @{}; $RightLeft = @{}; $LeftNull = [ordered]@{}; $RightNull = [ordered]@{}
        $LeftParameter = $PSBoundParameters.ContainsKey('LeftObject')
        $RightParameter = $PSBoundParameters.ContainsKey('RightObject')
        $RightKeys = GetKeys $RightObject
        $RightList = if ($RightParameter) { AsDictionary $RightObject $RightKeys }
        $LeftIndex = 0
    }
    process {
        # The Process block is invoked (once) if the pipeline is omitted but not if it is empty: @()
        if ($Null -eq $LeftKeys) { $LeftKeys = GetKeys $LeftObject }
        if ($LeftParameter) { $LeftList = AsDictionary $LeftObject $LeftKeys }
        else {
            if ($Null -eq $Pipeline) { $Pipeline = [Collections.Generic.List[Collections.IDictionary]]::New() }
            if ($Null -ne $LeftObject) {
                if ($LeftObject -isnot [Collections.IDictionary]) { $LeftObject = GetProperties $LeftObject $LeftKeys }
                if ($RightParameter) { ProcessObject $LeftObject; $LeftIndex++ } else { $Pipeline.Add($LeftObject) }
            }
        }
    }
    end {
        if (!($LeftParameter -or $Pipeline) -and !$RightParameter) { StopError 'A value for either the LeftObject, pipeline or the RightObject is required.' 'MissingObject' }
        if ($Pipeline) { $LeftList = $Pipeline } elseif ($Null -eq $LeftKeys) { $LeftList = @() }
        if (!$LeftIndex) { # Not yet streamed/processed
            if ($Null -eq $LeftList) { # Right Self Join
                $LeftKeys = $RightKeys
                $LeftList = $RightList
            }
            if ($Null -eq $RightList) { # Left Self Join
                $RightKeys = $LeftKeys
                $RightList = $LeftList
            }
            foreach ($Left in $LeftList) { ProcessObject $Left; $LeftIndex++ }
        }
        if ($JoinType -in 'Right', 'Full', 'Outer') {
            if (!$LeftIndex) { ProcessObject $LeftObject $Null }
            $LeftIndex = $Null; $Left = $LeftNull
            $RightIndex = 0; foreach ($Right in $RightList) {
                if (!$InnerRight -or !$InnerRight[$RightIndex]) {
                    if (&([scriptblock]::Create($Where))) { OutObject -LeftIndex $LeftIndex -RightIndex $RightIndex }
                }
                $RightIndex++
            }
        }
    }
}; 
Set-Alias Join Join-Object

$JoinCommand = Get-Command Join-Object
$MetaData = [System.Management.Automation.CommandMetadata]$JoinCommand
$ProxyCommand = [System.Management.Automation.ProxyCommand]::Create($MetaData)
$ParamBlock, $ScriptBlock = $ProxyCommand -Split '\r?\n(?=begin\r?\n)', 2

$Proxies =
    @{ Name = 'InnerJoin-Object'; Alias = 'InnerJoin'; Default = "JoinType = 'Inner'" },
    @{ Name = 'LeftJoin-Object';  Alias = 'LeftJoin';  Default = "JoinType = 'Left'" },
    @{ Name = 'RightJoin-Object'; Alias = 'RightJoin'; Default = "JoinType = 'Right'" },
    @{ Name = 'FullJoin-Object';  Alias = 'FullJoin';  Default = "JoinType = 'Full'" },
    @{ Name = 'OuterJoin-Object'; Alias = 'OuterJoin'; Default = "JoinType = 'Outer'" },
    @{ Name = 'CrossJoin-Object'; Alias = 'CrossJoin'; Default = "JoinType = 'Cross'" },
    @{ Name = 'Update-Object';    Alias = 'Update';    Default = "JoinType = 'Left'",  "Property = @{ '*' = 'Right.*' }" },
    @{ Name = 'Merge-Object';     Alias = 'Merge';     Default = "JoinType = 'Full'",  "Property = @{ '*' = 'Right.*' }" },
    @{ Name = 'Get-Difference';   Alias = 'Differs';   Default = "JoinType = 'Outer'", "Property = @{ '*' = 'Right.*' }" }

foreach ($Proxy in $Proxies) {
    $ProxyCommand = @(
        $ParamBlock
        'DynamicParam  {'
        foreach ($Default in @($Proxy.Default)) { '    $PSBoundParameters.' + $Default }
        '}'
        $ScriptBlock
    ) -Join [Environment]::NewLine
    $Null = New-Item -Path Function:\ -Name $Proxy.Name -Value $ProxyCommand -Force
    Set-Alias $Proxy.Alias $Proxy.Name
}

if ($PSBoundParameters.ContainsKey('Test') -or !$args ) {
	# https://github.com/iRon7/Join-Object
    $Employee=@( 
		[pscustomobject]@{Id=1; Name="Aerts";   Country="Belgium"; Department="Sales";        Age=40;  ReportsTo=5;     },
		[pscustomobject]@{Id=2; Name="Bauer";   Country="Germany"; Department="Engineering";  Age=31;  ReportsTo=4;     },
		[pscustomobject]@{Id=3; Name="Cook";    Country="England"; Department="Sales";        Age=69;  ReportsTo=1;     },
		[pscustomobject]@{Id=4; Name="Duval";   Country="France";  Department="Engineering";  Age=21;  ReportsTo=5;     },
		[pscustomobject]@{Id=5; Name="Evans";   Country="England"; Department="Marketing";    Age=35;  ReportsTo=$null; },
		[pscustomobject]@{Id=6; Name="Fischer"; Country="Germany"; Department="Engineering";  Age=29;  ReportsTo=4;     }
	)
	
	$Department=@( 
		[pscustomobject]@{Name="Engineering";  Country="Germany";  },
		[pscustomobject]@{Name="Marketing";    Country="England";  },
		[pscustomobject]@{Name="Sales";        Country="France";   },
		[pscustomobject]@{Name="Purchase";     Country="France";   }
	)
	
	$Changes = @(
		[pscustomobject]@{ ID=3; Name="Cook";    Country="England"; Deparatment="Sales";       Age="69"; ReportsTo=5; },
		[pscustomobject]@{ ID=6; Name="Fischer"; Country="France";  Deparatment="Engineering"; Age="29"; ReportsTo=4; },
		[pscustomobject]@{ ID=7; Name="Geralds"; Country="Belgium"; Deparatment="Sales";       Age="71"; ReportsTo=1; }
	)
	
	$Location=(
		[pscustomobject]@{ LocId=1; City="Jersey City"; House=@{Number=159; Street="2nd Str";  Zip="07302"; } },
		[pscustomobject]@{ LocId=2; City="Jersey City"; House=@{Number=158; Street="2nd Str";  Zip="07302"; } },
		[pscustomobject]@{ LocId=3; City="Jersey City"; House=@{Number=157; Street="2nd Str";  Zip="07302"; } }
	)
	
	$P1=@{ ID=10; Name=@{ First='Alex'; Last='Evteev'};  Location=$Location[0]; LocId=1;     }
    $P2=@{ ID=11; Name=@{ First='Kira'; Last='Evteeva'}; Location=$Location[1]; LocId=2;     }
	$P3=@{ ID=12; Name=@{ First='Kira'; Last='Evteeva'}; Location=$null; LocId=$null; }
	$P4=@{ ID=13; Name=@{ First='Kira'; Last='Evteeva'}; }
	
	$MyPeople+=@(
		[pscustomobject]$P1, 
		[pscustomobject]$P2,
		[pscustomobject]$P3,
		[pscustomobject]$P4
	)
	$a = 'a1', 'a2', 'a3', 'a4'
	$b = 'b1', 'b2', 'b3', 'b4'
	$c = 'c1', 'c2', 'c3', 'c4'
	$d = 'd1', 'd2', 'd3', 'd4'	
	echo "Test: $Test"
	switch ($Test) {
		1  { 
			echo '# Join the employees with the departments based on the country'
			# $Employee|Format-Table *; $Department|Format-Table *
			echo '$Employee | InnerJoin $Department -On Country | Format-Table } ; '
			$Employee | InnerJoin $Department -On Country | Format-Table 
		} ;
		2  { 
			echo '# Full join the employees with the departments based on the department name'
			# $Employee|Format-Table *; $Department|Format-Table *; 
			echo '$Employee | InnerJoin $Department -On Department -Equals Name -Discern Employee, Department | Format-Table } ;'
			$Employee | InnerJoin $Department -On Department -Equals Name -Discern Employee, Department | Format-Table 
		} ;
		3  { 
			echo '# Apply the changes to the employees'
			#  $Employee|Format-Table *; $Changes   |Format-Table *; 
			echo '$Employee | Merge  $Changes    -On Id      | Format-Table'
			$Employee | Merge  $Changes    -On Id      | Format-Table 
		} ;
		4  { 
			echo '# (Self) join each employee with its each manager';
			echo "LeftJoin $Employee -On ReportsTo -Equals Id -Property @{ Name = 'Left.Name' }, @{ Manager = 'Right.Name' }"
			LeftJoin $Employee -On ReportsTo -Equals Id -Property @{ Name = 'Left.Name' }, @{ Manager = 'Right.Name' }
		} 
		5  { 
			echo '# Add an Id to the department list';
			echo '1..9 |Join $Department -ValueName Id'
			1..9 |Join $Department -ValueName Id
		} 
		6  { 
			echo '# Join (transpose) multiple arrays to a collection array';
			echo '$a |Join $b |Join $c |Join $d |% { "$_" }'
			$a |Join $b |Join $c |Join $d |% { "$_" }
		} ;
		7  { 
			echo '# Create objects with named properties from multiple arrays';
			echo '$a |Join $b |Join $c |Join $d -Name a, b, c, d'
			$a |Join $b |Join $c |Join $d -Name a, b, c, d
		} ;
		11 { 
			#  $Location|Format-Table *; 
			#  $MyPeople  |Format-Table *; echo "***"; 
			echo '# Merge'
			echo '$MyPeople | Merge $Location   -On Id      | Format-Table -auto -wrap * ' 
			$MyPeople | Merge $Location   -On Id      | Format-Table -auto -wrap * 
		};
		12 { 
			# $Location|Format-Table *; $MyPeople  |Format-Table *; 
			echo '# Test Types of Join'
			foreach ($Action in @("Merge", "InnerJoin", "LeftJoin", "RightJoin", "FullJoin", "OuterJoin") ) {
				echo " `$MyPeople | $Action `$Location -on Id"; 
				& $Action -LeftObject:$MyPeople -On LocId -RightObject:$Location     | Format-Table -auto -wrap * 
			}
		}
	}

} else {
	if ($PSBoundParameters.ContainsKey('Measure')) {
		$args
		Measure-Command -expression { & Join-Object @args }
	} else {
		Join-Object @args
	}
}

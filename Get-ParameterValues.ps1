# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
# [CmdletBinding()]
param( $Name = $Env:UserName, [int[]]$Numbers=@(20,30,41,51), [string[]]$Strings=@("one","","two three"), $not_set)
function Get-ParameterValues {
    <#
        .Synopsis
            Get the actual values of parameters which have manually set (non-null) default values or values passed in the call
        .Description
            Unlike $PSBoundParameters, the hashtable returned from Get-ParameterValues includes non-empty default parameter values.
            NOTE: Default values that are the same as the implied values are ignored (e.g.: empty strings, zero numbers, nulls).
        .Example
            function Test-Parameters {
                [CmdletBinding()]
                param(
                    $Name = $Env:UserName,
                    $Age
                )
                $Parameters = . Get-ParameterValues
                # This WILL ALWAYS have a value... 
                Write-Host $Parameters["Name"]
                # But this will NOT always have a value... 
                Write-Host $PSBoundParameters["Name"]
            }
    #>
    [CmdletBinding()]
    param(
        # The $MyInvocation for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $Invocation = $MyInvocation,
        # The $PSBoundParameters for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $BoundParameters = $PSBoundParameters
    )

    if($MyInvocation.Line[($MyInvocation.OffsetInLine - 1)] -ne '.') {
        throw "Get-ParameterValues must be dot-sourced, like this: . Get-ParameterValues"
    }

    if($PSBoundParameters.Count -gt 0) {
        throw "You should not pass parameters to Get-ParameterValues, just dot-source it like this: . Get-ParameterValues"
    }

    $ParameterValues = @{}
    foreach($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
        # gm -in $parameter.Value | Out-Default
        try {
            $key = $parameter.Key
            if($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore)) {
                if($value -ne ($null -as $parameter.Value.ParameterType)) {
                    $ParameterValues[$key] = $value
                }
            }
            if($BoundParameters.ContainsKey($key)) {
                $ParameterValues[$key] = $BoundParameters[$key]
            }
        } finally {}
    }
    $ParameterValues
}

function Test-Parameters {
	# [CmdletBinding()]
	param(
		$Name = $Env:UserName,
		$Age
	)
	$Parameters = . Get-ParameterValues
	$Parameters
	# This WILL ALWAYS have a value... 
	Write-Host $Parameters["Name"]
	# But this will NOT always have a value... 
	Write-Host $PSBoundParameters["Name"]
}



write-output "`n`n * Start"


$Parameters = . Get-ParameterValues
$Parameters
# scriptblock to print out hashtable $Parameters and array $args
$TestArgsPrint = {
	write-output "== 1 ================="
	write-output "Parameters[$($Parameters.Count)]: $(($Parameters.GetEnumerator().ForEach({ "$(($_).Key)=$(($_).Value)" })) -join '; ')"  
	write-output "== 2 ================="
	write-output "Parameters[$($Parameters.Count)]: $(($Parameters.GetEnumerator()  | % { "$($_.Key)=$($_.Value)" }) -join '; ')"
	write-output "== 3 ================="
	write-output "Parameters[$($Parameters.Count)]: $(($Parameters.GetEnumerator().ForEach({ "$($_.Key)=$($_.Value)" })) -join '; ')"
	write-output "== 4 ================="
	write-output "Parameters[$($Parameters.Count)]: $($Parameters.Keys    | % { "$_=$($Parameters.$_ -join ',')" })"
	write-output "== Args =============="
	write-output "args[$(($args).Length)]: $($args -join '; ')"
}.GetNewClosure() 

$expanded    = $ExecutionContext.InvokeCommand.ExpandString($TestArgsPrint)
$expanded.ToString()

<#
write-output " ** Get-ScriptDirectory"
Get-ScriptDirectory
#>

# another way to print out hashtable $PSBoundParameters
# [string[]] $l_array = ($PSBoundParameters | Out-String -Stream) -ne '' | select-object -Skip 2; write-output "PSBoundParameters[$(($l_array).Length)]: $($l_array -join '; ')"


# another way to print out array $args
# write-output "args[$(($args).Length)] : $($args -join ';')"

# simplest way to print out hashtable $PSBoundParameters
# $PSBoundParameters

# "one","two" | TestInput @PSBoundParameters

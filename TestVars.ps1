param([Parameter(ValueFromRemainingArguments = $true)] [Object[]]$OtherArgs )

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' } else { $DebugPreference = 'SilentlyContinue' }
if ($PSBoundParameters.ContainsKey('Trace')) { Set-PSDebug -Trace $Trace }

# $DebugPreference = 'SilentlyContinue'
# Set-PSDebug -Trace 1 # turn on tracing
# Set-PSDebug -Trace 0 # turn off tracing
# Trace-Command –Name CommandDiscovery –Expression {ping localhost} | Out-File 
# Trace-Command –Name CommandDiscovery -FilePath C:\home\script\test1.trace_command.output –Command C:\home\script\test1.ps1 -Args @("-NoOfEvents",2)

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

function Get-Events2 () {
	[CmdletBinding( SupportsShouldProcess = $true, ConfirmImpact = 'Medium' )]
	param([int[]]$Levels=$null, [int] $NoOfEvents=2000 )

	# if ($Levels -eq $null) { write-output "Levels is not set" } else { write-output "Levels[$(($Levels).length)] : $($Levels -join ' ')" }
	
	[ScriptBlock] $ScriptBlock={ Get-WinEvent * -maxevent $NoOfEvents -ea 0 |  Where-Object { $null -eq $Levels -or $_.Level -in $Levels } | Group-Object LogName,ProviderName,Level }
	
	# $expanded = $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
	$newClosure = $ScriptBlock.GetNewClosure()
#$expanded.ToString()
	if ($PSCmdlet.ShouldProcess($newClosure.ToString(), "Execute")) {
		& $newClosure
	} 	
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


function Test-PsCallStack {
	#https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-pscallstack?view=powershell-7.2
	write-output '[PsCallStack] -- start --------------------'
	write-output "args[$(($args).length)] : $($args -join ' ')"
	$p = $args[0]
	write-output '[PsCallStack] -- Get-Alias --------------------'
	Get-Alias | Where-Object {$_.definition -like "*$p"} | format-table definition, name -auto
	write-output '[PsCallStack] -- get-pscallstack --------------------'
	get-pscallstack
	write-output '[PsCallStack] -- end ----------------------'
}

function Test-Invoke-Expression {
	write-output '[Test-Invoke-Expression] -- start ----------------------'
	$Cmdlet_name = "Get-ComputerInfo"
	$Example_number = 1
	$Example_code = (Get-Help $Cmdlet_name).examples.example[($Example_number-1)].code
	Invoke-Expression $Example_code
	write-output '[Test-Invoke-Expression] -- end ----------------------'	
}

function Test-AutoVars { 
	write-output '[Test-AutoVars] $EventArgs:'
	$EventArgs
	write-output '-- end of ----------'
	write-output '[Test-AutoVars] $EventArgs|select-object * :'
	$EventArgs | select-object *
	write-output '-- end of ----------'
	write-output '[Test-AutoVars] $PSItem:';             $PSItem; write-output '-- end of ----------'
	write-output '[Test-AutoVars] $_';                        $_; write-output '-- end of ----------'	

}

function Test-Args { 
	write-output "[Test-Args] == START ================"
	write-output "args[$(($args).length)] : $($args -join ' ')"
	write-output "[Test-Args] == END =================="
}

function TestPrint
{
    param($a, $b, $c, $d="set")

    "Test1 a:$a b:$b c:$c d:$d"
}

function TestCall
{
    param($a, $b, $c)
	
	write-output "Test Call PSBoundParameters[$($PSBoundParameters.Count)]" $PSBoundParameters
	
	$PSBoundParameters.Count
	
	write-output "Test Call Args[$(($Args).Length)]:"  $Args

    #Call the TestPrint function with $a, $b, and $c.
    TestPrint @PsBoundParameters

    #Call the TestPrint function with $b and $c, but not with $a
    $LimitedParameters = $PSBoundParameters
    $LimitedParameters.Remove("a") | Out-Null
    TestPrint @LimitedParameters @args
}


function Get-Sample {
  [CmdletBinding()]
  Param([string]$Name, [string]$Path)

  DynamicParam
  {
    if ($Path.StartsWith("HKLM:"))
    {
      $parameterAttribute = [System.Management.Automation.ParameterAttribute]@{
          ParameterSetName = "ByRegistryPath"
          Mandatory = $false
      }

      $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
      $attributeCollection.Add($parameterAttribute)

      $dynParam1 = [System.Management.Automation.RuntimeDefinedParameter]::new(
        'KeyCount', [Int32], $attributeCollection
      )

      $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
      $paramDictionary.Add('KeyCount', $dynParam1)
      return $paramDictionary
    }
  }
}


function TestInput
{
    begin
    {
        $i = 0
    }

    process
    {
        "Iteration: $i"
        $i++
        "`tInput: $input"
        "`tAccess Again: $input"
        $input.Reset()
        "`tAfter Reset: $input"
    }
}


<# 
# scriptblock to print out hashtable $PSBoundParameters and array $args
$TestArgsPrint = {
	write-output "== 1 ================="
	write-output "PSBoundParameters[$($PSBoundParameters.Count)]: $(($PSBoundParameters.GetEnumerator().ForEach({ "$(($_).Key)=$(($_).Value)" })) -join '; ')"  
	write-output "== 2 ================="
	write-output "PSBoundParameters[$($PSBoundParameters.Count)]: $(($PSBoundParameters.GetEnumerator()  | % { "$($_.Key)=$($_.Value)" }) -join '; ')"
	write-output "== 3 ================="
	write-output "PSBoundParameters[$($PSBoundParameters.Count)]: $(($PSBoundParameters.GetEnumerator().ForEach({ "$($_.Key)=$($_.Value)" })) -join '; ')"
	write-output "== 4 ================="
	write-output "PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys    | % { "$_=$($PSBoundParameters.$_ -join ',')" })"
	write-output "== Args =============="
	write-output "args[$(($args).Length)]: $($args -join '; ')"
}.GetNewClosure() 

# $expanded    = $ExecutionContext.InvokeCommand.ExpandString($TestArgsPrint)
# $expanded.ToString()
#>


# another way to print out hashtable $PSBoundParameters
# [string[]] $l_array = ($PSBoundParameters | Out-String -Stream) -ne '' | select-object -Skip 2; write-output "PSBoundParameters[$(($l_array).Length)]: $($l_array -join '; ')"


# another way to print out array $args
# write-output "args[$(($args).Length)] : $($args -join ';')"

# simplest way to print out hashtable $PSBoundParameters
# $PSBoundParameters

# "one","two" | TestInput @PSBoundParameters

#  Get-TraceSource , defines names of available TraceSources

# write-output "`n`n * Set `$Parameters"
$Parameters = . Get-ParameterValues
# $Parameters

function CodeExecutor {
	# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
    param (
        # Define the piece of functionality to accept as a [scriptblock]
        [string]$command="TopEvents"
    )
	write-output '[CodeExecutor] -- start ----------------------'
	write-output "command: $command; args[$(($args).length)] : $($args -join ' ')"
    
	Invoke-Command -ScriptBlock { & $command @args} -ArgumentList $args
    # Invoke the script block with `&`
	write-output '[CodeExecutor] -- end ----------------------'	    
	TopEvents @args
}

# write-output "`n`n * Call 1"
# CodeExecutor @Parameters

# break 
# CodeExecutor @Parameters

# Test-PsCallStack Get-Content @PSBoundParameters
# Test-Parameters @PSBoundParameters

# write-output "`n`n * Call 2"
# Test-Args @Parameters
# Measure-Command -Expression { Test-Args @Parameters }


# write-output "end"

# trace-command ParameterBinding -Expression { Test-Args @Parameters } # not clear what ParameterBinding does ?
# Test-AutoVars @PSBoundParameters

# TestCall -a 1 -b 2 -c 3 -d "- D -"

if ($PSBoundParameters.ContainsKey('Trace')) { Set-PSDebug -Trace 0 }

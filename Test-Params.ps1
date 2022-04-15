param( $Name = $Env:UserName, [int[]]$Numbers=@(20,30,41,51), [string[]]$Strings=@("one","","two three"), $not_set)
function Get-ScriptDirectory {
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

function Test-Params1 {
    # [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)] [Object[]]$OtherArgs )
    
    write-output "`n ** Test-Params1 start"

    $params = @{}
    foreach($h in $MyInvocation.MyCommand.Parameters.GetEnumerator()) {
        try {
            $key = $h.Key
            $val = Get-Variable -Name $key -ErrorAction Stop | Select-Object -ExpandProperty Value -ErrorAction Stop
            if (([String]::IsNullOrEmpty($val) -and (!$PSBoundParameters.ContainsKey($key)))) {
                throw "A blank value that wasn't supplied by the user."
            }
            Write-Verbose "$key => '$val'"
            $params[$key] = $val
        } catch {}
    }
    write-output "`n *** Test-Params1 local params"        
    
    $params

    $params = @{}
    $CallerInvocation = (Get-Variable MyInvocation -Scope 1).Value
    foreach($h in $CallerInvocation.MyCommand.Parameters.GetEnumerator()) {
        try {
            $key = $h.Key
            $val = Get-Variable -Name $key -ErrorAction Stop | Select-Object -ExpandProperty Value -ErrorAction Stop
            if (([String]::IsNullOrEmpty($val) -and (!$PSBoundParameters.ContainsKey($key)))) {
                throw "A blank value that wasn't supplied by the user."
            }
            Write-Verbose "$key => '$val'"
            $params[$key] = $val
        } catch {}
    }

    write-output "`n *** Test-Params1 caller params"
    $params
    write-output "`n ** Test-Params1 end"
}

function Test-Params2 {
  param(
      [switch] $SkipGetList,
      [switch] $DisableHistory,
      [datetime] $ComputationDate,
      [string] $RefVersion,
      [string] $WorkingDir,
      [int[]] $Indices
  )
  write-output "`n ** Test-Params2 start"

  # Get this function's invocation as a command line 
  # with literal (expanded) values.
  '{0} {1}' -f `
    $MyInvocation.InvocationName, # the function's own name, as invoked
    ($(foreach ($bp in $PSBoundParameters.GetEnumerator()) { # argument list
      $valRep =
        if ($bp.Value -is [switch]) { # switch parameter
          if ($bp.Value) { $sep = '' } # switch parameter name by itself is enough
          else { $sep = ':'; '$false' } # `-switch:$false` required
        }
        else { # Other data types, possibly *arrays* of values.
          $sep = ' '
          foreach ($val in $bp.Value) {
            if ($val -is [bool]) { # a Boolean parameter (rare)
              ('$false', '$true')[$val] # Booleans must be represented this way.
            } else { # all other types: stringify in a culture-invariant manner.
              if (-not ($val.GetType().IsPrimitive -or $val.GetType() -in [string], [datetime], [datetimeoffset], [decimal], [bigint])) {
                Write-Warning "Argument of type [$($val.GetType().FullName)] will likely not round-trip correctly; stringifies to: $val"
              }
              # Single-quote the (stringified) value only if necessary
              # (if it contains argument-mode metacharacters).
              if ($val -match '[ $''"`,;(){}|&<>@#]') { "'{0}'" -f ($val -replace "'", "''") }
              else { "$val" }
            }
          }
        }
      # Synthesize the parameter-value representation.
      '-{0}{1}{2}' -f $bp.Key, $sep, ($valRep -join ', ')
    }) -join ' ') # join all parameter-value representations with spaces

  write-output "`n ** Test-Params2 end"
}

function Test-Params3 {
    param ( [string] $SetVar = 'test value', [string[]] $SetArr = @('val 1', '', 'val 2'), [string] $NotSetVar )
    write-output "`n ** Test-Params3 start"
    write-output "`n *** Test-Params3 local params"
    $ParameterList = (Get-Command -Name $MyInvocation.MyCommand).Parameters
    $ParameterList
    foreach ($key in $ParameterList.keys) {
        Clear-Variable var -ErrorAction SilentlyContinue
        $var = Get-Variable -Name $key -ErrorAction SilentlyContinue
        if($var) {
            write-host " *** Var:$($var.name) ; Val: $($var.value)"
        }
    }
    write-output "`n *** Test-Params3 caller params"
    $CallerInvocation = (Get-Variable MyInvocation -Scope 1).Value
    $CallerParameterList = $CallerInvocation.MyCommand.Parameters;
    $CallerParameterList
    foreach ($key in $CallerParameterList.keys) {
        Clear-Variable var -ErrorAction SilentlyContinue
        $var = $CallerParameterList.$key
        if($CallerParameterList.$key) {
            write-host " *** Var:$($var.name) ; Val: $($var.value)"
        }
    }

    write-output "`n ** Test-Params3 end"
}


write-output " ** `$MyInvocation.MyCommand.Parameters =="
$MyInvocation.MyCommand.Parameters
write-output " ** `$MyInvocation.MyCommand.Parameters =="

Test-Params1 @args
Test-Params2 @args
Test-Params3 @args



param( 
  [String] $Param1 = $Env:UserName, 
  [int[]]$ParamIntArr=@(20,30,41,51), 
  [string[]]$ParamStrArr=@("one","","two three"), 
  $ParamNotSet
  )
# Jeffery Hicks
# http://jdhitsolutions.com/blog
# follow on Twitter: http://twitter.com/JeffHicks
#
# 
# "Those who forget to script are doomed to repeat their work."

#  ****************************************************************
#  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
#  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
#  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
#  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
#  ****************************************************************

Function Get-Parameter {
  <#
  .Synopsis
      Retrieve command parameter information.
  .Description
      Using Get-Command, this function will return information about parameters 
      for any loaded cmdlet or function. The common parameters like Verbose and
      ErrorAction are omitted. Get-Parameter returns a custom object with the most
      useful information an administrator might need to know. Here is an example:
      
      Position          : 0
      Name              : Name
      Type              : System.String[]
      Aliases           : {ServiceName}
      ValueFromPipeline : True
      Mandatory         : False
      ParameterSet      : Default
  
  .Parameter Command
      The name of a cmdlet or function. The parameter has an alias of Name.
  .Example
      PS C:\> get-parameter get-service
  
      Return parameter information for get-service
  .Example
  PS C:\Scripts> get-parameter mkdir | select Name,type 
  Found 6 specific parameters for mkdir
  
  Name                        Type
  ----                        ----
  Path                        System.String[]
  Name                        System.String
  Value                       System.Object
  Force                       System.Management.Automation.SwitchParameter
  Credential                  System.Management.Automation.PSCredential
  UseTransaction              System.Management.Automation.SwitchParameter
  .Example
  PS C:\Scripts> get-parameter get-wmiobject | sort parameterset | format-table -GroupBy ParameterSet -Property Name,Alias,Position,Type -autosize
  Found 18 non-common parameters for get-wmiobject
  
  
     ParameterSet: __AllParameterSets
  
  Name          Alias Position Type
  ----          ----- -------- ----
  ThrottleLimit                System.Int32
  Amended                      System.Management.Automation.SwitchParameter
  AsJob                        System.Management.Automation.SwitchParameter
  
  
     ParameterSet: class
  
  Name          Alias Position Type
  ----          ----- -------- ----
  Locale                       System.String
  Impersonation                System.Management.ImpersonationLevel
  
  
     ParameterSet: list
  
  Name         Alias Position Type
  ----         ----- -------- ----
  Namespace                   System.String
  ComputerName                System.String[]
  Authority                   System.String
  List                        System.Management.Automation.SwitchParameter
  Recurse                     System.Management.Automation.SwitchParameter
  
  
     ParameterSet: query
  
  Name                Alias Position Type
  ----                ----- -------- ----
  Filter                             System.String
  Property                  1        System.String[]
  Class                     0        System.String
  EnableAllPrivileges                System.Management.Automation.SwitchParameter
  DirectRead                         System.Management.Automation.SwitchParameter
  
  
     ParameterSet: WQLQuery
  
  Name           Alias Position Type
  ----           ----- -------- ----
  Query                         System.String
  Credential                    System.Management.Automation.PSCredential
  Authentication                System.Management.AuthenticationLevel
  
  .Inputs
      [string]
  .Outputs
      custom object
  .Link
      http://jdhitsolutions.com/blog/2010/07/get-parameter
  .Link
      Get-Command
      
  .Notes
   NAME:      Get-Parameter
   VERSION:   1.2
   AUTHOR:    Jeffery Hicks
   LASTEDIT:  July 20, 2010
   
   Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
   #>
  
  Param(
  [Parameter(Position=0,Mandatory=$True,
  ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
  HelpMessage="Enter a cmdlet name")]
  [ValidateNotNullorEmpty()]
  [Alias("name")]
  [string]$command
  )
  
  Process {
      #define the set of common parameters to exclude
      $common=@("Verbose",
      "Debug",
      "ErrorAction",
      "ErrorVariable",
      "WarningAction",
      "WarningVariable",
      "OutVariable",
      "OutBuffer",
      "WhatIf",
      "Confirm")
  
      Try {
          $data=(Get-Command -Name $command -errorAction "Stop").parameters
      }
      Catch {
          Write-Warning "Failed to find command $command"
      }
      #keep going if parameters were found
      if ($data.count -gt 0) {
          #$data is a hash table
          $params=$data.keys | where {$common -notcontains $_} 
          $count=($params | measure-object).count
          #only keep going if non-common parameters were found
          write-host "Found $count non-common parameters for $command" `
          -ForegroundColor Green
          
          if ($count -gt 0) {
              #get information from each parameter
              
              $params | foreach {
                  $name=$_
                  $type=$data.item($name).ParameterType
                  $aliases=$data.item($name).Aliases
                  $attributes=$data.item($name).Attributes
                  if ($attributes[0].position -ge 0) {
                      $position=$attributes[0].position
                    }
                  else {
                      $position=$null
                  }
                  #write a custom object to the pipeline    
                  New-Object -TypeName PSObject -Property @{
                      Name=$name
                      Aliases=$aliases
                      Mandatory=$attributes[0].mandatory
                      Position=$position
                      ValueFromPipeline=$attributes[0].ValueFromPipeline
                      Type=$type
                      ParameterSet=$attributes[0].ParameterSetName
                  } 
              } #foreach
          } #if $count
       } #if $data
       else {
          Write-Host "$command has no defined parameters" -ForegroundColor Red
       }
   } #process
} #end function  
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

function Get-MyInvocation1 { 
  $MyInvocation | format-list
}


function Get-MyInvocation { 
  write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"
  (Get-Variable MyInvocation -Scope 1) | format-list
}


function Get-MyInvocationValue { 
  write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"
  (Get-Variable MyInvocation -Scope 1).Value | format-list
}


function Get-MyCommand { 
  write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"
  write-output " ** $($MyInvocation.Line.trim()) MyCommand"
  (Get-Variable MyInvocation -Scope 1).Value.MyCommand | 
    format-list Path, Definition, Source, Visibility, # ScriptBlock, ScriptContents,
      OutputType, OriginalEncoding, Name, CommandType, Version, ModuleName, Module, RemotingCapability, Parameters, ParameterSets, HelpUri
  
  write-output " ** $($MyInvocation.Line.trim()) BoundParameters"
  (Get-Variable MyInvocation -Scope 1).Value.BoundParameters | format-list

  write-output " ** $($MyInvocation.Line.trim()) UnboundArguments"
  (Get-Variable MyInvocation -Scope 1).Value.UnboundArguments | format-list


}

function Get-Args { 
  write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"
  write-output " ** $($MyInvocation.Line.trim()) Args"
  $ScriptArgs=(Get-Variable Args -Scope 1).Value
  $OutStr="args[$($ScriptArgs.Length)]"
  #$OutStr="args"
  for($i=0; $i -lt $ScriptArgs.Length; $i++) { $OutStr+=" [$i]`:$($ScriptArgs[$i])"}
  # $OutStr.Trim(", ")
  $OutStr
}
function Get-Var { 
  param( $varname )
  write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"
  # $argv
  $Var = (Get-Variable $varname -Scope 1).Value
}

function Get-MyParameters { 
  Param(
    [Parameter(Position=0,Mandatory=$True,
    ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
    HelpMessage="Enter a cmdlet name")]
    [ValidateNotNullorEmpty()]
    [Alias("name")]
    [string]$command
    )
    
  Process {
    write-output " ** $($MyInvocation.Line.trim()) ** at $($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber) char:$($MyInvocation.OffsetInLine)"

    #define the set of common parameters to exclude
    $common=@("Verbose",
    "Debug",
    "ErrorAction",
    "ErrorVariable",
    "WarningAction",
    "WarningVariable",
    "OutVariable",
    "OutBuffer",
    "WhatIf",
    "Confirm")

    Try {
        $data=(Get-Command -Name $command -errorAction "Stop").parameters
    }
    Catch {
        Write-Warning "Failed to find command $command"
    }
    #keep going if parameters were found
    if ($data.count -gt 0) {
        #$data is a hash table
        $params=$data.keys | where {$common -notcontains $_} 
        $count=($params | measure-object).count
        #only keep going if non-common parameters were found
        write-host "Found $count non-common parameters for $command" `
        -ForegroundColor Green
        
        if ($count -gt 0) {
            #get information from each parameter
            
            $params | foreach {
                $name=$_
                $type=$data.item($name).ParameterType
                $aliases=$data.item($name).Aliases
                $attributes=$data.item($name).Attributes
                if ($attributes[0].position -ge 0) {
                    $position=$attributes[0].position
                  }
                else {
                    $position=$null
                }
                #write a custom object to the pipeline    
                New-Object -TypeName PSObject -Property @{
                    Name=$name
                    Aliases=$aliases
                    Mandatory=$attributes[0].mandatory
                    Position=$position
                    ValueFromPipeline=$attributes[0].ValueFromPipeline
                    Type=$type
                    ParameterSet=$attributes[0].ParameterSetName
                } 
            } #foreach
        } #if $count
     } #if $data
     else {
        Write-Host "$command has no defined parameters" -ForegroundColor Red
     }
 } #process  
<#   
  $MyParameters=@{}
  write-output " ** $($MyInvocation.Line.trim()) BoundParameters"
  (Get-Variable MyInvocation -Scope 1).Value.BoundParameters | format-list
  write-output " ** $($MyInvocation.Line.trim()) UnboundArguments"

  write-output " ** $($MyInvocation.Line.trim()) Parameters"
  # (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Parameters  | ForEach { $MyParameters["$($_.Key)"]=$_.Value }  # | Format-List
  # (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Parameters.Keys  | ForEach { $MyParameters["$_"]=(Get-Variable MyInvocation -Scope 1).Value.MyCommand.Parameters.$_ }  # | Format-List
  $MyParamDict=(Get-Variable MyInvocation -Scope 1).Value.MyCommand.Parameters
  $MyParamDict.Keys | % { $MyParameters["$_"]=$MyParamDict.$_ }
  [hashtable]$MyParameters = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Parameters 

  # .Keys | ForEach { $MyParameters["$_"]=(Get-Variable -Name $_  -Scope 1 -EA SilentlyContinue).Value }
  write-output " ** $($MyInvocation.Line.trim()) UnboundArguments"
  # (Get-Variable MyInvocation -Scope 1).Value.UnboundArguments   | Format-List
  # ConvertFrom-StringData $((Get-Variable MyInvocation -Scope 1).Value.UnboundArguments.ToString())  | Format-List
  # $MyParameters += (Get-Variable MyInvocation -Scope 1).Value.UnboundArguments
  # ConvertFrom-StringData 
  # | ForEach { $MyParameters["$_.Key"]=$_.Value}

  write-output " ** $($MyInvocation.Line.trim()) MyParameters"
  # $MyParameters| % { $_.Value | Format-List  }
  # $MyParameters | % { $MyParameters.$($_.Name) | Format-List  }
  $MyParameters.Keys | ForEach { write-output " *** $($MyInvocation.Line.trim()) MyParameters.$_" ; $MyParameters.$_ | Format-List  }
  # $MyParameters.ParamStrArr | Format-List  
  # $MyParameters
#>

}

# Get-MyInvocationValue test-var-1
# Get-MyCommand
# Get-Var "PSScriptRoot"
# Get-Args
Get-MyParameters
break 

write-output " ** Orig PSBoundParameters "
$PSBoundParameters

# https://localcoder.org/parameters-with-default-value-not-in-psboundparameters
foreach($localP in $MyInvocation.MyCommand.Parameters.Keys) {
    if(!$PSBoundParameters.ContainsKey($localP)) {
        $PSBoundParameters.Add($localP, (Get-Variable -Name $localP -ValueOnly -ea 0))
    }        
}

write-output " ** Updated `$PSBoundParameters "
$PSBoundParameters

break

# $ScriptInvocation = (Get-Variable MyInvocation).Value
# $ScriptInvocation.Parameters

# write-output " *** `$MyInvocation $(($MyInvocation).ToString())" # type, the same output as the next string
write-output " ** `$MyInvocation $MyInvocation"
$MyInvocation

write-output " ** `$MyInvocation.MyCommand.Parameters $(($MyInvocation).MyCommand.Parameters)"
$MyInvocation.MyCommand.Parameters

write-output " ** `$MyInvocation.MyCommand =="
$MyInvocation.MyCommand | Format-Table  Name, CommandType
$MyInvocation.MyCommand | Format-Table  Parameters
$MyInvocation.MyCommand.Parameters | select-object -ExpandProperty $_.value
# $MyInvocation.MyCommand | Format-Table  ParameterSets
# Path, Visibility, OutputType, OriginalEncoding, RemotingCapability,

break

#MyCommand.Parameters
write-output " ** `$MyInvocation end =="

Test-Params1 @args
Test-Params2 @args
Test-Params3 @args


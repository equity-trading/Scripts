# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
# [CmdletBinding()]
param($Arg1="Dflt 1",$Arg2)

# c:\home\src\Scripts\Get-ParameterValues.ps1 "The Start" -Arg1 "Arg V1" -Agr3 "Arg V3" -Agr2 "Arg V2"  V1 V2 "" " " "The End"
<#
PS C:\home\src\Scripts> c:\home\src\Scripts\Get-ParameterValues.ps1 "The Start" -Arg2 "Arg V2" -Arg1 "Arg A1" -Arg3 "Arg V3"  v1 v2 "" " " "The End"

PSBoundParameters[2]: [Arg2]='Arg V2' [Arg1]='Arg A1'
$PSBoundParameters["Arg1"]: Arg A1
$PSBoundParameters["Arg2"]: Arg V2
2. Parameters.BoundParameters[0]:
Parameters[0]: []=''

Test-Parameters start
$Parameters["Name"]: , $PSBoundParameters["Name"]: The Start
Parameters:System.Collections.Hashtable
$Parameters | Select-Object *: @{BoundParameters=System.Management.Automation.PSBoundParametersDictionary; Invocation=System.Management.Automation.InvocationInfo}
$Parameters["Name"]: 
$Parameters["Arg1"]:
args[10]: -Arg3; Arg V3; v2; ;  ; The End; -Arg2:; Arg V2; -Arg1:; Arg A1
Test-Parameters end

Get-PSBoundParameters start
1. PSBoundParameters[3]: [Arg3]='Arg V3' [Arg2]='Arg V2' [Arg1]='Arg A1'
2. PSBoundParameters[3]: [Arg3]=Arg V3,[Arg2]=Arg V2,[Arg1]=Arg A1
3. PSBoundParameters[3]: [Arg3]=Arg V3,[Arg2]=Arg V2,[Arg1]=Arg A1
4. PSBoundParameters[3]: Arg3 Arg V3,Arg2 Arg V2,Arg1 Arg A1
5. Args[6]: The Start; v1; v2; ;  ; The End
Get-PSBoundParameters end

Get-OtherArgs start
1. PSBoundParameters[4]: [Arg3]='Arg V3' [Arg2]='Arg V2' [Arg1]='Arg A1' [OtherArgs]='The Start v1 v2    The End'
2. Args[8]: The Start; -Arg3; Arg V3; v1; v2; ;  ; The End
Get-OtherArgs end

 Get-Args1 start
  1. PSBoundParameters[3]: [Arg3]='Arg V3' [Arg2]='Arg V2' [Arg1]='Arg A1'
  2. Args[6]: The Start; v1; v2; ;  ; The End
 Get-Args1 end

Get-Args start
1. Args[12]: The Start; -Arg3; Arg V3; v1; v2; ;  ; The End; -Arg2:; Arg V2; -Arg1:; Arg A1
 Get-Args1 start
  1. PSBoundParameters[3]: [Arg3]='Arg V3' [Arg2]='Arg V2' [Arg1]='Arg A1'
  2. Args[6]: The Start; v1; v2; ;  ; The End
 Get-Args1 end
Get-Args end


#>


# Credit to Joel - https://gist.github.com/Jaykul/72f30dce2cca55e8cd73e97670db0b09
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
    "Test-Parameters start"
    $Parameters = . Get-ParameterValues
    "PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys| ForEach-Object { "[$_]='$($PSBoundParameters.$_)'" })"
    'PSBoundParameters ["Arg1"]: {0} ["Arg2"]: {1}'            -f $PSBoundParameters["Arg1"],$PSBoundParameters["Arg2"]
    #"Parameters:$Parameters" ; # $Parameters | Get-Member; # 1. Parameters.BoundParameters: $(($Parameters).BoundParameters)"
    '$Parameters | Select-Object *: {0}'  -f $($Parameters | Select-Object *)
    '$Parameters ["Name"]: {0} ["Age"]: {1}' -f $Parameters["Name"], $Parameters["Age"]
    "args[$(($args).Length)]: $($args -join '; ')"
    # 'Parameters.BoundParameters | Out-String : ' -f $( $Parameters.BoundParameters | Out-String) 
    "Test-Parameters end"
} 

function Get-PSBoundParameters {
    param($Arg1,$Arg2,$Arg3="Dflt 3")
    "Get-PSBoundParameters start"
    "1. PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys| ForEach-Object { "[$_]='$($PSBoundParameters.$_)'" })"
    write-output "2. PSBoundParameters[$($PSBoundParameters.Count)]: $(($PSBoundParameters.GetEnumerator().ForEach({ "[$($_.Key)]=$($_.Value)" })) -join ',')"
    write-output "3. PSBoundParameters[$($PSBoundParameters.Count)]: $(($PSBoundParameters.GetEnumerator()|ForEach-Object { "[$($_.Key)]=$($_.Value)" }) -join ',')"
    [string[]] $l_array = ($PSBoundParameters | Out-String -Stream) -ne '' | select-object -Skip 2; write-output "4. PSBoundParameters[$(($l_array).Length)]: $($l_array -join ',')"
    "5. Args[$(($args).Length)]: $($args -join '; ')"
    "Get-PSBoundParameters end"
}

function Get-OtherArgs {
    param($Arg1,$Arg2,$Arg3="Dflt 3", [Parameter(ValueFromRemainingArguments = $true)] [Object[]]$OtherArgs )
    "Get-OtherArgs start"
    "1. PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys| ForEach-Object { "[$_]='$($PSBoundParameters.$_)'" })"
    "2. Args[$(($args).Length)]: $($args -join '; ')"
    "Get-OtherArgs end"
}


function Get-Args1 {
    param($Arg1,$Arg2,$Arg3="Dflt 3")    
    " Get-Args1 start"
    "  1. PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys| ForEach-Object { "[$_]='$($PSBoundParameters.$_)'" })"
    "  2. Args[$(($args).Length)]: $($args -join '; ')"
    " Get-Args1 end"
}

function Get-Args {
    "Get-Args start"
    "1. Args[$(($args).Length)]: $($args -join '; ')"
    Get-Args1 @args
    "Get-Args end"
}



function Get-VarInfo() {
    param($Var)
    $Out=@()
    foreach ($Attr in "Name", "Key", "Value", "Attributes" ) {
        try {
             $Out+="[$Attr]='$($Var.$Attr)'" 
        } finally {}
        # 'Name: {0} key: {1} value: {2} Type: {3} String: {4}' -f $Var.Name, $Var.key, $Var.value,  $Var.getType(), $Var.toString()
    }
    try { $Out+="[Attributes]='$($Var.Attributes | select-object * )'" } finally {}
    try { $Out+="[Attributes.Members]='$($Var.Attributes | get-member * )'" } finally {}
    $Out -join(' ')
    Get-Variable Var
#    'Name: {0} key: {1} value: {2} Type: {3} String: {4}' -f $Var.Name, $Var.key, $Var.value,  $Var.getType(), $Var.toString()

}


'Parameters: {0}' -f "$($MyInvocation.MyCommand.Parameters | select-object *)"
# Parameters: @{Comparer=System.OrdinalIgnoreCaseComparer; Count=2; Keys=System.Collections.Generic.Dictionary`2+KeyCollection[System.String,System.Management.Automation.ParameterMetadata]; Values=System.Collections.Generic.Dictionary`2+ValueCollection[System.String,System.Management.Automation.ParameterMetadata]; IsReadOnly=False; IsFixedSize=False; SyncRoot=System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.ParameterMetadata]; IsSynchronized=False}
''
foreach($parameter in $MyInvocation.MyCommand.Parameters.GetEnumerator()) {
    'parameter type(): {0} key: {1} value: {2} toString():{3}' -f $parameter.getType(), $parameter.key, $parameter.value, $parameter.toString()
    # parameter type(): System.Collections.Generic.KeyValuePair`2[System.String,System.Management.Automation.ParameterMetadata] key: Arg1 value: System.Management.Automation.ParameterMetadata toString():[Arg1, System.Management.Automation.ParameterMetadata]
    'value members: {0}' -f "$($parameter.Value | Get-Member)"
    # value members: bool Equals(System.Object obj) int GetHashCode() type GetType() string ToString() System.Collections.ObjectModel.Collection[string] Aliases {get;} System.Collections.ObjectModel.Collection[System.Attribute] Attributes {get;} bool IsDynamic {get;set;} string Name {get;set;} System.Collections.Generic.Dictionary[string,System.Management.Automation.ParameterSetMetadata] ParameterSets {get;} type ParameterType {get;set;} bool SwitchParameter {get;}
    'value values: {0}' -f "$($parameter.Value | select-object *)"
    # value values: @{Name=Arg1; ParameterType=System.Object; ParameterSets=System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.ParameterSetMetadata]; IsDynamic=False; Aliases=System.Collections.ObjectModel.Collection`1[System.String]; Attributes=System.Collections.ObjectModel.Collection`1[System.Attribute]; SwitchParameter=False}    
  
}
''

"PSBoundParameters[$($PSBoundParameters.Count)]: $($PSBoundParameters.Keys| ForEach-Object { "[$_]='$($PSBoundParameters.$_)'" })"
'PSBoundParameters ["Arg1"]: {0} ["Arg2"]: {1}'            -f $PSBoundParameters["Arg1"],$PSBoundParameters["Arg2"]
""
Test-Parameters -Arg1 $Arg1 -Arg2 $Arg2 @args
""
Get-PSBoundParameters -Arg1 $Arg1 -Arg2 $Arg2 @args
""
Get-OtherArgs -Arg1 $Arg1 -Arg2 $Arg2 @args
""
Get-Args1 -Arg1 $Arg1 -Arg2 $Arg2 @args
""
Get-Args -Arg1 $Arg1 -Arg2 $Arg2 @args
""
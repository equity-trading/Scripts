
function Get-JsonHashTable($InputObject) {
	[Reflection.Assembly]::LoadWithPartialName("System.Web.Script.Serialization")
	$JSSerializer = [System.Web.Script.Serialization.JavaScriptSerializer]::new()
	$JSSerializer.Deserialize($InputObject,'Hashtable')	
}

function Get-HashTableObject($InputObject, $Depth=2) {
	ConvertTo-JSON @PSBoundParameters | ConvertFrom-JSON
}

function Get-SerializedString2($InputObject, $Depth=3, $Iteration=0) {	
	$tArr=$InputObject.GetEnumerator()|% { 
		if ($_.Value -is [hashtable]) {
			$Depth++
			"$$q{0}$q=$q{1}$q" -f $_.Key,$(Get-HashTablePairs $_.Value $Depth )
		} elseif ($_.Value -is [array) {
		} else {
			'"{0}"="{1}"' -f $_.Key,$_.Value
		}

	}
	if ($Depth) {
		'@{{{0}}}' -f $($tArr -join(";"))
	} else {
		$tArr -join("`n")
	}
}

function Get-HashTableInfo([hashtable]$InputObject) {
	$InfoString=@($('HashCode={0}'-f $InputObject.GetHashCode()))
	$InfoString+=($InputObject.GetEnumerator()|% { '"{0}"="{1}"' -f $_.Key,$_.Value})
	# '$InfoString: {0}' -f $($InfoString -join("; "))
	ConvertFrom-StringData $($InfoString -join("`n"))
}

function Get-HashTableClone ($ht, $mode='xml') {
	$result=@{}
    switch ($mode) {
		'xml' {
			$TempCliXmlString = [System.Management.Automation.PSSerializer]::Serialize($ht, [int32]::MaxValue)
			$result=[System.Management.Automation.PSSerializer]::Deserialize($TempCliXmlString)
		}
		'ps' {
			
            foreach($key in $obj.keys) {
                $result[$key] = Get-HashTableClone $ht[$key] -mode:ps
            }
			
		}
		'json' {
			$result=ConvertTo-JSON $ht -Depth 3 | ConvertFrom-JSON -Depth 3
		}
	}
    return $result
}

function Resolve-ActionPreference {
   [CmdletBinding()]
   param (
      [Parameter(Mandatory = $true)]
      [ValidateScript( { $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' } )]
      [System.Management.Automation.PSCmdlet]
      $Cmdlet,

      [Parameter(Mandatory = $true)]
      [System.Management.Automation.SessionState]
      $SessionState,

      [Parameter(Mandatory = $false)]
      [ValidateSet('Confirm', 'Debug', 'ErrorAction', 'InformationAction', 'Verbose', 'WarningAction', 'WhatIf')]
      [string[]]
      $Action = @('Confirm', 'Debug', 'ErrorAction', 'InformationAction', 'Verbose', 'WarningAction', 'WhatIf')
   )
   $Action | ForEach-Object -Process {
      # only propagate inherited action preferences for common action parameters that were not explicitly given by arguments
      if (-not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($_)) {
         $actionPreference = $Cmdlet.SessionState.PSVariable.Get($preferenceVariables.$_)
         # only propagate inherited action preferences whose according preference variables have been given a value
         if ($actionPreference) {
            if ($SessionState -eq $ExecutionContext.SessionState) {
               Set-Variable -Scope 1 -Name $actionPreference.Name -Value $actionPreference.Value -Force -Confirm:$false -WhatIf:$false
            } else {
               $SessionState.PSVariable.Set($actionPreference.Name, $actionPreference.Value)
            }
         }
      }
   }
}

$script:preferenceVariables = @{
   'Confirm'           = 'ConfirmPreference'
   'Debug'             = 'DebugPreference'
   'ErrorAction'       = 'ErrorActionPreference'
   'InformationAction' = 'InformationPreference'
   'Verbose'           = 'VerbosePreference'
   'WarningAction'     = 'WarningPreference'
   'WhatIf'            = 'WhatIfPreference'
}

function Compare-HashTable {
	# https://www.powershellgallery.com/packages/Psx/2.1.22067.58707/Content/HashTable%5CHashTable.ps1
   [CmdletBinding()]
   [OutputType([PSCustomObject[]])]
   param (
      [Parameter(Mandatory = $true)]
      [HashTable]
      $ReferenceHashTable,

      [Parameter(Mandatory = $true)]
      [HashTable]
      $DifferenceHashTable,

      [Parameter(Mandatory = $false, DontShow)]
      [string]
      $Prefix = ''
   )
   # Resolve-ActionPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
   $ReferenceHashTable.Keys + $DifferenceHashTable.Keys | Sort-Object -Unique -PipelineVariable key | ForEach-Object -Process {
      $propertyName = if ($Prefix) { "$Prefix.$key" } else { $key }
      if ($ReferenceHashTable.ContainsKey($key) -and !$DifferenceHashTable.ContainsKey($key)) {
         [PSCustomObject]@{Key = $propertyName ; ReferenceValue = $ReferenceHashTable.$key ; SideIndicator = '<' ; DifferenceValue = $null } | Tee-Object -Variable difference
         Write-Verbose -Message $difference
      } elseif (!$ReferenceHashTable.ContainsKey($key) -and $DifferenceHashTable.ContainsKey($key)) {
         [PSCustomObject]@{Key = $propertyName ; ReferenceValue = $null ; SideIndicator = '>' ; DifferenceValue = $DifferenceHashTable.$key } | Tee-Object -Variable difference
         Write-Verbose -Message $difference
      } else {
         $referenceValue, $differenceValue = $ReferenceHashTable.$key, $DifferenceHashTable.$key
         if ($referenceValue -ne $differenceValue) {
            [PSCustomObject]@{Key = $propertyName ; ReferenceValue = $referenceValue ; SideIndicator = '<>' ; DifferenceValue = $differenceValue } | Tee-Object -Variable difference  
            Write-Verbose -Message $difference
         }
      }
   }
}
function Merge-HashTable {
   [CmdletBinding()]
   [OutputType([HashTable])]
   param(
      [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
      [HashTable[]]
      $HashTable,

      [Parameter(Mandatory = $false)]
      [string[]]
      $Exclude = @(),

      [Parameter(Mandatory = $false)]
      [switch]
      $Force
   )
   begin {
      Resolve-ActionPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
      $result = @{ }
   }
   process {
      $HashTable | ForEach-Object -Process { $_ } -PipelineVariable currentHashTable | Select-Object -ExpandProperty Keys -PipelineVariable key | ForEach-Object -Process {
         $propertyExists = $result.ContainsKey($key)
         if (-not $propertyExists -or ($Force -and $key -notin $Exclude) ) {
            $result.$key = $currentHashTable.$key
            if ($propertyExists) {
               Write-Verbose -Message "Property '$key' has been overwritten because it has been defined multiple times."
            }
         }
      }
   }
   end {
      $result
   }
}



function Compare-Hashtable1 {
    <#
        .SYNOPSIS
            Compares two hashtables and returns the differences.
        .DESCRIPTION
            Runs through two hashtables, comparing the vaules of all keys inside. Each difference found will result in an object containing values being returned.
        
            Arrays inside the hashtables are handled as well, however they must be arranged in the same order in both sides, or values will be shown as mismatched.
        .EXAMPLE
            Compare-Hashtable -ReferenceHashtable $Hash1 -DifferenceHashtable $Hash2 -IncludeEqual
            Compares the value of each key inside $Hash1 and $Hash2, and returns the result of the comparison, including values that are equal.
        .NOTES
            Author: kovergard
            Inspired by https://gist.github.com/dbroeglin/c6ce3e4639979fa250cf
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param (
        # Hashtable containing the reference values.
        [Parameter(Mandatory)]
        [Hashtable]$ReferenceHashtable,
        # Hashtable containing the values to compare against the reference values
        [Parameter(Mandatory)]
        [Hashtable]$DifferenceHashtable,
        # Defines if keys with matching values should be returned as well
        [switch]$IncludeEqual,
        # Internal parameter used to show the full path for nested hashtables 
        [Parameter(DontShow)]
        [string[]]$Path
        # TODO Additional switches: -ExcludeDifferent, -CaseSensitive 
    )
    function New-Result($Path, $Type, $RefValue, $SideIndicator, $DifValue) {
        [PSCustomObject][Ordered]@{
            Key             = $Path -join '.'
            Type            = $Type
            ReferenceValue  = $RefValue
            DifferenceValue = $DifValue
            SideIndicator   = $SideIndicator
        }
    }
    $ErrorActionPreference = 'Stop'
    # Loop through all keys in the reference hashtable.
    [Object[]]$Results = $ReferenceHashtable.Keys | ForEach-Object {
        $RefValue = $ReferenceHashtable[$_]
        $RefValueType = $RefValue.GetType().Name
        $FullPath = $Path + $_
        # Add result for keys that doesn't exist in the difference hashtable. 
        if (-not $DifferenceHashtable.ContainsKey($_)) {
            New-Result $FullPath $RefValueType $RefValue '=>' $null
        }
        else {
            $DifValue = $DifferenceHashtable[$_]
            $DifValueType = $DifValue.GetType().Name
            # Warn if the values are not of the same type
            if ($RefValueType -ne $DifValueType) {
                Write-Warning "Key $($FullPath -join '.') in the reference object is of type $RefValueType, but the corrosponding key in the difference object is of type $DifValueType. Cannot compare values."
            }
            # Handle nested arrays
            elseif ($RefValueType -eq 'Object[]') {
                $i = 0
                $RefValueCount = $RefValue.Count
                $DifValueCount = $DifValue.Count
                if ($RefValueCount -ne $DifValueCount) {
                    Write-Warning "Key $($FullPath -join '.') in the reference object is of type $RefValueType with $RefValueCount entries, but the corrosponding key in the difference object only have $DifValueCount entries. Cannot compare values."                    
                }
                else {
                    while ($i -lt $RefValueCount) {
                        $RefArrayValue = $RefValue[$i]
                        $RefArrayValueType = $RefArrayValue.GetType().Name
                        $DifArrayValue = $DifValue[$i]
                        $DifArrayValueType = $DifArrayValue.GetType().Name
                        $ArrayPath = $FullPath + "[$i]"
                        if ($RefArrayValueType -ne $DifArrayValueType) {
                            Write-Warning "Key $ArrayPath in the reference object is of type $RefArrayValueType, but the corrosponding key in the difference object is of type $DifArrayValueType. Cannot compare values."
                        }
                        elseif ($RefArrayValueType -eq 'Hashtable') {
                            Compare-Hashtable -ReferenceHashtable $RefArrayValue -DifferenceHashtable $DifArrayValue -Path $ArrayPath -IncludeEqual:$IncludeEqual
                        }
                        elseif ($RefArrayValue -cne $DifArrayValue) {
                            New-Result $ArrayPath $RefArrayValueType $RefArrayValue '!=' $DifArrayValue
                        }
                        elseif ($IncludeEqual) {
                            New-Result $ArrayPath $RefArrayValueType $RefArrayValue '==' $DifArrayValue
                        }
                        $i++
                    }
                }
            }
            # Handle nested hashtables
            elseif ($RefValueType -eq 'Hashtable') {
                Compare-Hashtable -ReferenceHashtable $RefValue -DifferenceHashtable $DifValue -Path $FullPath -IncludeEqual:$IncludeEqual  
            }
            # Add result if key values doesnt match
            elseif ($RefValue -cne $DifValue) {
                New-Result $FullPath $RefValueType $RefValue '!=' $DifValue
            }
            # Add result if key values match
            elseif ($IncludeEqual) {
                New-Result $FullPath $RefValueType $RefValue '==' $DifValue
            }
            
        }
    }
    # Add result for any keys that only exists in the difference hashtable.
    $Results += $DifferenceHashtable.Keys | ForEach-Object {
        if (!$ReferenceHashtable.ContainsKey($_) -and $DifferenceHashtable.ContainsKey($_)) {
            $DifValue = $DifferenceHashtable[$_]
            $DifValueType = $DifValue.GetType().Name
            New-Result $_ $DifValueType $null '<=' $DifValue
        } 
    }
    $Results 
} 


# Inspired from https://github.com/stuartleeks/PesterMatchHashtable
function Compare-Hashtable2 {
    [CmdletBinding()]
    param ( [Parameter( Position=0, Mandatory=$True )] [hashtable]$value, [Parameter( Position=1, Mandatory=$True )] [hashtable]$expectedMatch )
    process {
        if($value.Count -ne $expectedMatch.Count){
            Write-Verbose 'Count is different'
            return $false;
        }
        foreach($expectedKey in $expectedMatch.Keys) {
            if (-not($value.Keys -contains $expectedKey)){
                write-verbose "key $expectedKey from ExpectedMatch is not in Value"
                return $false;
            }
            if (-not ($value[$expectedKey] -eq $expectedMatch[$expectedKey])){
                write-verbose "different values for $expectedKey"
                return $false;
            }
        }
        return $true;
    }
}

<#
[hashtable]$SimpleHT =@{ A1 = "computer"; A2 = "folder"; A3 = "plane"; A4 = "flower"; A5 = "dog"; }
$ComplexHT=[ordered]@{ 
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

[hashtable]$ht11 =@{ A1 = "computer"; A2 = "folder"; A3 = "plane"; A4 = "flower"; A5 = "dog";  A6 = "letter";  }
[hashtable]$ht12 =@{ A1 = "computer"; A2 = "folder"; A3 = "plane"; A4 = "flower";  }
[hashtable]$ht21 =@{ "computer" = "P1"; "plane" = "P2"; "garden" = "p3"; "flower" = "P4"; "dog" = "P5"; }


$Array1 = @([PSCustomObject]$SimpleHT; [PSCustomObject]$ht12; [PSCustomObject]$ht21)
$Array2 = @([PSCustomObject]$SimpleHT; [PSCustomObject]$ht11; [PSCustomObject]$ht12)
$Array2 = @([PSCustomObject]$SimpleHT; [PSCustomObject]$ht11; [PSCustomObject]$ht12)

Compare-Object $Array1 $Array2 -Property Name -PassThru -IncludeEqual | 
Where-Object{ $_.SideIndicator -eq '==' }


$Complex10=$Complex+@{test=1}
$Complex11=$Complex.Clone()


foreach ($ht in $ComplexHT, $SimpleHT) {
	$new=Get-HashTableClone	$ht
	$new=Get-HashTableClone	$ht -mode:ps
	$new=Get-HashTableClone	$ht -mode:json
}
#>
Get-SerializedString @pargs
function Convert-ObjectToHashtable
{
    <#
            .SYNOPSIS
            Turns an object into a hashtable.

            .DESCRIPTION
            When an object is turned into a hashtable, it displays one property per line
            which can be better when you want to output the data in a gridview.

            .PARAMETER ParentObject
            The object you want to convert

            .PARAMETER ExcludeEmpty
            Exclude empty properties.

            .PARAMETER SortProperty
            Sort property names

            .PARAMETER FlattenArray
            Convert arrays to strings

            .PARAMETER ArrayDelimiter
            Delimiter used for flattening arrays. Default is comma.

            .PARAMETER ReturnAsNewObject
            Returns the hashtable as object again with all the requested manipulations in place

            .EXAMPLE
            Get-ComputerInfo | Convert-ObjectToHashtable -ExcludeEmpty -SortProperty | Out-GridView
            Get computer info and show each property in an individual line in gridview.
            Remove Convert-ObjectToHashTable to see the difference.
    #>


    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Object]
        $ParentObject,
        
        [Switch]
        $ExcludeEmpty,
        
        [Switch]
        $SortProperty,
        
        [Switch]
        $FlattenArray,
        
        [string]
        $ArrayDelimiter = ',',
        
        [Switch]
        $ReturnAsNewObject
    )
    
    process
    {
        $properties = $ParentObject.PSObject.Properties | 
            Where-Object { !$ExcludeEmpty -or ![String]::IsNullOrWhiteSpace($_.Value) } 
            
        if ($SortProperty)
        {
            $properties = $properties | Sort-Object -Property Name
        }
        
           
        $hashtable = [Ordered]@{}
        foreach($property in $properties)
        {
            if ($property.Value -is [Array] -and $FlattenArray)
            {
                $hashtable.Add($property.Name, $property.Value -join $ArrayDelimiter)
            }
            else
            {
                $hashtable.Add($property.Name, $property.Value)
            }
        }
        
        if ($ReturnAsNewObject)
        {
            [PSCustomObject]$hashtable
        }
        else
        {
            $hashtable
        }
    }
}

# Get-Service -Name Spooler | Convert-ObjectToHashtable -ExcludeEmpty -SortProperty | Out-GridView
# requires -Version 3.0 -Modules ImportExcel
# 
# Get-Service | Convert-ObjectToHashtable -SortProperty -FlattenArray -ArrayDelimiter ' ' -ReturnAsNewObject | Export-Excel

# Get-ADUser -Identity $env:USERNAME -Properties * |  Convert-ObjectToHashtable -ExcludeEmpty -SortProperty  |  Out-GridView

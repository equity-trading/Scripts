function Convert-ArrayToObject
{
    param
    (
        [Object[]]
        [Parameter(Mandatory,ValueFromPipeline)]
        $InputObject,
  
        [String[]]
        [Parameter(Mandatory)]
        $PropertyName,
        
        [Switch]
        $DiscardRemaining,
        
        [Switch]
        $AsHashtable
    )
  
    begin 
    { 
        $i = 0 
        $overflow = $false
        $maxPropertyIndex = $PropertyName.Count 
        $hashtable = [Ordered]@{}
    }
    process
    {
        $InputObject | ForEach-Object {
            if ($i -lt $maxPropertyIndex -and -not $overflow)
            {
                $hashtable[$PropertyName[$i]] = $_
                $i++
            }
            else
            {
                if ($DiscardRemaining)
                {
                    $overflow = $true
                }
                else
                {
                    if (-not $overflow)
                    {
                        $i--
                        $hashtable[$PropertyName[$i]] = [System.Collections.ArrayList]@($hashtable[$PropertyName[$i]])
                        $overflow = $true
                    }
                    $null = $hashtable[$PropertyName[$i]].Add($_)
                }
            }
        }
    }
    end
    {
        if ($AsHashtable)
        {
            return $hashtable
        }
        else
        {
            [PSCustomObject]$hashtable
        }
    }
}

# 1..3  | Convert-ArrayToObject -PropertyName A,B,C
# 1..10 | Convert-ArrayToObject -PropertyName A,B,C
# 1..10 | Convert-ArrayToObject -PropertyName A,B,C -DiscardRemaining
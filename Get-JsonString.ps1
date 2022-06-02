param ( [Parameter(ValueFromPipeLine = $True)]$InputObject, $depth)
begin {
    <#

    
    $num=1234567890
    $str=[string]$num
    $date=Get-Date
    $interval=(Get-Date) - (Get-Date).AddSeconds(-11)
    $ht=@{t=''; num=$num; str=$str; date=$date; interval=$interval }
    $obj=[pscustomobject]$ht
    $arr=@($str,$num,$interval,$date,$ht,$obj,$null)
    $arrlist=[System.Collections.ArrayList]$arr
    $list=[System.Collections.Generic.List[object]]$arr


    
    $num2=1234567890.123456
    $str2=(1..500|%{ $_}) -join (' ')
    $ht2=@{t=$null;  num=$num; str=$str2; date=$date; interval=$interval; num2=$num2; str2=$str2;}
    $obj2=[psobject]$ht2
    $arr2 = [Object[]]::new(10)
    $arr2[0],$arr2[1],$arr2[2],$arr2[3],$arr2[4],$arr2[5],$arr2[6],$arr2[7],$arr2[8]=$str,$str2,$num,$num2,$date,$interval,$ht,$obj,$ht2,$obj2
    $arrlist2=[System.Collections.ArrayList]$arr2
    $list2=[System.Collections.Generic.List[object]]$arr2
    
    
    $ht3=@{t=1; 1='t'; 't 1'=''; ''='t 1'; null=$null}
    $obj3=[pscustomobject]@{t=1; 1='t'; 't 1'=''; null=$null}
    $arr3=@('',$ht2,$obj2,$str2,$num2,$interval,$null)

    $ht4=@{ $ht=$ht; $obj=$obj }
    $obj4=[pscustomobject]$ht4
    $arr4=@( '', 'Test', @{ ''=''; test4=4; 4=4; 'test 4'='test 4'; null=$null })

    $ht5=@{t=1; @{ t=@{t=1} }=1 }    
    $obj5=[pscustomobject]$ht5

    $o=$ht;gm -input $o -force; "$(1..80|%{'-'})"; 'IsFixedSize','Keys','Values','Item' |% { "${_}:{0}" -f $o.$_ }; $o.Keys|% {'"{0}"="{1}"' -f $_,$o.Item($_)}; $o| ft -a; ($o.Item).GetTYPE(); $o.Item -is [Management.Automation.PSMethodInfo]
    $o=$arr;gm -input $o -force; "$(1..80|%{'-'})"; 'IsFixedSize','Keys','Values','Item' |% { "${_}:{0}" -f $o.$_ }; 
    $d={"$(1..80|%{'-'})"}; $o=$arr0;gm -input $o -force; &$d; gm -input $o.PsObject -force; &$d; 'IsFixedSize','Keys','Values','Item' |% { "${_}:{0}" -f $o.$_ }; &$d; 'IsFixedSize','Keys','Values','Item' |% { "${_}:{0}" -f $o.PsObject.$_ };
    $d={"$(1..80|%{'-'})"}; $o=$arr0; gm -input $o.psbase -force; &$d; 'get_Item','get_Keys','get_Values','Keys','Values','Item' |% { "${_}:{0} type:{1} / {2}" -f $o.PsBase.$_,(($o.PsBase.$_).GetType()).Name,(($o.PsBase.$_).GetType()).BaseType } 2>$null ;  

    #>


    
    function Get-String( [Parameter(ValueFromPipeLine = $True)] $InputObject, $depth=3) {
        $io=$InputObject
        if (!$io) { return '$null' } 
        $t=($io.GetType()).Name
        $o=($io.PsObject)
        if ( !$io) {
            $v="''"
        } elseif ( $io -is [string]) {
            $v="'$io'"
        } elseif( $io -is [DateTime]) {
            $v="[datetime]'$io'"
        } elseif( $io -is [TimeSpan]) {
            $v="[timespan]'$io'"
        } elseif( $io -is [valuetype]) {
            $v="$io"        
        } elseif( $io -is [hashtable]) {
            $v=$io.Keys | % {'{0}={1}' -f ( Get-JsonString $_) ,(Get-JsonString $io.Item($_)) }
            $v='[hashtable]@{{{0}}}' -f ($v -join('; '))
        } elseif ( $io.Item -is [Management.Automation.PSMethodInfo] -and $io.IndexOf -is [Management.Automation.PSMethodInfo] ) {
            $v=$io | % {'{0}' -f ( Get-JsonString $_) }
            $v='[{0}]@({1})' -f $t,($v -join(', '))
        } elseif ( $io.Item -is [Management.Automation.PSMethodInfo] -and $io.Keys -is [System.Collections.ICollection] ) {
            $v=$io.Keys | % {'{0}={1}' -f ( Get-JsonString $_) ,(Get-JsonString $io.Item($_)) }
            $v='[{0}]@{1}' -f $t,($v -join('; '))
        } elseif ( $io.GetEnumerator -is [System.Management.Automation.PsMethod] -and $io.get_Values -isnot  [System.Management.Automation.PsMethod]) {
            # -erroraction:0 doesn't work, see https://github.com/PowerShell/PowerShell/issues/5749
            $v=$io.getenumerator() |% { 
                $k=Get-JsonString $_.Key
                $v=Get-JsonString $_.Value
                '"{0}"="{1}"' -f $k,$v
            }
            $v='1[{0}]@{1}' -f $t,($v -join('; '))
        } elseif ( $o.GetEnumerator -is [System.Management.Automation.PsMethod] ) {
            $v=$io.getenumerator() |% { 
                $v=Get-JsonString $_ 
                '"{0}"' -f $v
            }
            $v='2[{0}]{1}' -f $t,($v -join('; '))
        } else {
            $v=$($io | ConvertTo-Json -compress -depth:$depth)
            $v='3[{0}]{1}' -f $t,($v -join('; '))
        }
        $l=$v.Length
        $max=$Host.UI.RawUI.WindowSize.Width-10
        if($l -gt $max ) { $v=$v.substring(0,$max-2)+'..' } elseif($l -eq 0) {$v="[$t]''"}
        return $v
    }
}

# $InputObject | Get-String @PsBoundParameters
process {
    Get-JsonString -InputObject:$InputObject  @PsBoundParameters
}
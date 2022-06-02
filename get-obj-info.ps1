param ( [Parameter(ValueFromPipeLine = $True)]$vars, $methods)
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
 
    $DebugPreference=0
    # foreach ($path in 'psobject', 'psadapted', 'psbase', 'psextended', 'psobject.psadapted', 'psobject.psbase', 'psobject.psextended') {
    $objinfocols=@( @{ E='path'; W=20 }, @{ E='type'; W=15 }, @{ E='basetype'; W=15 },
        @{ E='Name'; W=20; A='Left' }, @{ E='MemberType'; W=15 }, @{ E='Value'; W=50;A='Left' }, @{ E='IsSettable'; W=14; A='Left'}, 
        @{ E='IsGettable'; W=14; A='Left'},  @{ E='IsInstance'; W=20; A='Left' } , @{ E='TypeNameOfValue'; W=100; A='Left' }
        )
    get-obj-info.ps1 obj | select -exclude TypeNameOfValue *  | select -expand result * | ft $objinfocols
    get-obj-info.ps1 obj | select -expand result * | select -exclude TypeNameOfValue,basetype | ft *
    get-obj-info.ps1 ht -methods:members| select -expand result * | select -exclude TypeNameOfValue, OverloadDefinitions, Value, path, type, basetype, result | ft *
    get-obj-info.ps1 obj | select -expand result *  | select MemberType,name,expression,IsSettable,IsGettable,IsInstance,value | sort-object MemberType,name,expression | ft
    # 'get_BaseObject','get_ImmediateBaseObject','get_TypeNames'

    get-obj-info.ps1 str | select -expand result *  | select MemberType,name,expression,IsSettable,IsGettable,IsInstance,value |? {$_.IsGettable} | sort-object MemberType,name,expression | ft
    get-obj-info.ps1 str,obj,ht,arr,arrlist,list | select -expand result *  | select expression,MemberType,name,IsSettable,IsGettable,IsInstance,value |? {$_.Name -match 'GetEnumerator|Length|Count|Values|Keys|Length' -or $_.MemberType -match 'NoteProperty' } | sort-object expression,MemberType,name | ft 
 get-obj-info.ps1 str,num,date,obj,ht,arr,arrlist,list -methods:get_members| select -expand result * | select expression,MemberType,name,value |? {$_.Name -match '^(GetEnumerator|BaseObject|Length|Count|Values|Keys|Length)$' -or $_.MemberType -match 'NoteProperty' } | sort-object expression,MemberType,name | ft



 #>
    
    function get-obj-info([Parameter(ValueFromPipeLine = $True)]$vars
         , $methods=@('get_properties','get_methods')
         , $pathes=@('', 'psobject', 'psobject.psbase', 'psadapted', 'psbase', 'psextended', 'psobject.psadapted',  'psobject.psextended')) {
        # $var='obj'
        foreach ($var_name in $vars) {
            if (!$var_name) { return }
            $o=Invoke-Expression `$$var_name
            $type='{0}' -f ($o.GetType()).Name; $basetype='{0}' -f ($o.GetType()).BaseType
            Write-Debug $('var:{0} type:{1} basetype:{2}' -f $var_name, $type, $basetype)
            foreach ($m in $methods) {
                foreach ($path in $pathes ) {
                    $obj_path="`$$var_name"
                    if ($path.Length -gt 0 ) { $obj_path+=".$path"}
                    # if ($m -notlike 'get*') {$m="get_$m"}
                    $expr='{0}.{1} -is [System.Management.Automation.PSMethod]' -f $obj_path, $m
                    Write-Debug $('Expression : {0}' -f $expr)
                    if ( Invoke-Expression $expr ) {
                        $expr='{0}.{1}()' -f $obj_path, $m
                        Write-Debug $('  Run : {0}' -f $expr)
                        [pscustomobject]@{ path=$obj_path; type=$type; basetype=$basetype; expression=$expr; result=(Invoke-Expression $expr)}
                        # break
                    }
            
                }
            }    
        }
    }
}

process {
    get-obj-info -vars:$vars @PsBoundParameters
}
set-strictMode -version latest

function abc {
   param (
      [switch] $F,
      [string] $T,
      [int   ] $N
   )

   $out=foreach($var in 'N','F','T') { '{0,4}={1,-5}' -f $var,((get-variable $var).value -join(',')) }
   $out -join(' ')
   return 
}

function xyz {
   param (
      [int   ] $num,
      [switch] $flg,
      [string] $txt
   )

   # write-host "flg = $flg, num = $num, txt = $txt"
   $out=foreach($var in 'num','flg','txt') { '{0,4}={1,-5}' -f $var,((get-variable $var).value -join(',')) }
   $out -join(' ')
   abc -F:$flg -T $txt -N $num
}

$xyzParameters = (get-command xyz).parameters

$xyzParameters['num'].Attributes[0].Position  #           0
$xyzParameters['flg'].Attributes[0].Position  # -2147483648
$xyzParameters['txt'].Attributes[0].Position  #           1

xyz -flg 42 hello
xyz      42 hello
xyz      42 hello -flg
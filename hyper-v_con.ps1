$arg0 = $Args[0]
$arg1 = $Args[1]
$arg2 = $Args[2]
$arg3 = $Args[3]
$arg4 = $Args[4]
$arg5 = $Args[5]
write-host "$arg0"
write-host "$arg1"
write-host "$arg2"
write-host "$arg3"
write-host "$arg4"
write-host "$arg5"
cd "E:\scripts\vm_manager"; & ".\hyper-v.ps1"  $Args[0] $Args[1] $Args[2] $Args[3] $Args[4] $Args[5] $Args[6] $Args[7]
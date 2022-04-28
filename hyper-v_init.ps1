$arg0 = $Args[0]
$arg1 = $Args[1]
$arg2 = $Args[2]
$arg3 = $Args[3]
$arg4 = $Args[4]
$arg5 = $Args[5]
$arg6 = $Args[6]
$arg7 = $Args[7]
write-host "$arg0"
write-host "$arg1"
write-host "$arg2"
write-host "$arg3"
write-host "$arg4"
#pause
# PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""E:\scripts\manage_vm\vm_con.ps1 $arg0 $arg1 $arg2 $arg3 $arg4""' -Verb RunAs}"

PowerShell -NoProfile -ExecutionPolicy Bypass `
    -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""E:\scripts\vm_manager\hyper-v_con.ps1 $arg0 $arg1 $arg2 $arg3 $arg4 $arg5 $arg6 $arg7""' -Verb RunAs}"
# https://github.com/Sai-Yan-Naing/copy-paste/tree/2167d7ccb314e69b47dcd1b11f79ce3f2783c1f6/vm_manager
$BAT_DIR_PATH = "E:\scripts\vm_manager"
$cmd = $Args[0]
$host_ip = $Args[1]
$host_user = $Args[2]
$host_password = $Args[3]
$vm_name = $Args[4]
$path = $Args[5]
$del_dir = $Args[6]
$filename = $Args[7]
$del_vm = "C:\\Hyper-v\\Virtual Hard Disks\\$vm_name.vhdx"
$getchild = Get-ChildItem -Path E:\scripts\firewall -Filter *.vmcx -Name;
function get_session($server=$null, $user=$null, $passwd=$null, $port=5985) {
    try {
        $secure_string = ConvertTo-SecureString $passwd -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PsCredential($user, $secure_string)
        return New-PSSession -ComputerName $server -Credential $credential -Port $port
    } catch {
        return $null
    }
}

function remove_session($session=$null) {
    try {
        return Remove-PSSession -Session $session
    } catch {
        return $null
    }
}

try {
    $session = get_session $host_ip $host_user $host_password
    switch ($cmd) {
        "get_state" {
            $result = Invoke-Command -Session $session -Scriptblock{Get-VM -Name $Args[0]} -ArgumentList $vm_name
            return $result.State
        }
        "get_ip" {
            $result = Invoke-Command -Session $session -Scriptblock{$(Get-VMNetworkAdapter $(Get-VM -Name $Args[0])).IPAddresses} -ArgumentList $vm_name
            return $result
        }
        "startup" {
            Invoke-Command -Session $session -Scriptblock{Start-VM -Name $Args[0]} -ArgumentList $vm_name
            return "Complete start up."
        }
        "shutdown" {
            Invoke-Command -Session $session -Scriptblock{Stop-VM -Name $Args[0] -Force} -ArgumentList $vm_name
            return "Complete shutdown."
        }
        "poweroff" {
            Invoke-Command -Session $session -Scriptblock{Stop-VM -Name $Args[0] -TurnOff} -ArgumentList $vm_name
            echo "Complete power off."
        }
        "dissolve_vm" {
            $result = Invoke-Command -Session $session -FilePath $BAT_DIR_PATH\hyper-v_dissolve_vm.ps1 -ArgumentList $vm_name
            return $result
        }
        "remove_dissolved_vm" {
            $result = Invoke-Command -Session $session -FilePath $BAT_DIR_PATH\hyper-v_remove_dissolved_vm.ps1
            return $result
        }
        # additional
        "export_vm" {
            Invoke-Command -Session $session -Scriptblock{Remove-Item -path $Args[0] -recurse}  -ArgumentList $del_dir
            Invoke-Command -Session $session -Scriptblock{Export-VM -Name $Args[0] -Path $Args[1]} -ArgumentList $vm_name, $path
            echo "Complete export."
        }
        "delete_dir" {
            Invoke-Command -Session $session -Scriptblock{Remove-Item -path $Args[0] -recurse}  -ArgumentList $del_dir
            echo "Complete delete."
        }
        "restore_backup" {
            Invoke-Command -Session $session -Scriptblock{Stop-VM -Name $Args[0] -TurnOff} -ArgumentList $vm_name
            Invoke-Command -Session $session -Scriptblock{Remove-VM -Name $Args[0] -Force} -ArgumentList $vm_name
            Invoke-Command -Session $session -Scriptblock{Remove-Item -path $Args[0] -recurse}  -ArgumentList $del_vm
            Invoke-Command -Session $session -Scriptblock{Import-VM -Path $Args[0] -Copy -VhdDestinationPath 'C:\\Hyper-v\\Virtual Hard Disks\\'} -ArgumentList "$path\\Virtual Machines\\3C5F7CE8-66E4-4932-9C42-D9F352A42CCF.vmcx"
            echo "Complete restore."
        }
        "copy"{
            # Copy-Item -Path G:\application\SQLSERVER\2019\SQLEXPR_2019\* -ToSession $session -Destination 'C:\sqlserver\SQLEXPR_2019'
            Invoke-Command -Session $session -Scriptblock{C:\sqlserver\SQLEXPR_2019\setup.exe /ConfigurationFile=ConfigurationFile.ini}
            return "Complete start up."
        }
        "testpass"{
            Invoke-Command -Session $session -Scriptblock{C:\vm_manager\pass.ps1 $Args[0]} -ArgumentList $vm_name
            return "Complete start up."
        }
        default {
            return "Invalid command."
        }
    }
    remove_session $session
} catch {
    # return $_.Exception
}

# return $false
pause
# https://github.com/Sai-Yan-Naing/copy-paste/tree/2167d7ccb314e69b47dcd1b11f79ce3f2783c1f6/vm_manager
$cmd = $Args[0]
$user_id = $Args[1]
$user_password = $Args[2]
$new_user_password = $Args[3]

try {
    switch ($cmd) {
        "create_user" {
            $hostname = hostname
            [ADSI]$computer = "WinNT://$hostname,computer"

            # Create account.
            $user = $computer.Create("User", $user_id)
            $user.SetPassword($user_password)
            $user.SetInfo()

            # Set account properties.
            $user.FullName = $user_id
            $user.Description = $user_id
            $user_flags = $user.Get("UserFlags")
            $user_flags = $user_flags -bor 0x10000
            $user.Put("UserFlags", $user_flags)
            $user.SetInfo()

            # Add acccount to Users group.
            $group = $computer.GetObject("group", 'Users')
            $group.Add("WinNT://$hostname/$user_id")

            echo $?
        }
        "remove_user" {
            net user "${user_id}" /delete > nul 2>&1

            echo $?
        }
        "set_user_password" {
            $hostname = hostname
            [ADSI]$user = "WinNT://$hostname/$user_id,User"

            $user.SetPassword($user_password)
            $user.SetInfo()

            echo $?
        }
        "change_user_password" {
            $hostname = hostname
            [ADSI]$user = "WinNT://$hostname/$user_id,User"

            $user.ChangePassword($user_password, $new_user_password)

            #echo $?
            echo $LASTEXITCODE
        }
        "enable_user" {
            $hostname = hostname
            [ADSI]$user = "WinNT://$hostname/$user_id,User"

            $user_flags = $user.Get("UserFlags")
            $user_flags = $user_flags -bor 0x0202
            $user_flags = $user_flags -bxor 0x0202
            $user.Put("UserFlags", $user_flags)
            $user.SetInfo()

            echo $?
        }
        "disable_user" {
            $hostname = hostname
            [ADSI]$user = "WinNT://$hostname/$user_id,User"

            $user_flags = $user.Get("UserFlags")
            $user_flags = $user_flags -bor 0x0202
            $user.Put("UserFlags", $user_flags)
            $user.SetInfo()

            echo $?
        }
        "is_user" {
            $hostname = hostname
            [ADSI]$computer = "WinNT://$hostname,computer"

            $user_ids = $computer.psbase.children | ? {$_.psBase.schemaClassName -eq "User"} | Select-Object -expand Name

            echo ($user_ids -contains $user_id)
        }
        default {
            echo $false
        }
    }
} catch {
    echo $_.Exception
}
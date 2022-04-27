# Get-Process WDDriveService,Sysmon,Sysmon,ServiceShell
param([string[]]$name,[int[]]$id)

function ps-info1 ($pattern='*',[int]$id=$null) {
	$script:Services=@{}	
	'pattern: {0}' -f $pattern
	
	Foreach($wmi in (Get-WmiObject "Win32_Service" -ea 0 -Filter 'Name like "${pattern}*" and ProcessId>0'  | select -first 1 ) ) { 
		$script:Services[$wmi.ProcessId]+=@($wmi) 
	}
	'4540 is {0}' -f $script:Services.4540
	$script:Services
	return
	Foreach($p in (Get-Process $pattern -ea 0) ) {
		'pid: {0} name: {1} services: {2} {3}' -f $p.Id, $p.ProcessName, $script:Services[$p.Id].Count, $script:Services["$p.Id"] -join ','
		[pscustomobject]@{
			ProcessName         = $p.ProcessName
			Id                  = $p.Id
			TotalProcessorTime  = $p.TotalProcessorTime
			UserProcessorTime   = $p.UserProcessorTime
			WorkingSet          = $p.WorkingSet
			WorkingSet64        = $p.WorkingSet64
			CPU                 = $p.CPU
			VM                  = $p.VM
			PM                  = $p.PM
			Responding          = $p.Responding
			ExitCode            = $p.ExitCode
			MainWindowTitle     = $p.MainWindowTitle
			Threads             = $p.Threads
			MainModule          = $p.MainModule
			Modules             = $p.Modules
			Product             = $p.Product
			ProductVersion      = $p.ProductVersion
			Path                = $p.Path
			Services            = $script:Services[$p.Id]
			StartTime           = $p.StartTime
			ExitTime            = $p.ExitTime 
		}
		# $services = Get-WmiObject "Win32_Service" -filter "ProcessId=$($p.Id)"
		# Add-Member -InputObject $p -MemberType NoteProperty  -Name "Services" -Value $(($services | % {$_.name}) -join ',') -Force
	}
}

function proc_obj($p) {
	$PidStr=$p.Id.ToString()
	return [pscustomobject]@{
		ProcessName         = $p.ProcessName
		Id                  = $p.Id
		TotalProcessorTime  = $p.TotalProcessorTime
		UserProcessorTime   = $p.UserProcessorTime
		WorkingSet          = $p.WorkingSet
		WorkingSet64        = $p.WorkingSet64
		CPU                 = $p.CPU
		VM                  = $p.VM
		PM                  = $p.PM
		Responding          = $p.Responding
		ExitCode            = $p.ExitCode
		MainWindowTitle     = $p.MainWindowTitle
		Threads             = $p.Threads
		MainModule          = $p.MainModule
		Modules             = $p.Modules
		Product             = $p.Product
		ProductVersion      = $p.ProductVersion
		Path                = $p.Path
		Services            = $script:pid2services[$PidStr]
		StartTime           = $p.StartTime
		ExitTime            = $p.ExitTime 
	}
}

function proc_by_name([string[]]$patterns) {
	# $script:pid2services.Keys -join ','
	# 'pid-service-map.Count: {0} ' -f $script:pid2services.Count
	# foreach($key in $script:pid2services.keys) { echo "$key is $(${script:pid2services}.$key)" }
	if ( $patterns.Count -gt 0 ) {
		$Cmd="Get-Process -Name $($patterns -join ',')"	
		"Cmd: {0}" -f $Cmd
		$Objects=@( Invoke-Command -ScriptBlock { param($LocalCmd) Invoke-Expression -Command:$LocalCmd } -ArgumentList $Cmd ) 
		Foreach($p in $Objects ) {
			proc_obj $p
		}
	}
}

function proc_by_id([int[]]$process_ids) {
	if ( $process_ids.Count -gt 0 ) {
		$Cmd="Get-Process -Id $($process_ids -join ',')"	
		"Cmd: {0}" -f $Cmd
		$Objects=@( Invoke-Command -ScriptBlock { param($LocalCmd) Invoke-Expression -Command:$LocalCmd } -ArgumentList $Cmd ) 
		Foreach($p in $Objects ) {
			proc_obj $p
		}
	}
}


function service-info2($pattern) {
#https://stackoverflow.com/questions/68133040/is-it-possible-to-make-association-with-running-services-and-it-processes-via-po
	Get-CimInstance Win32_Service | ForEach-Object {
		$process = Get-Process -Id $_.ProcessId
		[PSCustomObject]@{
			ServiceName   = $_.Name
			ServiceStatus = $_.Status
			ServiceState  = $_.State
			ServicePath   = $_.PathName
			ProcessId     = $_.ProcessId
			ProcessName   = $process.Name
			ProcessPath   = $process.Path
		}
	}
}

# PS C:\home\scripts\ps1> $pattern="sysmo"; Get-CimInstance -Class Win32_Service -Filter "Name LIKE '${pattern}%'"  
function service-info3($pattern) {
	foreach ($s in @(Get-CimInstance -Class Win32_Service -Filter "Name LIKE '${pattern}%'" ) ) {
		Get-Process -Id $s.ProcessId
	}
}

# Get-CimInstance -Class Win32_Service -Filter "Name LIKE 'sysmon%'"
function pid-service-map($service_pattern) {
	$script:pid2services = @{}
	$Services=@(Get-CimInstance win32_service -Filter "Name LIKE '${service_pattern}%' and ProcessID>0" | Group-Object ProcessID ) 
	$Services | ForEach-Object {
		$script:pid2services[$_.Name]=$_
	}
}

# .\Processes_Services.ps1 -name v*
# .\Processes_Services.ps1 -id 1944,2552 
# .\Processes_Services.ps1 -id 1944,2552 | Out-String -Stream|Select-String "vmcompute"

pid-service-map
# 'pid-service-map.Count: {0} ' -f $script:pid2services.Count
# foreach($key in $script:pid2services.keys) { echo "$key is $(${script:pid2services}.$key)" }
# break

$OutFormat=@{ Label="Name"; Expression={$_.ProcessName}; Width=20},
	@{ Label="PID"; Expression={$_.Id}; Width=12},
	@{ Label="Services2"; Expression={$_.Services.Count+$($_.Services -join ',')};},
	@{ Label="Services"; Expression={$_.Services};},
	"Path"

if ($id) { 
    '[process search ids] {0}' -f $id -join(",")
    proc_by_id   $id   | Format-Table -Autosize $OutFormat 
} elseif ($name) {
    '[process search pattern] {0} ' -f $name
    proc_by_name $name | Format-Table -Autosize $OutFormat
}



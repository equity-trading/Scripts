# Get-Process WDDriveService,Sysmon,Sysmon,ServiceShell
param([string[]]$name,[int[]]$id)

function ps-info ([string[]]$name,[int[]]$id) {
	$Services=@{}	

    if ((!$name) -and (!$id) ) {
        'Either name or id parameter must be provided'
        return
    }
	if ($name) { 'name : {0}' -f $name -join(",") }
    if ($id)   { 'id   : {0}' -f $id   -join(",") }
    

	Foreach($wmi in (Get-CimInstance "Win32_Service" -ea 0 -Filter "Name like '${name}*' and ProcessId>0"  ) ) { 
		$Services[$wmi.ProcessId]+=@($wmi) 
	}
	# '4540 is {0}' -f $script:Services.4540
	$Services
	return
	Foreach($p in (Get-Process $name -ea 0) ) {
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

ps-info @PSBoundParameters
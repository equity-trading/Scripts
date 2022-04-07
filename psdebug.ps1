param([Parameter(Mandatory=$false)] [string]$traceCmd="C:\home\script\test1.ps1",[Parameter(ValueFromRemainingArguments = $true)] [Object[]]$OtherArgs )

# PS C:\Users\alexe> C:\home\script\psdebug.ps1 -Debug -Levels 1,2 -ev 0
# psdebug.ps1: A parameter cannot be found that matches parameter name 'Levels'.

# [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'Medium')]
#   -Trace 1 > C:\home\script\test1.dbg.out

begin {
	$Arguments = foreach ($Argument in $MyArgs) {
		if ($Argument -match '^-([a-z]+)$') {
			$Name = $Matches[1]
			$foreach.MoveNext() | Out-Null
			$Value = $foreach.Current
			New-Variable -Name $Name -Value $Value
			$PSBoundParameters.Add($Name,$Value) | Out-Null
		} else {
			$Argument
		}
	}
	if($PSBoundParameters.ContainsKey("Debug")) {
		$PSBoundParameters | Out-Default
		"Positional"
		$Arguments	
		Write-Debug "OtherArgs[$(($OtherArgs).length)] : $($OtherArgs -join ' ')"
	}
}

process {
	# if(Get-Command $func -ea SilentlyContinue) { & $func $args }
	if($traceFile=Get-Item $traceCmd -ea SilentlyContinue) {
		$traceLog   =  Join-Path $traceFile.Directory "$($traceFile.BaseName).dbg"
		$traceLog   =  Join-Path $env:TEMP test.log
		$PSExecutable  = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
		# $PSExecutable7 = 'C:\Program Files\PowerShell\7\pwsh.exe'
		$PSArguments   = "-Version 5 -NoProfile -File $traceCmd"
		# Write-Debug "Start-Process -FilePath $PSExecutable -RedirectStandardOutput $traceLog -ArgumentList @($($OtherArgs -join ' '))"
		Write-Debug "Start-Process -FilePath $PSExecutable -ArgumentList `"$PSArguments`" -RedirectStandardOutput $traceLog"
		Set-PSDebug -Trace 1
		Start-Process -FilePath $PSExecutable -ArgumentList "$PSArguments" -RedirectStandardOutput $traceLog 
		Set-PSDebug -Trace 0
    } else {
        # ignore
    }       

}

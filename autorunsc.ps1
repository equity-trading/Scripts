<# 
PS C:\Users\alexe> & $autorunsc -nobanner --help
Autorunsc shows programs configured to autostart during boot.

Usage: autorunsc [-a <*|bdeghiklmoprsw>] [-c|-ct] [-h] [-m] [-s] [-u] [-vt] [-o <output file>] [[-z <systemroot> <userprofile>] | [user]]]
  -a   Autostart entry selection:
     *    All.
     b    Boot execute.
     c    Codecs.
     d    Appinit DLLs.
     e    Explorer addons.
     g    Sidebar gadgets (Vista and higher)
     h    Image hijacks.
     i    Internet Explorer addons.
     k    Known DLLs.
     l    Logon startups (this is the default).
     m    WMI entries.
     n    Winsock protocol and network providers.
     o    Office addins.
     p    Printer monitor DLLs.
     r    LSA security providers.
     s    Autostart services and non-disabled drivers.
     t    Scheduled tasks.
     w    Winlogon entries.
  -c     Print output as CSV.
  -ct    Print output as tab-delimited values.
  -h     Show file hashes.
  -m     Hide Microsoft entries (signed entries if used with -s).
  -o     Write output to the specified file.
  -s     Verify digital signatures.
  -t     Show timestamps in normalized UTC (YYYYMMDD-hhmmss).
  -u     If VirusTotal check is enabled, show files that are unknown
         by VirusTotal or have non-zero detection, otherwise show only
         unsigned files.
  -x     Print output as XML.
  -v[rs] Query VirusTotal (www.virustotal.com) for malware based on file hash.
         Add 'r' to open reports for files with non-zero detection. Files
         reported as not previously scanned will be uploaded to VirusTotal
         if the 's' option is specified. Note scan results may not be
         available for five or more minutes.
  -vt    Before using VirusTotal features, you must accept
         VirusTotal terms of service. See:

              https://www.virustotal.com/en/about/terms-of-service/

         If you haven't accepted the terms and you omit this
         option, you will be interactively prompted.
  -z     Specifies the offline Windows system to scan.
  user   Specifies the name of the user account for which
         autorun items will be shown. Specify '*' to scan
         all user profiles.
  -nobanner
         Do not display the startup banner and copyright message.

#>


function get-autoruns ( [switch]$UseCache,[switch]$UpdateCache,$autorunsc='C:\home\apps\SysinternalsSuite\autorunsc64.exe' , $params=@('/accepteula', 'a', '*', '-c', '-h', '-s', '-nobanner')) {

	if ($UpdateCache -or (!$UpdateCache -or !$AUTORUN_ARR -or $AUTORUN_ARR.Count -eq 0) ) {
		$AUTORUN_RAW=& $autorunsc $params
		$AUTORUN_ARR=$AUTORUN_RAW|% { [regex]::replace($_,'[^\x20-\x7F]','').Trim() } |? { $_ } | ConvertFrom-Csv
	}
	
	$AUTORUN_ARR.Count # >>> 1541 >>> 1404
	$exclude='disabled|^$'; $match='P9'; $AUTORUN_ARR |? {$_.Enabled -notmatch $exclude -and $_.'Image Path' -match $match } | Select -First 2000 'Entry Location', Entry, Enabled, Category, 'Image Path'| ft -group 'Image Path' -auto


	
}

####################################
# SysInternal autorunsc64 -a * -c -h -s -nobanner '*'




get-autoruns @args
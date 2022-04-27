function Get-IPAddress {
    $ipInfo = ifconfig | select-string 'inet'
    $ipInfo = [regex]::matches($ipInfo,"addr:\b(?:\d{1,3}\.){3}\d{1,3}\b") | ForEach-Object value
    $ipInfo.replace('addr:','') | Where-Object {$_ -ne '127.0.0.1'}
}
# for linux only
Get-IPAddress
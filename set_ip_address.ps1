# https://www.pdq.com/blog/using-powershell-to-set-static-and-dhcp-ip-addresses-part-1/

function set-Static-IP-Address() {
	$IP = "10.10.10.10"
	$MaskBits = 24 # This means subnet mask = 255.255.255.0
	$Gateway = "10.10.10.1"
	$Dns = "10.10.10.100"
	$IPType = "IPv4"
	# Retrieve the network adapter that you want to configure
	$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
	# Remove any existing IP, gateway from our ipv4 adapter
	If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
	 $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
	}
	If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
	 $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
	}
	 # Configure the IP address and default gateway
	$adapter | New-NetIPAddress `
	 -AddressFamily $IPType `
	 -IPAddress $IP `
	 -PrefixLength $MaskBits `
	 -DefaultGateway $Gateway
	# Configure the DNS client server IP addresses
	$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

}

function set-DHCP-Address() {
	$IPType = "IPv4"
	$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
	$interface = $adapter | Get-NetIPInterface -AddressFamily $IPType
	If ($interface.Dhcp -eq "Disabled") {
	 # Remove existing gateway
	 If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
	 $interface | Remove-NetRoute -Confirm:$false
	 }
	 # Enable DHCP
	 $interface | Set-NetIPInterface -DHCP Enabled
	 # Configure the DNS Servers automatically
	 $interface | Set-DnsClientServerAddress -ResetServerAddresses
	}
}
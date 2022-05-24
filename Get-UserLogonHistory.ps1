# 
# Get-UserLogonHistory.ps1 
# Get-UserLogonHistory.ps1 -MaxEvents 1000
# Get-UserLogonHistory.ps1 240890
# https://www.pdq.com/blog/history-of-logged-on-users/

param ( $Index, [int]$MaxEvents=20000)


if ($Index) {
	Get-EventLog -LogName "Security" -Index $Index -InstanceId 4624 -Newest 1 -ErrorAction "SilentlyContinue"  | 
	select-object RunspaceId,Index,EventID,EntryType,TimeGenerated,
	 @{n='SecurityId';e={$_.ReplacementStrings[4]}},
	 @{n='AccountName';e={$_.ReplacementStrings[5]}},
	 @{n='AccountDomain';e={$_.ReplacementStrings[6]}},
	 @{n='AccountType';e={$_.ReplacementStrings[8]}},
	 @{n='LogonProcess';e={$_.ReplacementStrings[9]}},
	 @{n='AuthPackage';e={$_.ReplacementStrings[10]}},
	 @{n='ProcessPath';e={$_.ReplacementStrings[17]}} ,
	 @{n='ProcessID';e={[uint32]$_.ReplacementStrings[16]}}, 
	 TimeWritten, Source, InstanceId, MachineName, UserName, Data, Category, CategoryNumber, Container, ReplacementStrings, Message

	
} else {

	# Query all logon events with id 4624 
	Get-EventLog -LogName "Security" -InstanceId 4624 -Newest $MaxEvents -ErrorAction "SilentlyContinue"  | 
	select-object RunspaceId,Index,EventID,EntryType,TimeGenerated,
	 @{n='SecurityId';e={$_.ReplacementStrings[4]}},
	 @{n='AccountName';e={$_.ReplacementStrings[5]}},
	 @{n='AccountDomain';e={$_.ReplacementStrings[6]}},
	 @{n='AccountType';e={$_.ReplacementStrings[8]}},
	 @{n='LogonProcess';e={$_.ReplacementStrings[9]}},
	 @{n='AuthPackage';e={$_.ReplacementStrings[10]}},
	 @{n='ProcessPath';e={$_.ReplacementStrings[17]}},
	 @{n='ProcessID';e={[uint32]$_.ReplacementStrings[16]}}	| 
	 Group-Object AccountName,AccountType,ProcessPath,LogonProcess |
	  Select @{n='AccountName';e={$_.Values[0]}}, @{n='AccountType';e={$_.Values[1]}},
	   @{n='ProcessPath';e={$_.Values[2]}}, 
	   @{n='LogonProcess';e={$_.Values[3]}},
       Count,	   
	   @{n='FirsTime';e={$_.Group[$_.Group.Count-1].TimeGenerated}},@{n='LastTime';e={$_.Group[0].TimeGenerated}},
	   @{n='FirstPID';e={$_.Group[$_.Group.Count-1].ProcessID}},@{n='LastPID';e={$_.Group[0].ProcessID}},
	   @{n='FirstIndex';e={$_.Group[$_.Group.Count-1].Index}},@{n='LastIndex';e={$_.Group[0].Index}} |
	   Sort-Object AccountName, AccountType, ProcessPath, LogonProcess, Count| Format-Table -auto 
} 
 

<# 

|
 Select Count, 
   @{n='AccountName';e={(($_.Name)[0])}}, 
   @{n='LogonProcess';e={$_.Name[1]}}, 
   @{n='ProcessPath';e={$_.Name[2]}}, 
   Group
 
S-1-5-18
WIN11-2$
WORKGROUP
0x3e7
S-1-5-18
SYSTEM
NT AUTHORITY
0x3e7
5
Advapi
Negotiate
-
{00000000-0000-0000-0000-000000000000}
-
-
0
0x628
C:\Windows\System32\services.exe
-
-
%%1833
-
-
-
%%1843
0x0
%%1842
#>
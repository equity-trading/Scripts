
<#
PS C:\home\src\Scripts> Get-Winevent -logname System  -MaxEvents 1 | %{$_.ToXml()}        
<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='Service Control Manager' Guid='{555908d1-a6d7-4695-8e1e-26931d2012f4}' EventSourceName='Service Control Manager'/><EventID Qualifiers='16384'>7040</EventID><Version>0</Version><Level>4</Level><Task>0</Task><Opcode>0</Opcode><Keywords>0x8080000000000000</Keywords><TimeCreated SystemTime='2022-04-25T15:51:07.8840856Z'/><EventRecordID>11035</EventRecordID><Correlation/><Execution ProcessID='1592' ThreadID='20684'/><Channel>System</Channel><Computer>Win11-2</Computer><Security UserID='S-1-5-18'/></System><EventData><Data Name='param1'>Background Intelligent Transfer Service</Data><Data Name='param2'>auto start</Data><Data Name='param3'>demand start</Data><Data Name='param4'>BITS</Data></EventData></Event>


PS C:\home\src\Scripts> ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]"  -maxevent 1 -ea 0) | Get-TypeData
TypeName                                          Members
--------                                          -------
System.Diagnostics.Eventing.Reader.EventLogRecord {}

Get-FormatData -TypeName System.Diagnostics.Eventing.Reader.EventLogRecord | Export-FormatData -Path C:\home\src\Scripts\EventLogRecord.Format.ps1xml


PS C:\home\src\Scripts> ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]"  -maxevent 1 -ea 0).ToXml()

<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
<System><Provider Name='Service Control Manager' Guid='{555908d1-a6d7-4695-8e1e-26931d2012f4}' EventSourceName='Service Control Manager'/>
<EventID Qualifiers='16384'>7040</EventID><Version>0</Version><Level>4</Level><Task>0</Task><Opcode>0</Opcode><Keywords>0x8080000000000000</Keywords><TimeCreated SystemTime='2022-04-25T15:51:07.8840856Z'/><EventRecordID>11035</EventRecordID><Correlation/><Execution ProcessID='1592' ThreadID='20684'/><Channel>System</Channel><Computer>Win11-2</Computer><Security UserID='S-1-5-18'/></System><EventData><Data Name='param1'>Background Intelligent Transfer Service</Data><Data Name='param2'>auto start</Data><Data Name='param3'>demand start</Data><Data Name='param4'>BITS</Data></EventData></Event>


PS C:\home\src\Scripts> ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]"  -maxevent 1 -ea 0).ToXml().Replace("><",">`n<")

<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
<System>
<Provider Name='Service Control Manager' Guid='{555908d1-a6d7-4695-8e1e-26931d2012f4}' EventSourceName='Service Control Manager'/>
<EventID Qualifiers='16384'>7040</EventID>
<Version>0</Version>
<Level>4</Level>
<Task>0</Task>
<Opcode>0</Opcode>
<Keywords>0x8080000000000000</Keywords>
<TimeCreated SystemTime='2022-04-25T15:51:07.8840856Z'/>
<EventRecordID>11035</EventRecordID>
<Correlation/>
<Execution ProcessID='1592' ThreadID='20684'/>
<Channel>System</Channel>
<Computer>Win11-2</Computer>
<Security UserID='S-1-5-18'/>
</System>
<EventData>
<Data Name='param1'>Background Intelligent Transfer Service</Data>
<Data Name='param2'>auto start</Data>
<Data Name='param3'>demand start</Data>
<Data Name='param4'>BITS</Data>
</EventData>
</Event>

# PS C:\home\src\Scripts> ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Stream" -Depth 3
PS C:\home\src\Scripts> ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "String" -Depth 3

<?xml version="1.0" encoding="utf-8"?>
<Objects>
  <Object Type="System.Diagnostics.Eventing.Reader.EventLogRecord">
    <Property Name="Message" Type="System.String">The start type of the Background Intelligent Transfer Service service was changed from auto start to demand start.</Property>
    <Property Name="Id" Type="System.Int32">7040</Property>
    <Property Name="Version" Type="System.Byte">0</Property>
    <Property Name="Qualifiers" Type="System.Int32">16384</Property>
    <Property Name="Level" Type="System.Byte">4</Property>
    <Property Name="Task" Type="System.Int32">0</Property>
    <Property Name="Opcode" Type="System.Int16">0</Property>
    <Property Name="Keywords" Type="System.Int64">-9187343239835811840</Property>
    <Property Name="RecordId" Type="System.Int64">11035</Property>
    <Property Name="ProviderName" Type="System.String">Service Control Manager</Property>
    <Property Name="ProviderId" Type="System.Guid">555908d1-a6d7-4695-8e1e-26931d2012f4</Property>
    <Property Name="LogName" Type="System.String">System</Property>
    <Property Name="ProcessId" Type="System.Int32">1592</Property>
    <Property Name="ThreadId" Type="System.Int32">20684</Property>
    <Property Name="MachineName" Type="System.String">Win11-2</Property>
    <Property Name="UserId" Type="System.Security.Principal.SecurityIdentifier">
      <Property Name="BinaryLength" Type="System.Int32">12</Property>
      <Property Name="AccountDomainSid" Type="System.Security.Principal.SecurityIdentifier" />
      <Property Name="Value" Type="System.String">S-1-5-18</Property>
    </Property>
    <Property Name="TimeCreated" Type="System.DateTime">4/25/2022 11:51:07 AM</Property>
    <Property Name="ActivityId" Type="System.Nullable`1[[System.Guid, System.Private.CoreLib, Version=6.0.0.0, Culture=neutral, PublicKeyToken=7cec85d7bea7798e]]" />
    <Property Name="RelatedActivityId" Type="System.Nullable`1[[System.Guid, System.Private.CoreLib, Version=6.0.0.0, Culture=neutral, PublicKeyToken=7cec85d7bea7798e]]" />
    <Property Name="ContainerLog" Type="System.String">System</Property>
    <Property Name="MatchedQueryIds" Type="System.UInt32[]" />
    <Property Name="Bookmark" Type="System.Diagnostics.Eventing.Reader.EventBookmark" />
    <Property Name="LevelDisplayName" Type="System.String">Information</Property>
    <Property Name="OpcodeDisplayName" Type="System.String" />
    <Property Name="TaskDisplayName" Type="System.String" />
    <Property Name="KeywordsDisplayNames" Type="System.Collections.ObjectModel.ReadOnlyCollection`1[System.String]">
      <Property Type="System.String">Classic</Property>
    </Property>
    <Property Name="Properties" Type="System.Collections.Generic.List`1[System.Diagnostics.Eventing.Reader.EventProperty]">
      <Property Type="System.Diagnostics.Eventing.Reader.EventProperty">
        <Property Name="Value" Type="System.String">Background Intelligent Transfer Service</Property>
      </Property>
      <Property Type="System.Diagnostics.Eventing.Reader.EventProperty">
        <Property Name="Value" Type="System.String">auto start</Property>
      </Property>
      <Property Type="System.Diagnostics.Eventing.Reader.EventProperty">
        <Property Name="Value" Type="System.String">demand start</Property>
      </Property>
      <Property Type="System.Diagnostics.Eventing.Reader.EventProperty">
        <Property Name="Value" Type="System.String">BITS</Property>
      </Property>
    </Property>
  </Object>
</Objects>



#>


( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]"  -maxevent 1 -ea 0).ToXml().Replace("><",">`n<")


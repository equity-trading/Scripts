
# $mydoc = new-object System.Xml.XmlDocument
$mydoc = [xml] @"
<catalog>
<book id="bk101">
    <author>Gambardella, Matthew</author>
    <title>XML Developers Guide</title>
    <genre>Computer</genre>
    <price>44.95</price>
    <publish_date>2000-10-01</publish_date>
    <description>An in-depth look at creating applications 
    with XML.</description>
</book>
<book id="bk102">
    <author>Ralls, Kim</author>
    <title>Midnight Rain</title>
    <genre>Fantasy</genre>
    <price>5.95</price>
    <publish_date>2000-12-16</publish_date>
    <description>A former architect battles corporate zombies, 
    an evil sorceress, and her own childhood to become queen 
    of the world.</description>
</book>
</catalog>
"@

$myevent=[xml] @"
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
"@

function Test-Xml {
    Param($xdoc)
    $xdoc.SelectNodes(“//author”)

}

function Test-Event-Xml {
    Param($xml_event)
    $xml_event.SelectNodes(“//Event")

}

# Test-Xml $mydoc

# Test-Event-Xml $myevent
# $mydoc

# $myevent | Select-Xml *

# $myevent.SelectNodes("//*") | Select-Object -Expand Name

# ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "String" -Depth 3
# ( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Document" | Select-Xml -XPath "//Object" | foreach {$_.node.InnerXML}
# OuterXml
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Document" | Select-Xml -XPath "//Object/Property" | 
    foreach { $_.node | select Name,Type,NodeType,IsEmpty,HasAttributes,Attributes,HasChildNode,ChildNodes,InnerXml} | ft 

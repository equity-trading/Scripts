
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

<# 
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "String" -Depth 3
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Document" | Select-Xml -XPath "//Object" | foreach {$_.node.InnerXML}
# OuterXml
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Document" | Select-Xml -XPath "//Object/Property" |  ForEach-Object { $_.node | Where-Object {$_.IsEmpty -ne "True"} | Select-Object Name,Type,NodeType,IsEmpty,HasAttributes,Attributes,HasChildNodes,ChildNodes,InnerXml} | Format-Table -AutoSize


@{n='Logs';e={($_.Group | Select-Object -First 3 @{n='Providers';e={'{0}({1})' -f $_.LogName,$_.Count}}).Providers.join(',') }},
@{n='LastTimeCreated';e={$_.Group | Select-Object -Expand TimeCreated.ToString('MM/dd HH:mm:ss.fff') -First 1}}

( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "Document" | Select-Xml -XPath "//Object/Property" |  
    ForEach-Object { $_.node | Where-Object {$_.IsEmpty -ne "True"} |
    Select-Object Name,Type,HasChildNodes,
        @{n="ChildNodesText";e={(if($_.HasChildNodes -eq "True") {$_.ChildNodes |Select-Object -first 5 '#text'}).join(',') }}}, ChildNodes,InnerXml | 
    Format-Table -AutoSize



Values              Count Group      Name
------              ----- -----      ----
{Message, #text}        1 {Property} Message, System.Xml.XmlChildNodes
{Id, #text}             1 {Property} Id, System.Xml.XmlChildNodes
{Version, #text}        1 {Property} Version, System.Xml.XmlChildNodes
{Qualifiers, #text}     1 {Property} Qualifiers, System.Xml.XmlChildNodes
{Level, #text}          1 {Property} Level, System.Xml.XmlChildNodes

#>


#############################################################
# Fet Event by RecID and Proiders
# Get-EventRecId <RecId>,<Providers>
# 
function Get-EventRecId {
    Param($RecId=11035, $Providers=('Service Control Manager'))
    $eNo=0; $EVENTS=Get-WinEvent -ProviderName $Providers -FilterXPath "*[System[EventRecordID=$RecId]]" -maxevent 100 -ea 0; $eTot=$EVENTS.Count
    "RecID: $RecId; Providers:$($Providers -join('; ')); Total: $eTot Event$(($eTot -ne 1)?'s':'') "
    if ($eTot) {
        foreach ($E in $EVENTS) {
            $pad=1;$eNo++; $E.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eNo of $(($EVENTS).Count)") -split("`n") |
            % { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }
        }
        "RecID: $RecId; Providers:$Providers; Total: $eNo Event$(($eNo -ne 1)?'s':'') "
    }
}

#############################################################
# Convert to XML
# 


( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Xml -As "String" -Depth 3

Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0 | % {$_.ToXml() -replace("><",">`n<")}
    
$RecId=11035; $Prvds=('Service Control Manager'); $eNo=0; $EVENTS=Get-WinEvent -ProviderName $Prvds -FilterXPath "*[System[EventRecordID=$RecId]]" -maxevent 100 -ea 0; $EVENTS | % {$pad=1;$eNo++; $_.ToXml() -replace("><",">`n<") -replace("^<Event","<Event #$eNo of $(($EVENTS).Count)") -split("`n")} |
  % { $str=$_; if($str -match "^</.*>") {$pad-=2} ; "{0,$pad}{1}" -f "","$str"; if( -not ($str -replace "'[^']+'","'X'" -replace '"[^"]+"','"X"' -match "<[^>]*>[^<]*</[^ ].*>|<.*/>|^</.*>")) {$pad+=2} }; "Total: $eNo Event$(($eNo -ne 1)?'s':'') "




#############################################################
# Convert to Json
# 
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Json 
( Get-WinEvent -ProviderName 'Service Control Manager' -FilterXPath "*[System[EventRecordID=11035]]" -maxevent 2 -ea 0) | ConvertTo-Json -Compress

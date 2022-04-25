# https://www.sharepointdiary.com/2014/03/export-list-items-to-xml-using-powershell.html
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
 
#Set these three variables accordingly
$WebURL  = "https://projects.crescent.com/"
$ListName = "External Projects"
$XMLFilePath = "E:\data\ExternalProjects.xml"
 
#Get the Web
$web = Get-SPWeb $WebURL
#Get the List
$ProjectList = $web.Lists[$ListName]
 
#Create a XML File
$XMLFile = New-Object System.Xml.XmlDocument
#Add XML Declaration
[System.Xml.XmlDeclaration] $xmlDeclaration = $XMLFile.CreateXmlDeclaration("1.0", "UTF-16", $null);
$XMLFile.AppendChild($xmlDeclaration) | Out-Null
    
 #Create Root Elemment "Projects"
$ProjectsElement = $XMLFile.CreateElement("Projects")
  
 #Iterate through each list item and send Rows to XML file
foreach ($Item in $ProjectList.Items)
{
  #Add "Project" node under "Projects" Root node
  $ProjectElement = $XMLFile.CreateElement("Project")
  #Add "ID" attribute to "Project" element
  $ProjectElement.SetAttribute("id", $Item["ID"])
  $ProjectsElement.AppendChild($ProjectElement)  | Out-Null
   
  #Populate Each Columns
  #Add "Description" node under "Project" node
  $DescriptionElement = $XMLFile.CreateElement("description"); 
  $DescriptionElement.InnerText = $Item["Description"]
  #Append it to "Project" node
  $ProjectElement.AppendChild($DescriptionElement) | Out-Null
   
  #Add "Project Manager" element under "Project" node
  $managerElement = $XMLFile.CreateElement("manager"); 
  $managerElement.InnerText = $Item["Project Manager"]
  #Append it to "Project" node
  $ProjectElement.AppendChild($managerElement) | Out-Null
   
  #Add "Cost" element under "Project" node
  $CostElement = $XMLFile.CreateElement("cost"); 
  $CostElement.InnerText = $Item["Cost"]
  #Append it to "Project" node
  $ProjectElement.AppendChild($CostElement) | Out-Null
}
#Close the Root Element
$XMLFile.AppendChild($ProjectsElement) | Out-Null
#Save all changes
$XMLFile.Save($XMLFilePath) 
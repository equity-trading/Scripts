# https://www.sharepointdiary.com/2018/01/export-sharepoint-online-list-data-to-xml-using-powershell.html
# Load SharePoint CSOM Assemblies
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
  
#Set parameter values
$SiteURL="https://Crescent.sharepoint.com/"
$ListName="Projects"
$XMLFile ="C:\Temp\ProjectData.xml"
 
Try{
    #Get Credentials to connect
    $Cred= Get-Credential
   
    #Setup the context
    $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
    $Ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.Username, $Cred.Password)
  
    #Get the web & List objects
    $Web = $Ctx.Web
    $Ctx.Load($Ctx.Web)
    $List = $Web.Lists.GetByTitle($ListName)
    $ListFields =$List.Fields
    $Ctx.Load($ListFields)
    $ListItems = $List.GetItems([Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()) 
    $Ctx.Load($ListItems)
    $Ctx.ExecuteQuery()
 
    #Create new XML File
    [System.XML.XMLDocument]$XMLDocument=New-Object System.XML.XMLDocument
 
    #Add XML Declaration
    $Declaration = $XMLDocument.CreateXmlDeclaration("1.0","UTF-8",$null)
    $XMLDocument.AppendChild($Declaration)
     
    #Create Root Node
    [System.XML.XMLElement]$XMLRoot=$XMLDocument.CreateElement($ListName)
  
    #Iterate through each List Item in the List
    Foreach ($Item in $ListItems)
    {
        #Add child node "Item"
        $ItemElement = $XMLDocument.CreateElement("Item")
        $ItemElement.SetAttribute("ID", $Item.ID)
        $XMLRoot.AppendChild($ItemElement)
 
        #Loop through each column of the List Item
        ForEach($Field in $ListFields | Where {$_.Hidden -eq $false -and $_.ReadOnlyField -eq $false -and $_.Group -ne "_Hidden"})
        {
            $FieldElement = $XMLDocument.CreateElement($Field.InternalName)
            $FieldElement.Set_InnerText($Item[$Field.InternalName])
            #Append to Root node
            $ItemElement.AppendChild($FieldElement)
        }
    }
    # Append Root Node to XML
    $XMLDocument.AppendChild($XMLRoot)
 
    #Save XML File
    $XMLDocument.Save($XMLFile)
 
    Write-Host -f Green "List Items Exported to XML!"
}
Catch {
        write-host -f Red "Error Exporting List Data to XML!" $_.Exception.Message
}
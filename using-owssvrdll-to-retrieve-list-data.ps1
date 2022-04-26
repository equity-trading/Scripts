Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
https://www.sharepointdiary.com/2012/02/using-owssvrdll-to-retrieve-list-data.html 
#Parameters
$SiteURL = "https://crescent.sharepoint.com/sites/marketing"
$ListName = "Contacts"
$ViewName = "All Items"
 
#Get Credentials to connect
$Cred= Get-Credential
 
Try {
    #Setup the context
    $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
    $Ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.Username, $Cred.Password)
 
    #Get Necessary Objects
    $Web = $Ctx.Web
    $List = $Web.Lists.GetByTitle($ListName)
    $View = $List.Views.getByTitle($ViewName)
    $Ctx.Load($Web)
    $Ctx.Load($List)
    $Ctx.Load($View)
    $Ctx.ExecuteQuery()
 
    #Request XML data throgh RPC
    $URL = "{0}/_vti_bin/owssvr.dll?Cmd=Display&List={1}&View={2}&Query=*&XMLDATA=TRUE" -f $Web.Url, $List.ID, $view.ID
    $WebClient = New-Object System.Net.WebClient 
    $WebClient.Credentials =  New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.Username, $Cred.Password)
    $WebClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
    $XML = $WebClient.DownloadString($URL)
    $WebClient.Dispose()
}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
}
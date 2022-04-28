[Cmdletbinding()]
[Alias("Highlight")]
Param(
        [Parameter(ValueFromPipeline=$true, Position=0)] $content,
        [Parameter(Position=1)] 
        [ValidateNotNull()]
        [String[]] $words = $(throw "Provide word[s] to be highlighted!")
)
# PS C:\home\src\Scripts> .\Grep-Word.ps1 -words 'Auth' -content (Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition)
# PS C:\home\src\Scripts> .\Grep-Word.ps1 -Highlight 'Auth' -content (Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition)
# PS C:\home\src\Scripts> Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition | select -first 1 | .\Grep-Word.ps1 -words "Auth"

# https://superuser.com/questions/1219110/is-it-possible-to-color-grep-output-in-powershell
# Original name was  Trace-Word
Function Grep-Word {
    [Cmdletbinding()]
    [Alias("Highlight")]
    Param(
            [Parameter(ValueFromPipeline=$true, Position=0)] $content,
            [Parameter(Position=1)] 
            [ValidateNotNull()]
            [String[]] $words = $(throw "Provide word[s] to be highlighted!")
    )
    
Begin
{
    
    $Color = @{       
                0='Yellow'      
                1='Magenta'     
                2='Red'         
                3='Cyan'        
                4='Green'       
                5 ='Blue'        
                6 ='DarkGray'    
                7 ='Gray'        
                8 ='DarkYellow'    
                9 ='DarkMagenta'    
                10='DarkRed'     
                11='DarkCyan'    
                12='DarkGreen'    
                13='DarkBlue'        
    }

    $ColorLookup =@{}

    For($i=0;$i -lt $words.count ;$i++)
    {
        if($i -eq 13)
        {
            $j =0
        }
        else
        {
            $j = $i
        }

        $ColorLookup.Add($words[$i],$Color[$j])
        $j++
    }
    
}
Process
{
$content | format-table -Wrap | Out-String -stream | ForEach-Object {

    $TotalLength = 0
           
    $_.split() | `
    Where-Object {-not [string]::IsNullOrWhiteSpace($_)} | ` #Filter-out whiteSpaces
    ForEach-Object{
                    if($TotalLength -lt ($Host.ui.RawUI.BufferSize.Width-10))
                    {
                        #"TotalLength : $TotalLength"
                        $Token =  $_
                        $displayed= $False
                        
                        Foreach($Word in $Words)
                        {
                            if($Token -like "*$Word*")
                            {
                                $Before, $after = $Token -Split "$Word"
                          
                                    
                                #"[$Before][$Word][$After]{$Token}`n"
                                
                                Write-Host $Before -NoNewline ; 
                                Write-Host $Word -NoNewline -Fore Black -Back $ColorLookup[$Word];
                                Write-Host $after -NoNewline ; 
                                $displayed = $true                                   
                                #Start-Sleep -Seconds 1    
                                #break  
                            }

                        } 
                        If(-not $displayed)
                        {   
                            Write-Host "$Token " -NoNewline                                    
                        }
                        else
                        {
                            Write-Host " " -NoNewline  
                        }
                        $TotalLength = $TotalLength + $Token.Length  + 1
                    }
                    else
                    {                      
                        Write-Host '' #New Line  
                        $TotalLength = 0 

                    }

                        #Start-Sleep -Seconds 0.5
                    
    }
    Write-Host '' #New Line               
}
}
end
{    }
# the last bracket
}


# Grep-Word -content (Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition ) -words 'Auth' 
# Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition  | Grep-Word -words 'Auth' 
# PS C:\home\src\Scripts> .\Grep-Word.ps1 -content (Get-Command -Name get-service -ParameterName InputObject -ParameterType ServiceController | select Definition ) -words Get-Service,InputObject,ServiceController

Grep-Word @PSBoundParameters
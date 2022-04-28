Param( 
[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)] 
[String[]] $ParameterName,
[String] $ParameterType="*",
[String[]] $Name="*",
[int] $SearchMode=0
)


# PS C:\home\src\Scripts> .\Get-CommandParameter.ps1 "InputObject" -ParameterType "ServiceController" -SearchMode 0
# PS C:\home\src\Scripts> .\Get-CommandParameter.ps1 * -ParameterType ServiceController
function save-cursorPosition {
    write-host -noNewLine "$([char]27)[s"
 }

 function restore-cursorPosition {
    write-host -noNewLine "$([char]27)[u"
 }
 function save-color {
    write-host -noNewLine "$([char]27)[#p"
 }

 function restore-color {
    write-host -noNewLine "$([char]27)[#q"
 }

Function Set-ColoredFilter {
    [Cmdletbinding()]
    [Alias("Highlight")]
    Param(
            [Parameter(ValueFromPipeline=$true, Position=0)] $content,
            [Parameter(Position=1)] 
            [ValidateNotNull()]
            [String[]] $Words = $(throw "Provide word[s] to be highlighted!"),
            [int] $SearchMode=0 
            # 0 : strict - line is printed if all words match
            # 1 : one    - line is printed if one word matches
            # 2 : all    - all lines are printed
    )
Begin {
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
    $SearchWords=@()
    For($i=0;$i -lt $Words.count ;$i++) {
        if ($Words[$i] -ne '*') {
            if($i -eq 13) { $j =0 }
            else { $j = $i }
            $word=$Words[$i] -replace('\*','')
            $SearchWords+=$word
            $ColorLookup.Add($word,$Color[$j])
            $j++
        }
    }
    # "SearchWords[$(($SearchWords).Length)]: $($SearchWords -join '; ')"
    # $content
    # "[{0}] var:`${1,-15} type:{2,-45} val:{3}" -f $MyInvocation.MyCommand.Name,"content",$content.GetType(),$content.replace("`r?`n","\n")

}
Process {
    $text=($content | format-table -Wrap | Out-String -stream)
    # "[{0}] var:`${1,-15} type:{2,-45} val:{3}" -f $MyInvocation.MyCommand.Name,"text",$text.GetType(),$text.replace("`r?`n","\n")
    # $text
    $MatchArr=@()

    foreach ($word in $SearchWords) {
        $MatchArr+='( $line -match "{0}" )' -f $word
    }
    $NotEmpty='-not [string]::IsNullOrWhiteSpace($line)'
    switch ($SearchMode) {
        0 { $MatchString=$MatchArr -join ' -and '  ; $MatchString='{0} -and ({1})' -f $NotEmpty, $MatchString }
        1 { $MatchString=$MatchArr -join ' -or '   ; $MatchString='{0} -and ({1})' -f $NotEmpty, $MatchString }
        default { $MatchString='$true' } 
    }
    $MatchBlock=[scriptblock]::Create($MatchString)
    # "[{0}] var:`${1,-15} type:{2,-45} val:{3}" -f $MyInvocation.MyCommand.Name,"MatchString",$MatchString.GetType(),$MatchString
    # $MatchBlock.ToString()
    ForEach ($line in $text.split("`r?`n")) { 
        if ( & $MatchBlock  ) {
            $LineLength = 0
            ForEach ($Token in $line.split()) {
                $displayed= $False     
                $LineLength = $LineLength + $Token.Length  + 1
                if($LineLength -gt ($Host.ui.RawUI.BufferSize.Width-4)) {
                    Write-Host '' #New Line  
                    $LineLength = 0 
                }
                Foreach($Word in $SearchWords) {
                    if($Token -like "*$Word*") {
                        $Before, $After = $Token -Split "$Word"
                        Write-Host $Before -NoNewline
                        Write-Host $Word -NoNewline -Fore Black -Back $ColorLookup[$Word];
                        Write-Host $After -NoNewline ; 
                        $displayed = $true                                   
                    }
                }
                If (-not $displayed) { Write-Host "$Token " -NoNewline }
                else { Write-Host " " -NoNewline }
                # Start-Sleep -Seconds 0.5                   
            }
            Write-Host '' #New Line
        }
    }
}
end {    }
# the last bracket
}
Function Out-Table {
    Param([Parameter(ValueFromPipeline=$true)] $content)
    "[{0}] start" -f $MyInvocation.MyCommand.Name
    $content | Format-Table -Auto -Wrap Description
}

Function Out-Record {
    "[{0}] start" -f $MyInvocation.MyCommand.Name
    Select-Object *
}

Function Out-Result {
    Param([Parameter(ValueFromPipeline=$true)] $Objects)
    "[{0}] start" -f $MyInvocation.MyCommand.Name
    if ($Objects.Count -gt 1) { 
        "[{0}] There are {1} objects" -f $MyInvocation.MyCommand.Name, $Objects.Count
        if ( Get-Command -Name Out-Table -CommmandType Function -ErrorAction Ignore ) {  $Objects | Out-Table  } else {  $Objects | Format-Table * }
    } elseif ($Objects.Count -eq 1) { 
        "[{0}] is just one object" -f $MyInvocation.MyCommand.Name, $Objects.Count
        if ( Get-Command -Name Out-Table -CommmandType Function -ErrorAction Ignore ) {   $Objects | Out-Record  } else {  $Objects | Select-Object * }
    } else {
        "[{0}] is no objects" -f $MyInvocation.MyCommand.Name
    }

}

Function Get-ScriptBlock {
    param($ScriptBlock)
    try{
        # "[{0}] Running ScriptBlock {1}" -f $MyInvocation.MyCommand.Name, $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
        Invoke-Command -ScriptBlock $ScriptBlock
    } catch {
        "[{0}] Error in ScriptBlock:{1}" -f $MyInvocation.MyCommand.Name, $ScriptBlock.ToString()
        "[{0}] Error in Expanded:{1}" -f $MyInvocation.MyCommand.Name, $ExecutionContext.InvokeCommand.ExpandString($ScriptBlock)
        # "[{0}] ArgumentList:{1}" -f $MyInvocation.MyCommand.Name,$ArgumentList -join(",")
    }
}

function Get-CommandParameter {
    Param( [String[]] $Name,
        [String[]] $ParameterName,
        [String] $ParameterType,
        [int] $SearchMode=0
    )
    $CmdStr='Get-Command -Name $Name -ParameterName $ParameterName -ParameterType $ParameterType'
    "[{0}] {1}" -f $MyInvocation.MyCommand.Name, $ExecutionContext.InvokeCommand.ExpandString($CmdStr)
    
    try { 
        # $CmdScript=Create($ExecutionContext.InvokeCommand.ExpandString($CmdStr))
        $CmdScript=[ScriptBlock]::Create($CmdStr)
    } catch {
        "[{0}] No such commands" -f $MyInvocation.MyCommand.Name, $ExecutionContext.InvokeCommand.ExpandString($CmdStr)
        return
    }
    # $CmdScript={ Get-Command -Name $Name -ParameterName $ParameterName -ParameterType $ParameterType } #.GetNewClosure()
    

    # Get-Variable CmdScript
    # "[{0}] var:`${1,-15} type:{2,-45} val:{3}" -f $MyInvocation.MyCommand.Name,"CmdScript",$CmdScript.GetType(),$CmdScript.Tostring()
    
    # $ExpandedStr = $ExecutionContext.InvokeCommand.ExpandString($CmdScript)
    # "[{0}] var:`${1,-15} type:{2,-45} val:{3}" -f $MyInvocation.MyCommand.Name,"ExpandedStr",$ExpandedStr.GetType(),$ExpandedStr.Tostring()
    # Get-ScriptBlock $CmdScript | Format-Table -Wrap Definition

    Get-ScriptBlock $CmdScript | Select-Object Definition  | Set-ColoredFilter -Words @($Name,$ParameterName,$ParameterType) -SearchMode $SearchMode

    # | Select-Object Definition |  Set-ColoredFilter -words @($ParameterName,$ParameterType)
    # Get-Command $GetCommandOptions | select-object $Definition | Select-String -InputObject {$_.Definition} -Pattern $ParameterName | Set-ColoredFilter -words @($ParameterName,$ParameterType)
    return         
    Get-Command $GetCommandOptions | Select-String -InputObject $Definition -Pattern $ParameterName | Set-ColoredFilter -words @($ParameterName,$ParameterType)
}

# Set-ColoredFilter -content (Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition ) -words 'Auth' 
# Get-Command -ParameterName *Auth* -ParameterType AuthenticationMechanism | select Definition  | Set-ColoredFilter -words 'Auth' 
Get-CommandParameter -Name $Name -ParameterName $ParameterName -ParameterType $ParameterType -SearchMode $SearchMode

############################################
# ascii-codes replaces non-ASCII characters with hex codes
# $orig="`e[33m yellow `e[m"; $orig | ascii-codes
# 0x1B[33m yellow 0x1B[m
# [regex]::Replace(" char:{0} `e[33m yellow `e[m" -f [char]0x7e,"[^ -z]", { param($v); '<{0:X}>' -f  [Convert]::ToUInt32([char]$v.Value) } )
$Global:Backtick = @{}

function asciiToHex($a) {
	$b = $a.ToCharArray();
	Foreach ($element in $b) {$c = $c + "%#x" + [System.String]::Format("{0:X}",
	[System.Convert]::ToUInt32($element)) + ";"}
	$c
}


foreach ($Char in "0abefnrtv``".ToCharArray()) {
    $Global:Backtick[$ExecutionContext.InvokeCommand.ExpandString("``$Char")] = "``$Char"
}

$Global:SpecialCharacters = '[' + (-Join $Global:Backtick.get_Keys()) + ']'

function escape-codes($Text) {
    [regex]::Replace($Text, $Global:SpecialCharacters, { param($Match) $Backtick[$Match.Value] })
}


function ascii-codes() {
    [CmdletBinding()][OutputType([string])] param( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] [string[]]$strings )
	Process {
		$strings |? {$_} |% { 
			$orig=$_.TocharArray()
			$new= ( $orig |% { $code=[int] $_; if ( $code -lt 0x20 -or $code -gt 0x7F  ) {'0x{0,2:X2}' -f [int]$_ } else {$_}} )
			$new -join ('')
		}
	}
}

#  [regex]::Replace("`e[33m yellow `e[m","[`e]", { param($v); switch ($v.Value) { "`e" {'`e'} "`b" {'`b'} "`a" {'`a'} default {'.'} } } ) # note: not working
# " char:{0} `e[33m yellow `e[m" -f [char]0x7e | get-escape-codes
function get-escape-codes() {
    [CmdletBinding()][OutputType([string])] param( [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')] [string[]]$strings )
	Process {
		$strings|% { [regex]::Replace($_, '[^ -z]', { param($match); $code=[Convert]::ToUInt32([char]$match.Value); switch ($code) { 0xa {'`n'} 0xd {'`r'} 0x9 {'`t'} default {'<{0:X2}>' -f $code}  } } ) }
	}
}

# "`e[33m yellow `e[m`r`n`t~/.ssh" | get-escape-codes
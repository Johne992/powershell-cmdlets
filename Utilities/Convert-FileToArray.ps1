# Read the contents of the file into an array of strings
$lines = Get-Content "path"

# Remove empty lines
$nonEmptyLines = $lines | Where-Object { $_.Trim().Length -gt 0}

# Enclose each line in quotes and escape double quotes
$quotedLines = $nonEmptyLines | ForEach-Object { "`"$($_ -replace '"', '""')`""}

$arraySyntax = "@(" + ($quotedLines -join ', ') + ")"

Set-Content "path" -Value $arraySyntax
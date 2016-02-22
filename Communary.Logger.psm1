# Communary.Logger
# Author: Øyvind Kallstad

# read functions
Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Functions') | ForEach-Object {
    . $_.FullName
}
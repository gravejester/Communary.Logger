# Communary.Logger

A logging framework for PowerShell.

## Features

Supports logging to

- File
    - Minimal
    - Normal (Plain Text)
    - CMTrace (Can be viewed using CMTrace)
- Windows Event Log

Also includes a log rotation helper function to keep track of maximum file size and number of log files to keep.

## Usage

Use New-Log to create a new log, and Write-Log to write to it. Both functions have built in help that you can access using the Get-Help cmdlet.
function New-Log {
    <#
        .SYNOPSIS
            Create a new log.
        .DESCRIPTION
            The New-Log function is used to create a new log file or Windows Event log. A log object is also created
            and either saved in the global PSLOG variable (default) or sent to the pipeline. The latter is useful if
            you need to write to different log files in the same script/function.
        .EXAMPLE
            New-Log '.\myScript.log'
            Create a new log file called 'myScript.log' in the current folder, and save the log object in $global:PSLOG
        .EXAMPLE
            New-Log '.\myScript.log' -Header 'MyHeader - MyScript' -Append -Format 'CMTrace'
            Create a new log file called 'myScript.log' if it doesn't exist already, and add a custom header to it.
            The log format used for logging by Write-Log is the CMTrace format.
        .EXAMPLE
            $log1 = New-Log '.\myScript_log1.log'; $log2 = New-Log '.\myScript_log2.log'
            Create two different logs that can be written to depending on your own internal script logic. Remember to
            pass the correct log object to Write-Log!
        .EXAMPLE
            New-Log -EventLogName 'PowerShell Scripts' -EventLogSource 'MyScript'
            Create a new log called 'PowerShell Scripts' with a source of 'MyScript', for logging to the Windows Event Log.
        .NOTES
            Author: Øyvind Kallstad
            Date: 21.11.2014
            Version: 1.0
    #>
    [CmdletBinding(DefaultParameterSetName = 'LogFile')]
    param (
        # Path to log file.
        [Parameter(ParameterSetName = 'LogFile', Mandatory, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string] $Path,

        # Optionally define a header to be added when a new empty log file is created.
        [Parameter(ParameterSetName = 'LogFile')]
        [string] $Header,

        # If log file already exist, append instead of creating a new empty log file.
        [Parameter(ParameterSetName = 'LogFile')]
        [switch] $Append,

        # Maximum size of log file.
        [Parameter(ParameterSetName = 'LogFile')]
        [int64] $MaxLogSize = 1048576, # in bytes, default is 1048576 = 1 MB

        # Maximum number of log files to keep. Default is 3. Setting MaxLogFiles to 0 will keep all log files.
        [Parameter(ParameterSetName = 'LogFile')]
        [ValidateRange(0,99)]
        [int32] $MaxLogFiles = 3,

        # The format of the log file. Valid choices are 'Minimal', 'PlainText' and 'CMTrace'.
        # The 'Minimal' format will just pass the log entry to the log file, while the 'PlainText' includes meta-data.
        # CMTrace format are viewable using the CMTrace.exe tool.
        [Parameter(ParameterSetName = 'LogFile')]
        [ValidateSet('Minimal','PlainText','CMTrace')]
        [string] $Format = 'PlainText',

        # Specifies the name of the event log.
        [Parameter(ParameterSetName = 'EventLog', Mandatory)]
        [string] $EventLogName,

        # Specifies the name of the event log source.
        [Parameter(ParameterSetName = 'EventLog', Mandatory)]
        [string] $EventLogSource,

        # Define the default Event ID to use when writing to the Windows Event Log.
        # This Event ID will be used when writing to the Windows log, but can be overrided by the Write-Log function.
        [Parameter(ParameterSetName = 'EventLog')]
        [string] $DefaultEventID = '0',

        # When UseGlobalVariable is True, the log object is saved in the global PSLOG variable,
        # otherwise it's returned to the pipeline. Default value is True.
        [Parameter()]
        [switch] $UseGlobalVariable = $true
    )

    if ($PSCmdlet.ParameterSetName -eq 'EventLog') {
        $logType = 'EventLog'
        # when creating (and writing) to the event log, you need to run with elevated user rights
        $windowsIdentity=[System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($windowsIdentity)
        $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
        if ($windowsPrincipal.IsInRole($adm)) {
            $elevated = $true
            Remove-Variable -Name Format,MaxLogSize,MaxLogFiles -ErrorAction SilentlyContinue
            # create new event log if needed
            try {
                if (-not([System.Diagnostics.EventLog]::SourceExists($EventLogName))) {
                    New-EventLog -Source $EventLogSource -LogName $EventLogName
                    Write-Verbose "Created new event log (Name: $($EventLogName), Source: $($EventLogSource))"
                }
                else {
                    Write-Verbose "$($EventLogName) exists, skip create new event log."
                }
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }

        else {
            Write-Warning 'When creating a Windows Event Log you need to run as a user with elevated rights!'
            $elevated = $false
        }
    }

    else {
        $logType = 'LogFile'
        # create new log file if needed
        if((-not $Append) -or (-not(Test-Path $Path))){
            try {
                if($Header){
                    Set-Content -Path $Path -Value $Header -Encoding 'UTF8' -Force
                }
                else{
                    Set-Content -Path $Path -Value $null -Encoding 'UTF8' -Force
                }
                Write-Verbose "Created new log file ($($Path))"
            }
            catch{
                Write-Warning $_.Exception.Message
            }
		}
    }

    # create log object
    $logObject = [PSCustomObject] [Ordered] @{
        LogType = $logType
        LogFormat = $Format
        Path = [System.IO.Path]::GetFullPath($Path)
        MaxLogSize = $MaxLogSize
        MaxLogFiles = $MaxLogFiles
        LogHeader = $Header
        EventLogName = $EventLogName
        EventLogSource = $EventLogSource
        DefaultEventID = $DefaultEventID
        Elevated = $elevated
    }

    # save logObject to a global variable
    if($UseGlobalVariable){
        $global:PSLOG = $logObject
    }
    # unless UseGlobalValiable is false, then return it to the pipeline instead
    else{
        Write-Output $logObject
    }
}

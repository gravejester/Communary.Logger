function Write-Log {
    <#
        .SYNOPSIS
            Write to the log.
        .DESCRIPTION
            The Write-Log function is used to write to the log. It is using the log object created by New-Log
            to determine if it's going to write to a log file or to a Windows Event log.
        .EXAMPLE
            Write-Log 'Finished running WMI query'
            Get the log object from $global:PSLOG and write to the log.
        .EXAMPLE
            $myLog | Write-Log 'Finished running WMI query'
            Use the log object saved in $myLog and write to the log.
        .EXAMPLE
            Write-Log 'WMI query failed - Access denied!' -LogType Error -PassThru | Write-Warning
            Will write an error to the event log, and then pass the log entry to the Write-Warning cmdlet.
        .NOTES
            Author: Øyvind Kallstad
            Date: 21.11.2014
            Version: 1.0
            Dependencies: Invoke-LogRotation
    #>
    [CmdletBinding()]
    param (
        # The text you want to write to the log.
        [Parameter(Position = 0)]
        [string] $LogEntry,

        # The type of log entry. Valid choices are 'Error', 'FailureAudit','Information','SuccessAudit' and 'Warning'.
        # Note that the CMTrace format only supports 3 log types (1-3), so 'Error' and 'FailureAudit' are translated to CMTrace log type 3, 'Information' and 'SuccessAudit'
        # are translated to 1, while 'Warning' is translated to 2. 'FailureAudit' and 'SuccessAudit' are only really included since they are valid log types when
        # writing to the Windows Event Log.
        [Parameter()]
        [ValidateSet('Error','FailureAudit','Information','SuccessAudit','Warning')]
        [string] $LogType = 'Information',

        # Event ID. Only applicable when writing to the Windows Event Log.
        [Parameter()]
        [string] $EventID,

        # The log object created using the New-Log function. Defaults to reading the global PSLOG variable.
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [object] $Log = $global:PSLOG,

        # PassThru passes the log entry to the pipeline for further processing.
        [Parameter()]
        [switch] $PassThru
    )

    try {

        # get information from log object
        $logObject = $Log

        # translate event types to CMTrace format
        if ($logObject.LogFormat -eq 'CMTrace') {
            switch ($LogType) {
                'Error' {$cmType = '3';break}
                'FailureAudit' {$cmType = '3';break}
                'Information' {$cmType = '1';break}
                'SuccessAudit' {$cmType = '1';break}
                'Warning' {$cmType = '2';break}
                DEFAULT {$cmType = '1'}
            }
        }

        # get invocation information
        $thisInvocation = (Get-Variable -Name 'MyInvocation' -Scope 1).Value

        # get calling script info
        if(-not ($thisInvocation.ScriptName)){
            $scriptName = $thisInvocation.MyCommand
            $file = "$($scriptName)"
	    }
	    else{
            $scriptName = Split-Path -Leaf ($thisInvocation.ScriptName)
            $file = "$($scriptName):$($thisInvocation.ScriptLineNumber)"
	    }

        # get calling command info
        $component = "$($thisInvocation.MyCommand)"

        if ($logObject.LogType -eq 'EventLog') {
            if($logObject.Elevated) {

                # if EventID is not specified use default event id from the log object
                if([system.string]::IsNullOrEmpty($EventID)) {
                    $EventID = $logObject.DefaultEventID
                }

                Write-EventLog -LogName $logObject.EventLogName -Source $logObject.EventLogSource -EntryType $LogType -EventId $EventID -Message $LogEntry
            }

            else {
                Write-Warning 'When writing to the Windows Event Log you need to run as a user with elevated rights!'
            }
        }

        else {
            # create a mutex, so we can lock the file while writing to it
            $mutex = New-Object System.Threading.Mutex($false, 'LogMutex')

            # handle the different log file formats
            switch ($logObject.LogFormat) {

                'Minimal' { $logEntryString = $LogEntry; break }

                'PlainText' {
                    $logEntryString = "$((Get-Date).ToString()) $($LogType.ToUpper()) $($LogEntry)"
                    # when component and file are equal
                    #if($component -eq $file){
                        #$logEntryString = "$((Get-Date).ToString()) $($LogType.ToUpper()) [$($file)] $($LogEntry)"
                        #Write-Verbose $logEntryString ####
                    #}

                    # log entry when component and file are not equal
                    #else{
                        #$logEntryString = "$((Get-Date).ToString()) $($LogType.ToUpper()) [$($component) - $($file)] $($LogEntry)"
                    #}
                    break
                }

                'CMTrace' {
                    $date = Get-Date -Format 'MM-dd-yyyy'
                    $time = Get-Date -Format 'HH:mm:ss.ffffff'
                    #$logEntryString = "<![LOG[$LogEntry]LOG]!><time=""$time"" date=""$date"" component=""$component"" context="""" type=""$cmType"" thread=""$pid"" file=""$file"">"
                    $logEntryString = "<![LOG[$LogEntry]LOG]!><time=""$time"" date=""$date"" component="""" context="""" type=""$cmType"" thread=""$pid"" file="""">"
                    break
                }
            }

            # write to the log file
            [void]$mutex.WaitOne()
            Add-Content -Path $logObject.Path -Value $logEntryString
            $mutex.ReleaseMutex()

            # invoke log rotation if log is file
            if ($logObject.LogType -eq 'LogFile') {
                Invoke-LogRotation
            }

            # handle PassThru
            if ($PassThru) {
                Write-Output $LogEntry
            }
        }
    }

    catch {
        Write-Warning $_.Exception.Message
    }
}
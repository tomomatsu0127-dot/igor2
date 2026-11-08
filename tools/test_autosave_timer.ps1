param([string]$Directory=(Get-Location).Path)
$ErrorActionPreference='Stop'
$taskBase=$Directory.Replace('\',':').Replace('C::','C:')+':'
$taskSession='timer_'+[Guid]::NewGuid().ToString('N').Substring(0,12)
$taskFile=Join-Path $Directory ('timed_autosave\'+$taskSession+'_1.pxp')
$taskProcedure=$taskSession+'_main.ipf';$taskTests=$taskSession+'_test.ipf'
Copy-Item -LiteralPath (Join-Path $Directory 'new.ipf') -Destination (Join-Path $Directory $taskProcedure)
Copy-Item -LiteralPath (Join-Path $Directory 'tests230.ipf') -Destination (Join-Path $Directory $taskTests)
$taskStartup='OpenProc "'+$taskBase+$taskProcedure+'"; OpenProc "'+$taskBase+$taskTests+'"; Execute/P/Z "COMPILEPROCEDURES "; Execute/P/Z "MH3_StartTimed(\"'+$taskBase+'\",\"'+$taskSession+'\")"'
$taskExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe'
$taskProcess=Start-Process -FilePath $taskExe -ArgumentList @('/I','/UNATTENDED','/X',('"'+$taskStartup+'"')) -WindowStyle Hidden -PassThru
$taskClock=[Diagnostics.Stopwatch]::StartNew()
try {
    $taskStable=0;$taskLastLength=-1
    while($taskClock.Elapsed.TotalSeconds -lt 340) {
        Start-Sleep -Milliseconds 500
        if($taskProcess.HasExited) {throw 'Isolated autosave timer process exited.'}
        if(Test-Path -LiteralPath $taskFile) {
            $taskLength=(Get-Item -LiteralPath $taskFile).Length
            if($taskLength -eq $taskLastLength -and $taskLength -gt 0) {$taskStable++} else {$taskStable=0}
            $taskLastLength=$taskLength
            if($taskStable -ge 4) {break}
        }
    }
    if($taskStable -lt 4) {throw 'No completed automatic recovery file within 340 seconds.'}
    [pscustomobject]@{File=$taskFile;ObservedElapsedSeconds=$taskClock.Elapsed.TotalSeconds;CreatedPID=$taskProcess.Id;Mode='Actual idle background timer, no forced tick'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Directory 'scratch\actual_timer.json') -Encoding UTF8
    Get-Content -LiteralPath (Join-Path $Directory 'scratch\actual_timer.json') -Raw
} finally {
    if(!$taskProcess.HasExited) {$taskProcess.Kill()}
}

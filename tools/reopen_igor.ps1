param([Parameter(Mandatory=$true)][string]$Experiment,[Parameter(Mandatory=$true)][string]$Commands,[string]$Log='scratch/reopen.json',[string]$BeforeCompile='')
$ErrorActionPreference='Stop'
$taskToken=Get-Random -Minimum 1000000 -Maximum 1900000000
$taskExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe'
$taskProcess=Start-Process -FilePath $taskExe -ArgumentList @('/I','/Automation','/UNATTENDED','/X',('"Variable/G root:MHReopenIsolation='+$taskToken+'"')) -WindowStyle Hidden -PassThru
try {
    $taskApp=$null
    for($taskAttempt=0;$taskAttempt -lt 25;$taskAttempt++) {
        Start-Sleep -Seconds 1
        try {$taskApp=[Runtime.InteropServices.Marshal]::GetActiveObject('IgorPro.Application');break} catch {if($taskProcess.HasExited){throw 'Isolated Igor exited during startup.'}}
    }
    if(!$taskApp) {throw 'Isolated Igor automation is unavailable.'}
    $taskErr=0;$taskMessage='';$taskHistory='';$taskResults=''
    $taskApp.Execute2(0,65001,'Printf "%.0f",root:MHReopenIsolation',[ref]$taskErr,[ref]$taskMessage,[ref]$taskHistory,[ref]$taskResults)
    if($taskErr -ne 0 -or $taskHistory -notmatch ('\s'+$taskToken+'\s*$')) {throw 'Isolation token mismatch. No Experiment was opened.'}
    $taskApp.LoadExperiment(0,2,'',(Resolve-Path -LiteralPath $Experiment).Path)
    if($BeforeCompile) {
        $taskQueued='Execute/P/Z "'+$BeforeCompile.Replace('\','\\').Replace('"','\"')+'"'
        $taskApp.Execute2(0,65001,$taskQueued,[ref]$taskErr,[ref]$taskMessage,[ref]$taskHistory,[ref]$taskResults)
        if($taskErr) {throw ('Procedure replacement failed: '+$taskMessage)}
        Start-Sleep -Seconds 1
    }
    $taskApp.CompileProcedures(1)
    $taskApp.Execute2(0,65001,$Commands,[ref]$taskErr,[ref]$taskMessage,[ref]$taskHistory,[ref]$taskResults)
    $taskRecord=[pscustomobject]@{Error=$taskErr;Message=$taskMessage;History=$taskHistory;Results=$taskResults;CreatedPID=$taskProcess.Id;IsolationVerified=$true}
    $taskRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Log -Encoding UTF8
    $taskRecord | ConvertTo-Json -Depth 5
    if($taskErr) {throw 'The restarted Igor validation returned an error.'}
} finally {
    # Never call Quit on an unverified automation object or terminate another PID.
    if(!$taskProcess.HasExited) {$taskProcess.Kill()}
}

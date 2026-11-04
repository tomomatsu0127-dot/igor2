param([string]$Command='XRD_RunV127Tests()',[string]$TestProc='xrd_workbench_v1.2.7/tests/xrd_v127_tests',[string]$Log='scratch/v127/native124_com.txt',[string]$Experiment='')
$ErrorActionPreference='Stop'
$taskToken=Get-Random -Minimum 1000000 -Maximum 1900000000
$taskExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe'
$taskRoot=(Get-Location).Path
New-Item -ItemType Directory -Force (Split-Path -Parent $Log) | Out-Null
$taskProcess=Start-Process -FilePath $taskExe -ArgumentList @('/I','/Automation','/UNATTENDED','/X',('"Variable/G root:XRD127Isolation='+$taskToken+'"')) -WindowStyle Hidden -PassThru
$taskApp=$null
$taskVerified=$false
function Invoke-TaskIgor([string]$code) {
    $taskErr=0;$taskMsg='';$taskHistory='';$taskResult=''
    $taskApp.Execute2(0,65001,$code,[ref]$taskErr,[ref]$taskMsg,[ref]$taskHistory,[ref]$taskResult)
    Add-Content -LiteralPath $Log -Value ($code+"`n"+$taskHistory+"`nError="+$taskErr+' '+$taskMsg) -Encoding utf8
    if($taskErr){throw ('Igor error '+$taskErr+': '+$taskMsg+' '+$taskHistory)}
    return $taskHistory
}
function Task-IgorPath([string]$path){return (Join-Path $taskRoot $path).Replace('\',':').Replace('C::','C:').Replace('/',':')}
try {
    $taskApp=$null
    for($taskAttempt=0;$taskAttempt -lt 30;$taskAttempt++){
        Start-Sleep -Seconds 1
        try {$taskApp=[Runtime.InteropServices.Marshal]::GetActiveObject('IgorPro.Application');break} catch {if($taskProcess.HasExited){throw 'Isolated Igor exited during startup'}}
    }
    if(!$taskApp){throw 'Isolated Igor automation unavailable after startup wait'}
    $taskIdentity=Invoke-TaskIgor 'Printf "%.0f",root:XRD127Isolation'
    if($taskIdentity -notmatch ('\s'+$taskToken+'\s*$')){throw 'Isolated instance identity not verified.'}
    $taskVerified=$true
    if($Experiment){$taskApp.LoadExperiment(0,2,'',(Join-Path $taskRoot $Experiment))}
    Invoke-TaskIgor 'Variable/G root:taskHistory=CaptureHistoryStart()' | Out-Null
    Invoke-TaskIgor ('OpenProc "'+(Task-IgorPath 'xrd_workbench_v1.2.7/xrd_main.ipf')+'";OpenProc "'+(Task-IgorPath ($TestProc+'.ipf'))+'"') | Out-Null
    try {$taskApp.CompileProcedures(1)} catch {
        Invoke-TaskIgor 'Print CaptureHistory(root:taskHistory,0)' | Write-Output
        throw
    }
    Invoke-TaskIgor 'MoveWindow/F 0,0,1920,1080' | Out-Null
    $taskOutput=Invoke-TaskIgor $Command
    Write-Output $taskOutput
    if($taskOutput -match '(?im)(^|[\r\n])\s*(FAIL:|(?:V[0-9]+\s+)?RUNTIME ERROR(?:\s|:))'){throw "Native assertions failed; see log."}
} finally {
    # Only the PID created above can be terminated, even if COM binds elsewhere.
    if(!$taskProcess.HasExited){$taskProcess.Kill()}
    $taskApp=$null
}

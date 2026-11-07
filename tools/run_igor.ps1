param(
    [string]$Procedure='mh_vsm_analyzer_v2.2.0/MH_VSM_Analyzer_v2_2_0.ipf',
    [string]$Tests='',
    [string]$Commands='Print "COMPILED"; HMH_Init(); Print HMG_Init()',
    [string]$Experiment='',
    [string]$Log='scratch/compile.txt'
)
$ErrorActionPreference='Stop'
function Quote-Igor([string]$value) { '"'+$value.Replace('\','\\').Replace('"','\"')+'"' }
$taskRoot=(Get-Location).Path
$taskBase=$taskRoot.Replace('\',':').Replace('C::','C:')+':'
$taskLog=Join-Path $taskRoot $Log
[IO.Directory]::CreateDirectory((Split-Path $taskLog)) | Out-Null
$taskStartup='Variable/G root:MHIsolatedTest=1; Variable/G root:MHTestCapture=CaptureHistoryStart(); '
if($Experiment) {$taskStartup+='Execute/P/Z '+(Quote-Igor ('LoadExperiment '+(Quote-Igor ($taskBase+$Experiment.Replace('/',':')))))+'; '}
$taskStartup+='OpenProc '+(Quote-Igor ($taskBase+$Procedure.Replace('/',':')))+'; '
if($Tests) {$taskStartup+='OpenProc '+(Quote-Igor ($taskBase+$Tests.Replace('/',':')))+'; '}
$taskStartup+='Execute/P/Z "COMPILEPROCEDURES "; Execute/P/Z '+(Quote-Igor $Commands)+'; '
$taskWrite='String/G root:MHTestLog=CaptureHistory(root:MHTestCapture,1); Variable refNum; Open refNum as '+(Quote-Igor ($taskBase+$Log.Replace('/',':')))+'; fprintf refNum,"%s",root:MHTestLog; Close refNum'
$taskStartup+='Execute/P/Z '+(Quote-Igor $taskWrite)+'; Execute/P "Quit/N"'
$taskInfo=[Diagnostics.ProcessStartInfo]::new('C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe')
$taskInfo.UseShellExecute=$false
$taskInfo.CreateNoWindow=$true
$taskInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$taskInfo.Arguments='/I /UNATTENDED /X "'+$taskStartup+'"'
$taskProcess=[Diagnostics.Process]::Start($taskInfo)
try {
    if(!$taskProcess.WaitForExit(45000)) {throw 'The isolated Igor test timed out.'}
} finally {
    # Only the exact /I process created by this invocation may be terminated.
    if(!$taskProcess.HasExited) {$taskProcess.Kill()}
}
if(!(Test-Path -LiteralPath $taskLog)) {throw 'Igor did not write the requested log.'}
Get-Content -LiteralPath $taskLog -Raw -Encoding UTF8

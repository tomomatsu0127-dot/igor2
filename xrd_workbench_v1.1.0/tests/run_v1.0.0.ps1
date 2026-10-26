param(
 [string]$IgorExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe',
 [ValidateSet('smoke','integration','edges','core','saveundo','missinghkl')][string]$Suite='smoke',
 [string]$OutputDirectory=(Join-Path $env:TEMP ('XRD_v100_'+(Get-Date -Format 'yyyyMMdd_HHmmss')))
)
$ErrorActionPreference='Stop'
function IgorQuote([string]$Value) { return '"'+$Value.Replace('\','\\').Replace('"','\"')+'"' }
function IgorPath([string]$Value) { return ($Value.Replace('\',':') -replace '^([A-Za-z])::','$1:') }
$taskPackage=Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$taskOutput=(IgorPath ([IO.Path]::GetFullPath($OutputDirectory)))+':'
$taskBase=(IgorPath $taskPackage)+':'
switch($Suite) {
 smoke {$taskCommand='XRD_RunV100Smoke("'+$taskOutput+'")'}
 integration {$taskCommand='XRD_RunV100Guard("'+$taskBase+'tests:fixtures_v053:","'+$taskOutput+'")'}
 edges {$taskCommand='XRD_RunV100Edges("'+$taskOutput+'")'}
 core {$taskCommand='XRD_RunV100CoreTests("'+$taskOutput+'")'}
 saveundo {$taskCommand='XRD_RunV100SaveUndoTests("'+$taskBase+'tests:fixtures:","'+$taskOutput+'")'}
 missinghkl {$taskCommand='XRD_RunV82Tests("'+$taskBase+'tests:fixtures_v082:","'+$taskOutput+'")'}
}
$taskSave='String/G root:testLog=CaptureHistory(root:testCapture,1); Variable refNum; Open refNum as '+(IgorQuote ($taskOutput+'result.txt'))+'; fprintf refNum,"%s",root:testLog; Close refNum'
$taskStartup='Variable/G root:testCapture=CaptureHistoryStart(); OpenProc '+(IgorQuote ($taskBase+'xrd_main.ipf'))+'; OpenProc '+(IgorQuote ($taskBase+'tests:xrd_v100_tests.ipf'))+'; Execute/P/Z "COMPILEPROCEDURES "; Execute/P/Z '+(IgorQuote $taskCommand)+'; Execute/P/Z '+(IgorQuote $taskSave)+'; Execute/P "Quit/N"'
$taskInfo=[Diagnostics.ProcessStartInfo]::new($IgorExe)
$taskInfo.UseShellExecute=$false
$taskInfo.CreateNoWindow=$true
$taskInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$taskInfo.Arguments='/I /UNATTENDED /X "'+$taskStartup+'"'
$taskProcess=[Diagnostics.Process]::Start($taskInfo)
if(!$taskProcess.WaitForExit(60000)) {
 $taskProcess.Kill()
 throw 'Isolated check timed out. Only the process created by this script was stopped.'
}
$taskLog=Join-Path $OutputDirectory 'result.txt'
if(!(Test-Path -LiteralPath $taskLog)) { throw 'Igor did not write a result log.' }
$taskText=Get-Content -LiteralPath $taskLog -Raw
Write-Output $taskText
if($taskText -match 'FAIL:|error:|RUNTIME ERROR|failures=[1-9]') { throw 'Check failed; inspect result.txt.' }
Write-Output ('Results: '+$OutputDirectory)

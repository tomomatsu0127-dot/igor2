param([string]$Command='Print "COMPILED v1.2.2"',[string]$Log='scratch/v122/compile.txt',[int]$Timeout=55,[string]$TestProc='xrd_workbench_v1.2.2/tests/xrd_v122_tests',[string]$Release='xrd_workbench_v1.2.2')
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force (Split-Path -Parent $Log) | Out-Null
function IgorQuote([string]$s) { return '"'+$s.Replace('\','\\').Replace('"','\"')+'"' }
$taskBase=(Get-Location).Path.Replace('\',':').Replace('C::','C:')+':'
$taskMain=$taskBase+$Release.Replace('/',':')+':xrd_main.ipf'
$taskTests=$taskBase+$TestProc.Replace('/',':')+'.ipf'
$taskLog=$taskBase+$Log.Replace('/',':')
$taskWrite='String/G root:testLog=CaptureHistory(root:testCapture,1); Variable refNum; Open refNum as '+(IgorQuote $taskLog)+'; fprintf refNum,"%s",root:testLog; Close refNum'
$taskStartup='MoveWindow/F 0,0,1920,1080; Variable/G root:XRDCLIIsolated=1; Variable/G root:testCapture=CaptureHistoryStart(); OpenProc '+(IgorQuote $taskMain)+'; OpenProc '+(IgorQuote $taskTests)+'; Execute/P/Z "COMPILEPROCEDURES "; Execute/P/Z '+(IgorQuote $Command)+'; Execute/P/Z '+(IgorQuote $taskWrite)+'; Execute/P "Quit/N"'
$taskPsi=[Diagnostics.ProcessStartInfo]::new('C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe')
$taskPsi.UseShellExecute=$false
$taskPsi.CreateNoWindow=$true
$taskPsi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$taskPsi.Arguments='/I /UNATTENDED /X "'+$taskStartup+'"'
$taskStarted=Get-Date
$taskProcess=[Diagnostics.Process]::Start($taskPsi)
if(!$taskProcess.WaitForExit($Timeout*1000)) {
  # Terminate only the /I isolated process created in this invocation.
  $taskProcess.Kill()
  throw 'Isolated v1.2.2 test timed out; user Igor was not targeted.'
}
if(!(Test-Path -LiteralPath $Log) -or (Get-Item -LiteralPath $Log).LastWriteTime -lt $taskStarted) { throw 'Igor did not write a fresh log.' }
$taskLogText=Get-Content -LiteralPath $Log -Raw
if($taskLogText -match ': error:|RUNTIME ERROR|FAIL:') { Write-Output $taskLogText; throw 'Native compile/runtime/test failure; see log.' }
Write-Output $taskLogText

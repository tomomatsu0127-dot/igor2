param([string]$Command='Print "COMPILED v1.3.0"',[string]$Log='scratch/v130/compile.txt',[string]$TestProc='', [string]$Experiment='', [int]$Timeout=55)
$ErrorActionPreference='Stop'
function IgorQuote([string]$text){return [string][char]34+$text.Replace([string][char]92,([string][char]92+[char]92)).Replace([string][char]34,([string][char]92+[char]34))+[char]34}
$taskRoot=(Get-Location).Path
$taskBase=$taskRoot.Replace([char]92,[char]58).Replace('C::','C:')+':'
$taskLogPath=[IO.Path]::GetFullPath((Join-Path $taskRoot $Log))
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskLogPath) | Out-Null
$taskLog=$taskLogPath.Replace([char]92,[char]58).Replace('C::','C:')
$taskWrite='String/G root:testLog=CaptureHistory(root:testCapture,1);Variable refNum;Open refNum as '+(IgorQuote $taskLog)+';fprintf refNum,"%s",root:testLog;Close refNum'
$taskStartup='Variable/G root:XRDCLIIsolated130=1;Variable/G root:testCapture=CaptureHistoryStart();'
if(!$Experiment){$taskStartup+='OpenProc '+(IgorQuote ($taskBase+'xrd_workbench_v1.3.0:xrd_main.ipf'))+';'}
if($TestProc){$taskStartup+='OpenProc '+(IgorQuote ([IO.Path]::GetFullPath($TestProc).Replace([char]92,[char]58).Replace('C::','C:')))+';'}
$taskStartup+='Execute/P/Z "COMPILEPROCEDURES ";Execute/P/Z '+(IgorQuote $Command)+';Execute/P/Z '+(IgorQuote $taskWrite)+';Execute/P "Quit/N"'
$taskInfo=[Diagnostics.ProcessStartInfo]::new('C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe')
$taskInfo.UseShellExecute=$false;$taskInfo.CreateNoWindow=$true;$taskInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
if($Experiment){
 $taskItx=Join-Path (Split-Path -Parent $taskLogPath) ('startup_'+[Guid]::NewGuid().ToString('N')+'.itx')
 [IO.File]::WriteAllText($taskItx,"IGOR`r`nX "+$taskStartup+"`r`n",[Text.UTF8Encoding]::new($false))
 $taskInfo.Arguments='/I /UNATTENDED "'+[IO.Path]::GetFullPath($Experiment)+'" "'+$taskItx+'"'
}else{$taskInfo.Arguments='/I /UNATTENDED /X "'+$taskStartup+'"'}
$taskStarted=Get-Date
$taskProcess=[Diagnostics.Process]::Start($taskInfo)
try{
 if(!$taskProcess.WaitForExit($Timeout*1000)){throw 'Only the created isolated Igor timed out; user Igor was not targeted.'}
 if(!(Test-Path -LiteralPath $taskLogPath) -or (Get-Item -LiteralPath $taskLogPath).LastWriteTime -lt $taskStarted){throw 'No fresh native verification log'}
 $result=Get-Content -LiteralPath $taskLogPath -Raw
 Write-Output $result
 if($result -match ': error:|RUNTIME ERROR|FAIL:'){throw 'Native compile/runtime/test failure; see log'}
}finally{if(!$taskProcess.HasExited){$taskProcess.Kill()}}

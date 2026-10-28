param([string]$Release="xrd_workbench_v1.2.2",[switch]$Control)
$ErrorActionPreference='Stop'
$taskRoot=(Get-Location).Path
$taskExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe'
$taskToken=Get-Random -Minimum 1000000 -Maximum 1900000000
$taskPrefix='compat_'+$taskToken
$taskDir=Join-Path $taskRoot ('scratch/v122/'+$taskPrefix)
New-Item -ItemType Directory -Path $taskDir | Out-Null
Copy-Item -LiteralPath 'diagnostics/compat_255610381/updated.pxp' -Destination (Join-Path $taskDir 'legacy_copy.pxp')
function IgorPath([string]$value) { return $value.Replace('\',':').Replace('C::','C:') }
function Invoke-Igor([string]$command) {
 $taskErr=0;$taskMsg='';$taskHistory='';$taskResult=''
 $script:taskApp.Execute2(0,65001,$command,[ref]$taskErr,[ref]$taskMsg,[ref]$taskHistory,[ref]$taskResult)
 Add-Content -LiteralPath (Join-Path $taskDir 'commands.txt') -Value ($command+"`n"+$taskHistory+"`nError="+$taskErr+' '+$taskMsg) -Encoding utf8
 if($taskErr -ne 0) { throw ('Igor error '+$taskErr+': '+$taskMsg+' '+$taskHistory) }
 return $taskHistory
}
function Start-Isolated {
 $script:taskVerified=$false
 $script:taskProcess=Start-Process -FilePath $taskExe -ArgumentList @('/I','/Automation','/UNATTENDED','/X',('"Variable/G root:XRDV120Isolation='+$taskToken+'"')) -WindowStyle Hidden -PassThru
 Start-Sleep -Seconds 5
 $script:taskApp=New-Object -ComObject IgorPro.Application
 $taskCheck=Invoke-Igor 'Printf "%.0f",root:XRDV120Isolation'
 if($taskCheck -notmatch ('\s'+$taskToken+'\s*$')) { throw 'Did not bind isolated Igor; no Experiment opened.' }
 $script:taskVerified=$true
}
function Stop-Isolated {
 if(!$script:taskProcess.HasExited) { $script:taskProcess.Kill() }
 $script:taskApp=$null
}
try {
 Start-Isolated
 $script:taskApp.LoadExperiment(0,2,'',(Join-Path $taskDir 'legacy_copy.pxp'))
 Invoke-Igor 'Variable/G root:compatCapture=CaptureHistoryStart()' | Out-Null
 try { $script:taskApp.CompileProcedures(1) } catch {
  try { Invoke-Igor 'Print CaptureHistory(root:compatCapture,0)' | Write-Output } catch { Write-Output $_ }
  throw
 }
 Invoke-Igor 'CtrlNamedBackground XRDAutoSave,stop' | Out-Null
 $taskHelper=IgorPath (Join-Path $taskRoot 'xrd_workbench_v1.2.1/tests/xrd_semantic120.ipf').Replace('/',':')
 Invoke-Igor ('OpenProc "'+$taskHelper+'"') | Out-Null
 try { $script:taskApp.CompileProcedures(1) } catch {
  try { Invoke-Igor 'Print CaptureHistory(root:compatCapture,0)' | Write-Output } catch { Write-Output $_ }
  throw
 }
 Invoke-Igor ('XRD120_DumpAll("'+(IgorPath (Join-Path $taskDir 'old.tsv'))+'")') | Out-Null
 Invoke-Igor 'Print FunctionInfo("XRD_Open");Print WinList("*",";","WIN:128")' | Write-Output
 Invoke-Igor 'DoWindow/K XRDWorkbench' | Out-Null
 $taskClose='CloseProc/NAME="xrd_main.ipf"/COMP=0/D=0'
 Invoke-Igor ('Execute/P/Q "'+$taskClose.Replace('"','\"')+'"') | Out-Null
 Start-Sleep -Seconds 2
 Invoke-Igor 'Print "AFTER_CLOSE_PROCEDURES",WinList("*",";","WIN:128")' | Write-Output
 $taskMain=IgorPath (Join-Path $taskRoot ($Release+'/xrd_main.ipf')).Replace('/',':')
 Invoke-Igor ('OpenProc "'+$taskMain+'"') | Out-Null
 try { $script:taskApp.CompileProcedures(1) } catch {
  try { Invoke-Igor 'Print CaptureHistory(root:compatCapture,0)' | Write-Output } catch { Write-Output $_ }
  throw
 }
 Invoke-Igor ('XRD120_DumpAll("'+(IgorPath (Join-Path $taskDir 'new_preinit.tsv'))+'")') | Out-Null
 Invoke-Igor 'XRD_Open();CtrlNamedBackground XRDAutoSave,stop' | Out-Null
 Invoke-Igor ('XRD120_DumpAll("'+(IgorPath (Join-Path $taskDir 'new_postinit.tsv'))+'")') | Out-Null
 Invoke-Igor ('SaveExperiment/C/F={1,"",0} as "'+(IgorPath (Join-Path $taskDir 'updated.pxp'))+'"') | Out-Null
 Stop-Isolated
 Start-Isolated
 $script:taskApp.LoadExperiment(0,2,'',(Join-Path $taskDir 'updated.pxp'))
 try { $script:taskApp.CompileProcedures(1) } catch {
  try { Invoke-Igor 'Print CaptureHistory(root:compatCapture,0)' | Write-Output } catch { Write-Output $_ }
  throw
 }
 Invoke-Igor 'CtrlNamedBackground XRDAutoSave,stop' | Out-Null
 Invoke-Igor ('XRD120_DumpAll("'+(IgorPath (Join-Path $taskDir 'reopened.tsv'))+'")') | Out-Null
 Stop-Isolated
 $taskPointer=if($Control){'latest_control.txt'}else{'latest_compat.txt'}; [IO.File]::WriteAllText((Join-Path $taskRoot ('scratch/v122/'+$taskPointer)),$taskDir,[Text.UTF8Encoding]::new($false))
 Write-Output $taskDir
} finally { if($script:taskApp) {Stop-Isolated} }

param([string]$TaskDir)
$ErrorActionPreference='Stop'
if($PSEdition -ne 'Desktop'){throw 'Use Windows PowerShell 5.1'}
$taskRoot=(Get-Location).Path
$taskExe='C:\Program Files\WaveMetrics\Igor Pro 9 Folder\IgorBinaries_x64\Igor64.exe'
New-Item -ItemType Directory -Path $TaskDir | Out-Null
Copy-Item -LiteralPath 'C:/Users/su200/Desktop/QS_v1.2.4.pxp' -Destination (Join-Path $TaskDir 'baseline_copy.pxp')
Copy-Item -LiteralPath 'C:/Users/su200/Desktop/QS_update_v1.2.8_20261104_170038/xrd_workbench_v1.2.8' -Destination (Join-Path $TaskDir 'old_dependencies') -Recurse
Get-FileHash -LiteralPath 'C:/Users/su200/Desktop/QS_v1.2.4.pxp',(Join-Path $TaskDir 'baseline_copy.pxp') | ConvertTo-Json | Set-Content (Join-Path $TaskDir 'original_hashes.json')
function IgorPath([string]$path){$path.Replace('\',':').Replace('C::','C:').Replace('/',':')}
function Invoke-Igor([string]$code){
 $taskErr=0;$taskMsg='';$taskHistory='';$taskResult=''
 $script:taskApp.Execute2(0,65001,$code,[ref]$taskErr,[ref]$taskMsg,[ref]$taskHistory,[ref]$taskResult)
 Add-Content -LiteralPath (Join-Path $TaskDir 'commands.txt') -Value ($code+"`n"+$taskHistory+"`nError="+$taskErr+' '+$taskMsg) -Encoding utf8
 if($taskErr){throw ('Igor error '+$taskErr+': '+$taskMsg)}
 Write-Output $taskHistory
}
function Start-Isolated {
 $taskToken=Get-Random -Minimum 1000000 -Maximum 1900000000
 $script:taskProcess=Start-Process -FilePath $taskExe -ArgumentList @('/I','/Automation','/UNATTENDED','/X',('"Variable/G root:Compat129Identity='+$taskToken+'"')) -WindowStyle Hidden -PassThru
 $script:taskApp=$null
 for($taskAttempt=0;$taskAttempt -lt 30;$taskAttempt++){
  Start-Sleep -Seconds 1
  try {$script:taskApp=[Runtime.InteropServices.Marshal]::GetActiveObject('IgorPro.Application');break} catch {if($script:taskProcess.HasExited){throw 'Isolated Igor exited during startup'}}
 }
 if(!$script:taskApp){throw 'COM startup timeout'}
 $taskIdentity=Invoke-Igor 'Printf "%.0f",root:Compat129Identity'
 if($taskIdentity -notmatch ('\s'+$taskToken+'\s*$')){throw 'Identity mismatch; no data opened'}
}
function Stop-Isolated {if($script:taskProcess -and !$script:taskProcess.HasExited){$script:taskProcess.Kill();$script:taskProcess.WaitForExit()};$script:taskApp=$null}
function Dump([string]$name){Invoke-Igor ('XRD127_DumpAll("'+(IgorPath (Join-Path $TaskDir ($name+'.tsv')))+'")') | Out-Null;Write-Output ('DUMP '+$name)}
try {
 Start-Isolated
 $script:taskApp.LoadExperiment(0,2,'',(Join-Path $TaskDir 'baseline_copy.pxp'))
 $script:taskApp.CompileProcedures(1)
 Invoke-Igor 'CtrlNamedBackground XRDAutoSave,stop' | Out-Null
 Invoke-Igor ('OpenProc "'+(IgorPath (Join-Path $taskRoot 'xrd_workbench_v1.2.9/tests/xrd_semantic127.ipf'))+'"') | Out-Null
 $script:taskApp.CompileProcedures(1)
 Dump 'baseline'
 Invoke-Igor 'KillWindow/Z XRDWorkbench;KillWindow/Z XRDProjectManager;KillWindow/Z XRDCompareSelection;KillWindow/Z XRDPlotWorkspace;KillWindow/Z XRDFigureSettings' | Out-Null
 Start-Sleep -Seconds 1
 Invoke-Igor 'Execute/P/Q "CloseProc/NAME=\"xrd_main.ipf\"/COMP=0/D=0"' | Out-Null
 Start-Sleep -Seconds 1
 Invoke-Igor ('OpenProc "'+(IgorPath (Join-Path $taskRoot 'xrd_workbench_v1.2.9/xrd_main.ipf'))+'"') | Out-Null
 $script:taskApp.CompileProcedures(1)
 Dump 'new_preinit'
 Invoke-Igor 'XRD_Init();CtrlNamedBackground XRDAutoSave,stop;XRD_PlotDefaults()' | Out-Null
 Dump 'new_postinit'
 Invoke-Igor ('SaveExperiment/C/F={1,"",0} as "'+(IgorPath (Join-Path $TaskDir 'updated129.pxp'))+'"') | Out-Null
 Stop-Isolated
 Start-Isolated
 $script:taskApp.LoadExperiment(0,2,'',(Join-Path $TaskDir 'updated129.pxp'))
 $script:taskApp.CompileProcedures(1)
 Invoke-Igor 'CtrlNamedBackground XRDAutoSave,stop' | Out-Null
 Dump 'reopened'
 Write-Output 'COMPAT129_COMPLETED'
} finally {Stop-Isolated}

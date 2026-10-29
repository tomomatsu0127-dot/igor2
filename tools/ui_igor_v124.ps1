param([string]$Release='xrd_workbench_v1.2.4',[switch]$Serve)
$ErrorActionPreference='Stop'
$taskRoot=(Get-Location).Path
$taskLog=Join-Path $taskRoot 'scratch/v124/ui_setup.txt'
$taskToken=Get-Random -Minimum 1000000 -Maximum 1900000000
$taskProcess=Start-Process -FilePath 'C:/Program Files/WaveMetrics/Igor Pro 9 Folder/IgorBinaries_x64/Igor64.exe' -ArgumentList @('/I','/Automation','/UNATTENDED','/X',('"Variable/G root:Modal124Isolation='+$taskToken+'"')) -WindowStyle Hidden -PassThru
@{pid=$taskProcess.Id;token=$taskToken;release=$Release}|ConvertTo-Json|Set-Content scratch/v124/ui_instance.json
$taskVerified=$false
function Invoke-ModalTest([string]$code) {
    $taskErr=0;$taskMsg='';$taskHist='';$taskResult=''
    $taskApp.Execute2(0,65001,$code,[ref]$taskErr,[ref]$taskMsg,[ref]$taskHist,[ref]$taskResult)
    Add-Content -LiteralPath $taskLog -Value ($code+"`n"+$taskHist+"`nError="+$taskErr+' '+$taskMsg) -Encoding utf8
    if($taskErr){throw ($taskErr.ToString()+' '+$taskMsg)}
    return $taskHist
}
try {
    Start-Sleep -Seconds 5
    $taskApp=New-Object -ComObject IgorPro.Application
    $taskIdentity=Invoke-ModalTest 'Printf "%.0f",root:Modal124Isolation'
    if($taskIdentity -notmatch ('\s'+$taskToken+'\s*$')){throw 'Dedicated instance not verified'}
    $taskVerified=$true
    $taskMain=(Join-Path $taskRoot ($Release+'/xrd_main.ipf')).Replace('\',':').Replace('C::','C:').Replace('/',':')
    Invoke-ModalTest ('OpenProc "'+$taskMain+'"')|Out-Null
    $taskApp.CompileProcedures(1)
    $taskApp.Visible=1
    Invoke-ModalTest 'XRD_Open();XRD110_Manager();XRD80_LibraryPanel();DoWindow/T kwFrame,"XRD v1.2.4 isolated dialog verification"'|Out-Null
    Write-Output ('Dedicated UI PID '+$taskProcess.Id+' token '+$taskToken)
    if($Serve) {
        $taskDeadline=(Get-Date).AddMinutes(15)
        while((Get-Date) -lt $taskDeadline -and !$taskProcess.HasExited) {
            if(Test-Path -LiteralPath 'scratch/v124/ui_pending.txt') {
                $taskCode=Get-Content -LiteralPath 'scratch/v124/ui_pending.txt' -Raw
                Remove-Item -LiteralPath 'scratch/v124/ui_pending.txt'
                if($taskCode.Trim() -eq 'STOP'){break}
                Invoke-ModalTest $taskCode | Write-Output
            }
            Start-Sleep -Milliseconds 500
        }
        if(!$taskProcess.HasExited){$taskProcess.Kill()}
    }
} catch {
    if(!$taskProcess.HasExited){$taskProcess.Kill()}
    throw
}

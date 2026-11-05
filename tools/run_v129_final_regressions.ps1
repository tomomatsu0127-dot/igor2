param([int]$StartAt=0)
$ErrorActionPreference='Stop'
$taskRepo=(Get-Location).Path.Replace('\',':').Replace('C::','C:')
foreach($folder in @('workflow','regression','detector')){New-Item -ItemType Directory -Force (Join-Path 'scratch/v129' $folder) | Out-Null}
Copy-Item -LiteralPath 'xrd_workbench_v1.2.9/tests/fixtures_v110/missing_hkl120.txt' -Destination 'scratch/v129/regression/missing_hkl120.txt' -Force
$script:taskIndex=-1
function Invoke-Regression([string]$name,[string]$proc,[string]$command){
    $script:taskIndex+=1
    if($script:taskIndex -lt $StartAt){return}
    $taskOutput=& (Join-Path (Get-Location) 'tools/run_igor_v129.ps1') -TestProc ('xrd_workbench_v1.2.9/tests/'+$proc) -Command $command -Log ('scratch/v129/'+$name+'.txt')
    $taskText=$taskOutput -join "`n"
    Write-Output ($name+': PASS assertions='+([regex]::Matches($taskText,'PASS:').Count))
}
Invoke-Regression 'performance_regression' 'xrd_v128_tests' ('XRD_RunV128Tests("'+$taskRepo+':xrd_workbench_v1.2.9:tests:fixtures_v110:")')
Invoke-Regression 'workflow' 'xrd_v127_tests' ('XRD_RunV127Tests("'+$taskRepo+':xrd_workbench_v1.2.9:tests:fixtures_v110:","'+$taskRepo+':scratch:v129:workflow:")')
Invoke-Regression 'selection_manager' 'xrd_v125_tests' 'XRD_RunV125Tests()'
Invoke-Regression 'comparison' 'xrd_v126_tests' ('XRD_RunV126Tests("'+$taskRepo+':xrd_workbench_v1.2.9:tests:fixtures_v110:")')
Invoke-Regression 'regression' 'xrd_v120_tests' ('XRD_RunV120Tests("'+$taskRepo+':xrd_workbench_v1.2.9:tests:fixtures_v110:","'+$taskRepo+':scratch:v129:regression:")')
Invoke-Regression 'detector' 'xrd_v127_tests' ('XRD_RunV70Detector("'+$taskRepo+':xrd_workbench_v1.2.9:tests:fixtures_v060:","'+$taskRepo+':scratch:v129:detector:")')

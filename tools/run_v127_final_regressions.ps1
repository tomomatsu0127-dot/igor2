$ErrorActionPreference='Stop'
$taskRepo=(Get-Location).Path.Replace('\',':').Replace('C::','C:')
function Invoke-Regression([string]$proc,[string]$command,[string]$log){
    & (Join-Path (Get-Location) 'tools/run_igor_v127.ps1') -TestProc $proc -Command $command -Log $log
}
Invoke-Regression 'xrd_workbench_v1.2.7/tests/xrd_v125_tests' 'XRD_RunV125Tests()' 'scratch/v127/selection_manager_final.txt'
Invoke-Regression 'xrd_workbench_v1.2.7/tests/xrd_v126_tests' ('XRD_RunV126Tests("'+$taskRepo+':xrd_workbench_v1.2.7:tests:fixtures_v110:")') 'scratch/v127/comparison_final.txt'
Invoke-Regression 'xrd_workbench_v1.2.7/tests/xrd_v120_tests' ('XRD_RunV120Tests("'+$taskRepo+':xrd_workbench_v1.2.7:tests:fixtures_v110:","'+$taskRepo+':scratch:v127:regression:")') 'scratch/v127/regression_final.txt'
Invoke-Regression 'xrd_workbench_v1.2.7/tests/xrd_v127_tests' ('XRD_RunV70Detector("'+$taskRepo+':xrd_workbench_v1.2.7:tests:fixtures_v060:","'+$taskRepo+':scratch:v127:detector:")') 'scratch/v127/detector_final2.txt'

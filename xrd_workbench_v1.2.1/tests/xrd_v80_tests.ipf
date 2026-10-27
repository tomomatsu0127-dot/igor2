#pragma rtGlobals=3
// v0.8.0 integration entry points. Run in disposable /I Experiments only.
#include ":xrd_tests"
#include ":xrd_v80_core_tests"
#include ":xrd_v80_library_tests"
#include ":xrd_v80_plot_tests"
#include ":xrd_v80_integration_tests"
#include ":xrd_v80_profile_regression"

Function XRD_RunV80LibrarySuite(fixtures)
    String fixtures
    Variable/G root:XRDTestFailures=0
    NVAR failures=root:XRDTestFailures
    XRD_RunV80LibraryTests(fixtures)
    Print "v080 library failures="+num2istr(failures)
    return failures
End


"""Build the installable single Igor Procedure from the development modules."""
from pathlib import Path

package = Path(__file__).resolve().parents[1]
main = (package / "src/MH_VSM_Analyzer.ipf").read_text(encoding="utf-8")
main = main.replace('#include ":mh_figure"\n', "").replace('#include ":mh_axis"\n', "")
figure = (package / "src/mh_figure.ipf").read_text(encoding="utf-8")
figure = figure.replace("#pragma rtGlobals=3\n", "", 1)
figure = figure.replace("#pragma version=2.12\n", "", 1)
figure += "\n" + (package / "src/mh_axis.ipf").read_text(encoding="utf-8").replace("#pragma rtGlobals=3\n", "", 1)
out = package / "MH_VSM_Analyzer_v2_1_2.ipf"
out.write_text(
    main + "\n// ---- Figure layout module, bundled for single-file installation ----\n" + figure,
    encoding="utf-8",
)
print(out.name)

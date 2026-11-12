"""Build the Windows Igor migration ZIP from this Git checkout."""
from argparse import ArgumentParser
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path, help="Path to the new ZIP")
    args = parser.parse_args()

    source = Path(__file__).resolve().parent
    runtime = source.parents[1] / "xrd_workbench_v1.4.4"
    migration = source.parent / "legacy_xrd_migration_v0.1.0" / "xrd_legacy_migration.ipf"
    if not (runtime / "xrd_main.ipf").is_file():
        parser.error("Build this ZIP from the complete Igor2 repository checkout.")

    with ZipFile(args.destination, "x", compression=ZIP_DEFLATED) as archive:
        archive.write(source / "start_xrd_migration.ipf", "start_xrd_migration.ipf")
        archive.write(source / "README_ja.md", "README_ja.md")
        archive.write(
            migration,
            "support/xrd_legacy_migration.ipf",
        )
        for procedure in sorted(runtime.glob("*.ipf")):
            archive.write(procedure, "runtime/" + procedure.name)


if __name__ == "__main__":
    main()

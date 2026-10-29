import sys

if __name__ == '__main__':
    if '--self-check' in sys.argv:
        from studio.verification import run_check
        run_check(sys.argv[sys.argv.index('--self-check')+1])
    else:
        from studio.qt_app import main
        sys.exit(main())

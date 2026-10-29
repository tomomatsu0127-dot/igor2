import sys

if __name__ == '__main__':
    try:
        if '--self-check' in sys.argv:
            from studio.verification import run_check
            run_check(sys.argv[sys.argv.index('--self-check')+1])
        else:
            from studio.qt_app import main
            sys.exit(main())
    except Exception as error:
        if '--self-check' in sys.argv:
            import json,traceback
            from pathlib import Path
            Path(sys.argv[sys.argv.index('--self-check')+1]).write_text(json.dumps({
                'status':'FAIL','error':str(error),'traceback':traceback.format_exc()},ensure_ascii=False,indent=2),encoding='utf-8')
            sys.exit(1)
        raise

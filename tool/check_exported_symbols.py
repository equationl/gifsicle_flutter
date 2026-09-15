from pathlib import Path
import subprocess,sys,re
root=Path(__file__).resolve().parents[1]
allowed=set(re.findall(r'\b(gs_\w+)\s*\(', (root/'src/bridge/gifsicle_bridge.h').read_text()))
if sys.platform=='win32':
 text=subprocess.check_output(['dumpbin','/exports',str(root/'build/native/gifsicle_flutter.dll')],text=True)
 symbols={line.split()[-1] for line in text.splitlines() if re.match(r'\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+',line)}
else:
 path=root/'build/native'/('libgifsicle_flutter.dylib' if sys.platform=='darwin' else 'libgifsicle_flutter.so')
 args=['nm','-gU',str(path)] if sys.platform=='darwin' else ['nm','-D','--defined-only',str(path)]
 text=subprocess.check_output(args,text=True)
 symbols={line.split()[-1].removeprefix('_') if sys.platform=='darwin' else line.split()[-1] for line in text.splitlines() if len(line.split())>=3}
assert symbols==allowed, {'unexpected':list(symbols-allowed),'missing':list(allowed-symbols)}
print(f'{len(symbols)} public ABI exports verified')

if sys.platform!='win32':
 imports=subprocess.check_output(['nm','-u',str(path)],text=True)
 forbidden={'exit','_exit','abort','__assert_rtn','__assert_fail','popen','system','chdir','dup2','freopen','__stderrp','__stdoutp','__stdinp'}
 names={line.split()[-1].removeprefix('_') if sys.platform=='darwin' else line.split()[-1].split('@')[0] for line in imports.splitlines() if line.split()}
 assert not names&forbidden, sorted(names&forbidden)
 print('No process exit/assertion/stdio redirection or external command imports')

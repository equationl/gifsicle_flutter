"""Compare every pinned parser-table entry against the unmodified 1.96 CLI.
The reference executable is a development/test input, never a runtime dependency.
"""
import ctypes as c,json,subprocess,tempfile,sys,platform,base64
from pathlib import Path
root=Path(__file__).resolve().parents[1]
libpath=root/'build/native'/('gifsicle_flutter.dll' if sys.platform=='win32' else 'libgifsicle_flutter.dylib' if sys.platform=='darwin' else 'libgifsicle_flutter.so')
lib=c.CDLL(str(libpath))
class R(c.Structure):_fields_=[('status',c.c_int),('code',c.c_int),('out',c.c_void_p),('length',c.c_size_t),('err',c.c_void_p),('errlen',c.c_size_t)]
lib.gs_execute_isolated.restype=c.POINTER(R);lib.gs_execute_isolated.argtypes=[c.c_int,c.POINTER(c.c_char_p),c.c_void_p,c.c_size_t,c.c_char_p];lib.gs_execution_result_free.argtypes=[c.POINTER(R)]
ref=Path(sys.argv[1]).resolve();manifest=json.loads((root/'tool/cli/gifsicle_1_96_options.json').read_text())
values={'COLOR_TYPE':'#000000','TWO_COLORS_TYPE':'#000000','RECTANGLE_TYPE':'0,0+1x1','Clp_ValInt':'2','COLORMAP_ALG_TYPE':'diversity','DISPOSAL_TYPE':'background','DIMENSIONS_TYPE':'2x2','LOOP_TYPE':'0','OPTIMIZE_TYPE':'3','POSITION_TYPE':'0,0','FRAME_SPEC_TYPE':'#0','Clp_ValUnsigned':'2','RESIZE_METHOD_TYPE':'point','SCALE_FACTOR_TYPE':'2','Clp_ValString':'hello','Clp_ValStringNotOption':'out.gif'}
special={'--gamma':'srgb','--dither':'floyd-steinberg','--use-colormap':'web','--use-exact-colormap':'web','--resize-geometry':'2x2','--threads':'1','--extension':'255','--app-extension':'APPTEST0001','--output':'out.gif'}
results=[]
for entry in manifest['options']:
 name=entry['name'];value=special.get(name,values.get(entry['valueType']));args=([name+'='+value] if entry['optionalValue'] and value else [name] + ([value] if entry['valueType']!='0' else []))
 if name in ['--change-color']:args+=['#ffffff']
 if name in ['--extension','--app-extension']:args+=['data']
 args+=['input.gif']
 with tempfile.TemporaryDirectory(prefix='gs-cli-') as folder:
  work=Path(folder);(work/'input.gif').write_bytes((root/'test/fixtures/animated.gif').read_bytes())
  before={p.name:p.read_bytes() for p in work.iterdir()}
  if name=='--transform-colormap':expected=None
  else:expected=subprocess.run([str(ref),*args],cwd=work,capture_output=True,timeout=30)
  expectedfiles={p.name:p.read_bytes() for p in work.iterdir()}
  for p in work.iterdir():p.unlink()
  for k,v in before.items():(work/k).write_bytes(v)
  encoded=[s.encode() for s in args]
  result=lib.gs_execute_isolated(len(args),(c.c_char_p*len(args))(*encoded),None,0,str(work).encode())
  assert result
  r=result.contents;out=c.string_at(r.out,r.length) if r.out else b'';err=c.string_at(r.err,r.errlen) if r.err else b''
  actualfiles={p.name:p.read_bytes() for p in work.iterdir()}
  if expected is None:passed=r.status==10;comparison='explicit unsupported'
  else:
   passed=r.status==0 and r.code==expected.returncode and out==expected.stdout and actualfiles==expectedfiles
   comparison='exit code, stdout bytes, generated files'
   # Program-name decoration can differ; stderr is retained for review.
  results.append({'name':name,'arguments':args,'passed':passed,'bridgeStatus':r.status,'exitCode':r.code,'comparison':comparison,'stderr':err.decode(errors='replace'),'referenceStderr':expected.stderr.decode(errors='replace') if expected else None,'expectedStdout':base64.b64encode(expected.stdout).decode() if expected else '', 'expectedFiles':{k:base64.b64encode(v).decode() for k,v in expectedfiles.items()} if expected else {}})
  lib.gs_execution_result_free(result)
report={'platform':sys.platform,'architecture':platform.machine(),'version':'1.96','results':results,'passed':sum(r['passed'] for r in results),'total':len(results)}
(root/'tool/reports/cli_conformance.json').write_text(json.dumps(report,indent=2)+'\n')
(root/'example/integration_test/cli_cases.dart').write_text('// Generated from the pinned reference CLI by tool/cli_conformance.py.\nconst cliCasesJson = r'+chr(39)*3+'\n'+json.dumps(results)+'\n'+chr(39)*3+';\n')
print(f"{report['passed']}/{report['total']} parser cases passed")
for r in results:
 if not r['passed']:print(r['name'],r['bridgeStatus'],r['stderr'][:200])
raise SystemExit(0 if all(r['passed'] for r in results) else 1)

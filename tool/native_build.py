"""Host native build, sanitizer, fuzz and architecture compilation entry point."""
from pathlib import Path
import subprocess,sys,os
root=Path(__file__).resolve().parents[1]
names='clp fmalloc giffunc gifread gifunopt gifwrite kcolor merge optimize quantize support xform gifsicle'.split()
sources=[str(root/'src/bridge'/f'gifsicle_{n}.c') for n in ['bridge','context','files','io']]+[str(root/'src/third_party/gifsicle/src'/f'{n}.c') for n in names]
includes=[str(root/p) for p in ['src/bridge','src/third_party/gifsicle/include','src/third_party/gifsicle/src']]
if __name__=='__main__':
 mode=sys.argv[1] if len(sys.argv)>1 else 'test';out=root/'build/native';out.mkdir(parents=True,exist_ok=True)
 if os.name=='nt':
  target=out/('gifsicle_flutter.dll' if mode=='library' else 'bridge_test.exe')
  command=['cl','/nologo','/std:c11','/utf-8','/MD','/O2','/DHAVE_CONFIG_H=1','/D_CRT_SECURE_NO_WARNINGS=1',*['/I'+p for p in includes],*sources]
  if mode=='library':command+=['/LD','/Fe:'+str(target)]
  else:command+=[str(root/'native_test/bridge_test.c'),'/Fe:'+str(target)]
 else:
  target=out/('libgifsicle_flutter.dylib' if sys.platform=='darwin' else 'libgifsicle_flutter.so') if mode=='library' else out/mode
  command=[os.environ.get('CC','clang'),'-std=c11','-DHAVE_CONFIG_H=1','-g','-fvisibility=hidden',*['-I'+p for p in includes],*sources]
  if mode=='library':command+=['-shared','-O3']
  elif mode in ['fuzz','fuzz-arguments']:command+=['-fsanitize=fuzzer,address,undefined',str(root/('native_test/fuzz_gif_input.c' if mode=='fuzz' else 'native_test/fuzz_arguments.c'))]
  else:command+=['-DGS_TESTING=1','-fsanitize=address,undefined','-fno-omit-frame-pointer',str(root/'native_test/bridge_test.c')]
  if sys.platform=='darwin':command+=['-isysroot',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip()]
  command+=['-o',str(target),'-lm','-lpthread']
 subprocess.run(command,cwd=out,check=True)
 if mode=='test':subprocess.run([str(target)],check=True)
 print(target)

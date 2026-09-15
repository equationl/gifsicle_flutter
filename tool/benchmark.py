"""Native/CLI timing and decoded pixel regression checks (test-only Pillow)."""
from pathlib import Path
from PIL import Image,ImageSequence
import io,ctypes as c,subprocess,time,json,sys,statistics,os
root=Path(__file__).resolve().parents[1]
class R(c.Structure):_fields_=[('status',c.c_int),('code',c.c_int),('out',c.c_void_p),('length',c.c_size_t),('err',c.c_void_p),('errlen',c.c_size_t)]
lib=c.CDLL(str(root/'build/native/libgifsicle_flutter.dylib'));lib.gs_execute.restype=c.POINTER(R);lib.gs_execute.argtypes=[c.c_int,c.POINTER(c.c_char_p),c.c_void_p,c.c_size_t,c.c_char_p];lib.gs_execution_result_free.argtypes=[c.POINTER(R)]
def call(data,lossy=False):
 args=[b'-O3']+([b'--lossy=20'] if lossy else [])+[b'-'];r=lib.gs_execute(len(args),(c.c_char_p*len(args))(*args),data,len(data),None)
 assert r and not r.contents.status and not r.contents.code
 out=c.string_at(r.contents.out,r.contents.length);lib.gs_execution_result_free(r);return out
def rgba(f):
 b=bytearray(f.convert('RGBA').tobytes())
 for i in range(0,len(b),4):
  if b[i+3]==0:b[i:i+3]=b'\0\0\0'
 return bytes(b)
def decode(data):
 im=Image.open(io.BytesIO(data));return im.size,im.info.get('loop'),[(rgba(f),f.info.get('duration',0)) for f in ImageSequence.Iterator(im)]
report=[]
for name in ['small-static','small-animation','large-canvas','many-frames','many-colors','transparent','disposal-previous']:
 data=(root/'test/fixtures'/f'{name}.gif').read_bytes();timings=[]
 for i in range(5):
  start=time.perf_counter();out=call(data);timings.append((time.perf_counter()-start)*1000)
 refstart=time.perf_counter();ref=subprocess.run([sys.argv[1],'-O3','-'],input=data,capture_output=True,check=True).stdout;reftime=(time.perf_counter()-refstart)*1000
 assert out==ref,name+' CLI byte mismatch'
 assert decode(data)==decode(out),name+' decoded semantic mismatch'
 lossy=call(data,True);a,b=decode(data),decode(lossy)
 assert a[:2]==b[:2] and len(a[2])==len(b[2])
 err=0;pixels=0
 for (ap,at),(bp,bt) in zip(a[2],b[2]):
  assert at==bt
  err+=sum(abs(x-y) for x,y in zip(ap,bp));pixels+=len(ap)
 mae=err/max(1,pixels);assert mae<12,name+' lossy difference'
 report.append({'fixture':name,'inputBytes':len(data),'outputBytes':len(out),'medianNativeMs':statistics.median(timings),'referenceProcessWallMs':reftime,'lossyMeanAbsoluteChannelError':mae,'decodedPixelsAndTimingEqual':True})
def rss():return int(subprocess.check_output(['ps','-o','rss=','-p',str(os.getpid())],text=True).strip())
data=(root/'test/fixtures/small-animation.gif').read_bytes();before=rss();samples=[]
for i in range(100):
 call(data)
 if i in [0,24,49,74,99]:samples.append({'iteration':i+1,'rssKiB':rss()})
result={'platform':sys.platform,'samples':report,'rssBeforeKiB':before,'repeated100':samples,'notes':'CLI wall time includes process startup. Native timing excludes Dart/FFI transfer. RSS is an observational baseline, not proof of absence of leaks.'}
(root/'tool/reports/benchmark.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

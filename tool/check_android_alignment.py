"""Validate every native library's ELF LOAD and APK data alignment, without SDK tools."""
from pathlib import Path
import struct,sys,zipfile,json
apk=Path(sys.argv[1]);raw=apk.read_bytes();report=[]
with zipfile.ZipFile(apk) as z:
 for info in z.infolist():
  if not info.filename.endswith('.so'):continue
  data=z.read(info)
  assert data[:4]==b'\x7fELF',info.filename
  endian='<' if data[5]==1 else '>'
  if data[4]==2:
   phoff=struct.unpack_from(endian+'Q',data,32)[0];entsize,count=struct.unpack_from(endian+'HH',data,54);fmt=endian+'IIQQQQQQ'
  else:
   phoff=struct.unpack_from(endian+'I',data,28)[0];entsize,count=struct.unpack_from(endian+'HH',data,42);fmt=endian+'IIIIIIII'
  aligns=[]
  for i in range(count):
   h=struct.unpack_from(fmt,data,phoff+i*entsize)
   if h[0]==1:aligns.append(h[-1])
  assert aligns and min(aligns)>=16384,(info.filename,aligns)
  name,extra=struct.unpack_from('<HH',raw,info.header_offset+26);offset=info.header_offset+30+name+extra
  assert info.compress_type==zipfile.ZIP_STORED,(info.filename,'compressed native library')
  assert offset%16384==0,(info.filename,offset)
  report.append({'file':info.filename,'loadAlignments':aligns,'zipOffset':offset})
assert report,'No libraries found'
out=Path('tool/reports/android_alignment.json');out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n');print(f'{len(report)} native libraries passed ELF and APK 16 KB alignment')

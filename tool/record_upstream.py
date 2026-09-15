"""Maintainer tool: record a reviewed local source change as a reproducible patch."""
from pathlib import Path
import hashlib,json,tarfile,tempfile,difflib
root=Path(__file__).resolve().parents[1];vendor=root/'src/third_party/gifsicle';archive=root/'tool/upstream/gifsicle-1.96.tar.gz'
expected='fd23d279681a6dfe3c15264e33f344045b3ba473da4d19f49e67a50994b077fb'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==expected
with tempfile.TemporaryDirectory() as tmp:
 with tarfile.open(archive) as t:t.extractall(tmp,filter='data')
 original=Path(tmp)/'gifsicle-1.96';diff=[]
 for f in sorted(vendor.rglob('*')):
  if not f.is_file() or f.name=='UPSTREAM_VERSION':continue
  relative=f.relative_to(vendor).as_posix();old=original/relative
  if old.exists() and old.read_bytes()!=f.read_bytes():diff.extend(difflib.unified_diff(old.read_text().splitlines(True),f.read_text().splitlines(True),fromfile='a/'+relative,tofile='b/'+relative))
patch=root/'tool/patches/0001-embedded-core.patch';patch.write_text(''.join(diff))
metadata={'version':'1.96','tarballUrl':'https://www.lcdf.org/gifsicle/gifsicle-1.96.tar.gz','tarballSha256':expected,'gitCommit':'a08e0f6686d467bb8b9e4715b1f1835f12984fb0','gitTag':'v1.96','patchSha256':hashlib.sha256(patch.read_bytes()).hexdigest(),'files':{f.relative_to(vendor).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(vendor.rglob('*')) if f.is_file() and f.name!='UPSTREAM_VERSION'}}
(vendor/'UPSTREAM_VERSION').write_text(json.dumps(metadata,indent=2)+'\n')

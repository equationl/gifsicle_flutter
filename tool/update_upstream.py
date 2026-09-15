"""Restore vendored 1.96 from the fixed archive and apply the reviewed patch.
Deliberately refuses version changes: a new version requires a new reviewed spec.
"""
from pathlib import Path
import hashlib,json,tarfile,subprocess,tempfile,shutil
root=Path(__file__).resolve().parents[1]
meta=json.loads((root/'src/third_party/gifsicle/UPSTREAM_VERSION').read_text())
archive=root/'tool/upstream/gifsicle-1.96.tar.gz'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==meta['tarballSha256']
with tempfile.TemporaryDirectory(prefix='gifsicle-upstream-') as tmp:
 with tarfile.open(archive) as t:t.extractall(tmp,filter='data')
 original=Path(tmp)/'gifsicle-1.96'
 subprocess.run(['patch','-p1','-i',str(root/'tool/patches/0001-embedded-core.patch')],cwd=original,check=True)
 for directory in ['src','include']:shutil.copytree(original/directory,root/'src/third_party/gifsicle'/directory,dirs_exist_ok=True)
 for name in ['COPYING','gifsicle.1','NEWS.md']:shutil.copy2(original/name,root/'src/third_party/gifsicle'/name)
subprocess.run(['python3',str(root/'tool/verify_upstream.py')],check=True)

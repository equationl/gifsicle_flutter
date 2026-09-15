"""Offline integrity checks for the upstream archive, patch, and vendored files."""
from pathlib import Path
import hashlib,json,tarfile,tempfile,subprocess
root=Path(__file__).resolve().parents[1]
meta=json.loads((root/'src/third_party/gifsicle/UPSTREAM_VERSION').read_text())
archive=root/'tool/upstream/gifsicle-1.96.tar.gz'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==meta['tarballSha256'],'Upstream archive changed'
patch=root/'tool/patches/0001-embedded-core.patch'
assert hashlib.sha256(patch.read_bytes()).hexdigest()==meta['patchSha256'],'Reviewed patch changed'
for path,sha in meta['files'].items():assert hashlib.sha256((root/'src/third_party/gifsicle'/path).read_bytes()).hexdigest()==sha,path
# The archive and patch can be reproduced on hosts that supply the standard patch tool.
print(f"Gifsicle {meta['version']}: archive, patch and {len(meta['files'])} vendored files verified")

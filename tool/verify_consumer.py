"""Create a fresh app with only the package dependency; copy no platform config."""
from pathlib import Path
import tempfile,subprocess,sys,os
root=Path(__file__).resolve().parents[1]
flutter='flutter.bat' if os.name=='nt' else 'flutter'
platform='macos' if sys.platform=='darwin' else 'windows' if os.name=='nt' else 'android'
with tempfile.TemporaryDirectory(prefix='gifsicle-consumer-') as temp:
 app=Path(temp)/'consumer'
 subprocess.run([flutter,'create','--platforms='+platform,str(app)],check=True)
 pub=app/'pubspec.yaml';s=pub.read_text().replace('dependencies:\n','dependencies:\n  gifsicle_flutter:\n    path: '+root.as_posix()+'\n',1);pub.write_text(s)
 (app/'lib/main.dart').write_text("import 'package:flutter/material.dart';\nimport 'package:gifsicle_flutter/gifsicle_flutter.dart';\nvoid main() async { WidgetsFlutterBinding.ensureInitialized();final r=await Gifsicle.executeArguments(['--version']);runApp(MaterialApp(home:Text('Gifsicle ${r.exitCode}')));}\n")
 command=[flutter,'build','apk' if platform=='android' else platform,'--release']
 if platform=='android':command+=['--target-platform','android-arm64,android-x64']
 subprocess.run(command,cwd=app,check=True)
 print('Blank consumer build passed; only pubspec dependency and Dart entrypoint changed.')

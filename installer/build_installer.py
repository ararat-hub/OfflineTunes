"""Build the per-user Windows installer using a portable NSIS compiler."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--makensis', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--vc-runtime', required=True, type=Path,
                    help='Visual Studio VC/Redist/MSVC/<version>/x64/Microsoft.VC*.CRT directory')
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
version_match = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$',
                          (project / 'pubspec.yaml').read_text(encoding='utf-8'),
                          re.MULTILINE)
if not version_match:
    parser.error('Expected a numeric version and build number in pubspec.yaml')
version, build_number = version_match.groups()
build = project / 'build/windows/x64/runner/Release'
assert (build / 'oTune.exe').is_file(), 'Build the Windows release first.'
runtime = sorted(args.vc_runtime.glob('*.dll'))
required = {'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'}
if not required.issubset(file.name.lower() for file in runtime):
    parser.error('--vc-runtime must point to the x64 Visual C++ redistributable CRT directory')
for file in runtime:
    shutil.copy2(file, build / file.name)
excluded = {'.pdb', '.ilk', '.lib', '.exp'}
excluded_names = {'native_assets.json', 'offlinetunes.exe'}
files = sorted(p for p in build.rglob('*')
               if p.is_file() and p.suffix.lower() not in excluded
               and p.name.lower() not in excluded_names)
lines = []
for file in files:
    relative = str(file.relative_to(build)).replace('/', '\\')
    lines.append(f'Delete "$INSTDIR\\{relative}"')
all_directories = set()
for file in files:
    directory = file.parent
    while directory != build:
        all_directories.add(directory)
        directory = directory.parent
directories = sorted(all_directories, key=lambda p: (-len(p.parts), p))
for directory in directories:
    if directory != build:
        relative = str(directory.relative_to(build)).replace('/', '\\')
        lines.append(f'RMDir "$INSTDIR\\{relative}"')
(project / 'installer/files_uninstall.nsh').write_text('\n'.join(lines) + '\n', encoding='utf-8-sig')
args.output.mkdir(parents=True, exist_ok=True)
subprocess.run([str(args.makensis.resolve()), '/V2', f'/DBUILD_DIR={build}',
                f'/DAPP_VERSION={version}', f'/DFILE_VERSION={version}.{build_number}',
                f'/DOUTPUT_DIR={args.output.resolve()}', str(project / 'installer/windows.nsi')], check=True)
print(args.output.resolve() / f'oTune-Setup-{version}.exe')

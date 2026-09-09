#!/usr/bin/env python3
"""Run Godot UI regression checks in a disposable project and user profile."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--all', action='store_true', help='Also audit editor warnings, every scene, and environment checks.')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='outpost-ui-checks-') as directory:
        base = Path(directory)
        project = base / 'project'
        project.mkdir()
        userdata = base / 'userdata'
        userdata.mkdir()
        for name in ['scripts', 'scenes', 'tests', 'assets', 'tools']:
            if (source / name).exists():
                shutil.copytree(source / name, project / name, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        for name in ['default_bus_layout.tres', 'icon.svg']:
            shutil.copy2(source / name, project / name)
        profile = base.name
        config = (source / 'project.godot').read_text().replace(
            'config/name="Outpost"',
            f'config/name="Outpost UI Checks"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{profile}"')
        (project / 'project.godot').write_text(config)
        if sys.platform == 'darwin':
            user_parent = Path.home() / 'Library/Application Support'
        elif os.name == 'nt':
            user_parent = Path(os.environ['APPDATA'])
        else:
            user_parent = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
        user_parent.mkdir(parents=True, exist_ok=True)
        profile_link = user_parent / profile
        profile_link.symlink_to(userdata, target_is_directory=True)
        try:
            failed = False
            commands = [
                ('clean import', ['--import']),
                ('editor load', ['--editor', '--quit']),
                ('UI regressions', ['--verbose', '-s', 'res://tests/ui_regression.gd']),
                ('fresh-process persistence', ['-s', 'res://tests/ui_regression.gd', '--', '--binding-reload']),
            ]
            if args.all:
                commands += [
                    ('scene smoke checks', ['-s', 'res://tests/scene_smoke.gd']),
                    ('UI artwork', ['-s', 'res://tools/art/verify_ui.gd']),
                    ('terrain', ['-s', 'res://tools/art/verify_terrain.gd']),
                    ('playground', ['-s', 'res://tools/art/verify_meadow_playground.gd']),
                    ('harvesting', ['-s', 'res://tools/art/verify_meadow_harvest.gd']),
                    ('asset inspector', ['res://scenes/environment/meadow_art_lab.tscn', '--', '--meadow-lab-test']),
                    ('meadow preview', ['res://scenes/environment/meadow_preview.tscn', '--', '--meadow-test']),
                    ('meadow showcase', ['res://scenes/environment/meadow_showcase.tscn', '--', '--showcase-test']),
                ]
            for index, (label, extra) in enumerate(commands):
                result = subprocess.run(
                    [args.godot, '--headless', '--path', str(project), '--log-file', str(base / f'{index}.log'), *extra],
                    capture_output=True, text=True, timeout=60)
                output = result.stdout + result.stderr
                print(f'{label}:', flush=True)
                important = [line for line in output.splitlines() if any(tag in line for tag in ['REGRESSION:', 'SCENE CHECK:', 'FAIL:', 'PASS:'])]
                for line in important:
                    print(line, flush=True)
                if result.returncode or 'ERROR:' in output or 'WARNING:' in output or 'SCRIPT ERROR' in output:
                    print(output, flush=True)
                    failed = True
                    if label in ['clean import', 'editor load']:
                        return 1
                    continue
                print('PASS', flush=True)
            if args.all:
                from check_editor_warnings import audit
                if audit(project, args.godot):
                    failed = True
            return int(failed)
        finally:
            profile_link.unlink()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

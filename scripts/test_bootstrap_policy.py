"""Compile and execute the actual portable production policy, without an iOS SDK."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "tests/PXBootstrapPolicyTests.c"
with tempfile.TemporaryDirectory(prefix="px-bootstrap-") as directory:
    executable = Path(directory) / ("policy.exe" if os.name == "nt" else "policy")
    compiler = shutil.which("clang") or shutil.which("cc") or shutil.which("gcc")
    if compiler:
        subprocess.run([compiler, "-std=c11", "-Wall", "-Wextra", "-Werror",
                        "-I", str(ROOT / "common"), str(source), "-o", str(executable)], check=True)
        subprocess.run([str(executable)], check=True)
    elif os.name == "nt":
        roots = [Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")),
                 Path(os.environ.get("ProgramFiles", "C:/Program Files"))]
        setups = sorted({p for root in roots for p in
                         root.glob("Microsoft Visual Studio/*/*/VC/Auxiliary/Build/vcvars64.bat")})
        if not setups:
            raise SystemExit("A C compiler is required for bootstrap policy tests")
        # A batch file preserves Windows quotes without list2cmdline adding
        # backslashes to the nested command passed to cmd /c.
        command = (f'call "{setups[-1]}" >nul\nif errorlevel 1 exit /b 1\ncl /nologo /std:c11 /W4 /WX '
                   f'/I"{ROOT / "common"}" "{source}" /Fe:"{executable}" '
                   f'/Fo:"{Path(directory) / "policy.obj"}"\nif errorlevel 1 exit /b 1\n"{executable}"\n')
        batch = Path(directory) / "run.cmd"
        batch.write_text("@echo off\n" + command, encoding="utf-8")
        subprocess.run(["cmd.exe", "/d", "/c", str(batch)], cwd=ROOT, check=True)
    else:
        raise SystemExit("A C compiler is required for bootstrap policy tests")

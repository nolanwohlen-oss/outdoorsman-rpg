from pathlib import Path
root = Path(__file__).resolve().parents[1]
path = root / 'tests/run.gd'
text = path.read_text()
old = '\tcheck(overload.rig_fishing().ok and overload.cancel_fishing().ok, "A causal fight loss remains recoverable through a new rig.")'
new = '\tcheck(not overload.rig_fishing().ok, "An overload line break requires explicit tackle recovery before a new rig.")'
if text.count(old) != 1:
    raise SystemExit(f'expected one Phase 2M overload assertion, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
(root / 'tools/fix_phase2o_regression.py').unlink()
workflow = root / '.github/workflows/phase2o_fix.yml'
if workflow.exists():
    workflow.unlink()

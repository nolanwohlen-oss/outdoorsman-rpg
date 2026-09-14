from pathlib import Path

root = Path(__file__).resolve().parents[1]

p = root / "simulation/inventory.gd"
text = p.read_text()
old = '\tvar service := {\n'
new = '\tvar service: Array = {\n'
if old not in text:
    raise SystemExit('inventory typing anchor missing')
p.write_text(text.replace(old, new, 1))

p = root / "simulation/kernel.gd"
text = p.read_text()
old = '\tvar terminal_break := result.status == "continue" and int(candidate.world.fishing.line_tension) >= terminal_limit\n'
new = '\tvar terminal_break: bool = result.status == "continue" and int(candidate.world.fishing.line_tension) >= terminal_limit\n'
if old not in text:
    raise SystemExit('kernel typing anchor missing')
p.write_text(text.replace(old, new, 1))

print('Phase 2P strict typing fixed.')

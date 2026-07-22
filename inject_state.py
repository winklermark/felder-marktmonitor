#!/usr/bin/env python3
"""Spielt marktmonitor-state.json in marktmonitor.html ein (zwischen /*STATE_START*/ und /*STATE_END*/).
Aufruf: python inject_state.py [repo-dir]"""
import json, re, sys, os

d = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
state_path, html_path = os.path.join(d, "marktmonitor-state.json"), os.path.join(d, "marktmonitor.html")

with open(state_path, encoding="utf-8") as f:
    state = json.load(f)  # validiert nebenbei das JSON
for key in ("meta", "config", "wettbewerber", "ereignisse", "rohstoffe", "quellen", "changelog"):
    if key not in state:
        sys.exit(f"FEHLER: Pflichtschluessel '{key}' fehlt im State")

blob = json.dumps(state, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
with open(html_path, encoding="utf-8") as f:
    html = f.read()
new, n = re.subn(r"/\*STATE_START\*/.*?/\*STATE_END\*/", lambda m: f"/*STATE_START*/{blob}/*STATE_END*/", html, flags=re.S)
if n != 1:
    sys.exit(f"FEHLER: STATE-Marker {n}x gefunden (erwartet 1)")
with open(html_path, "w", encoding="utf-8") as f:
    f.write(new)
print(f"State eingespielt: {len(blob)} Zeichen, {len(state['wettbewerber'])} Wettbewerber, {len(state['ereignisse'])} Ereignisse")

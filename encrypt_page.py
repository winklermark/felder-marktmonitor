#!/usr/bin/env python3
"""Verschlüsselt eine HTML-Datei zu einer passwortgeschützten Seite (PBKDF2 + AES-256-GCM).
Aufruf: python3 encrypt_page.py input.html output.html "passwort"
"""
import sys, os, base64, json
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ITERATIONS = 600_000
SALT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "monitor-salt.bin")

def get_salt():
    """Stabiles Salt, damit die 'Angemeldet bleiben'-Schluessel Updates ueberleben.
    Das Salt steht ohnehin oeffentlich in der veroeffentlichten Seite; frisch pro
    Verschluesselung bleibt der GCM-IV."""
    if os.path.exists(SALT_FILE):
        with open(SALT_FILE, "rb") as f:
            salt = f.read()
        if len(salt) == 16:
            return salt
    salt = os.urandom(16)
    with open(SALT_FILE, "wb") as f:
        f.write(salt)
    return salt

def encrypt(html: bytes, password: str):
    salt = get_salt()
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=ITERATIONS)
    key = kdf.derive(password.encode("utf-8"))
    iv = os.urandom(12)
    ct = AESGCM(key).encrypt(iv, html, None)
    return salt, iv, ct

TEMPLATE = """<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FELDER Markt-Monitor · geschützt</title>
<style>
  body {{ font-family: system-ui, -apple-system, "Segoe UI", sans-serif; background: #f9f9f7; color: #0b0b0b;
         display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }}
  @media (prefers-color-scheme: dark) {{ body {{ background: #0d0d0d; color: #fff; }} .box {{ background: #1a1a19 !important; border-color: rgba(255,255,255,.1) !important; }} input {{ background:#0d0d0d; color:#fff; border-color:#383835 !important; }} }}
  .box {{ background: #fcfcfb; border: 1px solid rgba(11,11,11,.1); border-radius: 14px; padding: 34px 38px; max-width: 380px; width: 90%; text-align: center; }}
  h1 {{ font-size: 20px; margin: 0 0 6px; }}
  p {{ font-size: 13.5px; color: #898781; margin: 0 0 20px; }}
  input {{ width: 100%; box-sizing: border-box; font: inherit; padding: 10px 12px; border-radius: 8px; border: 1px solid #c3c2b7; margin-bottom: 12px; }}
  button {{ width: 100%; font: inherit; font-weight: 600; padding: 10px; border-radius: 8px; border: none; background: #2a78d6; color: #fff; cursor: pointer; }}
  button:hover {{ background: #1c5cab; }}
  label {{ font-size: 12.5px; color: #898781; display: flex; gap: 6px; align-items: center; justify-content: center; margin-bottom: 14px; }}
  #err {{ color: #d03b3b; font-size: 13px; min-height: 18px; margin-top: 10px; }}
</style>
</head>
<body>
<div class="box">
  <h1>🧭 FELDER Markt-Monitor</h1>
  <p>Wettbewerbsbeobachtung — bitte Passwort eingeben</p>
  <input type="password" id="pw" placeholder="Passwort" autofocus>
  <label><input type="checkbox" id="remember" style="width:auto;margin:0" checked> auf diesem Gerät merken</label>
  <button onclick="go()">Öffnen</button>
  <div id="err"></div>
</div>
<script>
const SALT = "{salt}", IV = "{iv}", CT = "{ct}", ITER = {iterations};
const b64 = s => Uint8Array.from(atob(s), c => c.charCodeAt(0));
async function deriveKey(pw) {{
  const mat = await crypto.subtle.importKey("raw", new TextEncoder().encode(pw), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({{ name: "PBKDF2", salt: b64(SALT), iterations: ITER, hash: "SHA-256" }},
    mat, {{ name: "AES-GCM", length: 256 }}, true, ["decrypt"]);
}}
async function decryptHtml(key) {{
  const plain = await crypto.subtle.decrypt({{ name: "AES-GCM", iv: b64(IV) }}, key, b64(CT));
  return new TextDecoder().decode(plain);
}}
function show(html) {{
  // Nur auf fertig geladener Seite aufrufen: document.open() waehrend des
  // Parsens ist ein No-Op und write() haengt den Inhalt sonst nur an.
  document.open(); document.write(html); document.close();
}}
async function go() {{
  const pw = document.getElementById("pw").value;
  const remember = document.getElementById("remember").checked;
  try {{
    const key = await deriveKey(pw);
    const html = await decryptHtml(key); // erst validieren (GCM), dann erst merken
    if (remember) {{
      try {{
        const raw = await crypto.subtle.exportKey("raw", key);
        localStorage.setItem("mm_key", btoa(String.fromCharCode(...new Uint8Array(raw))));
      }} catch (e) {{}}
    }}
    show(html);
  }} catch (e) {{
    document.getElementById("err").textContent = "Falsches Passwort — bitte erneut versuchen.";
  }}
}}
document.getElementById("pw").addEventListener("keydown", e => {{ if (e.key === "Enter") go(); }});
function autoLogin() {{
  (async () => {{
    try {{
      const stored = localStorage.getItem("mm_key");
      if (!stored) return;
      const key = await crypto.subtle.importKey("raw", b64(stored), {{ name: "AES-GCM" }}, true, ["decrypt"]);
      const html = await decryptHtml(key);
      show(html);
    }} catch (e) {{ try {{ localStorage.removeItem("mm_key"); }} catch (_) {{}} }}
  }})();
}}
if (document.readyState === "complete") {{ autoLogin(); }} else {{ window.addEventListener("load", autoLogin); }}
</script>
</body>
</html>"""

def main():
    src, dst, password = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(src, "rb") as f:
        html = f.read()
    salt, iv, ct = encrypt(html, password)
    out = TEMPLATE.format(
        salt=base64.b64encode(salt).decode(),
        iv=base64.b64encode(iv).decode(),
        ct=base64.b64encode(ct).decode(),
        iterations=ITERATIONS,
    )
    with open(dst, "w", encoding="utf-8") as f:
        f.write(out)
    print(f"encrypted -> {dst} ({os.path.getsize(dst)} bytes)")

if __name__ == "__main__":
    main()

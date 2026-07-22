#!/usr/bin/env python3
"""Stellt marktmonitor-state.json aus backup/state.enc wieder her (Gegenstück zu encrypt_page.py).
Aufruf: python restore_state.py backup/state.enc ziel.json "passwort" """
import sys, re, base64
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

src, dst, password = sys.argv[1], sys.argv[2], sys.argv[3]
page = open(src, encoding="utf-8").read()
m = re.search(r'const SALT = "([^"]+)", IV = "([^"]+)", CT = "([^"]+)", ITER = (\d+)', page)
if not m:
    sys.exit("FEHLER: Kryptokonstanten nicht gefunden")
salt, iv, ct, iters = base64.b64decode(m[1]), base64.b64decode(m[2]), base64.b64decode(m[3]), int(m[4])
key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=iters).derive(password.encode())
plain = AESGCM(key).decrypt(iv, ct, None)
open(dst, "wb").write(plain)
print(f"wiederhergestellt -> {dst} ({len(plain)} bytes)")

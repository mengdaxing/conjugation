#!/usr/bin/env python3
"""Create a private local signing key once; never replace an existing key."""
import os
from pathlib import Path
import secrets
import subprocess

folder = Path(__file__).resolve().parents[1] / 'Android/app'
key = folder / 'keystore.jks'
properties = folder / 'keystore.properties'
if key.exists() and properties.exists():
    raise SystemExit(0)
if key.exists() or properties.exists():
    raise SystemExit('Signing files are incomplete. Restore the matching keystore.jks and keystore.properties from your backup.')

password = secrets.token_urlsafe(32)
env = dict(os.environ, FRENCHVERBS_KEY_PASSWORD=password)
old_mask = os.umask(0o077)
try:
    subprocess.run([
        'keytool', '-genkeypair', '-keystore', str(key), '-storetype', 'PKCS12',
        '-alias', 'frenchverbs', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '36500',
        '-storepass:env', 'FRENCHVERBS_KEY_PASSWORD', '-keypass:env', 'FRENCHVERBS_KEY_PASSWORD',
        '-dname', 'CN=FrenchVerbs, OU=Android, O=Personal, C=FR', '-noprompt'
    ], env=env, check=True)
    properties.write_text(f'storeFile=keystore.jks\nstorePassword={password}\nkeyAlias=frenchverbs\nkeyPassword={password}\n')
    key.chmod(0o600)
    properties.chmod(0o600)
finally:
    os.umask(old_mask)
print('Created local Android signing files. Back up Android/app/keystore.jks and keystore.properties together.')

---
name: ssl-cert-convert
description: |
  Convert TLS/SSL certificate and key files between PEM, DER, and PKCS#12 (.pfx) formats, and build a leaf+intermediates fullchain bundle, using OpenSSL.

  Trigger for:
  - "Convert this .crt/.key to PEM" / "Make a .pfx from my cert and key"
  - "Build a fullchain.pem from my cert + intermediate"
  - Preparing certificate files for a web server, load balancer, or appliance that needs a specific format
  - Converting a DER/binary cert to PEM (or vice versa)

  Don't trigger for:
  - Issuing/renewing certificates (use certbot/ACME/a CA)
  - Inspecting a cert's contents only (just run `openssl x509 -text`)
  - Generating CSRs or private keys from scratch
---

# SSL/TLS Certificate Conversion

Convert certificate and key files between the formats services actually ask for —
PEM, DER, and PKCS#12 (`.pfx`/`.p12`) — and assemble a `fullchain.pem`
(leaf + intermediates) with OpenSSL.

This generalizes a lab-specific `sslfree.sh` that hardcoded a SSLForFree ZIP name,
copied files out of `/box-storage`, converted them, moved the results into
`/opt/gravwell/etc`, `chown`ed to `gravwell:gravwell`, and restarted the gravwell
web server. All of that is environment-specific. The bundled script keeps only the
genuinely reusable part — the **format conversion** — and leaves install/permissions/
reload to the caller, so it works for any service instead of one box. (The original
also had a latent bug: it converted to `mycert.pem`/`mykey.pem` but `chown`ed a
`mykey.pem` it never produced.)

## Prerequisites

`openssl` (present on virtually all Linux/macOS systems).

## How to run

```bash
# Normalize cert + key to PEM and build a fullchain:
bash .claude/skills/ssl-cert-convert/scripts/ssl-cert-convert.sh \
    --cert certificate.crt --key private.key --chain ca_bundle.crt \
    --fullchain --out-dir ./out --name mysite

# Convert a PEM cert to DER:
bash .claude/skills/ssl-cert-convert/scripts/ssl-cert-convert.sh \
    --cert mysite.crt --to der --out-dir ./out

# Build a Windows/IIS-style .pfx from cert + key (+ chain):
bash .claude/skills/ssl-cert-convert/scripts/ssl-cert-convert.sh \
    --cert mysite.crt --key mysite.key --chain ca_bundle.crt \
    --to pfx --pfx-pass 'S3cret' --out-dir ./out --name mysite
```

Flags: `--cert` (required), `--key`, `--chain`, `--to pem|der|pfx` (default `pem`),
`--fullchain` (concatenate leaf + chain), `--out-dir` (default `.`), `--name`
(output basename; defaults from the cert filename), `--pfx-pass` (PKCS#12 export
password; prompts if omitted).

The script auto-detects PEM vs. DER input, uses `openssl pkey` so it handles RSA/EC/
PKCS#8 keys uniformly, and `chmod 600`s any private-key/`.pfx` output.

## Deploying the result (do this explicitly, per environment)

Conversion is separated from deployment on purpose. When the user wants the cert
installed, perform the host-specific steps yourself rather than baking them into the
script — for example:

```bash
sudo cp out/mysite.fullchain.pem out/mysite.key.pem /etc/ssl/myservice/
sudo chown myservice:myservice /etc/ssl/myservice/mysite.*
sudo chmod 600 /etc/ssl/myservice/mysite.key.pem
sudo systemctl reload myservice
```

Always confirm the destination paths, ownership, and reload command with the user —
these differ per service (nginx, Apache, HAProxy, an appliance) and getting them
wrong can take a site offline.

## Validate

```bash
openssl x509 -in out/mysite.crt.pem -noout -subject -issuer -dates
# Confirm key matches cert (the two moduli/pubkeys should match):
openssl x509 -in out/mysite.crt.pem -noout -pubkey | openssl md5
openssl pkey -in out/mysite.key.pem -pubout | openssl md5
```

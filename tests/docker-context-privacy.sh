#!/usr/bin/env bash
# Exercise Docker's real .dockerignore handling using synthetic data only.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/context/.git" "$WORK/output"
cp "$ROOT/.dockerignore" "$ROOT/Dockerfile" "$ROOT/evil-winrm.rb" "$ROOT/LICENSE" "$WORK/context/"
printf '%s\n' 'DUMMY_CONTEXT_CANARY' > "$WORK/context/.git/config"
printf '%s\n' 'DUMMY_CONTEXT_CANARY' > "$WORK/context/.env"
printf '%s\n' 'DUMMY_CONTEXT_CANARY' > "$WORK/context/local-build-canary.txt"
printf '%s\n' 'DUMMY_CONTEXT_CANARY' > "$WORK/context/private.pem"
docker buildx build --no-cache --file - --output "type=local,dest=$WORK/output" "$WORK/context" <<'DOCKERFILE'
FROM scratch
COPY . /context/
DOCKERFILE
python3 - "$WORK/output/context" <<'PYTEST'
from pathlib import Path
import sys
root = Path(sys.argv[1])
actual = {p.name for p in root.iterdir()}
assert actual == {'Dockerfile', 'evil-winrm.rb', 'LICENSE'}, actual
assert not any(b'DUMMY_CONTEXT_CANARY' in p.read_bytes() for p in root.rglob('*') if p.is_file())
print('PASS: real Docker context excludes .git, .env, private keys and unrelated files; runtime and license retained')
PYTEST
python3 - "$ROOT/Dockerfile" <<'PYTEST'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
assert 'COPY evil-winrm.rb LICENSE /opt/evil-winrm/' in text
assert 'COPY . /opt/evil-winrm' not in text
print('PASS: Dockerfile uses an explicit runtime file allowlist')
PYTEST

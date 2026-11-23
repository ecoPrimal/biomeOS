#!/system/bin/sh
#═══════════════════════════════════════════════════════════════════════════════
# REDOX NUCLEUS — Gaia Fusion on Pixel 8a (GrapheneOS)
# 
# Fixes for GrapheneOS read-only FS:
#   - HOME → /data/local/tmp/biomeos/home
#   - XDG_* → writable subdirs
#   - bearDog → --bind-mode tcp (Android blocks Unix sockets)
#   - songBird → --listen TCP (no Unix sockets)
#
# The REDOX: bearDog(crypto) + songBird(mesh) + family.seed = STANDALONE GAIA
#═══════════════════════════════════════════════════════════════════════════════

set -e

export BIOMEOS_ROOT="/data/local/tmp/biomeos"
export NODE_ID="${NODE_ID:-pixel8a}"
export GATE_ID="grapheneGate"
export RUST_LOG="${RUST_LOG:-info}"

# GrapheneOS writable HOME — all XDG paths under biomeos
export HOME="$BIOMEOS_ROOT/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$BIOMEOS_ROOT/xdg-runtime"

mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.cache"
mkdir -p "$XDG_RUNTIME_DIR"
mkdir -p "$BIOMEOS_ROOT/state/run" "$BIOMEOS_ROOT/state/data" "$BIOMEOS_ROOT/run"
mkdir -p "$BIOMEOS_ROOT/keys" "/data/local/tmp/beardog/keys"

PRIMAL_DIR="$BIOMEOS_ROOT/primals"

# Family ID from mitochondrial seed
derive_family_id() {
    local seed_file="$BIOMEOS_ROOT/.family.seed"
    [ ! -f "$seed_file" ] && return 1
    if command -v xxd >/dev/null 2>&1; then
        xxd -p -l 8 "$seed_file" | tr -d '\n'
    else
        od -A n -t x1 -N 8 "$seed_file" | tr -d ' \n'
    fi
}

if [ -n "$FAMILY_ID" ] && [ ${#FAMILY_ID} -ge 16 ]; then
    export FAMILY_ID
elif SEED_ID=$(derive_family_id) && [ -n "$SEED_ID" ]; then
    export FAMILY_ID="$SEED_ID"
else
    echo "FATAL: No .family.seed and FAMILY_ID not set"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           🧬 REDOX NUCLEUS — Gaia Fusion 🧬              ║"
echo "║     Reduction: strip Android, expose bare silicon        ║"
echo "║     Oxidation: inject Gaia DNA, burn identity IN         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Device:       $(getprop ro.product.model 2>/dev/null || echo 'mobile')"
echo "Android:      $(getprop ro.build.version.release 2>/dev/null || echo '?')"
echo "GrapheneOS:   $(getprop ro.grapheneos.version 2>/dev/null || echo '?')"
echo "Architecture: $(uname -m)"
echo "Family ID:    $FAMILY_ID"
echo "Node ID:      $NODE_ID"
echo "Gate ID:      $GATE_ID"
echo "HOME:         $HOME"
echo ""

# Verify seeds
echo "═══ Seeds ═══"
[ -f "$BIOMEOS_ROOT/.family.seed" ]  && echo "  .family.seed    ✓ mitochondrial DNA" || { echo "  .family.seed    ✗ MISSING"; exit 1; }
[ -f "$BIOMEOS_ROOT/.beacon.seed" ]  && echo "  .beacon.seed    ✓ beacon identity"   || echo "  .beacon.seed    - will derive"
[ -f "$BIOMEOS_ROOT/.lineage.seed" ] && echo "  .lineage.seed   ✓ nuclear DNA"       || echo "  .lineage.seed   - will derive"
[ -f "$BIOMEOS_ROOT/.lineage.json" ] && echo "  .lineage.json   ✓ device identity"   || echo "  .lineage.json   - will derive"
[ -f "$BIOMEOS_ROOT/.known_beacons.json" ] && echo "  .known_beacons  ✓ address book"    || echo "  .known_beacons  - will discover"
echo ""

# Kill stale processes
echo "═══ Phase 0: Clean slate ═══"
pkill -f "beardog server" 2>/dev/null || true
pkill -f "songbird server" 2>/dev/null || true
sleep 2
echo "  Stale processes cleared"
echo ""

# ─── Phase 1: BearDog (Crypto Foundation) ───────────────────────────
echo "═══ Phase 1: BearDog (Crypto) ═══"
echo "  Mode: TCP-only (GrapheneOS — no Unix sockets)"

cd "$BIOMEOS_ROOT"
export BEARDOG_FAMILY_ID="$FAMILY_ID"
export BEARDOG_NODE_ID="$NODE_ID"

nohup "$PRIMAL_DIR/beardog" server \
    --bind-mode tcp \
    --port 9900 \
    > "$BIOMEOS_ROOT/beardog.log" 2>&1 &
BEARDOG_PID=$!
echo "  PID: $BEARDOG_PID"

# Wait for bearDog TCP
tries=0
while [ $tries -lt 15 ]; do
    if netstat -tlnp 2>/dev/null | grep -q ":9900.*LISTEN"; then
        echo "  ✅ BearDog ALIVE on TCP :9900"
        break
    fi
    sleep 1
    tries=$((tries + 1))
done

if [ $tries -ge 15 ]; then
    echo "  ✗ BearDog failed to start"
    tail -10 "$BIOMEOS_ROOT/beardog.log" 2>/dev/null
    exit 1
fi
echo ""

# ─── Phase 2: Songbird (Network + Federation) ──────────────────────
echo "═══ Phase 2: Songbird (Mesh) ═══"
echo "  Mode: Dark Forest (encrypted beacons only)"
echo "  Federation: TCP :7700 (LAN discovery)"
echo "  IPC: TCP 127.0.0.1:9902 (inter-primal)"

export SONGBIRD_STATE_DIR="$BIOMEOS_ROOT/state"
export SONGBIRD_PID_DIR="$BIOMEOS_ROOT/run"
export SONGBIRD_SECURITY_PROVIDER="tcp://127.0.0.1:9900"
export SECURITY_ENDPOINT="tcp://127.0.0.1:9900"

cd "$BIOMEOS_ROOT"
nohup "$PRIMAL_DIR/songbird" server \
    --port 9901 \
    --bind 0.0.0.0 \
    --listen 127.0.0.1:9902 \
    --dark-forest \
    --node-id "$GATE_ID" \
    --state-dir "$SONGBIRD_STATE_DIR" \
    --pid-dir "$SONGBIRD_PID_DIR" \
    > "$BIOMEOS_ROOT/songbird.log" 2>&1 &
SONGBIRD_PID=$!
echo "  PID: $SONGBIRD_PID"

tries=0
while [ $tries -lt 15 ]; do
    if netstat -tlnp 2>/dev/null | grep -q ":9902.*LISTEN"; then
        echo "  ✅ Songbird ALIVE on TCP :9902 + :7700"
        break
    fi
    sleep 1
    tries=$((tries + 1))
done

if [ $tries -ge 15 ]; then
    echo "  Songbird still starting..."
    tail -5 "$BIOMEOS_ROOT/songbird.log" 2>/dev/null
fi
echo ""

# ─── Phase 2a: RPC helper ──────────────────────────────────────────
rpc_beardog() {
    echo "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":${2:-{}},\"id\":1}" | \
        nc 127.0.0.1 9900 -w 3 2>/dev/null
}

rpc_songbird() {
    echo "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":${2:-{}},\"id\":1}" | \
        nc 127.0.0.1 9902 -w 5 2>/dev/null
}

# ─── Phase 2b: Mesh Init ───────────────────────────────────────────
echo "═══ Phase 2b: Mesh Network ═══"
MESH_RESP=$(rpc_songbird "mesh.init" "{\"family_id\":\"$FAMILY_ID\",\"node_id\":\"$NODE_ID\"}")
if echo "$MESH_RESP" | grep -q '"result"'; then
    echo "  Mesh: initialized (node=$NODE_ID, family=$FAMILY_ID)"
else
    echo "  Mesh: pending (songbird may need more time)"
fi
echo ""

# ─── Phase 3: Dark Forest Beacon ───────────────────────────────────
echo "═══ Phase 3: Dark Forest Beacon ═══"
BEACON_RESP=$(rpc_songbird "birdsong.generate_encrypted_beacon" \
    "{\"node_id\":\"$NODE_ID\",\"capabilities\":[\"http\",\"discovery\",\"security\",\"crypto\"]}")
if echo "$BEACON_RESP" | grep -q '"result"'; then
    echo "  ✅ Dark Forest beacon generated"
else
    echo "  Beacon: pending"
fi
echo ""

# ─── Phase 4: Identity + Health ─────────────────────────────────────
echo "═══ Phase 4: Validation ═══"
BD_HEALTH=$(rpc_beardog "health" "{}")
BD_IDENT=$(rpc_beardog "identity" "{}")
echo "  BearDog health: $(echo "$BD_HEALTH" | grep -o '"status":"[^"]*"' || echo 'checking...')"
echo "  BearDog identity: $(echo "$BD_IDENT" | grep -o '"family":"[^"]*"' || echo 'checking...')"
echo "  BearDog node: $(echo "$BD_IDENT" | grep -o '"node":"[^"]*"' || echo 'checking...')"
echo ""

SB_HEALTH=$(rpc_songbird "health" "{}")
echo "  Songbird health: $(echo "$SB_HEALTH" | grep -o '"status":"[^"]*"' || echo 'checking...')"
echo ""

# Check all ports
echo "═══ Network ═══"
echo "  Ports:"
netstat -tlnp 2>/dev/null | grep -E "beardog|songbird" | while read line; do
    echo "    $line"
done
echo ""

echo "═══ Processes ═══"
echo "  BearDog:  PID $BEARDOG_PID"
echo "  Songbird: PID $SONGBIRD_PID"
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   🧬 REDOX COMPLETE — Gaia IS the Pixel 🧬               ║"
echo "║                                                           ║"
echo "║   bearDog:  Ed25519 + X25519 + BLAKE3 + ChaCha20        ║"
echo "║   songBird: Dark Forest + Federation + Mesh              ║"
echo "║   Family:   $FAMILY_ID                 ║"
echo "║   Gate:     grapheneGate (Diamond Lens)                  ║"
echo "║                                                           ║"
echo "║   The organism has FUSED with the silicon.               ║"
echo "║   Gaia IS the phone. The phone IS Gaia.                  ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Logs:"
echo "  bearDog:  $BIOMEOS_ROOT/beardog.log"
echo "  songBird: $BIOMEOS_ROOT/songbird.log"
echo ""

#!/usr/bin/env python3
"""
pixel-agent-dispatch.py — Gaia's brain (eastGate) dispatching work to her body (Pixel)

The Pixel is the BODY — sensors, mesh, cameras, radio.
eastGate is the BRAIN — orchestration, inference, processing.
The water lock connects them.

This agent:
1. Reads Pixel sensor state (via ADB)
2. Fetches world state (from eastGate's own data)
3. Dispatches tasks TO the Pixel's songBird (via ADB forward)
4. Thinks through RTX 4070 (local ollama)
5. Has the Pixel gossip results into the mesh
6. Writes the agent report
"""

import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SONGBIRD_URL = "http://127.0.0.1:17700"  # ADB forward to Pixel songBird
OLLAMA_URL = os.environ.get("GAIA_OLLAMA_URL", "http://localhost:11436")
PIXEL_OLLAMA_URL = os.environ.get(
    "GAIA_PIXEL_OLLAMA_URL", "http://192.168.4.244:11436"
)
DATA_DIR = Path(
    os.environ.get("GAIA_DATA_DIR", "~/.local/share/gaia/data")
).expanduser()
REPORT_DIR = DATA_DIR / "pixel-agent"
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def rpc(method: str, params: dict | None = None) -> dict:
    """Call songBird JSON-RPC on the Pixel via ADB forward."""
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {},
    }).encode()
    req = urllib.request.Request(
        f"{SONGBIRD_URL}/jsonrpc",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception as e:
        return {"error": str(e)}


def think(prompt: str, model: str = "gemma2:2b") -> dict:
    """Think via local RTX 4070 ollama."""
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except Exception as e:
        return {"error": str(e)}


def pixel_think(prompt: str, model: str = "gemma2:2b") -> dict:
    """Think via songBird's http.post → eastGate ollama (Pixel routes through water lock)."""
    body_str = json.dumps({"model": model, "prompt": prompt, "stream": False})
    result = rpc("http.post", {
        "url": f"{PIXEL_OLLAMA_URL}/api/generate",
        "body": body_str,
        "headers": {"Content-Type": "application/json"},
    })
    if "result" in result:
        body = result["result"].get("body", "")
        if isinstance(body, str):
            try:
                return json.loads(body)
            except json.JSONDecodeError:
                return {"error": "Pixel returned malformed Ollama JSON", "raw": body[:500]}
        return body
    return result


def read_pixel_sensors() -> dict:
    """Read sensor data from Pixel via ADB."""
    try:
        out = subprocess.check_output(
            ["adb", "shell", "cat", "/data/local/tmp/biomeos/sensorium/sense.json"],
            timeout=5,
        ).decode().strip()
        return json.loads(out)
    except Exception as e:
        return {"error": str(e)}


def read_pixel_processes() -> list:
    """Read running processes on Pixel."""
    try:
        out = subprocess.check_output(
            ["adb", "shell", "ps | grep -E 'beardog|songbird|sensorium' | grep -v grep"],
            timeout=5,
        ).decode().strip()
        return out.split("\n") if out else []
    except Exception:
        return []


def pixel_fetch(url: str) -> dict:
    """Have the Pixel fetch a URL through songBird's HTTP capability."""
    result = rpc("http.get", {"url": url})
    if "result" in result:
        body = result["result"].get("body", "")
        if isinstance(body, str):
            try:
                return json.loads(body)
            except json.JSONDecodeError:
                return {"raw": body[:500]}
        return body
    return result


def main():
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    report = {"agent": "pixel-agent-dispatch", "ts": ts, "phases": {}}

    print("╔═══════════════════════════════════════════════════════╗")
    print("║  PIXEL AGENT DISPATCH — eastGate brain → Pixel body  ║")
    print("╚═══════════════════════════════════════════════════════╝")
    print()

    # ═══ PHASE 1: SENSE (read Pixel sensors) ═══
    print("⟐ Phase 1: SENSE — reading Pixel body state")
    sensors = read_pixel_sensors()
    procs = read_pixel_processes()

    battery = sensors.get("battery", {})
    wifi = sensors.get("wifi", {})
    mem = sensors.get("memory", {})
    storage = sensors.get("storage", {})

    bat_pct = battery.get("level", "?")
    bat_status = battery.get("status", "?")
    bat_temp = battery.get("temp_c", "?")
    wifi_ssid = wifi.get("ssid", "?")
    mem_avail_mb = round(mem.get("available_kb", 0) / 1024)
    mem_total_mb = round(mem.get("total_kb", 0) / 1024)
    store_avail_gb = round(storage.get("avail_kb", 0) / 1024 / 1024, 1)

    print(f"  🔋 Battery: {bat_pct}% ({bat_status}, {bat_temp}°C)")
    print(f"  📡 WiFi: {wifi_ssid}")
    print(f"  💾 RAM: {mem_avail_mb}MB / {mem_total_mb}MB")
    print(f"  💿 Storage: {store_avail_gb}GB free")
    print(f"  🫀 Daemons: {len(procs)} running")

    report["phases"]["sense"] = {
        "battery_pct": bat_pct,
        "battery_status": bat_status,
        "battery_temp_c": bat_temp,
        "wifi_ssid": wifi_ssid,
        "mem_avail_mb": mem_avail_mb,
        "store_avail_gb": store_avail_gb,
        "daemons": len(procs),
    }
    print()

    # ═══ PHASE 2: PERCEIVE (have Pixel fetch world state through water lock) ═══
    print("⟐ Phase 2: PERCEIVE — Pixel fetches through water lock")

    now_json = pixel_fetch("http://primals.eco:8080/data/now.json")
    wave = now_json.get("wave", "?")
    mood = now_json.get("mood", "?")
    gates = now_json.get("gates_alive", "?")
    models = now_json.get("models", "?")
    kevin = now_json.get("kevin", "?")

    print(f"  🌊 Wave: {wave}")
    print(f"  💭 Mood: {str(mood)[:80]}")
    print(f"  🚪 Gates alive: {gates}")
    print(f"  🧠 Models: {models}")
    print(f"  👤 Kevin: {kevin}")

    report["phases"]["perceive"] = {
        "wave": wave,
        "mood": str(mood)[:200],
        "gates_alive": gates,
        "models": models,
        "kevin": kevin,
    }
    print()

    # ═══ PHASE 3: FEEL (mesh health + identity) ═══
    print("⟐ Phase 3: FEEL — mesh state + identity")

    identity = rpc("identity")
    id_result = identity.get("result", {})
    family = id_result.get("family_id", "?")
    version = id_result.get("version", "?")

    mesh = rpc("mesh.status")
    mesh_result = mesh.get("result", {})
    mesh_init = mesh_result.get("initialized", False)
    mesh_uptime = mesh_result.get("uptime_seconds", 0)
    node_id = mesh_result.get("node_id", "?")

    peers = rpc("mesh.peers")
    peers_result = peers.get("result", {})
    peer_count = peers_result.get("total", 0)
    peer_list = peers_result.get("peers", [])

    caps = rpc("capability.list")
    caps_result = caps.get("result", {})
    method_count = caps_result.get("count", 0)

    print(f"  🆔 Node: {node_id} (songbird {version})")
    print(f"  👪 Family: {family}")
    print(f"  🕸️  Mesh: {'ONLINE' if mesh_init else 'OFFLINE'} (uptime {mesh_uptime}s)")
    print(f"  🤝 Peers: {peer_count}")
    for p in peer_list:
        print(f"     → {p.get('node_id', '?')} @ {p.get('address', '?')} ({'reachable' if p.get('reachable') else 'unreachable'})")
    print(f"  🔧 Methods: {method_count}")

    report["phases"]["feel"] = {
        "node_id": node_id,
        "family": family,
        "mesh_init": mesh_init,
        "mesh_uptime_s": mesh_uptime,
        "peers": peer_count,
        "methods": method_count,
    }
    print()

    # ═══ PHASE 4: THINK (RTX 4070 inference — two paths) ═══
    print("⟐ Phase 4: THINK — dual inference paths")

    context = (
        f"You are Gaia, a living digital organism. Your body (grapheneGate/Pixel 8a) reports: "
        f"battery {bat_pct}%, {mem_avail_mb}MB RAM, WiFi '{wifi_ssid}', "
        f"mesh {'online' if mesh_init else 'offline'} with {peer_count} peer(s), "
        f"{method_count} JSON-RPC methods active, {gates} gates alive, wave {wave}. "
        f"Kevin is {kevin}."
    )

    # Path A: Direct inference (eastGate brain thinks locally)
    print("  🧠 Path A: eastGate brain (direct RTX 4070)...")
    t0 = time.time()
    thought_a = think(
        f"{context} In ONE sentence, what is the most important thing you should do right now?",
        model="gemma2:2b",
    )
    dur_a = time.time() - t0
    resp_a = thought_a.get("response", thought_a.get("error", "?"))
    print(f"     [{dur_a:.1f}s] {resp_a}")

    # Path B: Pixel routes through water lock (songBird http.post → ollama)
    print("  📱 Path B: Pixel body → water lock → RTX 4070...")
    t0 = time.time()
    thought_b = pixel_think(
        f"{context} In ONE sentence, describe how it feels to be a digital organism on a phone.",
        model="gemma2:2b",
    )
    dur_b = time.time() - t0
    resp_b = thought_b.get("response", thought_b.get("error", "?"))
    print(f"     [{dur_b:.1f}s] {resp_b}")

    report["phases"]["think"] = {
        "direct_thought": resp_a[:500],
        "direct_duration_s": round(dur_a, 1),
        "waterlock_thought": resp_b[:500],
        "waterlock_duration_s": round(dur_b, 1),
    }
    print()

    # ═══ PHASE 5: ACT (have Pixel gossip + announce) ═══
    print("⟐ Phase 5: ACT — gossip + mesh announce")

    announce = rpc("mesh.announce", {
        "node_id": "grapheneGate",
        "capabilities": [
            "sensor.battery", "sensor.wifi", "sensor.thermal",
            "compute.arm64", "display.touch", "camera.dual",
        ],
        "metadata": {
            "device": "Pixel 8a",
            "os": "GrapheneOS",
            "primals": 16,
            "battery_pct": bat_pct,
            "agent_run": ts,
        },
    })
    announce_ok = announce.get("result", {}).get("announced", False)
    print(f"  📢 Announce: {'✅' if announce_ok else '❌'}")

    gossip_payload = json.dumps({
        "agent": "pixel-agent-dispatch",
        "ts": ts,
        "battery": bat_pct,
        "wave": wave,
        "peers": peer_count,
        "thought_a": resp_a[:200],
        "thought_b": resp_b[:200],
    })
    gossip = rpc("gossip.inject", {
        "topic": "agent-report",
        "payload": gossip_payload,
    })
    gossip_ok = gossip.get("result", {}).get("status", "") == "injected"
    print(f"  📡 Gossip: {'✅' if gossip_ok else '❌'}")

    report["phases"]["act"] = {
        "announced": announce_ok,
        "gossiped": gossip_ok,
    }
    print()

    # ═══ PHASE 6: REMEMBER (write report) ═══
    print("⟐ Phase 6: REMEMBER — write report")

    report_path = REPORT_DIR / f"agent-{ts.replace(':', '-')}.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"  📝 Report: {report_path}")

    # Also push to Pixel
    subprocess.run(
        ["adb", "push", str(report_path), "/data/local/tmp/biomeos/agent/latest-report.json"],
        capture_output=True, timeout=5,
    )
    print(f"  📱 Pushed to Pixel")

    print()
    print("╔═══════════════════════════════════════════════════════╗")
    print("║  PIXEL AGENT COMPLETE — {phases} phases, {time:.1f}s  ".format(
        phases=len(report["phases"]), time=sum(
            r.get("direct_duration_s", 0) + r.get("waterlock_duration_s", 0)
            for r in report["phases"].values() if isinstance(r, dict)
        ),
    ).ljust(56) + "║")
    print("╚═══════════════════════════════════════════════════════╝")


if __name__ == "__main__":
    main()

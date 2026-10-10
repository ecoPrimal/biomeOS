# biomeOS — Evolution Record

The changelog is sorted by capability surface, not by date.
Each section tells the arc: what emerged, what it replaced, what it became.
The date-sorted version history lives in `CHANGELOG_ARCHIVE.md`.

`H(data|epitope) < H(data|date) < H(data)`

---

## Neural API — JSON-RPC orchestration surface

Standalone `neural-api` binary with hardcoded routing → unified dispatch layer for 460+ methods, dual-protocol with HTTP, sole entry point for capability forwarding.

- **Route table & dispatch** (v2.30→v4.57): Match blocks → table-driven `ROUTE_TABLE` → semantic routes → signal-tier interception → wildcard dotted-capability dispatch.
- **capability.call** (v2.52→v4.57): Direct forwarding → translation registry → Songbird mesh fallback → gate-aware relay → riboCipher pooling + Perceptron L5 shadow routing.
- **capability.resolve / discover** (v3.01→v3.89): IPC DNS added; HTTP API proxies to Neural API socket; discovery schema aligned to `primary_endpoint` format.
- **Inference namespace** (v3.02): `inference.register_provider/complete/embed/models/providers` — springs register as backends with capability-layer fallback.
- **JSON-RPC compliance** (v2.40→v2.43): Batch requests, notification handling, `DispatchOutcome` separating protocol from application errors.
- **G22 API convergence** (v4.56): `biomeos api` and `biomeos neural-api` each launch HTTP + JSON-RPC in one process; standalone mode deprecated.

---

## Adaptive Routing — Layer 4 intelligence

First-match selection → EWMA-weighted adaptive routing with topology affinity, persistent state, and shadow validation.

- **RoutingWeightTable** (v3.67→v3.69): EWMA latency, error rate, affinity, cost hints, circuit breaker; `select_best()` replaces `providers[0]`.
- **Dispatch feedback** (v3.67→v3.95): Every call records outcome; PathwayLearner wired into graph node timing; utilization tracker via `neural_api.utilization`.
- **Persistent weights** (v3.69→v3.70): redb-backed table wired at startup — weights survive restart.
- **Topology affinity** (v3.94): Transport-tier auto-scoring (Unix 1.0 → WAN 0.3) seeded at registration.
- **Shadow analysis** (v3.95→v4.57): Weighted vs first-match divergence milestones; Perceptron L5 prep with re-entrancy guard.
- **Composition intelligence** (v3.67): `CompositionTier`, pattern registry, `plan_tier()` for emergent system sequences.

---

## Service Lifecycle — primal birth, health, resurrection

Shell-script NUCLEUS → pure-Rust lifecycle with dependency-ordered spawn, deep health probes, crash-resilient resurrection.

- **NUCLEUS launcher** (v1.17): `biomeos nucleus start` internalized shell script — binary discovery, dependency ordering, zero shell-outs.
- **LifecycleManager** (v1.17→v3.61): Register/apoptosis/resurrection; `--mode full` (12 primals) vs `Core` (5-primal legacy).
- **Health probing** (v3.50→v4.54): Strict body parsing → any successful RPC = alive; dual-protocol ping (JSON-RPC first, BTSP fallback) ended respawn storm.
- **Resurrection** (v4.50→v4.52): Auto-discovery registers `binary_path`; user-space paths (`~/.local/bin`, `$PATH`) fix socket evaporation on remote gates.
- **Socket ownership** (v4.51): `0o660` + `membrane` group for multi-user Sovereign CI; stale socket/PID cleanup on startup and shutdown (v3.62).
- **Virtual service suppression** (v4.54): External primals marked DEGRADED without resurrection; zombie reaping via background `child.wait()`.
- **Hot-reload & validation** (v3.47→v4.55): `composition.reload` per-primal swap; `composition.test_swap` + `composition.self_test` for Sovereign CI coevolution contract.

---

## Graph Execution — declarative composition engine

Monolithic executor → modular pipeline supporting transactional, continuous, streaming, and signal-tier coordination.

- **Executor core** (Deep Debt→v3.31): 1273-line monolith → `executor/` modules; unified schema for Neural API and DeploymentGraph node formats.
- **Execution modes** (v2.42→v2.43): Transactional (topo sort, checkpoints) → continuous (60 Hz tick loops) → streaming pipeline (bounded mpsc channels).
- **Signal dispatch** (v3.59→v3.63): 19 signal graphs across 5 tiers; all methods promoted to first-class route entries.
- **Spring deploy graphs** (v4.56): `action`/`params` shorthand normalized; shadow deploy validates remote gates at preflight.
- **Membrane composition** (v3.59→v3.71): Domain-appropriate node enforcement; `membrane_tower` as 7th composition pattern.
- **Cross-gate validation** (v3.07): Unregistered gate → explicit error; `node_graph_foreach` batch iteration (v4.57).

---

## Discovery & Topology — finding primals and capabilities

Hardcoded primal names → capability-domain-first discovery with multi-path socket scanning and live probing.

- **Capability registry** (v2.40→v4.57): Hardcoded defaults → TOML overlay → graph scan → persisted JSON snapshot with 30s sweep.
- **Socket discovery** (v1.5→v4.56): Unix-only → multi-transport; `/tmp` → `/run/biomeos` → `/run/membrane`; legacy paths scanned at Priority 3.
- **Capability-based resolution** (v2.82→v3.73): String literals → `primal_names` → `CapabilityTaxonomy` three-tier → domain-based subsystem detection.
- **Live topology** (v3.13→v3.78): Hardcoded `"healthy"` → endpoint probe; REST discovery endpoints; runtime `gate.register`/`gate.list` (v3.98).
- **Binary discovery** (v1.17→v4.52): plasmidBin-only → XDG user paths → `$PATH`; single `binary_search_dirs()` SSOT.

---

## Security & Authorization — BTSP, MethodGate, riboCipher

Plain JSON-RPC → BTSP encrypted framing → MethodGate authorization → ionic token envelopes → riboCipher signal tiers.

- **BTSP transport** (v2.98→v3.40): Insecure guard → `btsp.negotiate` → HKDF → Phase 3 encrypted framing via security provider delegation.
- **MethodGate** (v3.46→v3.50): Pre-dispatch Public/Protected classification; `auth.check/mode/peer_info`; token forwarding in enforced mode.
- **Ionic envelopes** (v3.47→v3.48): Token-carried mem/cpu/timeout/method_allowlist; orchestrator pre-dispatch + downstream injection.
- **riboCipher tiers** (v4.57): Clear/Mito/Nuclear enum; connection pooling; plain JSON-RPC when `btsp_optional=true` on local UDS.
- **Beacon genetics** (v1.7→v1.12): Two-seed architecture (lineage + beacon); pure noise beacons; A++ metadata privacy.

---

## Cross-Gate & Mesh — multi-gate composition

Single-gate orchestration → Songbird mesh dispatch, provenance sync, runtime gate registration.

- **Songbird mesh** (v3.75→v3.98): `relay.allocate` two-step → unified `capability.call { routing: "any" }` with UDS + TCP + TURN fallback.
- **nest.sync** (v3.64→v3.66): 6-node cross-spring provenance pipeline; `remote_gate` injected into graph env.
- **Gate routing** (v3.05→v3.07): Silent fallback → explicit error on unregistered gate; validated in both `capability.call` and `graph.execute`.
- **Federation** (v1.18→v1.27): HTTP JSON-RPC inter-NUCLEUS tier; Cloudflare tunnel rendezvous; Blake3-Lineage-KDF enrollment.
- **NAT traversal** (v1.13→v1.22): Mesh/STUN/relay/onion translations; 4-tier connection strategy; Plasmodium agent routing contexts.

---

## NUCLEUS & Spore Gateway — sovereign ingest/emit

CLI spore handling → signal-graph gateway with pseudoSpore 2.0 materialization and provenance trio.

- **NUCLEUS subcommands** (v3.77→v3.81): `nucleus ingest/emit/start`; 6-step ingest via signal graph; emit with exponential-backoff poll.
- **pseudoSpore 2.0** (v3.81): `biomeos-pseudospore` crate — canonical validation and full emit directory layout.
- **Provenance trio** (v2.32→v2.33): rhizoCrypt/loamSpine/sweetGrass wired; `rootpulse_commit.toml` 6-phase workflow.
- **RootPulse alignment** (v3.45): Graph methods aligned to primalSpring registry; standalone `biomeos graph execute` CLI.
- **Depot lineage** (v4.57): `graphs/depot_lineage.toml` templates; riboCipher Tier 2 mito-tag dispatch.

---

## Resource Management — envelopes, limits, spawn control

Ad-hoc spawning → structured resource envelopes, FD self-healing, data-driven launch profiles.

- **Resource envelopes** (v3.47→v3.61): Token-carried mem/cpu/timeout at pre-dispatch; full envelope forwarded downstream.
- **FD self-heal** (v4.57): `raise_fd_limit()` to 65536; PerceptronDispatcher recursion eliminated (58K → 14 FDs).
- **Launch profiles** (v3.90): `primal_launch_profiles.toml` data-driven socket config; capability-agnostic model injection.
- **Concurrent startup** (v2.39): Dependency-graph topological waves; DI `_with` variants for fully concurrent tests.

---

## IPC & Transport — multi-protocol client layer

Direct UnixStream → Universal IPC v3.0 with transport escalation and typed capability SDK.

- **AtomicClient** (v1.5→v2.46): Multi-transport JSON-RPC; 5-tier discovery; `IpcError` typed errors; `CapabilityClient` SDK.
- **tarpc escalation** (v1.8→v2.44): Binary protocol with JSON-RPC graceful fallback.
- **HTTP API** (v1.17→v4.56): REST routes wired; security headers; co-launched with Neural API in all modes.
- **Bind hardening** (v3.44): `--bind` flag; default localhost-only; TCP-only deprecated in release builds (v3.94).

---

## Observation & Collective Coordination — system self-awareness

Static health strings → structured dashboards, routing diagnostics, multi-gate collective awareness.

- **composition.health** (v3.04→v3.61): Subsystems response with mesh.state probing; pipeline readiness by capability domain.
- **Routing diagnostics** (v3.69→v3.70): `neural_api.weight_health` convergence stats; utilization hot/cold method tracking.
- **Plasmodium** (v1.15→v1.22): Over-NUCLEUS gate aggregation; agent routing; model cache with HF import; AI bridge via Songbird TLS chain.
- **Stability tiers** (v3.60): Every method classified stable/maturing/experimental/internal.

---

## Configuration & CLI — environment SSOT and operator interface

Scattered paths/env vars → typed constants, XDG compliance, `/run/membrane` namespace, unified mode tree.

- **SystemPaths & env SSOT** (v1.17→v3.96): XDG centralization; `/tmp` elimination (DH-1); 90+ env vars wired to typed constants; `primal_names` module.
- **Membrane namespace** (v4.56): `/biomeos/` → `/membrane/` across 46 files; `graphs_dir` resolution chain (v4.54).
- **CLI evolution** (v1.17→v4.57): `biomeos-cli` → `biome` helper; mode tree (api, nucleus, plasmodium, graph execute); process logging to `{socket_dir}/logs/`.

---

## Codebase Integrity — engineering standards (cross-cutting)

B+ scattered warnings → production-grade pure Rust with enforced quality gates.

- **Pure Rust** (v1.14→v3.08): Zero C/FFI deps; `#![forbid(unsafe_code)]` everywhere; `blake3`/`flate2` pure-only.
- **Quality gates** (Phase 1→v4.57): 719→578 tests (consolidated); zero production files >800 LOC; 47 dead deps removed; Edition 2024; clippy zero.

---

*Full date-sorted history: `CHANGELOG_ARCHIVE.md`*
*Last compressed: Wave 172*

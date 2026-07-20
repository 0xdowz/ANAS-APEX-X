# ANAS APEX X

ANAS APEX X is a modular command-line framework for Windows system diagnostics, latency benchmarking, cleanup, network repair, and performance tuning.

Developed and maintained by [0xdowz](https://github.com/0xdowz).

Unlike conventional optimization scripts that make unverified or irreversible system tweaks, ANAS APEX X is built around a transactional engine. Every modification applied to registry keys or system services is recorded in a native SQLite database (`logs/backups/apex.db`), enabling dry-run pre-validations and complete one-command rollbacks.

---

## Overview

### The Problem
Windows system tuning scripts often execute hardcoded registry modifications and service state changes without backup mechanisms or safety checks. Reverting these tweaks manually requires deep registry knowledge or complete system restores.

### The Solution
ANAS APEX X provides a structured CLI that enforces state tracking, declarative rules, and dry-run simulations:
- **Transactional Backups**: State changes are saved prior to execution.
- **Instant Rollbacks**: Reverts modifications in reverse (LIFO) order.
- **Declarative Rules**: Optimization parameters are decoupled into JSON files rather than hardcoded in script logic.
- **Asynchronous Execution**: Heavy operations (such as benchmarks and file scans) run in non-blocking background threads.

---

## Key Features

- **Transactional Rollback (`rollback`)**: Reverts modified registry properties and service startup configurations using recorded SQLite state data.
- **Declarative Rule DSL (`RuleEngine`)**: Loads rules from `rules/gaming.json` and `rules/network.json`, evaluating OS build compatibility constraints before applying actions.
- **Unified Subsystem Providers**: Standardized `Audit()`, `Backup()`, `Apply()`, `Restore()`, and `DryRun()` methods across Registry, Services, Power Schemes, and Network adapters.
- **Asynchronous Threading (`RunspaceEngine`)**: Offloads long-running diagnostic, benchmark, cleanup, and repair tasks to background PowerShell Runspaces.
- **System Integrity Doctor (`doctor`)**: Validates Administrator privilege elevation, TPM hardware status, and detects running game anti-cheat drivers (Vanguard, FACEIT, EAC).
- **Performance Benchmarking (`benchmark`)**: Performs ICMP latency tests against DNS resolvers and measures sequential disk read/write throughput in MB/s.
- **Junk Cleanup (`clean`)**: Scans and removes temporary files, system logs, crash dumps, and prefetch items.
- **Network Repair (`repair`)**: Resets Winsock catalog, resets TCP/IP stack configurations, and flushes DNS caches.
- **Dry-Run Mode (`--dry-run`)**: Simulates rule execution and outputs planned changes without altering system state.

---

## Tech Stack

- **Language**: PowerShell 5.1 / PowerShell 7+
- **Database Engine**: SQLite 3 via C# P/Invoke bindings to Windows native `C:\Windows\System32\winsqlite3.dll`
- **Concurrency**: PowerShell `RunspacePool` multi-threading
- **Testing**: Pester Unit Testing Framework (33/33 unit tests passing)
- **Windows APIs**: Win32 Registry API, Windows Service Control Manager (`Get-Service` / `Set-Service`), `powercfg.exe`, `netsh`, and WMI / CIM

---

## Architecture

```
                               ┌─────────────────────────┐
                               │  apex.ps1 / Start-Apex  │
                               └────────────┬────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────┐
                               │       CommandBus        │
                               └────────────┬────────────┘
                                            │
               ┌────────────────────────────┼────────────────────────────┐
               │                            │                            │
               ▼                            ▼                            ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐ ┌─────────────────────────────┐
│       SecurityEngine        │ │       RunspaceEngine        │ │         Logger Engine       │
│  (Privileges, TPM, Anticheat)│ │   (Background Runspaces)    │ │   (Console, File, JSON)     │
└─────────────────────────────┘ └───────────┬─────────────────┘ └─────────────────────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────────┐
                               │    Domain Execution Modules  │
                               │(Analysis, Benchmark, Clean) │
                               └────────────┬────────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────────┐
                               │         RuleEngine          │
                               │  (Parses rules/*.json DSL)  │
                               └────────────┬────────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────────┐
                               │      Providers Layer        │
                               │(Registry, Service, Network) │
                               └────────────┬────────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────────┐
                               │        StateManager         │
                               └────────────┬────────────────┘
                                            │
                                            ▼
                               ┌─────────────────────────────┐
                               │ SQLite Database (apex.db)   │
                               └─────────────────────────────┘
```

### Flow of Execution
1. **Invocation**: `apex.ps1` bootstraps the dynamic module registry and dispatches input parameters to `CommandBus`.
2. **Security Verification**: `SecurityEngine` verifies Administrator elevation and checks for anti-cheat driver conflicts.
3. **Async Dispatch**: Long-running commands (`analyze`, `benchmark`, `clean`, `repair`) execute via `RunspaceEngine` background thread pools.
4. **Rule Evaluation**: `RuleEngine` loads external JSON rules, checks OS build constraints, and triggers provider actions.
5. **Backup & Commit**: Before applying changes, `Providers` record original state data into `StateManager`, which writes transactions into `logs/backups/apex.db`.

---

## Project Structure

```
ANAS APEX X/
├── apex.ps1                    # Primary CLI execution wrapper
├── Apex.psd1                   # PowerShell module manifest
├── Apex.psm1                   # Module entrypoint & handler registration
├── rules/                      # Declarative JSON Rule DSL files
│   ├── gaming.json             # Game Mode & Xbox DVR optimizations
│   └── network.json            # Network throttling & TCP ACK overrides
├── src/
│   ├── Core/                   # Subsystem engines
│   │   ├── CommandBus.psm1     # Command line parser and router
│   │   ├── EventBus.psm1       # Decoupled Pub/Sub event engine
│   │   ├── RuleEngine.psm1     # Rule DSL parser and constraint evaluator
│   │   ├── RunspaceEngine.psm1 # Background thread pool manager
│   │   ├── SQLiteDatabase.psm1 # Native P/Invoke winsqlite3.dll driver
│   │   ├── StateManager.psm1   # Transactional backup & LIFO rollback engine
│   │   └── CacheEngine.psm1    # In-memory TTL cache engine
│   ├── Domain/                 # Task domain implementations
│   │   ├── Analysis/           # System compliance scanner
│   │   ├── Benchmark/          # ICMP Ping & Disk throughput tester
│   │   ├── Cleanup/            # Temp junk and prefetch cleaner
│   │   ├── Gaming/             # Gaming optimization domain
│   │   ├── Network/            # Network TCP/IP optimization domain
│   │   └── Repair/             # Network stack reset & DNS repair domain
│   ├── Providers/              # Hardware and system provider abstraction layer
│   │   ├── ProviderContract.psm1 # BaseProvider & AuditResult contracts
│   │   ├── RegistryProvider.psm1 # Win32 Registry provider
│   │   ├── ServiceProvider.psm1  # Windows Services provider
│   │   ├── PowerCfgProvider.psm1 # Windows Power Scheme provider
│   │   └── NetworkProvider.psm1  # Network TCP/IP provider
│   ├── Security/               # Integrity & anti-cheat checker
│   ├── Logger/                 # Multi-channel console, file, and JSON loggers
│   └── Tests/Unit/             # Pester unit test suite (33 unit tests)
├── .gitignore
├── LICENSE                     # MIT License
└── README.md
```

---

## Installation & Setup

### Prerequisites
- **Operating System**: Windows 10 or Windows 11 (64-bit)
- **Privileges**: Elevated Administrator PowerShell Console
- **PowerShell**: Version 5.1 or PowerShell 7+

### Setup Instructions

1. Clone the repository:
   ```powershell
   git clone https://github.com/0xdowz/ANAS-APEX-X.git
   cd ANAS-APEX-X
   ```

2. Enable script execution for the current session:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```

---

## Usage

Execute commands via `apex.ps1` in an elevated PowerShell session:

```powershell
# 1. Run security & environment checks
.\apex.ps1 doctor

# 2. Audit current system optimization compliance
.\apex.ps1 analyze

# 3. Simulate optimization changes without applying (Dry-Run Mode)
.\apex.ps1 optimize --dry-run

# 4. Apply gaming & network optimizations
.\apex.ps1 optimize

# 5. Revert all modifications from SQLite transaction history
.\apex.ps1 rollback

# 6. Run disk throughput & network latency benchmarks
.\apex.ps1 benchmark

# 7. Clean temporary files, logs, and prefetch cache
.\apex.ps1 clean

# 8. Reset Winsock catalog and flush DNS cache
.\apex.ps1 repair

# 9. View CLI version and environment information
.\apex.ps1 version
```

### Available Command Flags

- `--dry-run`: Pre-verifies operations without executing modifications.
- `--json`, `-j`: Outputs machine-readable JSON payloads.
- `--silent`: Suppresses console output.
- `--verbose`: Displays detailed diagnostic execution logs.
- `--help`, `-h`: Shows command usage help.

---

## Testing & Verification

Unit tests are implemented using the **Pester** test framework.

To execute the test suite:
```powershell
Invoke-Pester -Path src/Tests/Unit/
```

### Test Coverage Summary
- **StateManager**: Verifies SQLite transactions, LIFO ordering, and automatic migration from legacy `transaction_log.json`.
- **Providers**: Verifies `Audit()`, `Backup()`, `Apply()`, `Restore()`, and `DryRun()` across `RegistryProvider`, `ServiceProvider`, `PowerCfgProvider`, and `NetworkProvider`.
- **Rule Engine**: Verifies JSON rule parsing and OS build constraint evaluation.
- **Runspace Engine**: Verifies asynchronous background task execution.
- **Security Engine**: Verifies Administrator check, TPM detection, and anti-cheat validation.

---

## Author

Created and maintained by **[0xdowz](https://github.com/0xdowz)**.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

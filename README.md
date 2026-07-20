# ANAS APEX X

ANAS APEX X is a modular PowerShell framework for Windows system diagnostics, benchmarking, cleanup, network repair, and performance tuning. 

It is designed for system administrators, power users, and developers who want transparent, controllable Windows tuning. Unlike traditional tweak scripts that apply permanent registry hacks without tracking state, ANAS APEX X records every system change into a transactional SQLite database (`logs/backups/apex.db`). This enables single-command rollbacks, dry-run pre-validations, and complete transparency into modified system settings.

---

## Why This Project Exists

Windows performance optimization scripts often suffer from the same fundamental flaws:
- They run opaque batch commands or registry edits with no backup mechanism.
- Reverting changes requires manual registry editing or full system restore points.
- They frequently include placebo or destructive tweaks (such as disabling Windows Update or Defender).

ANAS APEX X was created to apply enterprise software patterns to system optimization. By decoupling rules into JSON definitions and storing original state in an embedded SQLite database, the tool ensures that every modification is auditable, safe, and fully reversible.

---

## Key Features

- **Transactional Rollback (`rollback`)**: Automatically records original registry values and service startup types before modifying them, allowing full restoration in reverse (LIFO) order.
- **Declarative Rule DSL (`RuleEngine`)**: Optimization rules are defined in `rules/gaming.json` and `rules/network.json`. Rules include OS build constraint evaluation to prevent applying incompatible settings.
- **Subsystem Provider Abstraction**: Encapsulates Windows API calls inside standardized `Audit()`, `Backup()`, `Apply()`, `Restore()`, and `DryRun()` methods across Registry, Services, Power Schemes, and Network adapters.
- **Asynchronous Runspace Threading (`RunspaceEngine`)**: Offloads long-running tasks (`analyze`, `benchmark`, `clean`, `repair`) to background PowerShell Runspaces to keep the console UI responsive.
- **Environment Integrity Check (`doctor`)**: Audits Administrator elevation, TPM chip status, and flags running game anti-cheat drivers (Vanguard, FACEIT, EAC) that could interfere with system tuning.
- **Performance Benchmarking (`benchmark`)**: Measures ICMP ping latency against public DNS resolvers and tests sequential disk read/write throughput in MB/s.
- **Junk & Temp Cleaner (`clean`)**: Safely removes temporary files, system log files, crash dumps, and prefetch caches.
- **Network Stack Repair (`repair`)**: Resets Winsock catalog entries, resets TCP/IP stack configurations, and flushes DNS caches.
- **Dry-Run Mode (`--dry-run`)**: Simulates rule execution and logs planned registry and service writes without modifying the system.

---

## Design Philosophy

- **Safety First**: No system setting is changed without first recording its original value.
- **Reversibility**: System state changes are non-destructive and can be undone via `apex rollback`.
- **Transparency**: Clear logging across console, file, and structured JSON outputs so users know exactly what was modified.
- **Modularity**: Domain logic, core engines, and subsystem providers are separated into dedicated PowerShell modules.

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
│       SecurityEngine        │ │       RunspaceEngine        │ │       Logger Subsystem      │
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

### Flow of Control
1. **Dispatcher**: `apex.ps1` initializes the module registry and routes CLI arguments through `CommandBus`.
2. **Environment Validation**: `SecurityEngine` validates execution privileges and checks for anti-cheat driver conflicts.
3. **Async Offloading**: Heavy domain workloads are passed to `RunspaceEngine` background thread pools.
4. **Rule Processing**: `RuleEngine` loads external JSON rules, checks OS build constraints, and triggers provider actions.
5. **State Recording**: Before writing changes, `Providers` record original state data into `StateManager`, which writes transaction logs to `logs/backups/apex.db`.

---

## Tech Stack

- **Language**: PowerShell 5.1 / PowerShell 7+
- **Embedded Database**: SQLite 3 via C# P/Invoke bindings to Windows native `C:\Windows\System32\winsqlite3.dll`
- **Concurrency**: PowerShell `RunspacePool` multi-threading
- **Testing Framework**: Pester Unit Testing Framework
- **Windows APIs**: Win32 Registry API, Windows Service Control Manager, `powercfg.exe`, `netsh`, and WMI / CIM

---

## Project Structure

```
ANAS APEX X/
├── apex.ps1                    # Primary CLI entrypoint script
├── Apex.psd1                   # PowerShell module manifest
├── Apex.psm1                   # Module entrypoint & handler registration
├── rules/                      # External JSON Rule DSL files
│   ├── gaming.json             # Game Mode & Xbox DVR rules
│   └── network.json            # Network throttling & TCP ACK rules
├── src/
│   ├── Core/                   # Core subsystem engines
│   │   ├── CommandBus.psm1     # Command line parser and router
│   │   ├── EventBus.psm1       # Decoupled Pub/Sub event engine
│   │   ├── RuleEngine.psm1     # Rule DSL parser and constraint evaluator
│   │   ├── RunspaceEngine.psm1 # Background thread pool manager
│   │   ├── SQLiteDatabase.psm1 # Native P/Invoke winsqlite3.dll driver
│   │   ├── StateManager.psm1   # Transactional backup & LIFO rollback engine
│   │   └── CacheEngine.psm1    # In-memory TTL cache engine
│   ├── Domain/                 # Domain execution modules
│   │   ├── Analysis/           # Compliance scanner
│   │   ├── Benchmark/          # Ping & Disk throughput tester
│   │   ├── Cleanup/            # Temp junk and prefetch cleaner
│   │   ├── Gaming/             # Gaming optimization domain
│   │   ├── Network/            # Network TCP/IP optimization domain
│   │   └── Repair/             # Network stack reset domain
│   ├── Providers/              # Subsystem provider abstraction layer
│   │   ├── ProviderContract.psm1 # BaseProvider & AuditResult contracts
│   │   ├── RegistryProvider.psm1 # Win32 Registry provider
│   │   ├── ServiceProvider.psm1  # Windows Services provider
│   │   ├── PowerCfgProvider.psm1 # Power scheme provider
│   │   └── NetworkProvider.psm1  # Network TCP/IP provider
│   ├── Security/               # Integrity & anti-cheat checker
│   ├── Logger/                 # Multi-channel loggers
│   └── Tests/Unit/             # Pester unit test suite (33 unit tests)
├── .gitignore
├── LICENSE                     # MIT License
└── README.md
```

---

## Installation

### Prerequisites
- **OS**: Windows 10 or Windows 11 (64-bit)
- **Privileges**: Administrator PowerShell Console
- **PowerShell**: Version 5.1 or PowerShell 7+

### Steps
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

Run `apex.ps1` from an elevated PowerShell console.

```powershell
# Environment integrity check
.\apex.ps1 doctor

# Audit current system compliance
.\apex.ps1 analyze

# Simulate optimizations (Dry-Run mode)
.\apex.ps1 optimize --dry-run

# Apply gaming & network optimizations
.\apex.ps1 optimize

# Revert all applied modifications
.\apex.ps1 rollback

# Run benchmark tests (Ping latency & Disk throughput)
.\apex.ps1 benchmark

# Clean system temp & junk files
.\apex.ps1 clean

# Repair network stack & flush DNS
.\apex.ps1 repair

# Display CLI version and environment diagnostics
.\apex.ps1 version
```

### Global Flags

- `--dry-run`: Pre-verify modifications without writing changes to registry or services.
- `--json`, `-j`: Output machine-readable JSON payloads.
- `--silent`: Suppress console outputs.
- `--verbose`: Output verbose diagnostic logs.
- `--help`, `-h`: Display CLI help.

---

## Safety & Security Considerations

- **Backup Guarantee**: Every registry or service state modification is stored in `logs/backups/apex.db` before execution.
- **SQLite Concurrency & WAL Mode**: SQLite runs with Write-Ahead Logging (`WAL`) mode enabled to prevent database locking during parallel operations.
- **Rollback Safety**: Reverts modified properties in reverse (LIFO) order to prevent dependency order conflicts.
- **Privilege Requirement**: System tuning requires Administrator elevation. Runs without Administrator privileges are blocked by `SecurityEngine`.

---

## Testing

Unit testing is powered by the **Pester** framework.

Execute all unit tests:
```powershell
Invoke-Pester -Path src/Tests/Unit/
```

### Verified Coverage
- **33 / 33 Unit Tests Passing**
- **StateManager**: SQLite transaction logging, LIFO rollbacks, and legacy JSON migration.
- **Providers**: `Audit`, `Backup`, `Apply`, `Restore`, and `DryRun` contract compliance.
- **Rule Engine**: DSL parsing and OS build constraint checking.
- **Runspace Engine**: Asynchronous thread pool execution.

---

## Limitations

- **Platform Limitation**: Compatible exclusively with Windows 10 and Windows 11 (64-bit).
- **Rollback Scope**: Rollback tracks registry properties and service states modified through the tool. Files deleted via `clean` are permanently purged and not backed up.

---

## Roadmap

- [ ] Selective transaction rollbacks by subsystem tag.
- [ ] Dedicated WMI/CIM GPU and CPU driver provider.
- [ ] Telemetry exporter for local dashboard integration.

---

## Contributing

1. Fork the repository on GitHub.
2. Create a feature branch (`git checkout -b feature/my-feature`).
3. Ensure all tests pass (`Invoke-Pester -Path src/Tests/Unit/`).
4. Push your branch and submit a Pull Request.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## Author

Created and maintained by **[0xdowz](https://github.com/0xdowz)**.

# Guardian Eye Pro — Local Environment Network Changes

This log records network/firewall changes made or recommended for the project. Because the Manus sandbox is a Linux container (not the owner's Windows machine), no Windows firewall rules have been executed here. All Windows steps are written as precise, reversible, owner-executed instructions with the previous-state recording requirement built in. Nothing in this document requires globally disabling the firewall or antivirus — that is explicitly forbidden by the project mandate (GA-19, register).

## 1. Previous State (Recording Requirement)

Before executing the commands below, the owner MUST record the pre-change state on their machine with:

```powershell
Get-NetFirewallRule -Profile Any | Select-Object Name, Enabled, Direction, Action | Export-Csv "$env:USERPROFILE\ge_firewall_state_before.csv" -NoTypeInformation
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction | Export-Csv "$env:USERPROFILE\ge_firewall_profile_before.csv" -NoTypeInformation
netstat -ano | findstr ":8080 :8081 :9099 :5037 :4447" > "$env:USERPROFILE\ge_ports_before.txt"
```

The exported CSVs are the auditable previous state. If any later rule behaves unexpectedly, revert using the rollback section.

## 2. Ports Used by the Project

| Component | Port(s) | Direction | Purpose |
| --------- | ------- | --------- | ------- |
| Firebase Emulator — Firestore | 8080 | localhost inbound | Emulator gRPC/REST |
| Firebase Emulator — Functions | 5001 | localhost inbound | Function HTTP triggers |
| Firebase Emulator — UI | 4000 | localhost inbound | Emulator suite dashboard |
| ADB server | 5037 | localhost | Host-to-device protocol |
| Emulator (AVD) guest → host | 5554, 5555 + 10.0.2.2 alias | host outbound / guest inbound | Emulator reaches host services (`10.0.2.2:8080` = host `localhost:8080`) |
| Flutter dev server | 8080-ish (random high port), observatory | localhost | Debug app hot reload |
| Gradle daemon | high random | localhost | Build |

All of these are localhost-only traffic except ADB (USB/TCP device) and outbound REST to `firebase.googleapis.com`, `firestore.googleapis.com`, `identitytoolkit.googleapis.com`, `storage.googleapis.com` (Google API outbound endpoints, port 443).

## 3. Recommended Scoped Changes (Owner-Executed, PowerShell as Administrator)

```powershell
# 3.1 ADB: allow inbound on its service port only (default deny profile untouched)
New-NetFirewallRule -DisplayName "ADB (Android Debug Bridge) inbound" -Direction Inbound -Protocol TCP -LocalPort 5037 -Profile Private -Action Allow -Enabled True

# 3.2 AVD guest-to-host traffic: allow inbound TCP from the emulator virtual adapter range
New-NetFirewallRule -DisplayName "Android Emulator guest-to-host" -Direction Inbound -Protocol TCP -RemoteAddress 10.0.2.0/24 -Profile Private -Action Allow -Enabled True

# 3.3 Emulator Suite loopback: normally not required (loopback is not filtered), added only if the owner observes blocked emulator UI
New-NetFirewallRule -DisplayName "Firebase Emulator UI loopback" -Direction Inbound -Protocol TCP -LocalPort 4000 -Profile Private -Action Allow -Enabled True
```

No outbound rule is normally needed (outbound is default-allow on Windows Desktop profiles). If a corporate policy tightens outbound, the minimum endpoints are `firebase.googleapis.com:443`, `firestore.googleapis.com:443`, `identitytoolkit.googleapis.com:443`, and `storage.googleapis.com:443`. If the owner is uncertain about any corporate policy, classify that change as HUMAN ACTION REQUIRED and STOP — do not guess.

## 4. Reason

ADB device connections over Wi-Fi (or TCP pairings) and AVD guest-to-host communication were the two failure modes historically caused by Windows Defender Firewall silently dropping inbound traffic on Private profile. The emulator needs `10.0.2.2` reachability to the host for tests against host-provided services. These scoped rules eliminate that failure class without reducing any profile's default-deny posture.

## 5. Verification

```powershell
# Confirm rules exist
Get-NetFirewallRule -DisplayName "ADB*","Android Emulator*","Firebase Emulator*" | Format-Table Name, Enabled, Direction, Action

# Confirm ADB pairing works: `adb devices` lists the device
# Confirm emulator-to-host: from inside the AVD shell, `adb shell` then
curl http://10.0.2.2:8080  # should complete or reject (emulator-specific), not hang silently
# Confirm emulator suite: run ./tool/run_firebase_emulator_tests.sh — Firestore 15/15 + Functions 2/2
```

## 6. Rollback Instructions

```powershell
Get-NetFirewallRule -DisplayName "ADB (Android Debug Bridge) inbound","Android Emulator guest-to-host","Firebase Emulator UI loopback" | Remove-NetFirewallRule
# Restore original profile state if ever modified (should never be):
# (re-apply values from ge_firewall_profile_before.csv)
```

Removal is safe because the original default-deny posture of each profile is untouched by the scoped additions.

## 7. Change Log

| Date | Change | Reason | Verifier | Rollback |
| ---- | ------ | ------ | -------- | -------- |
| 2026-08-14 | Document created; no Windows rules executed from sandbox | Mandate §23: scoped-only, owner-executed | Manus | §6 commands |
| (owner) | §3 rules after §1 state capture | ADB/AVD reachability | Owner | §6 commands |

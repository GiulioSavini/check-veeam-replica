# check_veeam_replica.ps1

**Icinga / NetEye monitoring plugin** per il monitoraggio dei **job di replica Veeam Backup & Replication**.

---

## Panoramica

Lo script controlla tutti i job di tipo Replica configurati in Veeam B&R:

| Check | Cosa verifica | Risultato |
|---|---|---|
| **Job falliti** | `Result = Failed` | CRITICAL |
| **Job con warning** | `Result = Warning` | WARNING |
| **Job disabilitati** | `IsScheduleEnabled = false` | Contati, nessun alert |
| **Job in esecuzione** | `State = Working` | Contati, nessun alert |
| **Nessun job replica** | 0 job trovati | UNKNOWN |

---

## Logica degli exit code

| Exit Code | Stato | Condizione |
|---|---|---|
| `0` | **OK** | Tutti i job replica completati con successo |
| `1` | **WARNING** | Almeno un job con warning (nessun fallito) |
| `2` | **CRITICAL** | Almeno un job fallito |
| `3` | **UNKNOWN** | Nessun job di replica trovato |

---

## Requisiti

- **PowerShell 5.1+**
- **Veeam Backup & Replication** installato sullo stesso server
- **Modulo PowerShell Veeam**: `Veeam.Backup.PowerShell`

### Permessi richiesti

Lo script deve essere eseguito con un utente che ha accesso alla console Veeam (tipicamente Local Administrator o Veeam Backup Administrator).

---

## Porte di rete richieste

| Sorgente | Destinazione | Porta | Protocollo | Descrizione |
|---|---|---|---|---|
| Monitoring server | Veeam B&R Server | **5985/tcp** | WinRM (HTTP) | Esecuzione remota PowerShell (se via Icinga Agent non serve) |
| Monitoring server | Veeam B&R Server | **5986/tcp** | WinRM (HTTPS) | Esecuzione remota PowerShell sicura |

> **Nota:** Se lo script viene eseguito localmente tramite Icinga Agent / NSClient++, non sono necessarie porte aggiuntive.

---

## Installazione

```powershell
# Clona il repository
git clone https://github.com/GiulioSavini/check-veeam-replica.git
cd check-veeam-replica

# Copia nella directory dei plugin
Copy-Item check_veeam_replica.ps1 "C:\ProgramData\icinga2\usr\lib\nagios\plugins\"
```

---

## Sintassi

```powershell
check_veeam_replica.ps1
```

Lo script non richiede parametri. Scansiona automaticamente tutti i job di tipo Replica.

---

## Esempi di utilizzo

### Check standard

```powershell
.\check_veeam_replica.ps1
```

Output:
```
OK! All 5 replica job(s) completed successfully (1 disabled) | total=6 success=5 failed=0 warning=0 disabled=1 running=0
```

### Esempio output CRITICAL

```
CRITICAL! 1 replica job(s) FAILED: Replica-SQL-DR (ended: 19/03/2026 04:15) | total=6 success=4 failed=1 warning=0 disabled=1 running=0
```

### Esempio output WARNING

```
WARNING! 1 replica job(s) with warnings: Replica-FileServer | total=6 success=4 failed=0 warning=1 disabled=1 running=0
```

---

## Performance Data (perfdata)

| Metrica | Descrizione |
|---|---|
| `total` | Numero totale di job replica |
| `success` | Job completati con successo |
| `failed` | Job falliti |
| `warning` | Job con warning |
| `disabled` | Job disabilitati |
| `running` | Job in esecuzione al momento del check |

---

## Dettagli tecnici

### Architettura dello script

```
check_veeam_replica.ps1
├── Get-VBRJob                    # Recupera tutti i job Veeam
├── Filtra Replica                # TypeToString -like "*Replica*" OR JobType -eq "Replica"
└── Per ogni job replica:
    ├── Disabilitato → disabled_count++
    ├── Nessuna sessione → success_count++
    ├── State = Working → running_count++
    ├── Result = Failed → CRITICAL + timestamp fine
    ├── Result = Warning → WARNING
    └── Altro → success_count++
```

### Rilevamento job replica

I job replica vengono identificati con doppio filtro:
- `TypeToString -like "*Replica*"` (stringa leggibile)
- `JobType -eq "Replica"` (enum interno)

Questo copre sia le versioni piu' vecchie che quelle recenti di Veeam B&R.

### Gestione "worst status wins"

Se ci sono sia job con warning che job falliti, il risultato finale e' CRITICAL (il peggiore vince). La logica:
- `$globalstatus = 2` se almeno un Failed
- `$globalstatus = 1` se almeno un Warning (e nessun Failed)
- `$globalstatus = 0` se tutto OK

---

## Configurazione Icinga / NetEye

### CheckCommand definition

```
object CheckCommand "check_veeam_replica" {
  command = [ "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", PluginDir + "/check_veeam_replica.ps1" ]
}
```

### Service definition

```
apply Service "veeam-replica" {
  check_command = "check_veeam_replica"
  check_interval = 15m
  retry_interval = 5m
  assign where host.vars.role == "veeam"
}
```

---

## Licenza

MIT License

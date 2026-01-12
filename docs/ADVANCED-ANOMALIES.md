# 🔴 Advanced Anomaly Detection Guide

**Patterns that Defender/SIEM CANNOT detect**

---

## Why Traditional SIEM Fails

| Defender/SIEM sees... | Cannot detect... |
|---|---|
| "GRANT SELECT OK" | 6 GRANTs in 2 min = privilege escalation |
| "SELECT from sales OK" | Same user accessing 5 schemas = recon |
| "Query at 3 AM OK" | User NEVER works at 3 AM = insider |
| "pg_tables query OK" | 15 system tables in 5 min = attacker mapping |

**Fabric ML uses `series_decompose_anomalies()` to learn behavioral baselines.**

---

## New Anomalies (v3)

### 1. Privilege Escalation
```
Threshold: >3 GRANT/REVOKE ops in 5 minutes
Severity: CRITICAL if >10, HIGH if >5
```

**Attack pattern**: Malware or insider rapidly granting themselves permissions.

### 2. Cross-Schema Reconnaissance  
```
Threshold: >4 different schemas accessed in 10 minutes
Severity: CRITICAL if >8, HIGH if >5
```

**Attack pattern**: Lateral movement before targeted exfiltration.

### 3. Deep Schema Enumeration
```
Threshold: >10 queries to pg_catalog/information_schema in 5 min
Severity: CRITICAL if >30, HIGH if >15
```

**Attack pattern**: Attacker mapping database structure before attack.

### 4. ML Baseline Deviation
```
Uses: series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
Severity: CRITICAL if score >3.0, HIGH if >2.0
```

**Attack pattern**: Any activity deviating from learned normal behavior.

---

## Testing

Execute `TEST-ANOMALY-TRIGGERS.sql` Tests 5-8 in PostgreSQL.

```sql
-- Test 5: Off-Hours Access
-- Test 6: Privilege Escalation
-- Test 7: Cross-Schema Reconnaissance  
-- Test 8: Deep Schema Enumeration
```

---

## Tuning Thresholds

| Anomaly | Current | Lower = More Alerts | Higher = Fewer Alerts |
|---|---|---|---|
| Privilege Escalation | >3 ops | >2 | >5 |
| Cross-Schema | >4 schemas | >3 | >6 |
| Schema Enum | >10 queries | >5 | >15 |
| ML Deviation | score >1.5 | >1.0 | >2.0 |

---

## ML Setup Requirements

Run `queries/ANOMALY-DETECTION-SETUP.kql` to create:
- `postgres_activity_metrics` table with HourOfDay, DayOfWeek dimensions
- Update policy for continuous aggregation
- Historical data backfill (30 days recommended)

---

**Version**: 3.0  
**Last Updated**: 2026-01-12

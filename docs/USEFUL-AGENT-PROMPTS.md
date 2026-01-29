# Useful Prompts for Data Agent

This file contains the 5 primary prompts aligned with Data Source Example Queries for security threat detection and anomaly analysis.

---

## 🔐 Security & Anomaly Detection Prompts

1. **"Show brute force login attempts"**
   - Multiple failed login attempts from same IP or user
   - Alert if more than 5 failures in a row

2. **"Show data exfiltration attempts"**
   - Which users are downloading or copying a lot of data
   - Alert if unusual query patterns detected

3. **"Show privilege changes"**
   - Who got new permissions or admin access
   - Alert if changes during after-hours

4. **"Show error spikes"**
   - What errors happened recently
   - Alert if more than normal error activity

5. **"Show unusual database activity"**
   - Find activity that doesn't match normal patterns
   - Alert if significant changes detected

---

## 📝 Additional Prompts

6. **"What's happening right now on the database?"**
   - Quick summary of current activity

7. **"Who's connected to the database today?"**
   - List of active users

8. **"What errors are we seeing?"**
   - Simple error summary

9. **"Show me users accessing many different areas"**
   - Potential reconnaissance patterns

10. **"Show late night database changes"**
    - Schema changes outside business hours


# Swarm Tests

Test sequence:
- Start old Postgres stack
- Fill sample data
- Shutdown old Postgres
- Upgrade volume
- Start new Postgres stack
- Check if sample data exists
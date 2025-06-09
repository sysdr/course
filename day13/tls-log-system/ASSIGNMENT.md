# Healthcare TLS Log System Assignment

## Scenario
You're building a telemedicine platform that processes patient consultation logs. These logs contain sensitive medical information and must be encrypted during transmission for HIPAA compliance.

## Requirements

### Core Features
1. **Patient ID Anonymization**: Hash patient IDs before transmission
2. **Log Rotation**: Create new log files every 10 entries  
3. **Connection Retry Logic**: Implement exponential backoff for failed connections
4. **Web Dashboard**: Display transmission statistics on port 8080

### Technical Specifications
- Use TLS 1.2+ for encryption
- Implement GZIP compression
- Support batch log processing
- Include Docker deployment
- Add comprehensive error handling

## Deliverables

1. **Enhanced Client** (`healthcare_client.py`)
   - Patient ID anonymization
   - Retry logic with exponential backoff
   - Batch processing for 50+ patient logs
   
2. **Enhanced Server** (`healthcare_server.py`)  
   - Log rotation every 10 entries
   - HIPAA compliance logging
   - Enhanced security headers
   
3. **Web Dashboard** (`healthcare_dashboard.py`)
   - Real-time transmission statistics
   - Patient log anonymization verification
   - Compliance reporting dashboard
   
4. **Docker Setup**
   - Multi-container deployment
   - Health checks for all services
   - Volume mounting for persistent logs
   
5. **Test Suite**
   - 50 simulated patient consultation logs
   - Anonymization verification tests
   - Connection failure simulation
   - Load testing with concurrent clients

## Acceptance Criteria

- [ ] All patient IDs are anonymized using SHA-256 hashing
- [ ] New log files created every 10 entries
- [ ] Failed connections retry with exponential backoff (1s, 2s, 4s)
- [ ] Web dashboard shows real-time statistics on port 8080
- [ ] Docker containers start successfully with `docker-compose up`
- [ ] All tests pass with `python tests/run_tests.py`
- [ ] HIPAA compliance verified through audit logs

## Testing Instructions

```bash
# Build and start system
./scripts/build.sh
./scripts/run_docker.sh

# Run healthcare simulation
docker-compose exec tls-log-client python src/tls_log_client.py healthcare

# Verify dashboard
curl http://localhost:8080/api/stats

# Run full test suite
./scripts/test.sh
```

## Bonus Challenges

1. **Advanced Anonymization**: Implement format-preserving encryption
2. **Audit Trail**: Add tamper-proof audit logging
3. **Performance Monitoring**: Add Prometheus metrics
4. **Certificate Rotation**: Implement automatic certificate renewal
5. **Multi-Region Setup**: Configure cross-region log replication

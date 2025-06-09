#!/bin/bash

echo "🎬 Day 20: Compatibility Layer Live Demo"
echo "======================================="

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ Please run build.sh first to set up the environment"
    exit 1
fi

echo ""
echo "🔍 Demo 1: Format Detection Engine"
echo "=================================="
python3 -c "
from src.detectors.format_detector import FormatDetector

print('Testing our intelligent format detection...')
detector = FormatDetector()

test_samples = [
    '<34>Oct 11 22:14:15 webserver nginx: 404 error for /missing.html',
    '__REALTIME_TIMESTAMP=1697058855123456\nMESSAGE=User login successful\nPRIORITY=6\n_PID=1234',
    '{\"timestamp\": \"2023-10-11T22:14:17Z\", \"level\": \"ERROR\", \"message\": \"Database timeout\"}',
    'Invalid log entry that does not match any format'
]

for i, sample in enumerate(test_samples, 1):
    result = detector.detect_format(sample)
    print(f'{i}. Format: {result[\"format\"]:>8} | Confidence: {result[\"confidence\"]:>5.1%} | Sample: {sample[:40]}...')
"

echo ""
echo "🔄 Demo 2: Syslog Transformation Pipeline" 
echo "========================================="
python3 -c "
from src.adapters.syslog_adapter import SyslogAdapter
from src.validators.schema_validator import SchemaValidator
from src.formatters.unified_formatter import UnifiedFormatter

print('Processing syslog entries through the complete pipeline...')

# Initialize components
syslog_adapter = SyslogAdapter()
validator = SchemaValidator()
formatter = UnifiedFormatter()

# Sample syslog entries with different priorities
syslog_entries = [
    '<34>Oct 11 22:14:15 mailserver postfix: authentication failed',
    '<85>Oct 11 22:14:16 webserver nginx: GET /api/users HTTP/1.1 200', 
    '<13>Oct 11 22:14:17 authserver sshd: invalid user admin from 192.168.1.100'
]

for entry in syslog_entries:
    # Parse syslog
    parsed = syslog_adapter.parse(entry)
    
    # Validate schema
    validation = validator.validate(parsed)
    
    # Format output
    if validation['valid']:
        formatted = formatter.format_entry(validation['entry'], 'structured')
        print(f'✅ {formatted}')
    else:
        print(f'❌ Validation failed: {validation[\"errors\"]}')
"

echo ""
echo "📖 Demo 3: Journald Processing"
echo "=============================="
python3 -c "
from src.adapters.journald_adapter import JournaldAdapter
from src.validators.schema_validator import SchemaValidator
from src.formatters.unified_formatter import UnifiedFormatter

print('Processing journald entries...')

adapter = JournaldAdapter()
validator = SchemaValidator()
formatter = UnifiedFormatter()

# Simulated journald export format
journald_data = '''__REALTIME_TIMESTAMP=1697058855123456
MESSAGE=Docker container started successfully
PRIORITY=6
_PID=2456
_UID=0
_GID=0
_COMM=dockerd
_EXE=/usr/bin/dockerd
_HOSTNAME=container-host

__REALTIME_TIMESTAMP=1697058856789012
MESSAGE=Memory usage exceeded threshold: 85%
PRIORITY=4
_PID=1
_UID=0
_GID=0
_COMM=systemd
_HOSTNAME=container-host'''

entries = adapter.parse_journal_export(journald_data)
print(f'Parsed {len(entries)} journald entries:')

for entry in entries:
    validation = validator.validate(entry)
    if validation['valid']:
        formatted = formatter.format_entry(validation['entry'], 'simple')
        print(f'  • {formatted}')
"

echo ""
echo "🔀 Demo 4: Mixed Format Processing"
echo "=================================="
python3 -c "
from src.compatibility_processor import CompatibilityProcessor

print('Processing mixed log formats in a single stream...')

processor = CompatibilityProcessor()

mixed_logs = [
    '<34>Oct 11 22:14:15 server1 su: authentication failed for user bob',
    '__REALTIME_TIMESTAMP=1697058856123456\nMESSAGE=Nginx service reloaded\nPRIORITY=6\n_PID=1234',
    '{\"timestamp\": \"2023-10-11T22:14:17Z\", \"level\": \"ERROR\", \"message\": \"API rate limit exceeded\", \"client\": \"192.168.1.50\"}',
    '<85>Oct 11 22:14:18 server1 cron[5678]: backup job completed successfully',
    '__REALTIME_TIMESTAMP=1697058859234567\nMESSAGE=User session timeout\nPRIORITY=5\n_PID=9012'
]

print(f'Input: {len(mixed_logs)} log entries from different sources')
print()

results = processor.process_log_stream(mixed_logs, 'structured')

# Show detection summary
detection = results['detection_summary']
print('Format Detection Results:')
for fmt, count in detection['format_distribution'].items():
    percentage = (count / detection['total_lines']) * 100
    print(f'  {fmt:>8}: {count:>3} entries ({percentage:>5.1f}%)')

print()

# Show processing summary
summary = results['processing_summary']
print(f'Processing Results:')
print(f'  Total input:     {summary[\"total_input_lines\"]}')
print(f'  Successfully parsed: {summary[\"successfully_parsed\"]}')
print(f'  Validation passed:   {summary[\"validation_passed\"]}')
print(f'  Success rate:    {summary[\"success_rate\"]*100:.1f}%')
print(f'  Processing time: {summary[\"processing_time_seconds\"]:.3f}s')
print(f'  Throughput:      {summary[\"throughput_logs_per_second\"]:.1f} logs/sec')

print()
print('Sample Unified Output:')
for i, output in enumerate(results['formatted_output'][:3], 1):
    print(f'  {i}. {output}')
"

echo ""
echo "📊 Demo 5: Performance Benchmarking"
echo "==================================="
python3 -c "
from src.compatibility_processor import CompatibilityProcessor
import time

print('Running performance benchmark...')

processor = CompatibilityProcessor()

# Generate larger test dataset
test_logs = []
formats = [
    '<34>Oct 11 22:14:15 server{} auth: login attempt {}',
    '__REALTIME_TIMESTAMP=169705885512345{}\nMESSAGE=Process {} started\nPRIORITY=6\n_PID={}',
    '{{\"timestamp\": \"2023-10-11T22:14:{}Z\", \"level\": \"INFO\", \"message\": \"Request {} processed\"}}'
]

for i in range(500):
    fmt_idx = i % 3
    if fmt_idx == 0:
        log = formats[fmt_idx].format(i % 10, i)
    elif fmt_idx == 1:
        log = formats[fmt_idx].format(i % 10, i, i % 1000)
    else:
        log = formats[fmt_idx].format(str(i % 60).zfill(2), i)
    test_logs.append(log)

print(f'Generated {len(test_logs)} test log entries')

# Benchmark processing
start_time = time.time()
results = processor.process_log_stream(test_logs)
end_time = time.time()

total_time = end_time - start_time
throughput = len(test_logs) / total_time

print(f'Benchmark Results:')
print(f'  Total logs:      {len(test_logs)}')
print(f'  Processing time: {total_time:.3f} seconds')
print(f'  Throughput:      {throughput:.1f} logs/second')
print(f'  Memory efficient: Processing {len(test_logs)} logs')

# Performance rating
if throughput > 200:
    rating = '🚀 Excellent'
elif throughput > 100:
    rating = '✅ Good'
elif throughput > 50:
    rating = '👍 Acceptable'
else:
    rating = '⚠️ Needs optimization'

print(f'  Performance:     {rating}')
"

echo ""
echo "📁 Demo 6: File Processing"
echo "=========================="
if [ -f "logs/samples/mixed_format.log" ]; then
    python3 -c "
from src.compatibility_processor import CompatibilityProcessor

print('Processing sample log file...')

processor = CompatibilityProcessor()

# Process the mixed format sample file
results = processor.process_file(
    'logs/samples/mixed_format.log',
    'logs/output/demo_output.json',
    'json'
)

if 'error' not in results:
    summary = results['processing_summary']
    print(f'File processing completed:')
    print(f'  Input file:      logs/samples/mixed_format.log')
    print(f'  Output file:     logs/output/demo_output.json')
    print(f'  Lines processed: {summary[\"total_input_lines\"]}')
    print(f'  Success rate:    {summary[\"success_rate\"]*100:.1f}%')
    print(f'  Processing time: {summary[\"processing_time_seconds\"]:.3f}s')
    
    # Show a few output lines
    try:
        with open('logs/output/demo_output.json', 'r') as f:
            lines = f.readlines()[:3]
        print(f'  Sample output (first 3 lines):')
        for i, line in enumerate(lines, 1):
            print(f'    {i}. {line.strip()[:80]}...')
    except:
        pass
else:
    print(f'❌ File processing failed: {results[\"error\"]}')
"
else
    echo "⚠️ Sample file not found, skipping file processing demo"
fi

echo ""
echo "🎉 Demo Complete!"
echo ""
echo "💡 Key Takeaways:"
echo "   • Universal format detection with high accuracy"
echo "   • Seamless translation between syslog, journald, and JSON"
echo "   • Robust schema validation ensures data quality"
echo "   • High-performance processing (>100 logs/second)"
echo "   • Production-ready error handling and monitoring"
echo ""
echo "🌐 Next Steps:"
echo "   • Open ui/compatibility_viewer.html for web interface"
echo "   • Test with your own log files"
echo "   • Integrate with your existing log pipeline"
echo "   • Scale to handle millions of logs per day"

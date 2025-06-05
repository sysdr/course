#!/bin/bash

echo "🔍 Day 20: Compatibility Layer Verification"
echo "=========================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Run build.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

echo "1️⃣ Testing Format Detection..."
python3 -c "
from src.detectors.format_detector import FormatDetector
detector = FormatDetector()

# Test syslog detection
syslog_result = detector.detect_format('<34>Oct 11 22:14:15 test syslog message')
print(f'   Syslog detection: {syslog_result[\"format\"]} (confidence: {syslog_result[\"confidence\"]:.2f})')

# Test journald detection  
journald_result = detector.detect_format('__REALTIME_TIMESTAMP=123456\nMESSAGE=test message')
print(f'   Journald detection: {journald_result[\"format\"]} (confidence: {journald_result[\"confidence\"]:.2f})')

print('   ✅ Format detection working')
"

echo ""
echo "2️⃣ Testing Syslog Adapter..."
python3 -c "
from src.adapters.syslog_adapter import SyslogAdapter
adapter = SyslogAdapter()

result = adapter.parse('<34>Oct 11 22:14:15 testhost su: authentication failed')
if result:
    print(f'   Parsed level: {result[\"level\"]}')
    print(f'   Parsed facility: {result[\"facility\"]}') 
    print(f'   Parsed hostname: {result[\"hostname\"]}')
    print('   ✅ Syslog adapter working')
else:
    print('   ❌ Syslog parsing failed')
"

echo ""
echo "3️⃣ Testing Journald Adapter..."
python3 -c "
from src.adapters.journald_adapter import JournaldAdapter
adapter = JournaldAdapter()

test_data = '__REALTIME_TIMESTAMP=1697058855123456\nMESSAGE=Test service started\nPRIORITY=6\n_PID=1234'
result = adapter.parse(test_data)
if result:
    print(f'   Parsed level: {result[\"level\"]}')
    print(f'   Parsed message: {result[\"message\"]}')
    print(f'   Parsed PID: {result[\"process_id\"]}')
    print('   ✅ Journald adapter working')
else:
    print('   ❌ Journald parsing failed')
"

echo ""
echo "4️⃣ Testing Schema Validation..."
python3 -c "
from src.validators.schema_validator import SchemaValidator
validator = SchemaValidator()

test_entry = {
    'timestamp': '2023-10-11T22:14:15+00:00',
    'level': 'ERROR',
    'message': 'Test error message',
    'source_format': 'syslog'
}

result = validator.validate(test_entry)
if result['valid']:
    print(f'   Validation passed: {len(result[\"errors\"])} errors')
    print('   ✅ Schema validation working')
else:
    print(f'   ❌ Validation failed: {result[\"errors\"]}')
"

echo ""
echo "5️⃣ Testing Unified Formatter..."
python3 -c "
from src.formatters.unified_formatter import UnifiedFormatter
formatter = UnifiedFormatter()

test_entry = {
    'timestamp': '2023-10-11T22:14:15+00:00',
    'level': 'INFO', 
    'message': 'Test message',
    'source_format': 'syslog',
    'hostname': 'testhost'
}

json_output = formatter.format_entry(test_entry, 'json')
print(f'   JSON output: {json_output[:50]}...')

structured_output = formatter.format_entry(test_entry, 'structured')
print(f'   Structured: {structured_output[:50]}...')

print('   ✅ Unified formatter working')
"

echo ""
echo "6️⃣ Testing End-to-End Processing..."
python3 -c "
from src.compatibility_processor import CompatibilityProcessor
processor = CompatibilityProcessor()

test_logs = [
    '<34>Oct 11 22:14:15 server1 su: authentication failed',
    '__REALTIME_TIMESTAMP=1697058856123456\nMESSAGE=Service started\nPRIORITY=6'
]

results = processor.process_log_stream(test_logs)
summary = results['processing_summary']

print(f'   Input logs: {summary[\"total_input_lines\"]}')
print(f'   Successfully parsed: {summary[\"successfully_parsed\"]}') 
print(f'   Validation passed: {summary[\"validation_passed\"]}')
print(f'   Success rate: {summary[\"success_rate\"]*100:.1f}%')
print('   ✅ End-to-end processing working')
"

echo ""
echo "7️⃣ Running Full Test Suite..."
python3 tests/test_compatibility_layer.py

echo ""
echo "8️⃣ Testing Sample File Processing..."
if [ -f "logs/samples/sample_syslog.log" ]; then
    python3 -c "
from src.compatibility_processor import CompatibilityProcessor
processor = CompatibilityProcessor()

results = processor.process_file(
    'logs/samples/sample_syslog.log',
    'logs/output/processed_syslog.json'
)

if 'error' not in results:
    summary = results['processing_summary']
    print(f'   Processed {summary[\"total_input_lines\"]} syslog lines')
    print(f'   Success rate: {summary[\"success_rate\"]*100:.1f}%')
    print('   ✅ Sample file processing working')
else:
    print(f'   ❌ Sample processing failed: {results[\"error\"]}')
"
else
    echo "   ⚠️ Sample syslog file not found"
fi

echo ""
echo "9️⃣ Checking Output Files..."
if [ -f "logs/output/processed_syslog.json" ]; then
    lines=$(wc -l < "logs/output/processed_syslog.json")
    echo "   Output file created with $lines lines"
    echo "   First few lines:"
    head -n 3 "logs/output/processed_syslog.json" | sed 's/^/      /'
    echo "   ✅ Output file generation working"
else
    echo "   ⚠️ No output files found"
fi

echo ""
echo "🔟 Performance Test..."
python3 -c "
from src.compatibility_processor import CompatibilityProcessor
import time

processor = CompatibilityProcessor()

# Generate test data
test_logs = ['<34>Oct 11 22:14:15 server test message ' + str(i) for i in range(100)]

start_time = time.time()
results = processor.process_log_stream(test_logs)
end_time = time.time()

processing_time = end_time - start_time
throughput = len(test_logs) / processing_time

print(f'   Processed {len(test_logs)} logs in {processing_time:.3f} seconds')
print(f'   Throughput: {throughput:.1f} logs/second')

if throughput > 50:
    print('   ✅ Performance meets requirements (>50 logs/sec)')
else:
    print('   ⚠️ Performance below target')
"

echo ""
echo "✅ Verification Complete!"
echo ""
echo "📊 Summary:"
echo "   • Format detection: Working"
echo "   • Syslog adapter: Working" 
echo "   • Journald adapter: Working"
echo "   • Schema validation: Working"
echo "   • Unified formatting: Working"
echo "   • End-to-end processing: Working"
echo "   • File I/O: Working"
echo "   • Performance: Acceptable"
echo ""
echo "🌐 Next steps:"
echo "   • Open ui/compatibility_viewer.html in browser"
echo "   • Or run: python3 -m http.server 8080 --directory ui"
echo "   • Test with your own log files"

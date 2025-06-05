"""
Main Compatibility Layer Processor
Orchestrates the entire log processing pipeline
"""

import time
import traceback
from typing import Dict, Any, List, Optional
from datetime import datetime

from detectors.format_detector import FormatDetector
from adapters.syslog_adapter import SyslogAdapter
from adapters.journald_adapter import JournaldAdapter
from validators.schema_validator import SchemaValidator
from formatters.unified_formatter import UnifiedFormatter
from config.compatibility_config import config

class CompatibilityProcessor:
    """Main processor that orchestrates the compatibility layer pipeline"""
    
    def __init__(self):
        # Initialize all components
        self.detector = FormatDetector()
        self.syslog_adapter = SyslogAdapter()
        self.journald_adapter = JournaldAdapter()
        self.validator = SchemaValidator()
        self.formatter = UnifiedFormatter()
        
        # Performance tracking
        self.stats = {
            'total_processed': 0,
            'format_counts': {},
            'error_counts': {},
            'start_time': None
        }
    
    def process_log_stream(self, log_lines: List[str], 
                          output_format: str = 'json') -> Dict[str, Any]:
        """
        Process a stream of log lines through the complete pipeline
        
        Args:
            log_lines: List of raw log lines
            output_format: Desired output format
            
        Returns:
            Complete processing results with summary
        """
        start_time = time.time()
        self.stats['start_time'] = start_time
        
        results = {
            'input_logs': log_lines,
            'detection_results': [],
            'parsing_results': [],
            'validation_results': [],
            'formatted_output': [],
            'errors': []
        }
        
        try:
            # Step 1: Format Detection
            print("🔍 Step 1: Detecting log formats...")
            detection_summary = self.detector.batch_detect(log_lines)
            results['detection_summary'] = detection_summary
            
            # Step 2: Parse logs by format
            print("📝 Step 2: Parsing logs by format...")
            parsed_logs = []
            
            for i, log_line in enumerate(log_lines):
                try:
                    detection = detection_summary['individual_results'][i]
                    format_type = detection['format']
                    
                    if format_type == 'syslog':
                        parsed = self.syslog_adapter.parse(log_line)
                    elif format_type == 'journald':
                        parsed = self.journald_adapter.parse(log_line)
                    else:
                        # Try to parse as syslog by default for unknown formats
                        parsed = self.syslog_adapter.parse(log_line)
                        if parsed:
                            parsed['source_format'] = 'syslog_fallback'
                    
                    if parsed:
                        parsed_logs.append(parsed)
                        results['parsing_results'].append({
                            'line_index': i,
                            'success': True,
                            'format': format_type,
                            'parsed_data': parsed
                        })
                    else:
                        error_msg = f"Failed to parse line {i}: {log_line[:100]}"
                        results['errors'].append(error_msg)
                        results['parsing_results'].append({
                            'line_index': i,
                            'success': False,
                            'error': error_msg
                        })
                        
                except Exception as e:
                    error_msg = f"Exception parsing line {i}: {str(e)}"
                    results['errors'].append(error_msg)
            
            # Step 3: Validate parsed logs
            print("✅ Step 3: Validating against unified schema...")
            validation_results = self.validator.batch_validate(parsed_logs)
            results['validation_summary'] = validation_results
            
            # Step 4: Format output
            print("🎯 Step 4: Formatting unified output...")
            valid_logs = validation_results['valid_logs']
            formatted_output = self.formatter.batch_format(valid_logs, output_format)
            results['formatted_output'] = formatted_output
            
            # Calculate final statistics
            processing_time = time.time() - start_time
            results['processing_summary'] = {
                'total_input_lines': len(log_lines),
                'successfully_parsed': len(parsed_logs),
                'validation_passed': len(valid_logs),
                'final_output_count': len(formatted_output),
                'processing_time_seconds': processing_time,
                'throughput_logs_per_second': len(log_lines) / processing_time if processing_time > 0 else 0,
                'success_rate': len(valid_logs) / len(log_lines) if log_lines else 0,
                'error_count': len(results['errors'])
            }
            
            self._update_stats(results)
            
            print(f"✨ Processing complete! {len(valid_logs)}/{len(log_lines)} logs successfully processed")
            
        except Exception as e:
            error_msg = f"Critical error in processing pipeline: {str(e)}"
            results['errors'].append(error_msg)
            results['critical_error'] = error_msg
            print(f"❌ {error_msg}")
            traceback.print_exc()
        
        return results
    
    def process_file(self, input_filepath: str, output_filepath: str, 
                    output_format: str = 'json') -> Dict[str, Any]:
        """
        Process a log file through the compatibility layer
        
        Args:
            input_filepath: Path to input log file
            output_filepath: Path for output file
            output_format: Output format
            
        Returns:
            Processing results
        """
        try:
            # Read input file
            with open(input_filepath, 'r') as f:
                log_lines = [line.strip() for line in f if line.strip()]
            
            print(f"📁 Processing file: {input_filepath} ({len(log_lines)} lines)")
            
            # Process through pipeline
            results = self.process_log_stream(log_lines, output_format)
            
            # Write output file
            if results.get('formatted_output'):
                with open(output_filepath, 'w') as f:
                    for line in results['formatted_output']:
                        f.write(line + '\n')
                
                print(f"💾 Output written to: {output_filepath}")
            
            return results
            
        except Exception as e:
            error_msg = f"Error processing file {input_filepath}: {str(e)}"
            print(f"❌ {error_msg}")
            return {'error': error_msg, 'success': False}
    
    def _update_stats(self, results: Dict[str, Any]):
        """Update internal statistics"""
        summary = results.get('processing_summary', {})
        
        self.stats['total_processed'] += summary.get('total_input_lines', 0)
        
        # Update format counts
        detection = results.get('detection_summary', {})
        format_dist = detection.get('format_distribution', {})
        for fmt, count in format_dist.items():
            self.stats['format_counts'][fmt] = self.stats['format_counts'].get(fmt, 0) + count
        
        # Update error counts
        self.stats['error_counts']['total'] = self.stats['error_counts'].get('total', 0) + len(results.get('errors', []))
    
    def get_stats(self) -> Dict[str, Any]:
        """Get current processing statistics"""
        current_time = time.time()
        uptime = current_time - self.stats['start_time'] if self.stats['start_time'] else 0
        
        return {
            'uptime_seconds': uptime,
            'total_logs_processed': self.stats['total_processed'],
            'format_distribution': self.stats['format_counts'],
            'error_summary': self.stats['error_counts'],
            'average_throughput': self.stats['total_processed'] / uptime if uptime > 0 else 0
        }

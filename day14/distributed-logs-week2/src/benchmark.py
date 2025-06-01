#!/usr/bin/env python3
import json
import time
import asyncio
import sys
import os
from datetime import datetime

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import psutil
except ImportError:
    print("Warning: psutil not available, system metrics will be skipped")
    psutil = None

from load_generator import LoadGenerator

class BenchmarkSuite:
    def __init__(self):
        self.results = []
        
    async def run_benchmark_scenarios(self):
        scenarios = [
            {"name": "Low Load", "rps": 50, "duration": 10, "workers": 2},
            {"name": "Medium Load", "rps": 200, "duration": 15, "workers": 3},
            {"name": "High Load", "rps": 500, "duration": 20, "workers": 5}
        ]
        
        print("=== DISTRIBUTED LOG SYSTEM BENCHMARK SUITE ===\n")
        
        for i, scenario in enumerate(scenarios):
            print(f"Running {scenario['name']} scenario ({i+1}/{len(scenarios)})...")
            
            # Monitor system resources before test
            cpu_before = psutil.cpu_percent() if psutil else 0
            memory_before = psutil.virtual_memory().percent if psutil else 0
            
            generator = LoadGenerator(
                target_rps=scenario['rps'],
                duration=scenario['duration'],
                num_workers=scenario['workers']
            )
            
            start_time = time.time()
            try:
                result = await generator.run_load_test()
            except Exception as e:
                print(f"Error in scenario {scenario['name']}: {e}")
                continue
            end_time = time.time()
            
            # Monitor system resources after test
            cpu_after = psutil.cpu_percent() if psutil else 0
            memory_after = psutil.virtual_memory().percent if psutil else 0
            
            # Enhance results with system metrics
            result.update({
                'scenario': scenario['name'],
                'cpu_usage_before': cpu_before,
                'cpu_usage_after': cpu_after,
                'memory_usage_before': memory_before,
                'memory_usage_after': memory_after,
                'test_timestamp': datetime.now().isoformat()
            })
            
            self.results.append(result)
            
            print(f"✓ {scenario['name']} completed - {result['actual_rps']:.1f} RPS\n")
            
            # Cool down between tests
            await asyncio.sleep(2)
    
    def generate_report(self):
        if not self.results:
            print("No results to report")
            return None
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"benchmark_report_{timestamp}.json"
        
        # Calculate summary statistics
        valid_results = [r for r in self.results if r.get('actual_rps', 0) > 0]
        
        if valid_results:
            summary = {
                'total_tests': len(self.results),
                'successful_tests': len(valid_results),
                'total_logs_sent': sum(r['logs_sent'] for r in valid_results),
                'average_rps': sum(r['actual_rps'] for r in valid_results) / len(valid_results),
                'max_rps': max(r['actual_rps'] for r in valid_results),
                'average_success_rate': sum(r['success_rate'] for r in valid_results) / len(valid_results),
                'test_timestamp': datetime.now().isoformat()
            }
        else:
            summary = {
                'total_tests': len(self.results),
                'successful_tests': 0,
                'total_logs_sent': 0,
                'average_rps': 0,
                'max_rps': 0,
                'average_success_rate': 0,
                'test_timestamp': datetime.now().isoformat()
            }
        
        report_data = {
            'summary': summary,
            'detailed_results': self.results
        }
        
        # Save detailed report
        try:
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2)
        except Exception as e:
            print(f"Failed to save report: {e}")
            return None
        
        # Print summary
        print("=== BENCHMARK SUMMARY REPORT ===")
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Successful Tests: {summary['successful_tests']}")
        print(f"Total Logs Processed: {summary['total_logs_sent']:,}")
        print(f"Average RPS: {summary['average_rps']:.2f}")
        print(f"Peak RPS: {summary['max_rps']:.2f}")
        print(f"Average Success Rate: {summary['average_success_rate']:.2f}%")
        print(f"\nDetailed report saved: {report_file}")
        
        return report_file

async def main():
    print("Starting benchmark suite...")
    benchmark = BenchmarkSuite()
    
    try:
        await benchmark.run_benchmark_scenarios()
        benchmark.generate_report()
    except KeyboardInterrupt:
        print("Benchmark interrupted.")
    except Exception as e:
        print(f"Benchmark failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
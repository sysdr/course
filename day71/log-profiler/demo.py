#!/usr/bin/env python3
"""
Demonstration script for Log Performance Profiler
Shows the complete profiling and optimization workflow
"""

import asyncio
import time
import json
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, TaskID

from src.profiler.profiler_engine import ProfilerEngine
from src.optimizer.optimization_engine import OptimizationEngine
from src.analyzer.log_analyzer import LogAnalyzer, generate_test_logs
from config.profiler_config import DEFAULT_CONFIG

console = Console()

async def main():
    console.print(Panel.fit(
        "🚀 Log Performance Profiler Demonstration\n"
        "Day 71: Profile and optimize log ingestion pipeline",
        title="254-Day System Design Series",
        style="bold blue"
    ))
    
    # Initialize components
    console.print("\n[bold green]1. Initializing profiler components...[/bold green]")
    profiler = ProfilerEngine(DEFAULT_CONFIG)
    optimizer = OptimizationEngine(DEFAULT_CONFIG)
    analyzer = LogAnalyzer()
    
    # Start profiling
    console.print("\n[bold green]2. Starting performance profiling...[/bold green]")
    profiler.start_profiling()
    
    # Generate and process test data
    console.print("\n[bold green]3. Processing test log data...[/bold green]")
    
    with Progress() as progress:
        task = progress.add_task("Processing logs...", total=1000)
        
        for batch_num in range(10):  # 10 batches of 100 logs each
            test_logs = generate_test_logs(100)
            await analyzer.process_log_batch(test_logs)
            progress.update(task, advance=100)
            await asyncio.sleep(0.1)  # Small delay to see profiling data
    
    # Let profiling collect data
    console.print("\n[bold green]4. Collecting performance metrics...[/bold green]")
    await asyncio.sleep(2)
    
    # Stop profiling and get results
    console.print("\n[bold green]5. Generating performance analysis...[/bold green]")
    metrics_summary = profiler.stop_profiling()
    
    # Display performance metrics
    display_performance_metrics(metrics_summary)
    
    # Generate optimization suggestions
    console.print("\n[bold green]6. Generating optimization recommendations...[/bold green]")
    optimization_report = optimizer.generate_optimization_report(metrics_summary)
    
    # Display optimization suggestions
    display_optimization_suggestions(optimization_report)
    
    # Display analyzer performance
    display_analyzer_stats(analyzer)
    
    console.print(Panel.fit(
        "✅ Demonstration completed successfully!\n"
        "🌐 Access the web dashboard at: http://localhost:8000\n"
        "📊 Run './start.sh' (from the log-profiler directory) to start the interactive dashboard",
        title="Next Steps",
        style="bold green"
    ))

def display_performance_metrics(metrics_summary):
    """Display performance metrics in a formatted table"""
    if not metrics_summary or 'summary' not in metrics_summary:
        console.print("[red]No performance metrics available[/red]")
        return
    
    summary = metrics_summary['summary']
    
    # Create performance metrics table
    table = Table(title="📊 Performance Metrics Summary")
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Value", style="magenta")
    table.add_column("Unit", style="green")
    
    table.add_row("Average CPU Usage", f"{summary.get('avg_cpu_percent', 0):.1f}", "%")
    table.add_row("Average Memory Usage", f"{summary.get('avg_memory_percent', 0):.1f}", "%")
    table.add_row("Peak Memory Usage", f"{summary.get('max_memory_mb', 0):.1f}", "MB")
    table.add_row("Total Samples", str(summary.get('total_samples', 0)), "count")
    table.add_row("Profiling Duration", f"{summary.get('profiling_duration_seconds', 0):.1f}", "seconds")
    
    console.print(table)
    
    # Display function timings if available
    function_timings = metrics_summary.get('function_timings', {})
    if function_timings:
        func_table = Table(title="⚡ Function Performance Analysis")
        func_table.add_column("Function", style="cyan")
        func_table.add_column("Calls", style="yellow")
        func_table.add_column("Avg Time", style="magenta")
        func_table.add_column("Max Time", style="red")
        
        for func_name, stats in function_timings.items():
            func_table.add_row(
                func_name,
                str(stats.get('count', 0)),
                f"{stats.get('avg_time_ms', 0):.2f} ms",
                f"{stats.get('max_time_ms', 0):.2f} ms"
            )
        
        console.print(func_table)

def display_optimization_suggestions(optimization_report):
    """Display optimization suggestions"""
    if not optimization_report or 'categories' not in optimization_report:
        console.print("[red]No optimization suggestions available[/red]")
        return
    
    console.print(Panel.fit(
        f"🎯 Found {optimization_report.get('total_suggestions', 0)} optimization opportunities\n"
        f"🚨 {optimization_report.get('high_priority_count', 0)} high-priority items need immediate attention",
        title="Optimization Analysis",
        style="bold yellow"
    ))
    
    # Display suggestions by category
    for category, suggestions in optimization_report['categories'].items():
        if not suggestions:
            continue
            
        console.print(f"\n[bold]{category.upper()} Optimizations:[/bold]")
        
        for i, suggestion in enumerate(suggestions, 1):
            priority_style = {
                'high': 'bold red',
                'medium': 'bold yellow', 
                'low': 'bold blue'
            }.get(suggestion.priority, 'white')
            
            console.print(f"  {i}. [{priority_style}]{suggestion.priority.upper()}[/{priority_style}]: {suggestion.description}")
            console.print(f"     💡 {suggestion.estimated_improvement}")
            console.print(f"     🔧 Complexity: {suggestion.implementation_complexity}")
            if suggestion.code_example:
                console.print(f"     📝 Code example available")
            console.print()

def display_analyzer_stats(analyzer):
    """Display log analyzer performance statistics"""
    stats = analyzer.get_performance_stats()
    
    if stats.get('status') == 'no_data':
        console.print("[red]No analyzer data available[/red]")
        return
    
    # Create analyzer stats table
    table = Table(title="📈 Log Processing Performance")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="magenta")
    
    table.add_row("Logs Processed", str(stats.get('processed_count', 0)))
    table.add_row("Processing Errors", str(stats.get('error_count', 0)))
    table.add_row("Error Rate", f"{stats.get('error_rate', 0)*100:.2f}%")
    table.add_row("Avg Processing Time", f"{stats.get('avg_processing_time_ms', 0):.2f} ms")
    table.add_row("Max Processing Time", f"{stats.get('max_processing_time_ms', 0):.2f} ms")
    table.add_row("Min Processing Time", f"{stats.get('min_processing_time_ms', 0):.2f} ms")
    
    console.print(table)

if __name__ == "__main__":
    asyncio.run(main())

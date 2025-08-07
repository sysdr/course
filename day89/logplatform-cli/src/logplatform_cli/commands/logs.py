import click
from rich.console import Console
from rich.table import Table
from rich.live import Live
from rich.panel import Panel
import asyncio
import json
import sys
from datetime import datetime, timedelta

from ..utils.api_client import APIClient
from ..utils.auth import get_authenticated_client
from ..formatters.log_formatter import LogFormatter
from ..utils.streaming import LogStreamer

console = Console()

@click.group()
def logs_group():
    """Log management commands"""
    pass

@logs_group.command('search')
@click.option('--query', '-q', help='Search query')
@click.option('--level', type=click.Choice(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']), help='Log level filter')
@click.option('--service', help='Service name filter')
@click.option('--start-time', help='Start time (ISO format)')
@click.option('--end-time', help='End time (ISO format)')
@click.option('--limit', default=100, type=int, help='Maximum number of results')
@click.option('--format', 'output_format', default='table', type=click.Choice(['table', 'json', 'csv']), help='Output format')
@click.pass_context
def search(ctx, query, level, service, start_time, end_time, limit, output_format):
    """Search logs with filters"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        
        # Build search parameters
        params = {
            'limit': limit
        }
        if query:
            params['query'] = query
        if level:
            params['level'] = level
        if service:
            params['service'] = service
        if start_time:
            params['start_time'] = start_time
        if end_time:
            params['end_time'] = end_time
        
        # Execute search
        with console.status("Searching logs..."):
            results = client.search_logs(params)
        
        # Format and display results
        formatter = LogFormatter(output_format)
        formatted_output = formatter.format_logs(results['logs'])
        
        if output_format == 'json':
            click.echo(json.dumps(results, indent=2))
        else:
            console.print(formatted_output)
            
        # Show summary
        total = results.get('total', len(results['logs']))
        console.print(f"\n[dim]Found {total} logs (showing {len(results['logs'])})[/dim]")
        
    except Exception as e:
        console.print(f"[red]Search failed: {e}[/red]")
        raise click.Abort()

@logs_group.command('stream')
@click.option('--query', '-q', help='Filter query for streaming')
@click.option('--level', type=click.Choice(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']), help='Log level filter')
@click.option('--service', help='Service name filter')
@click.option('--follow', '-f', is_flag=True, default=True, help='Follow log stream')
@click.pass_context
def stream(ctx, query, level, service, follow):
    """Stream logs in real-time"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        
        # Build stream parameters
        params = {}
        if query:
            params['query'] = query
        if level:
            params['level'] = level
        if service:
            params['service'] = service
        
        console.print(Panel(
            f"[green]Streaming logs[/green]\n"
            f"Query: {query or 'All logs'}\n"
            f"Level: {level or 'All levels'}\n"
            f"Service: {service or 'All services'}\n"
            f"Press Ctrl+C to stop",
            title="Log Stream"
        ))
        
        # Start streaming
        streamer = LogStreamer(client, console)
        asyncio.run(streamer.stream_logs(params, follow))
        
    except KeyboardInterrupt:
        console.print("\n[yellow]Streaming stopped[/yellow]")
    except Exception as e:
        console.print(f"[red]Streaming failed: {e}[/red]")
        raise click.Abort()

@logs_group.command('export')
@click.option('--query', '-q', help='Search query for export')
@click.option('--start-time', help='Start time (ISO format)')
@click.option('--end-time', help='End time (ISO format)')
@click.option('--format', 'export_format', default='json', type=click.Choice(['json', 'csv']), help='Export format')
@click.option('--output', '-o', help='Output file (default: stdout)')
@click.pass_context
def export(ctx, query, start_time, end_time, export_format, output):
    """Export logs to file"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        
        params = {}
        if query:
            params['query'] = query
        if start_time:
            params['start_time'] = start_time
        if end_time:
            params['end_time'] = end_time
        
        with console.status("Exporting logs..."):
            export_data = client.export_logs(params, export_format)
        
        if output:
            with open(output, 'w') as f:
                f.write(export_data)
            console.print(f"[green]Logs exported to {output}[/green]")
        else:
            click.echo(export_data)
            
    except Exception as e:
        console.print(f"[red]Export failed: {e}[/red]")
        raise click.Abort()

@logs_group.command('tail')
@click.argument('service_name')
@click.option('--lines', '-n', default=10, type=int, help='Number of recent lines to show')
@click.option('--follow', '-f', is_flag=True, help='Follow the logs')
@click.pass_context
def tail(ctx, service_name, lines, follow):
    """Show recent logs for a service (like tail -f)"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        
        # Get recent logs first
        params = {
            'service': service_name,
            'limit': lines
        }
        
        results = client.search_logs(params)
        
        # Display recent logs
        formatter = LogFormatter('table')
        if results['logs']:
            console.print(formatter.format_logs(results['logs']))
        
        # Follow if requested
        if follow:
            console.print(f"\n[dim]==> Following logs for {service_name} <==\n[/dim]")
            streamer = LogStreamer(client, console)
            asyncio.run(streamer.stream_logs({'service': service_name}, True))
            
    except KeyboardInterrupt:
        console.print("\n[yellow]Tailing stopped[/yellow]")
    except Exception as e:
        console.print(f"[red]Tail failed: {e}[/red]")
        raise click.Abort()

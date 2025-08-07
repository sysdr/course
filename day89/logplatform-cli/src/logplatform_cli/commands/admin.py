import click
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress

from ..utils.auth import get_authenticated_client

console = Console()

@click.group()
def admin_group():
    """Administrative commands"""
    pass

@admin_group.command('health')
@click.pass_context
def health_check(ctx):
    """Check platform health status"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        health_data = client.get_health_status()
        
        # Create health status table
        table = Table(title="Platform Health Status")
        table.add_column("Component", style="cyan")
        table.add_column("Status", style="white")
        table.add_column("Details", style="dim")
        
        overall_healthy = True
        
        for component, info in health_data.items():
            if isinstance(info, dict):
                status = info.get('status', 'unknown')
                details = info.get('details', '')
                
                if status == 'healthy':
                    status_display = "[green]Healthy[/green]"
                elif status == 'degraded':
                    status_display = "[yellow]Degraded[/yellow]"
                    overall_healthy = False
                else:
                    status_display = "[red]Unhealthy[/red]"
                    overall_healthy = False
                
                table.add_row(component.title(), status_display, details)
        
        console.print(table)
        
        # Overall status
        overall_status = "[green]All systems operational[/green]" if overall_healthy else "[red]Some issues detected[/red]"
        console.print(f"\nOverall Status: {overall_status}")
        
    except Exception as e:
        console.print(f"[red]Health check failed: {e}[/red]")
        raise click.Abort()

@admin_group.command('stats')
@click.pass_context
def platform_stats(ctx):
    """Show platform statistics"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        stats = client.get_platform_stats()
        
        console.print(Panel(
            f"[cyan]Total Logs:[/cyan] {stats.get('total_logs', 'N/A'):,}\n"
            f"[cyan]Logs Today:[/cyan] {stats.get('logs_today', 'N/A'):,}\n"
            f"[cyan]Active Services:[/cyan] {stats.get('active_services', 'N/A')}\n"
            f"[cyan]Storage Used:[/cyan] {stats.get('storage_used', 'N/A')}\n"
            f"[cyan]Active Alerts:[/cyan] {stats.get('active_alerts', 'N/A')}",
            title="Platform Statistics"
        ))
        
    except Exception as e:
        console.print(f"[red]Failed to get stats: {e}[/red]")
        raise click.Abort()

@admin_group.command('users')
@click.pass_context
def list_users(ctx):
    """List platform users"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        users = client.get_users()
        
        table = Table(title="Platform Users")
        table.add_column("ID", style="cyan")
        table.add_column("Username", style="white")
        table.add_column("Role", style="yellow")
        table.add_column("Last Active", style="dim")
        
        for user in users:
            table.add_row(
                str(user['id']),
                user['username'],
                user.get('role', 'user'),
                user.get('last_active', 'Never')
            )
        
        console.print(table)
        
    except Exception as e:
        console.print(f"[red]Failed to list users: {e}[/red]")
        raise click.Abort()

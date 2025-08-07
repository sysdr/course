import click
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
import json

from ..utils.auth import get_authenticated_client

console = Console()

@click.group()
def alerts_group():
    """Alert management commands"""
    pass

@alerts_group.command('list')
@click.option('--status', type=click.Choice(['active', 'resolved', 'all']), default='all', help='Filter by status')
@click.pass_context
def list_alerts(ctx, status):
    """List alerts"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        alerts = client.get_alerts(status)
        
        if not alerts:
            console.print("[yellow]No alerts found[/yellow]")
            return
        
        table = Table(title=f"Alerts ({status})")
        table.add_column("ID", style="cyan")
        table.add_column("Name", style="white")
        table.add_column("Status", style="yellow")
        table.add_column("Severity", style="red")
        table.add_column("Created", style="dim")
        
        for alert in alerts:
            status_color = "green" if alert['status'] == 'resolved' else "red"
            severity_color = {"high": "red", "medium": "yellow", "low": "green"}.get(alert.get('severity', 'low'), "white")
            
            table.add_row(
                str(alert['id']),
                alert['name'],
                f"[{status_color}]{alert['status']}[/{status_color}]",
                f"[{severity_color}]{alert.get('severity', 'low')}[/{severity_color}]",
                alert.get('created_at', 'Unknown')
            )
        
        console.print(table)
        
    except Exception as e:
        console.print(f"[red]Failed to list alerts: {e}[/red]")
        raise click.Abort()

@alerts_group.command('create')
@click.option('--name', prompt=True, help='Alert name')
@click.option('--query', prompt=True, help='Log query for alert')
@click.option('--threshold', type=int, prompt=True, help='Alert threshold')
@click.option('--severity', type=click.Choice(['low', 'medium', 'high']), default='medium', help='Alert severity')
@click.pass_context
def create_alert(ctx, name, query, threshold, severity):
    """Create a new alert"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        
        alert_data = {
            'name': name,
            'query': query,
            'threshold': threshold,
            'severity': severity
        }
        
        result = client.create_alert(alert_data)
        
        console.print(Panel(
            f"[green]Alert created successfully[/green]\n"
            f"ID: {result['id']}\n"
            f"Name: {name}\n"
            f"Query: {query}\n"
            f"Threshold: {threshold}\n"
            f"Severity: {severity}",
            title="Alert Created"
        ))
        
    except Exception as e:
        console.print(f"[red]Failed to create alert: {e}[/red]")
        raise click.Abort()

@alerts_group.command('delete')
@click.argument('alert_id', type=int)
@click.confirmation_option(prompt='Are you sure you want to delete this alert?')
@click.pass_context
def delete_alert(ctx, alert_id):
    """Delete an alert"""
    try:
        client = get_authenticated_client(ctx.obj['config'])
        client.delete_alert(alert_id)
        console.print(f"[green]Alert {alert_id} deleted successfully[/green]")
        
    except Exception as e:
        console.print(f"[red]Failed to delete alert: {e}[/red]")
        raise click.Abort()

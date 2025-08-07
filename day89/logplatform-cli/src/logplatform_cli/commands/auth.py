import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
import keyring
import requests
import json
from datetime import datetime, timedelta

from ..utils.api_client import APIClient
from ..utils.exceptions import AuthenticationError

console = Console()

@click.group()
def auth_group():
    """Authentication management commands"""
    pass

@auth_group.command('login')
@click.option('--username', prompt=True, help='Username for authentication')
@click.option('--password', prompt=True, hide_input=True, help='Password for authentication')
@click.option('--server', help='Server URL (overrides config)')
@click.pass_context
def login(ctx, username, password, server):
    """Login to the log platform"""
    config = ctx.obj['config']
    
    try:
        # Use server from option or config
        api_url = server or config.get('server_url', 'http://localhost:8000')
        
        # Create API client and authenticate
        client = APIClient(api_url)
        token_data = client.authenticate(username, password)
        
        # Store credentials securely
        keyring.set_password("logplatform-cli", username, token_data['access_token'])
        config.set('username', username)
        config.set('server_url', api_url)
        config.save()
        
        console.print(Panel(
            f"[green]Successfully authenticated as {username}[/green]\n"
            f"Server: {api_url}\n"
            f"Token expires: {token_data.get('expires_at', 'Unknown')}",
            title="Login Successful"
        ))
        
    except AuthenticationError as e:
        console.print(f"[red]Authentication failed: {e}[/red]")
        raise click.Abort()
    except Exception as e:
        console.print(f"[red]Login error: {e}[/red]")
        raise click.Abort()

@auth_group.command('logout')
@click.pass_context
def logout(ctx):
    """Logout from the log platform"""
    config = ctx.obj['config']
    username = config.get('username')
    
    if username:
        keyring.delete_password("logplatform-cli", username)
        config.remove('username')
        config.save()
        console.print("[green]Successfully logged out[/green]")
    else:
        console.print("[yellow]Not currently logged in[/yellow]")

@auth_group.command('status')
@click.pass_context
def status(ctx):
    """Show authentication status"""
    config = ctx.obj['config']
    username = config.get('username')
    server_url = config.get('server_url', 'Not configured')
    
    if username:
        try:
            token = keyring.get_password("logplatform-cli", username)
            status_text = "[green]Authenticated[/green]" if token else "[red]Token expired[/red]"
        except:
            status_text = "[red]No valid token[/red]"
    else:
        status_text = "[yellow]Not logged in[/yellow]"
    
    table = Table(title="Authentication Status")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="white")
    
    table.add_row("Status", status_text)
    table.add_row("Username", username or "None")
    table.add_row("Server", server_url)
    
    console.print(table)

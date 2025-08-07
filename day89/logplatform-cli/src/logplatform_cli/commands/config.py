import click
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

console = Console()

@click.group()
def config_group():
    """Configuration management commands"""
    pass

@config_group.command('get')
@click.argument('key', required=False)
@click.pass_context
def get_config(ctx, key):
    """Get configuration value(s)"""
    config = ctx.obj['config']
    
    if key:
        value = config.get(key)
        if value is not None:
            console.print(f"{key}: {value}")
        else:
            console.print(f"[yellow]Configuration key '{key}' not found[/yellow]")
    else:
        # Show all configuration
        all_config = config.get_all()
        if all_config:
            table = Table(title="Configuration")
            table.add_column("Key", style="cyan")
            table.add_column("Value", style="white")
            
            for k, v in all_config.items():
                # Hide sensitive values
                if 'password' in k.lower() or 'token' in k.lower():
                    v = '[hidden]'
                table.add_row(k, str(v))
            
            console.print(table)
        else:
            console.print("[yellow]No configuration found[/yellow]")

@config_group.command('set')
@click.argument('key')
@click.argument('value')
@click.pass_context
def set_config(ctx, key, value):
    """Set configuration value"""
    config = ctx.obj['config']
    config.set(key, value)
    config.save()
    console.print(f"[green]Set {key} = {value}[/green]")

@config_group.command('unset')
@click.argument('key')
@click.pass_context
def unset_config(ctx, key):
    """Remove configuration value"""
    config = ctx.obj['config']
    if config.get(key) is not None:
        config.remove(key)
        config.save()
        console.print(f"[green]Removed {key}[/green]")
    else:
        console.print(f"[yellow]Configuration key '{key}' not found[/yellow]")

@config_group.command('list-profiles')
@click.pass_context
def list_profiles(ctx):
    """List available configuration profiles"""
    config = ctx.obj['config']
    profiles = config.list_profiles()
    
    table = Table(title="Configuration Profiles")
    table.add_column("Profile", style="cyan")
    table.add_column("Status", style="white")
    
    for profile in profiles:
        status = "[green]Active[/green]" if profile == ctx.obj['profile'] else ""
        table.add_row(profile, status)
    
    console.print(table)

@config_group.command('init')
@click.option('--server-url', prompt=True, help='Log platform server URL')
@click.option('--profile-name', default='default', help='Profile name')
@click.pass_context
def init_config(ctx, server_url, profile_name):
    """Initialize configuration for a new profile"""
    config = ctx.obj['config']
    config.set('server_url', server_url)
    config.save()
    
    console.print(Panel(
        f"[green]Configuration initialized[/green]\n"
        f"Profile: {profile_name}\n"
        f"Server URL: {server_url}\n"
        f"Run 'logplatform auth login' to authenticate",
        title="Setup Complete"
    ))

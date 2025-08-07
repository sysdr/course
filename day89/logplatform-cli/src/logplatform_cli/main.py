#!/usr/bin/env python3
"""
LogPlatform CLI - Command line interface for distributed log processing platform
"""

import click
import sys
import os
from rich.console import Console
from rich.panel import Panel

from .commands.auth import auth_group
from .commands.logs import logs_group
from .commands.config import config_group
from .commands.alerts import alerts_group
from .commands.admin import admin_group
from .config.manager import ConfigManager
from .utils.exceptions import LogPlatformCLIError

console = Console()

@click.group()
@click.version_option(version="1.0.0")
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose output')
@click.option('--profile', default='default', help='Configuration profile to use')
@click.pass_context
def cli(ctx, verbose, profile):
    """LogPlatform CLI - Manage your distributed log processing platform"""
    ctx.ensure_object(dict)
    ctx.obj['verbose'] = verbose
    ctx.obj['profile'] = profile
    ctx.obj['config'] = ConfigManager(profile)
    
    if verbose:
        click.echo(f"Using profile: {profile}")

# Add command groups
cli.add_command(auth_group, name='auth')
cli.add_command(logs_group, name='logs')
cli.add_command(config_group, name='config')
cli.add_command(alerts_group, name='alerts')
cli.add_command(admin_group, name='admin')

def main():
    """Main entry point for the CLI"""
    try:
        cli()
    except LogPlatformCLIError as e:
        console.print(f"[red]Error: {e}[/red]")
        sys.exit(1)
    except KeyboardInterrupt:
        console.print("\n[yellow]Operation cancelled by user[/yellow]")
        sys.exit(0)
    except Exception as e:
        if os.getenv('LOGPLATFORM_DEBUG'):
            raise
        console.print(f"[red]Unexpected error: {e}[/red]")
        sys.exit(1)

if __name__ == '__main__':
    main()

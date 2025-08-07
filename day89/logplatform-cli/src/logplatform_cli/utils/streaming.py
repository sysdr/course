import asyncio
import json
import websockets
from rich.console import Console
from rich.live import Live
from rich.table import Table
from datetime import datetime
from typing import Dict, Any

from ..formatters.log_formatter import LogFormatter

class LogStreamer:
    """Handle real-time log streaming"""
    
    def __init__(self, api_client, console: Console):
        self.api_client = api_client
        self.console = console
        self.formatter = LogFormatter('table')
        self.logs_buffer = []
        self.max_buffer_size = 100
    
    async def stream_logs(self, params: Dict[str, Any], follow: bool = True):
        """Stream logs via WebSocket"""
        # Convert HTTP URL to WebSocket URL
        ws_url = self.api_client.base_url.replace('http://', 'ws://').replace('https://', 'wss://')
        ws_url += '/logs/stream'
        
        # Add authentication header
        headers = {}
        if self.api_client.token:
            headers['Authorization'] = f'Bearer {self.api_client.token}'
        
        try:
            async with websockets.connect(ws_url, extra_headers=headers) as websocket:
                # Send stream parameters
                await websocket.send(json.dumps(params))
                
                # Create live display for streaming logs
                with Live(self._create_logs_table(), refresh_per_second=2) as live:
                    async for message in websocket:
                        try:
                            log_data = json.loads(message)
                            
                            if log_data.get('type') == 'log':
                                self._add_log_to_buffer(log_data['data'])
                                live.update(self._create_logs_table())
                            elif log_data.get('type') == 'error':
                                self.console.print(f"[red]Stream error: {log_data['message']}[/red]")
                                break
                                
                        except json.JSONDecodeError:
                            continue
                        except KeyboardInterrupt:
                            break
                            
        except ConnectionRefusedError:
            self.console.print("[red]Failed to connect to log stream. Is the server running?[/red]")
        except Exception as e:
            self.console.print(f"[red]Streaming error: {e}[/red]")
    
    def _add_log_to_buffer(self, log_entry: Dict[str, Any]):
        """Add log entry to buffer with size limit"""
        self.logs_buffer.append(log_entry)
        if len(self.logs_buffer) > self.max_buffer_size:
            self.logs_buffer.pop(0)  # Remove oldest log
    
    def _create_logs_table(self) -> Table:
        """Create table for live log display"""
        table = Table(title="Live Logs")
        table.add_column("Time", style="cyan", width=12)
        table.add_column("Level", style="white", width=8)
        table.add_column("Service", style="yellow", width=15)
        table.add_column("Message", style="white", no_wrap=False)
        
        # Show recent logs (last 20)
        recent_logs = self.logs_buffer[-20:] if len(self.logs_buffer) > 20 else self.logs_buffer
        
        for log in recent_logs:
            level = log.get('level', 'INFO')
            level_color = self.formatter._get_level_color(level)
            
            # Format timestamp to show only time
            timestamp = log.get('timestamp', '')
            if timestamp:
                try:
                    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    timestamp = dt.strftime('%H:%M:%S')
                except:
                    timestamp = timestamp[:8]  # Fallback
            
            table.add_row(
                timestamp,
                f"[{level_color}]{level}[/{level_color}]",
                log.get('service', 'unknown')[:15],
                log.get('message', '')[:80]
            )
        
        return table

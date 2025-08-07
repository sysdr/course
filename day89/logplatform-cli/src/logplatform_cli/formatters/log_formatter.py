import json
import csv
from io import StringIO
from rich.table import Table
from rich.console import Console
from rich.text import Text
from typing import List, Dict, Any
from datetime import datetime

class LogFormatter:
    """Format log data for different output types"""
    
    def __init__(self, format_type: str = 'table'):
        self.format_type = format_type
        self.console = Console()
    
    def format_logs(self, logs: List[Dict[str, Any]]) -> Any:
        """Format logs based on output type"""
        if self.format_type == 'json':
            return self._format_json(logs)
        elif self.format_type == 'csv':
            return self._format_csv(logs)
        else:
            return self._format_table(logs)
    
    def _format_json(self, logs: List[Dict[str, Any]]) -> str:
        """Format logs as JSON"""
        return json.dumps(logs, indent=2, default=str)
    
    def _format_csv(self, logs: List[Dict[str, Any]]) -> str:
        """Format logs as CSV"""
        if not logs:
            return ""
        
        output = StringIO()
        writer = csv.DictWriter(output, fieldnames=logs[0].keys())
        writer.writeheader()
        writer.writerows(logs)
        return output.getvalue()
    
    def _format_table(self, logs: List[Dict[str, Any]]) -> Table:
        """Format logs as Rich table"""
        table = Table(title="Logs")
        
        if not logs:
            table.add_column("Message", style="dim")
            table.add_row("No logs found")
            return table
        
        # Add columns
        table.add_column("Timestamp", style="cyan", width=20)
        table.add_column("Level", style="white", width=8)
        table.add_column("Service", style="yellow", width=15)
        table.add_column("Message", style="white", no_wrap=False)
        
        # Add rows
        for log in logs:
            level = log.get('level', 'INFO')
            level_color = self._get_level_color(level)
            
            # Format timestamp
            timestamp = log.get('timestamp', '')
            if timestamp:
                try:
                    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    timestamp = dt.strftime('%Y-%m-%d %H:%M:%S')
                except:
                    pass
            
            table.add_row(
                timestamp,
                f"[{level_color}]{level}[/{level_color}]",
                log.get('service', 'unknown'),
                log.get('message', '')[:100]  # Truncate long messages
            )
        
        return table
    
    def _get_level_color(self, level: str) -> str:
        """Get color for log level"""
        level_colors = {
            'DEBUG': 'dim',
            'INFO': 'blue',
            'WARN': 'yellow',
            'ERROR': 'red',
            'FATAL': 'bright_red'
        }
        return level_colors.get(level.upper(), 'white')

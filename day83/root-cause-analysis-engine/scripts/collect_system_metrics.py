#!/usr/bin/env python3
"""
Enhanced System Metrics Collector
Collects comprehensive system metrics for all dashboard tabs
"""

import asyncio
import aiohttp
import psutil
import json
from datetime import datetime, timedelta
import platform
import subprocess
from typing import Dict, List, Any

class SystemMetricsCollector:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.performance_thresholds = {
            'cpu': {'warning': 70, 'critical': 85},
            'memory': {'warning': 75, 'critical': 90},
            'disk': {'warning': 80, 'critical': 90},
            'network': {'warning': 80, 'critical': 90}
        }

    async def collect_performance_metrics(self) -> Dict[str, Any]:
        """Collect detailed performance metrics"""
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        net_io = psutil.net_io_counters()
        
        return {
            "cpu_utilization": cpu_percent,
            "memory_usage": memory.percent,
            "disk_usage": disk.percent,
            "network": {
                "bytes_sent": net_io.bytes_sent,
                "bytes_recv": net_io.bytes_recv,
                "packets_sent": net_io.packets_sent,
                "packets_recv": net_io.packets_recv,
                "error_in": net_io.errin,
                "error_out": net_io.errout
            }
        }

    async def collect_resource_metrics(self) -> Dict[str, Any]:
        """Collect resource utilization metrics"""
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        disk_io = psutil.disk_io_counters()
        
        return {
            "memory": {
                "total": memory.total,
                "available": memory.available,
                "used": memory.used,
                "free": memory.free,
                "cached": memory.cached if hasattr(memory, 'cached') else 0,
                "buffers": memory.buffers if hasattr(memory, 'buffers') else 0
            },
            "swap": {
                "total": swap.total,
                "used": swap.used,
                "free": swap.free,
                "percent": swap.percent
            },
            "disk_io": {
                "read_bytes": disk_io.read_bytes,
                "write_bytes": disk_io.write_bytes,
                "read_count": disk_io.read_count,
                "write_count": disk_io.write_count
            }
        }

    def get_process_metrics(self) -> List[Dict[str, Any]]:
        """Collect metrics for top processes"""
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'create_time']):
            try:
                pinfo = proc.info
                pinfo['cpu_percent'] = proc.cpu_percent(interval=0.1)
                processes.append(pinfo)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        # Sort by CPU usage and get top 10
        return sorted(processes, key=lambda x: x['cpu_percent'], reverse=True)[:10]

    def generate_alerts(self, perf_metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate alerts based on metrics"""
        alerts = []
        timestamp = datetime.now()

        # CPU Alert
        if perf_metrics['cpu_utilization'] > self.performance_thresholds['cpu']['critical']:
            alerts.append({
                "timestamp": timestamp.isoformat(),
                "level": "ERROR",
                "service": "system-cpu",
                "message": f"Critical CPU usage: {perf_metrics['cpu_utilization']}%",
                "metadata": {"value": perf_metrics['cpu_utilization'], "threshold": self.performance_thresholds['cpu']['critical']}
            })
        elif perf_metrics['cpu_utilization'] > self.performance_thresholds['cpu']['warning']:
            alerts.append({
                "timestamp": timestamp.isoformat(),
                "level": "WARNING",
                "service": "system-cpu",
                "message": f"High CPU usage: {perf_metrics['cpu_utilization']}%",
                "metadata": {"value": perf_metrics['cpu_utilization'], "threshold": self.performance_thresholds['cpu']['warning']}
            })

        # Memory Alert
        if perf_metrics['memory_usage'] > self.performance_thresholds['memory']['critical']:
            alerts.append({
                "timestamp": timestamp.isoformat(),
                "level": "ERROR",
                "service": "system-memory",
                "message": f"Critical memory usage: {perf_metrics['memory_usage']}%",
                "metadata": {"value": perf_metrics['memory_usage'], "threshold": self.performance_thresholds['memory']['critical']}
            })
        elif perf_metrics['memory_usage'] > self.performance_thresholds['memory']['warning']:
            alerts.append({
                "timestamp": timestamp.isoformat(),
                "level": "WARNING",
                "service": "system-memory",
                "message": f"High memory usage: {perf_metrics['memory_usage']}%",
                "metadata": {"value": perf_metrics['memory_usage'], "threshold": self.performance_thresholds['memory']['warning']}
            })

        return alerts

    async def collect_and_send_metrics(self):
        """Collect and send all metrics"""
        try:
            # Collect all metrics
            perf_metrics = await self.collect_performance_metrics()
            resource_metrics = await self.collect_resource_metrics()
            process_metrics = self.get_process_metrics()
            alerts = self.generate_alerts(perf_metrics)

            # Prepare the complete metrics payload
            metrics_payload = {
                "timestamp": datetime.now().isoformat(),
                "performance": perf_metrics,
                "resources": resource_metrics,
                "processes": process_metrics,
                "system_info": {
                    "platform": platform.platform(),
                    "python_version": platform.python_version(),
                    "cpu_count": psutil.cpu_count(),
                    "cpu_freq": psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None
                }
            }

            # Send metrics to the analysis engine
            if alerts:
                async with aiohttp.ClientSession() as session:
                    async with session.post(
                        f"{self.base_url}/api/analyze-incident",
                        json=alerts,
                        headers={"Content-Type": "application/json"}
                    ) as response:
                        if response.status == 200:
                            result = await response.json()
                            print(f"✅ Alerts processed - Incident ID: {result['incident_id']}")
                        else:
                            print(f"❌ Alert processing failed: {response.status}")

            # Send metrics for dashboard updates
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/api/metrics",
                    json=metrics_payload,
                    headers={"Content-Type": "application/json"}
                ) as response:
                    if response.status == 200:
                        print(f"✅ Metrics updated successfully")
                    else:
                        print(f"❌ Metrics update failed: {response.status}")

        except Exception as e:
            print(f"❌ Error collecting/sending metrics: {e}")

async def main():
    collector = SystemMetricsCollector()
    while True:
        print("\n📊 Collecting system metrics...")
        await collector.collect_and_send_metrics()
        await asyncio.sleep(30)  # Update every 30 seconds

if __name__ == "__main__":
    asyncio.run(main())
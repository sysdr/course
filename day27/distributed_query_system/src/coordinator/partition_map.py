import json
import asyncio
from typing import Dict, List, Set
from datetime import datetime, timedelta
import structlog
from ..common.network import NetworkClient, PartitionInfo
from ..common.query_types import TimeRange, Query

logger = structlog.get_logger()

class PartitionMap:
    def __init__(self, config_file: str = "partitions.json"):
        self.partitions: Dict[str, PartitionInfo] = {}
        self.config_file = config_file
        self.network_client = NetworkClient()
        self.health_check_interval = 30  # seconds
        self._health_check_task = None
    
    async def start(self):
        """Initialize partition map and start health checking"""
        await self.network_client.start()
        await self.load_partition_config()
        self._health_check_task = asyncio.create_task(self._health_check_loop())
        logger.info("Partition map started", partition_count=len(self.partitions))
    
    async def stop(self):
        """Stop health checking and cleanup"""
        if self._health_check_task:
            self._health_check_task.cancel()
        await self.network_client.stop()
    
    async def load_partition_config(self):
        """Load partition configuration from file"""
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
            
            for partition_data in config.get("partitions", []):
                partition = PartitionInfo(
                    partition_id=partition_data["partition_id"],
                    host=partition_data["host"],
                    port=partition_data["port"],
                    time_ranges=partition_data.get("time_ranges", [])
                )
                self.partitions[partition.partition_id] = partition
                
        except FileNotFoundError:
            logger.warning("Partition config file not found, starting with empty map")
        except Exception as e:
            logger.error("Failed to load partition config", error=str(e))
    
    def find_relevant_partitions(self, query: Query) -> List[PartitionInfo]:
        """Find partitions that might contain relevant data for the query"""
        relevant = []
        
        for partition in self.partitions.values():
            if not partition.is_healthy():
                continue
                
            # If query has time range, check if partition covers it
            if query.time_range:
                if partition.covers_time_range(
                    query.time_range.start, 
                    query.time_range.end
                ):
                    relevant.append(partition)
            else:
                # No time filter, all healthy partitions are relevant
                relevant.append(partition)
        
        logger.info("Found relevant partitions", 
                   query_id=query.query_id,
                   total_partitions=len(self.partitions),
                   relevant_count=len(relevant))
        
        return relevant
    
    def get_healthy_partitions(self) -> List[PartitionInfo]:
        """Get all currently healthy partitions"""
        return [p for p in self.partitions.values() if p.is_healthy()]
    
    async def _health_check_loop(self):
        """Continuously check partition health"""
        while True:
            try:
                await self._check_all_partitions_health()
                await asyncio.sleep(self.health_check_interval)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("Health check failed", error=str(e))
                await asyncio.sleep(5)  # Brief delay before retry
    
    async def _check_all_partitions_health(self):
        """Check health of all registered partitions"""
        tasks = []
        for partition in self.partitions.values():
            task = asyncio.create_task(self._check_partition_health(partition))
            tasks.append(task)
        
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _check_partition_health(self, partition: PartitionInfo):
        """Check health of a single partition"""
        try:
            health_url = f"{partition.base_url}/health"
            response = await self.network_client.get_json(health_url)
            
            if response.get("status") == "healthy":
                partition.status = "healthy"
            else:
                partition.status = "unhealthy"
                
            partition.last_health_check = datetime.now()
            
        except Exception as e:
            partition.status = "unreachable"
            partition.last_health_check = datetime.now()
            logger.warning("Partition health check failed", 
                         partition_id=partition.partition_id,
                         error=str(e))
    
    def get_partition_stats(self) -> Dict[str, int]:
        """Get statistics about partition health"""
        healthy = sum(1 for p in self.partitions.values() if p.status == "healthy")
        unhealthy = sum(1 for p in self.partitions.values() if p.status == "unhealthy")
        unreachable = sum(1 for p in self.partitions.values() if p.status == "unreachable")
        
        return {
            "total": len(self.partitions),
            "healthy": healthy,
            "unhealthy": unhealthy,
            "unreachable": unreachable
        }

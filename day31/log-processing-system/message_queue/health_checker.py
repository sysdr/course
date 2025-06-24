"""
Health monitoring for RabbitMQ and queue status.
"""
import pika
import requests
import logging
from typing import Dict, Any, List
from message_queue.rabbitmq_setup import RabbitMQSetup

class HealthChecker:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.setup = RabbitMQSetup(config_path)
        self.management_url = "http://localhost:15672/api"
        
    def check_connection(self) -> Dict[str, Any]:
        """Check if RabbitMQ connection is healthy."""
        try:
            if self.setup.connect():
                self.setup.close_connection()
                return {'status': 'healthy', 'message': 'Connection successful'}
            else:
                return {'status': 'unhealthy', 'message': 'Connection failed'}
        except Exception as e:
            return {'status': 'unhealthy', 'message': str(e)}
            
    def check_management_api(self) -> Dict[str, Any]:
        """Check RabbitMQ management API availability."""
        try:
            response = requests.get(
                f"{self.management_url}/overview",
                auth=('guest', 'guest'),
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                return {
                    'status': 'healthy',
                    'version': data.get('rabbitmq_version', 'unknown'),
                    'node': data.get('node', 'unknown')
                }
            else:
                return {'status': 'unhealthy', 'message': f'API returned {response.status_code}'}
                
        except requests.exceptions.RequestException as e:
            return {'status': 'unhealthy', 'message': str(e)}
            
    def check_queues(self) -> List[Dict[str, Any]]:
        """Check status of all configured queues."""
        queue_status = []
        
        try:
            response = requests.get(
                f"{self.management_url}/queues",
                auth=('guest', 'guest'),
                timeout=5
            )
            
            if response.status_code == 200:
                queues = response.json()
                
                configured_queues = self.setup.config['queues']
                for queue_key, queue_config in configured_queues.items():
                    queue_name = queue_config['name']
                    
                    # Find queue in API response
                    queue_data = next((q for q in queues if q['name'] == queue_name), None)
                    
                    if queue_data:
                        queue_status.append({
                            'name': queue_name,
                            'status': 'healthy',
                            'messages': queue_data.get('messages', 0),
                            'consumers': queue_data.get('consumers', 0),
                            'memory': queue_data.get('memory', 0)
                        })
                    else:
                        queue_status.append({
                            'name': queue_name,
                            'status': 'missing',
                            'message': 'Queue not found'
                        })
                        
        except Exception as e:
            logging.error(f"Failed to check queues: {e}")
            
        return queue_status
        
    def generate_health_report(self) -> Dict[str, Any]:
        """Generate comprehensive health report."""
        report = {
            'timestamp': None,
            'connection': self.check_connection(),
            'management_api': self.check_management_api(),
            'queues': self.check_queues()
        }
        
        # Determine overall health
        overall_healthy = (
            report['connection']['status'] == 'healthy' and
            report['management_api']['status'] == 'healthy' and
            all(q['status'] == 'healthy' for q in report['queues'])
        )
        
        report['overall_status'] = 'healthy' if overall_healthy else 'unhealthy'
        
        return report
        
def main():
    """Generate and display health report."""
    checker = HealthChecker()
    report = checker.generate_health_report()
    
    print("🏥 RabbitMQ Health Report")
    print("=" * 40)
    print(f"Overall Status: {'✅' if report['overall_status'] == 'healthy' else '❌'} {report['overall_status'].upper()}")
    print()
    
    print("Connection:", "✅" if report['connection']['status'] == 'healthy' else '❌', report['connection']['message'])
    
    if report['management_api']['status'] == 'healthy':
        print(f"Management API: ✅ Running (Version: {report['management_api']['version']})")
    else:
        print("Management API: ❌", report['management_api']['message'])
        
    print("\nQueues:")
    for queue in report['queues']:
        status_icon = "✅" if queue['status'] == 'healthy' else "❌"
        if queue['status'] == 'healthy':
            print(f"  {status_icon} {queue['name']}: {queue['messages']} messages, {queue['consumers']} consumers")
        else:
            print(f"  {status_icon} {queue['name']}: {queue.get('message', 'Unknown error')}")

if __name__ == "__main__":
    main()

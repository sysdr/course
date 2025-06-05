import os

def get_cluster_config(num_nodes=3, base_port=7001):
    """Generate cluster configuration"""
    config = {
        'cluster_name': 'distributed-log-cluster',
        'replication_factor': 2,
        'nodes': []
    }
    
    for i in range(num_nodes):
        node_id = f"storage_node_{i+1}"
        config['nodes'].append({
            'id': node_id,
            'port': base_port + i,
            'storage_path': os.path.join('logs', f'node{i+1}'),
            'host': 'localhost'
        })
    
    return config

# Default 3-node configuration
DEFAULT_CONFIG = get_cluster_config()

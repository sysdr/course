import pytest
import sys
import os
import socket
import threading
import time
import tempfile
import shutil

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.storage_node import StorageNode
from storage.replication_manager import ReplicationManager


def _free_ports(n=2):
    """Return n free port numbers."""
    ports = []
    for _ in range(n):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', 0))
            ports.append(s.getsockname()[1])
    return ports


class TestReplicationManager:
    def setup_method(self):
        self.temp_dirs = []
        self.nodes = []
        self.ports = _free_ports(2)

        for i, port in enumerate(self.ports):
            d = tempfile.mkdtemp()
            self.temp_dirs.append(d)
            node = StorageNode(f"test_node_{i+1}", port, d)
            self.nodes.append(node)
            t = threading.Thread(target=node.start_server, daemon=True)
            t.start()
            time.sleep(0.5)
        time.sleep(2)

    def teardown_method(self):
        for d in self.temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    def test_replication_manager_creation(self):
        """ReplicationManager can be created with source and targets."""
        source = self.nodes[0]
        targets = [
            {'host': 'localhost', 'port': self.ports[1], 'id': 'test_node_2'}
        ]
        rm = ReplicationManager(source, targets, replication_factor=1)
        assert rm.replication_factor == 1
        assert len(rm.target_nodes) == 1

    def test_async_replication(self):
        """Replication replicates file to target node."""
        source = self.nodes[0]
        targets = [
            {'host': 'localhost', 'port': self.ports[1], 'id': 'test_node_2'}
        ]
        rm = ReplicationManager(source, targets, replication_factor=1)

        file_data = {'message': 'replication test', 'level': 'info'}
        file_path = source.write_log_data(file_data)
        read_back = source.read_log_data(file_path)
        assert read_back is not None

        success = rm.replicate_file_sync(file_path, read_back)
        assert success is True

        target_node = self.nodes[1]
        replicated = target_node.read_log_data(file_path)
        assert replicated is not None
        assert replicated.get('original_data') == file_data

    def test_replication_failure_handling(self):
        """ReplicationManager handles unreachable target gracefully."""
        source = self.nodes[0]
        targets = [
            {'host': 'localhost', 'port': 61999, 'id': 'nonexistent'}
        ]
        rm = ReplicationManager(source, targets, replication_factor=1)
        file_data = {'message': 'test'}
        file_path = source.write_log_data(file_data)
        read_back = source.read_log_data(file_path)

        success = rm.replicate_file_sync(file_path, read_back)
        assert success is False
        assert rm.stats['replications_failed'] >= 1

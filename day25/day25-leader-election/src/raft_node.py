import asyncio
import random
import time
import json
import logging
from enum import Enum
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

class NodeState(Enum):
    FOLLOWER = "follower"
    CANDIDATE = "candidate"
    LEADER = "leader"

@dataclass
class VoteRequest:
    term: int
    candidate_id: str
    last_log_index: int
    last_log_term: int

@dataclass
class VoteResponse:
    term: int
    vote_granted: bool

@dataclass
class AppendEntriesRequest:
    term: int
    leader_id: str
    entries: List[Dict] = None

class RaftNode:
    def __init__(self, node_id: str, peers: List[str], port: int = 8000):
        self.node_id = node_id
        self.peers = peers
        self.port = port
        
        # Persistent state
        self.current_term = 0
        self.voted_for = None
        self.log = []
        
        # Volatile state
        self.commit_index = 0
        self.last_applied = 0
        self.state = NodeState.FOLLOWER
        
        # Leader state
        self.next_index = {}
        self.match_index = {}
        
        # Election state
        self.votes_received = 0
        self.election_timeout = self._generate_election_timeout()
        self.last_heartbeat = time.time()
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(f"RaftNode-{node_id}")
        
        # Running state
        self.running = False
        self.tasks = []

    def _generate_election_timeout(self) -> float:
        """Generate random election timeout between 150-300ms"""
        return random.uniform(0.15, 0.3)

    async def start(self):
        """Start the Raft node"""
        self.running = True
        self.logger.info(f"Starting Raft node {self.node_id} on port {self.port}")
        
        # Start background tasks
        self.tasks = [
            asyncio.create_task(self._election_timeout_loop()),
            asyncio.create_task(self._heartbeat_loop()),
        ]
        
        # Start HTTP server for inter-node communication
        await self._start_server()

    async def stop(self):
        """Stop the Raft node"""
        self.running = False
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)

    async def _election_timeout_loop(self):
        """Monitor election timeout and start elections"""
        while self.running:
            await asyncio.sleep(0.01)  # Check every 10ms
            
            if self.state == NodeState.LEADER:
                continue
                
            time_since_heartbeat = time.time() - self.last_heartbeat
            if time_since_heartbeat > self.election_timeout:
                await self._start_election()

    async def _heartbeat_loop(self):
        """Send heartbeats if leader"""
        while self.running:
            if self.state == NodeState.LEADER:
                await self._send_heartbeats()
            await asyncio.sleep(0.05)  # Send heartbeats every 50ms

    async def _start_election(self):
        """Start a new election"""
        self.logger.info(f"Starting election for term {self.current_term + 1}")
        
        # Become candidate
        self.state = NodeState.CANDIDATE
        self.current_term += 1
        self.voted_for = self.node_id
        self.votes_received = 1  # Vote for self
        self.last_heartbeat = time.time()
        self.election_timeout = self._generate_election_timeout()
        
        # Request votes from peers
        vote_tasks = []
        for peer in self.peers:
            task = asyncio.create_task(self._request_vote(peer))
            vote_tasks.append(task)
        
        # Wait for vote responses
        if vote_tasks:
            await asyncio.gather(*vote_tasks, return_exceptions=True)

    async def _request_vote(self, peer: str):
        """Request vote from a peer"""
        try:
            vote_request = VoteRequest(
                term=self.current_term,
                candidate_id=self.node_id,
                last_log_index=len(self.log) - 1,
                last_log_term=self.log[-1]['term'] if self.log else 0
            )
            
            # Simulate network call (replace with actual HTTP request)
            await asyncio.sleep(random.uniform(0.01, 0.05))
            
            # For demo, randomly grant/deny votes
            vote_granted = random.choice([True, True, False])  # 66% success rate
            
            response = VoteResponse(
                term=self.current_term,
                vote_granted=vote_granted
            )
            
            await self._handle_vote_response(response)
            
        except Exception as e:
            self.logger.error(f"Error requesting vote from {peer}: {e}")

    async def _handle_vote_response(self, response: VoteResponse):
        """Handle vote response"""
        if response.term > self.current_term:
            await self._become_follower(response.term)
            return
        
        if self.state == NodeState.CANDIDATE and response.vote_granted:
            self.votes_received += 1
            self.logger.info(f"Received vote, total: {self.votes_received}/{len(self.peers) + 1}")
            
            # Check if we have majority
            if self.votes_received > (len(self.peers) + 1) // 2:
                await self._become_leader()

    async def _become_leader(self):
        """Become the leader"""
        self.logger.info(f"Became leader for term {self.current_term}")
        self.state = NodeState.LEADER
        
        # Initialize leader state
        for peer in self.peers:
            self.next_index[peer] = len(self.log)
            self.match_index[peer] = 0
        
        # Send immediate heartbeat
        await self._send_heartbeats()

    async def _become_follower(self, term: int):
        """Become follower"""
        self.logger.info(f"Became follower for term {term}")
        self.state = NodeState.FOLLOWER
        self.current_term = term
        self.voted_for = None
        self.last_heartbeat = time.time()

    async def _send_heartbeats(self):
        """Send heartbeats to all followers"""
        if self.state != NodeState.LEADER:
            return
        
        for peer in self.peers:
            asyncio.create_task(self._send_heartbeat(peer))

    async def _send_heartbeat(self, peer: str):
        """Send heartbeat to a specific peer"""
        try:
            request = AppendEntriesRequest(
                term=self.current_term,
                leader_id=self.node_id,
                entries=[]
            )
            
            # Simulate network call
            await asyncio.sleep(random.uniform(0.01, 0.03))
            
        except Exception as e:
            self.logger.error(f"Error sending heartbeat to {peer}: {e}")

    async def _start_server(self):
        """Start HTTP server for inter-node communication"""
        # Placeholder - in real implementation, start FastAPI server
        pass

    def get_status(self) -> Dict:
        """Get node status"""
        return {
            "node_id": self.node_id,
            "state": self.state.value,
            "term": self.current_term,
            "voted_for": self.voted_for,
            "peers": self.peers,
            "votes_received": self.votes_received if self.state == NodeState.CANDIDATE else 0,
            "is_leader": self.state == NodeState.LEADER
        }

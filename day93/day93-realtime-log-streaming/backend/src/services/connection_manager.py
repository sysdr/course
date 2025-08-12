from typing import Dict, Set
from fastapi import WebSocket
import structlog

logger = structlog.get_logger()

class ConnectionManager:
    """Manages WebSocket connections for log streaming"""
    
    def __init__(self):
        # stream_id -> set of websockets
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # websocket -> set of subscribed stream_ids (for multi-stream)
        self.multi_stream_connections: Set[WebSocket] = set()
        
    async def connect(self, websocket: WebSocket, stream_id: str):
        """Connect a websocket to a specific stream"""
        await websocket.accept()
        
        if stream_id not in self.active_connections:
            self.active_connections[stream_id] = set()
        
        self.active_connections[stream_id].add(websocket)
        logger.info("Connection established", 
                   stream_id=stream_id, 
                   total_connections=len(self.active_connections[stream_id]))
        
    def disconnect(self, websocket: WebSocket, stream_id: str):
        """Disconnect a websocket from a specific stream"""
        if stream_id in self.active_connections:
            self.active_connections[stream_id].discard(websocket)
            
            if not self.active_connections[stream_id]:
                del self.active_connections[stream_id]
                
        logger.info("Connection closed", 
                   stream_id=stream_id,
                   remaining_connections=len(self.active_connections.get(stream_id, [])))
    
    async def connect_multi(self, websocket: WebSocket):
        """Connect for multi-stream subscription"""
        await websocket.accept()
        self.multi_stream_connections.add(websocket)
        return websocket
        
    async def disconnect_multi(self, websocket: WebSocket):
        """Disconnect multi-stream client"""
        if websocket in self.multi_stream_connections:
            # Remove from all subscribed streams
            self.multi_stream_connections.discard(websocket)
            
    async def subscribe(self, websocket: WebSocket, stream_id: str):
        """Subscribe websocket to a stream"""
        if websocket in self.multi_stream_connections:
            if stream_id not in self.active_connections:
                self.active_connections[stream_id] = set()
            self.active_connections[stream_id].add(websocket)
            
    async def unsubscribe(self, websocket: WebSocket, stream_id: str):
        """Unsubscribe websocket from a stream"""
        if stream_id in self.active_connections:
            self.active_connections[stream_id].discard(websocket)
            
    async def broadcast_to_stream(self, stream_id: str, message: dict):
        """Broadcast message to all connections of a stream"""
        if stream_id not in self.active_connections:
            return
            
        disconnected = []
        for websocket in self.active_connections[stream_id]:
            try:
                await websocket.send_json(message)
            except Exception:
                disconnected.append(websocket)
                
        # Clean up disconnected websockets
        for websocket in disconnected:
            self.disconnect(websocket, stream_id)

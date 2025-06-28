import asyncio
import random
import time
import httpx
from faker import Faker
from typing import List
import structlog

logger = structlog.get_logger()
fake = Faker()

class EventSimulator:
    """Simulates realistic user events for testing sessionization"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.users = self._generate_users(50)  # 50 simulated users
        self.pages = [
            "/", "/home", "/products", "/about", "/contact",
            "/product/123", "/product/456", "/cart", "/checkout",
            "/profile", "/settings", "/help", "/search"
        ]
        self.event_types = ["page_view", "click", "scroll", "hover", "submit"]
        
    def _generate_users(self, count: int) -> List[str]:
        """Generate list of user IDs"""
        return [f"user_{i:03d}" for i in range(1, count + 1)]
    
    async def simulate_user_session(self, user_id: str, session_length: int = None):
        """Simulate a realistic user session"""
        if session_length is None:
            session_length = random.randint(3, 15)  # 3-15 events per session
            
        device_type = random.choice(["web", "mobile", "tablet"])
        session_start = time.time()
        
        async with httpx.AsyncClient() as client:
            for event_num in range(session_length):
                # Simulate realistic time gaps between events
                if event_num > 0:
                    time_gap = random.exponential(20)  # Average 20 seconds between events
                    await asyncio.sleep(min(time_gap, 120))  # Cap at 2 minutes
                
                # Choose event type and page
                event_type = random.choice(self.event_types)
                page_url = random.choice(self.pages)
                
                # Create realistic browsing patterns
                if event_num == 0:
                    page_url = "/"  # Start at home page
                elif "cart" in page_url and random.random() < 0.7:
                    # If viewing cart, likely to go to checkout
                    page_url = "/checkout"
                elif "product" in page_url and random.random() < 0.3:
                    # If viewing product, might add to cart
                    page_url = "/cart"
                
                event_data = {
                    "user_id": user_id,
                    "event_type": event_type,
                    "timestamp": time.time(),
                    "page_url": page_url,
                    "referrer": "/" if event_num == 0 else self.pages[random.randint(0, len(self.pages)-1)],
                    "device_type": device_type,
                    "metadata": {
                        "user_agent": fake.user_agent(),
                        "ip_address": fake.ipv4(),
                        "session_sequence": event_num + 1
                    }
                }
                
                try:
                    response = await client.post(
                        f"{self.base_url}/api/events",
                        json=event_data,
                        timeout=5.0
                    )
                    
                    if response.status_code == 200:
                        result = response.json()
                        if result.get("success"):
                            logger.info("Event sent", 
                                       user_id=user_id, 
                                       event_type=event_type,
                                       session_id=result.get("session_id"))
                        else:
                            logger.error("Event failed", error=result.get("error"))
                    else:
                        logger.error("HTTP error", status_code=response.status_code)
                        
                except Exception as e:
                    logger.error("Failed to send event", error=str(e), user_id=user_id)
    
    async def run_continuous_simulation(self, duration_minutes: int = 10):
        """Run continuous event simulation"""
        end_time = time.time() + (duration_minutes * 60)
        session_count = 0
        
        logger.info("Starting continuous simulation", 
                   duration_minutes=duration_minutes,
                   total_users=len(self.users))
        
        while time.time() < end_time:
            # Start random user sessions
            concurrent_sessions = random.randint(3, 8)  # 3-8 concurrent sessions
            
            tasks = []
            for _ in range(concurrent_sessions):
                user_id = random.choice(self.users)
                session_task = self.simulate_user_session(user_id)
                tasks.append(session_task)
                session_count += 1
            
            # Run sessions concurrently
            await asyncio.gather(*tasks, return_exceptions=True)
            
            # Wait before starting next batch
            await asyncio.sleep(random.uniform(10, 30))  # 10-30 seconds between batches
        
        logger.info("Simulation completed", 
                   total_sessions=session_count,
                   duration_minutes=duration_minutes)

async def main():
    """Main simulation entry point"""
    simulator = EventSimulator()
    
    # Wait for server to be ready
    print("⏳ Waiting for server to be ready...")
    await asyncio.sleep(5)
    
    # Run simulation
    print("🎭 Starting event simulation...")
    await simulator.run_continuous_simulation(duration_minutes=5)
    
    print("✅ Event simulation completed!")

if __name__ == "__main__":
    asyncio.run(main())

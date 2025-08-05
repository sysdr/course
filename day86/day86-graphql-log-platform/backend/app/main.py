import os
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import strawberry
from strawberry.fastapi import GraphQLRouter
from strawberry.subscriptions import GRAPHQL_WS_PROTOCOL

from schemas.log_schema import Query, Mutation, Subscription
from utils.database import init_db
from utils.redis_client import init_redis

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    await init_redis()
    yield
    # Shutdown
    pass

app = FastAPI(
    title="Day 86: GraphQL Log Platform",
    description="Flexible log querying with GraphQL",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create GraphQL schema
schema = strawberry.Schema(
    query=Query,
    mutation=Mutation,
    subscription=Subscription
)

# GraphQL router with subscriptions
graphql_app = GraphQLRouter(
    schema,
    subscription_protocols=[GRAPHQL_WS_PROTOCOL]
)

app.include_router(graphql_app, prefix="/graphql")

# Serve React frontend in production
if os.path.exists("../frontend/build"):
    app.mount("/", StaticFiles(directory="../frontend/build", html=True), name="static")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "graphql-log-platform"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

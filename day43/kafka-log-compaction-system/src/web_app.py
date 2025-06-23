#!/usr/bin/env python3

import uvicorn
from src.web.dashboard_app import create_app

if __name__ == "__main__":
    app = create_app()
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info",
        reload=False
    )

from setuptools import setup, find_packages

setup(
    name="priority-log-processor",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "asyncio-throttle>=1.0.2",
        "aioredis>=2.0.1",
        "prometheus-client>=0.17.1",
        "flask>=2.3.2",
        "pytest>=7.4.0",
        "pytest-asyncio>=0.21.1",
        "redis>=4.6.0",
        "pydantic>=2.0.3"
    ],
    author="Priority Queue System",
    description="High-performance priority queue system for distributed log processing",
    python_requires=">=3.8",
)

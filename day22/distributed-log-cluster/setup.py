from setuptools import setup, find_packages

setup(
    name="distributed-log-cluster",
    version="1.0.0",
    description="Day 22: Multi-Node Storage Cluster with Replication",
    packages=find_packages(),
    install_requires=[
        "flask>=2.3.3",
        "httpx==0.27.0",
        "requests>=2.31.0",
        "psutil>=5.9.6"
    ],
    python_requires=">=3.8",
    entry_points={
        'console_scripts': [
            'start-cluster=scripts.start_cluster:main',
        ],
    }
)

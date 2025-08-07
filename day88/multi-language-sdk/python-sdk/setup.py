from setuptools import setup, find_packages

setup(
    name="logplatform-sdk",
    version="1.0.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "requests>=2.31.0",
        "websockets>=12.0",
        "pydantic>=2.7.0",
        "aiohttp>=3.9.0"
    ],
    python_requires=">=3.11",
    author="Log Platform Team",
    description="Official Python SDK for Log Platform",
    long_description="Python client library for interacting with the distributed log processing platform",
    classifiers=[
        "Programming Language :: Python :: 3.11",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)

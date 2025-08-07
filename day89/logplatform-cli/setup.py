from setuptools import setup, find_packages

setup(
    name="logplatform-cli",
    version="1.0.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "click>=8.1.7",
        "requests>=2.31.0",
        "pyyaml>=6.0.1",
        "rich>=13.7.1",
        "websockets>=12.0",
        "pydantic>=2.7.1",
        "keyring>=25.2.1",
        "colorama>=0.4.6",
        "tabulate>=0.9.0",
        "python-dateutil>=2.9.0",
        "aiofiles>=23.2.1"
    ],
    entry_points={
        "console_scripts": [
            "logplatform=logplatform_cli.main:main",
        ],
    },
    python_requires=">=3.11",
    author="LogPlatform Team",
    description="CLI tool for distributed log processing platform",
    long_description="Command-line interface for managing distributed log processing operations",
)

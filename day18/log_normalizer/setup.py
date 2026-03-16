from setuptools import setup, find_packages

setup(
    name="log-normalizer",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "protobuf>=4.21.0",
        "avro-python3>=1.10.0",
        "pytest>=7.0.0",
        "structlog>=22.0.0",
        "pydantic>=1.10.0",
    ],
)

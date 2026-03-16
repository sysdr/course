# Protocol Buffers Log Processing System

## Day 16: Distributed Systems Implementation Course

This project demonstrates high-performance log processing using Protocol Buffers v29.3, showcasing the performance advantages of binary serialization over JSON in distributed systems.

## 🚀 Quick Start

### One-Click Setup and Demo
```bash
# Run the complete setup and demo
./scripts/one_click_demo.sh
```

### Manual Setup
```bash
# Install dependencies and generate protobuf code
./scripts/setup.sh

# Run performance tests
./scripts/run_tests.sh

# Run with Docker
docker-compose -f docker/docker-compose.yml up --build
```

## 📊 Performance Results

Typical performance improvements you'll see:

- **Speed**: 3-4x faster serialization
- **Size**: 2-3x smaller data size
- **Bandwidth**: Significant reduction in network traffic
- **Storage**: Substantial cost savings at scale

## 📁 Project Structure

```
protobuf-log-system/
├── proto/              # Protocol Buffer schema definitions
├── src/                # Core application code
├── tests/              # Unit and integration tests
├── docker/             # Container configuration
├── scripts/            # Automation scripts
├── frontend/           # Performance dashboard
└── logs/               # Generated log files (json/protobuf)
```

## 🎯 Learning Outcomes

- Understanding binary vs text serialization
- Protocol Buffer schema design and evolution
- Performance measurement and analysis
- Distributed systems optimization principles
- Infrastructure automation with scripts

## 🏗️ Real-World Applications

This implementation demonstrates patterns used by:
- Google (internal service communication)
- Netflix (microservice data exchange)
- Uber (real-time data processing)
- Any high-scale distributed system

## 🧪 Testing

```bash
# Run unit tests
python -m pytest tests/ -v

# Run performance benchmarks
cd src && python performance_tester.py

# Generate sample data
python generate_sample_data.py
```

## 🐳 Docker Commands

```bash
# Build image
docker build -f docker/Dockerfile -t protobuf-log-system .

# Run performance tests
docker run --rm -v $(pwd)/logs:/app/logs protobuf-log-system

# Run with docker-compose
docker-compose -f docker/docker-compose.yml up
```

## 📈 Next Steps

1. Run the performance tests and analyze results
2. Experiment with different log volumes
3. Compare with other serialization formats
4. Implement in your own distributed system projects

## 📝 License

Educational project for distributed systems learning.

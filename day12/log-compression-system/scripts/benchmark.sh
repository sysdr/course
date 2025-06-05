#!/bin/bash
set -e

source venv/bin/activate

echo "Running compression benchmarks..."

# Test different compression algorithms and levels
for algorithm in gzip zlib; do
    for level in 1 6 9; do
        echo "Testing $algorithm compression level $level..."
        python src/client.py --server localhost --port 5000 \
                         --compression $algorithm --level $level \
                         --batch-size 1000 --rate 1000 \
                         --batch-interval 2
        sleep 2
    done
done

echo "Benchmark complete!"

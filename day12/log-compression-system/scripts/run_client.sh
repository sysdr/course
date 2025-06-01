#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Run the client
echo "Starting log shipper client..."
python src/client.py --server localhost --port 5000 --batch-size 100 --batch-interval 5 --compression gzip --level 6 --rate 100

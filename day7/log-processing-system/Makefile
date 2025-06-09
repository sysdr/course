# Makefile
.PHONY: build run stop clean query local-run local-stop

# Docker compose commands
build:
	docker-compose build

run:
	docker-compose up -d

stop:
	docker-compose down

clean: stop
	docker-compose down -v
	docker system prune -f

# Run query tool interactively
query:
	docker-compose run --rm query python query.py --storage-dir /data/storage --pattern $(pattern)

query-index:
	docker-compose run --rm query python query.py --storage-dir /data/storage --index-type $(type) --index-value $(value)

# Local development commands
local-setup:
	mkdir -p logs data/collected data/parsed data/storage/index data/storage/active data/storage/archive

local-run: local-setup
	python integration/pipeline.py --config integration/config.yml

local-stop:
	pkill -f "python.*pipeline.py" || true
	pkill -f "python.*generator.py" || true
	pkill -f "python.*collector.py" || true
	pkill -f "python.*parser.py" || true
	pkill -f "python.*storage.py" || true

# View logs
view-logs:
	docker-compose logs -f
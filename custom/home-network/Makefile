# Makefile for Nuclei Home Network Scanner

.PHONY: help test local-test build deploy logs clean

help:
	@echo "Nuclei Home Network Scanner - Available commands:"
	@echo "  make test        - Run local tests"
	@echo "  make build       - Build custom Docker image"
	@echo "  make deploy      - Deploy to Synology NAS"
	@echo "  make logs        - View logs from NAS"
	@echo "  make clean       - Clean up local results"

test: local-test

local-test:
	@echo "Running local test configuration..."
	docker-compose -f docker-compose.local.yml up

build:
	@echo "Building custom Nuclei image..."
	docker build -t nuclei-home-network:latest .

deploy:
	@echo "Deploying to Synology NAS..."
	./deploy.sh

logs:
	@echo "Fetching logs from NAS..."
	ssh nas@192.168.10.163 'cd /volume1/docker/nuclei && docker-compose logs -f'

clean:
	@echo "Cleaning up local results..."
	rm -rf results/*
	docker-compose -f docker-compose.local.yml down

# Development commands
shell:
	@echo "Opening shell in local container..."
	docker-compose -f docker-compose.local.yml run --rm nuclei-local /bin/sh

validate:
	@echo "Validating configuration files..."
	docker-compose -f docker-compose.yml config
	docker-compose -f docker-compose.local.yml config
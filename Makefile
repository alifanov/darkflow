.PHONY: help up down build logs restart ps db-shell

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS=":.*##"}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start the webapp and database in the background
	docker compose up -d

down: ## Stop all services
	docker compose down

build: ## Rebuild the webapp image
	docker compose build

logs: ## Stream logs from all services (Ctrl-C to stop)
	docker compose logs -f

restart: ## Restart all services
	docker compose restart

ps: ## Show running containers and their status
	docker compose ps

db-shell: ## Open a psql shell inside the Postgres container
	docker compose exec db psql -U darkflow darkflow

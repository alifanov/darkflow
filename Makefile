.PHONY: help up down web logs restart ps db-shell docker-up

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS=":.*##"}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start Postgres in the background (webapp runs on the host — see `make web`)
	docker compose up -d

web: ## Build and run the webapp as a host process (http://localhost:3000)
	cd webapp && pnpm build && pnpm start

docker-up: ## Start Postgres + webapp in Docker (no cmux launch button; http://localhost:5555)
	docker compose --profile docker up -d

down: ## Stop all services
	docker compose down

logs: ## Stream Docker logs (Ctrl-C to stop)
	docker compose logs -f

restart: ## Restart Docker services
	docker compose restart

ps: ## Show running containers and their status
	docker compose ps

db-shell: ## Open a psql shell inside the Postgres container
	docker compose exec db psql -U darkflow darkflow

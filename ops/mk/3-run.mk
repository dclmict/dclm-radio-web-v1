# ═══════════════════════════════════════
# LOCAL DEV & DEPLOY — stack-aware runner
# ═══════════════════════════════════════

# Start app engine (stack-aware)
run-app:
	@\
	os=$$(hostname); \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	stack="$(DL_APP_STACK)"; \
	if [[ "$$stack" = "php-builtin" && "$$branch" = "bams" ]]; then \
		echo -e "$(GREEN_BOLD)▸ PHP built-in server$(RESET)"; \
		echo -e "  Source: $(GREEN)./$(APP_SRC_DIR)$(RESET)"; \
		echo -e "  URL:    $(GREEN)http://localhost:3000$(RESET)"; \
		cd ./$(APP_SRC_DIR) && PHP_CLI_SERVER_WORKERS=4 php -S 0.0.0.0:3000 router.php; \
	elif [[ "$$branch" = "bams" ]]; then \
		echo -e "$(GREEN_BOLD)▸ Local dev ($$stack)$(RESET)"; \
		make -s compose-local; \
		docker compose -f $(COMPOSE_FILE) up -d; \
		echo -e "  URL: $(GREEN)http://localhost:$(HTTP_PORT)$(RESET)"; \
	else \
		echo -e "Switch to $(RED_BOLD)bams$(RESET) branch to run"; \
	fi

new:
	@git restore .
	@git pull

down:
	@docker compose -f $(COMPOSE_FILE) down

start:
	@docker compose -f $(COMPOSE_FILE) start

restart:
	@docker compose -f $(COMPOSE_FILE) restart

stop:
	@docker compose -f $(COMPOSE_FILE) stop

ps:
	@docker compose -f $(COMPOSE_FILE) ps

stat:
	@docker compose -f $(COMPOSE_FILE) top

log:
	@docker compose -f $(COMPOSE_FILE) logs -f --no-log-prefix 2>&1 | while IFS= read -r line; do \
		if echo "$$line" | grep -q '"logger":"http.log.access"'; then \
			echo -e "$(GREEN)[CADDY]$(RESET) $$line"; \
		elif echo "$$line" | grep -qi 'PHP\|php'; then \
			echo -e "$(RED)[PHP]$(RESET) $$line"; \
		else \
			echo "$$line"; \
		fi; \
	done

sh:
	@docker compose -f $(COMPOSE_FILE) exec -it $(DL_APP_NAME) sh

# ═══════════════════════════════════════
# COMPOSE FILE GENERATORS
# ═══════════════════════════════════════

# --- Local dev compose (bams branch) ---
# Generates a stack-aware docker-compose.yml with code mounted for live reload.
# Each stack gets the right image, working dir, and volume mounts.
compose-local:
	@echo "Generating docker-compose.yml for local dev ($(DL_APP_STACK))..."
	@stack="$(DL_APP_STACK)"; \
	f="$(COMPOSE_FILE)"; \
	echo "services:" > $$f; \
	echo "  $(DL_APP_NAME):" >> $$f; \
	echo "    container_name: $(DL_APP_NAME)" >> $$f; \
	\
	if [[ "$$stack" = "frankenphp" ]]; then \
		echo "    image: img.dclmict.org/dclm/frankenphp:8.3" >> $$f; \
		echo "    environment:" >> $$f; \
		echo "      - SERVER_NAME=:$(HTTP_PORT)" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app/public" >> $$f; \
		echo "      - ../ops/php/Caddyfile:/etc/caddy/Caddyfile:ro" >> $$f; \
		echo "      - ../ops/php/php-errors.ini:/usr/local/etc/php/conf.d/errors.ini:ro" >> $$f; \
	elif [[ "$$stack" = "wordpress" ]]; then \
		echo "    image: wordpress:php8.3-apache" >> $$f; \
		echo "    working_dir: /var/www/html" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./wp-content:/var/www/html/wp-content" >> $$f; \
	elif [[ "$$stack" = "laravel" ]]; then \
		echo "    image: dunglas/frankenphp:latest-php8.3-alpine" >> $$f; \
		echo "    environment:" >> $$f; \
		echo "      - SERVER_NAME=:$(HTTP_PORT)" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app" >> $$f; \
	elif [[ "$$stack" = "nodejs" ]] || [[ "$$stack" = "nestjs" ]]; then \
		echo "    image: node:24-alpine" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    command: [\"sh\", \"-c\", \"npm install && npm run start:dev\"]" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app" >> $$f; \
		echo "      - /app/node_modules" >> $$f; \
	elif [[ "$$stack" = "nextjs" ]] || [[ "$$stack" = "vitejs" ]] || [[ "$$stack" = "reactjs" ]] || [[ "$$stack" = "bunjs" ]]; then \
		echo "    image: node:24-alpine" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    command: [\"sh\", \"-c\", \"npm install && npm run dev\"]" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app" >> $$f; \
		echo "      - /app/node_modules" >> $$f; \
	elif [[ "$$stack" = "python" ]]; then \
		echo "    image: python:3.12-slim" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    command: [\"sh\", \"-c\", \"pip install -r requirements.txt && python main.py\"]" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app" >> $$f; \
	elif [[ "$$stack" = "dotnet" ]]; then \
		echo "    image: mcr.microsoft.com/dotnet/sdk:8.0" >> $$f; \
		echo "    working_dir: /app" >> $$f; \
		echo "    command: [\"dotnet\", \"watch\", \"run\"]" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/app" >> $$f; \
	else \
		echo "    build:" >> $$f; \
		echo "      context: .." >> $$f; \
		echo "      dockerfile: ops/dkr/Dockerfile" >> $$f; \
		echo "    working_dir: /var/www" >> $$f; \
		echo "    volumes:" >> $$f; \
		echo "      - ./:/var/www" >> $$f; \
	fi; \
	echo "    env_file: .env" >> $$f; \
	echo "    ports:" >> $$f; \
	echo "      - \"$(HTTP_PORT):$(HTTP_PORT)\"" >> $$f; \
	echo "    restart: unless-stopped" >> $$f; \
	echo "Docker-compose file generated successfully."

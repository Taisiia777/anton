#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Останавливаем mamostore.su...${NC}"

docker-compose down

echo -e "${GREEN}✅ Остановлено!${NC}"
#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Быстрый запуск mamostore.su${NC}"
echo -e "${GREEN}================================${NC}"

# Запускаем контейнеры
docker-compose up -d

# Ждем немного
sleep 5

# Показываем статус
echo -e "${GREEN}✅ Запущено!${NC}"
echo -e "${GREEN}🌐 HTTP:  http://localhost:8080${NC}"
echo -e "${GREEN}🔒 HTTPS: https://localhost:8443${NC}"
echo ""
echo -e "${BLUE}Для управления используйте: ./manage.sh${NC}"
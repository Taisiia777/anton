#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Развертывание mamostore.su через Docker${NC}"
echo -e "${YELLOW}===============================================${NC}"

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен${NC}"
    echo -e "${YELLOW}💡 Установите Docker: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh${NC}"
    exit 1
fi

# Проверяем наличие Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose не установлен${NC}"
    echo -e "${YELLOW}💡 Установите Docker Compose${NC}"
    exit 1
fi

# Функция проверки портов
check_port() {
    if ss -tuln 2>/dev/null | grep -q ":$1 " || netstat -tuln 2>/dev/null | grep -q ":$1 "; then
        echo -e "${RED}❌ Порт $1 уже используется${NC}"
        echo -e "${YELLOW}💡 Освободите порт или измените конфигурацию${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Порт $1 свободен${NC}"
        return 0
    fi
}

# Информация о портах
echo -e "${BLUE}📋 Используемые порты:${NC}"
echo -e "${YELLOW}   🌐 HTTP:  8080 (внешний) -> 80 (nginx)${NC}"
echo -e "${YELLOW}   🔒 HTTPS: 8443 (внешний) -> 443 (nginx)${NC}"
echo -e "${YELLOW}   🐍 App:   8000 (внутренний)${NC}"
echo ""

# Проверяем доступность портов
echo -e "${BLUE}🔍 Проверяем доступность портов...${NC}"
check_port 8080 || exit 1
check_port 8443 || exit 1

# Проверяем SSL сертификаты
echo -e "${BLUE}🔐 Проверяем SSL сертификаты...${NC}"
if [ -f "/etc/letsencrypt/live/mamostore.su/fullchain.pem" ]; then
    echo -e "${GREEN}✅ SSL сертификаты найдены${NC}"
    SSL_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  SSL сертификаты не найдены. HTTPS будет недоступен.${NC}"
    SSL_AVAILABLE=false
fi

# Останавливаем существующие контейнеры
echo -e "${BLUE}🔄 Останавливаем существующие контейнеры...${NC}"
docker-compose down --remove-orphans

# Очищаем старые образы
echo -e "${BLUE}🧹 Очищаем старые образы...${NC}"
docker system prune -f

# Собираем новые образы
echo -e "${BLUE}🔨 Собираем Docker образы...${NC}"
docker-compose build --no-cache --parallel

# Запускаем контейнеры
echo -e "${BLUE}🚀 Запускаем контейнеры...${NC}"
docker-compose up -d

# Ждем запуска
echo -e "${BLUE}⏳ Ждем запуска сервисов...${NC}"
sleep 15

# Проверяем статус контейнеров
echo -e "${BLUE}📊 Проверяем статус контейнеров...${NC}"
docker-compose ps

# Проверяем работоспособность
echo -e "${BLUE}🔍 Проверяем работоспособность...${NC}"

# Проверка HTTP
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 --connect-timeout 10 | grep -q "200\|302\|301"; then
    echo -e "${GREEN}✅ HTTP сервер работает на порту 8080${NC}"
    HTTP_OK=true
else
    echo -e "${RED}❌ HTTP сервер не отвечает на порту 8080${NC}"
    HTTP_OK=false
fi

# Проверка HTTPS (если сертификаты есть)
if [ "$SSL_AVAILABLE" = true ]; then
    if curl -s -k -o /dev/null -w "%{http_code}" https://localhost:8443 --connect-timeout 10 | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✅ HTTPS сервер работает на порту 8443${NC}"
        HTTPS_OK=true
    else
        echo -e "${RED}❌ HTTPS сервер не отвечает на порту 8443${NC}"
        HTTPS_OK=false
    fi
fi

# Показываем логи в случае проблем
if [ "$HTTP_OK" = false ]; then
    echo -e "${RED}🚨 Показываем логи для диагностики:${NC}"
    docker-compose logs --tail=20
fi

# Итоговая информация
echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}✅ Развертывание завершено!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступные адреса:${NC}"

if [ "$HTTP_OK" = true ]; then
    echo -e "${GREEN}   📡 HTTP:  http://localhost:8080${NC}"
    echo -e "${GREEN}   📡 HTTP:  http://$(hostname -I | awk '{print $1}'):8080${NC}"
fi

if [ "$SSL_AVAILABLE" = true ] && [ "$HTTPS_OK" = true ]; then
    echo -e "${GREEN}   🔒 HTTPS: https://localhost:8443${NC}"
    echo -e "${GREEN}   🔒 HTTPS: https://$(hostname -I | awk '{print $1}'):8443${NC}"
fi

echo ""
echo -e "${BLUE}🛠️  Полезные команды:${NC}"
echo -e "${YELLOW}   📝 Логи:           docker-compose logs -f${NC}"
echo -e "${YELLOW}   📊 Статус:         docker-compose ps${NC}"
echo -e "${YELLOW}   🛑 Остановка:      docker-compose down${NC}"
echo -e "${YELLOW}   🔄 Перезапуск:     docker-compose restart${NC}"
echo -e "${YELLOW}   🔧 Управление:     ./manage.sh${NC}"
echo ""
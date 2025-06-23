#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функция показа статуса
show_status() {
    echo -e "${BLUE}📊 Статус контейнеров:${NC}"
    docker-compose ps
    echo ""
    
    echo -e "${BLUE}🔍 Проверка доступности:${NC}"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 --connect-timeout 5 | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✅ HTTP (8080): Работает${NC}"
    else
        echo -e "${RED}❌ HTTP (8080): Не доступен${NC}"
    fi
    
    if curl -s -k -o /dev/null -w "%{http_code}" https://localhost:8443 --connect-timeout 5 | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✅ HTTPS (8443): Работает${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTPS (8443): Не доступен${NC}"
    fi
}

# Функция показа ресурсов
show_resources() {
    echo -e "${BLUE}💾 Использование ресурсов:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose ps -q) 2>/dev/null || echo "Контейнеры не запущены"
}

case $1 in
    "start")
        echo -e "${GREEN}🚀 Запускаем контейнеры...${NC}"
        docker-compose up -d
        sleep 5
        show_status
        ;;
    "stop")
        echo -e "${YELLOW}🛑 Останавливаем контейнеры...${NC}"
        docker-compose down
        echo -e "${GREEN}✅ Контейнеры остановлены${NC}"
        ;;
    "restart")
        echo -e "${YELLOW}🔄 Перезапускаем контейнеры...${NC}"
        docker-compose restart
        sleep 5
        show_status
        ;;
    "logs")
        if [ -n "$2" ]; then
            echo -e "${YELLOW}📝 Логи сервиса $2:${NC}"
            docker-compose logs -f "$2"
        else
            echo -e "${YELLOW}📝 Логи всех сервисов:${NC}"
            docker-compose logs -f
        fi
        ;;
    "status")
        show_status
        ;;
    "resources")
        show_resources
        ;;
    "update")
        echo -e "${YELLOW}🔄 Обновляем приложение...${NC}"
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        sleep 10
        show_status
        echo -e "${GREEN}✅ Обновление завершено!${NC}"
        ;;
    "rebuild")
        echo -e "${YELLOW}🏗️  Полная пересборка...${NC}"
        docker-compose down --volumes --remove-orphans
        docker system prune -f
        docker-compose build --no-cache --parallel
        docker-compose up -d
        sleep 10
        show_status
        echo -e "${GREEN}✅ Пересборка завершена!${NC}"
        ;;
    "test")
        echo -e "${YELLOW}🔍 Тестируем соединения...${NC}"
        echo ""
        echo -e "${BLUE}HTTP тест:${NC}"
        curl -I http://localhost:8080 --connect-timeout 10 || echo -e "${RED}HTTP недоступен${NC}"
        echo ""
        echo -e "${BLUE}HTTPS тест:${NC}"
        curl -I -k https://localhost:8443 --connect-timeout 10 || echo -e "${YELLOW}HTTPS недоступен${NC}"
        ;;
    "shell")
        if [ "$2" = "app" ]; then
            echo -e "${BLUE}🐚 Подключение к контейнеру приложения...${NC}"
            docker-compose exec app /bin/bash
        elif [ "$2" = "nginx" ]; then
            echo -e "${BLUE}🐚 Подключение к контейнеру nginx...${NC}"
            docker-compose exec nginx /bin/sh
        else
            echo -e "${RED}Укажите контейнер: app или nginx${NC}"
            echo -e "${YELLOW}Пример: $0 shell app${NC}"
        fi
        ;;
    "cleanup")
        echo -e "${YELLOW}🧹 Очистка системы Docker...${NC}"
        docker-compose down --volumes --remove-orphans
        docker system prune -a -f --volumes
        echo -e "${GREEN}✅ Очистка завершена${NC}"
        ;;
    *)
        echo -e "${BLUE}🛠️  Система управления mamostore.su${NC}"
        echo ""
        echo -e "${YELLOW}Использование: $0 <команда> [параметры]${NC}"
        echo ""
        echo -e "${GREEN}Основные команды:${NC}"
        echo -e "  ${YELLOW}start${NC}      - Запустить все контейнеры"
        echo -e "  ${YELLOW}stop${NC}       - Остановить все контейнеры"
        echo -e "  ${YELLOW}restart${NC}    - Перезапустить все контейнеры"
        echo -e "  ${YELLOW}status${NC}     - Показать статус и доступность"
        echo -e "  ${YELLOW}update${NC}     - Обновить приложение"
        echo -e "  ${YELLOW}rebuild${NC}    - Полная пересборка"
        echo ""
        echo -e "${GREEN}Мониторинг:${NC}"
        echo -e "  ${YELLOW}logs${NC}       - Показать логи всех сервисов"
        echo -e "  ${YELLOW}logs app${NC}   - Показать логи приложения"
        echo -e "  ${YELLOW}logs nginx${NC} - Показать логи nginx"
        echo -e "  ${YELLOW}resources${NC}  - Показать использование ресурсов"
        echo -e "  ${YELLOW}test${NC}       - Протестировать соединения"
        echo ""
        echo -e "${GREEN}Управление:${NC}"
        echo -e "  ${YELLOW}shell app${NC}  - Подключиться к контейнеру приложения"
        echo -e "  ${YELLOW}shell nginx${NC}- Подключиться к контейнеру nginx"
        echo -e "  ${YELLOW}cleanup${NC}    - Очистить все данные Docker"
        echo ""
        echo -e "${BLUE}Доступные адреса:${NC}"
        echo -e "  ${GREEN}HTTP:${NC}  http://localhost:8080"
        echo -e "  ${GREEN}HTTPS:${NC} https://localhost:8443"
        exit 1
        ;;
esac
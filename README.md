# Домашнее задание: Балансировка веб-приложения

## Цель

Настроить Nginx в качестве балансировщика с двумя методами (round-robin и hash), два фронтенд-сервера с WordPress и общую базу данных MariaDB.

## Архитектура
![Архитектура проекта](screenshots/PhysicalArchitecture1.svg)

text

## Компоненты

| ВМ | IP | Роль | ПО |
|----|-----|------|-----|
| balancer | 192.168.200.41 | Балансировщик | Nginx |
| frontend-1 | 192.168.200.242 | Фронтенд | Nginx + PHP-FPM + WordPress |
| frontend-2 | 192.168.200.36 | Фронтенд | Nginx + PHP-FPM + WordPress |
| db | 192.168.200.67 | База данных | MariaDB |

## Методы балансировки

### Round-robin

Запросы распределяются по очереди:
Запрос 1 → frontend-2
Запрос 2 → frontend-1
Запрос 3 → frontend-2
Запрос 4 → frontend-1

text

### Hash

Одинаковые URI всегда попадают на один сервер:
/alpha → всегда frontend-2
/beta → всегда frontend-2
/gamma → всегда frontend-1

text

## Результаты тестирования

| Метод | Результат |
|-------|-----------|
| Round-robin | Запросы чередуются: 1→2→1→2→1→2 |
| Hash `/alpha` | Всегда `frontend-2` |
| Hash `/beta` | Всегда `frontend-2` |
| Hash `/gamma` | Всегда `frontend-1` |
| WordPress | HTTP 302 → `/wp-admin/install.php` |

## Структура проекта
balancer-project/
├── main.tf # Terraform: сеть, 4 ВМ, диски
├── outputs.tf # Выходные параметры
├── cloud-init.yaml # Cloud-init: пользователи, SSH
├── architecture.dot # Graphviz-схема
├── ansible/
│ ├── inventory.yml # Инвентарь узлов
│ ├── playbook.yml # Основной плейбук настройки
│ └── playbook_headers.yml # Добавление заголовка X-Backend-Server
├── screenshots/ # Скриншоты
└── README.md # Документация
## Обзор проекта: Балансировка веб-приложения

---

### Инфраструктура

С помощью **Terraform** созданы 4 виртуальные машины в локальном KVM/libvirt:

| ВМ | IP | Роль |
|----|-----|------|
| balancer | 192.168.200.41 | Nginx-балансировщик |
| frontend-1 | 192.168.200.242 | Nginx + PHP-FPM + WordPress |
| frontend-2 | 192.168.200.36 | Nginx + PHP-FPM + WordPress |
| db | 192.168.200.67 | MariaDB (общая БД) |

Все ВМ подключены к изолированной NAT-сети `192.168.200.0/24`.

### Настройка (Ansible)

**Балансировщик (balancer):**
- Установлен Nginx
- Настроен `upstream` с двумя бэкендами: `frontend-1` и `frontend-2`
- Два метода балансировки на разных location:
  - `/roundrobin` — запросы распределяются по очереди (round-robin)
  - `/hash` — запросы с одинаковым URI всегда попадают на один сервер (hash по `$request_uri`)

**Фронтенды (frontend-1, frontend-2):**
- Установлены Nginx + PHP-FPM 8.1 + расширения PHP
- Скачан и распакован WordPress
- Настроен `wp-config.php` с подключением к общей БД `192.168.200.67`
- Nginx проксирует PHP-запросы на `php8.1-fpm.sock`

**База данных (db):**
- Установлена MariaDB
- Создана БД `wordpress` и пользователь `wpuser`
- Разрешены подключения со всех адресов (`bind-address = 0.0.0.0`)

---

## Как это работает

### Round-robin

```
Запрос 1 → balancer → frontend-2
Запрос 2 → balancer → frontend-1
Запрос 3 → balancer → frontend-2
Запрос 4 → balancer → frontend-1
```

Каждый новый запрос уходит на следующий сервер по кругу. Это равномерно распределяет нагрузку.

**Конфигурация Nginx:**
```nginx
upstream backend_roundrobin {
    server 192.168.200.242;   # frontend-1
    server 192.168.200.36;    # frontend-2
}
```

### Hash

```
/alpha → всегда frontend-2
/beta  → всегда frontend-2
/gamma → всегда frontend-1
```

Nginx вычисляет хеш от URI запроса и направляет его на один и тот же сервер. Это полезно для кеширования: если страница закеширована на одном сервере, повторные запросы пойдут туда же.

**Конфигурация Nginx:**
```nginx
upstream backend_hash {
    hash $request_uri consistent;
    server 192.168.200.242;   # frontend-1
    server 192.168.200.36;    # frontend-2
}
```

### Обработка WordPress

1. Пользователь открывает `http://192.168.200.41/roundrobin`
2. Балансировщик направляет запрос на `frontend-1` или `frontend-2`
3. Nginx на фронтенде видит `.php` — передаёт в PHP-FPM
4. WordPress подключается к общей MariaDB (`192.168.200.67`)
5. Ответ возвращается через балансировщик пользователю

**Оба фронтенда используют одну БД** — поэтому контент (статьи, настройки) одинаковый на обоих серверах.

---

## Итоги тестирования

| Метод | Результат |
|-------|-----------|
| Round-robin | Запросы чередуются: 1→2→1→2→1→2 |
| Hash `/alpha` | Всегда `frontend-2` |
| Hash `/beta` | Всегда `frontend-2` |
| Hash `/gamma` | Всегда `frontend-1` |
| WordPress | HTTP 302 → `/wp-admin/install.php` |
| База данных | MariaDB принимает подключения от обоих фронтендов |

---

## Инструкция по воспроизведению

```bash
# 1. Клонировать репозиторий
git clone <url>
cd balancer-project

# 2. Создать инфраструктуру
terraform init
terraform import libvirt_pool.default <UUID>
terraform apply -auto-approve

# 3. Настроить ВМ
cd ansible
ansible-playbook -i inventory.yml playbook.yml

# 4. Проверить балансировку
curl -sI http://192.168.200.41/roundrobin | grep X-Backend-Server

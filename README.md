# ClickHouse Web Analytics

Аналитический проект на ClickHouse: расчёт метрик веб-трафика маркетплейса (DAU/WAU/MAU, воронка покупки, retention) на схемах с MergeTree и JOIN между логами и справочником товаров.

> **О данных:** Набор синтетический, создан для демонстрации. Все `visitor_id`, `product_id`, URL и метки времени сгенерированы.

## 🛠️ Технологии

- **ClickHouse** — MergeTree, LowCardinality, партиционирование, JOIN, оконные функции
- **SQL** — `countIf`, `uniq`, `lagInFrame`, `first_value`, `dateDiff`
- **SQLize.online** — песочница для запуска

## 📊 Схема данных

### `events` — факт-логи веб-трафика

| Колонка | Тип | Описание |
|---|---|---|
| event_time | DateTime | Время события |
| event_date | Date MATERIALIZED | Дата события |
| visitor_id | UInt64 | ID посетителя |
| session_id | UInt64 | ID сессии |
| event_type | LowCardinality(String) | Тип события |
| url | String | URL страницы |
| product_id | UInt32 | ID товара (0, если не связано) |
| duration_ms | UInt32 | Длительность в мс |

### `products` — справочник

| Колонка | Тип | Описание |
|---|---|---|
| product_id | UInt32 | ID товара |
| product_name | String | Название |
| category | LowCardinality(String) | Категория |
| price | UInt32 | Цена |

### Типы событий (шаги воронки)

| event_type | Шаг |
|---|---|
| `pageview` | 1 |
| `product_view` | 2 |
| `add_to_cart` | 3 |
| `checkout` | 4 |
| `purchase` | 5 |

## 🚀 Запуск

Все запросы лежат в [`queries.sql`](./queries.sql). Выполняются за один прогон в [SQLize.online — ClickHouse](https://sqlize.online/sql/clickhouse/), так как состояние между запусками не сохраняется.

## 📈 Метрики

### 1. DAU / WAU / MAU + Stickiness

ClickHouse не поддерживает коррелированные подзапросы без специального флага. Вместо подзапросов используется self-JOIN.

| event_date | dau | wau | mau | stickiness |
|---|---|---|---|---|
| 2026-09-04 | 5 | 5 | 5 | 1.000 |
| 2026-09-05 | 5 | 7 | 7 | 0.714 |
| 2026-09-06 | 5 | 8 | 8 | 0.625 |
| 2026-09-07 | 5 | 8 | 9 | 0.556 |

> DAU стабилен, MAU растёт. Stickiness падает — новые юзеры не возвращаются ежедневно.

### 2. Топ страниц

| url | views | unique_visitors | avg_duration_ms |
|---|---|---|---|
| /home | 14 | 9 | 1393 |
| /category/books | 4 | 3 | 4450 |
| /docs | 3 | 2 | 5167 |

> `/home` — транзитная точка входа, `/docs` и категории — глубокое вовлечение.

### 3. Воронка по сессиям

| step_num | step_name | sessions | cr_from_start | cr_from_prev |
|---|---|---|---|---|
| 1 | 1. pageview | 20 | 1.000 | NULL |
| 2 | 2. product_view | 10 | 0.500 | 0.500 |
| 3 | 3. add_to_cart | 6 | 0.300 | 0.600 |
| 4 | 4. checkout | 4 | 0.200 | 0.667 |
| 5 | 5. purchase | 4 | 0.200 | 1.000 |

> Главный отвал — `pageview → product_view` (CR 50%) и `add_to_cart → checkout` (CR 33%). `checkout → purchase` = 100%.

### 4. Воронка по пользователям

| step_num | step_name | users | cr_from_start |
|---|---|---|---|
| 1 | 1. pageview | 9 | 1.000 |
| 2 | 2. product_view | 8 | 0.889 |
| 3 | 3. add_to_cart | 5 | 0.556 |
| 4 | 4. checkout | 3 | 0.333 |
| 5 | 5. purchase | 3 | 0.333 |

> End-to-end конверсия в покупку — 33% от всех пришедших.

### 5. Retention по когортам (D1/D3)

| cohort_date | d0 | d1 | d3 | retention_d1 | retention_d3 |
|---|---|---|---|---|---|
| 2026-09-04 | 5 | 3 | 3 | 0.600 | 0.600 |
| 2026-09-05 | 2 | 1 | 0 | 0.500 | 0.000 |
| 2026-09-06 | 1 | 1 | 0 | 1.000 | 0.000 |
| 2026-09-07 | 1 | 0 | 0 | 0.000 | 0.000 |

> Когорта 04.09 удерживается на 60% в D1 и D3. Когорта 06.09 — 100% в D1.

### 6. Топ категорий по просмотрам (JOIN)

| category | product_views | unique_visitors |
|---|---|---|
| Электроника | 4 | 2 |
| Книги | 2 | 2 |
| Спорт | 2 | 2 |
| Дом | 1 | 1 |
| Детские товары | 1 | 1 |

> Топ категорий — основа категорийного менеджмента.

## 📁 Структура проекта

```
clickhouse-web-analytics/
├── README.md
└── queries.sql
```

## 📌 Что демонстрирует

- OLAP-проектирование: MergeTree, партиционирование, LowCardinality, материализованные колонки.
- Обход ограничения ClickHouse на коррелированные подзапросы через self-JOIN.
- Корректная воронка (пошаговая, с CR) на уровне сессий и юзеров.
- Когортный retention (D1/D3).
- DAU/WAU/MAU + stickiness.
- Window functions: `first_value`, `lagInFrame`, `dateDiff`.
- ClickHouse-функции: `uniq`, `countIf`, `toYYYYMM`, `multiIf`.

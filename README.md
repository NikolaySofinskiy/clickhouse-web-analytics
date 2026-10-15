# ClickHouse Web Analytics

Проект на ClickHouse: расчёт метрик веб-трафика маркетплейса (DAU/WAU/MAU, воронка покупки, retention) на схемах с MergeTree и JOIN между логами и справочником товаров.

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

Всё выполняется за один прогон в [SQLize.online — ClickHouse](https://sqlize.online/).

### 1. Создание таблиц

```sql
CREATE TABLE products
(
    product_id   UInt32,
    product_name String,
    category     LowCardinality(String),
    price        UInt32
)
ENGINE = MergeTree()
ORDER BY product_id;

CREATE TABLE events
(
    event_time  DateTime,
    event_date  Date MATERIALIZED toDate(event_time),
    visitor_id  UInt64,
    session_id  UInt64,
    event_type  LowCardinality(String),
    url         String,
    product_id  UInt32,
    duration_ms UInt32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, visitor_id, event_time);
```

### 2. Вставка данных

```sql
INSERT INTO products VALUES
(101, 'Смартфон X',       'Электроника',    45000),
(102, 'Наушники Y',       'Электроника',     8000),
(103, 'Книга "SQL"',      'Книги',           1200),
(104, 'Кофемашина Z',     'Дом',            35000),
(105, 'Беговая дорожка',  'Спорт',          60000),
(106, 'Конструктор',      'Детские товары',  2500);

INSERT INTO events
(event_time, visitor_id, session_id, event_type, url, product_id, duration_ms)
VALUES
('2026-09-04 10:00:00', 101, 20260904000101, 'pageview',     '/home',              0, 1200),
('2026-09-04 10:01:00', 101, 20260904000101, 'product_view', '/product/101',     101, 3400),
('2026-09-04 10:02:00', 101, 20260904000101, 'add_to_cart',  '/cart',            101,    0),
('2026-09-04 10:03:00', 101, 20260904000101, 'checkout',     '/checkout',          0,    0),
('2026-09-04 10:04:00', 101, 20260904000101, 'purchase',     '/checkout/success',  0,    0),
('2026-09-04 10:05:00', 102, 20260904000102, 'pageview',     '/home',              0, 1500),
('2026-09-04 10:06:00', 102, 20260904000102, 'pageview',     '/category/books',    0, 5000),
('2026-09-04 10:07:00', 103, 20260904000103, 'pageview',     '/home',              0,  900),
('2026-09-04 10:08:00', 103, 20260904000103, 'product_view', '/product/103',     103, 2500),
('2026-09-04 10:09:00', 107, 20260904000107, 'pageview',     '/docs',              0, 4200),
('2026-09-04 10:10:00', 108, 20260904000108, 'pageview',     '/home',              0, 1300),
('2026-09-05 11:00:00', 101, 20260905000101, 'pageview',     '/home',              0, 1100),
('2026-09-05 11:01:00', 101, 20260905000101, 'product_view', '/product/101',     101, 2900),
('2026-09-05 11:02:00', 104, 20260905000104, 'pageview',     '/home',              0, 2000),
('2026-09-05 11:03:00', 104, 20260905000104, 'product_view', '/product/104',     104, 7000),
('2026-09-05 11:04:00', 104, 20260905000104, 'add_to_cart',  '/cart',            104,    0),
('2026-09-05 11:05:00', 104, 20260905000104, 'checkout',     '/checkout',          0,    0),
('2026-09-05 11:06:00', 104, 20260905000104, 'purchase',     '/checkout/success',  0,    0),
('2026-09-05 11:07:00', 105, 20260905000105, 'pageview',     '/home',              0,  800),
('2026-09-05 11:08:00', 107, 20260905000107, 'pageview',     '/category/books',    0, 3600),
('2026-09-05 11:09:00', 108, 20260905000108, 'pageview',     '/home',              0, 2500),
('2026-09-05 11:10:00', 108, 20260905000108, 'product_view', '/product/102',     102, 2200),
('2026-09-05 11:11:00', 108, 20260905000108, 'add_to_cart',  '/cart',            102,    0),
('2026-09-06 12:00:00', 101, 20260906000101, 'pageview',     '/home',              0, 1050),
('2026-09-06 12:01:00', 102, 20260906000102, 'pageview',     '/category/books',    0, 4800),
('2026-09-06 12:02:00', 102, 20260906000102, 'product_view', '/product/103',     103, 3100),
('2026-09-06 12:03:00', 105, 20260906000105, 'pageview',     '/docs',              0, 6100),
('2026-09-06 12:04:00', 105, 20260906000105, 'product_view', '/product/105',     105, 4300),
('2026-09-06 12:05:00', 105, 20260906000105, 'add_to_cart',  '/cart',            105,    0),
('2026-09-06 12:06:00', 105, 20260906000105, 'checkout',     '/checkout',          0,    0),
('2026-09-06 12:07:00', 105, 20260906000105, 'purchase',     '/checkout/success',  0,    0),
('2026-09-06 12:08:00', 107, 20260906000107, 'pageview',     '/home',              0, 1400),
('2026-09-06 12:09:00', 109, 20260906000109, 'pageview',     '/home',              0, 1700),
('2026-09-06 12:10:00', 109, 20260906000109, 'product_view', '/product/105',     105, 3300),
('2026-09-06 12:11:00', 109, 20260906000109, 'add_to_cart',  '/cart',            105,    0),
('2026-09-07 13:00:00', 101, 20260907000101, 'pageview',     '/home',              0, 1000),
('2026-09-07 13:01:00', 101, 20260907000101, 'product_view', '/product/101',     101, 3100),
('2026-09-07 13:02:00', 101, 20260907000101, 'add_to_cart',  '/cart',            101,    0),
('2026-09-07 13:03:00', 101, 20260907000101, 'checkout',     '/checkout',          0,    0),
('2026-09-07 13:04:00', 101, 20260907000101, 'purchase',     '/checkout/success',  0,    0),
('2026-09-07 13:05:00', 106, 20260907000106, 'pageview',     '/home',              0, 1800),
('2026-09-07 13:06:00', 106, 20260907000106, 'product_view', '/product/106',     106, 1200),
('2026-09-07 13:07:00', 107, 20260907000107, 'pageview',     '/docs',              0, 5200),
('2026-09-07 13:08:00', 108, 20260907000108, 'pageview',     '/home',              0, 1250),
('2026-09-07 13:09:00', 109, 20260907000109, 'pageview',     '/category/books',    0, 4400);
```

### 3. Обогащённое представление

```sql
CREATE VIEW v_events_enriched AS
SELECT
    e.event_time,
    e.event_date,
    e.visitor_id,
    e.session_id,
    e.event_type,
    e.url,
    e.product_id,
    e.duration_ms,
    p.product_name,
    p.category,
    multiIf(
        e.event_type = 'pageview',     1,
        e.event_type = 'product_view', 2,
        e.event_type = 'add_to_cart',  3,
        e.event_type = 'checkout',     4,
        e.event_type = 'purchase',     5,
        0
    ) AS funnel_step
FROM events e
LEFT JOIN products p
    ON e.product_id = p.product_id AND e.product_id != 0;
```

## 📈 Метрики

### 1. DAU / WAU / MAU + Stickiness

```sql
WITH daily AS (
    SELECT event_date, uniq(visitor_id) AS dau
    FROM events
    GROUP BY event_date
)
SELECT
    event_date,
    dau,
    (SELECT uniq(visitor_id) FROM events
     WHERE event_date BETWEEN d.event_date - 6 AND d.event_date) AS wau,
    (SELECT uniq(visitor_id) FROM events
     WHERE event_date BETWEEN d.event_date - 29 AND d.event_date) AS mau,
    round(dau / nullIf(mau, 0), 3) AS stickiness
FROM daily d
ORDER BY event_date;
```

| event_date | dau | wau | mau | stickiness |
|---|---|---|---|---|
| 2026-09-04 | 5 | 5 | 5 | 1.000 |
| 2026-09-05 | 5 | 7 | 7 | 0.714 |
| 2026-09-06 | 5 | 8 | 8 | 0.625 |
| 2026-09-07 | 5 | 8 | 9 | 0.556 |

> DAU стабилен, MAU растёт. Stickiness падает — новые юзеры не возвращаются ежедневно.

### 2. Топ страниц

```sql
SELECT
    url,
    count()                 AS views,
    uniq(visitor_id)        AS unique_visitors,
    round(avg(duration_ms)) AS avg_duration_ms
FROM events
WHERE event_type = 'pageview'
GROUP BY url
ORDER BY views DESC;
```

| url | views | unique_visitors | avg_duration_ms |
|---|---|---|---|
| /home | 14 | 9 | 1393 |
| /category/books | 4 | 4 | 4450 |
| /docs | 3 | 2 | 5167 |

> `/home` — транзитная точка входа, `/docs` и категории — глубокое вовлечение.

### 3. Воронка по сессиям

```sql
WITH session_funnel AS (
    SELECT session_id, visitor_id, max(funnel_step) AS max_step
    FROM v_events_enriched
    GROUP BY session_id, visitor_id
)
SELECT
    step_num,
    step_name,
    sessions,
    round(sessions / first_value(sessions) OVER (ORDER BY step_num), 3) AS cr_from_start,
    round(sessions / lagInFrame(sessions) OVER (ORDER BY step_num), 3)  AS cr_from_prev
FROM (
    SELECT 1 AS step_num, '1. pageview'     AS step_name, countIf(max_step >= 1) AS sessions FROM session_funnel
    UNION ALL SELECT 2, '2. product_view', countIf(max_step >= 2) FROM session_funnel
    UNION ALL SELECT 3, '3. add_to_cart',  countIf(max_step >= 3) FROM session_funnel
    UNION ALL SELECT 4, '4. checkout',     countIf(max_step >= 4) FROM session_funnel
    UNION ALL SELECT 5, '5. purchase',     countIf(max_step >= 5) FROM session_funnel
)
ORDER BY step_num;
```

| step_num | step_name | sessions | cr_from_start | cr_from_prev |
|---|---|---|---|---|
| 1 | 1. pageview | 14 | 1.000 | — |
| 2 | 2. product_view | 10 | 0.714 | 0.714 |
| 3 | 3. add_to_cart | 6 | 0.429 | 0.600 |
| 4 | 4. checkout | 4 | 0.286 | 0.667 |
| 5 | 5. purchase | 4 | 0.286 | 1.000 |

> Главный отвал — `product_view → add_to_cart` (CR 60%). `checkout → purchase` = 100%.

### 4. Воронка по пользователям

```sql
WITH user_funnel AS (
    SELECT visitor_id, max(funnel_step) AS max_step
    FROM v_events_enriched
    GROUP BY visitor_id
)
SELECT
    step_num,
    step_name,
    users,
    round(users / first_value(users) OVER (ORDER BY step_num), 3) AS cr_from_start
FROM (
    SELECT 1 AS step_num, '1. pageview'     AS step_name, countIf(max_step >= 1) AS users FROM user_funnel
    UNION ALL SELECT 2, '2. product_view', countIf(max_step >= 2) FROM user_funnel
    UNION ALL SELECT 3, '3. add_to_cart',  countIf(max_step >= 3) FROM user_funnel
    UNION ALL SELECT 4, '4. checkout',     countIf(max_step >= 4) FROM user_funnel
    UNION ALL SELECT 5, '5. purchase',     countIf(max_step >= 5) FROM user_funnel
)
ORDER BY step_num;
```

| step_num | step_name | users | cr_from_start |
|---|---|---|---|
| 1 | 1. pageview | 9 | 1.000 |
| 2 | 2. product_view | 8 | 0.889 |
| 3 | 3. add_to_cart | 5 | 0.556 |
| 4 | 4. checkout | 3 | 0.333 |
| 5 | 5. purchase | 3 | 0.333 |

> End-to-end конверсия в покупку — 33% от всех пришедших.

### 5. Retention по когортам (D1/D3)

```sql
WITH first_visit AS (
    SELECT visitor_id, min(event_date) AS cohort_date
    FROM events
    GROUP BY visitor_id
),
activity AS (
    SELECT DISTINCT
        e.visitor_id,
        f.cohort_date,
        dateDiff('day', f.cohort_date, e.event_date) AS day_n
    FROM events e
    JOIN first_visit f USING (visitor_id)
)
SELECT
    cohort_date,
    countIf(day_n = 0) AS d0,
    countIf(day_n = 1) AS d1,
    countIf(day_n = 3) AS d3,
    round(countIf(day_n = 1) / countIf(day_n = 0), 3) AS retention_d1,
    round(countIf(day_n = 3) / countIf(day_n = 0), 3) AS retention_d3
FROM activity
GROUP BY cohort_date
ORDER BY cohort_date;
```

| cohort_date | d0 | d1 | d3 | retention_d1 | retention_d3 |
|---|---|---|---|---|---|
| 2026-09-04 | 5 | 3 | 3 | 0.600 | 0.600 |
| 2026-09-05 | 2 | 2 | 2 | 1.000 | 1.000 |
| 2026-09-06 | 2 | 1 | 1 | 0.500 | 0.500 |
| 2026-09-07 | 1 | 0 | 0 | 0.000 | 0.000 |

> Когорта 05.09 удерживается на 100%, 04.09 — 60% на D1.

### 6. Топ категорий по просмотрам (JOIN)

```sql
SELECT
    p.category,
    count()             AS product_views,
    uniq(e.visitor_id)  AS unique_visitors
FROM events e
INNER JOIN products p
    ON e.product_id = p.product_id
WHERE e.event_type = 'product_view'
GROUP BY p.category
ORDER BY product_views DESC;
```

| category | product_views | unique_visitors |
|---|---|---|
| Электроника | 4 | 2 |
| Книги | 2 | 2 |
| Спорт | 2 | 2 |
| Дом | 1 | 1 |
| Детские товары | 1 | 1 |

> Топ категорий — основа категорийного менеджмента.

## 📁 Структура

```
clickhouse-web-analytics/
├── README.md
├── 01_schema.sql
├── 02_insert_data.sql
├── 03_traffic_metrics.sql
├── 04_funnel.sql
└── 05_retention.sql
```

## 📌 Что демонстрирует

- OLAP-проектирование: MergeTree, партиционирование, LowCardinality, материализованные колонки.
- Корректная воронка (пошаговая, с CR) на уровне сессий и юзеров.
- Когортный retention (D1/D3).
- DAU/WAU/MAU + stickiness.
- Window functions: `first_value`, `lagInFrame`, `dateDiff`.
- ClickHouse-функции: `uniq`, `countIf`, `toYYYYMM`, `multiIf`.

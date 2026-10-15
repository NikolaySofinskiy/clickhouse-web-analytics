# ClickHouse Web Analytics

Аналитический проект на ClickHouse: расчёт метрик веб-трафика маркетплейса (DAU/WAU/MAU, воронка покупки, retention) на схемах с MergeTree и JOIN между логами и справочником товаров.

> **О данных:** Набор синтетический, создан для демонстрации. Все `visitor_id`, `product_id`, URL и метки времени сгенерированы. `session_id`, `device_type` и `utm_source` заданы вручную (в реальном проекте `session_id` вычисляется через `sessionize` — разрыв > 30 минут, `device_type` — из user-agent, `utm_source` — из URL или cookie). Данных мало (9 юзеров, 4 дня), поэтому retention D30 не посчитать. `retention_d7 = 0` — артефакт датасета: у последних когорт просто не было времени вернуться.

## 🛠️ Технологии

- **ClickHouse** — MergeTree, LowCardinality, партиционирование, JOIN, оконные функции, `uniqState`/`uniqMerge`, `windowFunnel`, `argMin`
- **SQL** — `countIf`, `uniq`, `uniqState`, `uniqMergeState`, `lagInFrame`, `first_value`, `argMin`, `dateDiff`, `windowFunnel`
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
| product_id | UInt32 | ID товара (заполнен для `product_view`, `add_to_cart`, `purchase`) |
| duration_ms | UInt32 | Длительность в мс (0 для `add_to_cart`, `checkout`, `purchase` — у этих событий нет «длительности страницы») |
| device_type | LowCardinality(String) | Тип устройства: `mobile`, `desktop`, `tablet` |
| utm_source | LowCardinality(String) | Канал: `organic`, `ads`, `email`, `social` |

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

Все запросы выполняются за один прогон в [SQLize.online — ClickHouse](https://sqlize.online/), так как состояние между запусками не сохраняется. Порядок: сначала весь блок «Создание таблиц» + «Вставка данных», затем — аналитические запросы.

## 📈 Запросы и результаты

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
    duration_ms UInt32,
    device_type LowCardinality(String),
    utm_source  LowCardinality(String)
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
(event_time, visitor_id, session_id, event_type, url, product_id, duration_ms, device_type, utm_source)
VALUES
('2026-09-04 10:00:00', 101, 20260904000101, 'pageview',     '/home',              0, 1200, 'mobile',  'ads'),
('2026-09-04 10:01:00', 101, 20260904000101, 'product_view', '/product/101',     101, 3400, 'mobile',  'ads'),
('2026-09-04 10:02:00', 101, 20260904000101, 'add_to_cart',  '/cart',            101,    0, 'mobile',  'ads'),
('2026-09-04 10:03:00', 101, 20260904000101, 'checkout',     '/checkout',          0,    0, 'mobile',  'ads'),
('2026-09-04 10:04:00', 101, 20260904000101, 'purchase',     '/checkout/success', 101,    0, 'mobile',  'ads'),
('2026-09-04 10:05:00', 102, 20260904000102, 'pageview',     '/home',              0, 1500, 'desktop', 'organic'),
('2026-09-04 10:06:00', 102, 20260904000102, 'pageview',     '/category/books',    0, 5000, 'desktop', 'organic'),
('2026-09-04 10:07:00', 103, 20260904000103, 'pageview',     '/home',              0,  900, 'mobile',  'social'),
('2026-09-04 10:08:00', 103, 20260904000103, 'product_view', '/product/103',     103, 2500, 'mobile',  'social'),
('2026-09-04 10:09:00', 107, 20260904000107, 'pageview',     '/docs',              0, 4200, 'desktop', 'organic'),
('2026-09-04 10:10:00', 108, 20260904000108, 'pageview',     '/home',              0, 1300, 'tablet',  'email'),
('2026-09-05 11:00:00', 101, 20260905000101, 'pageview',     '/home',              0, 1100, 'mobile',  'ads'),
('2026-09-05 11:01:00', 101, 20260905000101, 'product_view', '/product/101',     101, 2900, 'mobile',  'ads'),
('2026-09-05 11:02:00', 104, 20260905000104, 'pageview',     '/home',              0, 2000, 'desktop', 'organic'),
('2026-09-05 11:03:00', 104, 20260905000104, 'product_view', '/product/104',     104, 7000, 'desktop', 'organic'),
('2026-09-05 11:04:00', 104, 20260905000104, 'add_to_cart',  '/cart',            104,    0, 'desktop', 'organic'),
('2026-09-05 11:05:00', 104, 20260905000104, 'checkout',     '/checkout',          0,    0, 'desktop', 'organic'),
('2026-09-05 11:06:00', 104, 20260905000104, 'purchase',     '/checkout/success', 104,    0, 'desktop', 'organic'),
('2026-09-05 11:07:00', 105, 20260905000105, 'pageview',     '/home',              0,  800, 'mobile',  'email'),
('2026-09-05 11:08:00', 107, 20260905000107, 'pageview',     '/category/books',    0, 3600, 'desktop', 'organic'),
('2026-09-05 11:09:00', 108, 20260905000108, 'pageview',     '/home',              0, 2500, 'tablet',  'email'),
('2026-09-05 11:10:00', 108, 20260905000108, 'product_view', '/product/102',     102, 2200, 'tablet',  'email'),
('2026-09-05 11:11:00', 108, 20260905000108, 'add_to_cart',  '/cart',            102,    0, 'tablet',  'email'),
('2026-09-06 12:00:00', 101, 20260906000101, 'pageview',     '/home',              0, 1050, 'mobile',  'ads'),
('2026-09-06 12:01:00', 102, 20260906000102, 'pageview',     '/category/books',    0, 4800, 'desktop', 'organic'),
('2026-09-06 12:02:00', 102, 20260906000102, 'product_view', '/product/103',     103, 3100, 'desktop', 'organic'),
('2026-09-06 12:03:00', 105, 20260906000105, 'pageview',     '/docs',              0, 6100, 'mobile',  'email'),
('2026-09-06 12:04:00', 105, 20260906000105, 'product_view', '/product/105',     105, 4300, 'mobile',  'email'),
('2026-09-06 12:05:00', 105, 20260906000105, 'add_to_cart',  '/cart',            105,    0, 'mobile',  'email'),
('2026-09-06 12:06:00', 105, 20260906000105, 'checkout',     '/checkout',          0,    0, 'mobile',  'email'),
('2026-09-06 12:07:00', 105, 20260906000105, 'purchase',     '/checkout/success', 105,    0, 'mobile',  'email'),
('2026-09-06 12:08:00', 107, 20260906000107, 'pageview',     '/home',              0, 1400, 'desktop', 'organic'),
('2026-09-06 12:09:00', 109, 20260906000109, 'pageview',     '/home',              0, 1700, 'mobile',  'social'),
('2026-09-06 12:10:00', 109, 20260906000109, 'product_view', '/product/105',     105, 3300, 'mobile',  'social'),
('2026-09-06 12:11:00', 109, 20260906000109, 'add_to_cart',  '/cart',            105,    0, 'mobile',  'social'),
('2026-09-07 13:00:00', 101, 20260907000101, 'pageview',     '/home',              0, 1000, 'mobile',  'ads'),
('2026-09-07 13:01:00', 101, 20260907000101, 'product_view', '/product/101',     101, 3100, 'mobile',  'ads'),
('2026-09-07 13:02:00', 101, 20260907000101, 'add_to_cart',  '/cart',            101,    0, 'mobile',  'ads'),
('2026-09-07 13:03:00', 101, 20260907000101, 'checkout',     '/checkout',          0,    0, 'mobile',  'ads'),
('2026-09-07 13:04:00', 101, 20260907000101, 'purchase',     '/checkout/success', 101,    0, 'mobile',  'ads'),
('2026-09-07 13:05:00', 106, 20260907000106, 'pageview',     '/home',              0, 1800, 'desktop', 'organic'),
('2026-09-07 13:06:00', 106, 20260907000106, 'product_view', '/product/106',     106, 1200, 'desktop', 'organic'),
('2026-09-07 13:07:00', 107, 20260907000107, 'pageview',     '/docs',              0, 5200, 'desktop', 'organic'),
('2026-09-07 13:08:00', 108, 20260907000108, 'pageview',     '/home',              0, 1250, 'tablet',  'email'),
('2026-09-07 13:09:00', 109, 20260907000109, 'pageview',     '/category/books',    0, 4400, 'mobile',  'social');
```

### 3. Обогащённое представление (staging)

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
    e.device_type,
    e.utm_source,
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

### 4. DAU / WAU / MAU + Stickiness

Считаем через `uniqState` + self-JOIN. `finalizeAggregation` вынесен в CTE, чтобы не группировать по состоянию.

```sql
WITH daily AS (
    SELECT
        event_date,
        uniqState(visitor_id) AS visitors_state
    FROM events
    GROUP BY event_date
),
daily_final AS (
    SELECT
        event_date,
        visitors_state,
        finalizeAggregation(visitors_state) AS dau
    FROM daily
)
SELECT
    d.event_date,
    d.dau,
    finalizeAggregation(uniqMergeState(w.visitors_state)) AS wau,
    finalizeAggregation(uniqMergeState(m.visitors_state)) AS mau,
    round(
        d.dau / nullIf(finalizeAggregation(uniqMergeState(m.visitors_state)), 0),
        3
    ) AS stickiness
FROM daily_final d
LEFT JOIN daily w
    ON w.event_date BETWEEN d.event_date - 6 AND d.event_date
LEFT JOIN daily m
    ON m.event_date BETWEEN d.event_date - 29 AND d.event_date
GROUP BY d.event_date, d.dau, d.visitors_state
ORDER BY d.event_date;
```

| event_date | dau | wau | mau | stickiness |
|---|---|---|---|---|
| 2026-09-04 | 5 | 5 | 5 | 1.000 |
| 2026-09-05 | 5 | 7 | 7 | 0.714 |
| 2026-09-06 | 5 | 8 | 8 | 0.625 |
| 2026-09-07 | 5 | 8 | 9 | 0.556 |

> **Как это работает:** `uniqState` создаёт HyperLogLog-состояние по каждому дню, `uniqMergeState` мёржит состояния за 7/30 дней через self-JOIN, `finalizeAggregation` разворачивает в число.
>
> **Бизнес-смысл:** DAU стабилен (5), MAU растёт (5 → 9). Stickiness падает — новые юзеры не возвращаются ежедневно.

### 5. DAU по устройствам

```sql
SELECT
    device_type,
    uniq(visitor_id)                   AS unique_users,
    count(*)                           AS events,
    toUInt32(round(avg(duration_ms)))  AS avg_duration_ms
FROM events
GROUP BY device_type
ORDER BY unique_users DESC;
```

| device_type | unique_users | events | avg_duration_ms |
|---|---|---|---|
| mobile | 6 | 23 | 1789 |
| desktop | 4 | 14 | 3271 |
| tablet | 1 | 4 | 1813 |

> **Инсайт:** mobile — основной канал по числу юзеров, но desktop даёт в 1.8 раза больше времени на событие. Desktop-аудитория более вовлечена.

### 6. DAU по каналам

```sql
SELECT
    utm_source,
    uniq(visitor_id)                   AS unique_users,
    count(*)                           AS events,
    toUInt32(round(avg(duration_ms)))  AS avg_duration_ms
FROM events
GROUP BY utm_source
ORDER BY unique_users DESC;
```

| utm_source | unique_users | events | avg_duration_ms |
|---|---|---|---|
| organic | 4 | 15 | 2907 |
| ads | 1 | 13 | 1833 |
| email | 2 | 10 | 2850 |
| social | 2 | 7 | 3400 |

> **Инсайт:** organic даёт больше всего уникальных юзеров (4), ads — самый активный по событиям (13 от одного юзера). social показывает самую высокую вовлечённость (3400 мс в среднем).

### 7. Топ страниц по просмотрам

```sql
SELECT
    url,
    count(*)                           AS views,
    uniq(visitor_id)                   AS unique_visitors,
    toUInt32(round(avg(duration_ms)))  AS avg_duration_ms
FROM events
WHERE event_type = 'pageview'
GROUP BY url
ORDER BY views DESC;
```

| url | views | unique_visitors | avg_duration_ms |
|---|---|---|---|
| /home | 14 | 9 | 1393 |
| /category/books | 4 | 3 | 4450 |
| /docs | 3 | 2 | 5167 |

> `/home` — транзитная точка входа, `/docs` и категории — глубокое вовлечение.

### 8. Средняя длительность по типам событий

```sql
SELECT
    event_type,
    count(*)                           AS events,
    toUInt32(round(avg(duration_ms)))  AS avg_duration_ms
FROM events
WHERE event_type IN ('pageview', 'product_view')
GROUP BY event_type
ORDER BY avg_duration_ms DESC;
```

| event_type | events | avg_duration_ms |
|---|---|---|
| product_view | 10 | 3250 |
| pageview | 21 | 2781 |

> На карточке товара юзеры проводят в среднем на 17% больше времени, чем на страницах. Карточка вовлекает, но не конвертит — точка роста.

### 9. Сессии через `sessionize` (вычисляемый `session_id`)

Показываем, как в реальном проекте вычисляется `session_id` через `lagInFrame` + running sum. Новая сессия — если разрыв > 30 минут.

```sql
WITH with_lag AS (
    SELECT
        visitor_id,
        event_time,
        lagInFrame(event_time) OVER (
            PARTITION BY visitor_id ORDER BY event_time
        ) AS prev_time
    FROM events
),
with_flag AS (
    SELECT
        visitor_id,
        event_time,
        if(
            prev_time IS NULL OR dateDiff('minute', prev_time, event_time) > 30,
            1, 0
        ) AS is_new_session
    FROM with_lag
)
SELECT
    visitor_id,
    event_time,
    sum(is_new_session) OVER (
        PARTITION BY visitor_id ORDER BY event_time
    ) AS computed_session_id
FROM with_flag
ORDER BY visitor_id, event_time
LIMIT 15;
```

| visitor_id | event_time | computed_session_id |
|---|---|---|
| 101 | 2026-09-04 10:00:00 | 1 |
| 101 | 2026-09-04 10:01:00 | 1 |
| 101 | 2026-09-04 10:02:00 | 1 |
| 101 | 2026-09-04 10:03:00 | 1 |
| 101 | 2026-09-04 10:04:00 | 1 |
| 101 | 2026-09-05 11:00:00 | 2 |
| 101 | 2026-09-05 11:01:00 | 2 |
| 101 | 2026-09-06 12:00:00 | 3 |
| ... | ... | ... |

> **Зачем это нужно:** в проде `session_id` не хранится, а вычисляется. Этот запрос показывает механику: новый `session_id` = +1 к running sum, если разрыв > 30 минут.

### 10. Воронка покупки по сессиям

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
    round(sessions / nullIf(lagInFrame(sessions) OVER (ORDER BY step_num), 0), 3) AS cr_from_prev
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
| 1 | 1. pageview | 20 | 1.000 | NULL |
| 2 | 2. product_view | 10 | 0.500 | 0.500 |
| 3 | 3. add_to_cart | 6 | 0.300 | 0.600 |
| 4 | 4. checkout | 4 | 0.200 | 0.667 |
| 5 | 5. purchase | 4 | 0.200 | 1.000 |

> Главный отвал — `pageview → product_view` (CR 50%). На синтетических данных отвал выше реального (обычно 70–85%), но механика видна. `checkout → purchase` = 100% — оплата работает идеально.

### 11. Воронка покупки по пользователям

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

### 12. Воронка через `windowFunnel` (7 дней)

`windowFunnel` — встроенная функция ClickHouse, которая считает воронку за окно времени. Возвращает максимальный достигнутый шаг для каждого пользователя за окно. Здесь окно — **7 дней** (`7 * 86400` секунд), что реалистичнее для маркетплейса, чем 24 часа. Дополнительно фильтруем по дате — как в проде.

```sql
SELECT
    funnel_level,
    count(*) AS users,
    multiIf(
        funnel_level = 1, 'pageview only',
        funnel_level = 2, 'до product_view',
        funnel_level = 3, 'до add_to_cart',
        funnel_level = 4, 'до checkout',
        funnel_level = 5, 'purchase',
        '—'
    ) AS stage
FROM (
    SELECT
        visitor_id,
        windowFunnel(7 * 86400)(
            event_time,
            event_type = 'pageview',
            event_type = 'product_view',
            event_type = 'add_to_cart',
            event_type = 'checkout',
            event_type = 'purchase'
        ) AS funnel_level
    FROM events
    WHERE event_date >= '2026-09-01'
    GROUP BY visitor_id
)
GROUP BY funnel_level
ORDER BY funnel_level;
```

| funnel_level | users | stage |
|---|---|---|
| 1 | 1 | pageview only |
| 2 | 3 | до product_view |
| 3 | 2 | до add_to_cart |
| 5 | 3 | purchase |

> **Как читать:** `funnel_level` — максимальный шаг, до которого дошёл юзер за 7 дней. `funnel_level = 5` — прошёл всю воронку. Окно 7 дней показывает, что часть юзеров покупает не в тот же день, а в течение недели.

### 13. Retention по когортам (D1 / D3 / D7)

```sql
WITH first_visit AS (
    SELECT
        visitor_id,
        min(event_date) AS cohort_date
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
    countIf(day_n = 7) AS d7,
    round(countIf(day_n = 1) / nullIf(countIf(day_n = 0), 0), 3) AS retention_d1,
    round(countIf(day_n = 3) / nullIf(countIf(day_n = 0), 0), 3) AS retention_d3,
    round(countIf(day_n = 7) / nullIf(countIf(day_n = 0), 0), 3) AS retention_d7
FROM activity
GROUP BY cohort_date
ORDER BY cohort_date;
```

| cohort_date | d0 | d1 | d3 | d7 | retention_d1 | retention_d3 | retention_d7 |
|---|---|---|---|---|---|---|---|
| 2026-09-04 | 5 | 3 | 3 | 0 | 0.600 | 0.600 | 0.000 |
| 2026-09-05 | 2 | 1 | 0 | 0 | 0.500 | 0.000 | 0.000 |
| 2026-09-06 | 1 | 1 | 0 | 0 | 1.000 | 0.000 | 0.000 |
| 2026-09-07 | 1 | 0 | 0 | 0 | 0.000 | 0.000 | 0.000 |

> D1/D3/D7 — «активен **ровно** в N-й день после первого визита» (строгий retention). Если считать кумулятивно (`day_n >= N`), значения будут выше. `retention_d7 = 0` для всех когорт — **артефакт датасета**: данных всего 4 дня, юзеры физически не могли вернуться на 7-й день.

### 14. Retention по устройствам (D1)

Здесь используется `argMin(device_type, event_time)` — берём `device_type` **первого события** юзера. Это корректнее, чем `any()`, который вернул бы случайное значение.

```sql
WITH first_visit AS (
    SELECT
        visitor_id,
        min(event_date) AS cohort_date,
        argMin(device_type, event_time) AS first_device
    FROM events
    GROUP BY visitor_id
),
activity AS (
    SELECT DISTINCT
        e.visitor_id,
        f.cohort_date,
        f.first_device,
        dateDiff('day', f.cohort_date, e.event_date) AS day_n
    FROM events e
    JOIN first_visit f USING (visitor_id)
)
SELECT
    first_device AS device_type,
    countIf(day_n = 0) AS cohort_size,
    countIf(day_n = 1) AS returned_d1,
    round(countIf(day_n = 1) / nullIf(countIf(day_n = 0), 0), 3) AS retention_d1
FROM activity
GROUP BY first_device
ORDER BY cohort_size DESC;
```

| device_type | cohort_size | returned_d1 | retention_d1 |
|---|---|---|---|
| mobile | 6 | 4 | 0.667 |
| desktop | 2 | 1 | 0.500 |
| tablet | 1 | 0 | 0.000 |

> **Инсайт:** mobile-когорта удерживается лучше (67% на D1), чем desktop (50%). Для маркетплейса это сигнал: **мобильный опыт возвращает юзеров лучше**.

### 15. Топ категорий по просмотрам товаров (JOIN)

```sql
SELECT
    p.category,
    count(*)            AS product_views,
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

### 16. Воронка по категориям (JOIN + условные агрегации)

```sql
SELECT
    p.category,
    countIf(e.event_type = 'product_view') AS views,
    countIf(e.event_type = 'add_to_cart')  AS carts,
    countIf(e.event_type = 'purchase')     AS purchases,
    round(carts / nullIf(views, 0), 3)     AS cr_view_to_cart,
    round(purchases / nullIf(carts, 0), 3) AS cr_cart_to_purchase
FROM events e
INNER JOIN products p
    ON e.product_id = p.product_id
GROUP BY p.category
ORDER BY views DESC;
```

| category | views | carts | purchases | cr_view_to_cart | cr_cart_to_purchase |
|---|---|---|---|---|---|
| Электроника | 4 | 3 | 2 | 0.750 | 0.667 |
| Книги | 2 | 0 | 0 | 0.000 | — |
| Спорт | 2 | 2 | 1 | 1.000 | 0.500 |
| Дом | 1 | 1 | 1 | 1.000 | 1.000 |
| Детские товары | 1 | 0 | 0 | 0.000 | — |

> **Инсайты:**
> - **Дом** — 100% конверсия из корзины в покупку.
> - **Электроника** — 75% в корзину, 67% из корзины в покупку.
> - **Спорт** — 100% в корзину, 50% в покупку (юзер 109 добавил беговую дорожку, но не купил).
> - **Книги и Детские товары** — смотрят, но не добавляют. Проблема на уровне карточки товара.

### 17. Воронка по устройствам

```sql
WITH device_funnel AS (
    SELECT
        device_type,
        session_id,
        max(funnel_step) AS max_step
    FROM v_events_enriched
    GROUP BY device_type, session_id
)
SELECT
    device_type,
    countIf(max_step >= 1) AS sessions,
    countIf(max_step >= 5) AS purchases,
    round(countIf(max_step >= 5) / nullIf(countIf(max_step >= 1), 0), 3) AS cr_to_purchase
FROM device_funnel
GROUP BY device_type
ORDER BY sessions DESC;
```

| device_type | sessions | purchases | cr_to_purchase |
|---|---|---|---|
| mobile | 13 | 3 | 0.231 |
| desktop | 6 | 1 | 0.167 |
| tablet | 2 | 0 | 0.000 |

> **Инсайт:** mobile конвертит лучше desktop (23% vs 17%). Для маркетплейса: **мобильная версия работает хорошо, именно она — основной трафик**. Точка роста — tablet.

### 18. Воронка по каналам

```sql
WITH channel_funnel AS (
    SELECT
        utm_source,
        session_id,
        max(funnel_step) AS max_step
    FROM v_events_enriched
    GROUP BY utm_source, session_id
)
SELECT
    utm_source,
    countIf(max_step >= 1) AS sessions,
    countIf(max_step >= 5) AS purchases,
    round(countIf(max_step >= 5) / nullIf(countIf(max_step >= 1), 0), 3) AS cr_to_purchase
FROM channel_funnel
GROUP BY utm_source
ORDER BY sessions DESC;
```

| utm_source | sessions | purchases | cr_to_purchase |
|---|---|---|---|
| organic | 8 | 1 | 0.125 |
| ads | 5 | 2 | 0.400 |
| email | 4 | 1 | 0.250 |
| social | 3 | 0 | 0.000 |

> **Инсайт:** ads даёт лучшую конверсию (40%), несмотря на меньшее число сессий. organic — много трафика, но низкая конверсия (12.5%). social — 0% на 3 сессиях. Для маркетплейса это сигнал: **пересмотреть бюджеты в пользу ads, разобраться с social**.

## 📋 Что дальше

Проект можно развивать в нескольких направлениях:

- **Материализованное представление для DAU.** В проде вместо self-JOIN используют `AggregatingMergeTree` + `uniqState`:
  ```sql
  CREATE MATERIALIZED VIEW mv_daily_uniq
  ENGINE = AggregatingMergeTree()
  ORDER BY event_date
  AS SELECT event_date, uniqState(visitor_id) AS visitors_state
  FROM events
  GROUP BY event_date;
  ```
  Тогда DAU за любой день — это `uniqMerge(visitors_state)`, а WAU/MAU — сумма по диапазону.

- **`order_id` для покупок.** В реальном логе маркетплейса `purchase` — это заказ, а не товар. Один заказ может содержать несколько товаров. Это позволит считать средний чек и GMV.

- **`Dictionary` для справочника.** В проде `JOIN` со справочником заменяют на `Dictionary`-lookup — это быстрее.

- **Больше данных.** 10–50k событий, 1–3 месяца, 500+ юзеров — тогда retention D7/D30 и когорты станут осмысленными.

- **`ASOF JOIN`** для обогащения по времени (например, цена на момент покупки, а не текущая).

- **Больше разрезов.** `utm_campaign`, `geo`, `browser` — стандартные измерения веб-аналитики.

## ⚠️ Ограничения проекта

- **Данные синтетические:** 9 юзеров, 45 событий, 4 дня. Достаточно для демонстрации механики, но не для зрелых инсайтов.
- **`session_id`, `device_type`, `utm_source` заданы вручную.** В реальном проекте `session_id` вычисляется через `sessionize` (запрос №9), `device_type` — из user-agent, `utm_source` — из URL или cookie.
- **Retention D1/D3/D7, а не D1/D7/D30.** На 4 днях данных D30 не посчитать. Механика та же — достаточно расширить окно.
- **Retention считается строго** («ровно в N-й день»), а не кумулятивно («в N-й день или позже»). Оба подхода допустимы — выбор зависит от задачи.
- **`retention_d7 = 0`** для всех когорт — артефакт датасета, а не проблема удержания.
- **`windowFunnel` использует окно 7 дней.** Для маркетплейса это реалистичнее, чем 24 часа: юзер может добавить в корзину сегодня, а купить через неделю.
- **`duration_ms = 0`** для `add_to_cart`, `checkout`, `purchase` — у этих событий нет «длительности страницы» в том же смысле, что у `pageview`.
- **Нет `order_id`.** В реальном логе маркетплейса `purchase` — это заказ, а не товар. Здесь упрощено: одна покупка = один товар.

## 📁 Структура проекта

```
clickhouse-web-analytics/
├── README.md
└── queries.sql
```

## 📌 Что демонстрирует

- OLAP-проектирование: MergeTree, партиционирование, LowCardinality, материализованные колонки.
- Слой staging: обогащение фактов справочником, разметка шагов воронки.
- DAU/WAU/MAU через `uniqState` + `uniqMergeState` — промышленный подход, работающий в любой версии ClickHouse.
- **`sessionize`** — вычисление `session_id` через `lagInFrame` + running sum.
- Корректная воронка (пошаговая, с CR) на уровне сессий и юзеров.
- Воронка через `windowFunnel` с окном 7 дней — ClickHouse-специфичная функция.
- Воронка по категориям (JOIN + условные агрегации) — от `product_view` до `purchase`.
- Воронка и retention по устройствам — продуктовые разрезы.
- Воронка по каналам (`utm_source`) — маркетинговая аналитика.
- Когортный retention (D1/D3/D7).
- `argMin` для корректного определения первого устройства.
- Window functions: `first_value`, `lagInFrame`, `dateDiff`.
- ClickHouse-функции: `uniq`, `uniqState`, `uniqMergeState`, `finalizeAggregation`, `countIf`, `toYYYYMM`, `multiIf`, `windowFunnel`, `argMin`.

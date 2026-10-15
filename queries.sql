-- 1. Создание таблиц
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

-- 2. Вставка данных
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

-- 3. Обогащённое представление (staging)
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
    
-- 4. DAU / WAU / MAU + Stickiness
WITH daily AS (
    SELECT
        event_date,
        uniqState(visitor_id) AS visitors_state
    FROM events
    GROUP BY event_date
)
SELECT
    event_date,
    finalizeAggregation(visitors_state) AS dau,
    uniqMerge(visitors_state) OVER (
        ORDER BY event_date ASC
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS wau,
    uniqMerge(visitors_state) OVER (
        ORDER BY event_date ASC
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS mau,
    round(
        finalizeAggregation(visitors_state)
        / nullIf(
            uniqMerge(visitors_state) OVER (
                ORDER BY event_date ASC
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
            ), 0
        ),
        3
    ) AS stickiness
FROM daily
ORDER BY event_date;

-- 5. Воронка покупки по сессиям
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

-- 6. Воронка через windowFunnel (7 дней)
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

-- 7. Retention по когортам (D1 / D3 / D7)
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

-- 8. Воронка по каналам (utm_source)
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

-- 9. Воронка по категориям (JOIN + условные агрегации)
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
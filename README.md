# ClickHouse Web Analytics

Аналитический проект на ClickHouse: расчёт продуктовых метрик веб-трафика маркетплейса (DAU, воронка покупки, retention) на схемах с MergeTree и JOIN между логами и справочником товаров.

## 📖 О проекте

Проект показывает полный цикл работы с ClickHouse: проектирование нескольких таблиц, загрузку данных и расчёт метрик с использованием `JOIN`. Цель — продемонстрировать навыки работы с колоночной СУБД и понимание того, чем аналитическая (OLAP) нагрузка отличается от транзакционной (OLTP).

Проект отвечает на вопросы: как спроектировать несколько таблиц под аналитику веб-трафика маркетплейса, как эффективно хранить данные, как джойнить события со справочником и как считать продуктовые метрики на диалекте ClickHouse. В качестве примера используется веб-аналитика маркетплейса: логи поведения пользователей на сайте — просмотры страниц, просмотры карточек товаров, добавления в корзину, начало оформления и покупки. Справочник товаров позволяет обогатить события названием, категорией и ценой, а затем посчитать метрики в разрезе категорий.

## 🛠️ Технологии

- **ClickHouse** — движок MergeTree, LowCardinality, партиционирование, JOIN
- **SQL** — агрегации, JOIN, работа с датами, функции ClickHouse (`countIf`, `uniq`)
- **SQLize.online** — онлайн-песочница для запуска

## 📊 Схема данных

Две таблицы: `events` (факт-логи веб-трафика) и `products` (справочник товаров).

### Таблица `events`

| Колонка       | Тип                    | Описание                                             |
|---------------|------------------------|------------------------------------------------------|
| event_time    | DateTime               | Время события                                        |
| visitor_id    | UInt64                 | ID посетителя                                        |
| event_type    | LowCardinality(String) | Тип события (см. таблицу ниже)                       |
| url           | String                 | URL страницы                                         |
| product_id    | UInt32                 | ID товара (0, если событие не связано с товаром)     |
| duration_ms   | UInt32                 | Длительность в миллисекундах                         |

### Таблица `products`

| Колонка      | Тип                    | Описание             |
|--------------|------------------------|----------------------|
| product_id   | UInt32                 | ID товара            |
| product_name | String                 | Название товара      |
| category     | LowCardinality(String) | Категория товара     |
| price        | UInt32                 | Цена в рублях        |

### Типы событий `events.event_type`

| event_type     | Что означает                                       |
|----------------|----------------------------------------------------|
| `pageview`     | Просмотр страницы (главная, категория, docs)       |
| `product_view` | Просмотр карточки товара                           |
| `add_to_cart`  | Добавление товара в корзину                        |
| `checkout`     | Начало оформления заказа                           |
| `purchase`     | Успешная покупка                                   |

> **О данных:** Набор данных синтетический и создан исключительно для демонстрации возможностей ClickHouse. Все `visitor_id`, `product_id`, URL и временные метки сгенерированы. Проект не использует реальные логи, персональные данные или коммерческую информацию.

Особенности схемы: `PARTITION BY toYYYYMM(event_time)` разбивает данные по месяцам и ускоряет запросы с фильтром по дате; `ORDER BY (event_time, visitor_id)` задаёт сортировку внутри партиции, которая работает как индекс; `LowCardinality(String)` оптимизирует колонки с малым числом уникальных значений (`event_type`, `category`); `UInt32` и `UInt64` заменяют тяжёлые строковые и целочисленные типы, экономя память. Для JOIN между `events` и `products` используется `product_id` — в ClickHouse для справочников часто используют движок `Join` или `Dictionary`, но для учебного проекта достаточно MergeTree и обычного `JOIN`.

### Пример данных

Несколько строк из таблицы `events`:

| event_time          | visitor_id | event_type   | url               | product_id | duration_ms |
|---------------------|------------|--------------|-------------------|------------|-------------|
| 2026-09-04 10:00:00 | 101        | pageview     | /home             | 0          | 1200        |
| 2026-09-04 10:01:00 | 101        | product_view | /product/101      | 101        | 3400        |
| 2026-09-04 10:02:00 | 101        | add_to_cart  | /cart             | 101        | 0           |
| 2026-09-04 10:03:00 | 101        | checkout     | /checkout         | 0          | 0           |
| 2026-09-04 10:04:00 | 101        | purchase     | /checkout/success | 0          | 0           |
| 2026-09-04 10:05:00 | 102        | pageview     | /home             | 0          | 1500        |
| 2026-09-04 10:06:00 | 102        | pageview     | /category/books   | 0          | 5000        |

Несколько строк из таблицы `products`:

| product_id | product_name    | category       | price  |
|------------|-----------------|----------------|--------|
| 101        | Смартфон X      | Электроника    | 45000  |
| 102        | Наушники Y      | Электроника    | 8000   |
| 103        | Книга "SQL"     | Книги          | 1200   |
| 104        | Кофемашина Z    | Дом            | 35000  |
| 105        | Беговая дорожка | Спорт          | 60000  |
| 106        | Конструктор     | Детские товары | 2500   |

## 🚀 Запуск проекта

Все шаги выполняются в [SQLize.online — ClickHouse](https://sqlize.online/sql/clickhouse/).

> ⚠️ **Важно:** SQLize.online не сохраняет состояние между отдельными запусками. Каждый `Run` создаёт новую временную базу данных. Поэтому весь код ниже нужно выполнить за один запуск, а не по частям.

### Создание таблиц

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
    visitor_id  UInt64,
    event_type  LowCardinality(String),
    url         String,
    product_id  UInt32,
    duration_ms UInt32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (event_time, visitor_id);
```

### Вставка данных

```sql
INSERT INTO products VALUES
(101, 'Смартфон X',       'Электроника',    45000),
(102, 'Наушники Y',       'Электроника',     8000),
(103, 'Книга "SQL"',      'Книги',           1200),
(104, 'Кофемашина Z',     'Дом',            35000),
(105, 'Беговая дорожка',  'Спорт',          60000),
(106, 'Конструктор',      'Детские товары',  2500);

INSERT INTO events VALUES
-- 2026-09-04 (день 1)
('2026-09-04 10:00:00', 101, 'pageview',     '/home',              0, 1200),
('2026-09-04 10:01:00', 101, 'product_view', '/product/101',     101, 3400),
('2026-09-04 10:02:00', 101, 'add_to_cart',  '/cart',            101,    0),
('2026-09-04 10:03:00', 101, 'checkout',     '/checkout',          0,    0),
('2026-09-04 10:04:00', 101, 'purchase',     '/checkout/success',  0,    0),
('2026-09-04 10:05:00', 102, 'pageview',     '/home',              0, 1500),
('2026-09-04 10:06:00', 102, 'pageview',     '/category/books',    0, 5000),
('2026-09-04 10:07:00', 103, 'pageview',     '/home',              0,  900),
('2026-09-04 10:08:00', 103, 'product_view', '/product/103',     103, 2500),
('2026-09-04 10:09:00', 107, 'pageview',     '/docs',              0, 4200),
('2026-09-04 10:10:00', 108, 'pageview',     '/home',              0, 1300),

-- 2026-09-05 (день 2)
('2026-09-05 11:00:00', 101, 'pageview',     '/home',              0, 1100),
('2026-09-05 11:01:00', 101, 'product_view', '/product/101',     101, 2900),
('2026-09-05 11:02:00', 104, 'pageview',     '/home',              0, 2000),
('2026-09-05 11:03:00', 104, 'product_view', '/product/104',     104, 7000),
('2026-09-05 11:04:00', 104, 'add_to_cart',  '/cart',            104,    0),
('2026-09-05 11:05:00', 104, 'checkout',     '/checkout',          0,    0),
('2026-09-05 11:06:00', 104, 'purchase',     '/checkout/success',  0,    0),
('2026-09-05 11:07:00', 105, 'pageview',     '/home',              0,  800),
('2026-09-05 11:08:00', 107, 'pageview',     '/category/books',    0, 3600),
('2026-09-05 11:09:00', 108, 'pageview',     '/home',              0, 2500),
('2026-09-05 11:10:00', 108, 'product_view', '/product/102',     102, 2200),
('2026-09-05 11:11:00', 108, 'add_to_cart',  '/cart',            102,    0),

-- 2026-09-06 (день 3)
('2026-09-06 12:00:00', 101, 'pageview',     '/home',              0, 1050),
('2026-09-06 12:01:00', 102, 'pageview',     '/category/books',    0, 4800),
('2026-09-06 12:02:00', 102, 'product_view', '/product/103',     103, 3100),
('2026-09-06 12:03:00', 105, 'pageview',     '/docs',              0, 6100),
('2026-09-06 12:04:00', 105, 'product_view', '/product/105',     105, 4300),
('2026-09-06 12:05:00', 105, 'add_to_cart',  '/cart',            105,    0),
('2026-09-06 12:06:00', 105, 'checkout',     '/checkout',          0,    0),
('2026-09-06 12:07:00', 105, 'purchase',     '/checkout/success',  0,    0),
('2026-09-06 12:08:00', 107, 'pageview',     '/home',              0, 1400),
('2026-09-06 12:09:00', 109, 'pageview',     '/home',              0, 1700),
('2026-09-06 12:10:00', 109, 'product_view', '/product/105',     105, 3300),
('2026-09-06 12:11:00', 109, 'add_to_cart',  '/cart',            105,    0),

-- 2026-09-07 (день 4)
('2026-09-07 13:00:00', 101, 'pageview',     '/home',              0, 1000),
('2026-09-07 13:01:00', 101, 'product_view', '/product/101',     101, 3100),
('2026-09-07 13:02:00', 101, 'add_to_cart',  '/cart',            101,    0),
('2026-09-07 13:03:00', 101, 'checkout',     '/checkout',          0,    0),
('2026-09-07 13:04:00', 101, 'purchase',     '/checkout/success',  0,    0),
('2026-09-07 13:05:00', 106, 'pageview',     '/home',              0, 1800),
('2026-09-07 13:06:00', 106, 'product_view', '/product/106',     106, 1200),
('2026-09-07 13:07:00', 107, 'pageview',     '/docs',              0, 5200),
('2026-09-07 13:08:00', 108, 'pageview',     '/home',              0, 1250),
('2026-09-07 13:09:00', 109, 'pageview',     '/category/books',    0, 4400);
```

## 📈 Аналитические запросы

### 1. DAU за последний день

```sql
SELECT uniq(visitor_id) AS dau
FROM events
WHERE toDate(event_time) = '2026-09-07';
```

**Результат:**
| dau |
|-----|
| 5   |

> **Бизнес-смысл:** DAU (Daily Active Users) — базовая метрика вовлечённости. На маркетплейсе считается за день и используется для оценки трафика и нагрузки.

### 2. Топ страниц по просмотрам

```sql
SELECT
    url,
    count()                 AS views,
    round(avg(duration_ms)) AS avg_duration_ms
FROM events
WHERE event_type = 'pageview'
GROUP BY url
ORDER BY views DESC
LIMIT 5;
```

**Результат:**
| url             | views | avg_duration_ms |
|-----------------|-------|-----------------|
| /home           | 14    | 1393            |
| /category/books | 4     | 4450            |
| /docs           | 3     | 5167            |

> **Бизнес-смысл:** топ страниц показывает, куда идёт трафик. Главная — точка входа, категории и карточки — точки интереса. Высокая длительность = вовлечённость.

### 3. Динамика по дням

```sql
SELECT
    toDate(event_time) AS day,
    count()            AS total_events,
    uniq(visitor_id)   AS unique_visitors
FROM events
GROUP BY day
ORDER BY day;
```

**Результат:**
| day        | total_events | unique_visitors |
|------------|--------------|-----------------|
| 2026-09-04 | 11           | 5               |
| 2026-09-05 | 12           | 5               |
| 2026-09-06 | 12           | 5               |
| 2026-09-07 | 10           | 5               |

> **Бизнес-смысл:** динамика трафика по дням — основа для отслеживания трендов и сезонности маркетплейса.

### 4. Воронка покупки

```sql
SELECT
    event_type,
    count()          AS total,
    uniq(visitor_id) AS unique_visitors
FROM events
WHERE event_type IN ('pageview', 'product_view', 'add_to_cart', 'checkout', 'purchase')
GROUP BY event_type
ORDER BY total DESC;
```

**Результат:**
| event_type   | total | unique_visitors |
|--------------|-------|-----------------|
| pageview     | 21    | 9               |
| product_view | 10    | 8               |
| add_to_cart  | 6     | 5               |
| purchase     | 4     | 3               |
| checkout     | 4     | 3               |

> **Бизнес-смысл:** воронка покупки — ключевая метрика маркетплейса. Показывает, на каком шаге теряются пользователи. Сравнивая `unique_visitors` по шагам, можно посчитать конверсию между этапами.

### 5. Топ-5 посетителей по активности

```sql
SELECT
    visitor_id,
    count()                 AS events_count,
    round(avg(duration_ms)) AS avg_duration_ms
FROM events
GROUP BY visitor_id
ORDER BY events_count DESC
LIMIT 5;
```

**Результат:**
| visitor_id | events_count | avg_duration_ms |
|------------|--------------|-----------------|
| 101        | 13           | 1058            |
| 105        | 6            | 1867            |
| 104        | 5            | 1800            |
| 108        | 5            | 1450            |
| 107        | 4            | 3600            |


> **Бизнес-смысл:** самые активные пользователи — ядро аудитории. Их поведение — образец для анализа.

### 6. Retention

```sql
SELECT
    visitor_id,
    uniq(toDate(event_time)) AS active_days
FROM events
GROUP BY visitor_id
HAVING active_days > 1
ORDER BY active_days DESC;
```

**Результат:**
| visitor_id | active_days |
|------------|-------------|
| 107        | 4           |
| 101        | 4           |
| 108        | 3           |
| 105        | 2           |
| 109        | 2           |
| 102        | 2           |

> **Бизнес-смысл:** retention показывает, сколько дней пользователь возвращался. Высокий retention = продукт удерживает аудиторию.

### 7. Средняя длительность по страницам

```sql
SELECT
    url,
    round(avg(duration_ms)) AS avg_duration_ms,
    count()                 AS views
FROM events
WHERE event_type = 'pageview'
GROUP BY url
HAVING views >= 2
ORDER BY avg_duration_ms DESC;
```

**Результат:**
| url             | avg_duration_ms | views |
|-----------------|-----------------|-------|
| /docs           | 5167            | 3     |
| /category/books | 4450            | 4     |
| /home           | 1393            | 14    |

> **Бизнес-смысл:** страницы с высокой длительностью — самые вовлекающие. `/docs` и категории — точки глубокого интереса. Главная — транзитная страница.

### 8. Пользователи, дошедшие до покупки

```sql
SELECT
    visitor_id,
    countIf(event_type = 'product_view') AS product_views,
    countIf(event_type = 'add_to_cart')  AS add_to_cart,
    countIf(event_type = 'checkout')     AS checkouts,
    countIf(event_type = 'purchase')     AS purchases
FROM events
GROUP BY visitor_id
HAVING purchases > 0
ORDER BY purchases DESC;
```

**Результат:**
| visitor_id | product_views | add_to_cart | checkouts | purchases |
|------------|---------------|-------------|-----------|-----------|
| 101        | 3             | 2           | 2         | 2         |
| 104        | 1             | 1           | 1         | 1         |
| 105        | 1             | 1           | 1         | 1         |

> **Бизнес-смысл:** пользователи, дошедшие до покупки — самые ценные для маркетплейса. Их путь по воронке можно использовать как эталон при поиске точек роста конверсии.

### 9. Просмотры товаров с названием и категорией (JOIN)

```sql
SELECT
    e.visitor_id,
    p.product_name,
    p.category,
    p.price,
    e.event_time
FROM events e
JOIN products p ON e.product_id = p.product_id
WHERE e.event_type = 'product_view'
ORDER BY e.event_time
LIMIT 10;
```

**Результат:**
| visitor_id | product_name    | category       | price | event_time          |
|------------|-----------------|----------------|-------|---------------------|
| 101        | Смартфон X      | Электроника    | 45000 | 2026-09-04 10:01:00 |
| 103        | Книга "SQL"     | Книги          | 1200  | 2026-09-04 10:08:00 |
| 101        | Смартфон X      | Электроника    | 45000 | 2026-09-05 11:01:00 |
| 104        | Кофемашина Z    | Дом            | 35000 | 2026-09-05 11:03:00 |
| 108        | Наушники Y      | Электроника    | 8000  | 2026-09-05 11:10:00 |
| 102        | Книга "SQL"     | Книги          | 1200  | 2026-09-06 12:02:00 |
| 105        | Беговая дорожка | Спорт          | 60000 | 2026-09-06 12:04:00 |
| 109        | Беговая дорожка | Спорт          | 60000 | 2026-09-06 12:10:00 |
| 101        | Смартфон X      | Электроника    | 45000 | 2026-09-07 13:01:00 |
| 106        | Конструктор     | Детские товары | 2500  | 2026-09-07 13:06:00 |

> **Бизнес-смысл:** JOIN со справочником товаров обогащает события названием, категорией и ценой. Это база для анализа «какие товары смотрят чаще всего» и «товары каких категорий интересны пользователям».

### 10. Топ категорий по просмотрам товаров (JOIN + GROUP BY)

```sql
SELECT
    p.category,
    count()                 AS product_views,
    uniq(e.visitor_id)      AS unique_visitors,
    round(avg(p.price))     AS avg_price
FROM events e
JOIN products p ON e.product_id = p.product_id
WHERE e.event_type = 'product_view'
GROUP BY p.category
ORDER BY product_views DESC;
```

**Результат:**
| category       | product_views | unique_visitors | avg_price |
|----------------|---------------|-----------------|-----------|
| Электроника    | 4             | 2               | 35750     |
| Книги          | 2             | 2               | 1200      |
| Спорт          | 2             | 2               | 60000     |
| Дом            | 1             | 1               | 35000     |
| Детские товары | 1             | 1               | 2500      |

> **Бизнес-смысл:** топ категорий по просмотрам — основа для категорийного менеджмента маркетплейса. Показывает, какие категории вызывают интерес, и какие товары смотрят, но не покупают.

### 11. Воронка по категориям (JOIN + условные агрегации)

```sql
SELECT
    p.category,
    countIf(e.event_type = 'product_view') AS product_views,
    countIf(e.event_type = 'add_to_cart')  AS add_to_cart,
    countIf(e.event_type = 'purchase')     AS purchases
FROM events e
JOIN products p ON e.product_id = p.product_id
GROUP BY p.category
ORDER BY product_views DESC;
```

**Результат:**
| category       | product_views | add_to_cart | purchases |
|----------------|---------------|-------------|-----------|
| Электроника    | 4             | 3           | 0         |
| Книги          | 2             | 0           | 0         |
| Спорт          | 2             | 2           | 0         |
| Дом            | 1             | 1           | 0         |
| Детские товары | 1             | 0           | 0         |

> **Бизнес-смысл:** воронка в разрезе категорий показывает, где теряются пользователи на уровне товарной группы. Где-то высокая конверсия в корзину, где-то — низкая. Это точки для продуктовых и маркетинговых решений.

## 📁 Структура проекта

```
clickhouse-marketplace-web-analytics/
├── README.md
├── schema.sql        # CREATE TABLE events + products
├── insert_data.sql   # INSERT в обе таблицы
└── queries.sql       # аналитические запросы
```

## 📌 Что демонстрирует проект

- Понимание разницы между OLTP и OLAP (PostgreSQL vs ClickHouse).
- Навык проектирования **нескольких таблиц** под аналитические нагрузки.
- Умение писать аналитические запросы на диалекте ClickHouse.
- Знание оптимизаций: партиционирование, `LowCardinality`, `ORDER BY` как индекс.
- Работа с продуктовыми метриками маркетплейса: DAU, воронка покупки, retention, топ страниц, топ категорий.
- Использование ClickHouse-специфичных функций: `uniq`, `countIf`, `toYYYYMM`.

## 🔗 Интерактивная демонстрация

[Открыть в SQLize.online — ClickHouse](https://sqlize.online/sql/clickhouse/3d57839f18ae033f995563311e9c764d/)

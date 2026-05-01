/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Наместникова Софья
 * Дата: 25 апреля 2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
WITH user_info AS (
  SELECT
    count(u.id) AS all_users,
    count(CASE WHEN u.payer = 1 THEN 1 END) AS paying_users
  FROM fantasy.users u
)
SELECT
  all_users, -- общее количество игроков, зарегистрированных в игре
  paying_users, -- количество платящих игроков
  CAST(paying_users AS FLOAT) / all_users * 100 AS paying_users_share -- доля платящих игроков от общего количества игроков
FROM user_info;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
WITH stats_by_race AS (
	SELECT 
		r.race AS race,
		SUM(u.payer) AS paying_by_race,
		COUNT(u.id) AS all_users_by_race
	FROM fantasy.race r LEFT JOIN fantasy.users u ON r.race_id = u.race_id
	GROUP BY r.race
)
SELECT 
	race, -- раса персонажа
	paying_by_race, -- количество платящих игроков этой расы
	all_users_by_race, -- общее количество зарегистрированных игроков этой расы
	CAST(paying_by_race AS FLOAT) / all_users_by_race * 100 AS paying_users_share_by_race -- доля платящих по расам
FROM stats_by_race 
ORDER BY paying_users_share_by_race DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT 
	COUNT(e.transaction_id) AS all_purchases, -- общее количество покупок
	SUM(e.amount) AS total_amount, -- суммарная стоимость всех покупок
	MIN(e.amount) AS min_amount, -- минимальная стоимость покупки
	MAX(e.amount) AS max_amount, -- и максимальная стоимость покупки
	AVG(e.amount) AS avg_amount, -- среднее значение стоимости покупки
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY e.amount) AS median, -- медиана стоимости покупки
	STDDEV(e.amount) AS stddev -- стандартное отклонение стоимости покупки
FROM fantasy.events e;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
WITH purchase_info AS (
	SELECT 
		COUNT(CASE WHEN e.amount = 0 THEN 1 END) AS zero_amount_purchases_n, -- количество покупок с нулевой стоимостью
		COUNT(e.transaction_id) AS all_purchases -- общее количество покупок
	FROM fantasy.events e )
SELECT 
	zero_amount_purchases_n,
	CAST(zero_amount_purchases_n AS FLOAT) / all_purchases * 100 AS zero_amount_purchases_share -- доля покупок с нулевой стоимостью от общего кол-ва покупок
FROM purchase_info;
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH items_stats AS (
    SELECT
        i.game_items AS item,
        COUNT(e.transaction_id) AS purchases_n_by_item, 
        COUNT(DISTINCT e.id) AS buyers_n_by_item
    FROM fantasy.items i
    INNER JOIN fantasy.events e ON i.item_code = e.item_code
    WHERE amount > 0 
    GROUP BY i.game_items
),
general_stats AS (
    SELECT
        COUNT(transaction_id) AS all_purchases,
        COUNT(DISTINCT id) AS all_buyers
    FROM fantasy.events
    WHERE amount > 0 
)
SELECT
    i.item, -- название эпического предмета
    i.purchases_n_by_item, -- абсолютное кол-во внутриигровых продаж
    CAST(i.purchases_n_by_item AS FLOAT) / g.all_purchases * 100 AS purchase_share_pct, -- доля продажи каждого предмета от всех продаж
    i.buyers_n_by_item, -- абсолютное количество уникальных покупателей предмета
    CAST(i.buyers_n_by_item AS FLOAT) / g.all_buyers * 100 AS buyer_share_pct -- доля игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
FROM items_stats i, general_stats g
ORDER BY i.buyers_n_by_item DESC; -- сортировка по популярности эпического предмета среди игроков
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH registered AS (
    SELECT
        r.race,
        COUNT(u.id) AS registered_users_by_race
    FROM fantasy.race r
    LEFT JOIN fantasy.users u ON r.race_id = u.race_id
    GROUP BY r.race
),
buyers AS (
    SELECT
        r.race,
        COUNT(DISTINCT e.id) AS users_with_purchase, -- количество игроков, совершивших покупки
        COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS paying_buyers_by_race, -- количество платящих игроков по расам
        COUNT(e.transaction_id) AS purchases_by_race, -- кол-во покупок по расам
        AVG(e.amount) AS avg_purchase_amount, -- средняя стоимость одной покупки
        SUM(e.amount) AS total_amount_by_race -- общая стоимость всех покупок по расам
    FROM fantasy.events e
    JOIN fantasy.users u ON e.id = u.id
    JOIN fantasy.race r ON u.race_id = r.race_id
    WHERE e.amount > 0
    GROUP BY r.race
)
SELECT
    reg.race,
    reg.registered_users_by_race,
    b.users_with_purchase, 
    CAST(b.users_with_purchase AS FLOAT) / reg.registered_users_by_race * 100 AS users_with_purchase_share, -- доля игроков с покупками от количества зареганных
    CAST(b.paying_buyers_by_race AS FLOAT) / b.users_with_purchase * 100 AS paying_users_share, -- доля платящих от совершающих покупки
    CAST(b.purchases_by_race AS FLOAT) / b.users_with_purchase AS avg_purchases_per_buyer, -- среднее количество покупок
    b.avg_purchase_amount,
    b.total_amount_by_race / b.users_with_purchase AS avg_total_spend_per_buyer -- средняя суммарная стоимость
FROM registered reg
LEFT JOIN buyers b ON reg.race = b.race
ORDER BY avg_total_spend_per_buyer desc;

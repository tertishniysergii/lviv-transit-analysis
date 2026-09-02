CREATE OR REPLACE VIEW gtfs.v_hourly_intensity AS
WITH trip_start_times AS (
    SELECT
        trip_id,
        MIN(departure_time) AS start_time
    FROM gtfs.stop_times
    GROUP BY trip_id
),
classified_trips AS (
    SELECT
        t.trip_id,
        t.direction_id,
        r.route_short_name AS route_number,
        CASE r.route_type
            WHEN 0 THEN 'Трамвай'
            WHEN 800 THEN 'Тролейбус'
            WHEN 3 THEN 'Автобус'
            ELSE 'Інший транспорт'
        END AS transport_type,
        CASE
            WHEN c.monday = 1 AND c.friday = 1 THEN 'Будні (Пн-Пт)'
            WHEN c.saturday = 1 OR c.sunday = 1 THEN 'Вихідні (Сб-Нд)'
            ELSE 'Спецграфік'
        END AS day_type,
        tst.start_time::interval AS dep_time
    FROM gtfs.trips t
    JOIN trip_start_times tst ON t.trip_id = tst.trip_id
    JOIN gtfs.routes r ON t.route_id = r.route_id
    LEFT JOIN gtfs.calendar c ON t.service_id = c.service_id
),
gaps AS (
    SELECT
        day_type,
        transport_type,
        route_number,
        dep_time,
        EXTRACT(HOUR FROM dep_time)::int AS departure_hour,
        EXTRACT(EPOCH FROM (
            dep_time - LAG(dep_time) OVER (
                PARTITION BY day_type, transport_type, route_number, direction_id
                ORDER BY dep_time
            )
        )) / 60.0 AS gap_minutes
    FROM classified_trips
)
SELECT
    day_type,
    transport_type,
    route_number,
    departure_hour,
    COUNT(*) AS trips_count,
    ROUND(AVG(gap_minutes)::numeric, 1) AS avg_interval_minutes
FROM gaps
WHERE departure_hour BETWEEN 5 AND 23
  AND gap_minutes IS NOT NULL  
GROUP BY day_type, transport_type, route_number, departure_hour
ORDER BY transport_type, route_number, departure_hour;

select *
from gtfs.v_hourly_intensity vhi 

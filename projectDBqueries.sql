-- Question 1: Which route was most travelled by students, 
-- and what type of bus was preferred the most in that route?

column route_name format a40
column t_type format a7

SELECT table1.busid,
       bustype,
       rname as route_name,
       'Student' as t_type 
FROM (SELECT rn.busid,
             r.rname,
             'S' AS t_type,
             COUNT(*) AS num_tickets
      FROM Spring23_S003_15_Ticket t,
           Spring23_S003_15_Runson rn,
           Spring23_S003_15_Route r
      WHERE t_type = 'S'
      AND   t.busid = rn.busid
      AND   rn.routeid = r.routeid
      GROUP BY rn.busid,
               rn.routeid,
               r.rname
      HAVING COUNT(*) = (SELECT MAX(COUNT(*))
                         FROM Spring23_S003_15_Ticket s,
                              Spring23_S003_15_Runson rn,
                              Spring23_S003_15_Route r
                         WHERE t_type = 'S'
                         AND   s.busid = rn.busid
                         AND   rn.routeid = r.routeid
                         GROUP BY rn.busid,
                                  rn.routeid,
                                  r.rname)
      ORDER BY COUNT(*) DESC) table1
  INNER JOIN Spring23_S003_15_Bus bus ON table1.busid = bus.busid;
  





-- Question 2: What are the top revenue-generating routes for a given time period? 
-- (The highest revenue is subjective to the user.)

COLUMN rname format a40

SELECT r.rname AS route_name,
       SUM(t.cost) AS total_revenue
FROM Spring23_S003_15_Ticket t
  JOIN Spring23_S003_15_Runson rs ON t.busid = rs.busid
  JOIN Spring23_S003_15_Route r ON rs.routeid = r.routeid
WHERE t.t_datetime BETWEEN TO_DATE('2023-01-01','YYYY-MM-DD') AND TO_DATE('2023-01-31','YYYY-MM-DD')
GROUP BY r.rname
HAVING SUM(t.cost) > 500
ORDER BY total_revenue DESC;




-- Question 3: What are the most frequently traveled routes for a given period of time? 

COLUMN rname format a40 
COLUMN busiest_route format a40

SELECT '6:30 - 10:00' AS time_range,
       r.rname AS busiest_route,
       COUNT(t.ticketid) AS ticket_count
FROM Spring23_S003_15_Ticket t
  JOIN Spring23_S003_15_Runson rs ON t.busid = rs.busid
  JOIN Spring23_S003_15_Route r ON rs.routeid = r.routeid
WHERE TO_CHAR(t.t_datetime,'HH24:MI') BETWEEN '06:30' AND '10:00'
GROUP BY r.rname
HAVING COUNT(t.ticketid) = (SELECT MAX(ticket_count)
                            FROM (SELECT COUNT(ticketid) AS ticket_count
                                  FROM Spring23_S003_15_Ticket
                                  WHERE TO_CHAR(t_datetime,'HH24:MI') BETWEEN '06:30' AND '10:00'
                                  GROUP BY busid) temp);

  



-- Question 4: What are the peak hours in a day for a given time period?

COLUMN peak_hours format a15

SELECT hour_group AS peak_hours,
       SUM(t_count) AS tickets_sold
FROM (SELECT hour_interval || ' - ' || TO_CHAR(TO_DATE(hour_interval,'HH24:MI') +INTERVAL '1' HOUR,'HH24:MI') AS hour_group,
             SUM(ticket_count) AS t_count
      FROM (SELECT TO_CHAR(TRUNC(t_datetime,'HH24'),'HH24:MI') AS hour_interval,
                   COUNT(ticketid) AS ticket_count
            FROM Spring23_S003_15_Ticket
            WHERE t_datetime >= TO_DATE('2023-01-01','YYYY-MM-DD')
            -- Start date of the month
            AND   t_datetime < TO_DATE('2023-02-01','YYYY-MM-DD')
            -- End date of the month 
            GROUP BY TO_CHAR(TRUNC(t_datetime,'HH24'),'HH24:MI') -- Add hour_interval to GROUP 
                     ORDER BY ticket_count DESC)
      GROUP BY hour_interval)
GROUP BY hour_group
ORDER BY tickets_sold DESC fetch first 5 ROWS only;


-- Question 5: (Over) To give busiest days for each route (if in case, there are multiple busiest days, it will display them all)

column route_name format a50

SELECT
  r.rname AS route_name, busiest_day
FROM
  SPRING23_S003_15_ROUTE r
  LEFT JOIN (
    SELECT
      rs.routeid,
      TO_CHAR(t.t_datetime, 'DY') AS busiest_day,
      RANK() OVER (PARTITION BY rs.routeid ORDER BY COUNT(*) DESC) AS day_rank
    FROM
      SPRING23_S003_15_TICKET t
      JOIN SPRING23_S003_15_ROUTEHASSTOPS rs ON t.src_stop_id = rs.stopid
      JOIN SPRING23_S003_15_ROUTEHASSTOPS rd ON t.dest_stop_id = rd.stopid
    GROUP BY rs.routeid, TO_CHAR(t.t_datetime, 'DY')
  ) busiest_days ON r.routeid = busiest_days.routeid AND busiest_days.day_rank = 1
WHERE busiest_day IS NOT NULL
ORDER BY r.rname;


-- Question 6: Most travelled route for each Passenger type                        

column most_travelled_route format a40
column Passenger_type format a25

SELECT 
  CASE 
    WHEN t_type = 'S' THEN 'Student'
    WHEN t_type = 'SC' THEN 'Senior Citizen'
    WHEN t_type = 'PH' THEN 'Physically Handicapped'
    ELSE 'Regular'
  END AS Passenger_type, rname AS most_travelled_route
FROM (
  SELECT t.t_type, r.rname, COUNT(*) AS ticket_count,
         ROW_NUMBER() OVER (PARTITION BY t.t_type ORDER BY COUNT(*) DESC) AS rn
  FROM Spring23_S003_15_Ticket t
  JOIN Spring23_S003_15_Runson rs ON t.busid = rs.busid
  JOIN Spring23_S003_15_Route r ON rs.routeid = r.routeid
  GROUP BY t.t_type, r.rname
)
WHERE rn = 1;


-- Question 7: (Division) To find all Bus Depots which have all types of Buses available on them.

COLUMN Depot_name format a35

SELECT stopid AS Depot_id,
       stopname AS Depot_name
FROM SPRING23_S003_15_STOP
WHERE stopid IN (SELECT DISTINCT D.depotid
                 FROM SPRING23_S003_15_BUSDEPOT D
                 WHERE NOT EXISTS (SELECT T.bustype
                                   FROM SPRING23_S003_15_BUSTYPE T
                                   WHERE NOT EXISTS (SELECT B.busid
                                                     FROM SPRING23_S003_15_BUS B
                                                     WHERE B.depotid = D.depotid
                                                     AND   B.bustype = T.bustype)))
ORDER BY stopname ASC;



-- Question 8: (ROLLUP) For each route, list out the tickets sold for each bus type, 
-- using ROLLUP to get the subtotal and grandtotal.

COLUMN rname format a40

SELECT rname AS route_name,
       bustype,
       COUNT(*) AS ticket_count
FROM Spring23_S003_15_Ticket t
  JOIN Spring23_S003_15_Runson rn ON t.busid = rn.busid
  JOIN Spring23_S003_15_Route r ON rn.routeid = r.routeid
  JOIN Spring23_S003_15_bus b ON t.busid = b.busid
GROUP BY ROLLUP (rname,bustype)
ORDER BY rname,
         bustype;



-- Question 9: (CUBE) Generating a report for the number of tickets sold at each stop along a specific route, 
-- as well as for each stop alone, regardless of how many stops it belonged to. 

COLUMN route_name format a40 
COLUMN stop_name format a25

SELECT r.rname AS route_name,
       s.stopname AS stop_name,
       COUNT(*) AS ticket_count
FROM Spring23_S003_15_Ticket t
  INNER JOIN Spring23_S003_15_runson b ON t.busid = b.busid
  INNER JOIN Spring23_S003_15_Route r ON b.routeid = r.routeid
  INNER JOIN Spring23_S003_15_Stop s ON t.dest_stop_id = s.stopid
GROUP BY CUBE (r.rname,s.stopname)
ORDER BY r.rname,
         s.stopname;



-- Question 10: (CUBE) Analysing tickets sold for each route, for each passenger type and for each gender.

COLUMN route_name format a40 
COLUMN gender format a6 
COLUMN t_type format a6

SELECT t.t_type AS t_type,
       r.rname AS route_name,
       t.gender,
       COUNT(*) AS ticket_count
FROM Spring23_S003_15_Ticket t
  JOIN Spring23_S003_15_Runson rs ON t.busid = rs.busid
  JOIN Spring23_S003_15_Route r ON rs.routeid = r.routeid
GROUP BY CUBE (t.t_type,r.rname,t.gender)
ORDER BY t.t_type,
         r.rname,
         t.gender;









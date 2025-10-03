-- ==========================================================
-- Crimes LA – Final SQL Solutions (Q1–Q10)
-- ==========================================================

/* ----------------------------------------------------------
Q1. What is the total number of crimes for each crime status?
-----------------------------------------------------------*/
SELECT
  case_status_desc,
  COUNT(*) AS case_count
FROM report_t
GROUP BY case_status_desc;

/* ----------------------------------------------------------
Q2. Which was the most frequent crime committed each week?
   (rank per week and keep the #1)
-----------------------------------------------------------*/
SELECT
  week_number,
  crime_type,
  crimes_reported
FROM (
  SELECT
    week_number,
    crime_type,
    COUNT(*) AS crimes_reported,
    RANK() OVER (PARTITION BY week_number ORDER BY COUNT(*) DESC) AS high_crime_reported
  FROM report_t
  GROUP BY week_number, crime_type
) AS wk_crime
WHERE wk_crime.high_crime_reported = 1;

/* ----------------------------------------------------------
Q3. Does the existence of CCTV cameras deter crimes?
   (cases by area vs CCTV count)
-----------------------------------------------------------*/
SELECT
  l.area_name,
  l.cctv_count,
  COUNT(*) AS cases_reported
FROM report_t AS r
JOIN location_t AS l
  ON l.area_code = r.area_code
GROUP BY l.area_name, l.cctv_count
ORDER BY l.cctv_count DESC;

/* ----------------------------------------------------------
Q4. How much CCTV footage is available at crime scenes?
   (total cameras installed vs incidents with footage)
-----------------------------------------------------------*/
SELECT
  SUM(l.cctv_count) AS total_cctv_installed,
  SUM(CASE WHEN r.cctv_flag = 'TRUE' THEN 1 ELSE 0 END) AS total_cctv_footage_available
FROM report_t AS r
JOIN location_t AS l
  ON l.area_code = r.area_code;

/* ----------------------------------------------------------
Q5. Frequency of various complaint types
-----------------------------------------------------------*/
SELECT
  complaint_type,
  COUNT(*) AS cases_reported
FROM report_t
GROUP BY complaint_type;

/* ----------------------------------------------------------
Q6. Are crimes more by relations or strangers?
-----------------------------------------------------------*/
SELECT
  offender_relation,
  COUNT(*) AS count
FROM report_t
GROUP BY offender_relation;

/* ----------------------------------------------------------
Q7. Is crime more prevalent with high pop density, fewer officers,
    larger precinct area? (rollups per precinct)
-----------------------------------------------------------*/
SELECT
  o.precinct_code,
  SUM(l.population_density)               AS pop_density,
  COUNT(DISTINCT l.area_code)             AS total_areas,
  COUNT(DISTINCT o.officer_code)          AS total_officers,
  COUNT(r.report_no)                      AS cases_reported
FROM report_t AS r
JOIN location_t AS l
  ON l.area_code = r.area_code
JOIN officer_t AS o
  ON r.officer_code = o.officer_code
GROUP BY o.precinct_code
ORDER BY o.precinct_code;

/* ----------------------------------------------------------
Q8. At what parts of the day is the crime rate at its peak?
    (map time-of-day → dayparts, then rank per daypart+crime_type)
-----------------------------------------------------------*/
SELECT
  dayparts,
  crime_type,
  crimes_reported
FROM (
  SELECT
    CASE
      WHEN strftime('%H:%M', r.incident_time) >= '00:00' AND strftime('%H:%M', r.incident_time) < '05:00' THEN 'Midnight'
      WHEN strftime('%H:%M', r.incident_time) >= '05:01' AND strftime('%H:%M', r.incident_time) < '12:00' THEN 'Morning'
      WHEN strftime('%H:%M', r.incident_time) >= '12:01' AND strftime('%H:%M', r.incident_time) < '18:00' THEN 'Afternoon'
      WHEN strftime('%H:%M', r.incident_time) >= '18:01' AND strftime('%H:%M', r.incident_time) <= '21:00' THEN 'Evening'
      ELSE 'Night'
    END                           AS dayparts,
    r.crime_type,
    COUNT(r.report_no)            AS crimes_reported,
    RANK() OVER (
      PARTITION BY
        CASE
          WHEN strftime('%H:%M', r.incident_time) >= '00:00' AND strftime('%H:%M', r.incident_time) < '05:00' THEN 'Midnight'
          WHEN strftime('%H:%M', r.incident_time) >= '05:01' AND strftime('%H:%M', r.incident_time) < '12:00' THEN 'Morning'
          WHEN strftime('%H:%M', r.incident_time) >= '12:01' AND strftime('%H:%M', r.incident_time) < '18:00' THEN 'Afternoon'
          WHEN strftime('%H:%M', r.incident_time) >= '18:01' AND strftime('%H:%M', r.incident_time) <= '21:00' THEN 'Evening'
          ELSE 'Night'
        END
      ORDER BY COUNT(r.report_no) DESC
    ) AS high_crime_rank
  FROM report_t AS r
  GROUP BY dayparts, r.crime_type
) AS t
WHERE t.high_crime_rank = 1;

/* ----------------------------------------------------------
Q9. Peak time-of-day per locality (same daypart mapping)
-----------------------------------------------------------*/
SELECT
  area_name,
  dayparts,
  cases_reported
FROM (
  SELECT
    l.area_name,
    CASE
      WHEN strftime('%H:%M', r.incident_time) >= '00:00' AND strftime('%H:%M', r.incident_time) < '05:00' THEN 'Midnight'
      WHEN strftime('%H:%M', r.incident_time) >= '05:01' AND strftime('%H:%M', r.incident_time) < '12:00' THEN 'Morning'
      WHEN strftime('%H:%M', r.incident_time) >= '12:01' AND strftime('%H:%M', r.incident_time) < '18:00' THEN 'Afternoon'
      WHEN strftime('%H:%M', r.incident_time) >= '18:01' AND strftime('%H:%M', r.incident_time) <= '21:00' THEN 'Evening'
      ELSE 'Night'
    END                        AS dayparts,
    COUNT(r.report_no)         AS cases_reported,
    RANK() OVER (
      PARTITION BY l.area_name
      ORDER BY COUNT(r.report_no) DESC
    )                          AS high_crime_rank
  FROM report_t AS r
  JOIN location_t AS l
    ON l.area_code = r.area_code
  GROUP BY l.area_name, dayparts
) AS d
WHERE d.high_crime_rank = 1;

/* ----------------------------------------------------------
Q10. Which age group is more likely to fall victim at certain dayparts?
    (age buckets + dayparts, then counts)
-----------------------------------------------------------*/
SELECT  
    CASE  
        WHEN strftime('%H', r.incident_time) >= '00' AND strftime('%H', 
r.incident_time) < '05' THEN 'Midnight' 
        WHEN strftime('%H', r.incident_time) >= '05' AND strftime('%H', 
r.incident_time) < '12' THEN 'Morning' 
        WHEN strftime('%H', r.incident_time) >= '12' AND strftime('%H', 
r.incident_time) < '17' THEN 'Afternoon' 
        WHEN strftime('%H', r.incident_time) >= '17' AND strftime('%H', 
r.incident_time) <= '20' THEN 'Evening' 
        ELSE 'Night'  
    END AS dayparts,  
    CASE  
        WHEN v.victim_age >= 0 AND v.victim_age <= 12 THEN 'Kids' 
        WHEN v.victim_age > 12 AND v.victim_age <= 23 THEN 'Teenage' 
        WHEN v.victim_age > 23 AND v.victim_age <= 35 THEN 'Middle age' 
        WHEN v.victim_age > 35 AND v.victim_age <= 55 THEN 'Adults' 
        WHEN v.victim_age > 55 THEN 'Old' 
        ELSE 'Unknown'  
    END AS age_cat,  
    COUNT(*) AS cases_reported  
FROM report_t AS r
JOIN victim_t AS v  
ON v.victim_code = r.victim_code  
GROUP BY dayparts, age_cat 
ORDER BY cases_reported DESC; 
 
 





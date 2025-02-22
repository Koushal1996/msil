DROP PROCEDURE MSIL_VEH_AVAILABILITY

^; 
create or replace PROCEDURE MSIL_VEH_AVAILABILITY(
    C OUT SYS_REFCURSOR,
    lcode IN VARCHAR2)
    AS
BEGIN
OPEN C FOR   
WITH T1 AS
  (SELECT EIM_REGN_NO,
    EIM_MESSAGE_RECIEVED_TIME,
    EIM_LATITUDE,
    EIM_LONGITUDE,
    eim_message_created_time,
    ROW_NUMBER() OVER (PARTITION BY EIM_REGN_NO ORDER BY eim_message_created_time DESC) RN
  FROM ETRK_IN_MSGS_TRANS
  WHERE EXISTS
    (SELECT 1
    FROM ETRK_MUL_NEWTRIP
    WHERE TRIP_REGN_NO = EIM_REGN_NO
    AND TRIP_STATUS    > 2
    ) -- changed here
     
  )
  ,
  T2 AS
  (
  SELECT T.*,L.LATITUDE,L.LONGITUDE,
    DISTANCE_CALCULATOR(EIM_LONGITUDE,EIM_LATITUDE,L.LONGITUDE, L.LATITUDE) as DIST ,-- added distance calculator function
    ROW_NUMBER() OVER (PARTITION BY EIM_REGN_NO,DISTANCE_CALCULATOR(EIM_LONGITUDE,EIM_LATITUDE,L.LONGITUDE, L.LATITUDE) 
                      ORDER BY EIM_REGN_NO ASC ,DISTANCE_CALCULATOR(EIM_LONGITUDE,EIM_LATITUDE,L.LONGITUDE, L.LATITUDE) ASC,
                      EIM_MESSAGE_CREATED_TIME DESC) R
  FROM T1 T
  CROSS JOIN MSIL_OEM_LOC_CODE_MST_L2_GJ L
  WHERE CODE=lcode
  )
  SELECT COUNT(*),
  CASE
     WHEN DIST<=30 AND DIST >=0
    THEN '0 TO 30'
    WHEN DIST<=60 AND DIST  >30
    THEN '30.1 TO 60'
    WHEN DIST<=150 AND DIST  >60
    THEN '60.1 TO 150'
    ELSE '>150'
  END "DISTANCE"
FROM T2 t
WHERE t.R=1 
GROUP BY
  CASE
    WHEN DIST<=30 AND DIST >=0
    THEN '0 TO 30'
    WHEN DIST<=60 AND DIST  >30
    THEN '30.1 TO 60'
    WHEN DIST<=150 AND DIST  >60
    THEN '60.1 TO 150'
    ELSE '>150'
  END
ORDER BY
  CASE
     WHEN DIST<=30 AND DIST >=0
    THEN '0 TO 30'
    WHEN DIST<=60 AND DIST  >30
    THEN '30.1 TO 60'
    WHEN DIST<=150 AND DIST  >60
    THEN '60.1 TO 150'
    ELSE '>150'
  END  ;
  
END MSIL_VEH_AVAILABILITY;

^; 

DROP FUNCTION DISTANCE_CALCULATOR

^; 
create or replace FUNCTION DISTANCE_CALCULATOR 
(nLastMsgLongitude1 in Float,nLastMsgLatitude1  in Float,NEW_EIM_LONGITUDE1  in Float,NEW_EIM_LATITUDE1 in Float)
RETURN FLOAT 
IS

    X1 Float;
    Y1 Float;
    Z1 Float;
    X2 Float;
    Y2 Float;
    Z2 Float;
    D  Float;
    THETA  Float;
    ER Float  := 6366.707;
    nLastMsgLatitude FLOAT;
    nLastMsgLongitude FLOAT;
    NEW_EIM_LATITUDE FLOAT;
    NEW_EIM_LONGITUDE FLOAT;

BEGIN

    NEW_EIM_LONGITUDE:= NEW_EIM_LONGITUDE1;
    NEW_EIM_LATITUDE:=  NEW_EIM_LATITUDE1;
    
    nLastMsgLatitude:=  nLastMsgLatitude1;
    nLastMsgLongitude :=nLastMsgLongitude1;
    nLastMsgLatitude:=(((22/7)*nLastMsgLatitude)/180);
    nLastMsgLongitude:=(((22/7)*nLastMsgLongitude)/180);
    
    NEW_EIM_LATITUDE:=(((22/7)*NEW_EIM_LATITUDE)/180);
    NEW_EIM_LONGITUDE:=(((22/7)*NEW_EIM_LONGITUDE)/180);
    nLastMsgLatitude:=((22/7)/2)-nLastMsgLatitude;
    NEW_EIM_LATITUDE:=((22/7)/2)-NEW_EIM_LATITUDE;
    
    X1:= ER*COS(nLastMsgLongitude)*SIN(nLastMsgLatitude);
    Y1:= ER*SIN(nLastMsgLatitude)*SIN(nLastMsgLongitude);
    Z1:= ER*COS(nLastMsgLatitude);
    
    X2:= ER*COS(NEW_EIM_LONGITUDE)*SIN(NEW_EIM_LATITUDE);
    Y2:= ER*SIN(NEW_EIM_LATITUDE)*SIN(NEW_EIM_LONGITUDE);
    Z2:= ER*COS(NEW_EIM_LATITUDE);
    
    D:=SQRT((X1-X2)*(X1-X2)+(Y1-Y2)*(Y1-Y2)+(Z1-Z2)*(Z1-Z2));
    
    THETA:=ACOS( ((ER*ER)+(ER*ER)-(D*D)) /(2*ER*ER)) ;

RETURN(ROUND((THETA*ER),3));

END DISTANCE_CALCULATOR;

^; 

DROP PROCEDURE MSIL_TOTALTRIPS3

^; 

create or replace PROCEDURE MSIL_TOTALTRIPS3 
( 
    C OUT SYS_REFCURSOR, 
    P_FROM_DATE IN DATE, 
    P_TO_DATE   IN DATE) 
AS  
BEGIN 
  OPEN C FOR SELECT X.CNT,"MONTH" FROM 
  (SELECT EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH",COUNT(*) CNT 
  FROM ETRK_MUL_NEWTRIP 
  WHERE (TRIP_INV_DATE >= P_FROM_DATE 
  AND TRIP_INV_DATE    <= P_TO_DATE) 
  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') 
  GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE)  
  UNION 
  SELECT EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH",COUNT(*) CNT 
  FROM ETRK_MUL_NEWTRIP_HIST 
  WHERE (TRIP_INV_DATE >= P_FROM_DATE 
  AND TRIP_INV_DATE    <= P_TO_DATE) 
  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate) 
  GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE) 
  ) X ORDER BY "MONTH"; 
   
END MSIL_TOTALTRIPS3; 
 
^; 
 
DROP PROCEDURE MSIL_OPENTRIPS3 

^; 
create or replace PROCEDURE MSIL_OPENTRIPS3  
( 
    C OUT SYS_REFCURSOR, 
    P_FROM IN DATE, 
    P_TO IN DATE, 
    PRESENT_PAST VARCHAR2) 
AS 
from_date VARCHAR2(20) := to_char(P_FROM,'dd-MM-YY') || '00:00:00'; 
end_date VARCHAR2(20) := to_char(P_TO,'dd-MM-YY') || '23:59:59'; 
BEGIN 
  IF PRESENT_PAST = 'PRESENT' THEN 
    OPEN C FOR SELECT COUNT(*) CNT FROM ETRK_MUL_NEWTRIP WHERE TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') AND 
TRIP_STATUS = 1 AND TRIP_ONWD_COMP_DATE IS NULL; --ahead cases 
  ELSE 
    OPEN C FOR SELECT X.CNT,"MONTH" FROM 
    (SELECT COUNT(*) CNT, EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH" 
    FROM ETRK_MUL_NEWTRIP 
    WHERE TRIP_INV_DATE BETWEEN TO_DATE( from_date,'DD-MM-YY HH24:MI:SS') AND TO_DATE( end_date,'DD-MM-YY 
HH24:MI:SS') 
    AND (TRIP_AUTO_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_AUTO_CLOSURE_DATE IS NULL) 
    AND (TRIP_COMPLETED_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_COMPLETED_DATE IS NULL) 
    AND (TRIP_ONWD_COMP_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_ONWD_COMP_DATE IS NULL) 
    AND (PROXY_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR PROXY_CLOSURE_DATE IS NULL) 
    AND TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate) 
    GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE) 
    UNION 
     
    SELECT COUNT(*) CNT,EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH" 
    FROM ETRK_MUL_NEWTRIP_HIST 
    WHERE TRIP_INV_DATE BETWEEN TO_DATE( from_date,'DD-MM-YY HH24:MI:SS') AND TO_DATE( end_date,'DD-MM-YY      
HH24:MI:SS') 
    AND (TRIP_AUTO_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_AUTO_CLOSURE_DATE IS NULL) 
    AND (TRIP_COMPLETED_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_COMPLETED_DATE IS NULL) 
    AND (TRIP_ONWD_COMP_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_ONWD_COMP_DATE IS NULL) 
    AND (PROXY_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR PROXY_CLOSURE_DATE IS NULL) 
    AND TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate) 
    GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE) 
    ) X ORDER BY "MONTH"; 
  END IF; 
 
END MSIL_OPENTRIPS3; 

^; 
 
 DROP PROCEDURE MSIL_CLOSEDTRIPS3 

^; 
Create or replace PROCEDURE MSIL_CLOSEDTRIPS3 
( 
C OUT SYS_REFCURSOR, 
P_FROM_DATE IN DATE, 
P_TO_DATE IN DATE 
) 
AS 
BEGIN 
OPEN C FOR 
Select X.CNT, "Month" from ( 
SELECT COUNT(*) CNT,extract(month from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, 
TRIP_COMPLETED_DATE,     TRIP_AUTO_CLOSURE_DATE)) "Month" 
FROM ETRK_MUL_NEWTRIP 
WHERE 
COALESCE(TRIP_ONWD_COMP_DATE,PROXY_CLOSURE_DATE,TRIP_COMPLETED_DATE,TRIP_AUTO_CLOSURE_DATE)>=P_FROM_DATE AND 
COALESCE(TRIP_ONWD_COMP_DATE,PROXY_CLOSURE_DATE,TRIP_COMPLETED_DATE,TRIP_AUTO_CLOSURE_DATE)<=P_TO_DATE 
AND TRIP_INV_DATE >= TO_DATE('01-01-19','DD-MM-YY') 
Group by extract(month from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, 
TRIP_AUTO_CLOSURE_DATE)) 
UNION 
SELECT COUNT(*) CNT,extract(month from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, 
TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)) "Month" 
FROM ETRK_MUL_NEWTRIP_HIST 
WHERE 
COALESCE(TRIP_ONWD_COMP_DATE,PROXY_CLOSURE_DATE,TRIP_COMPLETED_DATE,TRIP_AUTO_CLOSURE_DATE)>=P_FROM_DATE 
AND 
COALESCE(TRIP_ONWD_COMP_DATE,PROXY_CLOSURE_DATE,TRIP_COMPLETED_DATE,TRIP_AUTO_CLOSURE_DATE)<=P_TO_DATE 
AND TRIP_INV_DATE >= TO_DATE('01-01-19','DD-MM-YY') 
Group by extract(month from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, 
TRIP_AUTO_CLOSURE_DATE)) 
 
 
)X order by "Month"; 
 
 END MSIL_CLOSEDTRIPS3; 
 
^; 
 
DROP PROCEDURE MSIL_DELAYTRIPS3

^; 
create or replace PROCEDURE MSIL_DELAYTRIPS3 
( 
    C OUT SYS_REFCURSOR, 
    P_FROM_DATE IN DATE, 
    P_TO_DATE IN DATE 
    )  
  AS  
 BEGIN 
  OPEN C FOR SELECT X.CNT,"MONTH" FROM 
  (SELECT EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH",COUNT(*) CNT 
  FROM ETRK_MUL_NEWTRIP 
  WHERE (TRIP_INV_DATE >= P_FROM_DATE 
  AND TRIP_INV_DATE    <= P_TO_DATE) 
  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate) 
  AND TRIP_ETA_STATUS LIKE 'DELAY%' 
  GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE) 
  UNION 
   SELECT EXTRACT(MONTH FROM TRIP_INV_DATE) "MONTH",COUNT(*) CNT 
  FROM ETRK_MUL_NEWTRIP_HIST 
  WHERE (TRIP_INV_DATE >= P_FROM_DATE 
  AND TRIP_INV_DATE    <= P_TO_DATE) 
  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate) 
  AND TRIP_ETA_STATUS LIKE 'DELAY%' 
  GROUP BY EXTRACT(MONTH FROM TRIP_INV_DATE) 
  ) X ORDER BY "MONTH"; 
   
   
END MSIL_DELAYTRIPS3; 
 
^; 
  
DROP PROCEDURE MSIL_TOTALTRIPS4

^; 
create or replace PROCEDURE MSIL_TOTALTRIPS4 
(  
    C OUT SYS_REFCURSOR,  
    P_FROM_DATE IN DATE,  
    P_TO_DATE   IN DATE)  
AS   
BEGIN  
  OPEN C FOR SELECT X.CNT,"YEAR" FROM  
  (SELECT EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR",COUNT(*) CNT  
  FROM ETRK_MUL_NEWTRIP  
  WHERE (TRIP_INV_DATE >= P_FROM_DATE  
  AND TRIP_INV_DATE    <= P_TO_DATE)  
--  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY')  
  GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)   
  UNION  
  SELECT EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR",COUNT(*) CNT  
  FROM ETRK_MUL_NEWTRIP_HIST  
  WHERE (TRIP_INV_DATE >= P_FROM_DATE  
  AND TRIP_INV_DATE    <= P_TO_DATE)  
--  AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate)  
  GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)  
  ) X ORDER BY "YEAR";  
    
END MSIL_TOTALTRIPS4;

^; 
  
  DROP PROCEDURE MSIL_OPENTRIPS4
^; 

create or replace PROCEDURE MSIL_OPENTRIPS4 
(
    C OUT SYS_REFCURSOR,
    P_FROM IN DATE,
    P_TO IN DATE,
    PRESENT_PAST VARCHAR2)
AS
from_date VARCHAR2(20) := to_char(P_FROM,'dd-MM-YY') || '00:00:00';
end_date VARCHAR2(20) := to_char(P_TO,'dd-MM-YY') || '23:59:59';
BEGIN
  IF PRESENT_PAST = 'PRESENT' THEN
    OPEN C FOR SELECT COUNT(*) CNT FROM ETRK_MUL_NEWTRIP WHERE TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') AND TRIP_STATUS = 1 AND TRIP_ONWD_COMP_DATE IS NULL; --ahead cases
  ELSE
    OPEN C FOR SELECT X.CNT,"YEAR" FROM
    (SELECT COUNT(*) CNT, EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR"
    FROM ETRK_MUL_NEWTRIP
    WHERE TRIP_INV_DATE BETWEEN TO_DATE( from_date,'DD-MM-YY HH24:MI:SS') AND TO_DATE( end_date,'DD-MM-YY HH24:MI:SS')
    AND (TRIP_AUTO_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_AUTO_CLOSURE_DATE IS NULL)
    AND (TRIP_COMPLETED_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_COMPLETED_DATE IS NULL)
    AND (TRIP_ONWD_COMP_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_ONWD_COMP_DATE IS NULL)
    AND (PROXY_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR PROXY_CLOSURE_DATE IS NULL)
   -- AND TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate)
    GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)
    UNION
    
    SELECT COUNT(*) CNT,EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR"
    FROM ETRK_MUL_NEWTRIP_HIST
    WHERE TRIP_INV_DATE BETWEEN TO_DATE( from_date,'DD-MM-YY HH24:MI:SS') AND TO_DATE( end_date,'DD-MM-YY HH24:MI:SS')
    AND (TRIP_AUTO_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_AUTO_CLOSURE_DATE IS NULL)
    AND (TRIP_COMPLETED_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_COMPLETED_DATE IS NULL)
    AND (TRIP_ONWD_COMP_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR TRIP_ONWD_COMP_DATE IS NULL)
    AND (PROXY_CLOSURE_DATE > TO_DATE(end_date,'DD-MM-YY HH24:MI:SS') OR PROXY_CLOSURE_DATE IS NULL)
   -- AND TRIP_INV_DATE >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate)
    GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)
    ) X ORDER BY "YEAR";
  END IF;

  
  
END MSIL_OPENTRIPS4;

^; 
  
DROP PROCEDURE MSIL_CLOSEDTRIPS4

^; 
create or replace PROCEDURE MSIL_CLOSEDTRIPS4
(
    C OUT SYS_REFCURSOR,
    P_FROM_DATE IN DATE,
    P_TO_DATE IN DATE
    ) 
AS 
BEGIN
 OPEN C FOR 
  Select X.CNT, "YEAR" from (
  SELECT COUNT(*) CNT,extract(YEAR from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)) "YEAR"
  FROM ETRK_MUL_NEWTRIP
  WHERE COALESCE(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)>=P_FROM_DATE
  AND COALESCE(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)<=P_TO_DATE
 -- AND TRIP_INV_DATE >= TO_DATE('01-01-19','DD-MM-YY')
  group by extract(YEAR from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE))
  
 
  UNION

  SELECT COUNT(*) CNT,extract(YEAR from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)) "YEAR" 
  FROM ETRK_MUL_NEWTRIP_HIST
  WHERE COALESCE(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)>=P_FROM_DATE
  AND COALESCE(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE)<=P_TO_DATE
  --AND TRIP_INV_DATE >= TO_DATE('01-01-19','DD-MM-YY')
  group by extract(YEAR from coalesce(TRIP_ONWD_COMP_DATE, PROXY_CLOSURE_DATE, TRIP_COMPLETED_DATE, TRIP_AUTO_CLOSURE_DATE))
 

  )X order by "YEAR";
  
  END MSIL_CLOSEDTRIPS4;
  
 ^; 
  
  DROP PROCEDURE MSIL_DELAYTRIPS4
  
  
  ^; 
  create or replace PROCEDURE MSIL_DELAYTRIPS4 

(
    C OUT SYS_REFCURSOR,
    P_FROM_DATE IN DATE,
    P_TO_DATE IN DATE
    ) 
AS 
BEGIN
  OPEN C FOR SELECT X.CNT,"YEAR" FROM
  (SELECT EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR",COUNT(*) CNT
  FROM ETRK_MUL_NEWTRIP
  WHERE (TRIP_INV_DATE >= P_FROM_DATE
  AND TRIP_INV_DATE    <= P_TO_DATE)
 -- AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate)
  AND TRIP_ETA_STATUS LIKE 'DELAY%'
  GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)
  
  UNION
  
  SELECT EXTRACT(YEAR FROM TRIP_INV_DATE) "YEAR",COUNT(*) CNT
  FROM ETRK_MUL_NEWTRIP_HIST
  WHERE (TRIP_INV_DATE >= P_FROM_DATE
  AND TRIP_INV_DATE    <= P_TO_DATE)
 -- AND TRIP_INV_DATE    >= TO_DATE('01-01-17','DD-MM-YY') -- HARD CODED (Since data before the date is not accurate)
  AND TRIP_ETA_STATUS LIKE 'DELAY%'
  GROUP BY EXTRACT(YEAR FROM TRIP_INV_DATE)
  ) X ORDER BY "YEAR";
  
  

END MSIL_DELAYTRIPS4;


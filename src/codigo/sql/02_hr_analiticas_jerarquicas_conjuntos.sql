/* =====================================================================
   TEMA 4. FUNCIONES ANALÍTICAS (OVER)
   Calculan sobre un grupo de filas SIN juntarlas en una sola, como hace GROUP BY.
   ===================================================================== */

-- Caso 4.1: Consultar el ranking de salarios dentro de cada departamento
SELECT department_id, last_name, salary,
       ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS fila,     -- 1,2,3,4 (sin empates)
       RANK()       OVER (PARTITION BY department_id ORDER BY salary DESC) AS rango,    -- 1,2,2,4 (salta)
       DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rango_d   -- 1,2,2,3 (no salta)
FROM   employees
WHERE  department_id IN (50, 80)
ORDER  BY department_id, salary DESC;

-- Caso 4.2: Consultar los 2 empleados mejor pagados de cada departamento (ranking + vista en línea)
SELECT *
FROM  (SELECT department_id, last_name, salary,
              DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rango
       FROM   employees)
WHERE  rango <= 2
ORDER  BY department_id, rango;

-- Caso 4.3: Consultar cada empleado con el promedio y el total de su departamento, sin GROUP BY
SELECT last_name, department_id, salary,
       ROUND(AVG(salary) OVER (PARTITION BY department_id)) AS prom_depto,
       SUM(salary)       OVER (PARTITION BY department_id)  AS nomina_depto,
       ROUND(100 * RATIO_TO_REPORT(salary) OVER (PARTITION BY department_id), 1) AS pct_de_la_nomina
FROM   employees
ORDER  BY department_id;

-- Caso 4.4: Consultar la nómina acumulada según la fecha de contratación (suma acumulada)
SELECT hire_date, last_name, salary,
       SUM(salary) OVER (ORDER BY hire_date, employee_id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado   -- desde la 1.ª fila hasta la actual
FROM   employees
ORDER  BY hire_date, employee_id;

-- Caso 4.5: Consultar quién se contrató antes y después de cada empleado en su departamento (LAG / LEAD)
SELECT department_id, last_name, hire_date,
       LAG(last_name)  OVER (PARTITION BY department_id ORDER BY hire_date) AS anterior,   -- fila de atrás
       LEAD(last_name) OVER (PARTITION BY department_id ORDER BY hire_date) AS siguiente,  -- fila de adelante
       hire_date - LAG(hire_date) OVER (PARTITION BY department_id ORDER BY hire_date) AS dias_desde_anterior
FROM   employees
WHERE  department_id IN (30, 60)
ORDER  BY department_id, hire_date;

-- Caso 4.6: Consultar el salario más alto y el más bajo de cada cargo al lado de cada empleado
SELECT job_id, last_name, salary,
       FIRST_VALUE(last_name) OVER (PARTITION BY job_id ORDER BY salary DESC) AS mejor_pagado,
       MAX(salary) OVER (PARTITION BY job_id) - salary AS le_falta_para_el_maximo
FROM   employees
ORDER  BY job_id, salary DESC;

-- Caso 4.7: Consultar los 5 salarios más altos (Top-N con FETCH FIRST, Oracle 12c+)
SELECT last_name, salary
FROM   employees
ORDER  BY salary DESC
FETCH  FIRST 5 ROWS WITH TIES;     -- WITH TIES: si el 5.º empata con otros, también los muestra

-- Caso 4.8: Consultar la "página 2" de empleados, de 10 en 10 (paginación)
SELECT employee_id, last_name
FROM   employees
ORDER  BY employee_id
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;   -- salta 10 y trae los siguientes 10

-- Caso 4.9: Lo mismo que 4.7 a la "antigua" con ROWNUM (versiones anteriores a 12c)
SELECT *
FROM  (SELECT last_name, salary FROM employees ORDER BY salary DESC)
WHERE  ROWNUM <= 5;                 -- ROWNUM se asigna ANTES del ORDER BY, por eso se ordena adentro


/* =====================================================================
   TEMA 5. CONSULTAS JERÁRQUICAS
   Recorren una tabla que se apunta a sí misma (employee_id -> manager_id).
   ===================================================================== */

-- Caso 5.1: Consultar el organigrama completo desde el presidente (King)
SELECT LEVEL,                                                          -- nivel en el árbol: 1 = raíz
       LPAD(' ', (LEVEL - 1) * 3) || last_name AS organigrama,         -- sangría según el nivel
       job_id
FROM   employees
START  WITH manager_id IS NULL                                         -- por dónde empieza el árbol
CONNECT BY PRIOR employee_id = manager_id                              -- PRIOR = la fila "padre"
ORDER  SIBLINGS BY last_name;                                          -- ordena hermanos sin romper el árbol

-- Caso 5.2: Consultar la cadena de jefes de un empleado hacia arriba (de Lorentz hasta King)
SELECT LEVEL, last_name, job_id
FROM   employees
START  WITH last_name = 'Lorentz'
CONNECT BY PRIOR manager_id = employee_id;                             -- PRIOR al otro lado: sube en vez de bajar

-- Caso 5.3: Consultar la ruta completa de cada empleado y si es hoja (no tiene subordinados)
SELECT last_name,
       SYS_CONNECT_BY_PATH(last_name, ' > ') AS ruta,                  -- arma el camino desde la raíz
       CONNECT_BY_ISLEAF AS es_hoja,                                    -- 1 = no tiene a nadie a cargo
       CONNECT_BY_ROOT last_name AS raiz
FROM   employees
START  WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id;

-- Caso 5.4: Consultar cuántas personas tiene a cargo (directa o indirectamente) cada jefe de primer nivel
SELECT raiz, COUNT(*) - 1 AS personas_a_cargo
FROM  (SELECT CONNECT_BY_ROOT last_name AS raiz
       FROM   employees
       START  WITH manager_id = 100
       CONNECT BY PRIOR employee_id = manager_id)
GROUP  BY raiz
ORDER  BY personas_a_cargo DESC;


/* =====================================================================
   TEMA 6. OPERADORES DE CONJUNTO
   Las dos consultas deben tener el mismo número de columnas y tipos compatibles.
   ===================================================================== */

-- Caso 6.1: Consultar todos los cargos que ha tenido el empleado 176: actual + anteriores (UNION quita repetidos)
SELECT job_id FROM employees   WHERE employee_id = 176
UNION
SELECT job_id FROM job_history WHERE employee_id = 176;

-- Caso 6.2: Lo mismo pero sin quitar repetidos (UNION ALL, más rápido)
SELECT employee_id, job_id, 'ACTUAL' AS tipo FROM employees   WHERE employee_id IN (176, 200)
UNION ALL
SELECT employee_id, job_id, 'ANTERIOR'       FROM job_history WHERE employee_id IN (176, 200)
ORDER  BY 1, 3;                                -- en conjuntos, el ORDER BY va al final y se puede usar el número de columna

-- Caso 6.3: Consultar empleados que volvieron a un cargo que ya habían tenido (INTERSECT: los que están en ambas)
SELECT employee_id, job_id FROM employees
INTERSECT
SELECT employee_id, job_id FROM job_history;

-- Caso 6.4: Consultar los departamentos que no tienen empleados (MINUS: los de arriba que no están abajo)
SELECT department_id FROM departments
MINUS
SELECT department_id FROM employees;


/* =====================================================================
   TEMA 7. FUNCIONES DE FILA
   ===================================================================== */

-- Caso 7.1: Consultar la categoría salarial de cada empleado (CASE buscado)
SELECT last_name, salary,
       CASE
         WHEN salary >= 15000 THEN 'Alto'
         WHEN salary >= 8000  THEN 'Medio'
         ELSE 'Bajo'
       END AS categoria
FROM   employees;

-- Caso 7.2: Consultar un aumento según el cargo (CASE simple y DECODE, que es la versión propia de Oracle)
SELECT last_name, job_id, salary,
       CASE job_id WHEN 'IT_PROG' THEN salary * 1.10
                   WHEN 'ST_CLERK' THEN salary * 1.15
                   ELSE salary END                                              AS con_case,
       DECODE(job_id, 'IT_PROG', salary * 1.10, 'ST_CLERK', salary * 1.15, salary) AS con_decode  -- (valor, si1, entonces1, ..., si_no)
FROM   employees;

-- Caso 7.3: Consultar el ingreso anual con comisión, manejando los NULL
SELECT last_name, salary, commission_pct,
       salary * 12 * (1 + NVL(commission_pct, 0))  AS anual,           -- NVL(a, b): si a es NULL usa b
       NVL2(commission_pct, 'Sí', 'No')            AS tiene_comision,  -- NVL2(a, si_no_nulo, si_nulo)
       COALESCE(commission_pct, 0)                  AS comision,        -- primer valor no nulo de la lista
       NULLIF(job_id, 'SA_REP')                     AS cargo_o_nulo     -- NULL si los dos son iguales
FROM   employees
WHERE  department_id = 80;

-- Caso 7.4: Consultar la antigüedad de cada empleado (funciones de fecha)
SELECT last_name, hire_date,
       TO_CHAR(hire_date, 'DD "de" fmMonth "de" YYYY', 'NLS_DATE_LANGUAGE=SPANISH') AS fecha_texto,  -- fm quita espacios
       TRUNC(MONTHS_BETWEEN(SYSDATE, hire_date) / 12) AS anios,
       ADD_MONTHS(hire_date, 6)                        AS fin_periodo_prueba,
       TRUNC(hire_date, 'MM')                          AS primer_dia_mes,   -- TRUNC con 'MM' corta la fecha al inicio del mes
       LAST_DAY(hire_date)                             AS ultimo_dia_mes
FROM   employees
ORDER  BY hire_date;

-- Caso 7.5: Consultar textos formateados
SELECT UPPER(last_name), INITCAP(LOWER(email)), LENGTH(last_name),
       SUBSTR(phone_number, 1, 3)      AS prefijo,
       INSTR(email, 'A')               AS posicion_a,
       LPAD(salary, 8, '*')            AS salario_relleno,
       TO_CHAR(salary, '$99,999.00')   AS salario_formato,
       REPLACE(job_id, '_', ' ')       AS cargo
FROM   employees
WHERE  ROWNUM <= 10;

-- Caso 7.6: Consultar en una sola línea los empleados de cada departamento (LISTAGG junta textos de un grupo)
SELECT department_id,
       LISTAGG(last_name, ', ') WITHIN GROUP (ORDER BY last_name) AS empleados
FROM   employees
WHERE  department_id IS NOT NULL
GROUP  BY department_id;

-- Caso 7.7: Consultar empleados cuyo apellido empieza por vocal (expresiones regulares)
SELECT last_name, phone_number,
       REGEXP_REPLACE(phone_number, '[^0-9]', '') AS solo_numeros     -- quita todo lo que no sea dígito
FROM   employees
WHERE  REGEXP_LIKE(last_name, '^[AEIOU]');                            -- ^ = empieza por

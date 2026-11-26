/* =====================================================================
   PRÁCTICA 1 - SQL AVANZADO (Oracle) - Esquema HR
   ---------------------------------------------------------------------
   Conectarse como el usuario HR.
   En SQL Developer: ejecutar caso por caso con Ctrl+Enter (o el script
   completo con F5). Cada caso tiene un comentario con lo que hace.
   Requiere Oracle 12c o superior (por FETCH FIRST).

   Tablas de HR que se usan:
     EMPLOYEES, DEPARTMENTS, JOBS, JOB_HISTORY, LOCATIONS, COUNTRIES, REGIONS

   TEMAS
     1.  Joins avanzados
     2.  Funciones de grupo, GROUP BY, HAVING, ROLLUP y CUBE
     3.  Subconsultas y WITH
     4.  Funciones analíticas (ranking, acumulados, LAG/LEAD)
     5.  Consultas jerárquicas
     6.  Operadores de conjunto
     7.  Funciones de fila (CASE, DECODE, NVL, fechas, LISTAGG)
     8.  DML avanzado y transacciones
     9.  Vistas
     10. Secuencias y sinónimos
     11. Índices y plan de ejecución
     12. Bloqueos: SELECT ... FOR UPDATE
     13. Limpieza
   ===================================================================== */


/* =====================================================================
   TEMA 1. JOINS AVANZADOS
   ===================================================================== */

-- Caso 1.1: Consultar cada empleado con el nombre de su departamento y su cargo (INNER JOIN de 3 tablas)
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS empleado,   -- || concatena textos
       d.department_name,
       j.job_title
FROM   employees e
JOIN   departments d ON d.department_id = e.department_id
JOIN   jobs j        ON j.job_id = e.job_id
ORDER  BY d.department_name, empleado;

-- Caso 1.2: Consultar TODOS los empleados, aunque no tengan departamento (LEFT JOIN)
SELECT e.last_name, e.department_id, d.department_name
FROM   employees e
LEFT   JOIN departments d ON d.department_id = e.department_id
WHERE  d.department_id IS NULL;          -- solo los que quedaron sin departamento (Grant)

-- Caso 1.3: Consultar los departamentos que no tienen empleados (RIGHT JOIN)
SELECT d.department_id, d.department_name
FROM   employees e
RIGHT  JOIN departments d ON d.department_id = e.department_id
WHERE  e.employee_id IS NULL;

-- Caso 1.4: Consultar empleados sin departamento Y departamentos sin empleados a la vez (FULL OUTER JOIN)
SELECT e.last_name, d.department_name
FROM   employees e
FULL   OUTER JOIN departments d ON d.department_id = e.department_id
WHERE  e.employee_id IS NULL OR d.department_id IS NULL;

-- Caso 1.5: Consultar cada empleado con el nombre de su jefe (SELF JOIN: la tabla se une consigo misma)
SELECT e.last_name AS empleado,
       m.last_name AS jefe
FROM   employees e
LEFT   JOIN employees m ON m.employee_id = e.manager_id   -- LEFT para incluir a King, que no tiene jefe
ORDER  BY jefe NULLS FIRST, empleado;                      -- NULLS FIRST: los nulos van primero

-- Caso 1.6: Consultar dónde trabaja cada empleado: ciudad, país y región (5 tablas)
SELECT e.last_name, d.department_name, l.city, c.country_name, r.region_name
FROM   employees e
JOIN   departments d ON d.department_id = e.department_id
JOIN   locations   l ON l.location_id   = d.location_id
JOIN   countries   c ON c.country_id    = l.country_id
JOIN   regions     r ON r.region_id     = c.region_id
ORDER  BY r.region_name, c.country_name, l.city;

-- Caso 1.7: Consultar empleados que ganan más que su jefe
SELECT e.last_name, e.salary, m.last_name AS jefe, m.salary AS salario_jefe
FROM   employees e
JOIN   employees m ON m.employee_id = e.manager_id
WHERE  e.salary > m.salary;

-- Caso 1.8: Consultar empleados con su rango salarial del cargo (NON-EQUIJOIN: la unión no es con "=")
SELECT e.last_name, e.salary, j.job_title, j.min_salary, j.max_salary
FROM   employees e
JOIN   jobs j ON e.salary BETWEEN j.min_salary AND j.max_salary
          AND j.job_id = e.job_id;

-- Caso 1.9: Consultar el historial de cargos de cada empleado (JOIN con USING: columnas con el mismo nombre)
SELECT employee_id, e.last_name, jh.start_date, jh.end_date, j.job_title AS cargo_anterior
FROM   employees e
JOIN   job_history jh USING (employee_id)      -- con USING la columna NO lleva alias de tabla
JOIN   jobs j ON j.job_id = jh.job_id          -- aquí no sirve USING(job_id): employees también tiene job_id
ORDER  BY employee_id, jh.start_date;


/* =====================================================================
   TEMA 2. FUNCIONES DE GRUPO, GROUP BY, HAVING, ROLLUP y CUBE
   ===================================================================== */

-- Caso 2.1: Consultar cuántos empleados hay y el salario mínimo, máximo, promedio y total
SELECT COUNT(*)              AS total_empleados,
       COUNT(commission_pct) AS con_comision,    -- COUNT(columna) no cuenta los NULL
       MIN(salary), MAX(salary),
       ROUND(AVG(salary), 2) AS promedio,
       SUM(salary)           AS nomina
FROM   employees;

-- Caso 2.2: Consultar el salario promedio por departamento
SELECT d.department_name, COUNT(*) AS empleados, ROUND(AVG(e.salary)) AS promedio
FROM   employees e
JOIN   departments d ON d.department_id = e.department_id
GROUP  BY d.department_name
ORDER  BY promedio DESC;

-- Caso 2.3: Consultar los departamentos con más de 5 empleados (HAVING filtra GRUPOS; WHERE filtra filas)
SELECT department_id, COUNT(*) AS empleados
FROM   employees
WHERE  department_id IS NOT NULL
GROUP  BY department_id
HAVING COUNT(*) > 5;

-- Caso 2.4: Consultar la nómina por departamento y cargo, con subtotales y total general (ROLLUP)
SELECT department_id, job_id, SUM(salary) AS nomina
FROM   employees
WHERE  department_id IN (20, 50, 80)
GROUP  BY ROLLUP (department_id, job_id)   -- agrega filas de subtotal por departamento y una de total
ORDER  BY department_id, job_id;

-- Caso 2.5: Igual que 2.4 pero con TODAS las combinaciones de subtotales (CUBE) y GROUPING para identificarlas
SELECT CASE WHEN GROUPING(department_id) = 1 THEN 'TODOS' ELSE TO_CHAR(department_id) END AS depto,
       CASE WHEN GROUPING(job_id) = 1        THEN 'TODOS' ELSE job_id END                  AS cargo,
       SUM(salary) AS nomina
FROM   employees
WHERE  department_id IN (20, 50)
GROUP  BY CUBE (department_id, job_id)     -- GROUPING(col) = 1 cuando esa fila es un subtotal de esa columna
ORDER  BY 1, 2;

-- Caso 2.6: Consultar cuántos empleados se contrataron por año
SELECT EXTRACT(YEAR FROM hire_date) AS anio, COUNT(*) AS contratados
FROM   employees
GROUP  BY EXTRACT(YEAR FROM hire_date)
ORDER  BY anio;


/* =====================================================================
   TEMA 3. SUBCONSULTAS Y WITH
   ===================================================================== */

-- Caso 3.1: Consultar quiénes ganan más que el promedio de la empresa (subconsulta de una sola fila)
SELECT last_name, salary
FROM   employees
WHERE  salary > (SELECT AVG(salary) FROM employees)
ORDER  BY salary DESC;

-- Caso 3.2: Consultar los empleados que trabajan en Seattle (subconsulta de varias filas con IN)
SELECT last_name, department_id
FROM   employees
WHERE  department_id IN (SELECT d.department_id
                         FROM   departments d
                         JOIN   locations l ON l.location_id = d.location_id
                         WHERE  l.city = 'Seattle');

-- Caso 3.3: Consultar quién gana más que TODOS los del departamento 60 (ALL) y más que ALGUNO (ANY)
SELECT last_name, salary FROM employees
WHERE  salary > ALL (SELECT salary FROM employees WHERE department_id = 60);   -- mayor que el máximo

SELECT last_name, salary FROM employees
WHERE  salary > ANY (SELECT salary FROM employees WHERE department_id = 60)    -- mayor que el mínimo
AND    department_id <> 60;

-- Caso 3.4: Consultar quién gana más que el promedio de SU propio departamento (subconsulta CORRELACIONADA)
SELECT e.last_name, e.department_id, e.salary
FROM   employees e
WHERE  e.salary > (SELECT AVG(x.salary)
                   FROM   employees x
                   WHERE  x.department_id = e.department_id)   -- usa la fila "e" de afuera: se repite por cada empleado
ORDER  BY e.department_id;

-- Caso 3.5: Consultar los empleados que son jefes de alguien (EXISTS: solo importa si hay al menos una fila)
SELECT m.employee_id, m.last_name
FROM   employees m
WHERE  EXISTS (SELECT 1 FROM employees e WHERE e.manager_id = m.employee_id);

-- Caso 3.6: Consultar los empleados que NO han cambiado de cargo nunca (NOT EXISTS)
SELECT e.employee_id, e.last_name
FROM   employees e
WHERE  NOT EXISTS (SELECT 1 FROM job_history jh WHERE jh.employee_id = e.employee_id);

-- Caso 3.7: Consultar cada empleado con el salario promedio de su departamento (subconsulta en el FROM = vista en línea)
SELECT e.last_name, e.salary, p.promedio, e.salary - p.promedio AS diferencia
FROM   employees e
JOIN  (SELECT department_id, ROUND(AVG(salary)) AS promedio
       FROM   employees
       GROUP  BY department_id) p ON p.department_id = e.department_id;

-- Caso 3.8: Consultar cada empleado con el total de empleados de su departamento (subconsulta ESCALAR en el SELECT)
SELECT e.last_name,
       (SELECT COUNT(*) FROM employees x WHERE x.department_id = e.department_id) AS companeros
FROM   employees e;

-- Caso 3.9: Consultar los departamentos cuya nómina supera el promedio de nóminas (WITH = subconsulta con nombre, CTE)
WITH nomina_depto AS (
       SELECT department_id, SUM(salary) AS nomina
       FROM   employees
       WHERE  department_id IS NOT NULL
       GROUP  BY department_id
     ),
     promedio AS (
       SELECT AVG(nomina) AS prom FROM nomina_depto      -- un WITH puede usar el anterior
     )
SELECT d.department_name, n.nomina
FROM   nomina_depto n
JOIN   departments d ON d.department_id = n.department_id
CROSS  JOIN promedio p                                   -- CROSS JOIN con una sola fila: la "pega" a todas
WHERE  n.nomina > p.prom
ORDER  BY n.nomina DESC;

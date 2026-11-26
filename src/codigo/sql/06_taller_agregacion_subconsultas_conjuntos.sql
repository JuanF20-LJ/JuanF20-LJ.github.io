/* =====================================================================
   BLOQUE D. AGREGACIÓN Y FILTRADO DE GRUPOS (6.6)
   ===================================================================== */

-- 6.6 Departamentos con más de 5 empleados y salario promedio > 6.000
SELECT d.department_id,
       d.department_name,
       COUNT(*)                 AS employee_count,
       ROUND(AVG(e.salary), 2)  AS avg_salary,
       MIN(e.salary)            AS min_salary,
       MAX(e.salary)            AS max_salary,
       SUM(e.salary)            AS salary_mass,
       COUNT(CASE WHEN e.hire_date > DATE '2005-01-01' THEN 1 END) AS empleados_recientes
FROM   employees e
JOIN   departments d ON d.department_id = e.department_id
GROUP  BY d.department_id, d.department_name
HAVING COUNT(*) > 5
   AND AVG(e.salary) > 6000
ORDER  BY d.department_id;
/*
   Por qué:
   - empleados_recientes usa AGREGACIÓN CONDICIONAL: el CASE devuelve 1 si la fecha cumple y NULL
     si no (no hay ELSE). COUNT no cuenta los NULL, así que solo cuenta a los recientes.
     Esto significa: el criterio de fecha solo afecta a ESA columna; employee_count sigue contando
     a todos. Si la fecha se pusiera en WHERE, esas filas se eliminarían ANTES de agrupar y
     cambiarían también employee_count, el promedio, el mínimo, etc.
   - DATE '2005-01-01' es un literal de fecha ANSI: no depende del formato de fecha de la sesión.
   - "Más de cinco empleados" no puede ir en WHERE porque WHERE se evalúa fila por fila ANTES del
     GROUP BY: en ese momento todavía no existen los grupos ni su COUNT(*). Las condiciones sobre
     funciones de grupo van en HAVING, que se evalúa después de agrupar.
   - Aquí INNER JOIN es correcto: solo interesan departamentos con empleados.
   Con los datos originales salen los departamentos 80 (Sales) y 100 (Finance).
   Nota: según la versión de HR, las fechas de contratación van de 1987 a 2000 (versiones antiguas)
   o de 2001 a 2008 (versiones nuevas), así que empleados_recientes puede variar.
*/


/* =====================================================================
   BLOQUE E. SUBCONSULTAS CORRELACIONADAS Y NO CORRELACIONADAS (6.7)
   ===================================================================== */

-- 6.7 Versión 1: subconsulta CORRELACIONADA
SELECT e.employee_id,
       e.last_name,
       e.department_id,
       e.salary,
       ROUND((SELECT AVG(x.salary) FROM employees x
              WHERE  x.department_id = e.department_id), 2) AS dept_avg_salary,
       ROUND(e.salary - (SELECT AVG(x.salary) FROM employees x
                         WHERE  x.department_id = e.department_id), 2) AS diff_vs_avg,
       ROUND(100 * (e.salary - (SELECT AVG(x.salary) FROM employees x
                                WHERE  x.department_id = e.department_id))
                 / (SELECT AVG(x.salary) FROM employees x
                    WHERE  x.department_id = e.department_id), 2) AS pct_vs_avg
FROM   employees e
ORDER  BY e.department_id, e.employee_id;
/*
   La correlación la produce la columna e.department_id dentro de la subconsulta
   (WHERE x.department_id = e.department_id): la subconsulta usa un valor de la fila de AFUERA,
   así que lógicamente se recalcula para cada empleado.
   Esto significa: una subconsulta NO correlacionada se puede ejecutar sola; una correlacionada no,
   porque depende de "e".
   Grant (department_id NULL): x.department_id = NULL nunca es verdadero, así que su promedio,
   diferencia y porcentaje salen NULL.
*/

-- 6.7 Versión 2: EXPRESIÓN COMÚN DE TABLA (WITH)
WITH promedios AS (
       SELECT department_id, AVG(salary) AS avg_sal
       FROM   employees
       WHERE  department_id IS NOT NULL
       GROUP  BY department_id                       -- se calcula UNA vez por departamento
     )
SELECT e.employee_id,
       e.last_name,
       e.department_id,
       e.salary,
       ROUND(p.avg_sal, 2)                               AS dept_avg_salary,
       ROUND(e.salary - p.avg_sal, 2)                    AS diff_vs_avg,
       ROUND(100 * (e.salary - p.avg_sal) / p.avg_sal, 2) AS pct_vs_avg
FROM   employees e
LEFT   JOIN promedios p ON p.department_id = e.department_id   -- LEFT: Grant sale con NULL, igual que en la v1
ORDER  BY e.department_id, e.employee_id;
/*
   Por qué son equivalentes: las dos devuelven 107 filas con los mismos valores. Se usa LEFT JOIN
   para que Grant (sin departamento) también aparezca con NULL; con JOIN normal desaparecería y
   las versiones ya no serían equivalentes.
   La CTE es una NO correlacionada: se puede ejecutar sola, calcula los 11 promedios una vez y luego
   se une a los empleados. Es más clara y no repite la misma subconsulta cuatro veces.
*/

-- 6.7 Planes de ejecución de las dos versiones
EXPLAIN PLAN SET STATEMENT_ID = 'V1_CORRELACIONADA' FOR
SELECT e.employee_id, e.last_name, e.department_id, e.salary,
       (SELECT AVG(x.salary) FROM employees x WHERE x.department_id = e.department_id) AS dept_avg_salary
FROM   employees e;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'V1_CORRELACIONADA', 'BASIC +ROWS +COST'));

EXPLAIN PLAN SET STATEMENT_ID = 'V2_CTE' FOR
WITH promedios AS (SELECT department_id, AVG(salary) AS avg_sal
                   FROM employees WHERE department_id IS NOT NULL GROUP BY department_id)
SELECT e.employee_id, e.last_name, e.department_id, e.salary, p.avg_sal
FROM   employees e LEFT JOIN promedios p ON p.department_id = e.department_id;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'V2_CTE', 'BASIC +ROWS +COST'));
/*
   Qué buscar al comparar los planes (anotar lo que salga en su base):
   - Versión correlacionada: suele aparecer la subconsulta como un SORT AGGREGATE que depende de
     cada fila de EMPLOYEES (lógicamente se ejecuta por cada empleado; Oracle guarda en caché el
     resultado por cada department_id distinto). En versiones nuevas el optimizador puede
     "desanidarla" (unnesting) y convertirla en un JOIN con una vista interna (VW_SQ_...).
   - Versión CTE: aparece un HASH GROUP BY (calcula los promedios una vez) y un HASH JOIN
     OUTER con EMPLOYEES.
   - Comparar la columna Cost: con las 107 filas de HR la diferencia es pequeña; en tablas grandes la
     CTE/tabla derivada escala mejor porque agrupa una sola vez.
   Alternativa con AUTOTRACE en SQL Developer: seleccionar la consulta y presionar F6.
*/


/* =====================================================================
   BLOQUE F. OPERACIONES DE CONJUNTOS (6.8)
   ===================================================================== */

-- 6.8 Movilidad interna con INTERSECT y MINUS
SELECT e.employee_id, e.last_name, 'CON HISTORIAL' AS movilidad_status
FROM   employees e
WHERE  e.employee_id IN (SELECT employee_id FROM employees
                         INTERSECT                      -- ids que están en las DOS tablas
                         SELECT employee_id FROM job_history)
UNION ALL
SELECT e.employee_id, e.last_name, 'SIN HISTORIAL'
FROM   employees e
WHERE  e.employee_id IN (SELECT employee_id FROM employees
                         MINUS                          -- ids de EMPLOYEES que NO están en JOB_HISTORY
                         SELECT employee_id FROM job_history)
ORDER  BY movilidad_status, employee_id;
/*
   Por qué:
   - INTERSECT devuelve las filas que están en ambas consultas (sin repetidos): los empleados que
     tienen al menos un registro en JOB_HISTORY. Aunque 101, 176 y 200 tienen dos registros cada uno,
     salen una sola vez porque los operadores de conjunto eliminan duplicados.
   - MINUS devuelve las filas de la primera consulta que no están en la segunda.
   - Se envuelven en IN (...) porque JOB_HISTORY no tiene last_name: los conjuntos se calculan
     solo con employee_id y luego se buscan los apellidos.
   Con los datos originales: 7 CON HISTORIAL (101, 102, 114, 122, 176, 200, 201) y 100 SIN HISTORIAL.
*/

-- 6.8 Versión equivalente con EXISTS / NOT EXISTS (debe dar exactamente el mismo resultado)
SELECT e.employee_id,
       e.last_name,
       CASE WHEN EXISTS (SELECT 1 FROM job_history h WHERE h.employee_id = e.employee_id)
            THEN 'CON HISTORIAL'
            ELSE 'SIN HISTORIAL'
       END AS movilidad_status
FROM   employees e
ORDER  BY movilidad_status, employee_id;

-- 6.8 Comprobación: la diferencia entre las dos versiones debe ser vacía (0 filas)
-- (los operadores de conjunto se evalúan de izquierda a derecha: primero el UNION ALL y luego el MINUS)
SELECT e.employee_id, 'CON HISTORIAL' AS st FROM employees e
WHERE  e.employee_id IN (SELECT employee_id FROM employees INTERSECT SELECT employee_id FROM job_history)
UNION ALL
SELECT e.employee_id, 'SIN HISTORIAL' FROM employees e
WHERE  e.employee_id IN (SELECT employee_id FROM employees MINUS SELECT employee_id FROM job_history)
MINUS
SELECT e.employee_id,
       CASE WHEN EXISTS (SELECT 1 FROM job_history h WHERE h.employee_id = e.employee_id)
            THEN 'CON HISTORIAL' ELSE 'SIN HISTORIAL' END
FROM   employees e;

-- 6.8 Demostración de cómo tratan los NULL los conjuntos frente al "="
SELECT department_id FROM employees WHERE employee_id = 178    -- devuelve NULL (Grant)
INTERSECT
SELECT CAST(NULL AS NUMBER) FROM dual;                         -- devuelve 1 fila: NULL "coincide" con NULL

SELECT COUNT(*) AS coincidencias_con_igual
FROM   employees
WHERE  department_id = CAST(NULL AS NUMBER);                   -- devuelve 0: NULL = NULL es UNKNOWN
/*
   Por qué:
   - Los operadores de conjunto (UNION, INTERSECT, MINUS) comparan filas completas y consideran que
     dos NULL son IGUALES (los tratan como duplicados). Por eso el INTERSECT de arriba devuelve una
     fila con NULL.
   - El operador "=" (en WHERE, ON, IN) usa lógica de tres valores: NULL = NULL es UNKNOWN, así que
     nunca coincide.
   Esto significa: en este caso no cambia el resultado porque employee_id nunca es NULL, pero si se
   comparara una columna con nulos (como department_id), INTERSECT/MINUS y "=" darían resultados
   distintos.
*/

/* =====================================================================
   TALLER DE REPASO - SQL AVANZADO APLICADO SOBRE EL ESQUEMA HR
   Universidad El Bosque - Bases de Datos 2
   ---------------------------------------------------------------------

   Conexión: usuario HR (Oracle 12c o superior).
   El script es de SOLO LECTURA: no tiene INSERT, UPDATE, DELETE ni DDL
   sobre las tablas de HR. (EXPLAIN PLAN solo escribe en PLAN_TABLE, la
   tabla de planes de Oracle; no toca los datos de HR.)

   Orden del script:
     Bloque A. Verificación de casos borde del esquema          (6.1)
     Bloque B. Reuniones internas y externas                    (6.2, 6.3, 6.4)
     Bloque C. Tratamiento de valores nulos                     (6.5)
     Bloque D. Agregación y filtrado de grupos                  (6.6)
     Bloque E. Subconsultas correlacionadas y no correlacionadas (6.7)
     Bloque F. Operaciones de conjuntos                         (6.8)
     Bloque G. Expresiones comunes de tabla y recursión         (6.9)
     Bloque H. Funciones de ventana                             (6.10, 6.11)
     Bloque I. Depuración de consultas defectuosas              (6.12)
     Comentarios finales de justificación técnica
     Anexo: verificación conceptual de cierre (sección 8)

   ORDEN LÓGICO DE EVALUACIÓN DE UN SELECT (se usa en todo el taller):
     1. FROM / JOIN   2. WHERE   3. GROUP BY   4. HAVING
     5. funciones de ventana   6. SELECT (alias)   7. DISTINCT   8. ORDER BY
     9. FETCH / OFFSET
   Esto significa: cada paso solo "ve" lo que dejaron los pasos anteriores.
   ===================================================================== */


/* =====================================================================
   BLOQUE A. VERIFICACIÓN DE CASOS BORDE DEL ESQUEMA (6.1)
   ===================================================================== */

-- 6.1 Casos borde: exactamente 4 filas
SELECT 'Empleado sin jefe'           AS caso_borde,
       COUNT(*)                      AS empleados_afectados,
       'manager_id es NULL: es la raíz de la jerarquía (King, 100)' AS descripcion
FROM   employees
WHERE  manager_id IS NULL
UNION ALL
SELECT 'Empleado sin departamento',
       COUNT(*),
       'department_id es NULL (Grant, 178): se pierde en cualquier INNER JOIN con DEPARTMENTS'
FROM   employees
WHERE  department_id IS NULL
UNION ALL
SELECT 'Empleados sin comisión',
       COUNT(*),
       'commission_pct es NULL: AVG los ignora y salary * commission_pct da NULL'
FROM   employees
WHERE  commission_pct IS NULL
UNION ALL
SELECT 'Departamentos sin empleados',
       COUNT(*),
       'No tienen filas en EMPLOYEES: solo aparecen con un OUTER JOIN y COUNT(*) los cuenta como 1'
FROM   departments d
WHERE  NOT EXISTS (SELECT 1 FROM employees e WHERE e.department_id = d.department_id);
/*
   Por qué:
   - IS NULL es la única forma de encontrar nulos: "manager_id = NULL" nunca es verdadero.
     Esto significa: cualquier comparación con NULL da UNKNOWN (desconocido), y WHERE solo deja pasar TRUE.
   - Para "departamentos sin empleados" se usa NOT EXISTS y no NOT IN, porque EMPLOYEES tiene un
     department_id NULL (Grant). Con NOT IN el resultado sería 0 (se explica en el bloque C).
   - UNION ALL une las cuatro consultas sin quitar repetidos (no hay nada que quitar y es más rápido).
   Con los datos originales debe dar: 1, 1, 72 y 16.
   Estos cuatro casos son los que rompen las consultas de los bloques siguientes:
     el empleado sin jefe      -> se pierde con INNER JOIN en la cadena de mando (6.3)
     el empleado sin depto     -> se pierde con INNER JOIN y daña NOT IN (6.5, I.2)
     los sin comisión          -> hacen nulo el total y bajan mal el promedio (6.5, I.5)
     los deptos sin empleados  -> COUNT(*) los muestra con 1 (6.2, I.1, I.3)
*/


/* =====================================================================
   BLOQUE B. REUNIONES INTERNAS Y EXTERNAS
   ===================================================================== */

-- 6.2 Inventario completo de departamentos (deben salir los 27, incluidos los vacíos)
SELECT d.department_id,
       d.department_name,
       l.city,
       c.country_name,
       COUNT(e.employee_id)  AS employee_count,   -- cuenta solo filas con empleado real
       ROUND(AVG(e.salary), 2) AS avg_salary       -- NULL en los vacíos: no hay salarios que promediar
FROM   departments d
LEFT   JOIN employees e ON e.department_id = d.department_id
LEFT   JOIN locations l ON l.location_id  = d.location_id
LEFT   JOIN countries c ON c.country_id   = l.country_id
GROUP  BY d.department_id, d.department_name, l.city, c.country_name
ORDER  BY d.department_id;
/*
   Por qué:
   - DEPARTMENTS va a la izquierda del LEFT JOIN: esto significa que se conservan TODOS los
     departamentos, tengan o no empleados.
   - Para un departamento sin empleados, el LEFT JOIN produce UNA fila con todas las columnas de
     EMPLOYEES en NULL (fila "rellenada con nulos").
   - COUNT(*) cuenta filas, sin importar su contenido: esa fila rellenada cuenta como 1. Por eso
     COUNT(*) da 1 en los departamentos vacíos (valor incorrecto).
   - COUNT(e.employee_id) cuenta solo los valores NO nulos de esa columna: en la fila rellenada
     employee_id es NULL, así que da 0. Esa es la función que lo corrige.
   - LOCATIONS y COUNTRIES también van con LEFT JOIN para que ningún departamento se pierda si
     faltara su ubicación (en HR todos la tienen, pero así la consulta es segura).
   - avg_salary queda NULL en los vacíos: AVG ignora los nulos y, si no hay ningún valor, devuelve NULL.
*/


-- 6.3 Cadena de mando (el empleado 100 debe aparecer con manager_name nulo)
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       j.job_title,
       e.manager_id,
       CASE WHEN m.employee_id IS NULL THEN NULL                 -- sin jefe: NULL de verdad
            ELSE m.first_name || ' ' || m.last_name END AS manager_name,
       d.department_name
FROM   employees e
JOIN   jobs j             ON j.job_id = e.job_id                -- todo empleado tiene cargo: INNER es correcto
LEFT   JOIN employees m   ON m.employee_id = e.manager_id       -- SELF JOIN externo: conserva a King
LEFT   JOIN departments d ON d.department_id = e.department_id  -- conserva a Grant (sin departamento)
ORDER  BY e.employee_id;
/*
   Por qué:
   - Es una AUTO-REUNIÓN (self join) EXTERNA: EMPLOYEES se une consigo misma (e = empleado,
     m = jefe) con LEFT JOIN.
   - King (100) tiene manager_id NULL. En el LEFT JOIN no encuentra jefe, pero se conserva y todas
     las columnas de "m" quedan en NULL.
   - Se usa CASE para manager_name porque Oracle trata NULL como texto vacío al concatenar:
     NULL || ' ' || NULL da ' ' (un espacio), no NULL. Con el CASE, King queda con NULL real.
   - Si se usara INNER JOIN con "m": la condición m.employee_id = NULL nunca es verdadera, así que
     King DESAPARECE del resultado (106 filas en vez de 107).
   - DEPARTMENTS también va con LEFT JOIN: con INNER JOIN desaparecería Grant (178).
*/


-- 6.4 Contraste: condición en ON vs. condición en WHERE (salario > 10.000)
SELECT 'Filtro en ON' AS variante,
       COUNT(*)       AS filas_devueltas,
       'Conserva los 27 departamentos; los que no tienen empleados > 10.000 salen con NULL' AS explicacion
FROM   departments d
LEFT   JOIN employees e ON e.department_id = d.department_id
                       AND e.salary > 10000
UNION ALL
SELECT 'Filtro en WHERE',
       COUNT(*),
       'Elimina las filas rellenadas con NULL: el LEFT JOIN se vuelve un INNER JOIN'
FROM   departments d
LEFT   JOIN employees e ON e.department_id = d.department_id
WHERE  e.salary > 10000;

-- Detalle de cada variante (para la evidencia)
SELECT d.department_id, d.department_name, e.last_name, e.salary
FROM   departments d
LEFT   JOIN employees e ON e.department_id = d.department_id AND e.salary > 10000
ORDER  BY d.department_id;

SELECT d.department_id, d.department_name, e.last_name, e.salary
FROM   departments d
LEFT   JOIN employees e ON e.department_id = d.department_id
WHERE  e.salary > 10000
ORDER  BY d.department_id;
/*
   Por qué:
   - En ON, la condición decide QUÉ EMPLEADOS se pegan a cada departamento. Si un departamento no
     tiene ninguno que cumpla, igual se conserva (con NULL), porque así funciona el LEFT JOIN.
     Con los datos originales: 15 empleados ganan más de 10.000 en 6 departamentos, más los
     21 departamentos sin coincidencia = 36 filas.
   - En WHERE, la condición se aplica DESPUÉS del JOIN, sobre el resultado. En las filas rellenadas
     e.salary es NULL, y NULL > 10000 es UNKNOWN, así que WHERE las elimina: quedan 15 filas.
   Regla general (una frase):
     Una condición sobre la tabla opcional de un LEFT JOIN escrita en WHERE convierte la reunión
     externa en interna; para conservar las filas sin coincidencia, la condición debe ir en el ON.
*/


/* =====================================================================
   BLOQUE C. TRATAMIENTO DE VALORES NULOS (6.5)
   ===================================================================== */

-- 6.5 Diagnóstico de nulos y compensación total
SELECT e.employee_id,
       e.last_name,
       e.department_id,
       e.salary,
       e.commission_pct,
       e.salary + e.salary * NVL(e.commission_pct, 0) AS total_compensation,   -- NVL: si es NULL usa 0
       CASE
         WHEN NOT EXISTS (SELECT 1 FROM employees s WHERE s.manager_id = e.employee_id)
         THEN 'NO'
         ELSE 'SI'
       END AS es_jefe
FROM   employees e
ORDER  BY e.employee_id;
/*
   Por qué:
   - Sin NVL, para los 72 empleados sin comisión: salary * NULL = NULL y salary + NULL = NULL.
     Esto significa: cualquier operación aritmética con NULL da NULL. NVL(commission_pct, 0)
     cambia el NULL por 0 antes de operar, así total_compensation nunca es nulo.
   - es_jefe con NOT EXISTS: pregunta "¿existe alguien cuyo manager_id sea este empleado?". EXISTS
     solo mira si hay filas (verdadero/falso), nunca compara con NULL, así que siempre responde
     SI o NO. (Columna "SI" sin tilde, como lo pide el enunciado.)
*/

-- 6.5 Evidencia: la versión con NOT IN devuelve el conjunto vacío
SELECT COUNT(*) AS no_jefes_con_not_in          -- da 0
FROM   employees e
WHERE  e.employee_id NOT IN (SELECT manager_id FROM employees);

SELECT COUNT(*) AS no_jefes_con_not_exists      -- da 89 (107 empleados - 18 jefes)
FROM   employees e
WHERE  NOT EXISTS (SELECT 1 FROM employees s WHERE s.manager_id = e.employee_id);
/*
   Por qué NOT IN devuelve vacío:
   - La subconsulta SELECT manager_id FROM employees incluye un NULL (el de King).
   - "x NOT IN (a, b, NULL)" equivale a  x <> a AND x <> b AND x <> NULL.
   - x <> NULL es UNKNOWN, y TRUE AND UNKNOWN = UNKNOWN. Nunca llega a ser TRUE.
   - Esto significa: basta UN NULL en la lista para que NOT IN no devuelva ninguna fila.
   Por qué NOT EXISTS no tiene el problema:
   - NOT EXISTS no compara contra una lista: busca filas con s.manager_id = e.employee_id. La fila
     de King (manager_id NULL) simplemente no coincide, y no "contamina" el resultado.
   Corrección alternativa de NOT IN: excluir los nulos en la subconsulta
     (... NOT IN (SELECT manager_id FROM employees WHERE manager_id IS NOT NULL)).
*/

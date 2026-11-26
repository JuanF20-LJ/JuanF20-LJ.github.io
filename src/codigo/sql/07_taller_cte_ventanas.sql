/* =====================================================================
   BLOQUE G. EXPRESIONES COMUNES DE TABLA Y RECURSIÓN (6.9)
   ===================================================================== */

-- 6.9 Jerarquía organizacional con CTE recursiva
WITH jerarquia (employee_id, last_name, manager_id, nivel, ruta_jerarquica) AS (
       -- CASO BASE (anchor): el empleado sin jefe
       SELECT employee_id,
              last_name,
              manager_id,
              1,
              CAST(last_name AS VARCHAR2(1000))      -- se agranda el tipo: la ruta crece en cada nivel
       FROM   employees
       WHERE  manager_id IS NULL
       UNION ALL
       -- PASO RECURSIVO: los empleados cuyo jefe ya está en la jerarquía
       SELECT e.employee_id,
              e.last_name,
              e.manager_id,
              j.nivel + 1,
              j.ruta_jerarquica || ' > ' || e.last_name
       FROM   employees e
       JOIN   jerarquia j ON e.manager_id = j.employee_id    -- aquí la CTE se llama a sí misma
     )
     SEARCH DEPTH FIRST BY last_name SET orden               -- recorre en profundidad: cada jefe seguido de su equipo
     CYCLE employee_id SET es_ciclo TO 'S' DEFAULT 'N'       -- control de ciclos
SELECT employee_id, last_name, manager_id, nivel, ruta_jerarquica
FROM   jerarquia
ORDER  BY orden;
/*
   Por qué:
   - Una CTE recursiva tiene dos partes unidas por UNION ALL:
       CASO BASE: la consulta que no se refiere a la CTE (WHERE manager_id IS NULL: King, nivel 1).
       PASO RECURSIVO: la consulta que hace JOIN con la propia CTE (jerarquia j). Se repite: primero
       encuentra a quienes reportan a King (nivel 2), luego a quienes reportan a esos (nivel 3), y
       así hasta que ya no aparecen filas nuevas.
   - En Oracle es obligatorio poner la lista de columnas (employee_id, last_name, ...) después del
     nombre de la CTE recursiva.
   - CAST(... AS VARCHAR2(1000)): el tipo de la columna lo fija el caso base (last_name es
     VARCHAR2(25)); sin agrandarlo, la ruta no cabría al concatenar.
   - Deben salir los 107 empleados. Grant (sin departamento) también aparece, porque sí tiene jefe.
   ¿Qué pasa si UNION ALL se cambia por UNION?
   - En Oracle da error ORA-32040: la recursión exige UNION ALL. En el estándar SQL, UNION eliminaría
     duplicados en cada paso (más costoso), y como cada empleado tiene un solo jefe, aquí no hay
     duplicados que quitar.
   ¿Cómo se controla un ciclo en los datos? (por ejemplo, si A es jefe de B y B es jefe de A)
   - Con la cláusula CYCLE: marca con 'S' la fila donde un employee_id se repite dentro de la misma
     rama y detiene esa rama. Sin ella, Oracle lanza ORA-32044 (ciclo detectado).
   - Otra forma: limitar la profundidad en el paso recursivo, por ejemplo AND j.nivel < 20.
*/


/* =====================================================================
   BLOQUE H. FUNCIONES DE VENTANA
   ===================================================================== */

-- 6.10 Posicionamiento salarial por departamento
SELECT employee_id,
       last_name,
       department_id,
       salary,
       ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rn,
       RANK()       OVER (PARTITION BY department_id ORDER BY salary DESC) AS rk,
       DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS drk,
       LAG(salary, 1, salary) OVER (PARTITION BY department_id
                                    ORDER BY hire_date, employee_id)       AS prev_salary,
       salary - LAG(salary, 1, salary) OVER (PARTITION BY department_id
                                             ORDER BY hire_date, employee_id) AS delta_prev,
       SUM(salary) OVER (PARTITION BY department_id
                         ORDER BY hire_date, employee_id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS salary_running_total,
       ROUND(AVG(salary) OVER (PARTITION BY department_id), 2)             AS dept_avg_salary,
       ROUND(100 * (salary - AVG(salary) OVER (PARTITION BY department_id))
                 / AVG(salary) OVER (PARTITION BY department_id), 2)       AS pct_vs_dept_avg
FROM   employees
ORDER  BY department_id, rn;
/*
   Por qué:
   - PARTITION BY department_id: la "ventana" es cada departamento. Esto significa que los cálculos
     se reinician en cada departamento, pero NO se colapsan las filas (a diferencia de GROUP BY):
     se conserva el detalle de cada empleado.
   - rn, rk y drk usan la misma partición y el mismo ORDER BY salary DESC.
   - LAG(salary, 1, salary): el 1 es "una fila atrás" y el tercer parámetro es el valor por defecto
     cuando no hay fila anterior. Al poner el propio salary, la primera fila de cada partición no
     queda en NULL (prev_salary = su salario y delta_prev = 0).
   - En LAG y en el acumulado se agrega employee_id al ORDER BY para desempatar empleados contratados
     el mismo día y que el orden sea siempre el mismo.

   Departamento con salarios empatados: 80 (Sales). Filas concretas:
       empleado        salario   rn   rk   drk
       Russell          14000     1    1    1
       Partners         13500     2    2    2
       Errazuriz        12000     3    3    3
       Ozer             11500     4    4    4
       Cambrault        11000     5    5    5
       Abel             11000     6    5    5
       Zlotkey          10500     7    7    6
       Vishney          10500     8    7    6
       Tucker/King/Bloom 10000  9-11   9    7
     - ROW_NUMBER nunca repite: entre empatados (Cambrault/Abel) el orden es arbitrario.
     - RANK: los empatados comparten número y luego SALTA (después de los dos 5 viene el 7).
     - DENSE_RANK: comparten número y NO salta (después de los dos 5 viene el 6).
     (También el 90: King 24000 y Kochhar/De Haan 17000: rn 1,2,3; rk 1,2,2; drk 1,2,2.)

   Marco de ventana por defecto:
   - Cuando el OVER tiene ORDER BY pero no dice ROWS ni RANGE, Oracle aplica
       RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.
     Esto significa: suma desde el inicio de la partición hasta la fila actual INCLUYENDO todas las
     filas empatadas en el ORDER BY ("pares"). Dos empleados contratados el mismo día recibirían el
     mismo acumulado. Por eso aquí se escribe ROWS explícitamente: acumula fila por fila.
   - Sin ORDER BY en el OVER (como en dept_avg_salary), el marco es toda la partición.
*/


-- 6.11 Tres mejor pagados de cada departamento
SELECT department_id, department_name, employee_id, last_name, salary, drk
FROM  (SELECT e.department_id,
              d.department_name,
              e.employee_id,
              e.last_name,
              e.salary,
              DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS drk
       FROM   employees e
       JOIN   departments d ON d.department_id = e.department_id)
WHERE  drk <= 3
ORDER  BY department_id, drk, employee_id;
/*
   Por qué hay que envolver la consulta:
   - Según el orden lógico de evaluación, las funciones de ventana se calculan DESPUÉS de WHERE,
     GROUP BY y HAVING, justo antes del SELECT final y del ORDER BY.
   - Cuando se evalúa el WHERE, el valor drk todavía no existe; además, el alias del SELECT tampoco.
     Por eso "WHERE drk <= 3" en la misma consulta da error (ORA-00904, identificador no válido), y
     tampoco se puede escribir la función de ventana dentro del WHERE (ORA-30483).
   - La solución es calcular drk en una consulta interna (tabla derivada) y filtrar en la de afuera,
     donde drk ya es una columna normal.
   - Se usa DENSE_RANK para que los empatados entren juntos: "tres mejores salarios" puede traer más
     de tres personas si hay empates.
   - Grant no aparece porque no tiene departamento (INNER JOIN con DEPARTMENTS).
*/

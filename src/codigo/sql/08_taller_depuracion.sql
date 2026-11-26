/* =====================================================================
   BLOQUE I. DEPURACIÓN DE CONSULTAS DEFECTUOSAS (6.12)
   Para cada una: consulta original, consulta corregida y explicación.
   Al final, el cuadro de diagnóstico.
   ===================================================================== */

-- I.1 ORIGINAL - Enunciado: todos los departamentos con la cantidad de empleados, incluidos los vacíos
SELECT   d.department_name, COUNT(*)
FROM     departments d LEFT JOIN employees e
         ON d.department_id = e.department_id
GROUP BY d.department_name;

-- I.1 CORREGIDA
SELECT   d.department_id, d.department_name, COUNT(e.employee_id) AS employee_count
FROM     departments d
LEFT     JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;
/*
   Error: los 16 departamentos vacíos muestran 1 en vez de 0.
   Mecanismo: el LEFT JOIN crea una fila rellenada con NULL para cada departamento vacío y COUNT(*)
   cuenta filas, no empleados. COUNT(e.employee_id) ignora los NULL y da 0.
   (Se agrega department_id al GROUP BY para no mezclar dos departamentos si tuvieran el mismo nombre.)
*/

-- I.2 ORIGINAL - Enunciado: empleados que no trabajan en los departamentos 10, 20 ni 30
SELECT last_name
FROM   employees
WHERE  department_id NOT IN (10, 20, 30);

-- I.2 CORREGIDA
SELECT last_name, department_id
FROM   employees
WHERE  department_id NOT IN (10, 20, 30)
   OR  department_id IS NULL;
/*
   Error: falta Grant (178), que no tiene departamento y por lo tanto NO trabaja en el 10, 20 ni 30.
   Mecanismo: para Grant la condición es NULL NOT IN (10, 20, 30), es decir
   NULL <> 10 AND NULL <> 20 AND NULL <> 30 = UNKNOWN, y WHERE descarta lo que no es TRUE.
   La corrección agrega explícitamente los nulos (OR department_id IS NULL). Alternativa equivalente:
   WHERE NVL(department_id, -1) NOT IN (10, 20, 30).
*/

-- I.3 ORIGINAL - Enunciado: departamentos ubicados en Estados Unidos con su cantidad de empleados
SELECT   d.department_name, COUNT(*)
FROM     departments d
LEFT     JOIN employees e ON d.department_id = e.department_id
LEFT     JOIN locations l ON d.location_id   = l.location_id
WHERE    l.country_id = 'US'
GROUP BY d.department_name;

-- I.3 CORREGIDA
SELECT   d.department_id, d.department_name, l.city, COUNT(e.employee_id) AS employee_count
FROM     departments d
JOIN     locations l ON l.location_id = d.location_id
                    AND l.country_id  = 'US'                -- el filtro del país pertenece a la reunión con LOCATIONS
LEFT     JOIN employees e ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name, l.city
ORDER BY d.department_id;
/*
   Error: los departamentos de Estados Unidos que no tienen empleados (la mayoría de Seattle) aparecen
   con 1 en vez de 0.
   Mecanismo (dos problemas):
   1. COUNT(*) cuenta la fila rellenada con NULL del LEFT JOIN con EMPLOYEES (mismo error de I.1).
   2. WHERE l.country_id = 'US' filtra una columna de la tabla opcional del LEFT JOIN con LOCATIONS:
      eso convierte esa reunión externa en interna (regla de 6.4). Aquí no cambia el resultado porque
      todos los departamentos tienen ubicación, pero el LEFT JOIN es engañoso: en realidad se quiere
      un INNER JOIN, porque solo interesan los departamentos que SÍ están en EE. UU.
   La corrección usa JOIN con LOCATIONS (con el país en el ON) y COUNT(e.employee_id).
*/

-- I.4 ORIGINAL - Enunciado: el empleado mejor pagado de cada departamento
SELECT   department_id, last_name, MAX(salary)
FROM     employees
GROUP BY department_id, last_name;

-- I.4 CORREGIDA
SELECT department_id, last_name, salary
FROM  (SELECT department_id, last_name, salary,
              RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rk
       FROM   employees)
WHERE  rk = 1
ORDER  BY department_id;
/*
   Error: devuelve casi todos los empleados (una fila por departamento y apellido), no uno por
   departamento.
   Mecanismo: al agrupar también por last_name, cada grupo es prácticamente un solo empleado, así que
   MAX(salary) es el salario de esa misma persona. El MAX se calcula por grupo, y los grupos quedaron
   demasiado pequeños.
   La corrección calcula el ranking dentro de cada departamento y se queda con el primero. Se usa RANK
   (no ROW_NUMBER) para que, si dos empleados empatan en el salario máximo, salgan ambos (en el 90,
   el mejor pagado es solo King; en el 80, Russell). Grant aparece en su propio grupo NULL.
*/

-- I.5 ORIGINAL - Enunciado: promedio de comisión de la compañía, contando como cero a quienes no reciben comisión
SELECT AVG(commission_pct)
FROM   employees;

-- I.5 CORREGIDA
SELECT ROUND(AVG(NVL(commission_pct, 0)), 4) AS promedio_comision
FROM   employees;
/*
   Error: el promedio sale mucho más alto de lo que pide el enunciado.
   Mecanismo: AVG ignora los NULL; divide la suma de comisiones entre los 35 que tienen comisión, no
   entre los 107 empleados. NVL(commission_pct, 0) convierte los NULL en 0 antes de promediar, así
   que entran al denominador.
   Equivalente: SUM(commission_pct) / COUNT(*).
*/

-- 6.12 Cuadro de diagnóstico (la evidencia se calcula con los datos reales: antes y después)
SELECT 'I.1' AS consulta_id,
       'Todos los departamentos con su cantidad de empleados, incluidos los vacíos' AS enunciado,
       'Los departamentos vacíos muestran 1' AS error_detectado,
       'COUNT(*) cuenta la fila rellenada con NULL del LEFT JOIN; COUNT(e.employee_id) no la cuenta' AS mecanismo,
       'Departamentos con conteo 0: antes ' ||
         (SELECT COUNT(*) FROM (SELECT COUNT(*) AS c FROM departments d
                                LEFT JOIN employees e ON d.department_id = e.department_id
                                GROUP BY d.department_name) WHERE c = 0) ||
       ', después ' ||
         (SELECT COUNT(*) FROM (SELECT COUNT(e.employee_id) AS c FROM departments d
                                LEFT JOIN employees e ON d.department_id = e.department_id
                                GROUP BY d.department_id) WHERE c = 0) AS evidencia_correccion
FROM dual
UNION ALL
SELECT 'I.2',
       'Empleados que no trabajan en los departamentos 10, 20 ni 30',
       'Falta el empleado sin departamento (Grant)',
       'NULL NOT IN (...) da UNKNOWN y WHERE lo descarta; se agrega OR department_id IS NULL',
       'Filas: antes ' ||
         (SELECT COUNT(*) FROM employees WHERE department_id NOT IN (10, 20, 30)) ||
       ', después ' ||
         (SELECT COUNT(*) FROM employees WHERE department_id NOT IN (10, 20, 30) OR department_id IS NULL)
FROM dual
UNION ALL
SELECT 'I.3',
       'Departamentos de Estados Unidos con su cantidad de empleados',
       'Los departamentos de EE. UU. sin empleados muestran 1',
       'COUNT(*) cuenta la fila nula del LEFT JOIN; el WHERE sobre LOCATIONS vuelve interna esa reunión',
       'Suma de los conteos: antes ' ||
         (SELECT SUM(c) FROM (SELECT COUNT(*) AS c FROM departments d
                              LEFT JOIN employees e ON d.department_id = e.department_id
                              LEFT JOIN locations l ON d.location_id = l.location_id
                              WHERE l.country_id = 'US' GROUP BY d.department_name)) ||
       ', después ' ||
         (SELECT SUM(c) FROM (SELECT COUNT(e.employee_id) AS c FROM departments d
                              JOIN locations l ON l.location_id = d.location_id AND l.country_id = 'US'
                              LEFT JOIN employees e ON e.department_id = d.department_id
                              GROUP BY d.department_id))
FROM dual
UNION ALL
SELECT 'I.4',
       'El empleado mejor pagado de cada departamento',
       'Devuelve casi todos los empleados, no uno por departamento',
       'Agrupar también por last_name deja grupos de un empleado; MAX(salary) es su propio salario',
       'Filas: antes ' ||
         (SELECT COUNT(*) FROM (SELECT department_id, last_name FROM employees
                                GROUP BY department_id, last_name)) ||
       ', después ' ||
         (SELECT COUNT(*) FROM (SELECT RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rk
                                FROM employees) WHERE rk = 1)
FROM dual
UNION ALL
SELECT 'I.5',
       'Promedio de comisión contando como cero a quienes no la reciben',
       'El promedio sale inflado',
       'AVG ignora los NULL (divide entre 35, no entre 107); NVL(commission_pct, 0) los incluye',
       'Promedio: antes ' ||
         (SELECT TO_CHAR(ROUND(AVG(commission_pct), 4)) FROM employees) ||
       ', después ' ||
         (SELECT TO_CHAR(ROUND(AVG(NVL(commission_pct, 0)), 4)) FROM employees)
FROM dual;


/* =====================================================================
   COMENTARIOS FINALES DE JUSTIFICACIÓN TÉCNICA
   ---------------------------------------------------------------------
   1. Reuniones externas que se degradan a internas: pasa cuando una condición sobre la tabla
      opcional de un LEFT JOIN se escribe en WHERE (6.4, I.3). Las filas rellenadas con NULL no
      cumplen la condición y desaparecen. Para conservarlas, la condición va en el ON.
   2. Nulos:
      - En comparaciones: cualquier comparación con NULL da UNKNOWN y WHERE la descarta (I.2).
      - En NOT IN: un solo NULL en la lista hace que nunca sea verdadero (6.5).
      - En agregaciones: AVG, SUM, MIN, MAX y COUNT(columna) ignoran los NULL (I.5); COUNT(*) no,
        porque cuenta filas (6.2, I.1).
      - En aritmética: cualquier operación con NULL da NULL (total_compensation en 6.5).
      - En conjuntos: UNION/INTERSECT/MINUS tratan dos NULL como iguales; "=" no (6.8).
   3. Subconsulta correlacionada vs. tabla derivada vs. CTE (6.7): la correlacionada es natural
      para "comparar cada fila con su grupo", pero lógicamente se repite por fila; la tabla derivada
      y la CTE calculan el grupo una sola vez. Se prefiere la CTE cuando el mismo resultado se usa
      varias veces o se quiere legibilidad.
   4. Recursión (6.9): caso base (manager_id IS NULL) y paso recursivo (JOIN con la propia CTE)
      separados por UNION ALL; CYCLE protege contra ciclos.
   5. Ventana vs. agregación: se usa una función de ventana cuando se necesita el cálculo del grupo
      SIN perder el detalle de cada fila (6.10, 6.11); GROUP BY cuando se quiere una fila por grupo
      (6.6). Como las funciones de ventana se calculan después del WHERE, para filtrarlas hay que
      envolver la consulta (6.11, I.4).
   6. Ninguna consulta defectuosa del bloque I falla al ejecutarse: todas son errores LÓGICOS. Por
      eso conviene revisar primero los casos borde del bloque A.
   ===================================================================== */


/* =====================================================================
   ANEXO: VERIFICACIÓN CONCEPTUAL DE CIERRE (sección 8), respuestas para estudiar
   ---------------------------------------------------------------------
   1. ¿Cuándo un LEFT JOIN se comporta como un INNER JOIN?
      Cuando en el WHERE se pone una condición sobre una columna de la tabla de la derecha que un
      NULL no puede cumplir (por ejemplo e.salary > 10000): se eliminan las filas sin coincidencia.

   2. Subconsulta que devuelve {5, 7, NULL}:
      - 3 NOT IN (5, 7, NULL) = 3<>5 AND 3<>7 AND 3<>NULL = TRUE AND TRUE AND UNKNOWN = UNKNOWN.
        No devuelve la fila (no es TRUE).
      - 3 IN (5, 7, NULL) = 3=5 OR 3=7 OR 3=NULL = FALSE OR FALSE OR UNKNOWN = UNKNOWN.
        Tampoco devuelve la fila.
      (Para 5, IN sí da TRUE, porque TRUE OR UNKNOWN = TRUE.)

   3. Salarios 9000, 9000 y 7000, orden descendente:
      ROW_NUMBER: 1, 2, 3      RANK: 1, 1, 3      DENSE_RANK: 1, 1, 2

   4. WHERE filtra filas ANTES de agrupar; HAVING filtra grupos DESPUÉS de agrupar.
      Un alias del SELECT funciona en ORDER BY pero no en HAVING porque, en el orden lógico,
      HAVING se evalúa antes que el SELECT (el alias todavía no existe) y ORDER BY se evalúa
      después del SELECT (el alias ya existe).

   5. Segundo salario más alto de cada departamento (máximo cinco líneas):
*/
SELECT department_id, salary
FROM  (SELECT department_id, salary,
              DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS drk
       FROM employees)
WHERE  drk = 2 GROUP BY department_id, salary;
/*
      DENSE_RANK hace que "segundo salario" sea el segundo VALOR distinto, aunque el primero esté
      empatado; el GROUP BY deja una sola fila si varios empleados tienen ese mismo salario.
   ===================================================================== */

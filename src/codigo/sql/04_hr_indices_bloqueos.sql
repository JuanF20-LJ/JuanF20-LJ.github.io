/* =====================================================================
   TEMA 11. ÍNDICES Y PLAN DE EJECUCIÓN
   ===================================================================== */

-- Caso 11.1: Consultar los índices que ya tiene HR y sus columnas
SELECT i.table_name, i.index_name, i.uniqueness, c.column_name, c.column_position
FROM   user_indexes i
JOIN   user_ind_columns c ON c.index_name = i.index_name
WHERE  i.table_name IN ('EMPLOYEES', 'EMP_PRACTICA')          -- en el diccionario los nombres van en MAYÚSCULA
ORDER  BY i.table_name, i.index_name, c.column_position;

-- Caso 11.2: Ver el plan de una consulta SIN índice en la columna (FULL TABLE SCAN: lee toda la tabla)
EXPLAIN PLAN FOR
SELECT * FROM emp_practica WHERE last_name = 'King';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);                      -- muestra el plan que se acaba de generar

-- Caso 11.3: Crear un índice normal (B-tree) y ver el plan otra vez (INDEX RANGE SCAN)
CREATE INDEX ix_emp_practica_apellido ON emp_practica (last_name);

EXPLAIN PLAN FOR
SELECT * FROM emp_practica WHERE last_name = 'King';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);                      -- con tablas tan pequeñas Oracle puede preferir el FULL SCAN

-- Caso 11.4: Crear un índice compuesto (varias columnas; sirve si la consulta filtra por la PRIMERA)
CREATE INDEX ix_emp_practica_depto_sal ON emp_practica (department_id, salary);

-- Caso 11.5: Crear un índice único (además de acelerar, impide repetidos)
CREATE UNIQUE INDEX ux_emp_practica_email ON emp_practica (email);
-- INSERT INTO emp_practica (employee_id, last_name, email, hire_date, job_id) VALUES (999, 'X', 'SKING', SYSDATE, 'IT_PROG');
--   -> falla: ORA-00001 (valor único violado)

-- Caso 11.6: Índice basado en función: una consulta con UPPER(columna) NO usa un índice normal
CREATE INDEX ix_emp_practica_upper ON emp_practica (UPPER(last_name));

EXPLAIN PLAN FOR
SELECT * FROM emp_practica WHERE UPPER(last_name) = 'KING';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Caso 11.7: Forzar el uso de un índice con un HINT (comentario especial /*+ ... */ que lee el optimizador)
EXPLAIN PLAN FOR
SELECT /*+ INDEX(e ix_emp_practica_apellido) */ * FROM emp_practica e WHERE last_name = 'King';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Caso 11.8: Hacer un índice invisible (existe, pero el optimizador lo ignora; sirve para probar si hace falta)
ALTER INDEX ix_emp_practica_apellido INVISIBLE;
SELECT index_name, visibility FROM user_indexes WHERE table_name = 'EMP_PRACTICA';
ALTER INDEX ix_emp_practica_apellido VISIBLE;

-- Caso 11.9: Reconstruir un índice (lo reorganiza, por ejemplo después de muchos DELETE)
ALTER INDEX ix_emp_practica_depto_sal REBUILD;

-- Caso 11.10: Actualizar las estadísticas de la tabla (el optimizador las usa para decidir el plan)
-- EXEC ejecuta un procedimiento en una sola línea (no ponerle comentarios al final de la línea)
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'EMP_PRACTICA')

SELECT table_name, num_rows, last_analyzed FROM user_tables WHERE table_name = 'EMP_PRACTICA';

-- Caso 11.11: Eliminar un índice
DROP INDEX ix_emp_practica_upper;


/* =====================================================================
   TEMA 12. BLOQUEOS: SELECT ... FOR UPDATE
   Para verlo de verdad se necesitan DOS sesiones de HR abiertas
   (en SQL Developer: clic derecho en la conexión -> "Abrir hoja de trabajo no compartida", Ctrl+Shift+N).
   ===================================================================== */

-- Caso 12.1 (SESIÓN 1): Bloquear las filas que se van a modificar
SELECT employee_id, last_name, salary
FROM   emp_practica
WHERE  department_id = 60
FOR UPDATE;                                    -- las filas quedan bloqueadas hasta COMMIT o ROLLBACK

-- Caso 12.2 (SESIÓN 2): Intentar modificar una de esas filas -> se queda ESPERANDO (no responde)
-- UPDATE emp_practica SET salary = salary + 1 WHERE employee_id = 103;

-- Caso 12.3 (SESIÓN 2): Intentar bloquear sin esperar -> error inmediato ORA-00054 (recurso ocupado)
-- SELECT * FROM emp_practica WHERE employee_id = 103 FOR UPDATE NOWAIT;

-- Caso 12.4 (SESIÓN 2): Esperar como máximo 5 segundos -> ORA-30006 si sigue ocupado
-- SELECT * FROM emp_practica WHERE employee_id = 103 FOR UPDATE WAIT 5;

-- Caso 12.5 (SESIÓN 2): Bloquear solo las filas libres y saltar las ocupadas (útil para colas de trabajo)
-- SELECT employee_id, last_name FROM emp_practica WHERE department_id IN (60, 90) FOR UPDATE SKIP LOCKED;
--   -> devuelve solo los del 90, porque los del 60 los tiene la sesión 1

-- Caso 12.6 (SESIÓN 1): Liberar los bloqueos; la sesión 2 sigue y termina su UPDATE
ROLLBACK;

-- Caso 12.7: FOR UPDATE OF: en un JOIN, bloquear solo las filas de UNA de las tablas
SELECT e.employee_id, e.salary, d.department_name
FROM   emp_practica e
JOIN   departments d ON d.department_id = e.department_id
WHERE  d.department_id = 90
FOR UPDATE OF e.salary;                        -- bloquea emp_practica, no departments
ROLLBACK;

-- Caso 12.8: Bloquear la tabla completa en modo exclusivo (nadie más puede modificarla)
LOCK TABLE emp_practica IN EXCLUSIVE MODE;
ROLLBACK;                                      -- el COMMIT o ROLLBACK libera también este bloqueo

-- Nota: un UPDATE o DELETE normal también bloquea las filas que toca, hasta el COMMIT/ROLLBACK.
-- FOR UPDATE sirve para bloquearlas ANTES, cuando primero se leen y luego se deciden los cambios.


/* =====================================================================
   TEMA 13. LIMPIEZA (borrar todo lo creado en esta práctica)
   ===================================================================== */

DROP SYNONYM emp;
DROP SEQUENCE seq_practica;
DROP VIEW v_emp_it;
DROP VIEW v_nomina_depto;
DROP VIEW v_empleados_detalle;
DROP TABLE emp_altos PURGE;                    -- PURGE: no la deja en la papelera de reciclaje
DROP TABLE emp_bajos PURGE;
DROP TABLE emp_historico PURGE;
DROP TABLE emp_practica PURGE;                 -- al borrar la tabla se borran también sus índices

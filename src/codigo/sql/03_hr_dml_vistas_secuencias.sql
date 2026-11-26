/* =====================================================================
   TEMA 8. DML AVANZADO Y TRANSACCIONES
   Se trabaja sobre COPIAS para no dañar las tablas de HR.
   ===================================================================== */

-- Caso 8.1: Crear una copia de EMPLOYEES para practicar (CTAS = CREATE TABLE AS SELECT)
CREATE TABLE emp_practica AS
SELECT employee_id, first_name, last_name, email, hire_date, job_id, salary,
       commission_pct, manager_id, department_id
FROM   employees;

ALTER TABLE emp_practica ADD CONSTRAINT emp_practica_pk PRIMARY KEY (employee_id);   -- CTAS no copia las llaves

-- Caso 8.2: Crear una tabla vacía con la misma estructura (truco: WHERE 1 = 0 no trae filas)
CREATE TABLE emp_historico AS
SELECT employee_id, last_name, salary, SYSDATE AS fecha_registro
FROM   employees
WHERE  1 = 0;

-- Caso 8.3: Insertar en bloque desde una consulta (INSERT ... SELECT)
INSERT INTO emp_historico (employee_id, last_name, salary, fecha_registro)
SELECT employee_id, last_name, salary, SYSDATE
FROM   emp_practica
WHERE  department_id = 60;

SELECT * FROM emp_historico;

-- Caso 8.4: Actualizar con una subconsulta: subir al salario mínimo de su cargo a quien esté por debajo + 500
UPDATE emp_practica e
SET    e.salary = (SELECT j.min_salary + 500 FROM jobs j WHERE j.job_id = e.job_id)
WHERE  e.salary < (SELECT j.min_salary + 500 FROM jobs j WHERE j.job_id = e.job_id);

-- Caso 8.5: Actualizar varias columnas a la vez con una subconsulta
UPDATE emp_practica
SET   (job_id, salary) = (SELECT job_id, salary FROM employees WHERE employee_id = 104)
WHERE  employee_id = 107;

-- Caso 8.6: Eliminar con subconsulta: borrar los empleados de los departamentos de Toronto
DELETE FROM emp_practica
WHERE  department_id IN (SELECT d.department_id
                         FROM   departments d JOIN locations l ON l.location_id = d.location_id
                         WHERE  l.city = 'Toronto');

-- Caso 8.7: MERGE: si el empleado ya existe en el histórico se actualiza; si no, se inserta (UPSERT)
MERGE INTO emp_historico h
USING (SELECT employee_id, last_name, salary FROM emp_practica WHERE department_id IN (60, 90)) p
ON    (h.employee_id = p.employee_id)
WHEN MATCHED THEN
     UPDATE SET h.salary = p.salary, h.fecha_registro = SYSDATE
WHEN NOT MATCHED THEN
     INSERT (employee_id, last_name, salary, fecha_registro)
     VALUES (p.employee_id, p.last_name, p.salary, SYSDATE);

SELECT * FROM emp_historico ORDER BY employee_id;

-- Caso 8.8: Inserción múltiple: una misma consulta reparte filas en dos tablas (INSERT ALL condicional)
CREATE TABLE emp_altos AS SELECT employee_id, last_name, salary FROM employees WHERE 1 = 0;
CREATE TABLE emp_bajos AS SELECT employee_id, last_name, salary FROM employees WHERE 1 = 0;

INSERT ALL
  WHEN salary >= 10000 THEN INTO emp_altos VALUES (employee_id, last_name, salary)
  WHEN salary <  5000  THEN INTO emp_bajos VALUES (employee_id, last_name, salary)
SELECT employee_id, last_name, salary FROM employees;

SELECT 'ALTOS' AS tabla, COUNT(*) FROM emp_altos
UNION ALL
SELECT 'BAJOS', COUNT(*) FROM emp_bajos;

-- Caso 8.9: Transacciones con SAVEPOINT (puntos de guardado dentro de una transacción)
COMMIT;                                                    -- deja confirmado todo lo anterior

UPDATE emp_practica SET salary = salary * 2 WHERE department_id = 90;
SAVEPOINT despues_de_duplicar;                             -- punto al que se puede volver

DELETE FROM emp_practica WHERE department_id = 90;
SELECT COUNT(*) FROM emp_practica WHERE department_id = 90;   -- 0: se borraron

ROLLBACK TO despues_de_duplicar;                           -- deshace SOLO el DELETE
SELECT last_name, salary FROM emp_practica WHERE department_id = 90;   -- volvieron, con salario doble

ROLLBACK;                                                  -- deshace todo desde el último COMMIT
SELECT last_name, salary FROM emp_practica WHERE department_id = 90;   -- salario original

-- Nota: un CREATE, ALTER o DROP hace COMMIT automático de lo que estuviera pendiente.


/* =====================================================================
   TEMA 9. VISTAS
   ===================================================================== */

-- Caso 9.1: Crear una vista con los datos completos de cada empleado (vista compleja: varias tablas)
CREATE OR REPLACE VIEW v_empleados_detalle AS
SELECT e.employee_id, e.first_name || ' ' || e.last_name AS empleado,
       j.job_title, d.department_name, l.city, e.salary
FROM   employees e
JOIN   jobs j             ON j.job_id = e.job_id
LEFT   JOIN departments d ON d.department_id = e.department_id
LEFT   JOIN locations l   ON l.location_id = d.location_id;

-- Caso 9.2: Consultar la vista como si fuera una tabla
SELECT * FROM v_empleados_detalle WHERE city = 'Seattle' ORDER BY salary DESC;

-- Caso 9.3: Crear una vista que solo deja modificar filas del departamento 60 (WITH CHECK OPTION)
CREATE OR REPLACE VIEW v_emp_it AS
SELECT employee_id, last_name, salary, department_id
FROM   emp_practica
WHERE  department_id = 60
WITH CHECK OPTION CONSTRAINT v_emp_it_ck;      -- impide que un UPDATE/INSERT deje la fila fuera de la vista

UPDATE v_emp_it SET salary = salary + 100 WHERE employee_id = 103;     -- funciona
-- UPDATE v_emp_it SET department_id = 50 WHERE employee_id = 103;     -- falla: ORA-01402 (la fila saldría de la vista)
ROLLBACK;

-- Caso 9.4: Crear una vista de solo lectura
CREATE OR REPLACE VIEW v_nomina_depto AS
SELECT department_id, COUNT(*) AS empleados, SUM(salary) AS nomina
FROM   employees
GROUP  BY department_id
WITH READ ONLY;                                 -- no permite INSERT, UPDATE ni DELETE

-- Caso 9.5: Consultar las vistas creadas y su texto
SELECT view_name, text FROM user_views;


/* =====================================================================
   TEMA 10. SECUENCIAS Y SINÓNIMOS
   ===================================================================== */

-- Caso 10.1: Crear una secuencia (generador de números consecutivos)
CREATE SEQUENCE seq_practica
  START WITH 1000
  INCREMENT BY 5
  NOCACHE;                                      -- NOCACHE: no reserva números en memoria (no deja huecos al reiniciar)

-- Caso 10.2: Usar la secuencia
SELECT seq_practica.NEXTVAL FROM dual;          -- DUAL: tabla de una sola fila para hacer cálculos
SELECT seq_practica.CURRVAL FROM dual;          -- CURRVAL solo funciona después de un NEXTVAL en la sesión

INSERT INTO emp_practica (employee_id, last_name, email, hire_date, job_id, salary)
VALUES (seq_practica.NEXTVAL, 'Practica', 'PRACTICA', SYSDATE, 'IT_PROG', 6000);

SELECT employee_id, last_name FROM emp_practica WHERE last_name = 'Practica';
ROLLBACK;                                       -- el número de la secuencia NO se devuelve con el ROLLBACK

-- Caso 10.3: Crear un sinónimo (otro nombre para un objeto)
CREATE SYNONYM emp FOR emp_practica;
SELECT COUNT(*) FROM emp;

-- Caso 10.4: Consultar secuencias y sinónimos
SELECT sequence_name, last_number, increment_by FROM user_sequences;
SELECT synonym_name, table_name FROM user_synonyms;

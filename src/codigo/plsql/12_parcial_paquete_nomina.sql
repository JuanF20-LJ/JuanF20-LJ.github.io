/*
================================================================================
  PARCIAL - PL/SQL
--------------------------------------------------------------------------------
  INTEGRANTES:
    - Luna Calderón Montenegro
    - Samuel Mesa
    - Juan Felipe Lozada Jara

  ENUNCIADO
  1. Crear un paquete.
     - Simular el proceso de nómina de las tablas de recursos humanos.
     - Al menos deben quedar dos objetos expuestos en la especificación.
     - Excepciones.
     - Buenas prácticas.
     - Nombramiento.

  Tablas del esquema HR:
    COUNTRIES, DEPARTMENTS, EMPLOYEES, JOBS, JOBS_HISTORY, LOCATIONS, REGIONS
================================================================================

  BORRADOR INICIAL

  SELECT * FROM jobs;
  SELECT * FROM employees;

  CREATE OR REPLACE PACKAGE pck_proceso_nomina IS

  END pck_proceso_nomina;
*/


--------------------------------------------------------------------------------
-- ESPECIFICACIÓN DEL PAQUETE
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pck_proceso_nomina IS

    PROCEDURE SP_AUMENTAR_SUELDO (
        p_id_empleado IN NUMBER,
        p_aumento     IN NUMBER);

    FUNCTION FN_SALARIO_PROMEDIO_DEPARTAMENTO (
        p_department_id IN NUMBER);

    FUNCTION FN_SALARIO_con_DEPARTAMENTO (
        p_department_id IN NUMBER);

END pck_proceso_nomina;


--------------------------------------------------------------------------------
-- FUNCIÓN: SALARIO CON COMISIÓN
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_salario_con_comision (
    p_id_empleado IN NUMBER)
RETURN NUMBER
IS
    vnSalarioCalculado NUMBER;
    vnSalarioBase      employees.salary%TYPE;
    vnComision         employees.salary%TYPE;
    e_sin_comision     EXCEPTION;
BEGIN
    SELECT salary         INTO vnSalarioBase FROM employees WHERE employee_id = p_id_empleado;
    SELECT commission_pct INTO vnComision    FROM employees WHERE employee_id = p_id_empleado;

    vnSalarioCalculado := (vnSalarioBase * vnComision) + vnSalarioBase;

    RETURN vnSalarioCalculado;
END fn_salario_con_comision;
/

SHOW ERRORS


--------------------------------------------------------------------------------
-- PRUEBA
--------------------------------------------------------------------------------
SELECT fn_salario_con_comision(employee_id) FROM employees;

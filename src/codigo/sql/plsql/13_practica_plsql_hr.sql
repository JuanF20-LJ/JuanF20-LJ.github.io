/* =====================================================================
   PRÁCTICA 2 - PL/SQL (Oracle) - Esquema HR
   ---------------------------------------------------------------------
   Conectarse como el usuario HR.
   En SQL Developer: ejecutar cada bloque seleccionándolo y con F5
   (o todo el script con F5). Los bloques PL/SQL terminan con "/" en una
   línea sola: eso le dice a la herramienta que ejecute el bloque.

   Para ver lo que imprime DBMS_OUTPUT.PUT_LINE:
     - Ejecutar SET SERVEROUTPUT ON (abajo), o
     - En SQL Developer: Ver -> Salida de DBMS -> botón "+" -> conexión HR.

   Se trabaja sobre COPIAS de las tablas para no dañar HR.

   TEMAS
     0.  Preparación
     1.  Bloque anónimo, variables, %TYPE, %ROWTYPE y SELECT INTO
     2.  Estructuras de control (IF, CASE, LOOP, WHILE, FOR)
     3.  Cursores (implícitos, explícitos, FOR, con parámetros, FOR UPDATE)
     4.  Registros, colecciones, BULK COLLECT y FORALL
     5.  Manejo de excepciones
     6.  Procedimientos
     7.  Funciones
     8.  Triggers
     9.  Paquetes
     10. SQL dinámico
     11. Consultar los objetos creados en el diccionario
     12. Limpieza
   ===================================================================== */

SET SERVEROUTPUT ON


/* =====================================================================
   TEMA 0. PREPARACIÓN
   ===================================================================== */

-- Caso 0.1: Borrar las tablas de práctica si ya existen (para poder correr el script varias veces).
-- Oracle (antes de la 23ai) no tiene DROP TABLE IF EXISTS; se simula atrapando el error -942 ("la tabla no existe").
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE  table_name IN ('PR_EMPLEADOS', 'PR_AUDITORIA', 'PR_ERRORES')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';   -- SQL dinámico: el DROP se arma como texto
  END LOOP;
END;
/

-- Caso 0.2: Crear la copia de EMPLOYEES con la que se practica
CREATE TABLE pr_empleados AS
SELECT employee_id, first_name, last_name, email, hire_date, job_id, salary,
       commission_pct, manager_id, department_id
FROM   employees;

ALTER TABLE pr_empleados ADD CONSTRAINT pr_empleados_pk PRIMARY KEY (employee_id);
ALTER TABLE pr_empleados ADD CONSTRAINT pr_empleados_email_uk UNIQUE (email);

-- Caso 0.3: Crear una tabla de auditoría (la llenan los triggers del tema 8)
CREATE TABLE pr_auditoria (
  id_auditoria  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- columna autoincremental (Oracle 12c+)
  tabla         VARCHAR2(30),
  operacion     VARCHAR2(10),
  employee_id   NUMBER,
  salario_antes NUMBER,
  salario_nuevo NUMBER,
  usuario       VARCHAR2(30) DEFAULT USER,
  fecha         DATE         DEFAULT SYSDATE
);

-- Caso 0.4: Crear una tabla para registrar errores (la usa el tema 5)
CREATE TABLE pr_errores (
  fecha    DATE DEFAULT SYSDATE,
  proceso  VARCHAR2(50),
  codigo   NUMBER,
  mensaje  VARCHAR2(4000)
);


/* =====================================================================
   TEMA 1. BLOQUE ANÓNIMO, VARIABLES, %TYPE, %ROWTYPE Y SELECT INTO
   Estructura:  DECLARE (opcional) -> BEGIN (obligatorio) -> EXCEPTION (opcional) -> END;
   ===================================================================== */

-- Caso 1.1: El bloque más sencillo: imprimir un mensaje
BEGIN
  DBMS_OUTPUT.PUT_LINE('Hola desde PL/SQL');
END;
/

-- Caso 1.2: Declarar variables y constantes, y operar con ellas
DECLARE
  v_nombre    VARCHAR2(50) := 'Bloom';              -- := es asignación
  v_salario   NUMBER(8,2)  := 4500.50;
  v_fecha     DATE         := SYSDATE;
  v_activo    BOOLEAN      := TRUE;                 -- BOOLEAN existe en PL/SQL, no en SQL (hasta 23ai)
  c_aumento   CONSTANT NUMBER := 0.10;              -- CONSTANT: no se puede cambiar
BEGIN
  v_salario := v_salario * (1 + c_aumento);
  DBMS_OUTPUT.PUT_LINE('Nombre: ' || v_nombre);
  DBMS_OUTPUT.PUT_LINE('Salario con aumento: ' || v_salario);
  DBMS_OUTPUT.PUT_LINE('Fecha: ' || TO_CHAR(v_fecha, 'DD/MM/YYYY HH24:MI'));
  IF v_activo THEN
    DBMS_OUTPUT.PUT_LINE('Está activo');            -- un BOOLEAN no se puede concatenar con ||
  END IF;
END;
/

-- Caso 1.3: Consultar un empleado con SELECT INTO y %TYPE (la variable toma el tipo de la columna)
DECLARE
  v_apellido  employees.last_name%TYPE;             -- si la columna cambia de tamaño, la variable también
  v_salario   employees.salary%TYPE;
  v_cargo     jobs.job_title%TYPE;
BEGIN
  SELECT e.last_name, e.salary, j.job_title
  INTO   v_apellido, v_salario, v_cargo             -- SELECT INTO debe devolver EXACTAMENTE una fila
  FROM   employees e
  JOIN   jobs j ON j.job_id = e.job_id
  WHERE  e.employee_id = 100;

  DBMS_OUTPUT.PUT_LINE(v_apellido || ' - ' || v_cargo || ' - $' || v_salario);
END;
/

-- Caso 1.4: Consultar una fila completa con %ROWTYPE (una variable con todas las columnas de la tabla)
DECLARE
  r_emp employees%ROWTYPE;
BEGIN
  SELECT * INTO r_emp FROM employees WHERE employee_id = 101;
  DBMS_OUTPUT.PUT_LINE('Empleado: ' || r_emp.first_name || ' ' || r_emp.last_name);   -- variable.columna
  DBMS_OUTPUT.PUT_LINE('Correo: '   || r_emp.email);
  DBMS_OUTPUT.PUT_LINE('Contratado: ' || TO_CHAR(r_emp.hire_date, 'DD/MM/YYYY'));
END;
/

-- Caso 1.5: Usar variables de sustitución (SQL Developer pide el valor en una ventana al ejecutar)
DECLARE
  v_id      employees.employee_id%TYPE := &id_empleado;     -- & = el programa pide el valor (probar con 103)
  v_nombre  VARCHAR2(100);
BEGIN
  SELECT first_name || ' ' || last_name INTO v_nombre
  FROM   employees WHERE employee_id = v_id;
  DBMS_OUTPUT.PUT_LINE('El empleado ' || v_id || ' es ' || v_nombre);
END;
/

-- Caso 1.6: Bloques anidados y alcance de las variables
DECLARE
  v_mensaje VARCHAR2(30) := 'bloque externo';
BEGIN
  DECLARE
    v_mensaje VARCHAR2(30) := 'bloque interno';    -- misma variable: la interna "tapa" a la externa
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Adentro: ' || v_mensaje);
  END;
  DBMS_OUTPUT.PUT_LINE('Afuera: ' || v_mensaje);
END;
/


/* =====================================================================
   TEMA 2. ESTRUCTURAS DE CONTROL
   ===================================================================== */

-- Caso 2.1: IF / ELSIF / ELSE: clasificar el salario de un empleado
DECLARE
  v_salario employees.salary%TYPE;
BEGIN
  SELECT salary INTO v_salario FROM employees WHERE employee_id = 104;
  IF v_salario >= 15000 THEN
    DBMS_OUTPUT.PUT_LINE('Salario alto: ' || v_salario);
  ELSIF v_salario >= 8000 THEN                       -- ojo: es ELSIF, no ELSEIF
    DBMS_OUTPUT.PUT_LINE('Salario medio: ' || v_salario);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Salario bajo: ' || v_salario);
  END IF;
END;
/

-- Caso 2.2: CASE como sentencia y como expresión
DECLARE
  v_job     employees.job_id%TYPE;
  v_area    VARCHAR2(30);
BEGIN
  SELECT job_id INTO v_job FROM employees WHERE employee_id = 145;

  v_area := CASE SUBSTR(v_job, 1, 2)                -- CASE como expresión: devuelve un valor
              WHEN 'SA' THEN 'Ventas'
              WHEN 'IT' THEN 'Tecnología'
              WHEN 'ST' THEN 'Bodega'
              ELSE 'Otra área'
            END;
  DBMS_OUTPUT.PUT_LINE(v_job || ' pertenece a ' || v_area);

  CASE                                              -- CASE como sentencia: ejecuta instrucciones
    WHEN v_job LIKE '%MAN' THEN DBMS_OUTPUT.PUT_LINE('Es gerente');
    ELSE DBMS_OUTPUT.PUT_LINE('No es gerente');
  END CASE;
END;
/

-- Caso 2.3: LOOP básico con EXIT WHEN (se repite hasta que se cumpla la condición)
DECLARE
  v_i NUMBER := 1;
BEGIN
  LOOP
    DBMS_OUTPUT.PUT_LINE('Vuelta ' || v_i);
    v_i := v_i + 1;
    EXIT WHEN v_i > 3;                              -- sin un EXIT el ciclo sería infinito
  END LOOP;
END;
/

-- Caso 2.4: WHILE: calcular en cuántos años se duplica un salario con aumentos del 5 %
DECLARE
  v_salario NUMBER := 5000;
  v_anios   NUMBER := 0;
BEGIN
  WHILE v_salario < 10000 LOOP
    v_salario := v_salario * 1.05;
    v_anios   := v_anios + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Se duplica en ' || v_anios || ' años (' || ROUND(v_salario, 2) || ')');
END;
/

-- Caso 2.5: FOR numérico, REVERSE y CONTINUE
BEGIN
  FOR i IN 1 .. 10 LOOP                             -- "i" se declara sola y solo existe dentro del ciclo
    CONTINUE WHEN MOD(i, 2) = 0;                    -- CONTINUE salta a la siguiente vuelta (salta los pares)
    DBMS_OUTPUT.PUT_LINE('Impar: ' || i);
  END LOOP;

  FOR i IN REVERSE 1 .. 3 LOOP                      -- REVERSE: cuenta hacia atrás
    DBMS_OUTPUT.PUT_LINE('Cuenta regresiva: ' || i);
  END LOOP;
END;
/

-- Caso 2.6: Ciclos anidados con etiquetas: salir del ciclo externo desde el interno
BEGIN
  <<externo>>                                       -- etiqueta para nombrar el ciclo
  FOR i IN 1 .. 3 LOOP
    FOR j IN 1 .. 3 LOOP
      EXIT externo WHEN i * j = 4;                  -- termina los DOS ciclos
      DBMS_OUTPUT.PUT_LINE(i || ' x ' || j || ' = ' || i * j);
    END LOOP;
  END LOOP externo;
END;
/


/* =====================================================================
   TEMA 3. CURSORES
   Un cursor es el resultado de una consulta que se recorre fila por fila.
   ===================================================================== */

-- Caso 3.1: Cursor IMPLÍCITO: Oracle lo crea solo en cada INSERT/UPDATE/DELETE; se consulta con SQL%
BEGIN
  UPDATE pr_empleados SET salary = salary * 1.05 WHERE department_id = 60;
  DBMS_OUTPUT.PUT_LINE('Filas actualizadas: ' || SQL%ROWCOUNT);   -- cuántas filas tocó la última sentencia

  DELETE FROM pr_empleados WHERE department_id = 999;
  IF SQL%NOTFOUND THEN                                              -- TRUE si no afectó ninguna fila
    DBMS_OUTPUT.PUT_LINE('No había empleados en el departamento 999');
  END IF;
  ROLLBACK;
END;
/

-- Caso 3.2: Cursor EXPLÍCITO paso a paso: DECLARE -> OPEN -> FETCH -> CLOSE
DECLARE
  CURSOR c_emp IS
    SELECT last_name, salary FROM employees WHERE department_id = 30 ORDER BY salary DESC;
  v_apellido employees.last_name%TYPE;
  v_salario  employees.salary%TYPE;
BEGIN
  OPEN c_emp;                                       -- ejecuta la consulta
  LOOP
    FETCH c_emp INTO v_apellido, v_salario;         -- trae la siguiente fila
    EXIT WHEN c_emp%NOTFOUND;                       -- ya no hay más filas
    DBMS_OUTPUT.PUT_LINE(c_emp%ROWCOUNT || '. ' || v_apellido || ' - ' || v_salario);   -- %ROWCOUNT: filas leídas
  END LOOP;
  CLOSE c_emp;                                      -- libera el cursor
END;
/

-- Caso 3.3: Cursor FOR (forma corta: abre, recorre y cierra solo)
DECLARE
  CURSOR c_deptos IS
    SELECT d.department_name, COUNT(e.employee_id) AS total
    FROM   departments d
    LEFT   JOIN employees e ON e.department_id = d.department_id
    GROUP  BY d.department_name
    HAVING COUNT(e.employee_id) > 0
    ORDER  BY total DESC;
BEGIN
  FOR r IN c_deptos LOOP                            -- "r" es un registro con las columnas del cursor
    DBMS_OUTPUT.PUT_LINE(RPAD(r.department_name, 20) || r.total);
  END LOOP;
END;
/

-- Caso 3.4: Cursor FOR con la consulta escrita directamente (sin declarar el cursor)
BEGIN
  FOR r IN (SELECT first_name, last_name FROM employees WHERE manager_id = 100) LOOP
    DBMS_OUTPUT.PUT_LINE('Reporta a King: ' || r.first_name || ' ' || r.last_name);
  END LOOP;
END;
/

-- Caso 3.5: Cursor con PARÁMETROS: el mismo cursor para distintos departamentos
DECLARE
  CURSOR c_por_depto (p_depto NUMBER, p_minimo NUMBER DEFAULT 0) IS
    SELECT last_name, salary FROM employees
    WHERE  department_id = p_depto AND salary >= p_minimo;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- Departamento 50, salario >= 7000 ---');
  FOR r IN c_por_depto(50, 7000) LOOP
    DBMS_OUTPUT.PUT_LINE(r.last_name || ' ' || r.salary);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('--- Departamento 90 (sin mínimo) ---');
  FOR r IN c_por_depto(90) LOOP                     -- p_minimo toma su valor por defecto
    DBMS_OUTPUT.PUT_LINE(r.last_name || ' ' || r.salary);
  END LOOP;
END;
/

-- Caso 3.6: Cursor FOR UPDATE + WHERE CURRENT OF: actualizar justo la fila que se está leyendo
DECLARE
  CURSOR c_aumento IS
    SELECT employee_id, last_name, salary
    FROM   pr_empleados
    WHERE  department_id = 50 AND salary < 3000
    FOR UPDATE OF salary;                           -- bloquea las filas al abrir el cursor
BEGIN
  FOR r IN c_aumento LOOP
    UPDATE pr_empleados
    SET    salary = salary + 200
    WHERE  CURRENT OF c_aumento;                    -- "la fila actual del cursor" (sin buscarla por id)
    DBMS_OUTPUT.PUT_LINE(r.last_name || ': ' || r.salary || ' -> ' || (r.salary + 200));
  END LOOP;
  COMMIT;                                           -- libera los bloqueos
END;
/

-- Caso 3.7: Cursor variable (REF CURSOR): la consulta se decide al ejecutar
DECLARE
  c_datos     SYS_REFCURSOR;                        -- tipo de cursor ya definido por Oracle
  v_texto     VARCHAR2(100);
  v_opcion    VARCHAR2(10) := 'DEPTOS';             -- cambiar a 'CARGOS' y volver a ejecutar
BEGIN
  IF v_opcion = 'DEPTOS' THEN
    OPEN c_datos FOR SELECT department_name FROM departments WHERE ROWNUM <= 5;
  ELSE
    OPEN c_datos FOR SELECT job_title FROM jobs WHERE ROWNUM <= 5;
  END IF;
  LOOP
    FETCH c_datos INTO v_texto;
    EXIT WHEN c_datos%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_texto);
  END LOOP;
  CLOSE c_datos;
END;
/


/* =====================================================================
   TEMA 4. REGISTROS, COLECCIONES, BULK COLLECT Y FORALL
   ===================================================================== */

-- Caso 4.1: Registro propio (TYPE ... IS RECORD): agrupar datos de distintas tablas
DECLARE
  TYPE t_ficha IS RECORD (
    nombre        VARCHAR2(50),
    departamento  departments.department_name%TYPE,
    ciudad        locations.city%TYPE
  );
  r_ficha t_ficha;
BEGIN
  SELECT e.first_name || ' ' || e.last_name, d.department_name, l.city
  INTO   r_ficha
  FROM   employees e
  JOIN   departments d ON d.department_id = e.department_id
  JOIN   locations l   ON l.location_id = d.location_id
  WHERE  e.employee_id = 200;
  DBMS_OUTPUT.PUT_LINE(r_ficha.nombre || ' trabaja en ' || r_ficha.departamento || ' (' || r_ficha.ciudad || ')');
END;
/

-- Caso 4.2: Arreglo asociativo (INDEX BY): una "tabla" en memoria con índice propio
DECLARE
  TYPE t_salarios IS TABLE OF NUMBER INDEX BY VARCHAR2(10);   -- índice de texto: como un diccionario
  v_promedios t_salarios;
  v_clave     VARCHAR2(10);
BEGIN
  FOR r IN (SELECT job_id, ROUND(AVG(salary)) AS prom FROM employees GROUP BY job_id) LOOP
    v_promedios(r.job_id) := r.prom;                -- guarda usando el job_id como clave
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Promedio IT_PROG: ' || v_promedios('IT_PROG'));
  DBMS_OUTPUT.PUT_LINE('Cargos guardados: ' || v_promedios.COUNT);     -- métodos: COUNT, FIRST, NEXT, EXISTS...

  v_clave := v_promedios.FIRST;                     -- recorrer en orden de clave
  WHILE v_clave IS NOT NULL LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(v_clave, 12) || v_promedios(v_clave));
    v_clave := v_promedios.NEXT(v_clave);
  END LOOP;
END;
/

-- Caso 4.3: BULK COLLECT: traer muchas filas a una colección en UNA sola ida a la base (más rápido que fila por fila)
DECLARE
  TYPE t_empleados IS TABLE OF employees%ROWTYPE;   -- tabla anidada de filas completas
  v_lista t_empleados;
BEGIN
  SELECT * BULK COLLECT INTO v_lista
  FROM   employees
  WHERE  department_id = 100;

  DBMS_OUTPUT.PUT_LINE('Se cargaron ' || v_lista.COUNT || ' empleados');
  FOR i IN 1 .. v_lista.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(i || '. ' || v_lista(i).last_name || ' - ' || v_lista(i).salary);
  END LOOP;
END;
/

-- Caso 4.4: FORALL: enviar muchos UPDATE en UNA sola ida a la base
DECLARE
  TYPE t_ids IS TABLE OF pr_empleados.employee_id%TYPE;
  v_ids t_ids;
BEGIN
  SELECT employee_id BULK COLLECT INTO v_ids
  FROM   pr_empleados WHERE job_id = 'ST_CLERK';

  FORALL i IN 1 .. v_ids.COUNT                      -- FORALL no es un ciclo normal: lleva UNA sola sentencia DML
    UPDATE pr_empleados SET salary = salary + 100 WHERE employee_id = v_ids(i);

  DBMS_OUTPUT.PUT_LINE('Empleados actualizados: ' || SQL%ROWCOUNT);
  ROLLBACK;
END;
/

-- Caso 4.5: BULK COLLECT con LIMIT: procesar de a pocos para no llenar la memoria con tablas grandes
DECLARE
  CURSOR c_emp IS SELECT last_name FROM employees ORDER BY last_name;
  TYPE t_nombres IS TABLE OF employees.last_name%TYPE;
  v_lote  t_nombres;
  v_lotes NUMBER := 0;
BEGIN
  OPEN c_emp;
  LOOP
    FETCH c_emp BULK COLLECT INTO v_lote LIMIT 25;  -- 25 filas por vuelta
    EXIT WHEN v_lote.COUNT = 0;                     -- con LIMIT se pregunta por COUNT, no por %NOTFOUND
    v_lotes := v_lotes + 1;
    DBMS_OUTPUT.PUT_LINE('Lote ' || v_lotes || ': ' || v_lote.COUNT || ' filas, desde ' || v_lote(1));
  END LOOP;
  CLOSE c_emp;
END;
/


/* =====================================================================
   TEMA 5. MANEJO DE EXCEPCIONES
   Cuando ocurre un error, el bloque salta a EXCEPTION y busca un WHEN que lo atienda.
   ===================================================================== */

-- Caso 5.1: NO_DATA_FOUND: el SELECT INTO no encontró ninguna fila
DECLARE
  v_apellido employees.last_name%TYPE;
BEGIN
  SELECT last_name INTO v_apellido FROM employees WHERE employee_id = 9999;
  DBMS_OUTPUT.PUT_LINE('Esto no se imprime');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No existe un empleado con ese id');
END;
/

-- Caso 5.2: TOO_MANY_ROWS: el SELECT INTO trajo más de una fila
DECLARE
  v_apellido employees.last_name%TYPE;
BEGIN
  SELECT last_name INTO v_apellido FROM employees WHERE department_id = 50;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('La consulta devolvió varias filas; usar un cursor');
END;
/

-- Caso 5.3: Varias excepciones predefinidas en el mismo bloque, y SQLCODE / SQLERRM
DECLARE
  v_resultado NUMBER;
  v_texto     VARCHAR2(3);
  v_opcion    NUMBER := 1;                          -- probar con 1, 2, 3 y 4
BEGIN
  IF v_opcion = 1 THEN
    v_resultado := 100 / 0;                         -- ZERO_DIVIDE
  ELSIF v_opcion = 2 THEN
    v_texto := 'TEXTO LARGO';                       -- VALUE_ERROR: no cabe en VARCHAR2(3)
  ELSIF v_opcion = 3 THEN
    INSERT INTO pr_empleados (employee_id, last_name, email, hire_date, job_id)
    VALUES (100, 'Repetido', 'REPETIDO', SYSDATE, 'IT_PROG');   -- DUP_VAL_ON_INDEX: el id 100 ya existe
  ELSE
    v_resultado := TO_NUMBER('abc');                -- INVALID_NUMBER / VALUE_ERROR
  END IF;
EXCEPTION
  WHEN ZERO_DIVIDE THEN
    DBMS_OUTPUT.PUT_LINE('No se puede dividir entre cero');
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('Ya existe un empleado con ese id o correo');
  WHEN VALUE_ERROR THEN
    DBMS_OUTPUT.PUT_LINE('Valor inválido o demasiado largo');
  WHEN OTHERS THEN                                  -- atrapa cualquier otro error; siempre va de último
    DBMS_OUTPUT.PUT_LINE('Error ' || SQLCODE || ': ' || SQLERRM);   -- código y mensaje del error
END;
/

-- Caso 5.4: Excepción definida por el usuario: una regla de negocio propia
DECLARE
  e_salario_excesivo EXCEPTION;                     -- se declara como una variable
  v_salario   NUMBER := 30000;
  v_maximo    jobs.max_salary%TYPE;
BEGIN
  SELECT max_salary INTO v_maximo FROM jobs WHERE job_id = 'IT_PROG';
  IF v_salario > v_maximo THEN
    RAISE e_salario_excesivo;                       -- se "lanza" a mano
  END IF;
  DBMS_OUTPUT.PUT_LINE('Salario válido');
EXCEPTION
  WHEN e_salario_excesivo THEN
    DBMS_OUTPUT.PUT_LINE('El salario ' || v_salario || ' supera el máximo del cargo (' || v_maximo || ')');
END;
/

-- Caso 5.5: RAISE_APPLICATION_ERROR: lanzar un error con código y mensaje propios (entre -20000 y -20999)
DECLARE
  v_cuantos NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cuantos FROM employees WHERE department_id = 120;
  IF v_cuantos = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'El departamento 120 no tiene empleados');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Capturado -> ' || SQLCODE || ' ' || SQLERRM);
END;
/

-- Caso 5.6: PRAGMA EXCEPTION_INIT: ponerle nombre a un error de Oracle que no tiene nombre predefinido
DECLARE
  e_hijos_existentes EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_hijos_existentes, -2292);   -- ORA-02292: hay filas hijas que apuntan a esta (llave foránea)
BEGIN
  DELETE FROM departments WHERE department_id = 60;   -- la tabla REAL: tiene empleados, así que falla
EXCEPTION
  WHEN e_hijos_existentes THEN
    DBMS_OUTPUT.PUT_LINE('No se puede borrar: el departamento tiene empleados');
END;
/

-- Caso 5.7: Propagación: un error que no se atiende adentro sube al bloque de afuera
BEGIN
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Bloque interno');
    RAISE NO_DATA_FOUND;                            -- el interno no tiene EXCEPTION...
  END;
  DBMS_OUTPUT.PUT_LINE('Esto no se ejecuta');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('...así que lo atiende el bloque externo');
END;
/

-- Caso 5.8: Registrar el error en una tabla y volver a lanzarlo con RAISE
DECLARE
  v_codigo  NUMBER;
  v_mensaje VARCHAR2(4000);
BEGIN
  UPDATE pr_empleados SET email = 'SKING' WHERE employee_id = 101;   -- correo repetido -> error de UNIQUE
EXCEPTION
  WHEN OTHERS THEN
    v_codigo  := SQLCODE;                           -- SQLCODE/SQLERRM no se pueden usar directo en un INSERT
    v_mensaje := SQLERRM;
    INSERT INTO pr_errores (proceso, codigo, mensaje) VALUES ('Caso 5.8', v_codigo, v_mensaje);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Error guardado en PR_ERRORES');
    -- RAISE;                                       -- quitar el comentario para relanzar el error después de registrarlo
END;
/

SELECT * FROM pr_errores;


/* =====================================================================
   TEMA 6. PROCEDIMIENTOS
   Bloque con nombre que se guarda en la base. Realiza una tarea.
   ===================================================================== */

-- Caso 6.1: Procedimiento sin parámetros
CREATE OR REPLACE PROCEDURE pr_listar_departamentos IS
BEGIN
  FOR r IN (SELECT department_id, department_name FROM departments ORDER BY department_id) LOOP
    DBMS_OUTPUT.PUT_LINE(r.department_id || ' - ' || r.department_name);
  END LOOP;
END pr_listar_departamentos;
/

-- Ejecutarlo (dos formas)
EXEC pr_listar_departamentos

BEGIN
  pr_listar_departamentos;
END;
/

-- Caso 6.2: Procedimiento con parámetros IN y validación: aumentar el salario de un empleado
CREATE OR REPLACE PROCEDURE pr_aumentar_salario (
  p_id          IN pr_empleados.employee_id%TYPE,
  p_porcentaje  IN NUMBER DEFAULT 10                 -- DEFAULT: si no se envía, vale 10
) IS
  v_actual pr_empleados.salary%TYPE;
BEGIN
  IF p_porcentaje <= 0 OR p_porcentaje > 50 THEN
    RAISE_APPLICATION_ERROR(-20010, 'El porcentaje debe estar entre 1 y 50');
  END IF;

  SELECT salary INTO v_actual FROM pr_empleados WHERE employee_id = p_id;

  UPDATE pr_empleados
  SET    salary = salary * (1 + p_porcentaje / 100)
  WHERE  employee_id = p_id;

  DBMS_OUTPUT.PUT_LINE('Empleado ' || p_id || ': ' || v_actual || ' -> ' || ROUND(v_actual * (1 + p_porcentaje / 100), 2));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20011, 'No existe el empleado ' || p_id);
END pr_aumentar_salario;
/

-- Ojo: no poner comentarios al final de una línea EXEC (EXEC le agrega "END;" al final y el comentario lo tapa).
-- Usa el 10 % por defecto:
EXEC pr_aumentar_salario(107)
EXEC pr_aumentar_salario(107, 5)
-- Notación con nombre (=>): el orden de los parámetros no importa:
EXEC pr_aumentar_salario(p_porcentaje => 20, p_id => 104)
-- Probar el error -20011 (empleado que no existe):
-- EXEC pr_aumentar_salario(9999)
ROLLBACK;

-- Caso 6.3: Parámetros OUT: el procedimiento "devuelve" varios valores
CREATE OR REPLACE PROCEDURE pr_datos_departamento (
  p_depto      IN  NUMBER,
  p_nombre     OUT VARCHAR2,                        -- OUT: el procedimiento lo llena
  p_empleados  OUT NUMBER,
  p_nomina     OUT NUMBER
) IS
BEGIN
  SELECT department_name INTO p_nombre FROM departments WHERE department_id = p_depto;
  SELECT COUNT(*), NVL(SUM(salary), 0)
  INTO   p_empleados, p_nomina
  FROM   employees WHERE department_id = p_depto;
END pr_datos_departamento;
/

DECLARE
  v_nombre    departments.department_name%TYPE;
  v_empleados NUMBER;
  v_nomina    NUMBER;
BEGIN
  pr_datos_departamento(80, v_nombre, v_empleados, v_nomina);   -- los OUT se reciben en variables
  DBMS_OUTPUT.PUT_LINE(v_nombre || ': ' || v_empleados || ' empleados, nómina $' || v_nomina);
END;
/

-- Caso 6.4: Parámetro IN OUT: entra un valor y sale modificado
CREATE OR REPLACE PROCEDURE pr_formatear_telefono (p_telefono IN OUT VARCHAR2) IS
BEGIN
  p_telefono := '(+1) ' || REPLACE(p_telefono, '.', '-');
END pr_formatear_telefono;
/

DECLARE
  v_tel employees.phone_number%TYPE;
BEGIN
  SELECT phone_number INTO v_tel FROM employees WHERE employee_id = 100;
  DBMS_OUTPUT.PUT_LINE('Antes:   ' || v_tel);
  pr_formatear_telefono(v_tel);
  DBMS_OUTPUT.PUT_LINE('Después: ' || v_tel);
END;
/

-- Caso 6.5: Procedimiento que inserta con validaciones y maneja sus excepciones
CREATE OR REPLACE PROCEDURE pr_contratar (
  p_nombre    IN VARCHAR2,
  p_apellido  IN VARCHAR2,
  p_email     IN VARCHAR2,
  p_job       IN VARCHAR2,
  p_salario   IN NUMBER,
  p_depto     IN NUMBER,
  p_id_nuevo  OUT NUMBER
) IS
  v_min jobs.min_salary%TYPE;
  v_max jobs.max_salary%TYPE;
BEGIN
  SELECT min_salary, max_salary INTO v_min, v_max FROM jobs WHERE job_id = p_job;

  IF p_salario NOT BETWEEN v_min AND v_max THEN
    RAISE_APPLICATION_ERROR(-20020, 'El salario debe estar entre ' || v_min || ' y ' || v_max);
  END IF;

  SELECT NVL(MAX(employee_id), 0) + 1 INTO p_id_nuevo FROM pr_empleados;

  INSERT INTO pr_empleados (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id)
  VALUES (p_id_nuevo, p_nombre, p_apellido, UPPER(p_email), SYSDATE, p_job, p_salario, p_depto);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20021, 'El cargo ' || p_job || ' no existe');
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20022, 'El correo ' || p_email || ' ya está registrado');
END pr_contratar;
/

DECLARE
  v_id NUMBER;
BEGIN
  pr_contratar('Ana', 'Pérez', 'aperez', 'IT_PROG', 6000, 60, v_id);
  DBMS_OUTPUT.PUT_LINE('Contratada con id ' || v_id);
  -- pr_contratar('Luis', 'Gómez', 'lgomez', 'IT_PROG', 99000, 60, v_id);   -- probar el error de salario
  -- pr_contratar('Eva', 'Ruiz', 'aperez', 'IT_PROG', 6000, 60, v_id);      -- probar el correo repetido
END;
/
ROLLBACK;


/* =====================================================================
   TEMA 7. FUNCIONES
   Como un procedimiento, pero SIEMPRE devuelve un valor con RETURN.
   Se pueden usar dentro de un SELECT.
   ===================================================================== */

-- Caso 7.1: Función que calcula los años de antigüedad
CREATE OR REPLACE FUNCTION fn_antiguedad (p_id IN NUMBER) RETURN NUMBER IS
  v_fecha employees.hire_date%TYPE;
BEGIN
  SELECT hire_date INTO v_fecha FROM employees WHERE employee_id = p_id;
  RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha) / 12);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;                                    -- una función siempre debe terminar en un RETURN
END fn_antiguedad;
/

-- Usarla en un SELECT y en un bloque
SELECT employee_id, last_name, fn_antiguedad(employee_id) AS anios
FROM   employees
ORDER  BY anios DESC
FETCH  FIRST 5 ROWS ONLY;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Antigüedad de King: ' || fn_antiguedad(100) || ' años');
END;
/

-- Caso 7.2: Función que devuelve texto: nombre completo con el cargo
CREATE OR REPLACE FUNCTION fn_nombre_completo (p_id IN NUMBER) RETURN VARCHAR2 IS
  v_resultado VARCHAR2(200);
BEGIN
  SELECT e.first_name || ' ' || e.last_name || ' (' || j.job_title || ')'
  INTO   v_resultado
  FROM   employees e JOIN jobs j ON j.job_id = e.job_id
  WHERE  e.employee_id = p_id;
  RETURN v_resultado;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'Empleado no encontrado';
END fn_nombre_completo;
/

SELECT fn_nombre_completo(206) FROM dual;
SELECT fn_nombre_completo(9999) FROM dual;

-- Caso 7.3: Función con cálculo puro (DETERMINISTIC: mismos datos de entrada -> mismo resultado)
CREATE OR REPLACE FUNCTION fn_salario_anual (
  p_salario   IN NUMBER,
  p_comision  IN NUMBER DEFAULT 0
) RETURN NUMBER DETERMINISTIC IS                   -- le permite a Oracle reutilizar resultados
BEGIN
  RETURN p_salario * 12 * (1 + NVL(p_comision, 0));
END fn_salario_anual;
/

SELECT last_name, salary, commission_pct, fn_salario_anual(salary, commission_pct) AS anual
FROM   employees
WHERE  department_id = 80
ORDER  BY anual DESC;

-- Caso 7.4: Función que devuelve un BOOLEAN (solo se puede usar en PL/SQL, no en un SELECT)
CREATE OR REPLACE FUNCTION fn_es_jefe (p_id IN NUMBER) RETURN BOOLEAN IS
  v_cuantos NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cuantos FROM employees WHERE manager_id = p_id;
  RETURN v_cuantos > 0;
END fn_es_jefe;
/

BEGIN
  FOR r IN (SELECT employee_id, last_name FROM employees WHERE department_id = 50 AND ROWNUM <= 8) LOOP
    IF fn_es_jefe(r.employee_id) THEN
      DBMS_OUTPUT.PUT_LINE(r.last_name || ' es jefe');
    ELSE
      DBMS_OUTPUT.PUT_LINE(r.last_name || ' no tiene personas a cargo');
    END IF;
  END LOOP;
END;
/


/* =====================================================================
   TEMA 8. TRIGGERS
   Bloques que se ejecutan SOLOS cuando ocurre un evento sobre una tabla.
   Se crean sobre PR_EMPLEADOS para no tocar los triggers que ya tiene HR.
   ===================================================================== */

-- Caso 8.1: Trigger BEFORE de fila: validar el salario contra el rango del cargo antes de guardar
CREATE OR REPLACE TRIGGER tg_pr_validar_salario
BEFORE INSERT OR UPDATE OF salary, job_id ON pr_empleados
FOR EACH ROW                                        -- se ejecuta una vez por cada fila afectada
DECLARE
  v_min jobs.min_salary%TYPE;
  v_max jobs.max_salary%TYPE;
BEGIN
  SELECT min_salary, max_salary INTO v_min, v_max FROM jobs WHERE job_id = :NEW.job_id;   -- :NEW = la fila nueva
  IF :NEW.salary NOT BETWEEN v_min AND v_max THEN
    RAISE_APPLICATION_ERROR(-20100,
      'Salario ' || :NEW.salary || ' fuera del rango de ' || :NEW.job_id || ' (' || v_min || ' - ' || v_max || ')');
  END IF;
END;
/

-- Probarlo
UPDATE pr_empleados SET salary = 9000 WHERE employee_id = 107;      -- IT_PROG: 4000-10000 -> funciona
-- UPDATE pr_empleados SET salary = 50000 WHERE employee_id = 107;  -- falla con ORA-20100
ROLLBACK;

-- Caso 8.2: Trigger BEFORE que COMPLETA datos: poner en mayúscula el correo y la fecha si viene vacía
CREATE OR REPLACE TRIGGER tg_pr_completar_datos
BEFORE INSERT OR UPDATE ON pr_empleados
FOR EACH ROW
BEGIN
  :NEW.email := UPPER(:NEW.email);                  -- en un BEFORE se puede cambiar :NEW antes de guardar
  IF INSERTING AND :NEW.hire_date IS NULL THEN      -- INSERTING: TRUE si el evento es un INSERT
    :NEW.hire_date := SYSDATE;
  END IF;
END;
/

-- Caso 8.3: Trigger AFTER de fila para AUDITORÍA: registra quién cambió qué
CREATE OR REPLACE TRIGGER tg_pr_auditoria
AFTER INSERT OR UPDATE OR DELETE ON pr_empleados
FOR EACH ROW
DECLARE
  v_operacion VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_operacion := 'INSERT';
  ELSIF UPDATING THEN
    v_operacion := 'UPDATE';
  ELSE
    v_operacion := 'DELETE';
  END IF;

  INSERT INTO pr_auditoria (tabla, operacion, employee_id, salario_antes, salario_nuevo)
  VALUES ('PR_EMPLEADOS', v_operacion,
          NVL(:NEW.employee_id, :OLD.employee_id),  -- en un DELETE :NEW está vacío; en un INSERT, :OLD
          :OLD.salary,                              -- :OLD = la fila como estaba antes
          :NEW.salary);
END;
/

-- Probarlo: insertar, actualizar y borrar, y ver la auditoría
INSERT INTO pr_empleados (employee_id, last_name, email, job_id, salary)
VALUES (500, 'Auditada', 'auditada', 'IT_PROG', 5000);     -- el correo queda en mayúscula y la fecha se llena sola
UPDATE pr_empleados SET salary = 5500 WHERE employee_id = 500;
DELETE FROM pr_empleados WHERE employee_id = 500;
COMMIT;

SELECT * FROM pr_auditoria ORDER BY id_auditoria;

-- Caso 8.4: Trigger con WHEN: solo se dispara si el salario BAJA (la condición se evalúa antes de ejecutar)
CREATE OR REPLACE TRIGGER tg_pr_alerta_baja
AFTER UPDATE OF salary ON pr_empleados
FOR EACH ROW
WHEN (NEW.salary < OLD.salary)                      -- en el WHEN van sin los dos puntos
BEGIN
  DBMS_OUTPUT.PUT_LINE('ALERTA: a ' || :OLD.last_name || ' le bajaron el salario de '
                       || :OLD.salary || ' a ' || :NEW.salary);
END;
/

UPDATE pr_empleados SET salary = salary - 100 WHERE employee_id = 104;   -- dispara la alerta
UPDATE pr_empleados SET salary = salary + 100 WHERE employee_id = 104;   -- no la dispara
ROLLBACK;

-- Caso 8.5: Trigger de SENTENCIA (sin FOR EACH ROW): se ejecuta UNA vez aunque cambien muchas filas
CREATE OR REPLACE TRIGGER tg_pr_horario
BEFORE INSERT OR UPDATE OR DELETE ON pr_empleados
BEGIN
  IF TO_CHAR(SYSDATE, 'HH24') NOT BETWEEN '06' AND '22' THEN
    RAISE_APPLICATION_ERROR(-20200, 'Solo se pueden hacer cambios entre las 6:00 y las 22:59');
  END IF;
END;
/

-- Caso 8.6: Activar y desactivar un trigger
ALTER TABLE pr_empleados DISABLE ALL TRIGGERS;     -- todos los de la tabla a la vez
ALTER TABLE pr_empleados ENABLE ALL TRIGGERS;
ALTER TRIGGER tg_pr_horario DISABLE;               -- deja de dispararse, pero sigue existiendo
-- Se deja DESACTIVADO para que el resto de la práctica funcione a cualquier hora.
-- Para probarlo: ALTER TRIGGER tg_pr_horario ENABLE; y hacer un UPDATE fuera del horario.

-- Caso 8.7: Error de TABLA MUTANTE: un trigger de FILA no puede consultar la misma tabla que lo disparó
CREATE OR REPLACE TRIGGER tg_pr_mutante
BEFORE UPDATE OF salary ON pr_empleados
FOR EACH ROW
DECLARE
  v_promedio NUMBER;
BEGIN
  SELECT AVG(salary) INTO v_promedio FROM pr_empleados;    -- consulta la misma tabla -> ORA-04091
END;
/

-- UPDATE pr_empleados SET salary = salary + 1 WHERE employee_id = 104;   -- falla con ORA-04091 (tabla mutante)
DROP TRIGGER tg_pr_mutante;                        -- se borra para que no afecte lo demás

-- Caso 8.8: Consultar los triggers de la tabla
SELECT trigger_name, trigger_type, triggering_event, status
FROM   user_triggers
WHERE  table_name = 'PR_EMPLEADOS';


/* =====================================================================
   TEMA 9. PAQUETES
   Agrupan procedimientos, funciones, variables y excepciones de un mismo tema.
   Tienen dos partes: ESPECIFICACIÓN (lo público) y CUERPO (el código).
   ===================================================================== */

-- Caso 9.1: Especificación del paquete (lo que se puede usar desde afuera)
CREATE OR REPLACE PACKAGE pkg_nomina IS
  -- Constantes y variables públicas
  c_aumento_maximo CONSTANT NUMBER := 30;
  g_operaciones    NUMBER := 0;                     -- variable global: dura toda la sesión

  -- Excepción pública
  e_porcentaje_invalido EXCEPTION;

  -- Funciones y procedimientos públicos
  FUNCTION nomina_departamento (p_depto IN NUMBER) RETURN NUMBER;
  PROCEDURE aumentar (p_id IN NUMBER, p_porcentaje IN NUMBER);
  PROCEDURE aumentar (p_depto IN NUMBER, p_porcentaje IN NUMBER, p_por_depto IN BOOLEAN);   -- SOBRECARGA: mismo nombre, otros parámetros
  PROCEDURE reporte (p_depto IN NUMBER);
END pkg_nomina;
/

-- Caso 9.2: Cuerpo del paquete (el código; lo que no está en la especificación es PRIVADO)
CREATE OR REPLACE PACKAGE BODY pkg_nomina IS

  -- Procedimiento PRIVADO: solo se puede usar dentro del paquete
  PROCEDURE validar_porcentaje (p_porcentaje IN NUMBER) IS
  BEGIN
    IF p_porcentaje <= 0 OR p_porcentaje > c_aumento_maximo THEN
      RAISE e_porcentaje_invalido;
    END IF;
  END validar_porcentaje;

  FUNCTION nomina_departamento (p_depto IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT NVL(SUM(salary), 0) INTO v_total FROM pr_empleados WHERE department_id = p_depto;
    RETURN v_total;
  END nomina_departamento;

  PROCEDURE aumentar (p_id IN NUMBER, p_porcentaje IN NUMBER) IS
  BEGIN
    validar_porcentaje(p_porcentaje);
    UPDATE pr_empleados SET salary = ROUND(salary * (1 + p_porcentaje / 100), 2)
    WHERE  employee_id = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20300, 'No existe el empleado ' || p_id);
    END IF;
    g_operaciones := g_operaciones + 1;
  END aumentar;

  PROCEDURE aumentar (p_depto IN NUMBER, p_porcentaje IN NUMBER, p_por_depto IN BOOLEAN) IS
  BEGIN
    validar_porcentaje(p_porcentaje);
    IF p_por_depto THEN
      UPDATE pr_empleados SET salary = ROUND(salary * (1 + p_porcentaje / 100), 2)
      WHERE  department_id = p_depto;
      DBMS_OUTPUT.PUT_LINE('Aumento aplicado a ' || SQL%ROWCOUNT || ' empleados del departamento ' || p_depto);
      g_operaciones := g_operaciones + 1;
    END IF;
  END aumentar;

  PROCEDURE reporte (p_depto IN NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Departamento ' || p_depto || ' ---');
    FOR r IN (SELECT last_name, salary FROM pr_empleados WHERE department_id = p_depto ORDER BY salary DESC) LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(r.last_name, 15) || TO_CHAR(r.salary, '99,999.00'));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Nómina total: ' || nomina_departamento(p_depto));
    DBMS_OUTPUT.PUT_LINE('Operaciones de aumento en esta sesión: ' || g_operaciones);
  END reporte;

END pkg_nomina;
/

-- Caso 9.3: Usar el paquete: paquete.elemento
BEGIN
  pkg_nomina.reporte(60);
  pkg_nomina.aumentar(103, 5);                      -- versión por empleado
  pkg_nomina.aumentar(60, 5, TRUE);                 -- versión por departamento (sobrecarga)
  pkg_nomina.reporte(60);
END;
/

SELECT pkg_nomina.nomina_departamento(60) FROM dual;   -- las funciones públicas también sirven en SQL
ROLLBACK;

-- Caso 9.4: Atrapar la excepción pública del paquete desde afuera
BEGIN
  pkg_nomina.aumentar(103, 80);                     -- 80 % supera el máximo de 30
EXCEPTION
  WHEN pkg_nomina.e_porcentaje_invalido THEN
    DBMS_OUTPUT.PUT_LINE('Porcentaje inválido: máximo ' || pkg_nomina.c_aumento_maximo || ' %');
END;
/

-- Caso 9.5: Intentar usar el procedimiento PRIVADO -> error PLS-00302 (no existe para quien está afuera)
-- BEGIN pkg_nomina.validar_porcentaje(10); END;
-- /


/* =====================================================================
   TEMA 10. SQL DINÁMICO
   La sentencia se arma como texto y se ejecuta con EXECUTE IMMEDIATE.
   ===================================================================== */

-- Caso 10.1: Contar filas de una tabla cuyo nombre se decide al ejecutar
DECLARE
  v_tabla   VARCHAR2(30) := 'EMPLOYEES';            -- cambiar por DEPARTMENTS, JOBS...
  v_total   NUMBER;
BEGIN
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_tabla INTO v_total;
  DBMS_OUTPUT.PUT_LINE(v_tabla || ' tiene ' || v_total || ' filas');
END;
/

-- Caso 10.2: SQL dinámico con variables de enlace (:valor), la forma segura de pasar datos
DECLARE
  v_depto  NUMBER := 90;
  v_total  NUMBER;
BEGIN
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM employees WHERE department_id = :d'
    INTO v_total
    USING v_depto;                                  -- USING llena :d (evita inyección SQL)
  DBMS_OUTPUT.PUT_LINE('Departamento ' || v_depto || ': ' || v_total || ' empleados');
END;
/


/* =====================================================================
   TEMA 11. CONSULTAR LOS OBJETOS CREADOS
   ===================================================================== */

-- Caso 11.1: Listar los objetos PL/SQL y su estado (VALID / INVALID)
SELECT object_name, object_type, status, last_ddl_time
FROM   user_objects
WHERE  object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER')
ORDER  BY object_type, object_name;

-- Caso 11.2: Ver el código fuente guardado de un objeto
SELECT line, text
FROM   user_source
WHERE  name = 'FN_ANTIGUEDAD'
ORDER  BY line;

-- Caso 11.3: Ver los errores de compilación (si un CREATE dice "compilado con errores")
SELECT name, type, line, position, text FROM user_errors;
-- SHOW ERRORS                                       -- muestra los errores del último objeto compilado

-- Caso 11.4: Ver los parámetros de un procedimiento o función
SELECT object_name, argument_name, data_type, in_out, position
FROM   user_arguments
WHERE  object_name = 'PR_CONTRATAR'
ORDER  BY position;


/* =====================================================================
   TEMA 12. LIMPIEZA (borrar todo lo creado en esta práctica)
   ===================================================================== */

DROP PACKAGE pkg_nomina;                            -- borra especificación y cuerpo
DROP FUNCTION fn_antiguedad;
DROP FUNCTION fn_nombre_completo;
DROP FUNCTION fn_salario_anual;
DROP FUNCTION fn_es_jefe;
DROP PROCEDURE pr_listar_departamentos;
DROP PROCEDURE pr_aumentar_salario;
DROP PROCEDURE pr_datos_departamento;
DROP PROCEDURE pr_formatear_telefono;
DROP PROCEDURE pr_contratar;
DROP TABLE pr_empleados PURGE;                      -- borra también sus triggers
DROP TABLE pr_auditoria PURGE;
DROP TABLE pr_errores PURGE;

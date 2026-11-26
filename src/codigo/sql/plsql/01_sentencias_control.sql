/*
AUTOR: Juan Felipe Lozada Jara
FECHA: 14/10/2026
DESCRIPCIÓN: Practica de PL/SQL - Sentencias de control. En cada practica se cambió
el nombre de las variables para coincidir con la notación vista en clase.
*/

--------------------------------------------------------------------------------
-- UNIVERSIDAD EL BOSQUE - INGENIERIA DE SISTEMAS
-- Bases de Datos - Modulo 1 de 4: SENTENCIAS DE CONTROL EN PL/SQL
-- Oracle Database 19c
-- Docente: Ing. Christian Felipe Duarte
--------------------------------------------------------------------------------
-- COMO USAR ESTE ARCHIVO
--
--   1. Este script es independiente: crea sus propias tablas (prefijo CTRL_) y
--      al final las elimina. No necesita los scripts de los otros modulos.
--   2. NO lo ejecute completo de una sola vez. Avance PASO por PASO.
--      En SQL Developer: seleccione el bloque del paso y presione Ctrl+Enter.
--   3. Cada paso tiene tres comentarios que usted debe leer ANTES de ejecutar:
--         QUE VAMOS A HACER  -> el objetivo del paso
--         QUE DEBE OBSERVAR  -> donde poner la atencion
--         RESULTADO ESPERADO -> con que debe comparar su salida
--   4. Los pasos marcados [ERROR PROVOCADO] DEBEN fallar. Lea el codigo ORA o
--      PLS antes de continuar: el objetivo es que reconozca el mensaje.
--   5. Requisitos: un usuario con CREATE TABLE y CREATE PROCEDURE en su
--      propio esquema.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ============================================================
PROMPT  MODULO 1 - SENTENCIAS DE CONTROL
PROMPT ============================================================


--------------------------------------------------------------------------------
-- PASO 0 - PREPARACION DEL ESQUEMA DE PRACTICA
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : crear dos tablas de trabajo y cargarlas con datos.
-- QUE DEBE OBSERVAR : el bloque borra las tablas si ya existian; si es la
--                     primera vez, ignora el error ORA-00942 en silencio.
-- RESULTADO ESPERADO: mensaje "Esquema de practica listo" y 8 estudiantes.
--------------------------------------------------------------------------------
BEGIN
  FOR r IN (SELECT table_name FROM user_tables
             WHERE table_name IN ('CTRL_NOTA','CTRL_ESTUDIANTE')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

CREATE TABLE ctrl_estudiante (
  id_estudiante NUMBER(5)      CONSTRAINT pk_ctrl_est PRIMARY KEY,
  nombre        VARCHAR2(40)   NOT NULL,
  jornada       CHAR(1),                       -- D = diurna, N = nocturna, NULL = sin definir
  semestre      NUMBER(2)
);

CREATE TABLE ctrl_nota (
  id_estudiante NUMBER(5) CONSTRAINT fk_ctrl_nota REFERENCES ctrl_estudiante,
  corte1        NUMBER(3,2),
  corte2        NUMBER(3,2),
  corte3        NUMBER(3,2),
  definitiva    NUMBER(3,2)
);

INSERT INTO ctrl_estudiante VALUES (1,'Ana Maria Torres','D',3);
INSERT INTO ctrl_estudiante VALUES (2,'Bernardo Pineda','N',5);
INSERT INTO ctrl_estudiante VALUES (3,'Carolina Reyes','D',3);
INSERT INTO ctrl_estudiante VALUES (4,'Daniel Ospina',NULL,7);
INSERT INTO ctrl_estudiante VALUES (5,'Elena Marquez','N',5);
INSERT INTO ctrl_estudiante VALUES (6,'Felipe Cardenas','D',1);
INSERT INTO ctrl_estudiante VALUES (7,'Gabriela Nino','N',7);
INSERT INTO ctrl_estudiante VALUES (8,'Hector Valbuena','D',1);

INSERT INTO ctrl_nota VALUES (1, 4.2, 3.8, 4.5, NULL);
INSERT INTO ctrl_nota VALUES (2, 2.5, 3.1, 2.9, NULL);
INSERT INTO ctrl_nota VALUES (3, 3.0, 3.0, 3.0, NULL);
INSERT INTO ctrl_nota VALUES (4, 4.8, 4.9, 5.0, NULL);
INSERT INTO ctrl_nota VALUES (5, 1.8, 2.2, 2.0, NULL);
INSERT INTO ctrl_nota VALUES (6, 3.5, NULL, 3.9, NULL);   -- corte2 sin registrar
INSERT INTO ctrl_nota VALUES (7, 4.0, 4.0, 3.5, NULL);
INSERT INTO ctrl_nota VALUES (8, 2.9, 3.4, 3.1, NULL);
COMMIT;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Esquema de practica listo.');
END;
/

SELECT e.id_estudiante, e.nombre, e.jornada, n.corte1, n.corte2, n.corte3
  FROM ctrl_estudiante e JOIN ctrl_nota n ON n.id_estudiante = e.id_estudiante
 ORDER BY e.id_estudiante;



--------------------------------------------------------------------------------
-- PASO 1 - EL BLOQUE MINIMO Y LA SALIDA POR PANTALLA
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : ejecutar el bloque PL/SQL mas pequeno posible.
-- QUE DEBE OBSERVAR : si no ve ninguna linea, falto SET SERVEROUTPUT ON.
--                     El bloque no falla: simplemente usted no ve la salida.
-- RESULTADO ESPERADO: dos lineas en pantalla.
--------------------------------------------------------------------------------
DECLARE
    vvMensaje VARCHAR2(60) := 'El bloque se ejecuto correctamente';
BEGIN
    DBMS_OUTPUT.PUT_LINE(vvMensaje);
    DBMS_OUTPUT.PUT_LINE('Usuario conectado: ' || USER);
END;
/

--------------------------------------------------------------------------------
-- PASO 2 - IF EN SUS TRES FORMAS
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : clasificar una nota con IF THEN, IF THEN ELSE e
--                     IF THEN ELSIF.
-- QUE DEBE OBSERVAR : el ELSIF se escribe SIN E intermedia, y la cascada se
--                     detiene en la PRIMERA condicion verdadera.
-- RESULTADO ESPERADO: Nota 4.2 -> APROBADO / nivel ALTO.
--------------------------------------------------------------------------------
DECLARE
  vnNota   NUMBER(3,2) := 3.0;
  vvEstado VARCHAR2(12);
  vvNivel  VARCHAR2(10);
BEGIN
  -- forma 1: una sola rama
  IF vnNota >= 3 THEN
    DBMS_OUTPUT.PUT_LINE('Forma 1: la nota alcanza para aprobar');
  END IF;

  -- forma 2: dos caminos excluyentes
  IF vnNota >= 3 THEN
    vvEstado := 'APROBADO';
  ELSE
    vvEstado := 'REPROBADO';
  END IF;

  -- forma 3: cascada evaluada en orden
  IF    vnNota >= 4 THEN vvNivel := 'ALTO';
  ELSIF vnNota >= 3 THEN vvNivel := 'MEDIO';
  ELSE                   vvNivel := 'BAJO';
  END IF;

  DBMS_OUTPUT.PUT_LINE('Forma 2: estado = ' || vvEstado);
  DBMS_OUTPUT.PUT_LINE('Forma 3: nivel  = ' || vvNivel);
END;
/
-- COMPRUEBE USTED MISMO: cambie v_nota a 3.0 y vuelva a ejecutar. Explique por
-- que el nivel resultante es MEDIO y no ALTO.
-- Básicamente, porque en la sentencia ELSIF se indica que si es 3 o mas, se coloque MEDIO en vez de ALTO.

--------------------------------------------------------------------------------
-- PASO 3 - LA CONDICION ES DE TRES VALORES: TRUE, FALSE Y NULL
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : evaluar una variable nula con = y con IS NULL.
-- QUE DEBE OBSERVAR : la comparacion con = NULL nunca es verdadera, asi que
--                     la rama THEN no se ejecuta y tampoco hay error.
-- RESULTADO ESPERADO: solo la segunda y la tercera prueba imprimen mensaje.
--------------------------------------------------------------------------------
DECLARE
  vcJornada CHAR(1) := NULL;
BEGIN
  IF vcJornada = NULL THEN
    DBMS_OUTPUT.PUT_LINE('Prueba 1: entro con = NULL   <- esto NUNCA aparece');
    -- No se puede comparar con un "=" un NULL
  END IF;

  IF vcJornada IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('Prueba 2: entro con IS NULL  <- forma correcta');
    -- Si se puede comparar con "IS" o "IS NOT" y NULL
  END IF;

  IF NVL(vcJornada,'X') = 'X' THEN
    DBMS_OUTPUT.PUT_LINE('Prueba 3: entro normalizando con NVL');
    -- NVL(valor_comprobar, valor_asignado) sirve para que si "valor_comprobar"
    -- es NULL, se "devuelva" "valor_asignado"
  END IF;

  -- el mismo efecto, aplicado a datos reales de la tabla
  FOR r IN (SELECT nombre FROM ctrl_estudiante WHERE jornada = NULL) LOOP
    DBMS_OUTPUT.PUT_LINE('Con = NULL: ' || r.nombre || '  <- no aparece ninguno');
    -- La misma idea: no se compara con "="
  END LOOP;

  FOR r IN (SELECT nombre FROM ctrl_estudiante WHERE jornada IS NULL) LOOP
    DBMS_OUTPUT.PUT_LINE('Con IS NULL: ' || r.nombre);
    -- Se usa "IS", está bien. Ya que devuelva o no algo es dependiendo de los datos 
  END LOOP;
END;
/


--------------------------------------------------------------------------------
-- PASO 4 - CASE SIMPLE Y CASE BUSCADO
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : traducir la jornada con CASE simple y clasificar la
--                     nota con CASE buscado.
-- QUE DEBE OBSERVAR : el CASE simple compara por igualdad, por eso el valor
--                     NULL de Daniel Ospina cae en la rama ELSE.
-- RESULTADO ESPERADO: ocho lineas, una por estudiante.
--------------------------------------------------------------------------------
DECLARE
  vvTexto_jornada VARCHAR2(15);
  vvNivel         VARCHAR2(10);
BEGIN
  FOR r IN (SELECT e.nombre, e.jornada, n.corte1
              FROM ctrl_estudiante e
              JOIN ctrl_nota n ON n.id_estudiante = e.id_estudiante
             ORDER BY e.id_estudiante) LOOP

    CASE r.jornada                                   -- CASE simple
      WHEN 'D' THEN vvTexto_jornada := 'Diurna';
      WHEN 'N' THEN vvTexto_jornada := 'Nocturna';
      ELSE          vvTexto_jornada := 'Sin definir';
    END CASE;
    
    -- Este case lo que hace es evaluar lo que está luego de CASE (r.jornada). Un selector por igualdad
    -- Este no sirve para comparar contra null

    CASE                                             -- CASE buscado
      WHEN r.corte1 IS NULL  THEN vvNivel := 'SIN NOTA';
      WHEN r.corte1 >= 4     THEN vvNivel := 'ALTO';
      WHEN r.corte1 >= 3     THEN vvNivel := 'MEDIO';
      ELSE                        vvNivel := 'BAJO';
    END CASE;
    -- Este case evalua linea por linea algo (r.corte1). Evalua condiciones independientes

    DBMS_OUTPUT.PUT_LINE(RPAD(r.nombre,20) || RPAD(vvTexto_jornada,14) || vvNivel);
    -- RPAD(algo, longitud, con_que): lo que hace es agregar tantas veces sea necesario
    -- de "con_que" para llegar a "longitud", luego de "algo". Digamos, si pongo
    -- RPAD('Juan', 6, 'X') el resultado sería 'JuanXX'
  END LOOP;
END;
/


--------------------------------------------------------------------------------
-- PASO 5 - SENTENCIA CASE Y EXPRESION CASE
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : escribir la misma clasificacion como sentencia y como
--                     expresion.
-- QUE DEBE OBSERVAR : la sentencia cierra con END CASE; la expresion cierra
--                     con END y se asigna a una variable.
-- RESULTADO ESPERADO: las dos lineas dicen exactamente lo mismo.
--------------------------------------------------------------------------------
DECLARE
  vnNota NUMBER(3,2) := 2.8;
  vvA    VARCHAR2(12);
  vvB    VARCHAR2(12);
BEGIN
  CASE                                    -- SENTENCIA
    WHEN vnNota >= 3 THEN vvA := 'APROBADO';
    ELSE                  vvA := 'REPROBADO';
  END CASE;
  -- En esta cada WHEN ejectua algo (asignar un valor a una variable)

  vvB := CASE                             -- EXPRESION
           WHEN vnNota >= 3 THEN 'APROBADO'
           ELSE                  'REPROBADO'
         END;
         -- En esta cada WHEN devuelve algo
         
  -- En palabras simples:
  -- Sentencia CASE: Si algo, entonces esto es igual a esto
  -- Expresion CASE: Si algo, entonces devuelva esto

  DBMS_OUTPUT.PUT_LINE('Sentencia: ' || vvA);
  DBMS_OUTPUT.PUT_LINE('Expresion: ' || vvB);
END;
/


--------------------------------------------------------------------------------
-- PASO 6 - [ERROR PROVOCADO] SENTENCIA CASE SIN ELSE
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : quitar la rama ELSE y pasarle un valor no contemplado.
-- QUE DEBE OBSERVAR : el bloque COMPILA y falla en EJECUCION.
-- RESULTADO ESPERADO: ORA-06592: CASE no encontrado al ejecutar la sentencia
--                     CASE. La excepcion predefinida se llama CASE_NOT_FOUND.
--------------------------------------------------------------------------------
DECLARE
  vcJornada CHAR(1) := 'X';     -- valor que ningun WHEN contempla
  vvTexto   VARCHAR2(15);
BEGIN
  CASE vcJornada
    WHEN 'D' THEN vvTexto := 'Diurna';
    WHEN 'N' THEN vvTexto := 'Nocturna';
  END CASE;                     -- sin ELSE
  -- Si no se usa el ELSE devuelve el error ORA-06592
  DBMS_OUTPUT.PUT_LINE(vvTexto);
END;
/

-- CORRECCION: la misma logica, atrapando la excepcion por su nombre.
DECLARE
  vcJornada CHAR(1) := 'X';
  vvTexto   VARCHAR2(15);
BEGIN
  CASE vcJornada
    WHEN 'D' THEN vvTexto := 'Diurna';
    WHEN 'N' THEN vvTexto := 'Nocturna';
  END CASE;
  -- Acá tampoco se usa el ELSE, sin embargo, se maneja la excepción al final.
  DBMS_OUTPUT.PUT_LINE(vvTexto);
EXCEPTION
  WHEN CASE_NOT_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Jornada no contemplada: ' || vcJornada ||
                         ' (SQLCODE = ' || SQLCODE || ')');
END;
/


--------------------------------------------------------------------------------
-- PASO 7 - LOOP BASICO, EXIT WHEN Y ETIQUETAS
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : recorrer un contador con el LOOP basico.
-- QUE DEBE OBSERVAR : la salida es responsabilidad suya. Si comenta la linea
--                     del EXIT, la sesion queda girando sin fin.
-- RESULTADO ESPERADO: cinco iteraciones y un mensaje de cierre.
--------------------------------------------------------------------------------
DECLARE
  vpI PLS_INTEGER := 1;
BEGIN
  <<principal>> -- Esto viene siendo el nombre del LOOP, la etiqueta
  LOOP
    DBMS_OUTPUT.PUT_LINE('Iteracion ' || vpI);
    vpI := vpI + 1;
    EXIT principal WHEN vpI > 5;
  END LOOP principal;

  DBMS_OUTPUT.PUT_LINE('El bucle basico siempre ejecuta al menos una vuelta.');
END;
/


--------------------------------------------------------------------------------
-- PASO 8 - WHILE: LA CONDICION SE EVALUA ANTES DE ENTRAR
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : simular el pago de un saldo en cuotas y luego repetir
--                     el ejercicio con la variable de control en NULL.
-- QUE DEBE OBSERVAR : en el segundo caso el cuerpo NO se ejecuta ninguna vez
--                     y no hay ningun error que lo advierta.
-- RESULTADO ESPERADO: 4 cuotas en el primer caso, 0 en el segundo.
--------------------------------------------------------------------------------
DECLARE
  vnSaldo  NUMBER := 1000;
  vpCuotas PLS_INTEGER := 0;
BEGIN
  WHILE vnSaldo > 0 LOOP
    vnSaldo  := vnSaldo - 250;
    vpCuotas := vpCuotas + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Caso 1 - cuotas necesarias: ' || vpCuotas);
  -- El valor del saldo se evalua antes de hacer cualquier cosa

  vnSaldo  := NULL;                 -- ahora la variable llega sin valor
  vpCuotas := 0;
  WHILE vnSaldo > 0 LOOP
    vpCuotas := vpCuotas + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Caso 2 - cuotas contadas : ' || vpCuotas ||
                       '  <- el bucle no entro ni una vez');
  -- Como NULL no es mayor, igual o menor a 0 (NULL no se compara con signos sino con "IS"), no entra al ciclo
END;
/


--------------------------------------------------------------------------------
-- PASO 9 - FOR NUMERICO, REVERSE Y LAS REGLAS DEL INDICE
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : recorrer un rango hacia adelante y hacia atras, y
--                     comprobar que un rango invertido no ejecuta el cuerpo.
-- QUE DEBE OBSERVAR : en REVERSE los limites se escriben igual, de menor a
--                     mayor; lo que cambia es el recorrido.
-- RESULTADO ESPERADO: 1 2 3, luego 3 2 1, y ninguna vuelta en el tercer bucle.
--------------------------------------------------------------------------------
DECLARE
  vpVueltas PLS_INTEGER := 0;
BEGIN
  FOR i IN 1..3 LOOP
    DBMS_OUTPUT.PUT_LINE('Ascendente: ' || i);
    -- Entra 3 veces: [1, 3] (Incluye los limites)
  END LOOP;

  FOR i IN REVERSE 1..3 LOOP
    DBMS_OUTPUT.PUT_LINE('Descendente: ' || i);
  END LOOP;
  -- Entra 3 veces, pero al reves: [3, 1] (Incluye los limites)

  FOR i IN 5..1 LOOP                 -- limite inferior mayor que el superior
    vpVueltas := vpVueltas + 1;
  END LOOP;
  -- Esto está mal. Debería ser simplemente FOR i IN REVERSE 1..5 LOOP
  DBMS_OUTPUT.PUT_LINE('Vueltas del rango invertido: ' || vpVueltas);
END;
/


--------------------------------------------------------------------------------
-- PASO 10 - [ERROR PROVOCADO] ASIGNAR VALOR AL INDICE DEL FOR
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : intentar modificar el indice dentro del bucle.
-- QUE DEBE OBSERVAR : este error es de COMPILACION, no de ejecucion: el
--                     bloque nunca llega a correr.
-- RESULTADO ESPERADO: PLS-00363: la expresion 'I' no se puede utilizar como
--                     destino de una asignacion.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN 1..3 LOOP
    i := i + 1;
    -- Esto no se puede hacer y arroja el error PLS-00363. 
  END LOOP;
END;
/

-- CORRECCION: use una variable propia si necesita controlar el avance.
DECLARE
  vpI PLS_INTEGER := 1;
BEGIN
  WHILE vpI <= 6 LOOP
    DBMS_OUTPUT.PUT_LINE('Avance de dos en dos: ' || vpI);
    vpI := vpI + 2;
    -- Además de usar una variable propia, se cambió el tipo de ciclo
  END LOOP;
END;
/


--------------------------------------------------------------------------------
-- PASO 11 - FOR SOBRE CURSOR: EL BUCLE QUE MAS SE USA
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : recorrer el resultado de una consulta sin declarar,
--                     abrir ni cerrar el cursor.
-- QUE DEBE OBSERVAR : el registro r toma automaticamente la estructura de la
--                     consulta; sus campos se leen con r.nombre_de_columna.
-- RESULTADO ESPERADO: los estudiantes ordenados por corte1 descendente.
--------------------------------------------------------------------------------
BEGIN
  FOR r IN (SELECT e.nombre, n.corte1
              FROM ctrl_estudiante e
              JOIN ctrl_nota n ON n.id_estudiante = e.id_estudiante
             WHERE n.corte1 IS NOT NULL
             ORDER BY n.corte1 DESC) LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.nombre,20) || TO_CHAR(r.corte1,'90.00'));
    -- En este caso el '90.00' es para decir que el número debe tener ese formato: 9 para espacio en blanco, 0 para rellenar con 0
    -- 0.45 pasa a ser ' 0.45', mientras que 23.4 para a ser '23.40'
  END LOOP;
END;
/


--------------------------------------------------------------------------------
-- PASO 12 - CONTINUE, EXIT Y BUCLES ANIDADOS CON ETIQUETA
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : saltar iteraciones con CONTINUE WHEN y abandonar dos
--                     bucles a la vez con EXIT sobre la etiqueta externa.
-- QUE DEBE OBSERVAR : CONTINUE cierra la iteracion en curso; EXIT termina el
--                     bucle indicado por la etiqueta.
-- RESULTADO ESPERADO: solo combinaciones con i impar, y corte cuando i*j > 12.
--------------------------------------------------------------------------------
BEGIN
  <<externo>>
  FOR i IN 1..6 LOOP
    CONTINUE externo WHEN MOD(i,2) = 0;      -- omite los pares
    <<interno>>
    FOR j IN 1..3 LOOP
      EXIT externo WHEN i * j > 12;          -- sale de los DOS bucles
      DBMS_OUTPUT.PUT_LINE(i || ' x ' || j || ' = ' || i*j);
    END LOOP interno;
  END LOOP externo;
END;
/

/*
La respuesta es:
1 x 1 = 1
1 x 2 = 2
1 x 3 = 3
3 x 1 = 3
3 x 2 = 6
3 x 3 = 9
5 x 1 = 5
5 x 2 = 10
Se detiene ahí porque 5 x 3 = 15, y esto cumple la condición de i * j > 12, por lo cual se sale del bucle extetrno, que contiene a ambos
*/


--------------------------------------------------------------------------------
-- PASO 13 - FILA A FILA CONTRA PROCESAMIENTO MASIVO
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : calcular la definitiva de las dos formas y medir el
--                     tiempo de cada una con DBMS_UTILITY.GET_TIME.
-- QUE DEBE OBSERVAR : con 8 filas la diferencia es minima; el punto es el
--                     mecanismo. Repita el ejercicio despues de multiplicar
--                     los datos y la diferencia se vuelve evidente.
-- RESULTADO ESPERADO: dos tiempos en centesimas de segundo y el mismo
--                     resultado en la tabla.
--------------------------------------------------------------------------------
DECLARE
  TYPE t_ids  IS TABLE OF ctrl_nota.id_estudiante%TYPE;
  TYPE t_defs IS TABLE OF ctrl_nota.definitiva%TYPE;
  v_ids  t_ids;
  v_defs t_defs;
  v_t0   PLS_INTEGER;
  v_t1   PLS_INTEGER;
BEGIN
  -- forma 1: un UPDATE por cada fila
  v_t0 := DBMS_UTILITY.GET_TIME;
  FOR r IN (SELECT id_estudiante, corte1, corte2, corte3 FROM ctrl_nota) LOOP
    UPDATE ctrl_nota
       SET definitiva = ROUND(NVL(r.corte1,0)*0.3 + NVL(r.corte2,0)*0.3
                              + NVL(r.corte3,0)*0.4, 2)
     WHERE id_estudiante = r.id_estudiante;
  END LOOP;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('Fila a fila : ' || (v_t1 - v_t0) || ' centesimas');

  -- forma 2: traer todo a memoria y actualizar en un solo envio
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT id_estudiante,
         ROUND(NVL(corte1,0)*0.3 + NVL(corte2,0)*0.3 + NVL(corte3,0)*0.4, 2)
    BULK COLLECT INTO v_ids, v_defs
    FROM ctrl_nota;
    -- Básicamente reemplaza todo el bucle de arriba y lo hace de una sola vez

  FORALL k IN 1..v_ids.COUNT
    UPDATE ctrl_nota SET definitiva = v_defs(k) WHERE id_estudiante = v_ids(k);
    -- Esto no es un bucle, sino mas bien una instrucción como "Te mando todo esto, debes hacer esto por cada uno"
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('Masivo      : ' || (v_t1 - v_t0) || ' centesimas');
  COMMIT;
END;
/

SELECT id_estudiante, corte1, corte2, corte3, definitiva
  FROM ctrl_nota ORDER BY id_estudiante;

-- PARA PENSAR: la tercera opcion es un solo UPDATE en SQL puro, sin bucle y
-- sin coleccion. Escribalo usted y compare los tres tiempos.


--------------------------------------------------------------------------------
-- PASO 14 - GOTO Y LA SENTENCIA NULL
--------------------------------------------------------------------------------
-- QUE VAMOS A HACER : ver el unico uso defendible de GOTO y el uso correcto
--                     de la sentencia NULL.
-- QUE DEBE OBSERVAR : la etiqueta debe preceder a una sentencia ejecutable;
--                     por eso aparece NULL; justo despues de la etiqueta.
-- RESULTADO ESPERADO: dos lineas, sin la tercera.
--------------------------------------------------------------------------------
DECLARE
  vcError CHAR(1) := 'S';
BEGIN
  DBMS_OUTPUT.PUT_LINE('Inicio del proceso');
  IF vcError = 'S' THEN
    GOTO fin;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Esta linea no se ejecuta');
  <<fin>>
  NULL;
  DBMS_OUTPUT.PUT_LINE('Fin del proceso');
END;
/
-- ADVERTENCIA PROFESIONAL: WHEN OTHERS THEN NULL; compila sin quejarse y
-- silencia todos los errores del bloque. Nunca lo escriba.


--------------------------------------------------------------------------------
-- EJERCICIOS PROPUESTOS
--------------------------------------------------------------------------------
-- Resuelvalos sobre las tablas CTRL_ de este script. Cada uno trae pista y
-- criterio de logrado para que usted mismo verifique su solucion.
--
-- EJERCICIO 1 - Clasificacion por semestre
--   Escriba un bloque que recorra CTRL_ESTUDIANTE e imprima, por cada
--   estudiante, si pertenece a primer ano (semestre 1 o 2), ciclo basico
--   (3 a 6) o ciclo profesional (7 o mas).
--   Pista: CASE buscado dentro de un FOR sobre cursor.
--   Logrado si: la salida tiene 8 lineas y ningun estudiante queda sin clasificar.

DECLARE
    vvCiclo VARCHAR2(25);
BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('ALUMNO', 20) || '| ' || RPAD('CICLO', 20));
    FOR r IN (SELECT nombre, semestre FROM ctrl_estudiante) LOOP
        CASE
            WHEN r.semestre >= 7 THEN vvCiclo := 'Ciclo Profesional';
            WHEN r.semestre >= 3 THEN vvCiclo := 'Ciclo Básico';
            ELSE                      vvCiclo := 'Primer Año';
        END CASE;
        DBMS_OUTPUT.PUT_LINE(RPAD(r.nombre, 20) || '| ' || RPAD(vvCiclo, 20));
    END LOOP;
END;
/

-- EJERCICIO 2 - Nota faltante
--   Recorra CTRL_NOTA e imprima el nombre de los estudiantes que tengan al
--   menos un corte sin registrar. No use la clausula WHERE de la consulta:
--   la deteccion debe hacerse con una estructura de control.
--   Pista: IF con OR y la comparacion IS NULL.
--   Logrado si: aparece Felipe Cardenas y nadie mas.

BEGIN
    FOR r IN (SELECT
                e.nombre,
                n.corte1,
                n.corte2,
                n.corte3
                FROM ctrl_estudiante e JOIN ctrl_nota n ON e.id_estudiante = n.id_estudiante) LOOP
        IF r.corte1 IS NULL OR r.corte2 IS NULL OR r.corte3 IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('El estudiante ' || r.nombre || ' tiene un corte sin registrar.');
        END IF;
    END LOOP;
END;
/

-- EJERCICIO 3 - Cuotas con tope
--   Un estudiante debe 1.200.000 pesos y abona 180.000 mensuales. Calcule en
--   cuantos meses termina de pagar, con un tope de 24 meses para evitar
--   bucles infinitos. Imprima el saldo restante en cada mes.
--   Pista: WHILE con dos condiciones, o LOOP con dos EXIT WHEN.
--   Logrado si: el bucle termina en 7 meses y el ultimo abono es parcial.

DECLARE
    vnSaldo NUMBER(7,0) := 1200000;
    vpCuotas PLS_INTEGER := 0;
BEGIN
    WHILE vnSaldo >= 0 AND vpCuotas < 24 LOOP
        vnSaldo := vnSaldo - 180000;
        vpCuotas := vpCuotas + 1;
        IF          vnSaldo >= 0 THEN DBMS_OUTPUT.PUT_LINE('El saldo restante del mes ' || vpCuotas || ' es de: ' || vnSaldo);
        ELSIF       vnSaldo < 0 THEN DBMS_OUTPUT.PUT_LINE('El saldo restante del mes ' || vpCuotas || ' es de: ' ||'0. El abono fue de: ' || TO_CHAR(180000 + vnSaldo));
        END IF;
    END LOOP;
END;
/

-- EJERCICIO 4 - Tabla de multiplicar con saltos
--   Imprima la tabla del 7 del 1 al 20, omitiendo los multiplos de 3 y
--   deteniendo el bucle cuando el producto supere 100.
--   Pista: CONTINUE WHEN y EXIT WHEN en el mismo bucle.
--   Logrado si: la ultima linea impresa es 7 x 14 = 98.

BEGIN
    <<bucle>>
    FOR i IN 1..20 LOOP
        CONTINUE bucle WHEN MOD(i, 3) = 0;
        EXIT bucle WHEN 7 * i > 100;
        DBMS_OUTPUT.PUT_LINE(7 || ' x ' || i || ' = ' || TO_CHAR(7*i));
    END LOOP;
END;
/

-- EJERCICIO 5 - Reescritura
--   Tome el bloque del PASO 2 y reescriba la cascada de IF THEN ELSIF como
--   una sola expresion CASE asignada a la variable v_nivel.
--   Pista: la expresion CASE cierra con END, no con END CASE.
--   Logrado si: el resultado es identico para las notas 4.2, 3.0 y 2.5.

DECLARE
    vnNota   NUMBER(3,2) := 2.5;
    vvNivel  VARCHAR2(10);
BEGIN
    vvNivel := CASE
                WHEN vnNota >= 4 THEN 'ALTO'
                WHEN vnNota >= 3 THEN 'MEDIO'
                ELSE                  'BAJO'
               END;
  DBMS_OUTPUT.PUT_LINE('Nivel  = ' || vvNivel);
END;
/

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- LIMPIEZA - ejecute este bloque SOLO cuando haya terminado la practica
--------------------------------------------------------------------------------
DROP TABLE ctrl_nota PURGE;
DROP TABLE ctrl_estudiante PURGE;
--------------------------------------------------------------------------------

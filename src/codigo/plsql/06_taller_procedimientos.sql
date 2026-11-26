--------------------------------------------------------------------------------
-- UNIVERSIDAD EL BOSQUE — INGENIERIA DE SISTEMAS
-- Asignatura: Bases de Datos 2
-- Docente: Ing., Esp., M.Ed. Christian Felipe Duarte
--
-- TALLER PL/SQL — PLANTILLA DE ENTREGA
--
-- GRUPO No.: 2
-- INTEGRANTES: 1) Luna Calderón Montenegro
--              2) Juan Felipe Lozada Jara
--              3) Samuel Andres Mesa Comaz
-- FECHA DE ENTREGA: 3 de octurbe de 2026
--------------------------------------------------------------------------------
--
-- COMO TRABAJAR
--   1. Ejecute primero, completo, el script 01_esquema_inventario.sql
--   2. Desarrolle cada punto en la seccion correspondiente de este archivo
--   3. No borre los encabezados de cada ejercicio ni cambie los nombres de los
--      objetos solicitados. La revision los busca por nombre: un objeto correcto
--      con otro nombre se califica como no entregado.
--   4. Los esqueletos de la Parte 5 no incluyen la clausula de disparo. Definirla
--      hace parte del ejercicio, de modo que esos bloques no compilan tal como se
--      entregan.
--
-- DISTRIBUCION DEL PUNTAJE                                     Total: 50 puntos
--   Parte 1  Procedimientos almacenados .................  8 puntos
--   Parte 2  Funciones ...................................  8 puntos
--   Parte 3  Cursores .................................... 10 puntos
--   Parte 4  Manejo de excepciones .......................  9 puntos
--   Parte 5  Disparadores ................................ 10 puntos
--   Parte 6  Caso integrador .............................  5 puntos
--
-- CRITERIOS DE EVALUACION
--   Correccion tecnica ....... 40%   El objeto compila y cumple el enunciado
--   Justificacion ............ 40%   Las decisiones de diseno estan argumentadas
--   Analisis operacional ..... 20%   Se anticipa el comportamiento ante
--                                    concurrencia, volumen y error
--
--   Cada objeto debe incluir su justificacion en el espacio marcado. Un ejercicio
--   sin justificacion obtiene como maximo el 40% de su puntaje aunque funcione.
--   Una justificacion que confunde la causa con el efecto no obtiene puntaje.
--   Describir lo que hace el codigo, sin argumentar por que se eligio esa
--   construccion y no otra, equivale a no justificar.
--
-- ENTREGA
--   Este archivo renombrado como TALLER_PLSQL_GRUPO_<n>.sql, junto con un
--   documento que contenga las salidas de DBMS_OUTPUT de cada bloque ejecutado.
--   Ambos archivos deben incluir los nombres de los tres integrantes.
--
-- SUSTENTACION
--   20 minutos por grupo. Los tres integrantes deben poder explicar cualquier
--   parte del codigo, no solamente la que desarrollaron.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

--==============================================================================
-- PARTE 1 — PROCEDIMIENTOS ALMACENADOS                        (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 1.1 (2 pts)
-- SP_REGISTRAR_PRODUCTO
-- Registra un producto nuevo. Debe asignar el identificador desde SEQ_PRODUCTO,
-- validar que el precio de venta supere el costo unitario, verificar que la
-- categoria exista y manejar el caso de codigo duplicado. Devuelve el
-- identificador generado.
-------------------------------------------------------------------------------
-- JUSTIFICACION: 
--Validamos primero el precio y la categoría para después tomar el numero de la 
--secuencia porque un ROLLBACK no la devuelve. El código duplicado lo manejamos 
--capturando DUP_VAL_ON_INDEX porque UNIQUE evita los duplicados incluso con usuarios a la vez.
--No se hace COMMIT para que el quien use el procedimiento decida si lo hace o no. 
--
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_PRODUCTO (
    p_codigo        IN  VARCHAR2,
    p_nombre        IN  VARCHAR2,
    p_id_categoria  IN  NUMBER,
    p_precio        IN  NUMBER,
    p_costo         IN  NUMBER,
    p_stock_minimo  IN  NUMBER DEFAULT 0,
    p_id_producto   OUT NUMBER
) IS
    vn_auxiliar NUMBER;
BEGIN
    --Que el precio de venta sea mayor al costo de uno solo
    if p_precio <= p_costo then
        raise_application_error(-20001, 'El precio de venta debe ser mayor al costo unitario');
    end if;

    --Que la categoria exista
    select count(*) into vn_auxiliar 
    from categoria 
    where id_categoria = p_id_categoria;
    if vn_auxiliar = 0 then
        raise_application_error(-20002, 'La categoría no existe');
    end if;

    --Que se tome el identificador desde la secuencia
    p_id_producto := SEQ_PRODUCTO.NEXTVAL;

    --Insertar
        INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria,
                          precio_unitario, costo_unitario, stock_minimo, activo)
    VALUES (p_id_producto, p_codigo, p_nombre, p_id_categoria,
            p_precio, p_costo, p_stock_minimo, 'S');
    EXCEPTION
    --Codigo duplicado
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Ya existe un producto con el codigo ' || p_codigo);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en SP_REGISTRAR_PRODUCTO: ' || SQLERRM);
        RAISE;
END SP_REGISTRAR_PRODUCTO;
/
--Prueba

DECLARE
    vn_aux NUMBER;
BEGIN
    SP_REGISTRAR_PRODUCTO('PP-0001','prueba', 1,100000, 50000,5,vn_aux);

    DBMS_OUTPUT.PUT_LINE(vn_aux);
END;
--prueba de que se registro
SELECT *
FROM   PRODUCTO
WHERE  codigo = 'PP-0001';
/

------------------------------------------------------------------- 1.2 (3 pts)
-- SP_AJUSTAR_STOCK
-- Registra una ENTRADA, SALIDA o AJUSTE de inventario sobre una bodega.
-- Debe actualizar EXISTENCIA e insertar el registro en MOVIMIENTO_INVENTARIO,
-- devolviendo el saldo resultante.
--   * Si la combinacion bodega-producto no existe y el tipo es ENTRADA, crearla
--   * Si el tipo es SALIDA y no existe la combinacion, rechazar la operacion
--   * Una SALIDA nunca puede dejar la existencia en negativo
-- Proteja la lectura de la existencia frente a modificaciones concurrentes.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/* 
El procedimiento centraliza las operaciones de inventario, permitiendo registrar 
ENTRADAS, SALIDAS y AJUSTES. La existencia se consulta con FOR UPDATE para bloquear 
la fila mientras se realiza la operación y evitar modificaciones al mismo tiempo 
sobre el mismo producto y bodega. 

Si la existencia no existe, solamente se permite crearla cuando la operación es 
una ENTRADA. Una SALIDA sobre una combinación inexistente se rechaza y una SALIDA 
nunca puede producir una existencia negativa. 

Cada operación realizada se registra en MOVIMIENTO_INVENTARIO. 
*/
CREATE OR REPLACE PROCEDURE SP_AJUSTAR_STOCK (
    p_id_producto  IN  NUMBER,
    p_id_bodega    IN  NUMBER,
    p_tipo         IN  VARCHAR2,
    p_cantidad     IN  NUMBER,
    p_observacion  IN  VARCHAR2 DEFAULT NULL,
    p_saldo_final  OUT NUMBER
) IS
    v_cantidad_existencia EXISTENCIA.cantidad%TYPE;
    v_nuevo_saldo         EXISTENCIA.cantidad%TYPE;
BEGIN

    IF p_tipo NOT IN ('ENTRADA', 'SALIDA', 'AJUSTE') THEN RAISE_APPLICATION_ERROR(-20001, 'Tipo de movimiento no valido');
    END IF;

    IF p_cantidad <= 0 THEN RAISE_APPLICATION_ERROR(-20002, 'La cantidad debe ser mayor que cero');
    END IF;

    BEGIN
        SELECT cantidad INTO v_cantidad_existencia FROM EXISTENCIA
            WHERE id_bodega = p_id_bodega AND id_producto = p_id_producto FOR UPDATE;

        IF p_tipo = 'ENTRADA' THEN v_nuevo_saldo := v_cantidad_existencia + p_cantidad;
        ELSIF p_tipo = 'SALIDA' THEN v_nuevo_saldo := v_cantidad_existencia - p_cantidad;
            IF v_nuevo_saldo < 0 THEN RAISE_APPLICATION_ERROR(-20003, 'La salida supera la existencia disponible');
            END IF;
        ELSE v_nuevo_saldo := v_cantidad_existencia + p_cantidad;
        END IF;

        UPDATE EXISTENCIA SET cantidad = v_nuevo_saldo WHERE id_bodega = p_id_bodega AND id_producto = p_id_producto;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF p_tipo = 'ENTRADA' THEN v_nuevo_saldo := p_cantidad;
                INSERT INTO EXISTENCIA (id_bodega, id_producto, cantidad)
                VALUES (p_id_bodega, p_id_producto, v_nuevo_saldo);
            ELSE
                RAISE_APPLICATION_ERROR(-20004, 'No existe existencia para esta bodega y producto');
            END IF;
    END;

    INSERT INTO MOVIMIENTO_INVENTARIO (id_movimiento, id_producto, id_bodega, 
    tipo, cantidad, fecha_mov, id_pedido, usuario_bd, observacion)
    VALUES (SEQ_MOVIMIENTO.NEXTVAL, p_id_producto, p_id_bodega, p_tipo, p_cantidad, 
    SYSDATE, NULL, USER, p_observacion);

    p_saldo_final := v_nuevo_saldo;

END SP_AJUSTAR_STOCK;
/
-- Pruebas
DECLARE
    v NUMBER;
    PROCEDURE intento(p_prod NUMBER, p_bod NUMBER, p_tipo VARCHAR2,
                      p_cant NUMBER, p_msg VARCHAR2) IS
    BEGIN
        SP_AJUSTAR_STOCK(p_prod, p_bod, p_tipo, p_cant, 'prueba 1.2', v);
        DBMS_OUTPUT.PUT_LINE(RPAD(p_msg, 34) || '-> saldo ' || v);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(RPAD(p_msg, 34) || '-> ' || SQLERRM);
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Saldo inicial 1001/bodega 1: ' || FN_STOCK_DISPONIBLE(1001, 1));
    intento(1001, 1, 'ENTRADA', 10,    'ENTRADA existente');        
    intento(1001, 1, 'SALIDA',  30,    'SALIDA valida');            
    intento(1001, 1, 'AJUSTE',  5,     'AJUSTE');                   
    intento(1005, 2, 'ENTRADA', 7,     'ENTRADA crea combinacion'); 
    intento(1001, 1, 'SALIDA',  99999, 'SALIDA mayor a existencia'); 
    intento(1002, 2, 'SALIDA',  1,     'SALIDA combinacion inexist.');
    intento(1001, 1, 'OTRO',    5,     'tipo invalido');            
    intento(1001, 1, 'ENTRADA', 0,     'cantidad 0');               
    SELECT COUNT(*) INTO v FROM MOVIMIENTO_INVENTARIO WHERE observacion = 'prueba 1.2';
    DBMS_OUTPUT.PUT_LINE('Movimientos registrados: ' || v);         
    ROLLBACK;
END;
/


------------------------------------------------------------------- 1.3 (3 pts)
-- SP_CREAR_PEDIDO
-- Crea la cabecera de un pedido en estado BORRADOR y devuelve el identificador
-- generado. Debe rechazar clientes inactivos y clientes sin cupo de credito
-- disponible, con mensajes distinguibles entre si.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*¿Que hace? La siguiente sentencia crea un procedimiento almacenado que recibe como entrada
el id del cliente y como salida el id del pedido. Se nos pide crear un pedido con
el id del cliente recibido con estado BORRADOR, rechazando a los clientes sin cupo
o inactivos. Por lo que inicializamos las variables vc_activo de un solo character 
en 'N' (Inactivo), vn_cupo como numero en 0, y las excepciones e_inactivo y e_sincupo.
Consultamos las columnas activo, cupo_credito y saldo pendiente para asignar a las 
variables  vc_activo si el cliente esta activo o no (S/N) y a vn_cupo el cupo de 
credito menos el saldo pendiente. Luego condicionamos, si vc_activo se guarda en N
eleva 'Usuario inactivo', si vn_cupo es menor o igual a 0 eleva 'Usuario sin cupo disponible',
luego si ninguna de las anteriores se cumple ahi si crea un nuevo pedido con el 
id del usuario ingresado, el id del pedido siguiente secuencialmente y estado: 'BORRADOR'.
¿Porque? Se realiza la sentencia con un procedimiento almacenado ya que, como lo que 
se esta pidiendo es actualizar una tabla, se realiza una accion DML y se entregam el 
resultado mediante el OUT de los parametros. */

CREATE OR REPLACE PROCEDURE SP_CREAR_PEDIDO (
    p_id_cliente  IN  NUMBER,
    p_id_pedido   OUT NUMBER
) IS
    vc_activo CHAR(1) := 'N';
    vn_cupo NUMBER := 0;
    e_inactivo EXCEPTION;
    e_sin_cupo EXCEPTION;
    
BEGIN
    SELECT activo, cupo_credito - saldo_pendiente
    INTO vc_activo, vn_cupo
    FROM CLIENTE WHERE id_cliente = p_id_cliente;
    
    IF vc_activo = 'N' THEN 
        RAISE e_inactivo;
    ELSIF vn_cupo <= 0 THEN
        RAISE e_sin_cupo;
    END IF;
    
    INSERT INTO PEDIDO (id_pedido, id_cliente, estado)
        VALUES (seq_pedido.NEXTVAL, p_id_cliente, 'BORRADOR')
    RETURNING id_pedido INTO p_id_pedido;
    
EXCEPTION 
    WHEN e_inactivo THEN 
        dbms_output.put_line('Usuario Inactivo');
    WHEN e_sin_cupo THEN 
        dbms_output.put_line('Usuario sin cupo disponible');
    
    WHEN NO_DATA_FOUND THEN 
        dbms_output.put_line('Usuario no encontrado');
    
END SP_CREAR_PEDIDO;
/

-- PRUEBA PUNTO 1.3

DECLARE
    vn_id_pedido NUMBER;
BEGIN
    FOR i IN 501..507 LOOP
        SP_CREAR_PEDIDO(i,vn_id_pedido);
        dbms_output.put_line('Pedido ' || i || ' procesado. ID generado: ' || vn_id_pedido);
    END LOOP;
    
    ROLLBACK;
END;
/

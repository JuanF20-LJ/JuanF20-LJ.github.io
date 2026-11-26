--==============================================================================
-- PARTE 4 — MANEJO DE EXCEPCIONES                             (9 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 4.1 (2 pts)
-- FN_PRECIO_PRODUCTO
-- Funcion que reciba el CODIGO de un producto y retorne su precio, manejando
-- explicitamente NO_DATA_FOUND y TOO_MANY_ROWS, con retorno de -1 y -2
-- respectivamente, e imprimiendo un mensaje descriptivo en cada caso.
-- Explique en que situacion real se produciria TOO_MANY_ROWS sobre esta tabla,
-- considerando las restricciones que hoy tiene.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Usamos SELECT INTO en lugar de un cursor explicito porque se espera una 
-- sola fila. Dejamos al motor mismo levantar automaticamente 
-- las excepciones NO_DATA_FOUND y TOO_MANY_ROWS y asi podemos capturarlas en EXCEPTION
-- sin usar IF o contadores manuales. Los mensajes (DBMS_OUTPUT) los pusimos antes del RETURN 
-- para que se impriman antes de que la funcion termine.
-- 
-- Situacion real: La tabla PRODUCTO tiene la restriccion 
-- UNIQUE (uk_producto_codigo).Entonces por diseñono puede devolver 
-- TOO_MANY_ROWS. En un entorno real, esta excepcion solo saldria si un alguien 
-- de base de datos con permisos suficientes deshabilita temporalmente la restriccion (DISABLE CONSTRAINT) 
-- para hacer una carga masiva de datos y entonces se insertan duplicados por error, y esta 
-- funcion se ejecuta antes de que se limpie los datos y se reactive la restriccion.
CREATE OR REPLACE FUNCTION FN_PRECIO_PRODUCTO (
    p_codigo IN VARCHAR2
) RETURN NUMBER IS
 vn_precio PRODUCTO.precio_unitario%TYPE;
BEGIN
    --Se espera una sola fila
    SELECT precio_unitario
    INTO   vn_precio
    FROM   PRODUCTO
    WHERE  codigo = p_codigo;
    
    RETURN vn_precio;
EXCEPTION
    --No encontro nada
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Aviso: No se encontro ningun producto registrado con el codigo: ' || p_codigo);
        RETURN -1;
    --Mas filas de las que deberia haber.No deberia pasar
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Error critico: Se encontraron multiples productos con el codigo ' || p_codigo || '.');
        RETURN -2;
    --Cualquier otro error
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en FN_PRECIO_PRODUCTO: ' || SQLERRM);
        RAISE;
        
END FN_PRECIO_PRODUCTO;
/

select FN_PRECIO_PRODUCTO('HM-0001') as codigoExistente,
       FN_PRECIO_PRODUCTO('1') as codigoInexistente
from dual;

------------------------------------------------------------------- 4.2 (2 pts)
-- SP_VALIDAR_DESPACHO
-- Procedimiento que verifique si puede despacharse una cantidad de un producto
-- desde una bodega. Debe declarar una EXCEPCION PROPIA, levantarla con RAISE
-- cuando la cantidad solicitada supere el disponible, y capturarla en el bloque
-- EXCEPTION.
-- Argumente por que conviene nombrar esa condicion en lugar de resolverla con un
-- condicional.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*¿Que hace? El procedimiento recibe un producto, una bodega y la cantidad que se 
quiere despachar, se verifica si se puede hacer el despacho con la cantidad en EXISTENCIA
y la compara con la cantidad pedida, si es mayor a la cantidad en stock se define 
la variable de salida del procedimiento como insuficiente, y se eleva la excepcion si es 
insuficiente, pero si es suficiente se imprimen la cantidad disponible en bodega.
¿por que? Se realiza con una excepcion propia porque oracle no cuenta con una que 
verifique esta regla, lanzar el error con raise separa el caso del error, se usa un 
procedimiento con salida porque el resultado no modifica niinguna tabla. */


CREATE OR REPLACE PROCEDURE SP_VALIDAR_DESPACHO (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER,
    p_cantidad    IN NUMBER,
    p_suficiente OUT BOOLEAN
) IS
    e_stock_insuficiente EXCEPTION;
    vn_cantidad NUMBER := 0;
    vb_suficiente BOOLEAN := FALSE;
BEGIN
    SELECT cantidad 
    INTO vn_cantidad
    FROM EXISTENCIA 
    WHERE id_producto = p_id_producto
    AND id_bodega = p_id_bodega;
    
    IF  p_cantidad > vn_cantidad THEN
        vb_suficiente := FALSE;
        
        RAISE e_stock_insuficiente;
    ELSE 
        vb_suficiente := TRUE;
        dbms_output.put_line('Cantidad en stock disponible: ' || vn_cantidad || ' ');
    END IF;
    
    p_suficiente := vb_suficiente ;
    
EXCEPTION
    WHEN e_stock_insuficiente THEN
        dbms_output.put_line('La cantidad de productos en stock es insuficiente');
    
END SP_VALIDAR_DESPACHO;
/

-- PRUEBA 4.2
DECLARE
    vb_suficiente BOOLEAN;
    vn_id_producto NUMBER := 1001;
    vn_id_bodega NUMBER := 1;
    vn_cantidad NUMBER := 50;
BEGIN
    
    SP_VALIDAR_DESPACHO(vn_id_producto, vn_id_bodega, vn_cantidad, vb_suficiente); 
    IF vb_suficiente THEN
        dbms_output.put_line('Para la consulta de ' || vn_cantidad || 
        ' produtos de la referencia: ' || vn_id_producto);
        dbms_output.put_line('Resultado: puede despacharse');
    ELSE
        dbms_output.put_line('  Resultado: NO puede despacharse');
    END IF;
END;
/

------------------------------------------------------------------- 4.3 (2 pts)
-- SP_ANULAR_PEDIDO
-- Procedimiento que anule un pedido, usando RAISE_APPLICATION_ERROR con estos
-- codigos:
--     -20010  el pedido no existe
--     -20011  el pedido ya esta anulado
--     -20012  el pedido tiene mas de 30 dias
-- Explique la diferencia entre RAISE y RAISE_APPLICATION_ERROR, y en que caso el
-- cliente de la base de datos puede distinguirlos.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
RAISE permite lanzar una excepción PL/SQL, normalmente una excepción predefinida
o una excepción declarada por el programador.  
RAISE_APPLICATION_ERROR permite generar un error personalizado con un código 
entre -20000 y -20999 y un mensaje definido por el programador. 
Por eso RAISE_APPLICATION_ERROR es apropiado cuando se busca devolver errores específicos, 
indicando un mensaje en cada caso. 
*/
CREATE OR REPLACE PROCEDURE SP_ANULAR_PEDIDO (
    p_id_pedido IN NUMBER
) IS

    vpFecha  PEDIDO.fecha_pedido%TYPE;
    vpEstado PEDIDO.estado%TYPE;

BEGIN

    BEGIN
        SELECT fecha_pedido, estado INTO vpFecha, vpEstado
        FROM PEDIDO
        WHERE id_pedido = p_id_pedido;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20010, 'EL PEDIDO NO EXISTE');
    END;

    IF vpEstado = 'ANULADO' THEN RAISE_APPLICATION_ERROR( -20011, 'EL PEDIDO YA ESTÁ ANULADO' );
    END IF;

    IF vpFecha < SYSDATE - 30 THEN RAISE_APPLICATION_ERROR(-20012, 'EL PEDIDO TIENE MAS DE 30 DÍAS');
    END IF;

    UPDATE PEDIDO SET estado = 'ANULADO' WHERE id_pedido = p_id_pedido;
END SP_ANULAR_PEDIDO;
/

--Pruebas
DECLARE
    v_estado PEDIDO.estado%TYPE;
BEGIN
    FOR r IN (SELECT 999 id, 'no existe' caso FROM dual
              UNION ALL SELECT 7, 'ya anulado'     FROM dual
              UNION ALL SELECT 1, 'mas de 30 dias' FROM dual) LOOP
        BEGIN
            SP_ANULAR_PEDIDO(r.id);
            DBMS_OUTPUT.PUT_LINE(RPAD(r.caso, 16) || '-> anulado (no deberia)');
        EXCEPTION WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(RPAD(r.caso, 16) || '-> ' || SQLCODE || ' ' || SQLERRM);
        END;
    END LOOP;
    
    INSERT INTO PEDIDO (id_pedido, id_cliente) VALUES (9001, 501);
    SP_ANULAR_PEDIDO(9001);
    SELECT estado INTO v_estado FROM PEDIDO WHERE id_pedido = 9001;
    DBMS_OUTPUT.PUT_LINE(RPAD('pedido valido', 16) || '-> estado ' || v_estado);   -- ANULADO
    ROLLBACK;
END;
/
------------------------------------------------------------------- 4.4 (2 pts)
-- Bloque anonimo que intente insertar un producto con una categoria inexistente
-- y capture el error de integridad referencial asociando ORA-02291 a una
-- excepcion con nombre.
-- Explique que aporta esa asociacion frente a atrapar el error en un manejador
-- generico.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Usamos PRAGMA EXCEPTION_INIT para enlazar un error de Oracle (ORA-02291: violation of foreign key) 
-- con una excepcion de nosotros (e_categoria_invalida). Esto nos deja capturar la falla por su nombre
-- en la clausula WHEN.
-- 
-- WHEN OTHERS: Capturar el error dentro de un WHEN OTHERS es una mala practica porque obliga a tragarse todos los errores posibles.
-- Si usaramos OTHERS,habria que programar un IF para saber que paso. 
-- Al usar el PRAGMA, logramos un control especifico porque atrapamos solo el error especifico 
-- y asi cualquier otro error no visto escale de forma natural.


DECLARE
    --Exepcion propia
    e_categoriaInvalida EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_categoriaInvalida, -2291);

BEGIN
    DBMS_OUTPUT.PUT_LINE('Intentando insertar producto.');
    
    INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria, 
                          precio_unitario, costo_unitario, stock_minimo, activo)
    VALUES (9999, 'PP-0044', 'Prueba2', 999, 
            20000, 15000, 10, 'S');
            
    -- Si el insert funcionara se confirma(no funciona)
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Insercion exitosa.'); 

EXCEPTION
    WHEN e_categoriaInvalida THEN
        DBMS_OUTPUT.PUT_LINE('Error: No se puede registrar el producto porque la categoria indicada no existe.');
        ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/

------------------------------------------------------------------- 4.5 (1 pt)
-- SP_REGISTRAR_ERROR
-- Procedimiento que reciba el origen y registre en LOG_ERRORES el SQLCODE y el
-- SQLERRM actuales. El registro debe persistir aunque la transaccion principal
-- termine en ROLLBACK.
-- Explique por que se requiere esa independencia transaccional y describa un
-- escenario en el que esa misma independencia oculte informacion en lugar de
-- preservarla.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
Se utiliza una transacción autónoma para que el registro del error sea independiente
de la transacción principal. De esta forma, si la operación principal falla y 
posteriormente realiza ROLLBACK, el registro almacenado en LOG_ERRORES permanece. 
SQLCODE y SQLERRM permiten registrar automáticamente el código y mensaje del error
que se encuentra activo cuando se ejecuta el procedimiento. 
*/

CREATE OR REPLACE PROCEDURE SP_REGISTRAR_ERROR (
    p_origen  IN VARCHAR2,
    p_detalle IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    vn_codigo  NUMBER;
    vc_mensaje VARCHAR2(500);
BEGIN
    vn_codigo  := SQLCODE;
    vc_mensaje := SUBSTR(SQLERRM, 1, 500);  
 
    INSERT INTO LOG_ERRORES (id_log, origen, codigo_error, mensaje, detalle, usuario_bd, fecha_log)
    VALUES (SEQ_LOG.NEXTVAL, p_origen, vn_codigo, vc_mensaje, p_detalle, USER, SYSTIMESTAMP);
    COMMIT;
END SP_REGISTRAR_ERROR;
/
--Pruebas:
DECLARE
    v NUMBER;
BEGIN
    INSERT INTO PEDIDO (id_pedido, id_cliente) VALUES (9002, 501);  
    SELECT 1 / 0 INTO v FROM dual;                                  
EXCEPTION WHEN OTHERS THEN
    SP_REGISTRAR_ERROR('PRUEBA_4_5', 'division por cero provocada');
    ROLLBACK;
END;
/
SELECT COUNT(*) AS pedido_9002_tras_rollback FROM PEDIDO WHERE id_pedido = 9002;   
SELECT origen, codigo_error, mensaje, detalle
FROM   LOG_ERRORES WHERE origen = 'PRUEBA_4_5';  
 
DELETE FROM LOG_ERRORES WHERE origen = 'PRUEBA_4_5';
COMMIT;
/

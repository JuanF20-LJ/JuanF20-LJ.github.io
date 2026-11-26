--==============================================================================
-- PARTE 5 — DISPARADORES                                     (10 puntos / 90 min)
--==============================================================================
-- Los esqueletos de esta parte no incluyen la clausula de disparo. Definirla
-- hace parte del ejercicio.
--==============================================================================

------------------------------------------------------------------- 5.1 (2 pts)
-- TRG_CLIENTE_BI
-- Al insertar un cliente debe asignar el identificador desde SEQ_CLIENTE si
-- llega nulo, convertir el nombre a mayusculas sin espacios sobrantes y forzar
-- el estado activo a 'S' si no se indica.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Usamos el disparador antes de la insercion para garantizar que los datos 
-- defectuosos o incompletos no lleguen a escribirse para no corregirlos despues
-- de guardados.La asignacion automatica solo pasa si el dato falta, para no bloquear
-- cargas manuales o migraciones que necesiten conservar sus propios codigos.
-- La normalizacion de nombres (mayusculas y 
-- sin espacios extra) se dejo a la base de datos para que la 
-- informacion siempre sea uniforme sin depender de la aplicacion externa.
-- Se fuerza el valor 'S' cuando no hay dato para que el sistema no falle por violar el NOT NULL 
-- asegurando que el proceso continue.

CREATE OR REPLACE TRIGGER TRG_CLIENTE_BI
BEFORE INSERT ON CLIENTE
FOR EACH ROW
BEGIN
    --Si llega nulo, asignar el identificador
    IF :NEW.id_cliente IS NULL THEN
        :NEW.id_cliente := SEQ_CLIENTE.NEXTVAL;
    END IF;

    -- Nombre a mayusculas y sin espacios sobrantes
    IF :NEW.nombre IS NOT NULL THEN
        -- TRIM quita espacios a los bordes, REGEXP_REPLACE quita multiples espacios internos
        :NEW.nombre := TRIM(REGEXP_REPLACE(UPPER(:NEW.nombre), '\s+', ' '));
    END IF;

    -- Forzar el estado activo a 'S' si no se indica (llega nulo)
    IF :NEW.activo IS NULL THEN
        :NEW.activo := 'S';
    END IF;
END;
/

INSERT INTO CLIENTE (id_cliente, documento, nombre, ciudad, activo)
VALUES (NULL, '999888777', '   ferreteria    los   andes  ', 'Bogota', NULL);
select * from CLIENTE where documento = '999888777';
/

------------------------------------------------------------------- 5.2 (2 pts)
-- TRG_PRODUCTO_AU_PRECIO
-- Debe registrar en AUDITORIA_PRECIO todo cambio de precio, calculando la
-- variacion porcentual, y dispararse unicamente cuando el precio efectivamente
-- cambie, resolviendo esa condicion con la clausula WHEN y no dentro del cuerpo.
-- Explique la diferencia entre ambas formas.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
El trigger garantiza que cada modificación real del precio de un producto quede 
registrada automáticamente en AUDITORIA_PRECIO, sin depender de que el programador 
recuerde realizar el registro manualmente.  
Se utiliza un trigger AFTER UPDATE porque la auditoría debe realizarse después de
que el cambio de precio haya sido efectuado. Al ser FOR EACH ROW, permite acceder
a :OLD y :NEW para conocer el precio anterior y el nuevo. La cláusula WHEN evita 
generar registros cuando el precio realmente no cambió.  
Además, se calcula variacion_pct para conservar no solamente los dos precios, sino
también el porcentaje de modificación.  
*/
CREATE OR REPLACE TRIGGER TRG_PRODUCTO_AU_PRECIO
    AFTER UPDATE OF precio_unitario ON PRODUCTO
    FOR EACH ROW
    WHEN (OLD.precio_unitario <> NEW.precio_unitario)

BEGIN

    INSERT INTO AUDITORIA_PRECIO (id_auditoria, id_producto, precio_anterior, precio_nuevo, variacion_pct)
    VALUES (SEQ_AUDITORIA.NEXTVAL, :OLD.id_producto, :OLD.precio_unitario, :NEW.precio_unitario,
        ((:NEW.precio_unitario - :OLD.precio_unitario)/ :OLD.precio_unitario) * 100);

END;
/
--Pruebas:
UPDATE PRODUCTO SET precio_unitario = 50000 WHERE id_producto = 1001;           
UPDATE PRODUCTO SET precio_unitario = 50000 WHERE id_producto = 1001;           
UPDATE PRODUCTO SET precio_unitario = precio_unitario WHERE id_producto = 1001; 
UPDATE PRODUCTO SET nombre = nombre WHERE id_producto = 1001;                   
SELECT id_producto, precio_anterior, precio_nuevo, variacion_pct
FROM   AUDITORIA_PRECIO WHERE id_producto = 1001;   
ROLLBACK;
/

------------------------------------------------------------------- 5.3 (2 pts)
-- TRG_PRODUCTO_BIU_MARGEN
-- Debe impedir que se guarde un producto cuyo precio no alcance el margen minimo
-- de su categoria, segun la formula precio >= costo * (1 + margen/100),
-- rechazando la operacion con el error -20020.
-- Considere que debe ocurrir cuando la categoria indicada no existe, y justifique
-- su decision.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/* ¿Que hace? El trigger se dispara en cada intento de insertar o actualizar un producto
cuyo precio unitario sea menor al minimo establecido por la categoria del producto
y el costo unitario del producto, evitando que en algun momento el producto se venda 
muy por debajo del minimo de lo que se puede vender el producto. 
Cuando la categoria no existe se eleva la excepcion NO_DATA_FOUND y se informa que
no se encontro la categoria, elegimos esta opcion porque sin la categoria no se puede 
calcular el minimo, asi que no se puede garantizar la regla y es mas seguro rechazar 
que dejar pasar la fila. Ademas, no permite continuar luego de lanzar la excepcion 
gracias al RAISE_APPLICATION_ERROR (-20021,Categoria no encontrada)
¿Por que? Se usa un trigger con el proposito de evitar que cualquier intento de insertar 
o actualizar un producto de forma incorrecta, se dispara el trigger y cancela cualquier 
intento. Ademas, dentro del trigger usamos BEFORE, y no after, ya que lo que necesitamos
es que se evite que se dispare ANTES de poder insertar o actualizar un producto. Tambien
usamos FOR EACH ROW porque necesita los valores :NEW de cada producto, :NEW y no un 
select porque leer la tabla desde el trigger causaria el error de tabla mutante. */

CREATE OR REPLACE TRIGGER TRG_PRODUCTO_BIU_MARGEN
    BEFORE INSERT OR UPDATE ON PRODUCTO
    FOR EACH ROW
DECLARE
    vn_margen NUMBER;
    vn_minimo NUMBER;
BEGIN
    SELECT margen_minimo
    INTO   vn_margen
    FROM   CATEGORIA
    WHERE  id_categoria = :NEW.id_categoria;

    vn_minimo := :NEW.costo_unitario * (1 + vn_margen / 100);

    IF :NEW.precio_unitario < vn_minimo THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Precio ' || :NEW.precio_unitario || ' por debajo del minimo permitido ' ||
            vn_minimo || ' (margen ' || vn_margen || '%)');
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021,'No se encontró la categoria');
END;
/

-- PRUEBA 5.3.1 (Deberia disparar)
BEGIN
    INSERT INTO PRODUCTO VALUES (2001, 'TST-001', 'Prueba 1', 1, 20000, 28000, 0, 'S');
    dbms_output.put_line('Insertado.');
    
EXCEPTION
    WHEN OTHERS THEN dbms_output.put_line(SQLERRM);
END;
/
-- PRUEBA 5.3.2 (Deberia insertar)
BEGIN
    INSERT INTO PRODUCTO VALUES (2001, 'TST-001', 'Prueba 1', 1, 40000, 28000, 0, 'S');
    dbms_output.put_line('Insert valido: aceptado');
    
EXCEPTION
    WHEN OTHERS THEN dbms_output.put_line(SQLERRM);
END;
/
-- PRUEBA 5.3.3  (Disparar con una actualizacion)
BEGIN
   BEGIN
        UPDATE PRODUCTO SET precio_unitario = 30000 WHERE id_producto = 2001;
        dbms_output.put_line('Update: aceptado (no deberia)');
EXCEPTION 
    WHEN OTHERS THEN 
        dbms_output.put_line('Actualizacion: ' || SQLERRM);
END;

    
SELECT p.id_producto, p.nombre, c.nombre AS categoria, p.precio_unitario, p.costo_unitario, c.margen_minimo
FROM PRODUCTO p 
LEFT JOIN CATEGORIA c ON p.id_categoria = c.id_categoria;

ROLLBACK;

SELECT text FROM user_source WHERE name = 'TRG_PRODUCTO_BIU_MARGEN' ORDER BY line;
/

------------------------------------------------------------------- 5.4 (2 pts)
-- TRG_DETALLE_AI_STOCK
-- Al insertar una linea de pedido debe descontar el stock de la bodega indicada
-- y registrar el movimiento de SALIDA correspondiente. Si no hay stock suficiente
-- debe abortar la operacion con el error -20030.
-- Explique por que el momento de disparo que eligio es el correcto y que dejaria
-- de funcionar con el contrario.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- El disparador actua despues de insertar porque es propagar un efecto a otras tablas
-- no alterar los datos del propio detalle del pedido. 
-- 
-- Si lo hicieramos ANTES el disparador modificaria el inventario sin saber si el detalle del pedido es valido. 
-- Dejaria de funcionar la logica porque podriamos descontar stock 
-- para una linea de pedido que el motor de base de datos terminara rechazando 
-- despues por violar una restriccion desperdiciando procesamiento en operaciones destinadas a fallar.
--
-- Usamos FOR UPDATE al consultar la existencia para 
-- bloquear la fila y asi evitar que si dos vendedores registran un 
-- detalle al mismo tiempo para el mismo producto el sistema lea el mismo saldo 
-- inicial para ambos y termine aprobando ventas sin stock real.

CREATE OR REPLACE TRIGGER TRG_DETALLE_AI_STOCK
AFTER INSERT ON DETALLE_PEDIDO
FOR EACH ROW
DECLARE
    v_stock_actual EXISTENCIA.cantidad%TYPE;
BEGIN
    --Se consulta el stock actual de la bodega bloqueando la fila
    SELECT cantidad
    INTO   v_stock_actual
    FROM   EXISTENCIA
    WHERE  id_bodega = :NEW.id_bodega
      AND  id_producto = :NEW.id_producto
    FOR UPDATE;

    --Validacion del stock suficiente
    IF :NEW.cantidad > v_stock_actual THEN
        RAISE_APPLICATION_ERROR(-20030, 'Error: Stock insuficiente en la bodega para el producto solicitado.');
    END IF;

    --Actualizacion del inventario
    UPDATE EXISTENCIA
    SET    cantidad = cantidad - :NEW.cantidad
    WHERE  id_bodega = :NEW.id_bodega
      AND  id_producto = :NEW.id_producto;

    --Registro en la bitacora de movimientos
    INSERT INTO MOVIMIENTO_INVENTARIO (
        id_movimiento, 
        id_producto, 
        id_bodega, 
        tipo, 
        cantidad, 
        id_pedido, 
        observacion
    ) VALUES (
        SEQ_MOVIMIENTO.NEXTVAL, 
        :NEW.id_producto, 
        :NEW.id_bodega, 
        'SALIDA', 
        :NEW.cantidad, 
        :NEW.id_pedido, 
        'Despacho automatico por nueva linea de pedido'
    );
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si la combinacion producto-bodega no existe en EXISTENCIA, no hay stock
        RAISE_APPLICATION_ERROR(-20030, 'Error: El producto no tiene registro en la bodega indicada.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/

SELECT cantidad as cantidad1001 FROM EXISTENCIA WHERE id_bodega = 1 AND id_producto = 1001;
INSERT INTO DETALLE_PEDIDO (id_pedido, linea, id_producto, id_bodega, cantidad, precio_unitario, subtotal)
VALUES (6, 1, 1001, 1, 10, 45000, 450000);
SELECT cantidad FROM EXISTENCIA WHERE id_bodega = 1 AND id_producto = 1001;
SELECT id_movimiento, tipo, cantidad, observacion FROM MOVIMIENTO_INVENTARIO WHERE id_pedido = 6;

INSERT INTO DETALLE_PEDIDO (id_pedido, linea, id_producto, id_bodega, cantidad, precio_unitario, subtotal)
VALUES (6, 2, 1001, 1, 5000, 45000, 225000000);
/


------------------------------------------------------------------- 5.5 (1 pt)
-- TRG_DETALLE_TOTAL
-- Debe recalcular el total de la cabecera del pedido despues de cualquier
-- insercion, actualizacion o borrado de sus lineas.
-- Documente el error que obtiene en su primer intento, en que momento aparece,
-- y como lo resuelve la construccion que finalmente utilizo.
-- Este punto no se califica sin esa explicacion.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
El trigger mantiene sincronizado el campo total de PEDIDO con la suma de los subtotales
de sus detalles. Cuando se inserta, modifica o elimina un detalle, el total del pedido
debe recalcularse porque los valores que lo componen han cambiado.  
Se utiliza un compound trigger porque DETALLE_PEDIDO es precisamente la tabla que
contiene los detalles que se están modificando. Intentar o consultar directamente 
esa misma tabla durante determinados momentos de un trigger de fila puede producir
el error de tabla mutante. La solución consiste en guardar durante AFTER EACH ROW
los pedidos afectados y realizar el cálculo cuando termina la sentencia, en AFTER STATEMENT. 

Esto además permite manejar correctamente los tres casos:  
INSERT: aparece un nuevo detalle. 
UPDATE: cambia un detalle existente. 
DELETE: desaparece un detalle. 

Finalmente, el total se obtiene mediante SUM(subtotal) y se actualiza en PEDIDO. 
Esto corresponde directamente con el modelo, donde DETALLE_PEDIDO contiene subtotal 
y PEDIDO contiene total. 
*/
CREATE OR REPLACE TRIGGER TRG_DETALLE_TOTAL
    FOR INSERT OR UPDATE OR DELETE ON DETALLE_PEDIDO
    COMPOUND TRIGGER

    TYPE t_pedidos IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    v_pedidos t_pedidos;

    AFTER EACH ROW IS
    BEGIN

        IF INSERTING OR UPDATING THEN v_pedidos(:NEW.id_pedido) := TRUE;
        END IF;
        IF DELETING OR UPDATING THEN v_pedidos(:OLD.id_pedido) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id_pedido PLS_INTEGER;
    BEGIN

        v_id_pedido := v_pedidos.FIRST;

        WHILE v_id_pedido IS NOT NULL LOOP

            UPDATE PEDIDO SET total = (SELECT NVL(SUM(subtotal), 0) FROM DETALLE_PEDIDO WHERE id_pedido = v_id_pedido)
            WHERE id_pedido = v_id_pedido;
            v_id_pedido := v_pedidos.NEXT(v_id_pedido);
        END LOOP;

    END AFTER STATEMENT;

END;
/
--Pruebas:
DECLARE
    PROCEDURE total(p_msg VARCHAR2) IS
        v NUMBER;
    BEGIN
        SELECT total INTO v FROM PEDIDO WHERE id_pedido = 9001;
        DBMS_OUTPUT.PUT_LINE(RPAD(p_msg, 36) || '-> total ' || v);
    END;
BEGIN
    INSERT INTO PEDIDO (id_pedido, id_cliente) VALUES (9001, 501);
    INSERT INTO DETALLE_PEDIDO VALUES (9001, 1, 1001, 1, 2,  45000, 90000);
    total('INSERT linea 1');                                 
    INSERT INTO DETALLE_PEDIDO VALUES (9001, 2, 1002, 1, 1,  62000, 62000);
    total('INSERT linea 2');                                 
    INSERT INTO DETALLE_PEDIDO                               
        SELECT 9001, 3, 1003, 1, 1, 38000, 38000 FROM dual
        UNION ALL
        SELECT 9001, 4, 1008, 1, 1, 18500, 18500 FROM dual;
    total('INSERT multifila (lineas 3 y 4)');                
    UPDATE DETALLE_PEDIDO SET subtotal = 100000 WHERE id_pedido = 9001 AND linea = 1;
    total('UPDATE linea 1 a 100.000');                       
    DELETE FROM DETALLE_PEDIDO WHERE id_pedido = 9001 AND linea = 2;
    total('DELETE linea 2');                                 
    DELETE FROM DETALLE_PEDIDO WHERE id_pedido = 9001;
    total('DELETE de todas las lineas');                     
    ROLLBACK;
END;
/

------------------------------------------------------------------- 5.6 (1 pt)
-- TRG_V_STOCK_IO
-- Debe permitir actualizar el precio y el stock minimo del producto a traves de
-- la vista V_STOCK_CONSOLIDADO.
-- Explique por que esa vista no es actualizable de forma directa.
-------------------------------------------------------------------------------
-- JUSTIFICACION:

CREATE OR REPLACE TRIGGER TRG_V_STOCK_IO
    INSTEAD OF UPDATE ON V_STOCK_CONSOLIDADO
    FOR EACH ROW
BEGIN

    UPDATE PRODUCTO
    SET precio_unitario = :NEW.precio_unitario,
    stock_minimo = :NEW.stock_minimo
    WHERE id_producto = :OLD.id_producto;
    
END;
/
SHOW ERRORS

UPDATE V_STOCK_CONSOLIDADO SET precio_unitario = 50000 , stock_minimo = 25 WHERE id_producto = 1001;

SELECT id_producto, precio_unitario, stock_minimo
FROM   PRODUCTO WHERE id_producto = 1001;

ROLLBACK;

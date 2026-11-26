--==============================================================================
-- PARTE 3 — CURSORES                                         (10 puntos / 90 min)
--==============================================================================

------------------------------------------------------------------- 3.1 (2 pts)
-- Bloque anonimo que recorra, con un CURSOR EXPLICITO, los productos cuyo stock
-- consolidado este por debajo del stock minimo, e imprima un reporte con codigo,
-- nombre, stock actual, stock minimo y unidades faltantes, mas el total de
-- productos en esa condicion.
-- Debe usar OPEN, FETCH y CLOSE de forma explicita. El ciclo FOR implicito no se
-- acepta en este punto.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Hicimos que la condicion %NOTFOUND
-- se evaluara despues del FETCH para no tomar una fila de mas.
-- Usamos el filtro stock_total < stock_minimo dentro del cursor en el WHERE para traer solo las
-- filas que cumplen.

DECLARE
    -- Declaración del cursor explícito
    CURSOR c_bajo_minimo IS
        SELECT codigo,
               producto,
               stock_total,
               stock_minimo,
               (stock_minimo - stock_total) AS faltantes
        FROM   V_STOCK_CONSOLIDADO
        WHERE  stock_total < stock_minimo
        ORDER  BY faltantes DESC;

    r_fila c_bajo_minimo%ROWTYPE;
    vn_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Reporte: Productos con stock por debajo del minimo');
    OPEN c_bajo_minimo;
    
    LOOP
        FETCH c_bajo_minimo INTO r_fila;
        EXIT WHEN c_bajo_minimo%NOTFOUND;
        --Para contar 
        vn_total := vn_total + 1;
        
        DBMS_OUTPUT.PUT_LINE('Código: ' || r_fila.codigo || 
                             ' | Producto: ' || r_fila.producto || 
                             ' | Stock Actual: ' || r_fila.stock_total || 
                             ' | Stock Mínimo: ' || r_fila.stock_minimo || 
                             ' | Faltantes: ' || r_fila.faltantes);
    END LOOP;
    
    CLOSE c_bajo_minimo;
    DBMS_OUTPUT.PUT_LINE('Total de productos por debajo del minimo: ' || vn_total);
END;
/

------------------------------------------------------------------- 3.2 (2 pts)
-- Bloque anonimo con un CURSOR PARAMETRIZADO que reciba identificador de cliente
-- y un rango de fechas, y muestre los pedidos CONFIRMADOS de ese cliente en ese
-- rango, con su total y la cantidad de lineas de cada pedido.
-- Pruebelo con el cliente 501 entre 2026-01-01 y 2026-12-31.
-- Los parametros deben declararse en el cursor, no tomarse del alcance del bloque.
-------------------------------------------------------------------------------
-- JUSTIFICACION
/*¿Que hace? Se crea un cursor sobre el que se recibe el id del cliente y un 
rango de fehcas, la consulta une PEDIDO con DETALLE_PEDIDO y devuelve,
por cada pedido en estado CONFIRMADO del cliente dentro del rango, su id, su fecha, 
su total y la cantidad de lineas, se imprimen todos los pedidos del usuario de el año,
Se usa p_hasta + 1 con el operador < para incluir todo el ultimo dia, aunque la fecha 
tenga hora.
¿Porque? Se usa un cursosor ya que se rreuqiere procesar el resultado fila por fila,
y se parametriza para que se pueda reutilizar el cursor con otro cliente u otro rango
de fechas. 
*/

DECLARE
    CURSOR c_pedidos (p_id_cliente NUMBER, p_desde DATE, p_hasta DATE) IS
        SELECT p.id_pedido, p.fecha_pedido, p.total, COUNT(d.linea) AS lineas
        FROM   pedido p
               LEFT JOIN detalle_pedido d ON p.id_pedido = d.id_pedido
        WHERE  p.id_cliente = p_id_cliente
        AND    p.estado = 'CONFIRMADO'
        AND    p.fecha_pedido >= p_desde
        AND    p.fecha_pedido <  p_hasta + 1
        GROUP  BY p.id_pedido, p.fecha_pedido, p.total
        ORDER  BY p.fecha_pedido;
BEGIN
    FOR r IN c_pedidos(501, DATE '2026-01-01', DATE '2026-12-31') LOOP
        DBMS_OUTPUT.PUT_LINE('Pedido: ' || r.id_pedido || ', ' || TO_CHAR(r.fecha_pedido, 'YYYY-MM-DD')
            || '. Total ' || TO_CHAR(r.total, 'FM999G999G990') || '. Lineas ' || r.lineas);
    END LOOP;
END;
/

------------------------------------------------------------------- 3.3 (3 pts)
-- Bloque anonimo con un CURSOR FOR UPDATE que recorra los productos de una
-- categoria y ajuste su precio un porcentaje dado, usando WHERE CURRENT OF.
--   * No debe modificar productos inactivos
--   * El precio resultante no puede quedar por debajo del costo mas el margen
--     minimo de la categoria
-- Explique que bloqueo genera FOR UPDATE, cuanto dura, y por que WHERE CURRENT OF
-- es preferible a un UPDATE por clave primaria.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
El cursor permite recorrer únicamente los productos activos de una determinada 
categoría y modificar su precio de forma individual. FOR UPDATE es necesario 
porque las filas seleccionadas serán modificadas posteriormente, por lo cual Oracle
las bloquea para evitar modificaciones al tiempo que el cursor las procesa.  

WHERE CURRENT OF permite actualizar la fila que está siendo procesada por el 
cursor, evitando tener que volver a localizarla mediante otra condición. Además, 
antes de actualizar se verifica el precio mínimo permitido, calculado a partir del 
costo del producto y el margen mínimo establecido para su categoría. De esta manera, 
el procedimiento no solamente modifica precios, sino que también respeta una regla 
de negocio: el precio no debe quedar por debajo del costo más el margen mínimo. La 
relación entre producto y categoría, así como el campo margen_minimo, están definidos 
en PRODUCTO y CATEGORIA. 
*/
DECLARE

    CURSOR c_productos (p_id_categoria CATEGORIA.id_categoria%TYPE) IS
        SELECT p.id_producto, p.precio_unitario, p.costo_unitario, c.margen_minimo
        FROM PRODUCTO p JOIN CATEGORIA c 
        ON c.id_categoria = p.id_categoria
        WHERE p.id_categoria = p_id_categoria AND p.activo = 'S'
        FOR UPDATE OF p.precio_unitario;

    vpNuevoPrecio PRODUCTO.precio_unitario%TYPE;
    vnPorcentaje NUMBER := 10;

BEGIN

    FOR r IN c_productos(1) LOOP vpNuevoPrecio := r.precio_unitario * (1 + vnPorcentaje / 100);
        IF vpNuevoPrecio < r.costo_unitario * (1 + r.margen_minimo / 100) THEN
            vpNuevoPrecio := r.costo_unitario * (1 + r.margen_minimo / 100);
        END IF;
        UPDATE PRODUCTO SET precio_unitario = vpNuevoPrecio WHERE CURRENT OF c_productos;
    END LOOP;

END;
/
--Pruebas
SELECT id_producto, precio_unitario FROM PRODUCTO WHERE id_categoria = 1 ORDER BY id_producto;
SELECT id_producto, precio_anterior, precio_nuevo, variacion_pct
FROM   AUDITORIA_PRECIO ORDER BY id_auditoria;
ROLLBACK;
/
------------------------------------------------------------------- 3.4 (2 pts)
-- SP_LISTAR_MOVIMIENTOS
-- Procedimiento que reciba un identificador de producto y devuelva un
-- SYS_REFCURSOR con los movimientos de inventario de ese producto, ordenados
-- por fecha. Incluya un bloque anonimo que consuma el cursor devuelto y lo cierre.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Usamos SYS_REFCURSOR para abrir la consulta en el procedimiento y pasar la 
-- referencia sin cargar todos los registros en la memoria en bloque consumidor
-- se hace la extraccion de datos.
-- El bloque consumidor evalua %NOTFOUND despues del FETCH y es quien ejecuta 
-- el CLOSE, ya que quien consume el cursor es el que debe liberar la memoria.

CREATE OR REPLACE PROCEDURE SP_LISTAR_MOVIMIENTOS (
    p_id_producto IN  NUMBER,
    p_cursor      OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR
        SELECT id_movimiento, 
               tipo, 
               cantidad, 
               fecha_mov, 
               observacion
        FROM   MOVIMIENTO_INVENTARIO
        WHERE  id_producto = p_id_producto
        ORDER  BY fecha_mov;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en SP_LISTAR_MOVIMIENTOS: ' || SQLERRM);
        RAISE;
END SP_LISTAR_MOVIMIENTOS;
/

-- Bloque consumidor:
DECLARE
    v_cursor      SYS_REFCURSOR;
    
    vn_id_mov     MOVIMIENTO_INVENTARIO.id_movimiento%TYPE;
    vn_tipo        MOVIMIENTO_INVENTARIO.tipo%TYPE;
    vn_cantidad    MOVIMIENTO_INVENTARIO.cantidad%TYPE;
    vd_fecha       MOVIMIENTO_INVENTARIO.fecha_mov%TYPE;
    vv_observacion MOVIMIENTO_INVENTARIO.observacion%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Movimientos del producto:');
    SP_LISTAR_MOVIMIENTOS(1001, v_cursor);
    
    LOOP
        FETCH v_cursor INTO vn_id_mov, vn_tipo, vn_cantidad, vd_fecha, vv_observacion;
        EXIT WHEN v_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE('ID Mov: ' || vn_id_mov || 
                             ' | Fecha: ' || TO_CHAR(vd_fecha, 'YYYY-MM-DD') || 
                             ' | Tipo: ' || vn_tipo || 
                             ' | Cantidad: ' || vn_cantidad || 
                             ' | Obs: ' || vv_observacion);
    END LOOP;
    
    CLOSE v_cursor;
END;

------------------------------------------------------------------- 3.5 (1 pt)
-- Bloque anonimo que cargue con BULK COLLECT los productos de una categoria en
-- una coleccion y use FORALL para actualizar su stock minimo.
-- Explique que costo concreto elimina esta tecnica y a partir de que volumen
-- empieza a notarse.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
BULK COLLECT permite traer múltiples filas desde SQL hacia una colección PL/SQL 
en una sola operación.  
FORALL permite ejecutar el mismo DML para todos los elementos de la colección en bloque.  
La técnica reduce el intercambio entre el motor SQL y el motor PL/SQL (context 
switches), evitando ejecutar un UPDATE individual desde un LOOP para cada producto 
y mejorando el rendimiento cuando se procesan muchas filas. 
*/
DECLARE

    TYPE t_productos IS TABLE OF PRODUCTO.id_producto%TYPE;
    vtProductos t_productos;
    vcIdCategoria CATEGORIA.id_categoria%TYPE := 1;

BEGIN

    SELECT id_producto
    BULK COLLECT INTO vtProductos
    FROM PRODUCTO
    WHERE id_categoria = vcIdCategoria AND activo = 'S';

    FORALL i IN 1 .. vtProductos.COUNT
        UPDATE PRODUCTO SET stock_minimo = stock_minimo + 5 WHERE id_producto = vtProductos(i);

END;
/
--Pruebas:
SELECT id_producto, activo, stock_minimo
FROM   PRODUCTO WHERE id_categoria = 1 ORDER BY id_producto;
-- Ejecutar bloque anónimo
SELECT id_producto, stock_minimo FROM PRODUCTO WHERE id_categoria = 1 ORDER BY id_producto;
ROLLBACK;
/

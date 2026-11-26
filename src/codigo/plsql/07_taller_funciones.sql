--==============================================================================
-- PARTE 2 — FUNCIONES                                         (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 2.1 (2 pts)
-- FN_STOCK_DISPONIBLE
-- Retorna la cantidad disponible de un producto. Si se indica bodega, devuelve
-- el saldo de esa bodega; si p_id_bodega llega nulo, el consolidado de todas.
-- Un producto inexistente debe retornar cero y no una excepcion.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Usamos NVL(SUM(cantidad), 0) porque SUM da NULL cuando no hay filas y asi un
-- producto que no existe retorna 0 sin necesidad de excepciones.
-- Separamos los dos casos con un IF porque comparar id_bodega = NULL nunca 
-- es verdadero y devolveria 0 en vez de tomar todas las bodegas
-- La funcion solo lee datos entonces tambien puede usarse
-- dentro de una sentencia SELECT.
CREATE OR REPLACE FUNCTION FN_STOCK_DISPONIBLE (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER DEFAULT NULL
) RETURN NUMBER IS
vn_stock NUMBER;
BEGIN
    --Si no hay bodega,se miran todas
     IF p_id_bodega IS NULL THEN
     --Si no hay producto, se retorna 0
        SELECT NVL(SUM(cantidad), 0)
        INTO   vn_stock
        FROM   EXISTENCIA
        WHERE  id_producto = p_id_producto;
    ELSE
    --Si hay bodega, se mira solo esa
        SELECT NVL(SUM(cantidad), 0)
        INTO   vn_stock
        FROM   EXISTENCIA
        WHERE  id_producto = p_id_producto
        AND    id_bodega   = p_id_bodega;
    END IF;
    RETURN vn_stock;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en FN_STOCK_DISPONIBLE: ' || SQLERRM);
        RAISE;
END FN_STOCK_DISPONIBLE;
/
--Prueba
SELECT * from EXISTENCIA where id_producto = 1001;

SELECT FN_STOCK_DISPONIBLE(1001,1) as pruebaConbodega1,
FN_STOCK_DISPONIBLE(1001,2) as pruebaConbodega2,
FN_STOCK_DISPONIBLE(1001) as pruebaSinbodega
from dual;
/
------------------------------------------------------------------- 2.2 (2 pts)
-- FN_CUPO_DISPONIBLE
-- Retorna el cupo de credito disponible del cliente, entendido como cupo menos
-- saldo pendiente. Un cliente inactivo retorna cero y el resultado nunca puede
-- ser negativo.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*¿Que hace? La funcion recibe como parametro el id del cliente y retorna su cupo
de credito disponible. Consulta el estado del cliente, su cupo de credito y su
saldo pendiente. Si el cliente esta inactivo retorna 0; si esta activo retorna
la resta entre el cupo de credito y el saldo pendiente. Se usa GREATEST(valor, 0)
para que el resultado nunca sea negativo (por ejemplo, cuando el cupo esta agotado),
y si el cliente no existe se captura NO_DATA_FOUND y tambien se retorna 0.
¿Por que? Se utiliza una funcion porque solo se necesita calcular y devolver un
unico valor numerico, sin modificar ninguna tabla. Al no tener efectos secundarios,
puede reutilizarse en otras reglas de negocio (como la creacion de pedidos) y
llamarse directamente desde una sentencia SELECT, como se hace en el punto 2.4.
*/


CREATE OR REPLACE FUNCTION FN_CUPO_DISPONIBLE (
    p_id_cliente IN NUMBER
) RETURN NUMBER IS
    vc_activo CHAR(1) := 'N';
    vn_cupo NUMBER := 0;
    
BEGIN
    SELECT activo, cupo_credito - saldo_pendiente
    INTO vc_activo, vn_cupo
    FROM CLIENTE WHERE id_cliente = p_id_cliente;
    
    IF vc_activo = 'N' THEN 
        RETURN 0;
    END IF;
    
    RETURN GREATEST(vn_cupo, 0);

EXCEPTION
    
    WHEN NO_DATA_FOUND THEN 
        return 0;
    
END FN_CUPO_DISPONIBLE;
/

-- PRUEBA 2.2

BEGIN
    FOR i IN 501..507 LOOP
        dbms_output.put_line('Cliente ' || i || ' | Cupo disponible: ' || FN_CUPO_DISPONIBLE(i));
    END LOOP;
   
END;
/
------------------------------------------------------------------- 2.3 (3 pts)
-- FN_CALCULAR_DESCUENTO
-- Retorna el VALOR en pesos del descuento aplicable, segun estas reglas
-- acumulables:
--     Monto mayor o igual a 2.000.000 ................. 8%
--     Monto entre 800.000 y 1.999.999 ................. 5%
--     Monto menor a 800.000 ........................... 0%
--     Adicional si el cliente no tiene saldo pendiente . 2%
--     Tope maximo acumulado ........................... 10%
-- La funcion retorna el valor del descuento, no el porcentaje.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
La función permite encapsular en un único lugar las reglas de negocio utilizadas 
para calcular el descuento de un cliente. Se determina inicialmente el porcentaje 
según el monto de la compra y posteriormente se adiciona el beneficio correspondiente 
a los clientes que no tienen saldo pendiente. El límite del 10 % evita que la suma de 
beneficios supere el máximo establecido.  La función retorna el valor monetario 
del descuento por lo que el resultado puede utilizarse directamente en cálculos 
de facturación o pedidos. 
*/
CREATE OR REPLACE FUNCTION FN_CALCULAR_DESCUENTO (
    p_id_cliente IN NUMBER,
    p_monto      IN NUMBER
) RETURN NUMBER 
IS

    vnPorcentaje NUMBER;
    vnDescuento  NUMBER;
    vcSaldo      CLIENTE.saldo_pendiente%TYPE;

BEGIN
    SELECT saldo_pendiente INTO vcSaldo FROM CLIENTE WHERE id_cliente = p_id_cliente;

    IF p_monto >= 2000000 THEN vnPorcentaje := 8;
    ELSIF p_monto BETWEEN 800000 AND 1999999 THEN vnPorcentaje := 5;
    ELSE vnPorcentaje := 0;
    END IF;

    IF vcSaldo = 0 THEN vnPorcentaje := vnPorcentaje + 2;
    END IF;

    IF vnPorcentaje > 10 THEN vnPorcentaje := 10;
    END IF;

    vnDescuento := p_monto * vnPorcentaje / 100;

    RETURN vnDescuento;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20005, 'El cliente no existe');
    
END FN_CALCULAR_DESCUENTO;
/
--Pruebas
SELECT 'Cli 501 |       500.000 -> 0'            AS caso, FN_CALCULAR_DESCUENTO(501,  500000) AS valor FROM dual UNION ALL
SELECT 'Cli 501 |       800.000 -> 40.000 (5%)'  , FN_CALCULAR_DESCUENTO(501,  800000) FROM dual UNION ALL
SELECT 'Cli 501 |     2.000.000 -> 160.000 (8%)' , FN_CALCULAR_DESCUENTO(501, 2000000) FROM dual UNION ALL
SELECT 'Cli 503 |       500.000 -> 10.000 (0+2%)', FN_CALCULAR_DESCUENTO(503,  500000) FROM dual UNION ALL
SELECT 'Cli 503 |       800.000 -> 56.000 (5+2%)', FN_CALCULAR_DESCUENTO(503,  800000) FROM dual UNION ALL
SELECT 'Cli 503 |     2.000.000 -> 200.000 (10%)', FN_CALCULAR_DESCUENTO(503, 2000000) FROM dual UNION ALL
SELECT 'Cli 501 | 1.999.999,50 -> 99.999,98 (5%)', FN_CALCULAR_DESCUENTO(501, 1999999.5) FROM dual;
/


------------------------------------------------------------------- 2.4 (1 pt)
-- Escriba una consulta que liste los clientes activos con su cupo disponible,
-- usando la funcion del punto 2.2, ordenados de mayor a menor.
-- Explique por que una funcion definida por el usuario puede invocarse desde
-- una sentencia SQL y que restriccion debe cumplir para poder hacerlo.
-------------------------------------------------------------------------------
-- RESPUESTA:
/*
Una función puede invocarse desde SQL porque retorna un valor que puede utilizarse
como una expresión dentro de una sentencia SQL. Para poder invocarse desde SQL, 
la función debe tener un tipo de retorno compatible con SQL y cumplir las restricciones
de las funciones que se ejecutan desde SQL, como por ejemplo, no debe realizar 
operaciones DML no permitidas sobre las tablas involucradas en la sentencia.
*/

SELECT
    id_cliente,
    nombre,
    FN_CUPO_DISPONIBLE(id_cliente) AS cupo_disponible
FROM CLIENTE
WHERE activo = 'S'
ORDER BY cupo_disponible DESC;
/

--Evidencia en el pdf

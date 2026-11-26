--==============================================================================
-- PARTE 6 — CASO INTEGRADOR                                   (5 puntos / 45 min)
--==============================================================================

-------------------------------------------------------------------------------
-- PKG_VENTAS
-- Construya un PAQUETE que exponga el procedimiento SP_FACTURAR_PEDIDO, el cual,
-- para un pedido en estado BORRADOR, debe:
--
--   1. Validar que el pedido exista y este en BORRADOR
--   2. Recorrer sus lineas con un cursor y acumular el subtotal
--   3. Calcular el descuento con FN_CALCULAR_DESCUENTO
--   4. Validar contra FN_CUPO_DISPONIBLE que el cliente tenga cupo suficiente
--   5. Actualizar el total del pedido y cambiar su estado a CONFIRMADO
--   6. Incrementar el saldo pendiente del cliente
--   7. Usar SAVEPOINT y revertir parcialmente ante cualquier fallo, registrando
--      el error con SP_REGISTRAR_ERROR
--   8. Devolver por parametros OUT el total facturado y el descuento aplicado
--
-- Firma esperada:
--   PKG_VENTAS.SP_FACTURAR_PEDIDO(p_id_pedido IN NUMBER,
--                                 p_total     OUT NUMBER,
--                                 p_descuento OUT NUMBER)
--
-- Se evalua la integracion. El procedimiento debe apoyarse en los objetos de las
-- partes 1 a 5 y no reimplementar su logica: uno que vuelva a codificar el
-- calculo del descuento pierde la mitad del puntaje de esta parte.
-- Defina explicitamente el alcance transaccional y justifique donde decidio
-- ubicar la confirmacion de la transaccion.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
Se construyó un paquete porque el enunciado pide exponer un único punto de entrada
(SP_FACTURAR_PEDIDO) y encapsular la lógica de facturación: la especificación publica 
solo la firma y el cuerpo oculta el cursor y las variables, de modo que nadie puede 
facturar saltándose las validaciones. El procedimiento no vuelve a hacer las reglas
de las partes anteriores, sino que se apoya en ellas: el descuento lo calcula 
FN_CALCULAR_DESCUENTO, el cupo lo valida FN_CUPO_DISPONIBLE y los errores se 
registran con SP_REGISTRAR_ERROR.  

Además, el stock y el total de cabecera ya fueron manejados por TRG_DETALLE_AI_STOCK 
y TRG_DETALLE_TOTAL cuando se insertaron las líneas, por eso aquí no se toca el inventario. 
El pedido se lee con FOR UPDATE para que dos sesiones no lo facturen a la vez y se bloquea 
también la fila del cliente antes de validar el cupo, porque sin ese bloqueo dos pedidos
del mismo cliente facturados en paralelo podrían pasar la validación con el mismo 
saldo y exceder el crédito, además de que los bloqueos se toman siempre en el mismo
orden (pedido y luego cliente) para evitar interbloqueos. Las líneas se recorren
con un cursor parametrizado porque el enunciado lo exige y porque permite acumular 
el subtotal en un solo recorrido, donde un pedido sin líneas se rechaza, ya que no
hay nada que facturar. El total facturado que se guarda en PEDIDO y se devuelve
por p_total es el neto (subtotal menos descuento), y ese mismo valor es el que 
se suma al saldo pendiente del cliente, de modo que lo que se factura, lo que queda
registrado y lo que se adeuda coinciden. El alcance transaccional es todo lo que 
ocurre entre el SAVEPOINT sp_facturar, que es la primera instrucción del procedimiento, y
su final: la actualización de PEDIDO y de CLIENTE forman una sola unidad, de manera 
que ante cualquier fallo el manejador registra el error, revierte únicamente hasta 
el savepoint y relanza la excepción con RAISE, dejando intacto lo que el llamador
hubiera hecho antes de invocarlo y permitiéndole saber que la factura no se generó. 
El registro del error se ejecuta antes del ROLLBACK TO SAVEPOINT porque SQLCODE y
SQLERRM deben seguir vigentes, y sobrevive a la reversión porque SP_REGISTRAR_ERROR 
es una transacción autónoma. La confirmación no se ubicó dentro del paquete sino en 
quien lo llama: facturar es un paso de un proceso de venta más grande (crear el pedido,
insertar líneas que descuentan stock, facturar), y si el procedimiento hiciera COMMIT
dejaría permanentes esos pasos previos, aunque el llamador necesitara deshacerlos
después, además de volverlo imposible de componer con otras operaciones. El único 
COMMIT que existe es el interno de SP_REGISTRAR_ERROR, que solo confirma el log. 
Los errores propios son -20401 (pedido inexistente), -20402 (pedido que no está 
en BORRADOR), -20403 (pedido sin líneas) y -20404 (cupo insuficiente), todos distinguibles
entre sí. Finalmente, el recorrido del cursor es lineal respecto al número de líneas 
y los bloqueos duran hasta que el llamador confirme o revierta, por lo que conviene
que esa decisión se tome de inmediato después de facturar. 
*/

CREATE OR REPLACE PACKAGE PKG_VENTAS IS
    PROCEDURE SP_FACTURAR_PEDIDO (p_id_pedido IN  NUMBER, p_total OUT NUMBER, p_descuento OUT NUMBER);
END PKG_VENTAS;
/

CREATE OR REPLACE PACKAGE BODY PKG_VENTAS IS

    PROCEDURE SP_FACTURAR_PEDIDO (p_id_pedido IN  NUMBER, p_total OUT NUMBER, p_descuento OUT NUMBER
    ) IS
        CURSOR c_lineas (p_pedido PEDIDO.id_pedido%TYPE) IS
            SELECT linea, subtotal FROM   DETALLE_PEDIDO
            WHERE  id_pedido = p_pedido
            ORDER  BY linea;

        vpIdCliente PEDIDO.id_cliente%TYPE;
        vpEstado     PEDIDO.estado%TYPE;
        vcSaldo      CLIENTE.saldo_pendiente%TYPE;
        vnSubtotal   NUMBER := 0;
        vnLineas     PLS_INTEGER := 0;
        vnDescuento  NUMBER;
        vnNeto       NUMBER;
        vnCupo       NUMBER;
    BEGIN
        SAVEPOINT sp_facturar;

        BEGIN
            SELECT id_cliente, estado
            INTO   vpIdCliente, vpEstado
            FROM   PEDIDO
            WHERE  id_pedido = p_id_pedido
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20401, 'El pedido ' || p_id_pedido || ' no existe');
        END;

        IF vpEstado <> 'BORRADOR' THEN RAISE_APPLICATION_ERROR(-20402,
                'El pedido ' || p_id_pedido || ' esta en estado ' || vpEstado ||
                ' y solo se factura un pedido en BORRADOR');
        END IF;

        FOR r IN c_lineas(p_id_pedido) LOOP
            vnSubtotal := vnSubtotal + r.subtotal;
            vnLineas   := vnLineas + 1;
        END LOOP;

        IF vnLineas = 0 THEN
            RAISE_APPLICATION_ERROR(-20403, 'El pedido ' || p_id_pedido || ' no tiene lineas');
        END IF;

        SELECT saldo_pendiente INTO   vcSaldo
        FROM   CLIENTE
        WHERE  id_cliente = vpIdCliente
        FOR UPDATE;

        vnDescuento := FN_CALCULAR_DESCUENTO(vpIdCliente, vnSubtotal);
        vnNeto      := vnSubtotal - vnDescuento;
        vnCupo      := FN_CUPO_DISPONIBLE(vpIdCliente);

        IF vnNeto > vnCupo THEN RAISE_APPLICATION_ERROR(-20404,
                'Cupo insuficiente: el total a facturar ' || vnNeto ||
                ' supera el cupo disponible ' || vnCupo);
        END IF;

        UPDATE PEDIDO SET    total  = vnNeto, estado = 'CONFIRMADO'
        WHERE  id_pedido = p_id_pedido;

        UPDATE CLIENTE
        SET    saldo_pendiente = saldo_pendiente + vnNeto
        WHERE  id_cliente = vpIdCliente;

        p_total     := vnNeto;
        p_descuento := vnDescuento;
    EXCEPTION
        WHEN OTHERS THEN
            SP_REGISTRAR_ERROR('PKG_VENTAS.SP_FACTURAR_PEDIDO pedido=' || p_id_pedido);
            ROLLBACK TO SAVEPOINT sp_facturar;
            p_total     := NULL;
            p_descuento := NULL;
            RAISE;
    END SP_FACTURAR_PEDIDO;

END PKG_VENTAS;
/

--Pruebas:
DECLARE
    vpPed    PEDIDO.id_pedido%TYPE;
    vnTotal  NUMBER;
    vnDesc   NUMBER;
    vpEstado PEDIDO.estado%TYPE;
BEGIN
    SP_CREAR_PEDIDO(503, vpPed);
    INSERT INTO DETALLE_PEDIDO VALUES (vpPed, 1, 1002, 1, 2, 62000, 124000);
    INSERT INTO DETALLE_PEDIDO VALUES (vpPed, 2, 1001, 1, 10, 45000, 450000);
    PKG_VENTAS.SP_FACTURAR_PEDIDO(vpPed, vnTotal, vnDesc);
    DBMS_OUTPUT.PUT_LINE('Pedido ' || vpPed || ' facturado. Total: ' || vnTotal || ' | Descuento: ' || vnDesc);
    DBMS_OUTPUT.PUT_LINE('Cupo disponible cliente 503: ' || FN_CUPO_DISPONIBLE(503));

    BEGIN
        PKG_VENTAS.SP_FACTURAR_PEDIDO(vpPed, vnTotal, vnDesc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Refacturar el mismo pedido: ' || SQLERRM);
    END;

    SP_CREAR_PEDIDO(502, vpPed);
    INSERT INTO DETALLE_PEDIDO VALUES (vpPed, 1, 1004, 1, 2, 320000, 640000);
    BEGIN
        PKG_VENTAS.SP_FACTURAR_PEDIDO(vpPed, vnTotal, vnDesc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Cliente 502: ' || SQLERRM);
    END;
    SELECT estado INTO vpEstado FROM PEDIDO WHERE id_pedido = vpPed;
    DBMS_OUTPUT.PUT_LINE('Estado del pedido tras el fallo: ' || vpEstado);

    BEGIN
        PKG_VENTAS.SP_FACTURAR_PEDIDO(9999, vnTotal, vnDesc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Pedido inexistente: ' || SQLERRM);
    END;

    BEGIN
        PKG_VENTAS.SP_FACTURAR_PEDIDO(1, vnTotal, vnDesc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Pedido ya confirmado: ' || SQLERRM);
    END;

    ROLLBACK;
END;
/

SELECT id_log, origen, codigo_error, SUBSTR(mensaje, 1, 80) AS mensaje
FROM   LOG_ERRORES
ORDER  BY id_log;

--==============================================================================
-- FIN DE LA PLANTILLA
--==============================================================================

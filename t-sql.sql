--TRIGGER
--for:se disparan despues de una accion (poniendo for por defecto es after)
--instead of: se disparan antes de una accion, antes de q ocurra un cambio en las tablas, cancela el resto de las acciones

/* Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto que se debe almacenar en el deposito y
 que el stock maximo es la maxima cantidad de ese producto en ese deposito, cree el/los objetos de base de datos necesarios
 para que dicha regla de negocio se cumpla automaticamente. No se conoce la forma de acceso a los datos ni el procedimiento
  por el cual se incrementa o descuenta stock*/



create trigger controlador_stock on STOCK instead of update
as begin
    declare @producto1 char(8), @deposito1 char(2), @cantidad1 decimal(12,2),
            @minimo1 decimal(12,2), @maximo1 decimal(12,2)

    declare c1 cursor for select stoc_producto, stoc_deposito, stoc_cantidad, stoc_punto_reposicion, stoc_stock_maximo
                          from inserted

    open c1
    fetch next from c1 into @producto1, @deposito1, @cantidad1, @minimo1, @maximo1
    while @@FETCH_STATUS = 0
    begin
        if(@cantidad1 >= @minimo1 and @cantidad1 <= @maximo1)
            update STOCK
            set stoc_cantidad = @cantidad1
            where stoc_producto = @producto1 and stoc_deposito = @deposito1
        else
        begin
            if(@cantidad1 < @minimo1)
                PRINT 'NO SE ALTERO EL STOCK: YA HA ALCANZADO EL MINIMO'
            else
                PRINT 'NO SE ALTERO EL STOCK: YA HA ALCANZADO EL MAXIMO'
        end
        fetch next from c1 into @producto1, @deposito1, @cantidad1, @minimo1, @maximo1
    end
    close c1
    deallocate c1

end


/*Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente regla de negocio automáticamente
 “Ningún jefe puede tener menos de 5 años de antigüedad y tampoco puede tener más del 50% del personal a su cargo
  (contando directos e indirectos) a excepción del gerente general”. 
  Se sabe que en la actualidad la regla se cumple y existe un único gerente general.*/


------------PUNTO 2---------------
create trigger restriccionJefes on dbo.Empleado
for insert, update
as begin transaction
    
    declare miCursor cursor for (select empl_codigo, empl_ingreso, empl_jefe from inserted)
    
    declare @cod_nuevo_empleado numeric(6,0)
    declare @fecha_ingreso smalldatetime
    declare @antiguedad int
    declare @jefe_nuevo_empleado numeric(6,0)
    declare @empleadosTotales int
    declare @empleadosACargo int

    
    set @empleadosTotales = (select count(*) from dbo.Empleado)


    OPEN miCursor
        fetch next from miCursor into @cod_nuevo_empleado, @fecha_ingreso, @jefe_nuevo_empleado

        WHILE(@@FETCH_STATUS = 0)
            begin
                set @antiguedad = YEAR(@fecha_ingreso)
                set @empleadosACargo = (select Count(*) from dbo.Empleado e where loTieneACargo(@cod_nuevo_empleado, e.empl_codigo) = 1)

                if (@empleadosACargo > 0)
                    begin
                        if (@antiguedad < 5)
                            begin 
                                raiserror('Un jefe no puede tener menos de 5 años de antiguedad',16,1)
                                rollback transaction
                            end
                        if (@empleadosACargo * 100 / @empleadosTotales > 50)
                            begin
                                if(@jefe_nuevo_empleado is not null)
                                    begin
                                    raiserror('Un jefe no puede tener mas del 50% del personal a su cargo', 16,1)
                                    rollback transaction
                                end
                            end
                    end
            end

    CLOSE miCursor
    DEALLOCATE miCursor
commit transaction
go



Create function loTieneACargo(@cod_jefe numeric(6,0), @cod_empleado numeric(6,0))
returns bit(1)
as begin
    Declare @jefe numeric(6,0)
    Set @jefe = (Select empl_jefe From dbo.Empleado e where e.empl_codigo= @cod_empleado)
    if (@jefe = @cod_jefe)
        begin
            return 1
        end
    else if(@jefe is null)
        begin
            return 0
        end
    else
        begin
            return loTieneACargo(@cod_jefe, @jefe)
        end
    end
go

-- recuperatorio 28/06/2016
/* 
En virtud de una recategorizacion de productos referida a la familia de los mismos se solicita que desarrolle una consulta sql
que retorne para todos los productos: 
1- Codigo de producto
2- Detalle del producto 
3- Codigo de la familia del producto 
4- Detalle de la familia actual del producto
5- Codigo de la familia sugerido para el producto 
6- Detalla de la familia sugerido para el producto 
 
La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo detalle coinciden en los primeros 5 caracteres.
En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor codigo.
Solo se deben mostrar los productos para los cuales la familia actual sea diferente a la sugerida
Los resultados deben ser ordenados por detalle de producto de manera ascendente 
*/

SELECT P.prod_codigo AS codProducto, P.prod_detalle AS detalleProducto, 
    F.fami_id AS codFamiliaActualProducto, F.fami_detalle AS detalleFamiliaActualProducto,
    F2.fami_id AS codFamiliaSugeridaProducto, F2.fami_detalle AS detalleFamiliaSugeridaProducto
FROM Producto P
inner join Familia F on F.fami_id = P.prod_familia ,
Familia F2
where F2.fami_id = (SELECT TOP 1 Fam.fami_id
                    FROM Producto Prod
                    inner join Familia Fam on Fam.fami_id = Prod.prod_familia
                    WHERE SUBSTRING(Prod.prod_detalle, 1, 5) = SUBSTRING(P.prod_detalle, 1, 5)
                    GROUP BY Fam.fami_id 
                    ORDER BY Count(DISTINCT Prod.prod_codigo) DESC, Fam.fami_id ASC)
AND P.prod_familia != F2.fami_id
ORDER BY P.prod_detalle ASC


/*
. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al menos una factura,
la cantidad de clientes a los que se les facturo de manera incorrecta al menos una factura y 
que cantidad de facturas se realizaron de manera incorrecta.
Se considera que una factura es incorrecta cuando la diferencia
entre el total de la factura menos el total de impuesto tiene una diferencia mayor
a $ 1 respecto a la sumatoria de los costos de cada uno de los items de dicha factura
. Las columnas que se deben mostrar son: 
1- Año
2- Clientes a los que se les facturo mal en ese año
3- Facturas mal realizadas en ese año 
*/

select YEAR(f1.fact_fecha) as Año, COUNT(DISTINCT f1.fact_cliente), COUNT(*)
from Factura f1
   WHERE ((f1.fact_total - f1.fact_total_impuestos) - ( select SUM(item_precio * item_cantidad) from Item_Factura
     where item_tipo=f1.fact_tipo and item_sucursal=f1.fact_sucursal and item_numero=f1.fact_numero) > 1 )
group by YEAR(f1.fact_fecha)
HAVING COUNT(DISTINCT f1.fact_fecha) >= 1

--TRIGGER
--for:se disparan despues de una accion (poniendo for por defecto es after)
--instead of: se disparan antes de una accion, antes de q ocurra un cambio en las tablas, cancela el resto de las acciones

--en las tablas inserted y deleted, los campos q no se updetean estan los mismos,OSEA NO ESTAN EN NULL


/*Implementar el/los objetos necesarios para que no se pueda realizar una factura si el precio de venta de algún artículo
 (ítem_precio) es distinto al precio que se encuentra en la tabla Producto (prod_precio)..*/


create trigger controlador_precio_de_venta on Item_factura instead of insert
as begin
    declare @item_tipo char(1), @item_sucursal char(4), @item_numero char(8)

    declare miCursor cursor
    for select i.item_tipo, i.item_sucursal, i.item_numero
       from inserted i


    if not EXISTS (select item_tipo, item_sucursal, item_numero, item_producto, item_cantidad,item_precio
               from inserted
               where item_precio <>( select prod_precio
                                   from dbo.Producto
                                   where prod_codigo = item_producto)
               ) 
    begin
         insert into Item_Factura
            select item_tipo, item_sucursal, item_numero, item_producto, item_cantidad,item_precio
               from inserted
    end
    else
    begin
         open miCursor
         fetch next from miCursor into @item_tipo, @item_sucursal, @item_numero
         while @@FETCH_STATUS = 0
         begin
             delete factura
                where fact_tipo=@item_tipo and fact_sucursal=@item_sucursal and fact_numero=@item_numero
            fetch next from miCursor into @item_tipo, @item_sucursal, @item_numero
         end
    end

    deallocate miCursor
    close miCursor

end

/* Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto que se debe almacenar en el deposito y
 que el stock maximo es la maxima cantidad de ese producto en ese deposito, cree el/los objetos de base de datos necesarios
 para que dicha regla de negocio se cumpla automaticamente. No se conoce la forma de acceso a los datos ni el procedimiento
  por el cual se incrementa o descuenta stock*/

--echo por reinosa
create trigger controlador_stock on STOCK instead of update
as begin
    declare @producto1 char(8), @deposito1 char(2), @cantidad1 decimal(12,2),
            @minimo1 decimal(12,2), @maximo1 decimal(12,2)

    declare miCursor cursor for select stoc_producto, stoc_deposito, stoc_cantidad, stoc_punto_reposicion, stoc_stock_maximo
                          from inserted

    open miCursor
    fetch next from miCursor into @producto1, @deposito1, @cantidad1, @minimo1, @maximo1
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
        fetch next from miCursor into @producto1, @deposito1, @cantidad1, @minimo1, @maximo1
    end
    close miCursor
    deallocate miCursor

end

------------PUNTO 2---------------
/*Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente regla de negocio automáticamente
 “Ningún jefe puede tener menos de 5 años de antigüedad y tampoco puede tener más del 50% del personal a su cargo
  (contando directos e indirectos) a excepción del gerente general”. 
  Se sabe que en la actualidad la regla se cumple y existe un único gerente general.*/


create trigger tr_controlar_jefes on dbo.Empleado
for insert, update
as begin

BEGIN TRANSACTION  
BEGIN TRY
    
    declare miCursor cursor for (select empl_jefe from inserted)
    
    declare @antiguedad int
    declare @jefe_del_nuevo_empleado numeric(6,0)
    declare @empleadosTotales int
    declare @cantEmpleadosACargo int
    declare @gerenteGeneral int

    
    set @empleadosTotales = (select count(*) from dbo.Empleado)
    select @gerenteGeneral =empl_codigo
     from dbo.Empleado
     where empl_jefe is null


    OPEN miCursor
        fetch next from miCursor into @jefe_del_nuevo_empleado

        WHILE(@@FETCH_STATUS = 0)
        begin

                if (@jefe_del_nuevo_empleado <> @gerenteGeneral)
                    begin

                        set @antiguedad = (select YEAR(empl_ingreso)
                                            from dbo.Empleado
                                            where empl_codigo = @jefe_del_nuevo_empleado
                                           )

                        if (@antiguedad < 5)
                            begin 
                                raiserror('ERROR:Un jefe no puede tener menos de 5 años de antiguedad',16,1)
                            end


                        set @cantEmpleadosACargo =(select Count(*)
                                                    from dbo.Empleado  
                                                    where dbo.loTieneACargo(@jefe_del_nuevo_empleado, empl_codigo) = 1
                                                   )


                        if ( (@cantEmpleadosACargo * 100 / @empleadosTotales) > 50)
                            begin
                                 raiserror('ERROR:Un jefe no puede tener mas del 50% del personal a su cargo', 16,1)
                            end
                            
                    end

             fetch next from miCursor into @jefe_del_nuevo_empleado
        end

    CLOSE miCursor
    DEALLOCATE miCursor

COMMIT TRAN  
END TRY

BEGIN CATCH  
ROLLBACK TRAN     
print(ERROR_MESSAGE()) 
END CATCH 

end




go

-- la funcion devuelve un 1 si lo tiene a cargo o un cero si no lo tiene
create function loTieneACargo(@jefe_supremo numeric(6,0), @cod_empleado numeric(6,0))
returns bit
as begin
    Declare @jefe numeric(6,0), @bool bit

    set @jefe = (select empl_jefe from dbo.Empleado  where empl_codigo= @cod_empleado)

    if (@jefe = @jefe_supremo)
        begin
            SET @bool=1
        end
    else if(@jefe is null)
        begin
            SET @bool=0
        end
    else
        begin
            SET @bool= dbo.loTieneACargo(@jefe_supremo, @jefe)
        end

    return @bool 
end
go

-- esto nose que es ?¿

create trigger tg_jefes_de_no_mas_de_10_empleados
on Empleado
after insert, delete
as
begin

    if exists(
        select 1 
        from Empleado as E
        group by 
            E.empl_jefe
        having 
            COUNT(*) >= 10 or COUNT(*) < 1)
    rollback
end

--2

/*
  12/11/16
1º parcial lacquaniti
Implementar el/los objetos necesarios para que cada vez que se decida incrementar la comision
de un empleado no se permita incrementar mas de un 5 % la comision de aquellos empleados
responsables de menos de 4 depositos

correccion lacquaniti
PL: No contempla la posibilidad que cambien otros atributos del cliente, por ejemplo, el nombre.
 Al hacer un trigger instead of, si no modifica los datos en el codigo no se hace.

*/
create trigger tr_controlar_aumento_en_comicion on dbo.Empleado instead of update
as begin

    declare miCursor cursor for (select empl_codigo, empl_comision from inserted)

    declare miCursor2 cursor for (select empl_comision from deleted)
    
    declare @comisionNueva decimal(12,2)
    declare @comisionVieja decimal(12,2)
    declare @empl_codigo numeric(6)
    declare @cantDepocitosAcargo numeric(6)


    OPEN miCursor
    OPEN miCursor2
        fetch next from miCursor into @empl_codigo, @comisionNueva
        fetch next from miCursor2 into @comisionVieja

        WHILE(@@FETCH_STATUS = 0)
        begin
         /* ACA HAY QUE UPDETEAR TODOS LOS CAMPOS (MENOS EL CAMPO "empl_comision")                                                     
*/                                                                   
                set @cantDepocitosAcargo = (select Count(*) from dbo.DEPOSITO  where depo_encargado=@empl_codigo)

                if ( ( (@comisionNueva-@comisionVieja) * 100 / @comisionVieja) > 5)
                    begin
                        if (@cantDepocitosAcargo > 4)
                            begin
                                update Empleado  SET empl_comision = @comisionNueva
                                where empl_codigo=@empl_codigo

                            end
                            
                    end
                fetch next from miCursor into @empl_codigo, @comisionNueva
                fetch next from miCursor2 into @comisionVieja    
        end

    CLOSE miCursor
    DEALLOCATE miCursor
    CLOSE miCursor2
    DEALLOCATE miCursor2


end


/*
correccion lacquaniti
PL: No contempla la posibilidad que cambien otros atributos del cliente, por ejemplo, el nombre.
 Al hacer un trigger instead of, si no modifica los datos en el codigo no se hace.
*/

--corregio el error
create trigger tr_controlar_aumento_en_comicion on dbo.Empleado
for insert, update
as begin

    begin transaction


    declare miCursor cursor for (select empl_codigo, empl_comision from inserted)

    declare miCursor2 cursor for (select empl_comision from deleted)
    
    declare @comisionNueva decimal(12,2)
    declare @comisionVieja decimal(12,2)
    declare @empl_codigo numeric(6)
    declare @cantDepocitosAcargo numeric(6)


    OPEN miCursor
    OPEN miCursor2
        fetch next from miCursor into @empl_codigo, @comisionNueva
        fetch next from miCursor2 into @comisionVieja

        WHILE(@@FETCH_STATUS = 0)
        begin
                set @cantDepocitosAcargo = (select Count(*) from dbo.DEPOSITO  where depo_encargado=@empl_codigo)

                if ( (@cantDepocitosAcargo < 4))
                    begin
                          if ( ( (@comisionNueva-@comisionVieja) * 100 / @comisionVieja) < 5)
                            begin
                                 rollback transaction
                            end
                    end

                fetch next from miCursor into @empl_codigo, @comisionNueva
                fetch next from miCursor2 into @comisionVieja    
        end

    CLOSE miCursor
    DEALLOCATE miCursor
    CLOSE miCursor2
    DEALLOCATE miCursor2
    

    commit transaction
end


/*
1º recuperatorio de lacquaniti
Implemente el/los objetos necesarios para obtener en una nueva tabla (FacturacionPorMes) los datos
correspondientes a los montos totales de ventas,actualizados a cada momento.
La tabla debe contener: mes,año,cantidad de facturas emitidas, monto total de ventas (incluir los impuetos) y
cliente q mas compro para ese mes y año.
*/

create trigger facturacion_por_mes on Factura instead of insert
as begin
    
   declare @fecha char(smalldatetime), @total char(12,2), @cliente char(6)

    declare miCursor cursor
    for select fact_fecha,fact_total,fact_cliente
       from inserted i

    open miCursor
    fetch next from miCursor into @fecha, @total, @cliente

    while @@FETCH_STATUS = 0
    begin

      pk = buscar_registro(@fecha)

      if(pk is null)
      begin
        insertar_registro()
      end
      else
      begin
       actualizar_registro(pk)
      end

    fetch next from miCursor into @fecha, @total, @cliente

    end

    deallocate miCursor
    close miCursor
end


/*
La tabla a completar es la siguiente:
1)Orden del ranking
2)codigo del cliente
3)nombre del cliente
4)cantidad de facturas compradas en el año corriente
5)precio promedio de la factura
6)"si" o "no" en funcion de que haya comprado productos con composicion o no
nombre del producto mas comprado por este cliente en el año corriente

Se debe considerar que los datos deben insertarse en orden de mayor a menor,o sea,
el cliente que mas compro en plata primero y el que menos compro en plata ultimo,
numerando en la columna posicion el orden que ocupa dentro del ranking.
*/

 CREATE FUNCTION comprobarCombo(@codCliente as char(6))
returns varchar(3)
as
BEGIN
DECLARE @rta as varchar(3), @cant as integer
 select @cant= count(*)     
    from factura f
    inner join Item_Factura i on f.fact_tipo=i.item_tipo and f.fact_sucursal=i.item_sucursal and f.fact_numero=i.item_numero
    inner join composicion c on i.item_producto = c.comp_producto
    where f.fact_cliente = @codCliente
if (@cant>0)
    SET @rta='SI'
ELSE
    SET @rta='NO'
return @rta
END


CREATE procedure generarRanking 
as
BEGIN
insert into raking
select  ROW_NUMBER() over (order by SUM(f1.fact_total) desc) as posicion,
c1.clie_codigo as cod_clie, 
SUM(f1.fact_total) as factTotal,
c1.clie_razon_social as nom_clie,
COUNT(f1.fact_numero) as cantidad,
SUM(f1.fact_total)/COUNT( f1.fact_numero) as pre_pro,
dbo.comprobarCombo (c1.clie_codigo) as poseeCombo,
(
select top 1 p2.prod_detalle
        from Factura f2
        inner join Item_Factura i2 on f2.fact_tipo=i2.item_tipo and f2.fact_sucursal=i2.item_sucursal and f2.fact_numero=i2.item_numero
        inner join Producto p2 on p2.prod_codigo = i2.item_producto
        where f2.fact_cliente=c1.clie_codigo
        group by p2.prod_detalle
        order by SUM(i2.item_cantidad) desc
        ) as nom_producto
from Cliente c1
inner join Factura f1 on c1.clie_codigo=f1.fact_cliente
group by c1.clie_codigo, c1.clie_razon_social


END

/*
ultimo recuperatorio de lacquaniti
Implementar el/los objetos necesarios para que dada una factura se retorne un entero que indique 1 (uno)
si esa factura tiene productos que podrian venderse como composicion o 0 (cero) en caso contrario.
Ejemplo: Si tenemos una composicion COMOBO1 (COMPOSICION.comp_composicion) y este esta compuesto por 1 gaseosa y 2 Hamburguesas (
COMPOSICION.comp_producto), una factura que vendio 4 hamburguesas, 1 gaseosa y 2 papas, se debera retornar 1.
*/
create function dbo.fn_se_puede_vender_como_coposicion(@tipo char(1), @sucursal char(4), @numero char(8))
returns bit
as begin
declare @tiene_compocicion bit

   set @tiene_compocicion = 0;

   if exists(
            select comp_producto 
            from Item_Factura 
            inner join Composicion C1 on (item_producto = C1.comp_componente)
            where item_cantidad >= C1.comp_cantidad and
                  item_sucursal = @sucursal and
                  item_numero = @numero and
                  item_tipo = @tipo
            group by C1.comp_producto
            having COUNT(*) = (select COUNT(*) from Composicion as C2 where C2.comp_producto= C1.comp_producto)
            )    
    begin
         set @tiene_compocicion = 1
    end

return @tiene_compocicion;

end



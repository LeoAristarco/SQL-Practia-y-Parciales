--TRIGGER
--for:se disparan despues de una accion (poniendo for por defecto es after)
--instead of: se disparan antes de una accion, antes de q ocurra un cambio en las tablas, cancela el resto de las acciones

--en las tablas inserted y deleted, los campos q no se updetean estan los mismos,OSEA NO ESTAN EN NULL


/*Implementar el/los objetos necesarios para que no se pueda realizar una factura si el precio de venta de algún artículo
 (ítem_precio) es distinto al precio que se encuentra en la tabla Producto (prod_precio)..*/


create trigger controlador_stock on Item_factura instead of insert
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
         open c1
         fetch next from c1 into @item_tipo, @item_sucursal, @item_numero
         while @@FETCH_STATUS = 0
         begin
             delete factura
                where fact_tipo=@item_tipo and fact_sucursal=@item_sucursal and fact_numero=@item_numero
            fetch next from c1 into @item_tipo, @item_sucursal, @item_numero
         end
         close c1
    end

    deallocate c1

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



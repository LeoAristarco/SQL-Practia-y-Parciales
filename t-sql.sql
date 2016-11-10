/* Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto que se debe almacenar en el deposito y
 que el stock maximo es la maxima cantidad de ese producto en ese deposito, cree el/los objetos de base de datos necesarios
 para que dicha regla de negocio se cumpla automaticamente. No se conoce la forma de acceso a los datos ni el procedimiento
  por el cual se incrementa o descuenta stock*/



create trigger controlador_stock on STOCK instead of update
as begin
    declare @producto1 char(8), @deposito1 char(2), @cantidad1 decimal(12,2), @minimo1 decimal(12,2), @maximo1 decimal(12,2)
    declare c1 cursor for select stoc_producto, stoc_deposito, stoc_cantidad, stoc_punto_reposicion, stoc_stock_maximo from inserted

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
Create trigger restriccionJefes on dbo.Empleado
for insert, update
as begin transaction
    
    Declare miCursor cursor for (Select empl_codigo, empl_ingreso, empl_jefe From inserted)
    
    Declare @cod_nuevo_empleado numeric(6,0)
    Declare @fecha_ingreso smalldatetime
    Declare @antiguedad int
    Declare @jefe_nuevo_empleado numeric(6,0)
    Declare @empleadosTotales int
    Declare @empleadosACargo int

    
    Set @empleadosTotales = (Select Count(*) From dbo.Empleado)


    OPEN miCursor
        fetch next from miCursor into @cod_nuevo_empleado, @fecha_ingreso, @jefe_nuevo_empleado

        WHILE(@@FETCH_STATUS = 0)
            begin
                Set @antiguedad = YEAR(@fecha_ingreso)
                Set @empleadosACargo = (Select Count(*) From dbo.Empleado e where loTieneACargo(@cod_nuevo_empleado, e.empl_codigo) = 1)

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
                                    raiserror('Un jefe no puede tener', 16,1)
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


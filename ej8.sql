
/*
Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por cantidad
de sus componentes, se aclara que un producto que compone a otro, también puede
estar compuesto por otros y así sucesivamente, la tabla se debe crear y está formada
por las siguientes columnas:

*/


create function FN_CALCULAR_SUMA_COMPONENTES (@producto char(8))
returns decimal(12,2)
as
	begin
		declare @costo decimal(12,2);
		declare @cantidad decimal(12,2);
		declare @componente char(8);
		
		if NOT EXISTS(SELECT * FROM Composicion WHERE comp_producto = @producto)
		begin
			set @costo = (select isnull(prod_precio,0) from Producto where prod_codigo=@producto)
			RETURN @costo
		end;
		
		set @costo = 0;
		
		declare cComp cursor for
		select comp_componente, comp_cantidad
		from Composicion 
		where comp_producto = @producto
		
		open cComp
		fetch next from cComp into @componente, @cantidad
		while @@FETCH_STATUS = 0
			begin
				set @costo = @costo + (dbo.FN_CALCULAR_SUMA_COMPONENTES(@componente) * @cantidad)
				fetch next from cComp into @componente, @cantidad;
			end
		close cComp;
		deallocate cComp;	
		return @costo;	
	end;

go


create table DIFERENCIAS
(
dife_producto char(8),
dife_detalle char(50),
dife_cantidad integer,
dife_precio_generado decimal(12,2),
dife_precio_facturado decimal(12,2)
)


go

create procedure SP_DIFERENCIAS
as
begin
	insert into DIFERENCIAS
	(dife_producto, dife_detalle, dife_cantidad, dife_precio_generado, dife_precio_facturado)
	select prod_codigo, prod_detalle, COUNT(distinct comp_componente), dbo.FN_CALCULAR_SUMA_COMPONENTES(prod_codigo), item_precio
	from Producto join Item_Factura on (prod_codigo = item_producto) --relaciono la tabla Producto con Item_Factura
				  join Composicion on (prod_codigo=comp_producto)-- el enunciado dice q tiene q machear con composicion
	where item_precio <> dbo.FN_CALCULAR_SUMA_COMPONENTES(prod_codigo) -- y el precio de facturación sea diferente al precio del 
                                                                 -- cálculo de los precios unitarios por cantidad de sus componentes
	group by prod_codigo, prod_detalle, item_precio
end

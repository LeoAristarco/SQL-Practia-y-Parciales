-- 1
select clie_codigo, clie_razon_social
from Cliente
where clie_limite_credito > 1000
order by clie_codigo

f2.fact_tipo f2.fact_sucursal f2.fact_numero
/* Ejercicio 2: Código y detalle de artículos vendidos en el 2012 ordenados por cantidad vendida */
select prod_codigo,prod_detalle 
from factura 
inner join Item_Factura  on item_tipo=fact_tipo and item_sucursal=fact_sucursal and item_numero=fact_numero
inner join Producto on item_producto = prod_codigo
where YEAR(fact_fecha)= 2012
group by prod_codigo , prod_detalle
order by SUM(item_cantidad) desc

/* Ejercicio 3: Código, nombre y stock total del producto ordenados por nombre artículo de menor a mayor */
select prod_codigo, prod_detalle, sum(stoc_cantidad) as stock_total
from Producto
inner join Stock on prod_codigo = stoc_producto
group by prod_codigo , prod_detalle
Order By prod_detalle asc


/* Ejercicio 4, echo en clases:
   Código, detalle y cantidad de componentes de cada artículo con stock promedio por depósito > 100 */
 select prod_codigo, prod_detalle, ISNULL(count(distinct comp_componente),0) as cantidad_de_productos_que_lo_componen, AVG(stoc_cantidad) as  stock_promedio_por_depocito
from Producto 
left join Composicion on prod_codigo = comp_producto
inner join Stock on prod_codigo = stoc_producto
 Group By prod_codigo, prod_detalle
Having AVG(stoc_cantidad) > 100
 Order By prod_codigo asc


 /* Ejercicio 8 (en clase):
   Nombre del artículo y nombre del depósito con mayor stock sólo de los artículos con stock en todos los depósitos */
select prod_detalle, MAX(stoc_cantidad) as stock_maximo
from Producto 
inner join STOCK on stoc_producto = prod_codigo
where stoc_cantidad > 0
group by prod_detalle
having count(stoc_deposito) = (select count (*)from DEPOSITO) -23

 --9
 select j.empl_codigo as jefe, e.empl_codigo, e.empl_nombre , count(distinct dj.depo_codigo) as deposito_jefe ,count(distinct de.depo_codigo) as depocito_emple
 from Empleado j 
 left join Empleado e on  j.empl_codigo = e.empl_jefe
left join DEPOSITO dj on dj.depo_encargado = j.empl_codigo
left join DEPOSITO de on de.depo_encargado = e.empl_codigo
 Group By j.empl_codigo, e.empl_codigo, e.empl_nombre 



 --9 por lobo (supuestamente mas perfomante)
select 
	   j.empl_codigo as jefe, 
	   e.empl_codigo, 
	   e.empl_nombre,
	              (select count(*)
				  from DEPOSITO
				  where depo_encargado = j.empl_codigo or depo_encargado = e.empl_codigo
				    ) as deposito_ambos
 from Empleado j 
 left join Empleado e on  j.empl_codigo = e.empl_jefe
 group by j.empl_codigo, e.empl_codigo, e.empl_nombre 

--10 

--a)

select
prod_codigo,
(
 select top 1 fact_cliente
 From dbo.Item_Factura
 inner join dbo.Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero
 where item_producto = prod_codigo
 group by fact_cliente
 order by count(item_cantidad) desc
 )as 'Cliente que más compró'
from dbo.Producto
where 
	prod_codigo in (
	select top 10 item_producto 
	from dbo.Item_Factura
	group by item_producto
	order by sum(item_cantidad) desc
	)
or
	prod_codigo in (
	select top 10 item_producto
	from dbo.Item_Factura
	group by item_producto
	order by sum(item_cantidad) asc
	)


--11
Select F.fami_detalle, COUNT(distinct P.prod_codigo)as cantidad_diferentes_de_productos_vendidos, SUM(I.item_cantidad * I.item_precio) as montoDeVentas
  From Familia F, Producto P, Item_Factura I
 Where P.prod_familia = F.fami_id
   And I.item_producto = P.prod_codigo
 Group By F.fami_id, F.fami_detalle
Having (SUM(I.item_cantidad * I.item_precio))  > 20000
 Order by COUNT(distinct P.prod_codigo) DESC

 
 --12 ISNULL(count(distinct comp_componente),0) 
 select      prod_detalle, isnull(count(distinct clie_codigo ),0)
             as clientes_que_lo_compraron,

             avg(fact_total) as importe_promedio_pagado,

            (select count(stoc_deposito)
			from STOCK
			where stoc_producto = prod_codigo and stoc_cantidad> 0
			) as cantida_de_depocitos_en_los_cuales_hay_stock,

			(select sum(stoc_cantidad)
			from STOCK
			where stoc_producto = prod_codigo and stoc_cantidad> 0
			) as cantida_de_stock_en_todos_los_depocitos
from  Factura 
inner join Item_Factura  on item_tipo=fact_tipo and item_sucursal=fact_sucursal and item_numero=fact_numero
inner join Cliente on clie_codigo =fact_cliente
right join Producto on   item_producto= prod_codigo
where year(fact_fecha) = 2012
group by prod_detalle,prod_codigo
Order By SUM(item_precio * item_cantidad) DESC


--13
select  p1.prod_codigo,p1.prod_detalle,p1.prod_precio,sum(p2.prod_precio*c1.comp_cantidad) as compra_de_productos_separados
from Composicion c1 inner join Producto p1 on c1.comp_producto = p1.prod_codigo,
Producto p2
where p2.prod_codigo =c1.comp_componente
group by p1.prod_detalle,p1.prod_codigo,p1.prod_precio

--14
select f1.fact_cliente,count( f1.fact_cliente),avg(f1.fact_total)
from Factura f1
where year(f1.fact_fecha) =(select max(year(f.fact_fecha)) 
                         from Factura f)
group by f1.fact_cliente
order by count(f1.fact_cliente) desc

--15
select i1.item_producto,i2.item_producto,count(*)as cantidadDeVecesQueSeVendieronJuntos -- en la misma factura
from 
Item_Factura i1 
inner join Item_Factura i2 on i2.item_tipo=i1.item_tipo and i2.item_sucursal=i1.item_sucursal and i2.item_numero=i1.item_numero
where i1.item_producto < i2.item_producto
group by i1.item_producto,i2.item_producto
having count(*)> 500

--17
select (Year(f1.fact_fecha)*100+month(f1.fact_fecha)) ,p1.prod_codigo,p1.prod_detalle,
(select count(i2.item_producto)
from Factura f2
inner join Item_Factura i2 on i2.item_tipo=f2.fact_tipo and i2.item_sucursal=f2.fact_sucursal and i2.item_numero=f2.fact_numero
where i2.item_producto= p1.prod_codigo and Year(f2.fact_fecha)=Year(f1.fact_fecha) and month(f2.fact_fecha)=month(f1.fact_fecha)
),
(
select count(i3.item_producto)
from Factura f3
inner join Item_Factura i3 on i3.item_tipo=f3.fact_tipo and i3.item_sucursal=f3.fact_sucursal and i3.item_numero=f3.fact_numero
where i3.item_producto= p1.prod_codigo and  Year(f3.fact_fecha)=Year(f1.fact_fecha)-1 and month(f3.fact_fecha)=month(f1.fact_fecha)
)
from Producto p1,Factura f1
group by Year(f1.fact_fecha),month(f1.fact_fecha),p1.prod_codigo,p1.prod_detalle
order by (Year(f1.fact_fecha)*100+month(f1.fact_fecha)),p1.prod_codigo desc



/*  Realizar una consulta SQL que retorne:

1) Año

2) Cantidad total de productos distintos vendidos para ese año.

3) Monto total Facturado para ese año.

4) Cliente que más Compro ese año.
Solamente se deberán mostrar los años donde su facturación fue mayor que la facturación del año anterior.
*/


  select YEAR(f.fact_fecha) as Año,count(distinct i2.item_producto),sum(f.fact_total)
from Factura f
inner join Item_Factura i2 on i2.item_tipo=f.fact_tipo and i2.item_sucursal=f.fact_sucursal and i2.item_numero=f.fact_numero
group by YEAR(f.fact_fecha)
HAVING sum(f.fact_total) > (select isnull(sum(f2.fact_total),0) from Factura f2 where year(f.fact_fecha)-1=year(f2.fact_fecha))




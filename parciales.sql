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



-- intento de resolucion de parcial de utenianos
/* realizar una consulta que muestre:
a)año
b)el producto con compocicion mas vendido para es año
c)cantidad de productos q componen al mas vendido
*/
select YEAR(f1.fact_fecha) as Año, i1.item_producto,
(
select COUNT( c3.comp_componente)
from Composicion c3
where c3.comp_producto = i1.item_producto
) as cantidadDeProductosQueLoComponen,
count(f1.fact_fecha) as cantidadDeFacturasDondeAparece,
(
select top 1 f5.fact_cliente
from Factura f5
inner join Item_Factura i5 on i5.item_tipo=f5.fact_tipo and i5.item_sucursal=f5.fact_sucursal and i5.item_numero=f5.fact_numero
where i5.item_producto= i1.item_producto and YEAR(f1.fact_fecha) = YEAR(f5.fact_fecha)
group by f5.fact_cliente
order by COUNT(*) desc
) as codigoDelClienteQueMasLoCompro
from Factura f1
inner join Item_Factura i1 on i1.item_tipo=f1.fact_tipo and i1.item_sucursal=f1.fact_sucursal and i1.item_numero=f1.fact_numero
group by YEAR(f1.fact_fecha),i1.item_producto
having i1.item_producto= (select top 1 i2.item_producto 
                        from factura f2 
                        inner join Item_Factura i2 on i2.item_tipo=f2.fact_tipo and i2.item_sucursal=f2.fact_sucursal and i2.item_numero=f2.fact_numero
                        inner join Composicion c2 on i2.item_producto = c2.comp_producto
                        where YEAR(f2.fact_fecha) = YEAR(f1.fact_fecha)
                        group by i2.item_producto
                        order by SUM(i2.item_cantidad) desc
                        )

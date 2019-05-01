-- 1. SELECT FROM two Tables

select * from [Customers] -- tbl1 (left)
select * from [Orders] -- tbl2 (right)

-- 2. INNER JOIN
-- Link two tables by fk

select * from [Customers] cust
	inner join [Orders] ord
		on cust.CustomerID = ord.CustomerID

-- 3. LEFT OUTER JOIN
-- Link two tables by fk and select all from tbl1 (left) and link records from tbl2 (right)

select * from [Customers] cust
	left join [Orders] ord
		on cust.CustomerID = ord.CustomerID

-- 4. RIGHT OUTER JOIN
-- Link two tables by fk and select all from tbl2 (right) and link records from tbl1 (left)

select * from [Customers] cust
	right join [Orders] ord
		on cust.CustomerID = ord.CustomerID

-- 5. SEMI JOIN
-- Similar to INNER JOIN, with less duplication from tbl2

select * from [Customers] cust
	where exists (select 1 from [Orders] ord where ord.CustomerID = cust.CustomerID);

-- 6. ANTI SEMI JOIN
-- Similar to LEFT OUTER JOIN with exclussion (or RIGHT OUTER JOIN with exclussion if you swap tables)

select * from [Customers] cust
	where not exists (select 1 from [Orders] ord where ord.CustomerID = cust.CustomerID);

-- 7. LEFT OUTER JOIN with exclussion - replacement for a NOT IN
-- Similar to ANTI SEMI JOIN

select * from [Customers] cust
	left join [Orders] ord
		on cust.CustomerID = ord.CustomerID
	where ord.CustomerID is null

-- 8. RIGHT OUTER JOIN with exclussion - replacement for a NOT IN
-- Similar to ANTI SEMI JOIN

select * from [Customers] cust
	right join [Orders] ord
		on cust.CustomerID = ord.CustomerID
	where cust.CustomerID is null

-- 9. FULL OUTER JOIN

select * from [Customers] cust
	full outer join [Orders] ord
		on cust.CustomerID = ord.CustomerID

-- 10. CROSS JOIN, like a FULL OUTER JOIN with out specifying join condition

select * from [Customers] cust
	cross join [Orders] ord
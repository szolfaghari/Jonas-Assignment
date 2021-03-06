USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[GetValueListJsonEx]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--select  id,field_name  from [dbo].[MergedData_Fields] (nolock)
-- truncate table MergedData_Data
-- truncate table MergedData_Fields
-- select * from [MergedData_Data] (nolock) order by 1 desc
-- select * from [MergedData_Fields] order by 1 
-- exec dbo.[GetValueListJsonEx] 1996 ,100706, 'FFF,ACTCM25,ACTEN25,OPEID,UNITID'
-- exec dbo.[GetValueListJsonEx] 1996 ,'100706,100724', 'FFF,ACTCM25,ACTEN25,OPEID,UNITID'
-- exec dbo.[GetValueListJson] 1997 ,	126049
-- exec dbo.[GetValueListJson] 1996 ,	101295
-- exec dbo.[GetValueListJsonEx] 1997 ,	'100636,107521', '-1'
-- exec dbo.[GetValueListJsonEx] '-1' ,'-1', 'OPEID,OPEID6'
-- select * from 
CREATE procedure [dbo].[GetValueListJsonEx](@year_list varchar(max) , @unit_id_list varchar(max) , @field_list varchar(max)   )  --,  @field_list varchar(max) we might want to filter the fields 
as 
-- declare @year int = 1996 ; declare @unit_id int = 100636
-- declare @field table (id int , [value] varchar(max) , name varchar(200) ) 
-- declare @tbl table (id int , [value] varchar(max) , name varchar(200) )  

declare @years_sql varchar(max) = 'select -1 as id union all select ' + replace (@year_list, ',' , '  union all select ') ; print @years_sql
declare @years table ([year] int) ; insert into @years exec (@years_sql)  --; select * from @years

declare @ids_sql varchar(max) = 'select -1 as id union all select ' + replace (@unit_id_list, ',' , '  union all select ') ; print @ids_sql
declare @ids table (id int) ; insert into @ids exec (@ids_sql) --; select * from @ids

declare @fields_sql varchar(max) = 'select cast('''' as varchar(max)) as field_name union all select ''' + replace (@field_list, ',' , '''  union all select ''') + ''' ;' ; print @fields_sql
declare @fields table (field_name varchar(max) ) ; insert into @fields exec (@fields_sql)  --; select * from @fields

declare @data table ([year] int, [unit_id] int , field_name varchar(max) , [value] varchar(max) )
insert into @data  
select [year], [unit_id],  field_name , [value] from  [dbo].[MergedData_Data] DAT (nolock) 
inner join [dbo].[MergedData_Fields] FLD (nolock) on Dat.field_id = FLD.id
where 2> 1
  and ([year] in (select [year] from @years where [year] >0) or @year_list = '-1') 
  and ([unit_id] in (select id from @ids where id > 0)  or @unit_id_list = '-1')
  and (field_name in (select field_name from @fields where isnull(field_name,'') <>'') or @field_list ='-1') 

--select * from @data ;return 0 

declare @json varchar(max) = '{   "_____id": "' + cast(newID() as varchar(max)) +'" ,  "_____dt":"' + convert(varchar(max) ,GETUTCDATE(), 121)  + '" , "data" : [  {{{REMOVE}}}'  ;

select  @json = @json +  ',{ "year" : "' + cast([year] as varchar(max))  + '" , "unit_id" : "' + cast(unit_id as varchar(max))  + '" ' + [data] + '}' 
 from 
(
		select [year], [unit_id] 
		,(select ' , "'+ field_name + '" : "'+ [value]+'"' from @data BBB where BBB.year = AAA.year and BBB.unit_id = AAA.unit_id for XML PATH('')) as data
		from 
		(select distinct [year], [unit_id] from @data )AAA
) CCC

select  @json = replace(replace(@json,'{{{REMOVE}}},',  ''),'{{{REMOVE}}}','')   + ' ] } '

select @json
return 0 
--

GO

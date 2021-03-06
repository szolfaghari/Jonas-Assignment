USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[GetValueListJson]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- select * from [MergedData_Data]
-- exec dbo.[GetValueListJson] 1996 ,100706
CREATE procedure [dbo].[GetValueListJson](@year int , @unit_id int    )  --,  @field_list varchar(max) we might want to filter the fields 
as 
-- declare @year int = 1996 ; declare @unit_id int = 100636
-- declare @field table (id int , [value] varchar(max) , name varchar(200) ) 
-- declare @tbl table (id int , [value] varchar(max) , name varchar(200) )  

declare @json varchar(max) = '{   "_____id": "' + cast(newID() as varchar(max)) +'" ,  "_____dt":"' + convert(varchar(max) ,GETUTCDATE(), 121)  + '" '  ;


select @json = @json + ',"'+  field_name + '":"'+[value] +'"' from 
(
select row_number() over (order by field_id) as seq,  FF.field_name , DD.[value] from 
(select field_id , [value] from  [dbo].[MergedData_Data] (nolock) where [year]= @year and unit_id = @unit_id) DD
inner join [dbo].[MergedData_Fields] FF (nolock) on FF.id = DD.field_id
) AA


select @json = @json + '}'


select  @json
GO

USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[AddFieldIfNotExisting]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- dbo.AddFieldIfNotExisting 'FFF' 
-- 
CREATE procedure [dbo].[AddFieldIfNotExisting](@field_name varchar(max) ) 
as 

set nocount on;
declare @id int = (select top 1 id from [dbo].[MergedData_Fields] (nolock) where [field_name] = @field_name)

if @id is null 
begin 
insert into [dbo].[MergedData_Fields] ([field_name] ) select @field_name
select @id = SCOPE_IDENTITY();
end 
select @id;
return @id; 
 


 /*
if not exists (select top 1 1 from sys.all_columns where object_id =  object_id('[dbo].[MergedData]') and name = @field_name)
begin 
declare @sql varchar(4000) = 'alter table [dbo].[MergedData] add '+ @field_name+ ' varchar(max) NULL '; 
exec (@sql) 
end 
*/
-- select * from sys.all_columns where object_id =  object_id('[dbo].[MergedData]') order by name
GO

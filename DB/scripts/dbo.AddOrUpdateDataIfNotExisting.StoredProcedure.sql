USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[AddOrUpdateDataIfNotExisting]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- dbo.AddOrUpdateDataIfNotExisting  2001, 9999, 'FFF' , NULL
-- select * from [MergedData_Data]
CREATE procedure [dbo].[AddOrUpdateDataIfNotExisting](@year int , @unit_id int ,  @field_name varchar(max), @value varchar(max) = NULL   ) 
as 

set nocount on;


declare @field_id int = (select top 1 id from [dbo].[MergedData_Fields] (nolock) where [field_name] = @field_name)

if @field_id is null 
begin
insert into [MergedData_Fields] (field_name) select @field_name
set @field_id = SCOPE_IDENTITY()
end 


if @field_id is null return;



if @value = 'NULL' select @value = NULL 
select @value = isnull(@value,'')  
print '@value=' +@value

declare @existing_id int 
declare @existing_value varchar(max) 

select @existing_id = id , @existing_value = [value] from 
(select top 1 id, [value]  from [dbo].[MergedData_Data] (nolock) where [year] = @year and [unit_id] = @unit_id and [field_id] = @field_id ) TMP 
print '@existing_id=' +cast( @existing_id as varchar(max))
print '@existing_value=' +cast( @existing_value as varchar(max))
-- update if record existing and value is new 
if @existing_id is not null and @existing_value <>  @value
 begin 
  
  if @value <> '' 
     begin 
	 print 'updating non-blank value'
     update [MergedData_Data] set [value] = @value where id = @existing_id
     end  
  else 
     begin 
	 print 'deleting blank value'
     delete [MergedData_Data]  where id = @existing_id
     end 
 end 

if @existing_id is null and @value <> '' 
begin 
   insert into [dbo].[MergedData_Data] ([year],unit_id,[field_id],[value]) select @year, @unit_id, @field_id, @value
end 






GO

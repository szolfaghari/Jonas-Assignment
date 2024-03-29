USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[AddOrUpdateValue]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- dbo.AddOrUpdateDataIfNotExisting  2001, 9999, 'FFF' , NULL
-- exec [dbo].[AddOrUpdateValue] @year=1996,@unit_id=100751,@field_id=204,@value='NULL'
-- select * from [MergedData_Data]

-- truncate table [MergedData_Data]
CREATE procedure [dbo].[AddOrUpdateValue](@year int , @unit_id int ,  @field_id int, @value varchar(max) = NULL   ) 
as 

set nocount on;


--declare @field_id int = (select top 1 id from [dbo].[MergedData_Fields] (nolock) where [field_name] = @field_name)
--if @field_id is null return;



if @value = 'NULL' select @value = NULL 
select @value = isnull(@value,'')  
print '@value=' +@value

declare @existing_id int 
declare @existing_value varchar(max) 

select @existing_id = id , @existing_value = [value] from 
(select top 1 id, [value]  from [dbo].[MergedData_Data] (nolock) where [year] = @year and [unit_id] = @unit_id and [field_id] = @field_id ) TMP 
print '@existing_id=' + isnull(cast( @existing_id as varchar(max)),'NULL')
print '@existing_value=' +ISNULL(cast( @existing_value as varchar(max)),'NULL')
-- update if record existing and value is new 
 if @existing_id is not null
  begin
      if @existing_value <> @value
        begin
            if @value <> ''
              begin
                  print 'updating non-blank value'
				  update [mergeddata_data]  set    [value] = @value  where  id = @existing_id
              end
            else
              begin
                  print 'deleting blank value'
				  delete [mergeddata_data]  where  id = @existing_id
              end
        end
  end
else
  begin
      if @value <> ''
        begin
            print 'inserting new record '

            insert into [dbo].[mergeddata_data]
                        ([year],
                         unit_id,
                         [field_id],
                         [value])
            select @year,
                   @unit_id,
                   @field_id,
                   @value
        end
  end  



GO

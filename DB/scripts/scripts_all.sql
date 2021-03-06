USE [JonasDB]
GO
/****** Object:  UserDefinedFunction [dbo].[parseJSON]    Script Date: 2/3/2020 1:53:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION [dbo].[parseJSON]( @JSON NVARCHAR(MAX))
RETURNS @hierarchy table
(
element_id int IDENTITY(1, 1) NOT NULL, /* internal surrogate primary key gives the order of parsing and the list order */
parent_id int, /* if the element has a parent then it is in this column. The document is the ultimate parent, so you can get the structure from recursing from the document */
object_id int, /* each list or object has an object id. This ties all elements to a parent. Lists are treated as objects here */
name nvarchar(2000), /* the name of the object */
stringvalue nvarchar(4000) NOT NULL, /*the string representation of the value of the element. */
valuetype nvarchar(100) NOT null /* the declared type of the value represented as a string in stringvalue*/
)

AS

BEGIN
DECLARE
@firstobject int, --the index of the first open bracket found in the JSON string
@opendelimiter int,--the index of the next open bracket found in the JSON string
@nextopendelimiter int,--the index of subsequent open bracket found in the JSON string
@nextclosedelimiter int,--the index of subsequent close bracket found in the JSON string
@type nvarchar(10),--whether it denotes an object or an array
@nextclosedelimiterChar CHAR(1),--either a '}' or a ']'
@contents nvarchar(MAX), --the unparsed contents of the bracketed expression
@start int, --index of the start of the token that you are parsing
@end int,--index of the end of the token that you are parsing
@param int,--the parameter at the end of the next Object/Array token
@endofname int,--the index of the start of the parameter at end of Object/Array token
@token nvarchar(4000),--either a string or object
@value nvarchar(MAX), -- the value as a string
@name nvarchar(200), --the name as a string
@parent_id int,--the next parent ID to allocate
@lenjson int,--the current length of the JSON String
@characters NCHAR(62),--used to convert hex to decimal
@result BIGINT,--the value of the hex symbol being parsed
@index SMALLINT,--used for parsing the hex value
@escape int --the index of the next escape character

/* in this temporary table we keep all strings, even the names of the elements, since they are 'escaped'
* in a different way, and may contain, unescaped, brackets denoting objects or lists. These are replaced in
* the JSON string by tokens representing the string
*/
DECLARE @strings table
(
string_id int IDENTITY(1, 1),
stringvalue nvarchar(MAX)
)

/* initialise the characters to convert hex to ascii */
SELECT
@characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
@parent_id = 0;

/* firstly we process all strings. This is done because [{} and ] aren't escaped in strings, which complicates an iterative parse. */
WHILE 1 = 1 /* forever until there is nothing more to do */
BEGIN
SELECT @start = PATINDEX('%[^a-zA-Z]["]%', @json collate SQL_Latin1_General_CP850_Bin); /* next delimited string */
IF @start = 0 BREAK /*no more so drop through the WHILE loop */
IF SUBSTRING(@json, @start+1, 1) = '"'
BEGIN /* Delimited name */
SET @start = @start+1;
SET @end = PATINDEX('%[^\]["]%', RIGHT(@json, LEN(@json+'|')-@start) collate SQL_Latin1_General_CP850_Bin);
END

IF @end = 0 /*no end delimiter to last string*/
BREAK /* no more */

SELECT @token = SUBSTRING(@json, @start+1, @end-1)

/* now put in the escaped control characters */
SELECT @token = REPLACE(@token, from_string, to_string)
FROM
(
SELECT '\"' AS from_string, '"' AS to_string
UNION ALL
SELECT '\\', '\'
UNION ALL
SELECT '\/', '/'
UNION ALL
SELECT '\b', CHAR(08)
UNION ALL
SELECT '\f', CHAR(12)
UNION ALL
SELECT '\n', CHAR(10)
UNION ALL
SELECT '\r', CHAR(13)
UNION ALL
SELECT '\t', CHAR(09)
) substitutions

SELECT @result = 0, @escape = 1

/*Begin to take out any hex escape codes*/
WHILE @escape > 0
BEGIN
/* find the next hex escape sequence */
SELECT
@index = 0,
@escape = PATINDEX('%\x[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%', @token collate SQL_Latin1_General_CP850_Bin)

IF @escape > 0 /* if there is one */
BEGIN
WHILE @index < 4 /* there are always four digits to a \x sequence */
BEGIN
/* determine its value */
SELECT
@result =
@result + POWER(16, @index) * (CHARINDEX(SUBSTRING(@token, @escape + 2 + 3 - @index, 1), @characters) - 1), @index = @index+1 ;
END

/* and replace the hex sequence by its unicode value */
SELECT @token = STUFF(@token, @escape, 6, NCHAR(@result))
END
END

/* now store the string away */
INSERT INTO @strings
(stringvalue)
SELECT @token

/* and replace the string with a token */
SELECT @json = STUFF(@json, @start, @end + 1, '@string' + CONVERT(nvarchar(5), @@identity))
END

/* all strings are now removed. Now we find the first leaf. */
WHILE 1 = 1 /* forever until there is nothing more to do */
BEGIN
SELECT @parent_id = @parent_id + 1

/* find the first object or list by looking for the open bracket */
SELECT @firstobject = PATINDEX('%[{[[]%', @json collate SQL_Latin1_General_CP850_Bin) /*object or array*/

IF @firstobject = 0
BREAK

IF (SUBSTRING(@json, @firstobject, 1) = '{')
SELECT @nextclosedelimiterChar = '}', @type = 'object'
ELSE
SELECT @nextclosedelimiterChar = ']', @type = 'array'

SELECT @opendelimiter = @firstobject

WHILE 1 = 1 --find the innermost object or list...
BEGIN
SELECT @lenjson = LEN(@json+'|')-1
/* find the matching close-delimiter proceeding after the open-delimiter */
SELECT @nextclosedelimiter = CHARINDEX(@nextclosedelimiterChar, @json, @opendelimiter + 1)

/* is there an intervening open-delimiter of either type */
SELECT @nextopendelimiter = PATINDEX('%[{[[]%',RIGHT(@json, @lenjson-@opendelimiter) collate SQL_Latin1_General_CP850_Bin) /*object*/
IF @nextopendelimiter = 0
BREAK

SELECT @nextopendelimiter = @nextopendelimiter + @opendelimiter

IF @nextclosedelimiter < @nextopendelimiter
BREAK

IF SUBSTRING(@json, @nextopendelimiter, 1) = '{'
SELECT @nextclosedelimiterChar = '}', @type = 'object'
ELSE
SELECT @nextclosedelimiterChar = ']', @type = 'array'

SELECT @opendelimiter = @nextopendelimiter
END

/* and parse out the list or name/value pairs */
SELECT @contents = SUBSTRING(@json, @opendelimiter+1, @nextclosedelimiter-@opendelimiter - 1)

SELECT @json = STUFF(@json, @opendelimiter, @nextclosedelimiter - @opendelimiter + 1, '@' + @type + CONVERT(nvarchar(5), @parent_id))

WHILE (PATINDEX('%[A-Za-z0-9@+.e]%', @contents collate SQL_Latin1_General_CP850_Bin)) < > 0
BEGIN /* WHILE PATINDEX */
IF @type = 'object' /*it will be a 0-n list containing a string followed by a string, number,boolean, or null*/
BEGIN
SELECT @end = CHARINDEX(':', ' '+@contents) /*if there is anything, it will be a string-based name.*/
SELECT @start = PATINDEX('%[^A-Za-z@][@]%', ' '+@contents collate SQL_Latin1_General_CP850_Bin) /*AAAAAAAA*/

SELECT
@token = SUBSTRING(' '+@contents, @start + 1, @end - @start - 1),
@endofname = PATINDEX('%[0-9]%', @token collate SQL_Latin1_General_CP850_Bin),
@param = RIGHT(@token, LEN(@token)-@endofname+1)

SELECT
@token = LEFT(@token, @endofname - 1),
@contents = RIGHT(' ' + @contents, LEN(' ' + @contents + '|') - @end - 1)

SELECT @name = stringvalue
FROM @strings
WHERE string_id = @param /*fetch the name*/

END
ELSE
BEGIN
SELECT @name = null
END

SELECT @end = CHARINDEX(',', @contents) /*a string-token, object-token, list-token, number,boolean, or null*/

IF @end = 0
SELECT @end = PATINDEX('%[A-Za-z0-9@+.e][^A-Za-z0-9@+.e]%', @contents+' ' collate SQL_Latin1_General_CP850_Bin) + 1

SELECT @start = PATINDEX('%[^A-Za-z0-9@+.e][A-Za-z0-9@+.e]%', ' ' + @contents collate SQL_Latin1_General_CP850_Bin)
/*select @start,@end, LEN(@contents+'|'), @contents */

SELECT
@value = RTRIM(SUBSTRING(@contents, @start, @end-@start)),
@contents = RIGHT(@contents + ' ', LEN(@contents+'|') - @end)

IF SUBSTRING(@value, 1, 7) = '@object'
INSERT INTO @hierarchy (name, parent_id, stringvalue, object_id, valuetype)

SELECT @name, @parent_id, SUBSTRING(@value, 8, 5),
SUBSTRING(@value, 8, 5), 'object'

ELSE
IF SUBSTRING(@value, 1, 6) = '@array'
INSERT INTO @hierarchy (name, parent_id, stringvalue, object_id, valuetype)

SELECT @name, @parent_id, SUBSTRING(@value, 7, 5), SUBSTRING(@value, 7, 5), 'array'

ELSE
IF SUBSTRING(@value, 1, 7) = '@string'
INSERT INTO @hierarchy (name, parent_id, stringvalue, valuetype)

SELECT @name, @parent_id, stringvalue, 'string'
FROM @strings
WHERE string_id = SUBSTRING(@value, 8, 5)

ELSE
IF @value IN ('true', 'false')
INSERT INTO @hierarchy (name, parent_id, stringvalue, valuetype)

SELECT @name, @parent_id, @value, 'boolean'

ELSE
IF @value = 'null'
INSERT INTO @hierarchy (name, parent_id, stringvalue, valuetype)

SELECT @name, @parent_id, @value, 'null'

ELSE
IF PATINDEX('%[^0-9]%', @value collate SQL_Latin1_General_CP850_Bin) > 0
INSERT INTO @hierarchy (name, parent_id, stringvalue, valuetype)

SELECT @name, @parent_id, @value, 'real'

ELSE
INSERT INTO @hierarchy (name, parent_id, stringvalue, valuetype)

SELECT @name, @parent_id, @value, 'int'
END /* WHILE PATINDEX */
END /* WHILE 1=1 forever until there is nothing more to do */

INSERT INTO @hierarchy (name, parent_id, stringvalue, object_id, valuetype)
SELECT '-', NULL, '', @parent_id - 1, @type

RETURN

END
GO
/****** Object:  View [dbo].[vw_getSeq]    Script Date: 2/3/2020 1:53:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_getSeq]
AS
select row_number() over (order by object_id) as seq  from master.sys.all_parameters
GO
/****** Object:  Table [dbo].[MergedData_Data]    Script Date: 2/3/2020 1:53:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MergedData_Data](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[year] [int] NULL,
	[unit_id] [int] NULL,
	[field_id] [int] NULL,
	[value] [varchar](max) NULL,
 CONSTRAINT [PK_MergedData_Data] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MergedData_Fields]    Script Date: 2/3/2020 1:53:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MergedData_Fields](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[field_name] [varchar](200) NULL
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[AddFieldIfNotExisting]    Script Date: 2/3/2020 1:53:30 AM ******/
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
/****** Object:  StoredProcedure [dbo].[AddOrUpdateDataIfNotExisting]    Script Date: 2/3/2020 1:53:30 AM ******/
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
/****** Object:  StoredProcedure [dbo].[AddOrUpdateValue]    Script Date: 2/3/2020 1:53:30 AM ******/
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
/****** Object:  StoredProcedure [dbo].[GetFieldNames]    Script Date: 2/3/2020 1:53:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[GetFieldNames] as
select  id,field_name  from [dbo].[MergedData_Fields] (nolock) order by id 
GO
/****** Object:  StoredProcedure [dbo].[GetValueListJson]    Script Date: 2/3/2020 1:53:30 AM ******/
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
/****** Object:  StoredProcedure [dbo].[GetValueListJsonEx]    Script Date: 2/3/2020 1:53:30 AM ******/
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
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vw_getSeq'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vw_getSeq'
GO

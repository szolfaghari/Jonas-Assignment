USE [JonasDB]
GO
/****** Object:  StoredProcedure [dbo].[GetFieldNames]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[GetFieldNames] as
select  id,field_name  from [dbo].[MergedData_Fields] (nolock) order by id 
GO

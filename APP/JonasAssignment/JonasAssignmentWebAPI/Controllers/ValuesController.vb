Imports System.Net
Imports System.Web.Http
Imports System.Data.Entity
Imports System.Data.SqlClient

Public Class ValuesController
    Inherits ApiController



    'Get api/values  --This will get the whole line with all available values in the DB. In order to keep tehDB size minimal 
    'I have assumed NULL And blank are the same And they are Not kept In the DB. So Not showing In the result 
    Public Function GetValue(year As Integer, unit_id As Integer) As IHttpActionResult
        Try
            Using db As New MergedDataEntities
                Dim result = db.GetValueListJson(year, unit_id).ToList()
                Dim obj = Newtonsoft.Json.JsonConvert.DeserializeObject(Of Object)(result.FirstOrDefault())
                Return Ok(obj)
            End Using
        Catch ex As Exception
            Dim obj = Newtonsoft.Json.JsonConvert.DeserializeObject("{ status = 'ERROR', msg = 'GENERAL ERROR' }")
            Return Ok(obj)
        End Try
    End Function

    'Get api/values  --This is the more flexible yet slower call. you can pass the list of yeas/ list of unit ids and even list of fields (all comma separated)  
    'This query may potentially kill the DB. So I have to add a max number of returning records (not in place yet) 
    Public Function GetValues(years_csv As String, ids_csv As String, fieldnames_csv As String) As IHttpActionResult
        Try
            Using db As New MergedDataEntities
                Dim result = db.GetValueListJsonEx(years_csv, ids_csv, fieldnames_csv).ToList()
                Dim obj = Newtonsoft.Json.JsonConvert.DeserializeObject(Of Object)(result.FirstOrDefault())
                Return Ok(obj)
            End Using
        Catch ex As Exception
            Dim obj = Newtonsoft.Json.JsonConvert.DeserializeObject("{ status = 'ERROR', msg = 'GENERAL ERROR' }")
            Return Ok(obj)
        End Try
    End Function


    ' POST api/values - This is to add or update a record
    ' it will overwrite the previous value , but in case we need to keep track og the history , that can be maintained as well with small tweak and with the risk of ending up with a larger DB size 
    Public Function PostValue(year As Integer, unit_id As Integer, field_name As String, value As String) As IHttpActionResult
        Try
            Using db As New MergedDataEntities
                db.AddOrUpdateDataIfNotExisting(year, unit_id, field_name, value)
                Return Ok("Success")
            End Using
        Catch ex As Exception
            Return Ok("Error")
        End Try
    End Function


    ' DELETE api/values
    ' I have created a delete in 4 different levels
    ' (1) Delete based on year + unit_id + field_name
    ' (2) Delete based on year + unit_id 
    ' (3) Delete based on year 
    ' (4) Delete based on field_name
    ' delete action will physically remove the records from the DB  

    Public Function DeleteValue(year As Integer) As IHttpActionResult
        Try
            Using db As New MergedDataEntities()
                db.Database.ExecuteSqlCommand("delete [MergedData_Data] where year = @year", New SqlParameter("@year", year))
                Return Ok("Success")
            End Using
        Catch ex As Exception
            Return Ok("Error")
        End Try

    End Function

    Public Function DeleteValue(year As Integer, unit_id As Integer) As IHttpActionResult
        Try
            Using db As New MergedDataEntities()
                db.Database.ExecuteSqlCommand("delete [MergedData_Data] where year = @year and unit_id = @unit_id" _
                                          , New SqlParameter("@year", year) _
                                          , New SqlParameter("@unit_id", unit_id)
                                          )
                Return Ok("Success")
            End Using
        Catch ex As Exception
            Return Ok("Error")
        End Try

    End Function


    Public Function DeleteValue(year As Integer, unit_id As Integer, field_name As String) As IHttpActionResult
        Try
            Using db As New MergedDataEntities()
                db.Database.ExecuteSqlCommand("delete [MergedData_Data] where year = @year and unit_id = @unit_id and field_id in ( select top 1 id from [dbo].[MergedData_Fields] (nolock) where field_name = @field_name  ) " _
                                          , New SqlParameter("@year", year) _
                                          , New SqlParameter("@unit_id", unit_id) _
                                          , New SqlParameter("@field_name", field_name)
                                          )
                Return Ok("Success")
            End Using
        Catch ex As Exception
            Return Ok("Error")
        End Try

    End Function

    Public Function DeleteValue(field_name As String) As IHttpActionResult
        Try
            Using db As New MergedDataEntities()
                db.Database.ExecuteSqlCommand("delete [MergedData_Data] where field_id in ( select top 1 id from [dbo].[MergedData_Fields] (nolock) where field_name = @field_name); delete dbo.MergedData_Fields where field_name = @field_name ;  ", New SqlParameter("@field_name", field_name))
                Return Ok("Success")
            End Using
        Catch ex As Exception
            Return Ok("Error")
        End Try

    End Function

End Class

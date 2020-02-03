Imports System.Data.SqlClient

Module Module1

    Sub Main()
        Dim files = System.IO.Directory.GetFiles("C:\Users\AsusAdmin\Downloads\CollegeScorecard_Raw_Data\CollegeScorecard_Raw_Data\", "MERGED*")
        For Each file In files
            Console.WriteLine("Processing " + file)
            ProcessCsvFile(file)
            ''MarkAsProcessed(file)             ''log into a table , rename the file and delete the .sig file
        Next
    End Sub

    Public Class FieldItem
        Public id As Integer
        Public field_name As String
    End Class


    Sub ProcessCsvFile(file As String)
        Try
            Dim content = System.IO.File.ReadAllText(file)    ''' reading the whole file but If they become larger we need To take other approach
            Dim year = System.IO.Path.GetFileName(file).ToString().Substring(6, 4)
            Dim lines = content.Split(vbLf)
            Dim headers = ParseTextAsCsv(lines(0))            ''' TODO: add some validation [naming, duplicates, ...]
            Dim ids(headers.Length - 1) As Integer

            For Each header In headers
                AddFieldToDb(header)
            Next

            Parallel.ForEach(headers,
                             Sub(header)
                                 AddFieldToDb(header)
                             End Sub
                           )

            Using db As New MergedDataEntities()
                Dim field_list = db.GetFieldNames().ToList()
                Dim dic As New Dictionary(Of String, Integer)
                For Each fld In field_list
                    dic.Add(fld.field_name, fld.id)
                Next


                For index = 0 To headers.Count - 1
                    Dim idx = index
                    ''ids(index) = field_list.FirstOrDefault(Function(itm) itm.field_name = headers(idx)).id
                    ids(index) = dic.Item(headers(idx))
                Next


                For index = 1 To field_list.Count - 1

                    Console.WriteLine(String.Format("Processing line {0}", index.ToString()))
                    ProcessLine(Integer.Parse(year), ids, lines(index))
                Next
            End Using




        Catch ex As Exception

        End Try
    End Sub


    Function ParseTextAsCsv(csv As String) As String()

        Return csv.Split(",")           '' TODO: improve by using a more complicated csv parsing   [to handle qoutes, escapes , ...] 

    End Function

    Sub AddFieldToDb(columnName As String)
        Try

            Using db As New MergedDataEntities()
                db.Database.ExecuteSqlCommand("exec dbo.AddFieldIfNotExisting @newCol",
                          New SqlParameter("@newCol", columnName))
            End Using

        Catch ex As Exception
            '' TODO: handle properly , log and stop the process 
        End Try

    End Sub

    Sub ProcessLine(year As Integer, ids As Integer(), lineData As String)
        Dim values = ParseTextAsCsv(lineData)
        If ids.Length <> values.Length Then Return

        Dim unit_id = Integer.Parse(values(0))

        For index = 1 To values.Length - 1

            Console.WriteLine(String.Format("Processing field {0} --> {1} --> {2}={3}", year.ToString(), unit_id.ToString(), ids(index).ToString(), values(index)))
            If values(index) <> "NULL" Then
                Using db As New MergedDataEntities()
                    db.AddOrUpdateValue(year, unit_id, ids(index), values(index))
                End Using

            End If

        Next


    End Sub














End Module

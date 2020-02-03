# Jonas-Assignment [2020-02-02]

The initial investigation of the data files shows that we will need to overcome below obstacles:

(1) the limitation on the number of fields per table in SQL Server (max = 1024)

(2) the max length of each record in SQL server  

 
My proposed structure is to break down the whole table into records each holding 1 piece of data, assuming the primary key for this is [Year] + [Unit_id]

This might impact the performance a bit, but will make the solution more extendable in case we have more fields in the future.


* In order to keep the DB size smaller, I have assumed NULL and blank have the same meaning , so I am eliminating the record in such cases. (either by deleting or even not inserting in the first place)
* I am always comparing the new value with the existing to make sure update happens only when it is necessary
* For csv parsing, I am using a rather non-efficient approach. We can improve by using custom parser or any 3rd party parsing library.
* Most of the data manipulation is taken care of in the stored procedure level.
* I have compared the performance for the file reads and it seems multi treating does not help much with I/O  operations, so I kept it as a sequential loop.
* As I am not familliar with the data I have taken a generic apprach. If we dig deeper into the details, part of the approach might not make sense or will need to be revisited.
* We can improve the performance by tweaking the indexes. However we need to know the balance between the frequeny of reads vs writes


# Optimization Ideas
  * For the batch insert, we probably can do some grouping. I noticed there are a lot of NULLs and ZEROs. so we may handle them separately all zeros in 1 batch
  * For the batch insert, we can make a larger script and hit to DB every N records (or while the script size is OK)
  * For the batch insert, we can delete all the year/unit_id combinations and call [add] instead of [addorupdate] depending of the nature of update.


# API Guide 

**Read data [GET]**

* /api/values?year=<YEAR>&unit_id=<UNIT_ID>
* /api/values?years_csv=<YEAR1,Year2,...>&ids_csv=<UNIT_ID1,UNIT_ID2,...>&fieldnames_csv=<FIELDNAME1,FIELDNAME2,...>

**ADD/Update  [POST]**

* /api/values?year=<YEAR>&unit_id=<UNIT_ID>&field_name=<FIELDNAME>&value=<VALUE>

**Delete  [DELETE]**

* /api/values?year=<YEAR>&unit_id=<UNIT_ID>&field_name=<FIELDNAME>
* /api/values?year=<YEAR>&unit_id=<UNIT_ID>
* /api/values?year=<YEAR>
* /api/values?field_name=<FIELDNAME>

# Projects 

Both projects can be found under <APP> foler in the repository. They are done with VB.net as per request and can be executed with minimal changes
(connectionstrings need to be tweaked for sure)

* JonasAssignment (ConsoleApp) 
* JonasAssignmentWebAPI

A copy of DB backup has been included the the repository. it needs to be restored as **JonasDB** to the database.



 




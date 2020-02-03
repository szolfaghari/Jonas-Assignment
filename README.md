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
* As I am not familiar with the data I have taken a generic approach. If we dig deeper into the details, part of the approach might not make sense or will need to be revisited.
* We can improve the performance by tweaking the indexes. However we need to know the ratio between reads vs writes

# API Guide 

**Read data [GET]**

* /api/values?year=**[YEAR1]**&unit_id=**[UNIT_ID1]**
* /api/values?years_csv=**[YEAR1,YEAR2,...]**&ids_csv=**[UNIT_ID1,UNIT_ID2,...]**&fieldnames_csv=**[FIELDNAME1,FIELDNAME2,...]**

**Add/Update  [POST]**

* /api/values?year=**[YEAR1]**&unit_id=**[UNIT_ID1]**&field_name=**[FIELDNAME1]**&value=**[VALUE1]**

**Delete  [DELETE]**

* /api/values?year=**[YEAR1]**&unit_id=**[UNIT_ID1]**&field_name=**[FIELDNAME1]**
* /api/values?year=**[YEAR1]**&unit_id=**[UNIT_ID1]**
* /api/values?year=**[YEAR1]**
* /api/values?field_name=**[FIELDNAME1]**

# Projects 

Both projects can be found under **[APP]** folder in the repository. They are done with VB.Net [as per request] and can be executed with minimal changes.(**connectionstring** needs to be tweaked for sure)

* JonasAssignment (ConsoleApp) 
* JonasAssignmentWebAPI

A copy of DB backup has been included the the repository. It needs to be restored as **JonasDB** to the database. This can be found under **[DB]** folder in the repository. 

# Optimization Ideas
  * For the batch insert, we probably can do some grouping. I noticed there are a lot of NULLs and ZEROs. So we may handle them separately (and in one shot) 
  * For the batch insert, we can make a larger script and hit the DB every N records (or while the script size is safe)
  * For the batch insert, In case we need to redo (or refresh) files , we can delete all the year/unit_id combinations and call [add] instead of [AddOrUpdate] depending of the nature of update.
  * We need to manage the folder containing the files, so after we are done with each file we rename them or move to a [processed] folder. Also we need to add the filenames to a table for tracking sake. In case the same file is fed into the system again we need to know the action that is to be taken.
  * We may need to use signal files to point the app on what files to pick up (that is something I have used in most of the file processing apps)

 




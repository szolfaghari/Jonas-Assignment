<div class="jumbotron">
    <h1>Jonas Assignment [2020-02-02]</h1>
    <p class="lead">Please use this document as a quick guide for calling the WEB API</p>
    
</div>
<div class="row">

    <h2>Read Data [GET]</h2>
    <p> /api/values?year=1996&unit_id=100636 </p>
    <p> /api/values?years_csv=1996,1997&ids_csv=100706,100724&fieldnames_csv=ACTCM25,ACTEN25,OPEID,OPEID6  </p>

    <h2>Add/Update Data [POST]</h2>
    <p> /api/values?year=1996&unit_id=100636&field_name=ZOLFAGHARI&value=99999999 </p>

    <h2>Delete Data [DELETE]</h2>
    <p>/api/values?field_name=SOROUSH</p>
    <p>/api/values?year=1996&unit_id=100636&field_name=SOROUSH</p>
    <p>/api/values?year=1996&unit_id=100636</p>
    <p>/api/values?year=1996</p>
</div>

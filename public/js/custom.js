// UUID Search
$('#search').on('click', function(event) {

    console.log($('#uuid_value').val());
    console.log($('#services_list').val());

    $.get(
        "/uuid_details",
        { 
            service_type : $('#services_list').val(), 
            uuid_value : $('#uuid_value').val()
        },
        function(data) {
            $('#search_result').html('<code>' + JSON.stringify(data, null, '  ') + '</code>');
        }
    );

});

$('#updateButton').click(function(){
  clientId = $('#client_list').val();
  templateCategory = $('#notif_cat').val();
  templateText = $('#templateText').val();
  templateState = $('#templateState').is(':checked'); 
  defaultValue = "null";
  if (templateText != "" && templateCategory != defaultValue && clientId != defaultValue){
    $.post("/templates/update",
    {
      templateCategory: templateCategory,
      templateText: templateText,
      templateState: templateState,
      clientId: clientId,
      templateType: 'notification'
    },
    function(data,status){
      if (data == "success"){
        $('#formInfo').html('<span class="label label-success">Updated Successfull</span>');
      } else {
        $('#formInfo').html('<span class="label label-danger">Error</span>');
      }
    });
  } else {
    $('#formInfo').html('<span class="label label-danger">Input values missing</span>');
  }
});

$('#notif_cat').change(function() {
  clientId = $('#client_list').val();
  defaultValue = "null";
  if ($(this).val() != defaultValue){
    $.get(
      "/templates_text",
      {
        templateCategory : $(this).val(),
        clientId : clientId
      },
      function(data) {
        $('#templateText').val(data);
      }
    );
  } else {
    $('#templateText').val("");
  }
});

$('#client_list').change(function() {
  clientId = $(this).val();
  defaultValue = "null";
  if ($('#notif_cat').val() != defaultValue) {
    $.get(
      "/templates_text",
      {
        templateCategory : $('#notif_cat').val(),
        clientId : clientId
      },
      function(data) {
        $('#templateText').val(data);
      }
    );
  } else {
    $('#templateText').val("");
  }
});
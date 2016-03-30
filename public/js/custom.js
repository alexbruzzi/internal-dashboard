// UUID Search
$('#search').on('click', function(event) {

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

$('#category_client_list').change(function(){
  clientId = $(this).val();
  defaultValue = "null";
  if (clientId != defaultValue) {
    $.get(
      "/fetch_categories",
      {
        clientId : clientId
      },
      function(data) {
        $("#category_list").html('');
        $(data).each(function( index, value ) {
          $("#category_list").append('<li class="list-group-item">'+ value['category_type'] +'</li>');
        });
      }
    );
  }
});

$('#updateCategory').click(function(){
  clientId = $('#category_client_list').val();
  category_type = $('#category_type').val();
  defaultValue = "null";
  if (clientId != defaultValue && category_type != '') {
    $.post("/add_category",
    {
      clientId: clientId,
      category_type: category_type
    },
    function(data,status){
      if (data == "success"){
        $('#formInfo').html('<span class="label label-success">Updated Successfull</span>');
        $("#category_list").append('<li class="list-group-item">' + category_type + '</li>');
      } else {
        $('#formInfo').html('<span class="label label-danger">Error</span>');
      }
    });
  }
});

$('#updateRateLimit').click(function(){
  if ($('#client_manage_list').val() != "null" && $('#rate_limit').val()){
    $.post("/plugins/update",
    {
      plugin_id: $('#client_manage_list :selected').data("pluginid"),
      consumer_id: $('#client_manage_list :selected').val(),
      day_limit: $('#rate_limit').val(),
      apikey: $('#client_manage_list :selected').data("apikey")
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

$('#template_clients').change(function() {
  clientId = $(this).val();
  defaultValue = "null";
  if (clientId != defaultValue) {
    $.get(
      "/fetch_categories",
      {
        clientId : clientId
      },
      function(data) {
        $('#templateText').val("");
        $('#templateState').prop('checked', false);
        $("#template_category").html('');
        $("#template_category").append('<option value="null">Select Category</option>');
        $(data).each(function( index, value ) {
          $("#template_category").append('<option value="'+value['category_type']+'">'+ value['category_type'] +'</option>');
        });
      }
    );
  } else {
    $('#templateText').val("");
    $('#templateState').prop('checked', false);
  }
});

$('#template_category').change(function() {
  clientId = $('#template_clients').val();
  defaultValue = "null";
  if ($(this).val() != defaultValue){
    $.get(
      "/templates_text",
      {
        templateCategory : $(this).val(),
        clientId : clientId
      },
      function(data) {
        var obj = jQuery.parseJSON(data);
        $('#templateText').val(obj['text']);
        $('#templateState').prop('checked', obj['state']);
      }
    );
  } else {
    $('#templateText').val("");
    $('#templateState').prop('checked', false);
  }
});

$('#updateButton').click(function(){
  clientId = $('#template_clients').val();
  templateCategory = $('#template_category').val();
  templateText = $('#templateText').val();
  templateState = $('#templateState').is(':checked'); 
  defaultValue = "null";
  if (templateText != "" && templateCategory != defaultValue && clientId != defaultValue){
    $.post("/template_update",
    {
      templateCategory: templateCategory,
      templateText: templateText,
      templateState: templateState,
      clientId: clientId
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
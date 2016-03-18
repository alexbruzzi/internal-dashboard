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
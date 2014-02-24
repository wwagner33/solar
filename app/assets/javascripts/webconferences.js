function save_webconference(){
  var content = $('div.ckeditor .cke_contents iframe').contents().find('body').html();

  if (content != "<p><br></p>" && content != "")
    $('textarea.ckeditor').html(content); // ckeditor nao envia conteudo quando se usa o serialize_and_submit

  $('form#webconference_form').serialize_and_submit({
    replace_list: $('.list_webconferences')
  });
}

$(function(){
  if ($("#radio_option_group").prop("checked"))
    $(".group_label").show();

  $(".expand, .compress").click(function(){
    $(this).parents('div:first').hide();
    $($(this).parents('div:first').siblings()[0]).show();
  });

  $(".link_new_webconference").call_fancybox();

  $('.delete_webconference').click(function(){
    if ($(this).attr('disabled') == 'disabled'){
      flash_message("<%=I18n.t(:choose_at_least_one, scope: 'webconferences.list')%>", "alert");
      return false;
    }

    if (!confirm("<%=I18n.t(:message_confirm)%>"))
      return false;

    var webconferences = $('.ckb_webconference:checked', $(this).parents("div.list_webconferences"));
    var webconference_ids = $('.ckb_webconference:checked', $(this).parents("div.list_webconferences")).map(function() { return this.value; }).get();

    if (webconference_ids.length) {
      $.delete($(this).data('link-delete').replace(':id', webconference_ids), function(data){
        flash_message(data.notice, 'notice');
        webconferences.parents('tr').fadeOut().remove();

        $(".btn_edit, .btn_del").attr("disabled", true);
      }).error(function(data){
        var data = $.parseJSON(data.responseText);
        if (typeof(data.alert) != "undefined")
          flash_message(data.alert, 'alert');
      });
    }
  });

  $(".btn_edit").click(function(){
    if ($(this).attr('disabled') == 'disabled'){
      flash_message("<%=I18n.t(:choose_one, scope: 'webconferences.list')%>", "alert");
      return false;
    }

    var webconference_ids = $('.ckb_webconference:checked', $(this).parents("div.list_webconferences")).map(function() { return this.value; }).get();
    var url_edit = $(this).data('link-edit').replace(':id', webconference_ids);
    $(this).call_fancybox({href : url_edit, open: true});

  });

  $(".all_webconferences").nice_checkbox();
});

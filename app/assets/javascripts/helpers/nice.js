/*********************************************
 * Funcoes genericas - extensoes do jQuery
 *********************************************/

$.fn.nice_checkbox = function(options){
  var parent = this, children_names = $(this).data("children-names");

  /* para que o checkbox possa habilitar ou desabilitar algum botão, deve receber o parâmetro */
  var can_enable_or_disable = (typeof(options) != "undefined" && typeof(options.can_enable_elements) != "undefined"); 

  /**
   * Funcoes para habilitar/desabilitar edicao/delecao
   */
  var enable_edition = function() { $(".btn_edit").attr("disabled", false); };
  var disable_edition = function() { $(".btn_edit").attr("disabled", true); };
  var enable_deletion = function() { $(".btn_del").attr("disabled", false); };
  var disable_deletion = function() { $(".btn_del").attr("disabled", true); };

  /* habilita ou desabilita os elementos passados verificando se aceita um ou múltimos itens checkados 
     o default é aceitar multiplos. caso o elemento aceite apenas um, deverá conter um "data-single"   */
  var enable_other_elements = function (children_checked_length) {
    if (typeof(options) != "undefined" && typeof(options.objects_to_change_status) != "undefined"){
      var elements_to_change = options.objects_to_change_status;
      for (var i = 0; i < elements_to_change.length; i++) {
        var element = $(elements_to_change[i]);
        // se nenhum ckb filho for selecionado, elemento é desabilitado
        // se mais de um ckb filho for selecionado, mas elemento só aceitar um, este é desabilitado
        // caso contrário, habilita
        element.attr("disabled", ( children_checked_length == 0 || (element.data("single") != undefined && children_checked_length > 1)));
      }

    }
  };

  /**
   * Capturando evento de click nos filhos
   */
  var f_kids = function(children) {
    children.click(function(){
      var kid = this;
      var children_checked = $('input:checkbox[name*="' + children_names + '"]:checked');

      if (can_enable_or_disable){
        enable_other_elements(children_checked.length);

        if (kid.checked) { // filho selecionado
          enable_deletion();
          enable_edition();  
          if (children_checked.length == 0 || children_checked.length > 1)
            disable_edition();
        } else { // o evento de click tirou selecao do filho
          if (children_checked.length == 0) { // nenhum filho selecionado
            disable_deletion();
            disable_edition();
          } else if (children_checked.length == 1) { // apenas um filho selecionado
            enable_deletion();
            enable_edition();
          } else if (children_checked.length > 1) { // mais de um filho selecionado
            enable_deletion();
            disable_edition();
          }
        }
      }

      var icon = $('i', parent);
      if(icon.length){ // checkbox como botão
        if(kid.checked && children.length == children_checked.length)
          $(icon).removeClass('icon-checkbox-unchecked').addClass('icon-checkbox-checked');
        else
          $(icon).addClass('icon-checkbox-unchecked').removeClass('icon-checkbox-checked');
      }else // checkbox normal
        $(parent).prop("checked", (kid.checked && children.length == children_checked.length)); // atualiza o pai verificando o status dos filhos

    }); // event de click no filho
  };

  var children = $('input:checkbox[name*="' + children_names + '"]');
  f_kids(children); // eventos nos filhos

  /***
   * Capturando evento de click no parent
   */
  $(this).click(function() {
    var parent = this;
    var icon = $('i', parent);
    if (icon.length){ // checkbox normal
      $(icon).toggleClass('icon-checkbox-unchecked').toggleClass('icon-checkbox-checked');
      var check = !( icon.prop('class') == 'icon-checkbox-unchecked' );
    } else 
      var check = parent.checked;

    children.each(function(i){ $(this).prop("checked", check); });
    f_kids(children); // aplicando funcoes nos filhos

    if (can_enable_or_disable){
      // o botao de edicao devera ser habilitado apenas para um unico objeto
      var children_checked = $('input:checkbox[name*="' + children_names + '"]:checked');
      $(".btn_edit").attr("disabled", !(children_checked.length == 1));
      $(".btn_del").attr("disabled", !check);

      enable_other_elements(children_checked.length);
    }

  }); // end click

  return this;
}

// recupera dados do filtro, consulta, atualiza dados
$.fn.nice_filter = function(options) {
  var filter = $(this);
  $('#search', filter).click(function(){
    erase_flash_messages();

    var load_to = $(this).data("load-to");
    var combos = $('.filter select', filter);

    if (combos.length) {
      // pegar todas as obrigatorias e checar se tem alguma vazia
      var required = $('.filter select:not([data-optional])', filter);
      var filled = required.map(function(){ if (!$(this).is_empty()) return $(this).combobox("value"); });

      if (required.length == filled.length) {
        var combos = combos.map(function(){ if (!$(this).is_empty()) return $(this).prop('name')+'_id: ' + $(this).combobox("value"); }).toArray().join(', ');
        var data = eval("({" + combos + "})"); // transformando os valores dos filtros em json
        var url = $(this).data("url-search");

        if (typeof(options.data_function) == "function"){
          // se selecionou groups, mas não selecionou nenhuma turma, impede de prosseguir
          if(options.data_function().radio_option == "group" && !options.data_function().groups_id.length){
            flash_message("<%= I18n.t(:alert, scope: [:editions]) %>", "alert");
            $('.' + load_to).html('');
            return false;    
          }

          // adiciona os dados das turmas selecionadas, caso haja alguma
          data = $.extend(data, options.data_function());
        }

        $.get(url, data, function(result){
          $('.' + load_to).html(result);
        }).error(function(data){
          $('.' + load_to).html('');

          var data = $.parseJSON(data.responseText);
          if (typeof(data.alert) != "undefined")
            flash_message(data.alert, 'alert');
        });
      } else {
        flash_message("<%= I18n.t(:alert, scope: [:editions]) %>", "alert");
        $('.' + load_to).html('');
      }

    } else
      console.error("Classes não encontradas");
  });

  return this;
}

/**
 * Deleta um objeto retirando sua tr da tabela
 * Apresenta msg (notice, alert) como flash messages
 **/
$.fn.nice_delete = function(options) {
  if (!confirm("<%= I18n.t(:message_confirm) %>"))
    return this;
  if (typeof(options) == "undefined")
    options = {};

  options = $.extend({ parent: 'tr', url: $(this).data("link-delete") }, options);
  var parent = $(this).parents(options.parent);

  if (typeof(options) != "undefined" && typeof(options.success) == "undefined") { // definir success
    options.success = function(data) {
      if (typeof(data.notice) != "undefined")
        flash_message(data.notice, 'notice');

      parent.fadeOut(500, function(){ $(this).remove() });

      if (typeof(options.complement_success) == "function")
        options.complement_success(data);
    }
  }

  if (typeof(options.error) == "undefined") {
    options.error = function(data) {
      var data = $.parseJSON(data.responseText);
      if (typeof(data.alert) != "undefined")
        flash_message(data.alert, 'alert');
    }
  }

  $.ajax({
    method: "DELETE",
    url: options.url,
    success: options.success,
    error: options.error
  });

  return this;
}

/**
 * Define uma funcao pra fazer submit de um form serializando os dados.
 *  - Em caso de erro:
 *     -- O form é exibido novamente, depois do submit, mostrando os erros
 *  - Em caso de sucesso
 *    -- O lightbox fecha (caso não haja opção dizendo o contrário)
 *    -- Exibe msg de notice (caso exista)
 **/
$.fn.serialize_and_submit = function(options) {
  if (typeof(options) == "undefined")
    options = {};
  if (typeof(options) != "undefined" && typeof(options.success) == "undefined") { // definir success
    var form_id = ["form#", $(this).attr('id'), ":first"].join('');
    options.success = function(data) {
      if (typeof(data) == "string" && data.search(".field_with_errors") != -1)
        $('' + form_id).replaceWith(data);
      else {
        // se não houver opção indicando que o lightbox deve se manter aberto, o default é fechá-lo
        if(typeof(options.dont_remove_lightbox) == "undefined" || !options.dont_remove_lightbox) 
          removeLightBox();

        if (typeof(data) != "undefined" && typeof(data.notice) != "undefined")
          flash_message(data.notice, 'notice');

        if (typeof(options.complement_success) == "function")
          options.complement_success(data);

        if (typeof(options.replace_list) != "undefined")
          $.get(options.replace_list.data("link-list"), function(data){
            options.replace_list.replaceWith(data);
          });
      }
    }
  }

  if (typeof(options) != "undefined" && typeof(options.files) != "undefined")
    var data = (new FormData($(this)[0]));
  else
    var data = $(this).serialize();

  var ajax_options = {
    type: $(this).attr('method'),
    url: $(this).attr('action'),
    data: data,
    success: options.success,
    error: function(data) {
      removeLightBox();
      var response = JSON.parse(data.responseText);
      if (typeof(response.alert) != "undefined")
        flash_message(response.alert, 'alert');
    }
  };

  if (typeof(options.files) != "undefined") {
    $.extend(ajax_options, {
      cache: false,
      contentType: false,
      processData: false
    });
  }

  $.ajax(ajax_options);
  return this;
}

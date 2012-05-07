module PostsHelper

  def post_html(post, display_mode = 'list', can_interact = false)
    user = User.find(post.user_id)
    photo_url = user.photo.url(:forum)

    childs = post.children
    editable = ((post.user.id == current_user.id) && (childs.count == 0))

    child_html = ''
    childs.each { |child| child_html << post_html(child, true, can_interact)} unless display_mode == 'list'

    html = <<HTML
      <table border="0" cellpadding="0" cellspacing="0" class="forum_post" id="#{post.id}">
        <tr>
          <td rowspan="3" class="forum_post_icon">
            #{image_tag(photo_url, :alt => t(:mysolar_alt_img_user) + ' ' + user.nick)}
          </td>
          <td class="forum_post_head">
            <div class="forum_post_author">
              <div class="forum_participant_nick" alt="#{user.nick}">
                #{user.nick}
              </div>
              <div class="forum_participant_profile" >
                #{(profile = post.profile).nil? ? '' : profile.name}
              </div>
            </div>
            <div class="forum_post_date">
              #{l(post.updated_at.to_time, :format => :discussion_post_date)}<br />#{l(post.updated_at.to_time, :format => :discussion_post_hour)}
            </div>
          </td>
        </tr>
        <tr>
          <td class="forum_post_content" colspan="2">
            <div class="forum_post_inner_content">
              #{sanitize(post.content)}
            </div>

            #{attachments(post, editable, can_interact)}
            #{buttons(post, editable, can_interact)}
            #{child_html}

          </td>
        </tr>
        <tr></tr>
      </table>
HTML
  end

  def attachments(post, editable = false, can_interact = false)
    files = post.files
    return '' if files.count == 0

    html, html_files =  '', ''
    files.each do |file|
      link_to_down = (link_to file.attachment_file_name, :controller => "discussions", :action => "download_post_file", :idFile => file.id, :id => @discussion.id)
      link_to_remove = (editable and can_interact) ? (link_to (image_tag "icon_delete_small.png", :alt => t(:forum_remove_file)), {:controller => "discussions", :action => "remove_attached_file",
                        :idFile => file.id, :current_page => @current_page, :id => @discussion.id},
                        :confirm=>t(:forum_remove_file_confirm), :title => t(:forum_remove_file), 'data-tooltip' => t(:forum_remove_file)) : ''

      html_files << '<li>'
      html_files <<     "#{link_to_down}&nbsp;&nbsp;#{link_to_remove}"
      html_files << '</li>'
    end

    html = <<HTML
      <div class="forum_post_attachment">
        <h3>
          #{t(:forum_file_list)}
        </h3>
        <ul class="forum_post_attachment_list">
          #{html_files}
        </ul>
      </div>
HTML
  end

  def buttons(post, editable = false, can_interact = false)
    post_string = '<div class="forum_post_buttons">'

    if can_interact
      if editable
        post_string << "<button type='button' class='btn btn_default forum_button_attachment' onclick='showUploadForm(#{post.discussion.id}, #{post.id});'>"
        post_string <<    t(:forum_attach_file) << (image_tag "icon_attachment.png", :alt => t(:forum_attach_file))
        post_string << "</button>"
        post_string << "<input type='button' onclick='del_post(#{post.id}, \"#{discussion_post_path(post.discussion, post)}\")' class='btn btn_caution' value='#{t(:forum_show_remove)}'/>"
      end

      if post.can_be_answered?
        post_string << "<input type='button' post_id='#{post.id}' level='#{post.level}' class='btn btn_default postDialogLink' value='#{t(:forum_show_answer)}'/>"
      end
    else
      post_string << "<a class='forum_post_link_disabled forum_post_link_remove_disabled'>#{t(:forum_show_remove)}</a>&nbsp;&nbsp;"
      post_string << "<a class='forum_post_link_disabled'>#{t(:forum_show_edit)}</a>&nbsp;&nbsp;"
      post_string << "<a class='forum_post_link_disabled'>#{t(:forum_show_answer)}</a>"
    end

    post_string << '</div></div>'
  end

end

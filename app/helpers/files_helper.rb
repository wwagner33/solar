module FilesHelper

  ##
  # Download de arquivos
  ##
  def download_file(redirect_error, pathfile, filename = nil)
    if File.exist?(pathfile)
      send_file pathfile, :filename => filename
    else
      respond_to do |format|
        flash[:error] = t(:error_nonexistent_file)
        format.html {redirect_to(redirect_error)}
      end
    end
  end

end

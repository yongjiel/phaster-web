  Paperclip.interpolates :secret_id do |attachment, style|
    attachment.instance.secret_id
  end

  # Paperclip.interpolates :basename do |attachment, style|
  #   attachment.instance.accession_id
  # end
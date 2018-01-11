module ApplicationHelper

  def render_form_errors(entry)
    render :partial => '/shared/form_errors', :locals => { :entry => entry }
  end

end

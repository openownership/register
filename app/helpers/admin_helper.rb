module AdminHelper
  def admin_user_attributes(user)
    user.attributes.slice(:email, :name, :company_name, :position)
  end
end

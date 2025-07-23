class ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
    # Handle both GET (view) and PATCH (update) requests
    if request.patch?
      update_profile
    end
  end

  def edit
    # Redirect to show page since we're using inline editing
    redirect_to profile_show_path
  end

  private

  def set_user
    @user = current_user
  end

  def update_profile
    # Handle password update separately if provided
    if profile_params[:password].present?
      if @user.update_with_password(profile_params_with_password)
        bypass_sign_in(@user) # Keep user signed in after password change
        redirect_to profile_show_path, notice: "Profile updated successfully!"
      else
        render :show, status: :unprocessable_entity
      end
    else
      # Update profile without password
      profile_update_params = profile_params.except(:password, :password_confirmation, :current_password)
      if @user.update(profile_update_params)
        redirect_to profile_show_path, notice: "Profile updated successfully!"
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :current_password)
  end

  def profile_params_with_password
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :current_password)
  end
end

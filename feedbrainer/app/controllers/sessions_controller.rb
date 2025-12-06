class SessionsController < ApplicationController
  def new
    # Renders the login page
    if current_user
      redirect_to root_path
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out successfully."
  end
end

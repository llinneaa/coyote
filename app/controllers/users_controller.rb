# frozen_string_literal: true

# Provides read-only access to view the profile of individual users
class UsersController < ApplicationController
  before_action :authorize_access

  helper_method :user

  # GET /users/1
  def show
  end

  private

  attr_writer :user

  def authorize_access
    authorize(user)
  end

  def pundit_user
    # necessary to override ApplicationController's method here because in this controller we may not be dealing with a particular organization
    @pundit_user ||= Coyote::OrganizationUser.new(current_user, nil)
  end

  def user
    @user ||= User.find(params[:id])
  end
end

class AlertPreferencesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(alert_params)
      redirect_to edit_alert_preferences_path, notice: "Preferences updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def alert_params
    params.require(:user).permit(:alert_frequency, :alert_email_enabled)
  end
end

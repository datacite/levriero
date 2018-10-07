class Ability
  include CanCan::Ability

  attr_reader :user

  def initialize(user)
    user ||= User.new(nil) # Guest user
    @user = user

    if user.role_id == "staff_admin"
      can :manage, :all
    elsif user.role_id == "staff_user"
      can :read, :all
    end
  end
end

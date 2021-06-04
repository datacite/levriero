class Ability
  include CanCan::Ability

  attr_reader :user

  def initialize(user)
    user ||= User.new(nil) # Guest user
    @user = user

    case user.role_id
    when "staff_admin"
      can :manage, :all
    when "staff_user"
      can :read, :all
    end
  end
end

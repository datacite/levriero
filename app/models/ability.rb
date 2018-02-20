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
    elsif user.role_id == "provider_admin" && user.provider_id.present?
      can [:update, :read], Provider, :symbol => user.provider_id.upcase
      can [:manage], Client,:provider_id => user.provider_id
      can [:read], User
    elsif user.role_id == "provider_user" && user.provider_id.present?
      can [:read], Provider, :symbol => user.provider_id.upcase
      can [:read], Client, :provider_id => user.provider_id
      can [:read], User
    elsif user.role_id == "client_admin" && user.client_id.present?
      can [:read, :update], Client, :symbol => user.client_id.upcase
      can [:read], User
    elsif user.role_id == "client_user" && user.client_id.present?
      can [:read], Client, :symbol => user.client_id.upcase
      can [:read], User
    elsif user.role_id == "user"
      can [:read, :update], Provider, :symbol => user.provider_id.upcase if user.provider_id.present?
      can [:read, :update], Client, :symbol => user.client_id.upcase if user.client_id.present?
      can [:read], User, :id => user.id
    end
  end
end

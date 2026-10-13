module ServerAction::Registry
  CONTRACT = %i[validate! execute! succeeded! failed!].freeze

  def self.register(classes)
    classes.each_with_object({}) do |klass, actions|
      unless klass.is_a?(Class) && !(klass < ActiveRecord::Base) && klass.const_defined?(:KEY, false)
        raise ArgumentError, "Invalid action contract"
      end
      key = klass::KEY
      raise ArgumentError, "Duplicate action key" if actions.key?(key)
      raise ArgumentError, "Invalid action contract" unless key.is_a?(String) && key.present? && CONTRACT.all? { |method| klass.method_defined?(method) }
      actions[key] = klass
    end.freeze
  end

  ACTIONS = register([
    ServerActions::CreateApp,
    ServerActions::CreateDomain,
    ServerActions::CreateService,
    ServerActions::DeployApp,
    ServerActions::DestroyApp,
    ServerActions::DestroyDomain,
    ServerActions::DestroyProject,
    ServerActions::DestroyService,
    ServerActions::EnableSsl,
    ServerActions::LinkService,
    ServerActions::MountStorage,
    ServerActions::PullEnv,
    ServerActions::RestartApp,
    ServerActions::RestartService,
    ServerActions::SetAppBuilder,
    ServerActions::UnlinkService,
    ServerActions::UnmountStorage,
    ServerActions::UpdateEnv
  ])

  def self.key_for(action)
    raise ArgumentError, "Unregistered action" unless ACTIONS.value?(action)
    action::KEY
  end

  def self.build(run)
    ACTIONS.fetch(run.action_key).new(run)
  end
end

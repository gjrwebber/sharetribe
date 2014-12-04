module TransactionService::Store::PaymentSettings

  PaymentSettingsModel = ::PaymentSettings

  PaymentSettings = EntityUtils.define_builder(
    [:active, :to_bool, default: false],
    [:community_id, :mandatory, :fixnum],
    [:payment_gateway, :to_symbol, one_of: [:paypal, :braintree, :checkout, :none], default: :none],
    [:payment_process, :to_symbol, one_of: [:preauthorize, :postpay, :free], default: :free],
    [:commission_from_seller, :fixnum],
    [:minimum_price_cents, :fixnum],
    [:confirmation_after_days, :fixnum, default: 14]
  )

  module_function

  def create(opts)
    settings = HashUtils.compact(PaymentSettings.call(opts))
    model = PaymentSettingsModel.create!(settings)
    from_model(model)
  end

  def update(opts)
    settings = HashUtils.compact(PaymentSettings.call(opts)).except(:active, :payment_process, :payment_gateway)
    model = find(opts[:community_id], opts[:payment_gateway], opts[:payment_process])
    raise ArgumentError.new("Cannot find settings to update: cid: #{opts[:community_id]}, gateway: #{opts[:payment_gateway]}, process: #{opts[:payment_process]}") if model.nil?

    model.update_attributes!(settings)
    from_model(model)
  end

  def get(community_id:, payment_gateway:, payment_process:)
    Maybe(find(community_id, payment_gateway, payment_process))
      .map { |m| from_model(m) }
      .or_else(nil)
  end

  def get_active(community_id:)
    Maybe(PaymentSettingsModel
           .where(community_id: community_id, active: true)
           .first)
      .map { |m| from_model(m) }
      .or_else(nil)
  end

  def activate(community_id:, payment_gateway:, payment_process:)
    model = find(community_id, payment_gateway, payment_process)
    raise ArgumentError.new("Cannot find settings to activate: cid: #{community_id}, gateway: #{payment_gateway}, process: #{payment_process}") if model.nil?

    return from_model(model) if model.active

    prev_active = PaymentSettingsModel.where(community_id: community_id, active: true)
    ActiveRecord::Base.transaction do
      prev_active.each { |m| m.update_attributes!(active: false) }
      model.update_attributes!(active: true)
    end

    from_model(model)
  end

  def disable(community_id:, payment_gateway:, payment_process:)
    model = find(community_id, payment_gateway, payment_process)
    raise ArgumentError.new("Cannot find settings to disable: cid: #{community_id}, gateway: #{payment_gateway}, process: #{payment_process}") if model.nil?

    model.update_attributes!(active: false)
    from_model(model)
  end

  ## Privates

  def from_model(model)
    Maybe(model)
      .map { |m| PaymentSettings.call(EntityUtils.model_to_hash(m)) }
      .or_else(nil)
  end

  def find(community_id, payment_gateway, payment_process)
    PaymentSettingsModel.where(
      community_id: community_id,
      payment_process: payment_process,
      payment_gateway: payment_gateway
    ).first
  end

end
